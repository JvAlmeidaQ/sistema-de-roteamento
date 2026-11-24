/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Camada Transversal: Core / Exceções
 */
package br.ufjf.dcc.entregas.core.exception;

import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

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
                .map(v -> v.getMessage())
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
            case MissingRequestHeaderException mrh -> {
                log.warn("Cabeçalho obrigatório ausente: {}", mrh.getHeaderName());
                yield "X-User-Id".equalsIgnoreCase(mrh.getHeaderName())
                        ? "Identificação do usuário não informada."
                        : "Informação obrigatória ausente na requisição.";
            }
            case MethodArgumentTypeMismatchException matm ->
                    "Valor inválido para o parâmetro informado.";
            case HttpMessageNotReadableException ignored ->
                    "Os dados enviados estão em formato inválido.";
            default -> "Requisição inválida.";
        };
        return build(HttpStatus.BAD_REQUEST, message, null, List.of());
    }

    @ExceptionHandler({DataAccessException.class, SQLException.class})
    public ResponseEntity<ApiErrorResponse> handleDatabaseError(Exception ex) {
        SQLException sqlEx = findSqlException(ex);
        if (sqlEx == null) {
            log.error("Erro de persistência sem SQLException associada", ex);
            return build(HttpStatus.INTERNAL_SERVER_ERROR, "Não foi possível concluir a operação no momento.", null, List.of());
        }

        String sqlState = sqlEx.getSQLState();
        String rawMessage = sqlEx.getMessage();
        HttpStatus status = mapSqlState(sqlState, rawMessage);
        if (status.is5xxServerError()) {
            log.error("Erro interno de banco de dados (SQLSTATE={}): {}", sqlState, rawMessage, ex);
        } else {
            log.warn("Restrição de banco de dados acionada (SQLSTATE={}, status={}): {}", sqlState, status.value(), rawMessage);
        }
        String friendlyMessage = traduzirMensagemBanco(sqlState, rawMessage, status);

        return build(status, friendlyMessage, null, List.of());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleUnexpected(Exception ex) {
        log.error("Erro interno inesperado", ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "Ocorreu um erro inesperado. Tente novamente.", null, List.of());
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

    private String traduzirMensagemBanco(String sqlState, String rawMessage, HttpStatus status) {
        if (status == HttpStatus.INTERNAL_SERVER_ERROR) {
            return "Não foi possível concluir a operação no momento. Tente novamente.";
        }
        String upper = rawMessage == null ? "" : rawMessage.toUpperCase();
        if ("23505".equals(sqlState)) {
            if (upper.contains("CPF")) return "Já existe uma pessoa cadastrada com este CPF.";
            if (upper.contains("EMAIL")) return "Já existe uma pessoa cadastrada com este e-mail.";
            if (upper.contains("CNPJ")) return "Já existe uma loja cadastrada com este CNPJ.";
            return "Já existe um registro com os dados informados.";
        }
        if ("23503".equals(sqlState)) {
            return "Não foi possível concluir a operação porque há referência a um registro inexistente ou em uso.";
        }
        if ("23502".equals(sqlState)) {
            return "Preencha todos os campos obrigatórios antes de continuar.";
        }
        if ("23001".equals(sqlState)) {
            return "Não é possível remover este registro enquanto houver dados vinculados.";
        }
        if (upper.contains("RN02")) return "Você já atingiu o limite de 2 entregas na rota atual.";
        if (upper.contains("RN03")) return "Finalize a entrega em atraso antes de assumir outra.";
        if (upper.contains("RN08") || upper.contains("RR11")) return "O histórico de movimentações não pode ser alterado.";
        if (upper.contains("RR12")) return "Os dados principais de um endereço salvo não podem ser alterados.";
        if (upper.contains("RR03")) return "O endereço selecionado não pertence à sua conta.";
        if (upper.contains("RR06")) return "Esta alteração de status não é permitida no momento.";
        if (upper.contains("RN01") || upper.contains("RR04")) return "A loja ou o produto selecionado não está disponível para pedidos.";
        if (upper.contains("RN13") || upper.contains("RR08")) return "Esta ação só fica disponível após a conclusão da entrega.";
        if (upper.contains("RN05")) return "Os valores da divisão financeira não conferem com o total do pedido.";
        return "Não foi possível concluir a operação devido às regras do sistema.";
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
