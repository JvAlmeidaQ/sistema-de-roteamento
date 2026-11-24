/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: RF05, RF06, RF10 (rastreabilidade cronológica e consulta de SLA)
 */
package br.ufjf.dcc.entregas.features.auditoria.controller;

import br.ufjf.dcc.entregas.features.auditoria.dto.EventoHistoricoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.LinhaTempoPedidoResponse;
import br.ufjf.dcc.entregas.features.auditoria.dto.SlaEntregaResponse;
import br.ufjf.dcc.entregas.features.auditoria.service.AuditoriaService;
import jakarta.validation.constraints.Positive;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/auditoria")
@Validated
public class AuditoriaController {

    private final AuditoriaService auditoriaService;

    public AuditoriaController(AuditoriaService auditoriaService) {
        this.auditoriaService = auditoriaService;
    }

    @GetMapping("/pedidos/{idPedido}/historico")
    public List<EventoHistoricoResponse> listarHistoricoPedido(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuario,
            @PathVariable @Positive Long idPedido
    ) {
        return auditoriaService.consultarHistoricoPedido(idPedido, idUsuario);
    }

    @GetMapping("/entregas/{idEntrega}/historico")
    public List<EventoHistoricoResponse> listarHistoricoEntrega(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuario,
            @PathVariable @Positive Long idEntrega
    ) {
        return auditoriaService.consultarHistoricoEntrega(idEntrega, idUsuario);
    }

    @GetMapping("/pedidos/{idPedido}/linha-tempo")
    public List<LinhaTempoPedidoResponse> listarLinhaTempoPedido(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuario,
            @PathVariable @Positive Long idPedido
    ) {
        return auditoriaService.consultarLinhaTempoPedido(idPedido, idUsuario);
    }

    @GetMapping("/sla/entregas")
    public List<SlaEntregaResponse> listarSlaEntregas(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuario,
            @RequestParam(required = false) @Positive Long idLoja,
            @RequestParam(required = false) Boolean apenasAtrasadas,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime inicio,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime fim
    ) {
        return auditoriaService.consultarSlaEntregas(idLoja, apenasAtrasadas, inicio, fim, idUsuario);
    }
}