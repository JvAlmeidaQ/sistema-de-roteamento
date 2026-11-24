/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística — RF05
 */
package br.ufjf.dcc.entregas.features.logistica.service;

import br.ufjf.dcc.entregas.core.exception.AcessoNegadoException;
import br.ufjf.dcc.entregas.core.exception.RecursoNaoEncontradoException;
import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse;
import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse.EntregaAtual;
import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse.Evento;
import br.ufjf.dcc.entregas.features.logistica.dto.RastreioPedidoResponse.TipoEvento;
import br.ufjf.dcc.entregas.features.logistica.repository.RastreioRepository;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

@Service
public class RastreioService {

    private static final List<String> CICLO_PEDIDO = List.of(
            "solicitado", "aceito", "pago", "em_preparacao", "pronto", "concluido");
    private static final List<String> CICLO_ENTREGA = List.of(
            "aguardando_entregador", "aceita", "a_caminho", "entregue");

    private final RastreioRepository rastreioRepository;

    public RastreioService(RastreioRepository rastreioRepository) {
        this.rastreioRepository = rastreioRepository;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public RastreioPedidoResponse consultar(long idPedido, long idUsuario) {
        var pedido = rastreioRepository.buscarPedido(idPedido)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Pedido " + idPedido + " não encontrado."));
        if (pedido.idCliente() != idUsuario && pedido.idLojista() != idUsuario
                && !Objects.equals(pedido.idEntregador(), idUsuario)) {
            throw new AcessoNegadoException("Somente os participantes do pedido podem consultar o rastreio.");
        }

        String statusPedido = pedido.statusPedido().getLiteral();
        var eventosPedido = rastreioRepository.listarEventosPedido(idPedido);
        var esperadosPedido = pedido.statusPedido() == StatusPedido.recusado
                ? List.of("solicitado", "recusado")
                : CICLO_PEDIDO.subList(0, CICLO_PEDIDO.indexOf(statusPedido) + 1);
        boolean historicoIncompleto = faltamEventos(esperadosPedido, eventosPedido);
        var eventos = new ArrayList<>(eventosPedido);
        EntregaAtual entrega = null;

        if (pedido.idEntrega() != null) {
            String statusEntrega = pedido.statusEntrega().getLiteral();
            entrega = new EntregaAtual(statusEntrega, pedido.previsaoEntrega());
            var eventosEntrega = rastreioRepository.listarEventosEntrega(pedido.idEntrega());
            var esperadosEntrega = CICLO_ENTREGA.subList(0, CICLO_ENTREGA.indexOf(statusEntrega) + 1);
            historicoIncompleto |= faltamEventos(esperadosEntrega, eventosEntrega);
            eventos.addAll(eventosEntrega);
        } else if (pedido.statusPedido() == StatusPedido.pronto || pedido.statusPedido() == StatusPedido.concluido) {
            // Algumas linhas da carga antiga chegaram a pronto sem gerar uma entrega.
            historicoIncompleto = true;
        }

        eventos.sort(Comparator.comparing((Evento evento) -> evento.dataHora().toInstant())
                .thenComparingInt(RastreioService::desempateCronologico));
        return new RastreioPedidoResponse(idPedido, pedido.nomeLoja(), statusPedido, entrega,
                List.copyOf(eventos), historicoIncompleto);
    }

    private static boolean faltamEventos(List<String> esperados, List<Evento> eventos) {
        return esperados.stream().anyMatch(status -> eventos.stream().noneMatch(e -> e.status().equals(status)));
    }

    private static int desempateCronologico(Evento evento) {
        // No mesmo instante, pedido pronto vem antes da entrega inicial e entrega concluída antes do pedido concluído.
        if (evento.tipo() == TipoEvento.ENTREGA) {
            return CICLO_PEDIDO.size() + CICLO_ENTREGA.indexOf(evento.status());
        }
        return switch (evento.status()) {
            case "recusado" -> 1;
            case "concluido" -> CICLO_PEDIDO.size() + CICLO_ENTREGA.size();
            default -> CICLO_PEDIDO.indexOf(evento.status());
        };
    }
}
