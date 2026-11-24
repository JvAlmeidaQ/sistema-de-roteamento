/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 */
package br.ufjf.dcc.entregas.features.identidade.dto;

public record SessaoAutenticadaResponse(
        Long idPessoa,
        String nome,
        String email,
        boolean perfilCliente,
        boolean perfilLojista,
        boolean perfilEntregador,
        boolean administrador,
        Long idLoja,
        String nomeLoja
) {}
