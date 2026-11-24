/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Logística — RF05
 */
package br.ufjf.dcc.entregas.features.logistica.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record RastreioPedidoResponse(
        long idPedido,
        String nomeLoja,
        String statusPedido,
        EntregaAtual entrega,
        List<Evento> eventos,
        boolean historicoIncompleto
) {
    public record EntregaAtual(String status, OffsetDateTime previsaoEntrega) {}

    public record Evento(TipoEvento tipo, String status, OffsetDateTime dataHora) {}

    public enum TipoEvento { PEDIDO, ENTREGA }
}
