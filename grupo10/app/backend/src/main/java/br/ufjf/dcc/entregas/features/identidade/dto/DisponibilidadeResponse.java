/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 */
package br.ufjf.dcc.entregas.features.identidade.dto;

public record DisponibilidadeResponse(
        boolean emailDisponivel,
        boolean cpfDisponivel
) {}
