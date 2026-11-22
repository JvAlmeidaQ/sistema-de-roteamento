/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.service;

import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RequisicaoInvalidaException;
import br.ufjf.dcc.entregas.features.comercio.dto.ConsultaEstrategicaResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.PedidoResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.RelatorioPedidosLojaResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.ResumoFinanceiroLojaResponse;
import br.ufjf.dcc.entregas.features.comercio.repository.PedidoRepository;
import br.ufjf.dcc.entregas.features.comercio.repository.RelatorioComercioRepository;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class RelatorioComercioService {

    private final RelatorioComercioRepository relatorioRepository;
    private final PedidoRepository pedidoRepository;
    private final PedidoService pedidoService;

    public RelatorioComercioService(
            RelatorioComercioRepository relatorioRepository,
            PedidoRepository pedidoRepository,
            PedidoService pedidoService
    ) {
        this.relatorioRepository = relatorioRepository;
        this.pedidoRepository = pedidoRepository;
        this.pedidoService = pedidoService;
    }

    public List<ResumoFinanceiroLojaResponse> listarResumoFinanceiroLojas(Long idLoja) {
        return relatorioRepository.listarResumoFinanceiroLojas(idLoja);
    }

    public RelatorioPedidosLojaResponse gerarRelatorioLoja(
            Long idUsuarioAutenticado,
            Long idLoja,
            String statusLiteral,
            OffsetDateTime dataInicio,
            OffsetDateTime dataFim,
            int limit
    ) {
        if (dataInicio != null && dataFim != null && dataInicio.isAfter(dataFim)) {
            throw new RequisicaoInvalidaException("A data inicial não pode ser posterior à data final.");
        }

        var loja = pedidoRepository.buscarLoja(idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Loja " + idLoja + " não encontrada."));

        StatusPedido status = null;
        if (statusLiteral != null && !statusLiteral.isBlank()) {
            status = StatusPedido.lookupLiteral(statusLiteral);
            if (status == null) {
                throw new RequisicaoInvalidaException("Status de pedido inválido: " + statusLiteral);
            }
        }

        var agregados = relatorioRepository.calcularAgregadosPedidosLoja(idLoja, status, dataInicio, dataFim);
        List<PedidoResponse> pedidos = pedidoService.listarPedidos(
                idUsuarioAutenticado, idLoja, null, statusLiteral, dataInicio, dataFim, limit
        );

        return new RelatorioPedidosLojaResponse(
                loja.getIdLoja(),
                loja.getNome(),
                agregados.totalPedidos(),
                agregados.faturamentoTotal().setScale(2, RoundingMode.HALF_UP),
                agregados.ticketMedio().setScale(2, RoundingMode.HALF_UP),
                pedidos
        );
    }

    public ConsultaEstrategicaResponse executarConsultaEstrategica(int numero) {
        if (numero < 5 || numero > 12) {
            throw new RequisicaoInvalidaException("As consultas do subdomínio Comércio e Finanças vão de 5 a 12.");
        }
        return relatorioRepository.executarConsultaEstrategica(numero);
    }
}
