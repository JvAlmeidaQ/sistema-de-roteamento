/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística
 */
package br.ufjf.dcc.entregas.features.logistica.controller;

import br.ufjf.dcc.entregas.features.logistica.dto.AtualizarStatusEntregaRequest;
import br.ufjf.dcc.entregas.features.logistica.dto.EntregadorSessaoResponse;
import br.ufjf.dcc.entregas.features.logistica.dto.PainelEntregadorResponse;
import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse;
import br.ufjf.dcc.entregas.features.logistica.service.EntregaService;
import br.ufjf.dcc.entregas.features.logistica.service.RastreioService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
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

import java.util.List;

@Validated
@RestController
@RequestMapping("/api/logistica")
public class LogisticaController {

    private final EntregaService entregaService;
    private final RastreioService rastreioService;

    public LogisticaController(EntregaService entregaService, RastreioService rastreioService) {
        this.entregaService = entregaService;
        this.rastreioService = rastreioService;
    }

    @GetMapping("/sessao/entregadores")
    public ResponseEntity<List<EntregadorSessaoResponse>> listarEntregadoresSessao() {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(entregaService.listarEntregadoresSessao());
    }

    @GetMapping("/pedidos/{idPedido}/rastreio")
    public ResponseEntity<RastreioPedidoResponse> consultarRastreio(
            @RequestHeader("X-User-Id") @Positive long idUsuario,
            @PathVariable @Positive long idPedido
    ) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(rastreioService.consultar(idPedido, idUsuario));
    }

    @GetMapping("/painel")
    public ResponseEntity<PainelEntregadorResponse> consultarPainel(
            @RequestHeader("X-User-Id") @Positive long idEntregador,
            @RequestParam(defaultValue = "1") @Min(1) @Max(100_000) int paginaDisponiveis,
            @RequestParam(defaultValue = "1") @Min(1) @Max(100_000) int paginaEncerradas
    ) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(entregaService.consultarPainel(idEntregador, paginaDisponiveis, paginaEncerradas));
    }

    @PostMapping("/entregas/{idEntrega}/assumir")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void assumirEntrega(
            @RequestHeader("X-User-Id") @Positive long idEntregador,
            @PathVariable @Positive long idEntrega
    ) {
        entregaService.assumirEntrega(idEntregador, idEntrega);
    }

    @PatchMapping("/entregas/{idEntrega}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void atualizarStatus(
            @RequestHeader("X-User-Id") @Positive long idEntregador,
            @PathVariable @Positive long idEntrega,
            @Valid @RequestBody AtualizarStatusEntregaRequest request
    ) {
        entregaService.atualizarStatus(idEntregador, idEntrega, request.novoStatus());
    }
}
