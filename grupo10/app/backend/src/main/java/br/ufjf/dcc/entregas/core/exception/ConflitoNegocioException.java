/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Exceções
 */
package br.ufjf.dcc.entregas.core.exception;

public class ConflitoNegocioException extends RuntimeException {
    public ConflitoNegocioException(String message) {
        super(message);
    }
}
