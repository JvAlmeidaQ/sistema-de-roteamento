/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Exceções
 */
package br.ufjf.dcc.entregas.core.exception;

import jakarta.validation.ConstraintViolationException;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.sql.SQLException;
import java.util.List;

/**
 * Traduz exceções de domínio, Bean Validation e códigos SQLSTATE do PostgreSQL
 * para respostas HTTP padronizadas sem expor detalhes internos de infraestrutura.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(RegraNegocioException.class)
    public ResponseEntity<ApiErrorResponse> handleRegraNegocio(RegraNegocioException ex) {
        return build(HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage(), null, List.of());
    }

    @ExceptionHandler(ConflitoNegocioException.class)
    public ResponseEntity<ApiErrorResponse> handleConflito(ConflitoNegocioException ex) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), null, List.of());
    }

    @ExceptionHandler(AcessoNegadoException.class)
    public ResponseEntity<ApiErrorResponse> handleAcessoNegado(AcessoNegadoException ex) {
        return build(HttpStatus.FORBIDDEN, ex.getMessage(), null, List.of());
    }

    @ExceptionHandler(RecursoNaoEncontradoException.class)
    public ResponseEntity<ApiErrorResponse> handleNaoEncontrado(RecursoNaoEncontradoException ex) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), null, List.of());
    }

    @ExceptionHandler(RequisicaoInvalidaException.class)
    public ResponseEntity<ApiErrorResponse> handleRequisicaoInvalida(RequisicaoInvalidaException ex) {
        return build(HttpStatus.BAD_REQUEST, ex.getMessage(), null, List.of());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(err -> err.getField() + ": " + err.getDefaultMessage())
                .toList();
        return build(HttpStatus.BAD_REQUEST, "Dados de entrada inválidos.", null, details);
    }

    @ExceptionHandler(BindException.class)
    public ResponseEntity<ApiErrorResponse> handleBind(BindException ex) {
        List<String> details = ex.getBindingResult().getFieldErrors().stream()
                .map(err -> err.getField() + ": " + err.getDefaultMessage())
                .toList();
        return build(HttpStatus.BAD_REQUEST, "Parâmetros de requisição inválidos.", null, details);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiErrorResponse> handleConstraintViolation(ConstraintViolationException ex) {
        List<String> details = ex.getConstraintViolations().stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .toList();
        return build(HttpStatus.BAD_REQUEST, "Parâmetros de requisição inválidos.", null, details);
    }

    @ExceptionHandler({
            MissingRequestHeaderException.class,
            MethodArgumentTypeMismatchException.class,
            HttpMessageNotReadableException.class
    })
    public ResponseEntity<ApiErrorResponse> handleBadRequest(Exception ex) {
        String message = switch (ex) {
            case MissingRequestHeaderException mrh ->
                    "Cabeçalho obrigatório ausente: " + mrh.getHeaderName();
            case MethodArgumentTypeMismatchException matm ->
                    "Tipo de parâmetro inválido para '" + matm.getName() + "'.";
            case HttpMessageNotReadableException ignored ->
                    "Corpo da requisição malformado ou ilegível.";
            default -> "Requisição inválida.";
        };
        return build(HttpStatus.BAD_REQUEST, message, null, List.of());
    }

    @ExceptionHandler({DataAccessException.class, SQLException.class})
    public ResponseEntity<ApiErrorResponse> handleDatabaseError(Exception ex) {
        SQLException sqlEx = findSqlException(ex);
        if (sqlEx == null) {
            return build(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno de persistência.", null, List.of());
        }

        String sqlState = sqlEx.getSQLState();
        String rawMessage = sqlEx.getMessage();
        HttpStatus status = mapSqlState(sqlState, rawMessage);
        String sanitizedMessage = extractPostgresMessage(sqlEx, status);

        return build(status, sanitizedMessage, sqlState, List.of());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleUnexpected(Exception ignored) {
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "Ocorreu um erro interno inesperado.", null, List.of());
    }

    private HttpStatus mapSqlState(String sqlState, String message) {
        if (sqlState == null) {
            return HttpStatus.INTERNAL_SERVER_ERROR;
        }
        return switch (sqlState) {
            case "23505", "23001" -> HttpStatus.CONFLICT;
            case "23503" -> HttpStatus.UNPROCESSABLE_ENTITY;
            case "23514", "P0001" -> isImutabilidade(message) ? HttpStatus.CONFLICT : HttpStatus.UNPROCESSABLE_ENTITY;
            case "23502" -> HttpStatus.BAD_REQUEST;
            default -> HttpStatus.INTERNAL_SERVER_ERROR;
        };
    }

    private boolean isImutabilidade(String message) {
        if (message == null) {
            return false;
        }
        String upper = message.toUpperCase();
        return upper.contains("RN08")
                || upper.contains("RR11")
                || upper.contains("RR12")
                || upper.contains("IMUT");
    }

    private SQLException findSqlException(Throwable ex) {
        Throwable current = ex;
        while (current != null) {
            if (current instanceof SQLException sqlEx) {
                return sqlEx;
            }
            current = current.getCause();
        }
        return null;
    }

    private String extractPostgresMessage(SQLException sqlEx, HttpStatus status) {
        if (status == HttpStatus.INTERNAL_SERVER_ERROR) {
            return "Erro interno de persistência no banco de dados.";
        }
        String raw = sqlEx.getMessage();
        if (raw == null || raw.isBlank()) {
            return "Violação de integridade no banco de dados.";
        }
        int whereIdx = raw.indexOf("\n  Where:");
        String clean = whereIdx > 0 ? raw.substring(0, whereIdx) : raw;
        int detailIdx = clean.indexOf("\n  Detail:");
        if (detailIdx > 0) {
            clean = clean.substring(0, detailIdx);
        }
        return clean.replaceFirst("^ERROR:\\s*", "").trim();
    }

    private ResponseEntity<ApiErrorResponse> build(
            HttpStatus status, String message, String sqlState, List<String> details) {
        ApiErrorResponse body = new ApiErrorResponse(
                status.value(),
                status.getReasonPhrase(),
                message,
                sqlState,
                details
        );
        return ResponseEntity.status(status).body(body);
    }
}
