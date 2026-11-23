package br.ufjf.dcc.entregas.features.catalogo.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;

public record CriarProdutoRequest(
        @NotBlank(message = "Nome do produto é obrigatório.")
        @Size(max = 120, message = "Nome do produto não pode exceder 120 caracteres.")
        String nome,

        String descricao,

        @NotNull(message = "Preço é obrigatório.")
        @Positive(message = "Preço deve ser estritamente maior que zero.")
        BigDecimal preco,

        @NotEmpty(message = "O produto deve estar associado a pelo menos uma categoria.")
        List<Long> categoriasIds
) {}
