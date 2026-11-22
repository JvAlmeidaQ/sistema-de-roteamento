/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.time.OffsetDateTime;

public record AvaliacaoResponse(
        Long idPedido,
        Short nota,
        String comentario,
        OffsetDateTime dataAvaliacao
) {
}
