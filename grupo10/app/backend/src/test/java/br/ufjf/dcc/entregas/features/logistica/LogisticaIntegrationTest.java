/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica;

import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jooq.DSLContext;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJISTA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class LogisticaIntegrationTest {

    private static final String PAINEL = "/api/logistica/painel";
    private static final String ENTREGA_API = "/api/logistica/entregas/{id}";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DSLContext dsl;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void deveOferecerEntregadorExclusivoNaSessaoDeDemonstracao() throws Exception {
        long idEntregador = dsl.select(ENTREGADOR.ID_PESSOA).from(ENTREGADOR)
                .whereNotExists(dsl.selectOne().from(CLIENTE).where(CLIENTE.ID_PESSOA.eq(ENTREGADOR.ID_PESSOA)))
                .andNotExists(dsl.selectOne().from(LOJISTA).where(LOJISTA.ID_PESSOA.eq(ENTREGADOR.ID_PESSOA)))
                .orderBy(ENTREGADOR.ID_PESSOA).limit(1).fetchSingle(ENTREGADOR.ID_PESSOA);

        mockMvc.perform(get("/api/logistica/sessao/entregadores"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].idPessoa", hasItem((int) idEntregador)))
                .andExpect(jsonPath("$[0].nome").isString())
                .andExpect(jsonPath("$[*].email").isEmpty());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(status().isOk());
    }

    @Test
    void deveListarFilaPaginadaSemExporEnderecoCompleto() throws Exception {
        long idEntregador = dsl.select(ENTREGADOR.ID_PESSOA)
                .from(ENTREGADOR)
                .orderBy(ENTREGADOR.ID_PESSOA)
                .limit(1)
                .fetchSingle(ENTREGADOR.ID_PESSOA);

        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.disponiveis.pagina").value(1))
                .andExpect(jsonPath("$.disponiveis.temProxima").value(true))
                .andExpect(jsonPath("$.disponiveis.itens", hasSize(10)))
                .andExpect(jsonPath("$.disponiveis.itens[0].nomeLoja").isString())
                .andExpect(jsonPath("$.disponiveis.itens[0].bairroDestino").isString())
                .andExpect(jsonPath("$.disponiveis.itens[0].previsaoEntrega").isString())
                .andExpect(jsonPath("$.disponiveis.itens[0].enderecoEntrega").doesNotHaveJsonPath())
                .andExpect(jsonPath("$.disponiveis.itens[0].cepDestino").doesNotHaveJsonPath());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador)
                        .param("paginaDisponiveis", "2").param("paginaEncerradas", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.disponiveis.pagina").value(2))
                .andExpect(jsonPath("$.encerradas.pagina").value(3));
    }

    @Test
    void deveAssumirEntregaEAbrirRotaComUmaVaga() throws Exception {
        long idEntregador = entregadoresSemRotaAberta(1).getFirst();
        var entrega = gerarEntrega();

        assumir(idEntregador, entrega.idEntrega()).andExpect(status().isNoContent());

        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rotaAtual.vagas").value(1))
                .andExpect(jsonPath("$.rotaAtual.entregasAtivas").value(1))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].idEntrega").value(is(entrega.idEntrega()), Long.class))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].status").value("aceita"))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].enderecoColeta", matchesPattern(".*CEP [0-9]{5}-[0-9]{3}.*")))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].enderecoEntrega", matchesPattern(".*CEP [0-9]{5}-[0-9]{3}.*")))
                .andExpect(jsonPath("$.disponiveis.itens[*].idEntrega", not(hasItem((int) entrega.idEntrega()))));
    }

    @Test
    void deveRegistrarRetiradaEConcluirPedidoAoFinalizarUltimaEntrega() throws Exception {
        var entregadores = entregadoresSemRotaAberta(2);
        long idEntregador = entregadores.get(0);
        long idOutro = entregadores.get(1);
        var entrega = gerarEntrega();
        long idCliente = dsl.select(PEDIDO.ID_CLIENTE).from(PEDIDO)
                .where(PEDIDO.ID_PEDIDO.eq(entrega.idPedido())).fetchSingle(PEDIDO.ID_CLIENTE);

        assumir(idEntregador, entrega.idEntrega()).andExpect(status().isNoContent());
        long idRota = painel(idEntregador).path("rotaAtual").path("idRota").asLong();

        alterarStatus(idEntregador, entrega.idEntrega(), "a_caminho").andExpect(status().isNoContent());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].status").value("a_caminho"));

        alterarStatus(idEntregador, entrega.idEntrega(), "entregue").andExpect(status().isNoContent());
        alterarStatus(idEntregador, entrega.idEntrega(), "entregue").andExpect(status().isConflict());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(jsonPath("$.rotaAtual").value(nullValue()))
                .andExpect(jsonPath("$.encerradas.itens[?(@.idRota == %d)].idsPedidos[*]".formatted(idRota),
                        hasItem((int) entrega.idPedido())));
        mockMvc.perform(get(PAINEL).header("X-User-Id", idOutro))
                .andExpect(jsonPath("$.encerradas.itens[*].idRota", not(hasItem((int) idRota))));
        mockMvc.perform(get("/api/logistica/pedidos/{id}/rastreio", entrega.idPedido()).header("X-User-Id", idEntregador))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.entrega.status").value("entregue"));
        mockMvc.perform(get("/api/pedidos/{id}", entrega.idPedido()).header("X-User-Id", idCliente))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("concluido"))
                .andExpect(jsonPath("$.statusEntrega").value("entregue"));
    }

    @Test
    void deveBloquearAlteracaoDeTerceiroESaltoDeStatus() throws Exception {
        var entregadores = entregadoresSemRotaAberta(2);
        long idResponsavel = entregadores.get(0);
        long idOutro = entregadores.get(1);
        var entrega = gerarEntrega();

        assumir(idResponsavel, entrega.idEntrega()).andExpect(status().isNoContent());
        alterarStatus(idOutro, entrega.idEntrega(), "a_caminho").andExpect(status().isForbidden());
        alterarStatus(idResponsavel, entrega.idEntrega(), "entregue").andExpect(status().isUnprocessableEntity());
        alterarStatus(idResponsavel, entrega.idEntrega(), "aguardando_entregador").andExpect(status().isBadRequest());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idResponsavel))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].status").value("aceita"));
        mockMvc.perform(get(PAINEL).header("X-User-Id", idOutro))
                .andExpect(jsonPath("$.rotaAtual").value(nullValue()));
    }

    @Test
    void deveManterLimiteAposPrimeiraConclusaoEAbrirOutraRotaSoDepoisDoEncerramento() throws Exception {
        long idEntregador = entregadoresSemRotaAberta(1).getFirst();
        var primeira = gerarEntrega();
        var segunda = gerarEntrega();
        var terceira = gerarEntrega();

        assumir(idEntregador, primeira.idEntrega()).andExpect(status().isNoContent());
        long idRota = painel(idEntregador).path("rotaAtual").path("idRota").asLong();
        assumir(idEntregador, segunda.idEntrega()).andExpect(status().isNoContent());

        concluirEntrega(idEntregador, primeira.idEntrega());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(jsonPath("$.rotaAtual.idRota").value(is(idRota), Long.class))
                .andExpect(jsonPath("$.rotaAtual.totalEntregas").value(2))
                .andExpect(jsonPath("$.rotaAtual.entregasAtivas").value(1))
                .andExpect(jsonPath("$.rotaAtual.vagas").value(0));
        assumir(idEntregador, terceira.idEntrega()).andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message", containsString("RN02")));

        concluirEntrega(idEntregador, segunda.idEntrega());
        assumir(idEntregador, terceira.idEntrega()).andExpect(status().isNoContent());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(jsonPath("$.rotaAtual.idRota").value(not(is(idRota)), Long.class))
                .andExpect(jsonPath("$.rotaAtual.totalEntregas").value(1))
                .andExpect(jsonPath("$.encerradas.itens[*].idRota", hasItem((int) idRota)));
    }

    @Test
    void deveBloquearSegundaEntregaComAtrasoMesmoHavendoVaga() throws Exception {
        long idEntregador = entregadoresSemRotaAberta(1).getFirst();
        var vencida = gerarEntrega();
        var outra = gerarEntrega();
        dsl.update(ENTREGA).set(ENTREGA.PREVISAO_ENTREGA, OffsetDateTime.now().minusDays(1))
                .where(ENTREGA.ID_ENTREGA.eq(vencida.idEntrega())).execute();

        assumir(idEntregador, vencida.idEntrega()).andExpect(status().isNoContent());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(jsonPath("$.rotaAtual.vagas").value(1))
                .andExpect(jsonPath("$.rotaAtual.entregasAtrasadas").value(1))
                .andExpect(jsonPath("$.rotaAtual.entregas[0].atrasada").value(true));
        assumir(idEntregador, outra.idEntrega()).andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message", containsString("RN03")));

        concluirEntrega(idEntregador, vencida.idEntrega());
        assumir(idEntregador, outra.idEntrega()).andExpect(status().isNoContent());
    }

    @Test
    void deveMostrarEntregaGeradaPeloBancoQuandoPedidoFicaPronto() throws Exception {
        long idEntregador = entregadoresSemRotaAberta(1).getFirst();
        var pedido = dsl.select(PEDIDO.ID_PEDIDO, LOJA.ID_LOJISTA).from(PEDIDO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .where(PEDIDO.STATUS.eq(StatusPedido.em_preparacao))
                .orderBy(PEDIDO.ID_PEDIDO).limit(1).fetchSingle();

        mockMvc.perform(patch("/api/pedidos/{id}/status", pedido.value1())
                        .header("X-User-Id", pedido.value2())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"pronto\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statusEntrega").value("aguardando_entregador"));
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(jsonPath("$.disponiveis.itens[0].idPedido").value(is(pedido.value1()), Long.class));
    }

    @Test
    void deveExigirPapelDeEntregadorEValidarParametros() throws Exception {
        long idEntregador = entregadoresSemRotaAberta(1).getFirst();
        long idSemPapelDeEntregador = dsl.select(PESSOA.ID_PESSOA).from(PESSOA)
                .whereNotExists(dsl.selectOne().from(ENTREGADOR).where(ENTREGADOR.ID_PESSOA.eq(PESSOA.ID_PESSOA)))
                .limit(1).fetchSingle(PESSOA.ID_PESSOA);

        mockMvc.perform(get(PAINEL)).andExpect(status().isBadRequest());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador).param("paginaDisponiveis", "0"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(get(PAINEL).header("X-User-Id", idSemPapelDeEntregador))
                .andExpect(status().isForbidden());
        assumir(idSemPapelDeEntregador, gerarEntrega().idEntrega()).andExpect(status().isForbidden());
        assumir(idEntregador, Long.MAX_VALUE).andExpect(status().isNotFound());
    }

    private void concluirEntrega(long idEntregador, long idEntrega) throws Exception {
        alterarStatus(idEntregador, idEntrega, "a_caminho").andExpect(status().isNoContent());
        alterarStatus(idEntregador, idEntrega, "entregue").andExpect(status().isNoContent());
    }

    private ResultActions assumir(long idEntregador, long idEntrega) throws Exception {
        return mockMvc.perform(post(ENTREGA_API + "/assumir", idEntrega).header("X-User-Id", idEntregador));
    }

    private ResultActions alterarStatus(long idEntregador, long idEntrega, String novoStatus) throws Exception {
        return mockMvc.perform(patch(ENTREGA_API + "/status", idEntrega)
                .header("X-User-Id", idEntregador)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"novoStatus\":\"" + novoStatus + "\"}"));
    }

    private JsonNode painel(long idEntregador) throws Exception {
        return objectMapper.readTree(mockMvc.perform(get(PAINEL).header("X-User-Id", idEntregador))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString());
    }

    private List<Long> entregadoresSemRotaAberta(int quantidade) {
        return dsl.select(ENTREGADOR.ID_PESSOA)
                .from(ENTREGADOR)
                .whereNotExists(dsl.selectOne().from(ROTA)
                        .where(ROTA.ID_ENTREGADOR.eq(ENTREGADOR.ID_PESSOA))
                        .and(ROTA.ENCERRADA_EM.isNull()))
                .orderBy(ENTREGADOR.ID_PESSOA)
                .limit(quantidade)
                .fetch(ENTREGADOR.ID_PESSOA);
    }

    private EntregaFixture gerarEntrega() {
        long idPedido = dsl.select(PEDIDO.ID_PEDIDO).from(PEDIDO)
                .where(PEDIDO.STATUS.eq(StatusPedido.em_preparacao))
                .orderBy(PEDIDO.ID_PEDIDO)
                .limit(1)
                .fetchSingle(PEDIDO.ID_PEDIDO);
        dsl.update(PEDIDO).set(PEDIDO.STATUS, StatusPedido.pronto)
                .where(PEDIDO.ID_PEDIDO.eq(idPedido)).execute();
        long idEntrega = dsl.select(ENTREGA.ID_ENTREGA).from(ENTREGA)
                .where(ENTREGA.ID_PEDIDO.eq(idPedido)).fetchSingle(ENTREGA.ID_ENTREGA);
        return new EntregaFixture(idPedido, idEntrega);
    }

    private record EntregaFixture(long idPedido, long idEntrega) {}
}
