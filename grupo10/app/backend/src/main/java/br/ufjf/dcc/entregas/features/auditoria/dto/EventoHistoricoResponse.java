/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Auditoria
 * Implementa: RF05 / RN04 (consulta de eventos individuais do histórico imutável)
 */
package br.ufjf.dcc.entregas.features.auditoria.dto;

import java.time.OffsetDateTime;

public record EventoHistoricoResponse(
        String status,
        OffsetDateTime dataHora
) {}