package br.ufjf.dcc.entregas.features.catalogo.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record AtualizarLojaRequest(
        @NotBlank(message = "Telefone é obrigatório.")
        @Size(max = 20, message = "Telefone não pode exceder 20 caracteres.")
        String telefone,

        @Size(max = 80, message = "Complemento não pode exceder 80 caracteres.")
        String complementoEndereco,

        @NotNull(message = "Tempo de entrega estimado é obrigatório.")
        @Positive(message = "Tempo de entrega estimado deve ser maior que zero.")
        Integer tempoEntregaEstimado,

        @NotNull(message = "Taxa de entrega é obrigatória.")
        @PositiveOrZero(message = "Taxa de entrega não pode ser negativa.")
        BigDecimal taxaEntrega
) {}
