/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio;

import br.ufjf.dcc.entregas.core.exception.GlobalExceptionHandler;
import br.ufjf.dcc.entregas.jooq.enums.StatusEntrega;
import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.jooq.DSLContext;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.SQLException;

import static br.ufjf.dcc.entregas.jooq.Tables.AVALIACAO_ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.AVALIACAO_LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.DIVISAO_PAGAMENTO;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA_ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class ComercioFinancasIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DSLContext dsl;

    @Autowired
    private GlobalExceptionHandler exceptionHandler;

    @Test
    void deveCriarPedidoPreservarSnapshotsECicloCompletoComAutorizacao() throws Exception {
        var lojaAberta = dsl.selectFrom(LOJA)
                .where(LOJA.STATUS_FUNCIONAMENTO.eq(StatusFuncionamento.aberta))
                .limit(1)
                .fetchOne();
        assertThat(lojaAberta).isNotNull();

        var outraLoja = dsl.selectFrom(LOJA)
                .where(LOJA.ID_LOJA.ne(lojaAberta.getIdLoja()))
                .limit(1)
                .fetchOne();
        assertThat(outraLoja).isNotNull();

        var produtoAtivo = dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_LOJA.eq(lojaAberta.getIdLoja()))
                .and(PRODUTO.ATIVO.isTrue())
                .limit(1)
                .fetchOne();
        assertThat(produtoAtivo).isNotNull();

        var clientes = dsl.select(CLIENTE.ID_PESSOA, CLIENTE.ID_ENDERECO_ATUAL)
                .from(CLIENTE)
                .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                .limit(2)
                .fetch();
        assertThat(clientes).hasSize(2);

        Long idClienteA = clientes.get(0).value1();
        Long idEnderecoA = clientes.get(0).value2();
        Long idClienteB = clientes.get(1).value1();

        String payload = """
                {
                  "idLoja": %d,
                  "idEndereco": %d,
                  "formaPagamento": "pix",
                  "observacaoEntrega": "Tocar interfone",
                  "itens": [
                    { "idProduto": %d, "quantidade": 2 }
                  ]
                }
                """.formatted(lojaAberta.getIdLoja(), idEnderecoA, produtoAtivo.getIdProduto());

        String responseBody = mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", idClienteA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("solicitado"))
                .andExpect(jsonPath("$.taxaServico").value(2.5))
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode json = objectMapper.readTree(responseBody);
        long idPedido = json.get("idPedido").asLong();
        BigDecimal subtotalEsperado = produtoAtivo.getPreco().multiply(BigDecimal.valueOf(2));
        BigDecimal totalEsperado = subtotalEsperado.add(lojaAberta.getTaxaEntrega()).add(new BigDecimal("2.50"));
        assertThat(new BigDecimal(json.get("subtotal").asText())).isEqualByComparingTo(subtotalEsperado);
        assertThat(new BigDecimal(json.get("valorTotal").asText())).isEqualByComparingTo(totalEsperado);

        // RR09: alterar preço do produto e taxa da loja após a compra não altera os snapshots do pedido
        dsl.update(PRODUTO)
                .set(PRODUTO.PRECO, produtoAtivo.getPreco().add(new BigDecimal("50.00")))
                .where(PRODUTO.ID_PRODUTO.eq(produtoAtivo.getIdProduto()))
                .execute();
        dsl.update(LOJA)
                .set(LOJA.TAXA_ENTREGA, lojaAberta.getTaxaEntrega().add(new BigDecimal("15.00")))
                .where(LOJA.ID_LOJA.eq(lojaAberta.getIdLoja()))
                .execute();

        String consultaPosAlteracao = mockMvc.perform(get("/api/pedidos/{id}", idPedido)
                        .header("X-User-Id", idClienteA))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        JsonNode jsonPos = objectMapper.readTree(consultaPosAlteracao);
        assertThat(new BigDecimal(jsonPos.get("valorTotal").asText())).isEqualByComparingTo(totalEsperado);

        // Autorização: Cliente B não pode consultar pedido do Cliente A (403)
        mockMvc.perform(get("/api/pedidos/{id}", idPedido)
                        .header("X-User-Id", idClienteB))
                .andExpect(status().isForbidden());

        // Autorização: Lojista de outra loja não pode aceitar pedido da loja atual (403)
        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", outraLoja.getIdLojista())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"aceito\"}"))
                .andExpect(status().isForbidden());

        // RR06: salto inválido solicitado -> pronto deve falhar com 422
        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", lojaAberta.getIdLojista())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"pronto\"}"))
                .andExpect(status().isUnprocessableEntity());

        // RF03: Lojista aceita -> Cliente B tenta pagar (403) -> Cliente A paga -> em_preparacao -> pronto (RN12)
        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", lojaAberta.getIdLojista())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"aceito\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("aceito"));

        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", idClienteB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"pago\"}"))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", idClienteA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"pago\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("pago"));

        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", lojaAberta.getIdLojista())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"em_preparacao\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("em_preparacao"));

        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", lojaAberta.getIdLojista())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"pronto\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("pronto"))
                .andExpect(jsonPath("$.statusEntrega").value("aguardando_entregador"));

        // RN13/RR08: antes de concluir entrega, split (pelo lojista) e avaliações falham com 422
        mockMvc.perform(post("/api/pedidos/{id}/divisao-pagamento", idPedido)
                        .header("X-User-Id", lojaAberta.getIdLojista()))
                .andExpect(status().isUnprocessableEntity());

        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/loja", idPedido)
                        .header("X-User-Id", idClienteA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":5,\"comentario\":\"Ótimo\"}"))
                .andExpect(status().isUnprocessableEntity());

        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/entregador", idPedido)
                        .header("X-User-Id", idClienteA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":5,\"comentario\":\"Rápido\"}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void devePermitirRecusaDePedidoEBloquearPagamentoPosterior() throws Exception {
        var lojaAberta = dsl.selectFrom(LOJA)
                .where(LOJA.STATUS_FUNCIONAMENTO.eq(StatusFuncionamento.aberta))
                .limit(1)
                .fetchOne();
        var produtoAtivo = dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_LOJA.eq(lojaAberta.getIdLoja()))
                .and(PRODUTO.ATIVO.isTrue())
                .limit(1)
                .fetchOne();
        var cliente = dsl.select(CLIENTE.ID_PESSOA, CLIENTE.ID_ENDERECO_ATUAL)
                .from(CLIENTE)
                .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                .limit(1)
                .fetchOne();

        String body = mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "cartao_credito",
                                  "itens": [{ "idProduto": %d, "quantidade": 1 }]
                                }
                                """.formatted(lojaAberta.getIdLoja(), cliente.value2(), produtoAtivo.getIdProduto())))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        long idPedido = objectMapper.readTree(body).get("idPedido").asLong();

        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", lojaAberta.getIdLojista())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"recusado\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("recusado"));

        mockMvc.perform(patch("/api/pedidos/{id}/status", idPedido)
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"novoStatus\":\"pago\"}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void deveRejeitarViolacoesDeRn01Rn07Rn09ERr03AoCriarPedido() throws Exception {
        var lojaFechada = dsl.selectFrom(LOJA)
                .where(LOJA.STATUS_FUNCIONAMENTO.eq(StatusFuncionamento.fechada))
                .limit(1)
                .fetchOne();
        assertThat(lojaFechada).isNotNull();

        var produtoLojaFechada = dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_LOJA.eq(lojaFechada.getIdLoja()))
                .and(PRODUTO.ATIVO.isTrue())
                .limit(1)
                .fetchOne();
        assertThat(produtoLojaFechada).isNotNull();

        var cliente = dsl.select(CLIENTE.ID_PESSOA, CLIENTE.ID_ENDERECO_ATUAL)
                .from(CLIENTE)
                .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                .limit(1)
                .fetchOne();
        assertThat(cliente).isNotNull();

        // RN09/RR13 e RR19: quantidade 0 e lista vazia -> 400
        mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "pix",
                                  "itens": []
                                }
                                """.formatted(lojaFechada.getIdLoja(), cliente.value2())))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "pix",
                                  "itens": [{ "idProduto": %d, "quantidade": 0 }]
                                }
                                """.formatted(lojaFechada.getIdLoja(), cliente.value2(), produtoLojaFechada.getIdProduto())))
                .andExpect(status().isBadRequest());

        // RN01: loja fechada -> 422
        mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "pix",
                                  "itens": [{ "idProduto": %d, "quantidade": 1 }]
                                }
                                """.formatted(lojaFechada.getIdLoja(), cliente.value2(), produtoLojaFechada.getIdProduto())))
                .andExpect(status().isUnprocessableEntity());

        // RN07: item de outra loja -> 422
        var lojaAberta = dsl.selectFrom(LOJA)
                .where(LOJA.STATUS_FUNCIONAMENTO.eq(StatusFuncionamento.aberta))
                .limit(1)
                .fetchOne();
        assertThat(lojaAberta).isNotNull();

        mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "pix",
                                  "itens": [{ "idProduto": %d, "quantidade": 1 }]
                                }
                                """.formatted(lojaAberta.getIdLoja(), cliente.value2(), produtoLojaFechada.getIdProduto())))
                .andExpect(status().isUnprocessableEntity());

        // RR04: produto inativo -> 422
        var produtoInativo = dsl.select(PRODUTO.ID_LOJA, PRODUTO.ID_PRODUTO)
                .from(PRODUTO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PRODUTO.ID_LOJA))
                .where(PRODUTO.ATIVO.isFalse())
                .and(LOJA.STATUS_FUNCIONAMENTO.eq(StatusFuncionamento.aberta))
                .limit(1)
                .fetchOne();
        assertThat(produtoInativo).isNotNull();

        mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "pix",
                                  "itens": [{ "idProduto": %d, "quantidade": 1 }]
                                }
                                """.formatted(
                                produtoInativo.value1(),
                                cliente.value2(),
                                produtoInativo.value2())))
                .andExpect(status().isUnprocessableEntity());

        // RR03: endereço de outro cliente -> 422
        Long enderecoAlheio = dsl.select(PESSOA_ENDERECO.ID_ENDERECO)
                .from(PESSOA_ENDERECO)
                .where(PESSOA_ENDERECO.ID_PESSOA.ne(cliente.value1()))
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(enderecoAlheio).isNotNull();

        var produtoLojaAberta = dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_LOJA.eq(lojaAberta.getIdLoja()))
                .and(PRODUTO.ATIVO.isTrue())
                .limit(1)
                .fetchOne();
        assertThat(produtoLojaAberta).isNotNull();

        mockMvc.perform(post("/api/pedidos")
                        .header("X-User-Id", cliente.value1())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idLoja": %d,
                                  "idEndereco": %d,
                                  "formaPagamento": "pix",
                                  "itens": [{ "idProduto": %d, "quantidade": 1 }]
                                }
                                """.formatted(lojaAberta.getIdLoja(), enderecoAlheio, produtoLojaAberta.getIdProduto())))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void deveRegistrarSplitEAvaliacoesParaPedidoConcluidoEEntregue() throws Exception {
        var pedidoEntregue = dsl.select(PEDIDO.ID_PEDIDO, PEDIDO.ID_CLIENTE, LOJA.ID_LOJISTA, PEDIDO.TAXA_ENTREGA, PEDIDO.VALOR_TOTAL)
                .from(PEDIDO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .join(ENTREGA).on(ENTREGA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .where(PEDIDO.STATUS.eq(StatusPedido.concluido))
                .and(ENTREGA.STATUS.eq(StatusEntrega.entregue))
                .andNotExists(dsl.selectOne().from(AVALIACAO_LOJA).where(AVALIACAO_LOJA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO)))
                .andNotExists(dsl.selectOne().from(AVALIACAO_ENTREGADOR).where(AVALIACAO_ENTREGADOR.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO)))
                .limit(1)
                .fetchOne();
        assertThat(pedidoEntregue).isNotNull();

        Long idPedido = pedidoEntregue.value1();
        Long idCliente = pedidoEntregue.value2();
        Long idLojista = pedidoEntregue.value3();
        BigDecimal taxaEntregaPedido = pedidoEntregue.value4();
        BigDecimal valorTotalPedido = pedidoEntregue.value5();

        // Garante teste limpo de split removendo eventual split da carga na transação (revertido ao fim do @Test)
        dsl.deleteFrom(DIVISAO_PAGAMENTO).where(DIVISAO_PAGAMENTO.ID_PEDIDO.eq(idPedido)).execute();

        // Cliente não pode registrar split -> 403
        mockMvc.perform(post("/api/pedidos/{id}/divisao-pagamento", idPedido)
                        .header("X-User-Id", idCliente))
                .andExpect(status().isForbidden());

        // RF09/RN05: lojista dono calcula e registra split (201 Created) e verifica soma exata
        String splitBody = mockMvc.perform(post("/api/pedidos/{id}/divisao-pagamento", idPedido)
                        .header("X-User-Id", idLojista))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode splitJson = objectMapper.readTree(splitBody);
        BigDecimal parcelaLoja = new BigDecimal(splitJson.get("parcelaLoja").asText());
        BigDecimal comissaoEntregador = new BigDecimal(splitJson.get("comissaoEntregador").asText());
        BigDecimal taxaPlataforma = new BigDecimal(splitJson.get("taxaPlataforma").asText());
        assertThat(comissaoEntregador).isEqualByComparingTo(taxaEntregaPedido);
        assertThat(parcelaLoja.add(comissaoEntregador).add(taxaPlataforma)).isEqualByComparingTo(valorTotalPedido);

        // RF09 duplicidade -> 409 Conflict
        mockMvc.perform(post("/api/pedidos/{id}/divisao-pagamento", idPedido)
                        .header("X-User-Id", idLojista))
                .andExpect(status().isConflict());

        // RF08: Avaliação de Loja e de Entregador (nota inválida -> 400, válida -> 201, duplicada -> 409)
        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/loja", idPedido)
                        .header("X-User-Id", idCliente)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":6,\"comentario\":\"Inválida\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/loja", idPedido)
                        .header("X-User-Id", idCliente)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":5,\"comentario\":\"Excelente atendimento\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.nota").value(5));

        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/loja", idPedido)
                        .header("X-User-Id", idCliente)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":4,\"comentario\":\"Duplicada\"}"))
                .andExpect(status().isConflict());

        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/entregador", idPedido)
                        .header("X-User-Id", idCliente)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":5,\"comentario\":\"Entrega pontual\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.nota").value(5));

        mockMvc.perform(post("/api/pedidos/{id}/avaliacoes/entregador", idPedido)
                        .header("X-User-Id", idCliente)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nota\":3,\"comentario\":\"Duplicada\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void deveRetornarRelatoriosVisaoConsultasEEndpointsDeCheckout() throws Exception {
        Long idLojistaLoja1 = dsl.select(LOJA.ID_LOJISTA)
                .from(LOJA)
                .where(LOJA.ID_LOJA.eq(1L))
                .fetchOneInto(Long.class);
        assertThat(idLojistaLoja1).isNotNull();

        Long idClienteComEndereco = dsl.select(CLIENTE.ID_PESSOA)
                .from(CLIENTE)
                .where(CLIENTE.ID_ENDERECO_ATUAL.isNotNull())
                .and(CLIENTE.ID_PESSOA.ne(idLojistaLoja1))
                .limit(1)
                .fetchOneInto(Long.class);
        assertThat(idClienteComEndereco).isNotNull();

        // Exige X-User-Id nos endpoints protegidos
        mockMvc.perform(get("/api/pedidos")).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/pedidos/1")).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/comercio/lojas/resumo-financeiro")).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/comercio/lojas/1/relatorio")).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/comercio/consultas/5")).andExpect(status().isForbidden());
        mockMvc.perform(get("/api/comercio/checkout/clientes/{id}/enderecos", idClienteComEndereco))
                .andExpect(status().isForbidden());

        // Cliente comum não pode consultar resumo financeiro nem consultas estratégicas -> 403
        mockMvc.perform(get("/api/comercio/lojas/resumo-financeiro").header("X-User-Id", idClienteComEndereco))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/comercio/consultas/5").header("X-User-Id", idClienteComEndereco))
                .andExpect(status().isForbidden());
        // Terceiro não pode consultar endereços de outro cliente -> 403
        mockMvc.perform(get("/api/comercio/checkout/clientes/{id}/enderecos", idClienteComEndereco)
                        .header("X-User-Id", idLojistaLoja1))
                .andExpect(status().isForbidden());

        // Lojista vê apenas o resumo financeiro da própria loja e é bloqueado ao pedir outra loja
        mockMvc.perform(get("/api/comercio/lojas/resumo-financeiro").header("X-User-Id", idLojistaLoja1))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idLoja").value(1));
        mockMvc.perform(get("/api/comercio/lojas/resumo-financeiro")
                        .header("X-User-Id", idLojistaLoja1)
                        .param("idLoja", "2"))
                .andExpect(status().isForbidden());

        // Outro usuário não pode consultar relatório da loja 1 -> 403
        mockMvc.perform(get("/api/comercio/lojas/1/relatorio")
                        .header("X-User-Id", idClienteComEndereco)
                        .param("status", "concluido"))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/comercio/lojas/1/relatorio")
                        .header("X-User-Id", idLojistaLoja1)
                        .param("status", "concluido"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idLoja").value(1));

        // dataInicio > dataFim -> 400
        mockMvc.perform(get("/api/comercio/lojas/1/relatorio")
                        .header("X-User-Id", idLojistaLoja1)
                        .param("dataInicio", "2026-11-20T00:00:00Z")
                        .param("dataFim", "2026-11-01T00:00:00Z"))
                .andExpect(status().isBadRequest());

        // Lojista pode executar consultas C5–C12 escopadas à própria loja
        for (int n = 5; n <= 12; n++) {
            mockMvc.perform(get("/api/comercio/consultas/{numero}", n)
                            .header("X-User-Id", idLojistaLoja1))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.numero").value(n));
        }

        // Garante que consulta 7/11 retorna apenas linhas da loja 1 (ou vazio)
        String consulta11Body = mockMvc.perform(get("/api/comercio/consultas/11")
                        .header("X-User-Id", idLojistaLoja1))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        JsonNode linhas11 = objectMapper.readTree(consulta11Body).get("linhas");
        for (JsonNode linha : linhas11) {
            assertThat(linha.get("id_loja").asLong()).isEqualTo(1L);
        }

        String usuariosBody = mockMvc.perform(get("/api/comercio/checkout/usuarios"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idPessoa").exists())
                .andReturn().getResponse().getContentAsString();
        JsonNode usuariosJson = objectMapper.readTree(usuariosBody);
        for (JsonNode u : usuariosJson) {
            assertThat(u.get("administrador").asBoolean()).isFalse();
            assertThat(u.get("idPessoa").asLong()).isNotIn(7L, 15L, 19L, 23L, 37L);
        }

        mockMvc.perform(get("/api/comercio/checkout/lojas"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idLoja").exists());

        mockMvc.perform(get("/api/comercio/checkout/clientes/{id}/enderecos", idClienteComEndereco)
                        .header("X-User-Id", idClienteComEndereco))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idEndereco").exists());
    }

    @Test
    void deveTraduzirSqlStatesParaStatusHttpCorretos() {
        var r23505 = exceptionHandler.handleDatabaseError(new SQLException("duplicate key", "23505"));
        assertThat(r23505.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(r23505.getBody().sqlState()).isNull();

        var r23503 = exceptionHandler.handleDatabaseError(new SQLException("fk violation", "23503"));
        assertThat(r23503.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
        assertThat(r23503.getBody().sqlState()).isNull();

        var r23514Regra = exceptionHandler.handleDatabaseError(new SQLException("RN09 check violation", "23514"));
        assertThat(r23514Regra.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);

        var r23514Imutavel = exceptionHandler.handleDatabaseError(
                new SQLException("RR12: logradouro, número e CEP não podem ser alterados", "23514")
        );
        assertThat(r23514Imutavel.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(r23514Imutavel.getBody().message()).doesNotContain("RR12");
    }
}
