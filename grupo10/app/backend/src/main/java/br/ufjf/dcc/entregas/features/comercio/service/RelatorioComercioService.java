/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RequisicaoInvalidaException;
import br.ufjf.dcc.entregas.core.security.AdminAccessService;
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
    private final AdminAccessService adminAccessService;

    public RelatorioComercioService(
            RelatorioComercioRepository relatorioRepository,
            PedidoRepository pedidoRepository,
            PedidoService pedidoService,
            AdminAccessService adminAccessService
    ) {
        this.relatorioRepository = relatorioRepository;
        this.pedidoRepository = pedidoRepository;
        this.pedidoService = pedidoService;
        this.adminAccessService = adminAccessService;
    }

    public List<ResumoFinanceiroLojaResponse> listarResumoFinanceiroLojas(Long idUsuarioAutenticado, Long idLoja) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);
        if (adminAccessService.isAdmin(idUsuarioAutenticado)) {
            return relatorioRepository.listarResumoFinanceiroLojas(idLoja);
        }

        List<Long> idsLojasDoLojista = relatorioRepository.buscarIdsLojasDoLojista(idUsuarioAutenticado);
        if (idsLojasDoLojista.isEmpty()) {
            throw new AcessoNegadoException("Acesso restrito a lojistas ou administradores.");
        }
        if (idLoja != null) {
            if (!idsLojasDoLojista.contains(idLoja)) {
                throw new AcessoNegadoException("Você só pode consultar o resumo financeiro da sua própria loja.");
            }
            return relatorioRepository.listarResumoFinanceiroLojas(idLoja);
        }
        return relatorioRepository.listarResumoFinanceiroLojasPorIds(idsLojasDoLojista);
    }

    public RelatorioPedidosLojaResponse gerarRelatorioLoja(
            Long idUsuarioAutenticado,
            Long idLoja,
            String statusLiteral,
            OffsetDateTime dataInicio,
            OffsetDateTime dataFim,
            int limit
    ) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);

        if (dataInicio != null && dataFim != null && dataInicio.isAfter(dataFim)) {
            throw new RequisicaoInvalidaException("A data inicial não pode ser posterior à data final.");
        }

        var loja = pedidoRepository.buscarLoja(idLoja)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Loja não encontrada."));

        if (!adminAccessService.isAdmin(idUsuarioAutenticado) && !loja.getIdLojista().equals(idUsuarioAutenticado)) {
            throw new AcessoNegadoException("Você só pode consultar relatórios da sua própria loja.");
        }

        StatusPedido status = null;
        if (statusLiteral != null && !statusLiteral.isBlank()) {
            status = StatusPedido.lookupLiteral(statusLiteral);
            if (status == null) {
                throw new RequisicaoInvalidaException("Status de pedido inválido.");
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

    public ConsultaEstrategicaResponse executarConsultaEstrategica(Long idUsuarioAutenticado, int numero) {
        adminAccessService.exigirIdentificacao(idUsuarioAutenticado);
        if (numero < 5 || numero > 12) {
            throw new RequisicaoInvalidaException("Consulta gerencial inválida.");
        }

        if (adminAccessService.isAdmin(idUsuarioAutenticado)) {
            return relatorioRepository.executarConsultaEstrategica(numero, null);
        }

        List<Long> idsLojasDoLojista = relatorioRepository.buscarIdsLojasDoLojista(idUsuarioAutenticado);
        if (idsLojasDoLojista.isEmpty()) {
            throw new AcessoNegadoException("Acesso restrito a lojistas ou administradores.");
        }
        return relatorioRepository.executarConsultaEstrategica(numero, idsLojasDoLojista.getFirst());
    }
}
