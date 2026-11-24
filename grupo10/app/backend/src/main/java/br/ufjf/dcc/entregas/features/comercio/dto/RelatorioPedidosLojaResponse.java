/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.math.BigDecimal;
import java.util.List;

public record RelatorioPedidosLojaResponse(
        Long idLoja,
        String nomeLoja,
        Long totalPedidosFiltrados,
        BigDecimal faturamentoFiltrado,
        BigDecimal ticketMedioFiltrado,
        List<PedidoResponse> pedidos
) {
}
