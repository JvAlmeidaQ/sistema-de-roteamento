/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record DivisaoPagamentoResponse(
        Long idPedido,
        BigDecimal valorTotal,
        BigDecimal parcelaLoja,
        BigDecimal comissaoEntregador,
        BigDecimal taxaPlataforma,
        OffsetDateTime calculadaEm
) {
}
