/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: DTO estritamente de leitura para exibição de produtos no checkout (RF02).
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.math.BigDecimal;

public record ProdutoCheckoutResponse(
        Long idProduto,
        Long idLoja,
        String nome,
        String descricao,
        BigDecimal preco,
        boolean ativo
) {
}
