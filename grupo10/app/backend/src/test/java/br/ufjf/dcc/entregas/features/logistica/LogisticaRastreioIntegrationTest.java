/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística — RF05
 */
package br.ufjf.dcc.entregas.features.logistica;

import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jooq.DSLContext;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.sql.SQLException;

import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;
import static br.ufjf.dcc.entregas.jooq.Tables.ROTA;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
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
class LogisticaRastreioIntegrationTest {

    private static final String RASTREIO = "/api/logistica/pedidos/{id}/rastreio";
    private static final String USUARIO = "X-User-Id";
    private static final String STATUS_PEDIDO = "/api/pedidos/{id}/status";
    private static final String STATUS_ENTREGA = "/api/logistica/entregas/{id}/status";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DSLContext dsl;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void deveRastrearPedidoEEntregaEmSequenciaCronologica() throws Exception {
        var pedido = dsl.select(PEDIDO.ID_PEDIDO, PEDIDO.ID_CLIENTE).from(PEDIDO)
                .where(PEDIDO.STATUS.eq(StatusPedido.concluido))
                .orderBy(PEDIDO.ID_PEDIDO).limit(1).fetchSingle();

        mockMvc.perform(get(RASTREIO, pedido.value1()).header(USUARIO, pedido.value2()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.statusPedido").value("concluido"))
                .andExpect(jsonPath("$.entrega.status").value("entregue"))
                .andExpect(jsonPath("$.historicoIncompleto").value(false))
                .andExpect(jsonPath("$.eventos", hasSize(10)))
                .andExpect(jsonPath("$.eventos[0].tipo").value("PEDIDO"))
                .andExpect(jsonPath("$.eventos[0].status").value("solicitado"))
                .andExpect(jsonPath("$.eventos[4].status").value("pronto"))
                .andExpect(jsonPath("$.eventos[5].tipo").value("ENTREGA"))
                .andExpect(jsonPath("$.eventos[5].status").value("aguardando_entregador"))
                .andExpect(jsonPath("$.eventos[8].status").value("entregue"))
                .andExpect(jsonPath("$.eventos[9].status").value("concluido"))
                .andExpect(jsonPath("$.eventos[9].dataHora").isString());
    }

    @Test
    void deveRegistrarENavegarTodoOCicloDeUmPedidoNovo() throws Exception {
        var cliente = dsl.select(CLIENTE.ID_PESSOA, CLIENTE.ID_ENDERECO_ATUAL).from(CLIENTE)
                .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                .orderBy(CLIENTE.ID_PESSOA).limit(1).fetchSingle();
        var loja = dsl.select(LOJA.ID_LOJA, LOJA.ID_LOJISTA, PRODUTO.ID_PRODUTO).from(LOJA)
                .join(PRODUTO).on(PRODUTO.ID_LOJA.eq(LOJA.ID_LOJA))
                .where(LOJA.STATUS_FUNCIONAMENTO.eq(StatusFuncionamento.aberta)).and(PRODUTO.ATIVO.isTrue())
                .orderBy(LOJA.ID_LOJA, PRODUTO.ID_PRODUTO).limit(1).fetchSingle();
        long idEntregador = dsl.select(ENTREGADOR.ID_PESSOA).from(ENTREGADOR)
                .where(ENTREGADOR.ID_PESSOA.notIn(cliente.value1(), loja.value2()))
                .andNotExists(dsl.selectOne().from(ROTA)
                        .where(ROTA.ID_ENTREGADOR.eq(ENTREGADOR.ID_PESSOA)).and(ROTA.ENCERRADA_EM.isNull()))
                .orderBy(ENTREGADOR.ID_PESSOA).limit(1).fetchSingle(ENTREGADOR.ID_PESSOA);

        String resposta = mockMvc.perform(post("/api/pedidos").header(USUARIO, cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"idLoja":%d,"idEndereco":%d,"formaPagamento":"pix",
                                 "itens":[{"idProduto":%d,"quantidade":1}]}
                                """.formatted(loja.value1(), cliente.value2(), loja.value3())))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long idPedido = objectMapper.readTree(resposta).path("idPedido").longValue();

        mockMvc.perform(get(RASTREIO, idPedido).header(USUARIO, cliente.value1()))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(jsonPath("$.entrega").value(nullValue()))
                .andExpect(jsonPath("$.historicoIncompleto").value(false))
                .andExpect(jsonPath("$.eventos[*].status", contains("solicitado")));
        mockMvc.perform(get(RASTREIO, idPedido).header(USUARIO, idEntregador))
                .andExpect(status().isForbidden());

        mudarStatus(STATUS_PEDIDO, idPedido, loja.value2(), "aceito", 200);
        mudarStatus(STATUS_PEDIDO, idPedido, cliente.value1(), "pago", 200);
        mudarStatus(STATUS_PEDIDO, idPedido, loja.value2(), "em_preparacao", 200);
        mudarStatus(STATUS_PEDIDO, idPedido, loja.value2(), "pronto", 200);
        long idEntrega = dsl.select(ENTREGA.ID_ENTREGA).from(ENTREGA)
                .where(ENTREGA.ID_PEDIDO.eq(idPedido)).fetchSingle(ENTREGA.ID_ENTREGA);
        mockMvc.perform(post("/api/logistica/entregas/{id}/assumir", idEntrega).header(USUARIO, idEntregador))
                .andExpect(status().isNoContent());
        mudarStatus(STATUS_ENTREGA, idEntrega, idEntregador, "a_caminho", 204);
        mudarStatus(STATUS_ENTREGA, idEntrega, idEntregador, "entregue", 204);

        for (long participante : new long[]{cliente.value1(), loja.value2(), idEntregador}) {
            mockMvc.perform(get(RASTREIO, idPedido).header(USUARIO, participante))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.historicoIncompleto").value(false))
                    .andExpect(jsonPath("$.entrega.previsaoEntrega").isString())
                    .andExpect(jsonPath("$.eventos[*].status", contains("solicitado", "aceito", "pago",
                            "em_preparacao", "pronto", "aguardando_entregador", "aceita", "a_caminho",
                            "entregue", "concluido")));
        }
        long terceiro = dsl.select(PESSOA.ID_PESSOA).from(PESSOA)
                .where(PESSOA.ID_PESSOA.notIn(cliente.value1(), loja.value2(), idEntregador))
                .limit(1).fetchSingle(PESSOA.ID_PESSOA);
        mockMvc.perform(get(RASTREIO, idPedido).header(USUARIO, terceiro))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.eventos").doesNotHaveJsonPath());
    }

    @Test
    void deveExplicitarLacunaDeEntregaLegadaSemCriarEventos() throws Exception {
        var pedido = dsl.select(PEDIDO.ID_PEDIDO, PEDIDO.ID_CLIENTE).from(PEDIDO)
                .where(PEDIDO.STATUS.eq(StatusPedido.pronto))
                .andNotExists(dsl.selectOne().from(ENTREGA).where(ENTREGA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO)))
                .orderBy(PEDIDO.ID_PEDIDO).limit(1).fetchSingle();

        mockMvc.perform(get(RASTREIO, pedido.value1()).header(USUARIO, pedido.value2()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.entrega").value(nullValue()))
                .andExpect(jsonPath("$.historicoIncompleto").value(true))
                .andExpect(jsonPath("$.eventos[*].status", contains("solicitado", "aceito", "pago",
                        "em_preparacao", "pronto")));
    }

    @Test
    void deveValidarIdentificadorECabecalhoNoRastreio() throws Exception {
        mockMvc.perform(get(RASTREIO, 1)).andExpect(status().isBadRequest());
        mockMvc.perform(get(RASTREIO, 0).header(USUARIO, 1)).andExpect(status().isBadRequest());
        mockMvc.perform(get(RASTREIO, Long.MAX_VALUE).header(USUARIO, 1)).andExpect(status().isNotFound());
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "UPDATE historico_pedido SET data_hora = data_hora WHERE id_pedido = 1",
            "DELETE FROM historico_pedido WHERE id_pedido = 1",
            "UPDATE historico_entrega SET data_hora = data_hora WHERE id_entrega = 1",
            "DELETE FROM historico_entrega WHERE id_entrega = 1"
    })
    void deveProtegerOsEventosRegistrados(String comando) {
        assertThatThrownBy(() -> dsl.execute(comando))
                .rootCause()
                .isInstanceOfSatisfying(SQLException.class, erro -> {
                    assertThat(erro.getSQLState()).isEqualTo("23514");
                    assertThat(erro.getMessage()).contains("RN08/RR11");
                });
    }

    private void mudarStatus(String rota, long id, long participante, String novoStatus, int esperado) throws Exception {
        mockMvc.perform(patch(rota, id).header(USUARIO, participante)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"" + novoStatus + "\"}"))
                .andExpect(status().is(esperado));
    }
}
