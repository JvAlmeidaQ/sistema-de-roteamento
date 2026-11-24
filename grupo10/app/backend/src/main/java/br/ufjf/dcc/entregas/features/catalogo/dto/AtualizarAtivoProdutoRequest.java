package br.ufjf.dcc.entregas.features.catalogo.dto;

import jakarta.validation.constraints.NotNull;

public record AtualizarAtivoProdutoRequest(
        @NotNull(message = "O campo ativo é obrigatório.")
        Boolean ativo
) {}
