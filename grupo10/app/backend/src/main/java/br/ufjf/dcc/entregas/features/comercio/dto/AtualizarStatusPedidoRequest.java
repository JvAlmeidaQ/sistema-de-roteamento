/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import jakarta.validation.constraints.NotBlank;

public record AtualizarStatusPedidoRequest(
        @NotBlank(message = "O novo status do pedido é obrigatório.")
        String novoStatus
) {
}
