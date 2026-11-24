/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica;

import br.ufjf.dcc.entregas.jooq.enums.FormaPagamento;
import br.ufjf.dcc.entregas.jooq.enums.StatusEntrega;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import br.ufjf.dcc.entregas.jooq.enums.TipoVeiculo;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jooq.DSLContext;
import org.junit.jupiter.api.Test;
import org.postgresql.ds.PGSimpleDataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.support.BeanDefinitionRegistryPostProcessor;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.support.GenericApplicationContext;
import org.springframework.core.env.MapPropertySource;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadLocalRandom;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static java.util.concurrent.TimeUnit.SECONDS;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.fail;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.http.HttpStatus.CONFLICT;
import static org.springframework.http.HttpStatus.NO_CONTENT;
import static org.springframework.http.HttpStatus.UNPROCESSABLE_ENTITY;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Limita a espera por locks no PostgreSQL mesmo se o cancelamento do Future não interromper o SQL.
@SpringBootTest(properties = "spring.datasource.hikari.connection-init-sql=SET statement_timeout = '15s'")
@AutoConfigureMockMvc
@ContextConfiguration(initializers = LogisticaConcorrenciaIntegrationTest.BancoDescartavel.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class LogisticaConcorrenciaIntegrationTest {

    private static final String ASSUMIR = "/api/logistica/entregas/{id}/assumir";
    private static final String PAINEL = "/api/logistica/painel";
    private static final String USUARIO = "X-User-Id";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DSLContext dsl;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void apenasUmEntregadorDeveAssumirAMesmaEntregaEmDisputa() throws Exception {
        var fixture = criarFixture(2, 1);
        long idEntrega = fixture.idsEntregas().getFirst();
        var tentativas = fixture.idsEntregadores().stream()
                .map(idEntregador -> new TentativaAceite(idEntregador, idEntrega))
                .toList();

        var resultados = assumirConcorrentemente(tentativas);

        assertThat(resultados).as("Respostas dos aceites: %s", resultados)
                .extracting(ResultadoAceite::statusHttp)
                .containsExactlyInAnyOrder(NO_CONTENT.value(), CONFLICT.value());
        for (var resultado : resultados) {
            long idEntregador = resultado.tentativa().idEntregador();
            if (resultado.statusHttp() == NO_CONTENT.value()) {
                verificarRota(idEntregador, List.of(idEntrega), 1);
            } else {
                painel(idEntregador).andExpect(jsonPath("$.rotaAtual").value(nullValue()));
            }
        }
    }

    @Test
    void deveAbrirUmaUnicaRotaERespeitarRn02EmAceitesSimultaneos() throws Exception {
        var fixture = criarFixture(1, 3);
        long idEntregador = fixture.idsEntregadores().getFirst();
        painel(idEntregador).andExpect(jsonPath("$.rotaAtual").value(nullValue()));
        var tentativas = fixture.idsEntregas().stream()
                .map(idEntrega -> new TentativaAceite(idEntregador, idEntrega))
                .toList();

        var resultados = assumirConcorrentemente(tentativas);

        assertThat(resultados).as("Respostas dos aceites: %s", resultados)
                .extracting(ResultadoAceite::statusHttp)
                .containsExactlyInAnyOrder(NO_CONTENT.value(), NO_CONTENT.value(), UNPROCESSABLE_ENTITY.value());
        var recusada = resultados.stream()
                .filter(resultado -> resultado.statusHttp() == UNPROCESSABLE_ENTITY.value())
                .findFirst().orElseThrow();
        assertThat(objectMapper.readTree(recusada.corpo()).path("message").asText())
                .as("Motivo do 422 para a entrega %d", recusada.tentativa().idEntrega())
                .contains("limite de 2 entregas");
        var aceitas = resultados.stream()
                .filter(resultado -> resultado.statusHttp() == NO_CONTENT.value())
                .map(resultado -> resultado.tentativa().idEntrega())
                .toList();
        long idRota = verificarRota(idEntregador, aceitas, 0);

        // O painel só exibe uma rota aberta, mesmo se houver uma segunda rota órfã.
        assertThat(dsl.select(ROTA.ID_ROTA).from(ROTA)
                .where(ROTA.ID_ENTREGADOR.eq(idEntregador)).fetch(ROTA.ID_ROTA))
                .as("Rotas persistidas para o entregador %d", idEntregador)
                .containsExactly(idRota);
    }

    @Test
    void gatilhoRn02DeveRecusarTerceiroVinculoConcorrenteNaMesmaRota() throws Exception {
        var fixture = criarFixture(1, 3);
        long primeira = fixture.idsEntregas().get(0);
        long segunda = fixture.idsEntregas().get(1);
        long terceira = fixture.idsEntregas().get(2);
        long idRota = dsl.transactionResult(config -> {
            var tx = config.dsl();
            long rota = tx.insertInto(ROTA)
                    .set(ROTA.ID_ENTREGADOR, fixture.idsEntregadores().getFirst())
                    .returningResult(ROTA.ID_ROTA).fetchSingle(ROTA.ID_ROTA);
            assertThat(vincularEntrega(tx, primeira, rota)).isEqualTo(1);
            return rota;
        });

        var executor = Executors.newSingleThreadExecutor(
                Thread.ofPlatform().daemon().name("rn02-concorrente").factory());
        try {
            var terceiroVinculo = dsl.transactionResult(config -> {
                var tx = config.dsl();
                tx.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED");
                int pidBloqueador = pidPostgres(tx);
                // As escritas vão direto a ENTREGA, sem o lock do entregador usado pelo serviço.
                assertThat(vincularEntrega(tx, segunda, idRota)).isEqualTo(1);

                var pidConcorrente = new CompletableFuture<Integer>();
                var tentativa = executor.submit(() -> {
                    try {
                        return dsl.transactionResult(configConcorrente -> {
                            var concorrente = configConcorrente.dsl();
                            concorrente.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED");
                            pidConcorrente.complete(pidPostgres(concorrente));
                            return vincularEntrega(concorrente, terceira, idRota);
                        });
                    } catch (RuntimeException e) {
                        pidConcorrente.completeExceptionally(e);
                        throw e;
                    }
                });

                int pidBloqueado = pidConcorrente.get(5, SECONDS);
                assertThat(pidBloqueado).as("Sessões PostgreSQL independentes").isNotEqualTo(pidBloqueador);
                aguardarBloqueioDaRota(tx, pidBloqueador, pidBloqueado, tentativa);
                // transactionResult só confirma o segundo vínculo depois de observar o bloqueio.
                return tentativa;
            });

            assertThatThrownBy(() -> terceiroVinculo.get(10, SECONDS))
                    .as("A última vaga pertence à transação que confirmou o segundo vínculo")
                    .isInstanceOf(ExecutionException.class)
                    .rootCause()
                    .isInstanceOfSatisfying(SQLException.class, erro -> {
                        assertThat(erro.getSQLState()).isEqualTo("23514");
                        assertThat(erro.getMessage()).contains("RN02");
                    });
        } finally {
            executor.shutdownNow();
            assertThat(executor.awaitTermination(20, SECONDS))
                    .as("Término da tentativa de vínculo antes do descarte do banco").isTrue();
        }

        assertThat(dsl.select(ENTREGA.ID_ENTREGA).from(ENTREGA)
                .where(ENTREGA.ID_ROTA.eq(idRota)).fetch(ENTREGA.ID_ENTREGA))
                .as("Vínculos confirmados na rota %d", idRota)
                .containsExactlyInAnyOrder(primeira, segunda);
    }

    private int vincularEntrega(DSLContext tx, long idEntrega, long idRota) {
        return tx.update(ENTREGA)
                .set(ENTREGA.ID_ROTA, idRota)
                .set(ENTREGA.STATUS, StatusEntrega.aceita)
                .where(ENTREGA.ID_ENTREGA.eq(idEntrega)).execute();
    }

    private int pidPostgres(DSLContext tx) {
        return tx.fetchSingle("select pg_backend_pid()").get(0, Integer.class);
    }

    private void aguardarBloqueioDaRota(DSLContext tx, int pidBloqueador, int pidBloqueado,
                                       Future<Integer> tentativa) throws Exception {
        long inicio = System.nanoTime();
        do {
            var bloqueada = tx.fetchSingle("select ? = any(pg_blocking_pids(?))", pidBloqueador, pidBloqueado)
                    .get(0, Boolean.class);
            if (Boolean.TRUE.equals(bloqueada)) {
                return;
            }
            if (tentativa.isDone()) {
                fail("O terceiro vínculo alterou %d linha(s) sem aguardar o lock da rota", tentativa.get(0, SECONDS));
            }
            Thread.sleep(25);
        } while (System.nanoTime() - inicio < SECONDS.toNanos(5));
        fail("A sessão %d não ficou bloqueada pela sessão %d", pidBloqueado, pidBloqueador);
    }

    private List<ResultadoAceite> assumirConcorrentemente(List<TentativaAceite> tentativas) throws Exception {
        var largada = new CyclicBarrier(tentativas.size());
        var tarefas = tentativas.stream().<Callable<ResultadoAceite>>map(tentativa -> () -> {
            var requisicao = post(ASSUMIR, tentativa.idEntrega()).header(USUARIO, tentativa.idEntregador());
            largada.await(10, SECONDS);
            var resposta = mockMvc.perform(requisicao).andReturn().getResponse();
            return new ResultadoAceite(tentativa, resposta.getStatus(), resposta.getContentAsString());
        }).toList();

        var executor = Executors.newFixedThreadPool(tarefas.size(),
                Thread.ofPlatform().daemon().name("aceite-concorrente-", 0).factory());
        List<Future<ResultadoAceite>> futuros;
        try {
            futuros = executor.invokeAll(tarefas, 30, SECONDS);
        } finally {
            executor.shutdownNow();
            assertThat(executor.awaitTermination(20, SECONDS))
                    .as("Término das threads de aceite antes do descarte do banco").isTrue();
        }

        var resultados = new ArrayList<ResultadoAceite>();
        for (int i = 0; i < futuros.size(); i++) {
            var futuro = futuros.get(i);
            assertThat(futuro.isCancelled()).as("Prazo para o POST de %s", tentativas.get(i)).isFalse();
            resultados.add(futuro.get(0, SECONDS));
        }
        return resultados;
    }

    private ResultActions painel(long idEntregador) throws Exception {
        return mockMvc.perform(get(PAINEL).header(USUARIO, idEntregador))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.encerradas.itens", hasSize(0)));
    }

    private long verificarRota(long idEntregador, List<Long> entregasEsperadas, int vagas) throws Exception {
        String corpo = painel(idEntregador)
                .andExpect(jsonPath("$.rotaAtual.idRota").isNumber())
                .andExpect(jsonPath("$.rotaAtual.totalEntregas").value(entregasEsperadas.size()))
                .andExpect(jsonPath("$.rotaAtual.vagas").value(vagas))
                .andExpect(jsonPath("$.rotaAtual.entregas").isArray())
                .andReturn().getResponse().getContentAsString();
        var rota = objectMapper.readTree(corpo).path("rotaAtual");
        long idRota = rota.path("idRota").longValue();
        assertThat(idRota).isPositive();
        var idsEntregas = new ArrayList<Long>();
        rota.path("entregas").forEach(entrega -> idsEntregas.add(entrega.path("idEntrega").longValue()));
        assertThat(idsEntregas).as("Entregas da rota %d", idRota)
                .containsExactlyInAnyOrderElementsOf(entregasEsperadas);
        return idRota;
    }

    private Fixture criarFixture(int quantidadeEntregadores, int quantidadeEntregas) {
        // Confirma todos os inserts antes dos POSTs, que usam transações próprias do serviço.
        return dsl.transactionResult(config -> {
            var tx = config.dsl();
            var cliente = tx.select(CLIENTE.ID_PESSOA, CLIENTE.ID_ENDERECO_ATUAL).from(CLIENTE)
                    .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                    .orderBy(CLIENTE.ID_PESSOA).limit(1).fetchSingle();
            // O gatilho usa o tempo estimado da loja; a folga evita que RN03 interfira no teste de RN02.
            var loja = tx.select(LOJA.ID_LOJA, LOJA.TAXA_ENTREGA).from(LOJA)
                    .where(LOJA.TEMPO_ENTREGA_ESTIMADO.ge(10))
                    .orderBy(LOJA.ID_LOJA).limit(1).fetchSingle();

            var idsEntregadores = new ArrayList<Long>();
            for (int i = 0; i < quantidadeEntregadores; i++) {
                idsEntregadores.add(criarEntregador(tx));
            }

            var idsEntregas = new ArrayList<Long>();
            var subtotal = BigDecimal.TEN;
            var taxaEntrega = loja.value2();
            var taxaServico = new BigDecimal("2.50");
            for (int i = 0; i < quantidadeEntregas; i++) {
                long idPedido = tx.insertInto(PEDIDO)
                        .set(PEDIDO.ID_CLIENTE, cliente.value1())
                        .set(PEDIDO.ID_ENDERECO, cliente.value2())
                        .set(PEDIDO.ID_LOJA, loja.value1())
                        .set(PEDIDO.FORMA_PAGAMENTO, FormaPagamento.pix)
                        .set(PEDIDO.STATUS, StatusPedido.em_preparacao)
                        .set(PEDIDO.SUBTOTAL, subtotal)
                        .set(PEDIDO.TAXA_ENTREGA, taxaEntrega)
                        .set(PEDIDO.TAXA_SERVICO, taxaServico)
                        .set(PEDIDO.VALOR_TOTAL, subtotal.add(taxaEntrega).add(taxaServico))
                        .returningResult(PEDIDO.ID_PEDIDO).fetchSingle(PEDIDO.ID_PEDIDO);
                tx.update(PEDIDO).set(PEDIDO.STATUS, StatusPedido.pronto)
                        .where(PEDIDO.ID_PEDIDO.eq(idPedido)).execute();
                idsEntregas.add(tx.select(ENTREGA.ID_ENTREGA).from(ENTREGA)
                        .where(ENTREGA.ID_PEDIDO.eq(idPedido)).fetchSingle(ENTREGA.ID_ENTREGA));
            }
            return new Fixture(List.copyOf(idsEntregadores), List.copyOf(idsEntregas));
        });
    }

    private long criarEntregador(DSLContext tx) {
        String cpf = Long.toString(ThreadLocalRandom.current().nextLong(90_000_000_000L, 100_000_000_000L));
        long id = tx.insertInto(PESSOA)
                .set(PESSOA.NOME, "Entregador do teste de concorrência")
                .set(PESSOA.CPF, cpf)
                .set(PESSOA.EMAIL, "logistica-concorrencia-" + cpf + "@example.test")
                .returningResult(PESSOA.ID_PESSOA).fetchSingle(PESSOA.ID_PESSOA);
        tx.insertInto(ENTREGADOR).set(ENTREGADOR.ID_PESSOA, id)
                .set(ENTREGADOR.TIPO_VEICULO, TipoVeiculo.bicicleta).execute();
        return id;
    }

    static class BancoDescartavel implements ApplicationContextInitializer<GenericApplicationContext> {

        @Override
        public void initialize(GenericApplicationContext context) {
            // Dentro do refresh (para descartar mesmo se a inicialização falhar), antes da autoconfiguração.
            context.addBeanFactoryPostProcessor(
                    (BeanDefinitionRegistryPostProcessor) registry -> prepararBanco(context));
        }

        private static void prepararBanco(GenericApplicationContext context) {
            var ambiente = context.getEnvironment();
            String nome = "logistica_conc_it_" + UUID.randomUUID().toString().replace("-", "");

            var postgres = new PGSimpleDataSource();
            postgres.setUrl(ambiente.getRequiredProperty("spring.datasource.url"));
            postgres.setUser(ambiente.getRequiredProperty("spring.datasource.username"));
            postgres.setPassword(ambiente.getRequiredProperty("spring.datasource.password"));
            postgres.setDatabaseName(nome);
            String urlDoTeste = postgres.getUrl();
            postgres.setDatabaseName("postgres");

            try (var conexao = postgres.getConnection(); var comando = conexao.createStatement()) {
                comando.execute("CREATE DATABASE " + nome + " TEMPLATE template0");
                // Registrado antes do pool, para rodar depois de ele fechar. Só descarta um CREATE bem-sucedido.
                context.getDefaultListableBeanFactory().registerDisposableBean(nome, () -> {
                    try (var manutencao = postgres.getConnection(); var drop = manutencao.createStatement()) {
                        drop.execute("DROP DATABASE " + nome + " WITH (FORCE)");
                    }
                });
            } catch (SQLException e) {
                throw new IllegalStateException("Não foi possível criar o banco de teste " + nome
                        + "; é preciso acesso ao banco postgres e permissão CREATEDB.", e);
            }

            ambiente.getPropertySources().addFirst(new MapPropertySource("bancoLogisticaConcorrencia", Map.of(
                    "spring.datasource.url", urlDoTeste,
                    "spring.datasource.hikari.jdbc-url", urlDoTeste,
                    "spring.datasource.hikari.username", "${spring.datasource.username}",
                    "spring.datasource.hikari.password", "${spring.datasource.password}",
                    "spring.flyway.url", urlDoTeste,
                    "spring.flyway.user", "${spring.datasource.username}",
                    "spring.flyway.password", "${spring.datasource.password}",
                    "spring.flyway.enabled", true)));
        }
    }

    private record Fixture(List<Long> idsEntregadores, List<Long> idsEntregas) {}
    private record TentativaAceite(long idEntregador, long idEntrega) {}
    private record ResultadoAceite(TentativaAceite tentativa, int statusHttp, String corpo) {}
}
