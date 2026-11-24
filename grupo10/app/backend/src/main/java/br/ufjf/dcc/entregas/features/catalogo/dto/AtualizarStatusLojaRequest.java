package br.ufjf.dcc.entregas.features.catalogo.dto;

import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import jakarta.validation.constraints.NotNull;

public record AtualizarStatusLojaRequest(
        @NotNull(message = "Status de funcionamento é obrigatório.")
        StatusFuncionamento statusFuncionamento
) {}
