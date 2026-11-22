/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Exceções
 */
package br.ufjf.dcc.entregas.core.exception;

import java.time.OffsetDateTime;
import java.util.List;

public record ApiErrorResponse(
        int status,
        String error,
        String message,
        String sqlState,
        OffsetDateTime timestamp,
        List<String> details
) {
    public ApiErrorResponse(int status, String error, String message, String sqlState, List<String> details) {
        this(status, error, message, sqlState, OffsetDateTime.now(), details);
    }
}
