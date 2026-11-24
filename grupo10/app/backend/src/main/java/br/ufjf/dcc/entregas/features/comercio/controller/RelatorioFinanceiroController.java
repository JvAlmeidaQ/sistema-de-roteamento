/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.controller;

import br.ufjf.dcc.entregas.features.comercio.dto.ConsultaEstrategicaResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.RelatorioPedidosLojaResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.ResumoFinanceiroLojaResponse;
import br.ufjf.dcc.entregas.features.comercio.service.RelatorioComercioService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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

@Validated
@RestController
@RequestMapping("/api/comercio")
public class RelatorioFinanceiroController {

    private final RelatorioComercioService relatorioService;

    public RelatorioFinanceiroController(RelatorioComercioService relatorioService) {
        this.relatorioService = relatorioService;
    }

    @GetMapping("/lojas/resumo-financeiro")
    public List<ResumoFinanceiroLojaResponse> listarResumoFinanceiro(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @RequestParam(required = false) @Positive Long idLoja
    ) {
        return relatorioService.listarResumoFinanceiroLojas(idUsuarioAutenticado, idLoja);
    }

    @GetMapping("/lojas/{idLoja}/relatorio")
    public RelatorioPedidosLojaResponse relatorioLoja(
            @RequestHeader(value = "X-User-Id", required = false) @Positive Long idUsuarioAutenticado,
            @PathVariable @Positive Long idLoja,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime dataInicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime dataFim,
            @RequestParam(defaultValue = "25") @Min(1) @Max(200) int limit
    ) {
        return relatorioService.gerarRelatorioLoja(idUsuarioAutenticado, idLoja, status, dataInicio, dataFim, limit);
    }

    @GetMapping("/consultas/{numero}")
    public ConsultaEstrategicaResponse executarConsultaEstrategica(
            @RequestHeader(value = "X-User-Id", required = false) Long idUsuarioAutenticado,
            @PathVariable @Min(5) @Max(12) int numero
    ) {
        return relatorioService.executarConsultaEstrategica(idUsuarioAutenticado, numero);
    }
}
