/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public record PedidoResponse(
        Long idPedido,
        Long idLoja,
        String nomeLoja,
        Long idCliente,
        String nomeCliente,
        Long idEndereco,
        String resumoEndereco,
        String complementoEntrega,
        String referenciaEntrega,
        String observacaoEntrega,
        String status,
        String statusEntrega,
        OffsetDateTime dataPedido,
        String formaPagamento,
        BigDecimal subtotal,
        BigDecimal taxaEntrega,
        BigDecimal taxaServico,
        BigDecimal valorTotal,
        List<ItemPedidoResponse> itens,
        DivisaoPagamentoResponse divisaoPagamento,
        AvaliacaoResponse avaliacaoLoja,
        AvaliacaoResponse avaliacaoEntregador
) {
}
