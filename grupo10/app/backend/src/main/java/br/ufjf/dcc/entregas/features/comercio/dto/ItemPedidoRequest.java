/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record ItemPedidoRequest(
        @NotNull(message = "O identificador do produto é obrigatório.")
        @Positive(message = "O identificador do produto deve ser positivo.")
        Long idProduto,

        @NotNull(message = "A quantidade é obrigatória.")
        @Positive(message = "A quantidade do item deve ser maior que zero.")
        Integer quantidade
) {
}
