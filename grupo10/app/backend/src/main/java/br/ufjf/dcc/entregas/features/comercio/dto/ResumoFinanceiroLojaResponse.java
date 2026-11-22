/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.math.BigDecimal;

public record ResumoFinanceiroLojaResponse(
        Long idLoja,
        String nomeLoja,
        Long pedidosConcluidos,
        BigDecimal faturamentoBruto,
        BigDecimal repasseTotalLoja,
        BigDecimal totalComissaoEntregadores,
        BigDecimal receitaPlataforma,
        BigDecimal mediaAvaliacaoLoja
) {
}
