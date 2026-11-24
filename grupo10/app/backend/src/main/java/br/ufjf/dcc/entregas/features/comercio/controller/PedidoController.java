/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.controller;

import br.ufjf.dcc.entregas.features.comercio.dto.AtualizarStatusPedidoRequest;
import br.ufjf.dcc.entregas.features.comercio.dto.CriarPedidoRequest;
import br.ufjf.dcc.entregas.features.comercio.dto.DivisaoPagamentoResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.PedidoResponse;
import br.ufjf.dcc.entregas.features.comercio.service.PagamentoService;
import br.ufjf.dcc.entregas.features.comercio.service.PedidoService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.List;

@Validated
@RestController
@RequestMapping("/api/pedidos")
public class PedidoController {

    private final PedidoService pedidoService;
    private final PagamentoService pagamentoService;

    public PedidoController(PedidoService pedidoService, PagamentoService pagamentoService) {
        this.pedidoService = pedidoService;
        this.pagamentoService = pagamentoService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PedidoResponse criar(
            @RequestHeader("X-User-Id") @Positive Long idCliente,
            @Valid @RequestBody CriarPedidoRequest request
    ) {
        return pedidoService.criarPedido(idCliente, request);
    }

    @GetMapping
    public List<PedidoResponse> listar(
            @RequestHeader(value = "X-User-Id", required = false) @Positive Long idUsuarioAutenticado,
            @RequestParam(required = false) @Positive Long idLoja,
            @RequestParam(required = false) @Positive Long idCliente,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime dataInicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime dataFim,
            @RequestParam(defaultValue = "25") @Min(1) @Max(200) int limit
    ) {
        return pedidoService.listarPedidos(
                idUsuarioAutenticado, idLoja, idCliente, status, dataInicio, dataFim, limit
        );
    }

    @GetMapping("/{idPedido}")
    public PedidoResponse buscarPorId(
            @RequestHeader(value = "X-User-Id", required = false) @Positive Long idUsuarioAutenticado,
            @PathVariable @Positive Long idPedido
    ) {
        return pedidoService.buscarPorId(idUsuarioAutenticado, idPedido);
    }

    @PatchMapping("/{idPedido}/status")
    public PedidoResponse atualizarStatus(
            @RequestHeader("X-User-Id") @Positive Long idUsuarioAutenticado,
            @PathVariable @Positive Long idPedido,
            @Valid @RequestBody AtualizarStatusPedidoRequest request
    ) {
        return pedidoService.atualizarStatus(idUsuarioAutenticado, idPedido, request.novoStatus());
    }

    @PostMapping("/{idPedido}/divisao-pagamento")
    @ResponseStatus(HttpStatus.CREATED)
    public DivisaoPagamentoResponse calcularSplit(
            @RequestHeader(value = "X-User-Id", required = false) @Positive Long idUsuarioAutenticado,
            @PathVariable @Positive Long idPedido
    ) {
        return pagamentoService.calcularERegistrarSplit(idUsuarioAutenticado, idPedido);
    }

    @GetMapping("/{idPedido}/divisao-pagamento")
    public DivisaoPagamentoResponse buscarSplit(
            @RequestHeader(value = "X-User-Id", required = false) @Positive Long idUsuarioAutenticado,
            @PathVariable @Positive Long idPedido
    ) {
        return pagamentoService.buscarPorPedido(idUsuarioAutenticado, idPedido);
    }
}
