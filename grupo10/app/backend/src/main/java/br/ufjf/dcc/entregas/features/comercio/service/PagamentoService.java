/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.ConflitoNegocioException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RegraNegocioException;
import br.ufjf.dcc.entregas.features.comercio.dto.DivisaoPagamentoResponse;
import br.ufjf.dcc.entregas.features.comercio.repository.DivisaoPagamentoRepository;
import br.ufjf.dcc.entregas.features.comercio.repository.PedidoRepository;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Calcula e persiste a divisão financeira do pedido (RF09, RN05, RN13, RR08, RR10).
 *
 * Integração desacoplada com Logística: a transição final de Entrega para 'entregue'
 * (que atualiza Pedido para 'concluido') é responsabilidade do subdomínio de Logística.
 * Este serviço está preparado para ser invocado pelo endpoint REST ou por evento de conclusão
 * assim que o pedido estiver com status 'concluido' e entrega 'entregue'.
 */
@Service
@Transactional(readOnly = true)
public class PagamentoService {

    private final PedidoRepository pedidoRepository;
    private final DivisaoPagamentoRepository divisaoPagamentoRepository;
    private final BigDecimal percentualRetencaoSubtotal;

    public PagamentoService(
            PedidoRepository pedidoRepository,
            DivisaoPagamentoRepository divisaoPagamentoRepository,
            @Value("${app.financeiro.percentual-retencao-subtotal:0.15}") BigDecimal percentualRetencaoSubtotal
    ) {
        this.pedidoRepository = pedidoRepository;
        this.divisaoPagamentoRepository = divisaoPagamentoRepository;
        this.percentualRetencaoSubtotal = percentualRetencaoSubtotal;
    }

    @Transactional
    public DivisaoPagamentoResponse calcularERegistrarSplit(Long idUsuarioAutenticado, Long idPedido) {
        var pedido = pedidoRepository.buscarPedidoPorIdForUpdate(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));

        if (idUsuarioAutenticado != null) {
            validarAutorizacaoAcesso(idUsuarioAutenticado, idPedido);
        }

        if (divisaoPagamentoRepository.buscarPorPedido(idPedido).isPresent()) {
            throw new ConflitoNegocioException("[RF09] A divisão de pagamento do pedido " + idPedido + " já foi registrada.");
        }

        if (pedido.getStatus() != StatusPedido.concluido || !pedidoRepository.entregaEstaConcluida(idPedido)) {
            throw new RegraNegocioException(
                    "[RN13/RR08] A divisão de pagamento só pode ser registrada após o pedido estar concluído com entrega realizada ('entregue')."
            );
        }

        BigDecimal valorTotal = pedido.getValorTotal().setScale(2, RoundingMode.HALF_UP);
        BigDecimal comissaoEntregador = pedido.getTaxaEntrega().setScale(2, RoundingMode.HALF_UP);
        BigDecimal fatorLoja = BigDecimal.ONE.subtract(percentualRetencaoSubtotal);
        BigDecimal parcelaLoja = pedido.getSubtotal().multiply(fatorLoja).setScale(2, RoundingMode.HALF_UP);
        BigDecimal taxaPlataforma = valorTotal.subtract(parcelaLoja).subtract(comissaoEntregador).setScale(2, RoundingMode.HALF_UP);

        return divisaoPagamentoRepository.inserir(
                idPedido,
                valorTotal,
                parcelaLoja,
                comissaoEntregador,
                taxaPlataforma
        );
    }

    public DivisaoPagamentoResponse buscarPorPedido(Long idUsuarioAutenticado, Long idPedido) {
        if (idUsuarioAutenticado != null) {
            validarAutorizacaoAcesso(idUsuarioAutenticado, idPedido);
        }
        return divisaoPagamentoRepository.buscarPorPedido(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Divisão de pagamento não encontrada para o pedido " + idPedido + "."));
    }

    private void validarAutorizacaoAcesso(Long idUsuarioAutenticado, Long idPedido) {
        var detalhes = pedidoRepository.buscarDetalhesPedido(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));
        boolean ehClienteDono = detalhes.idCliente().equals(idUsuarioAutenticado);
        boolean ehLojistaDono = detalhes.idLojista().equals(idUsuarioAutenticado);
        if (!ehClienteDono && !ehLojistaDono) {
            throw new AcessoNegadoException("Acesso negado à divisão financeira deste pedido.");
        }
    }
}
