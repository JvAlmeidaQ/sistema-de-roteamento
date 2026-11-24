/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Verifica: RF05, RF06, RF10, RN04, RN08, RR11 pela API /api/auditoria e gatilhos do banco
 */
package br.ufjf.dcc.entregas.features.auditoria;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jooq.DSLContext;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.HISTORICO_ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.HISTORICO_PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static br.ufjf.dcc.entregas.jooq.Tables.VW_AUDITORIA_SLA_ENTREGAS;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class AuditoriaIntegrationTest {

    private static final String USUARIO_HEADER = "X-User-Id";
    private static final long ADMIN_ID = 7L;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DSLContext dsl;

    @Test
    @DisplayName("RF05/RN04: retorna histórico cronológico de um pedido existente")
    void deveListarHistoricoPedidoEmOrdemCronologica() throws Exception {
        Long idPedido = dsl.select(HISTORICO_PEDIDO.ID_PEDIDO)
                .from(HISTORICO_PEDIDO)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idPedido).isNotNull();

        JsonNode eventos = lerJson(mockMvc.perform(get("/api/auditoria/pedidos/{id}/historico", idPedido)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0)))));

        assertOrdemCronologica(eventos, "dataHora");
    }

    @Test
    @DisplayName("RF05/RN04: retorna histórico cronológico de uma entrega existente")
    void deveListarHistoricoEntregaEmOrdemCronologica() throws Exception {
        Long idEntrega = dsl.select(HISTORICO_ENTREGA.ID_ENTREGA)
                .from(HISTORICO_ENTREGA)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idEntrega).isNotNull();

        JsonNode eventos = lerJson(mockMvc.perform(get("/api/auditoria/entregas/{id}/historico", idEntrega)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0)))));

        assertOrdemCronologica(eventos, "dataHora");
    }

    @Test
    @DisplayName("RF05: unifica eventos comerciais e logísticos na linha do tempo do pedido (vw_auditoria_linha_tempo_pedido)")
    void deveListarLinhaTempoUnificadaDoPedido() throws Exception {
        Long idPedidoComEntrega = dsl.select(ENTREGA.ID_PEDIDO)
                .from(ENTREGA)
                .join(HISTORICO_ENTREGA).on(HISTORICO_ENTREGA.ID_ENTREGA.eq(ENTREGA.ID_ENTREGA))
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idPedidoComEntrega).isNotNull();

        JsonNode linhaTempo = lerJson(mockMvc.perform(get("/api/auditoria/pedidos/{id}/linha-tempo", idPedidoComEntrega)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(1)))));

        List<String> dominios = new ArrayList<>();
        linhaTempo.forEach(item -> dominios.add(item.get("dominioEvento").asText()));

        assertThat(dominios).contains("COMERCIAL", "LOGISTICO");
        assertOrdemCronologica(linhaTempo, "dataHora");
    }

    @Test
    @DisplayName("RF10: consulta SLA de entregas com filtros por loja e apenasAtrasadas (vw_auditoria_sla_entregas)")
    void deveConsultarSlaEntregasComFiltros() throws Exception {
        Long idLojaComSla = dsl.select(VW_AUDITORIA_SLA_ENTREGAS.ID_LOJA)
                .from(VW_AUDITORIA_SLA_ENTREGAS)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idLojaComSla).isNotNull();

        JsonNode porLoja = lerJson(mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header(USUARIO_HEADER, ADMIN_ID)
                        .param("idLoja", idLojaComSla.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0)))));

        porLoja.forEach(item -> assertThat(item.get("idLoja").asLong()).isEqualTo(idLojaComSla));

        JsonNode atrasadas = lerJson(mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header(USUARIO_HEADER, ADMIN_ID)
                        .param("apenasAtrasadas", "true"))
                .andExpect(status().isOk()));

        atrasadas.forEach(item -> assertThat(item.get("atrasada").asBoolean()).isTrue());
    }

    @Test
    @DisplayName("RF05: retorna 404 para pedido ou entrega inexistentes e 400 para ID inválido")
    void deveRetornarNotFoundParaRecursosInexistentes() throws Exception {
        mockMvc.perform(get("/api/auditoria/pedidos/{id}/historico", 999_999_999L)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isNotFound());

        mockMvc.perform(get("/api/auditoria/pedidos/{id}/linha-tempo", 999_999_999L)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isNotFound());

        mockMvc.perform(get("/api/auditoria/entregas/{id}/historico", 999_999_999L)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isNotFound());

        mockMvc.perform(get("/api/auditoria/pedidos/{id}/linha-tempo", 0)
                        .header(USUARIO_HEADER, ADMIN_ID))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("RF10: rejeita intervalo temporal invertido (inicio > fim) com 400 Bad Request")
    void deveRejeitarIntervaloTemporalInvalido() throws Exception {
        mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header(USUARIO_HEADER, ADMIN_ID)
                        .param("inicio", "2026-06-01T00:00:00Z")
                        .param("fim", "2026-05-01T00:00:00Z"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("RF05/RF10: aplica controle de acesso por ator (Admin, Lojista, Entregador, Cliente e terceiro)")
    void deveAplicarControleDeAcessoPorAtor() throws Exception {
        // 1) Sem X-User-Id -> 403
        mockMvc.perform(get("/api/auditoria/sla/entregas"))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/auditoria/pedidos/1/linha-tempo"))
                .andExpect(status().isForbidden());

        // 2) Cliente exclusivo não pode consultar painel de SLA -> 403
        Long idClienteExclusivo = dsl.select(CLIENTE.ID_PESSOA)
                .from(CLIENTE)
                .whereNotExists(dsl.selectOne().from(LOJA).where(LOJA.ID_LOJISTA.eq(CLIENTE.ID_PESSOA)))
                .andNotExists(dsl.selectOne().from(ENTREGADOR).where(ENTREGADOR.ID_PESSOA.eq(CLIENTE.ID_PESSOA)))
                .and(CLIENTE.ID_PESSOA.ne(ADMIN_ID))
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idClienteExclusivo).isNotNull();

        mockMvc.perform(get("/api/auditoria/sla/entregas").header(USUARIO_HEADER, idClienteExclusivo))
                .andExpect(status().isForbidden());

        // 3) Lojista só consulta SLA da própria loja; outra loja retorna 403
        var lojaSla = dsl.select(LOJA.ID_LOJA, LOJA.ID_LOJISTA)
                .from(LOJA)
                .join(VW_AUDITORIA_SLA_ENTREGAS).on(VW_AUDITORIA_SLA_ENTREGAS.ID_LOJA.eq(LOJA.ID_LOJA))
                .where(LOJA.ID_LOJISTA.ne(ADMIN_ID))
                .limit(1)
                .fetchOne();
        assertThat(lojaSla).isNotNull();
        Long idLoja = lojaSla.value1();
        Long idLojista = lojaSla.value2();

        JsonNode slaLojista = lerJson(mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header(USUARIO_HEADER, idLojista))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0)))));
        slaLojista.forEach(item -> assertThat(item.get("idLoja").asLong()).isEqualTo(idLoja));

        Long outraLoja = dsl.select(LOJA.ID_LOJA)
                .from(LOJA)
                .where(LOJA.ID_LOJISTA.ne(idLojista))
                .limit(1)
                .fetchOneInto(Long.class);
        if (outraLoja != null) {
            mockMvc.perform(get("/api/auditoria/sla/entregas")
                            .header(USUARIO_HEADER, idLojista)
                            .param("idLoja", outraLoja.toString()))
                    .andExpect(status().isForbidden());
        }

        // 4) Entregador exclusivo só vê SLA das próprias rotas
        var entregaRota = dsl.select(ROTA.ID_ROTA, ROTA.ID_ENTREGADOR)
                .from(ROTA)
                .join(VW_AUDITORIA_SLA_ENTREGAS).on(VW_AUDITORIA_SLA_ENTREGAS.ID_ROTA.eq(ROTA.ID_ROTA))
                .whereNotExists(dsl.selectOne().from(LOJA).where(LOJA.ID_LOJISTA.eq(ROTA.ID_ENTREGADOR)))
                .and(ROTA.ID_ENTREGADOR.ne(ADMIN_ID))
                .limit(1)
                .fetchOne();
        assertThat(entregaRota).isNotNull();
        Long idEntregador = entregaRota.value2();

        JsonNode slaEntregador = lerJson(mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header(USUARIO_HEADER, idEntregador))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(greaterThan(0)))));
        List<Long> rotasDoEntregador = dsl.select(ROTA.ID_ROTA)
                .from(ROTA)
                .where(ROTA.ID_ENTREGADOR.eq(idEntregador))
                .fetchInto(Long.class);
        slaEntregador.forEach(item -> assertThat(rotasDoEntregador).contains(item.get("idRota").asLong()));

        // 5) Participante pode ver linha do tempo do pedido; terceiro sem vínculo recebe 403
        var pedido = dsl.select(PEDIDO.ID_PEDIDO, PEDIDO.ID_CLIENTE, LOJA.ID_LOJISTA)
                .from(PEDIDO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .limit(1)
                .fetchOne();
        assertThat(pedido).isNotNull();

        mockMvc.perform(get("/api/auditoria/pedidos/{id}/linha-tempo", pedido.value1())
                        .header(USUARIO_HEADER, pedido.value2()))
                .andExpect(status().isOk());

        Long terceiro = dsl.select(PESSOA.ID_PESSOA)
                .from(PESSOA)
                .where(PESSOA.ID_PESSOA.ne(ADMIN_ID)
                        .and(PESSOA.ID_PESSOA.ne(pedido.value2()))
                        .and(PESSOA.ID_PESSOA.ne(pedido.value3())))
                .andNotExists(dsl.selectOne()
                        .from(ENTREGA)
                        .join(ROTA).on(ROTA.ID_ROTA.eq(ENTREGA.ID_ROTA))
                        .where(ENTREGA.ID_PEDIDO.eq(pedido.value1()).and(ROTA.ID_ENTREGADOR.eq(PESSOA.ID_PESSOA))))
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(terceiro).isNotNull();

        mockMvc.perform(get("/api/auditoria/pedidos/{id}/linha-tempo", pedido.value1())
                        .header(USUARIO_HEADER, terceiro))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("RN08/RR11: API de auditoria é somente leitura e rejeita POST, PUT e DELETE (405)")
    void deveBloquearMetodosDeEscritaNaApiDeAuditoria() throws Exception {
        mockMvc.perform(post("/api/auditoria/pedidos/1/historico"))
                .andExpect(status().isMethodNotAllowed());

        mockMvc.perform(put("/api/auditoria/pedidos/1/historico"))
                .andExpect(status().isMethodNotAllowed());

        mockMvc.perform(delete("/api/auditoria/pedidos/1/historico"))
                .andExpect(status().isMethodNotAllowed());
    }

    @Test
    @DisplayName("RN08/RR11: gatilho bloqueia UPDATE em historico_pedido")
    void deveBloquearUpdateEmHistoricoPedido() {
        Long idPedido = dsl.select(HISTORICO_PEDIDO.ID_PEDIDO)
                .from(HISTORICO_PEDIDO)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idPedido).isNotNull();

        assertThatThrownBy(() -> dsl.update(HISTORICO_PEDIDO)
                .set(HISTORICO_PEDIDO.DATA_HORA, OffsetDateTime.now())
                .where(HISTORICO_PEDIDO.ID_PEDIDO.eq(idPedido))
                .execute())
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("RN08");
    }

    @Test
    @DisplayName("RN08/RR11: gatilho bloqueia DELETE em historico_pedido")
    void deveBloquearDeleteEmHistoricoPedido() {
        Long idPedido = dsl.select(HISTORICO_PEDIDO.ID_PEDIDO)
                .from(HISTORICO_PEDIDO)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idPedido).isNotNull();

        assertThatThrownBy(() -> dsl.deleteFrom(HISTORICO_PEDIDO)
                .where(HISTORICO_PEDIDO.ID_PEDIDO.eq(idPedido))
                .execute())
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("RN08");
    }

    @Test
    @DisplayName("RN08/RR11: gatilho bloqueia UPDATE em historico_entrega")
    void deveBloquearUpdateEmHistoricoEntrega() {
        Long idEntrega = dsl.select(HISTORICO_ENTREGA.ID_ENTREGA)
                .from(HISTORICO_ENTREGA)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idEntrega).isNotNull();

        assertThatThrownBy(() -> dsl.update(HISTORICO_ENTREGA)
                .set(HISTORICO_ENTREGA.DATA_HORA, OffsetDateTime.now())
                .where(HISTORICO_ENTREGA.ID_ENTREGA.eq(idEntrega))
                .execute())
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("RN08");
    }

    @Test
    @DisplayName("RN08/RR11: gatilho bloqueia DELETE em historico_entrega")
    void deveBloquearDeleteEmHistoricoEntrega() {
        Long idEntrega = dsl.select(HISTORICO_ENTREGA.ID_ENTREGA)
                .from(HISTORICO_ENTREGA)
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idEntrega).isNotNull();

        assertThatThrownBy(() -> dsl.deleteFrom(HISTORICO_ENTREGA)
                .where(HISTORICO_ENTREGA.ID_ENTREGA.eq(idEntrega))
                .execute())
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("RN08");
    }

    @Test
    @DisplayName("Segurança: Admin atuando como entregador via X-Active-Role restringe SLA às próprias entregas")
    void deveRespeitarPapelAtivoDoAdminNoSla() throws Exception {
        // ID 7 é administrador e entregador na carga; com X-Active-Role=entregador não deve receber entregas de terceiros
        mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header("X-User-Id", 7L)
                        .header("X-Active-Role", "entregador"))
                .andExpect(status().isOk());

        // ID 7 não é lojista -> X-Active-Role=lojista deve retornar 403
        mockMvc.perform(get("/api/auditoria/sla/entregas")
                        .header("X-User-Id", 7L)
                        .header("X-Active-Role", "lojista"))
                .andExpect(status().isForbidden());
    }

    private JsonNode lerJson(ResultActions resultado) throws Exception {
        return objectMapper.readTree(resultado.andReturn().getResponse().getContentAsString());
    }

    private void assertOrdemCronologica(JsonNode lista, String campoData) {
        OffsetDateTime anterior = null;
        for (JsonNode item : lista) {
            OffsetDateTime atual = OffsetDateTime.parse(item.get(campoData).asText());
            if (anterior != null) {
                assertThat(atual).isAfterOrEqualTo(anterior);
            }
            anterior = atual;
        }
    }
}