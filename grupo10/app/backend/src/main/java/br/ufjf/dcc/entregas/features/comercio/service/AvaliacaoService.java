/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.ConflitoNegocioException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.core.exception.RegraNegocioException;
import br.ufjf.dcc.entregas.features.comercio.dto.AvaliacaoRequest;
import br.ufjf.dcc.entregas.features.comercio.dto.AvaliacaoResponse;
import br.ufjf.dcc.entregas.features.comercio.repository.AvaliacaoRepository;
import br.ufjf.dcc.entregas.features.comercio.repository.PedidoRepository;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AvaliacaoService {

    private final PedidoRepository pedidoRepository;
    private final AvaliacaoRepository avaliacaoRepository;

    public AvaliacaoService(PedidoRepository pedidoRepository, AvaliacaoRepository avaliacaoRepository) {
        this.pedidoRepository = pedidoRepository;
        this.avaliacaoRepository = avaliacaoRepository;
    }

    @Transactional
    public AvaliacaoResponse avaliarLoja(Long idCliente, Long idPedido, AvaliacaoRequest requisicao) {
        validarElegibilidade(idCliente, idPedido);

        if (avaliacaoRepository.buscarAvaliacaoLoja(idPedido).isPresent()) {
            throw new ConflitoNegocioException("[RF08] A loja já foi avaliada para o pedido " + idPedido + ".");
        }

        return avaliacaoRepository.inserirAvaliacaoLoja(idPedido, requisicao.nota(), requisicao.comentario());
    }

    @Transactional
    public AvaliacaoResponse avaliarEntregador(Long idCliente, Long idPedido, AvaliacaoRequest requisicao) {
        validarElegibilidade(idCliente, idPedido);

        if (avaliacaoRepository.buscarAvaliacaoEntregador(idPedido).isPresent()) {
            throw new ConflitoNegocioException("[RF08] O entregador já foi avaliado para o pedido " + idPedido + ".");
        }

        return avaliacaoRepository.inserirAvaliacaoEntregador(idPedido, requisicao.nota(), requisicao.comentario());
    }

    private void validarElegibilidade(Long idCliente, Long idPedido) {
        var pedido = pedidoRepository.buscarPedidoPorId(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));

        if (!pedido.getIdCliente().equals(idCliente)) {
            throw new AcessoNegadoException("Apenas o cliente dono do pedido pode enviar avaliações.");
        }

        if (pedido.getStatus() != StatusPedido.concluido || !pedidoRepository.entregaEstaConcluida(idPedido)) {
            throw new RegraNegocioException(
                    "[RN13/RR08] A avaliação só pode ser registrada após o pedido estar concluído e entregue."
            );
        }
    }
}
