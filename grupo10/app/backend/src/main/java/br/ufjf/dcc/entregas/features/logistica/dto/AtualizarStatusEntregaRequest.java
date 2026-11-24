/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record AtualizarStatusEntregaRequest(
        @NotBlank
        @Pattern(regexp = "a_caminho|entregue", message = "deve ser a_caminho ou entregue")
        String novoStatus
) {}
