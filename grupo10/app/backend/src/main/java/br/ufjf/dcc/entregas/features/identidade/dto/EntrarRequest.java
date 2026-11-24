/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 */
package br.ufjf.dcc.entregas.features.identidade.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EntrarRequest(
        @NotBlank(message = "Informe o e-mail ou CPF cadastrado.")
        @Size(max = 255, message = "Identificador muito longo.")
        String identificador
) {}
