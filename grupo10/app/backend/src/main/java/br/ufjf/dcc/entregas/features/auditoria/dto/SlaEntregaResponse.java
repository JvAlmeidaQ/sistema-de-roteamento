/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: RF06 / RF10 / RN03 / RN04 (relatório de SLA e pontualidade de entregas)
 */
package br.ufjf.dcc.entregas.features.auditoria.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record SlaEntregaResponse(
        Long idEntrega,
        Long idPedido,
        Long idLoja,
        String nomeLoja,
        Long idRota,
        OffsetDateTime dataPedido,
        OffsetDateTime previsaoEntrega,
        OffsetDateTime entregueEm,
        boolean atrasada,
        BigDecimal desvioMinutos
) {}