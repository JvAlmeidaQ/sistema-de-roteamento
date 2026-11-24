/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: RF05 / RN04 (linha do tempo unificada comercial + logística)
 */
package br.ufjf.dcc.entregas.features.auditoria.dto;

import java.time.OffsetDateTime;

public record LinhaTempoPedidoResponse(
        Long idPedido,
        Long idLoja,
        Long idCliente,
        String dominioEvento,
        String statusEvento,
        OffsetDateTime dataHora
) {}