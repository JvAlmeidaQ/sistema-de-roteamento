/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

import java.util.List;
import java.util.Map;

public record ConsultaEstrategicaResponse(
        int numero,
        String titulo,
        String descricao,
        List<String> colunas,
        List<Map<String, Object>> linhas
) {
}
