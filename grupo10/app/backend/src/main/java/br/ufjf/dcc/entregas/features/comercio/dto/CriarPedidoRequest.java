/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CriarPedidoRequest(
        @NotNull(message = "A loja é obrigatória.")
        @Positive(message = "O identificador da loja deve ser positivo.")
        Long idLoja,

        @NotNull(message = "O endereço de entrega é obrigatório.")
        @Positive(message = "O identificador do endereço deve ser positivo.")
        Long idEndereco,

        @NotBlank(message = "A forma de pagamento é obrigatória.")
        String formaPagamento,

        @Size(max = 255, message = "A observação de entrega deve ter no máximo 255 caracteres.")
        String observacaoEntrega,

        @NotEmpty(message = "O pedido deve conter ao menos um item.")
        @Size(max = 100, message = "O pedido pode conter no máximo 100 itens distintos.")
        List<@Valid ItemPedidoRequest> itens
) {
}
