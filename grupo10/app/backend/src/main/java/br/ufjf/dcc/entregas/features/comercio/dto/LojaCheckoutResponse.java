/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: DTO estritamente de leitura para seleção de loja e catálogo no checkout (RF02).
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.math.BigDecimal;
import java.util.List;

public record LojaCheckoutResponse(
        Long idLoja,
        Long idLojista,
        String nome,
        String cnpj,
        String statusFuncionamento,
        Integer tempoEntregaEstimado,
        BigDecimal taxaEntrega,
        List<ProdutoCheckoutResponse> produtos
) {
}
