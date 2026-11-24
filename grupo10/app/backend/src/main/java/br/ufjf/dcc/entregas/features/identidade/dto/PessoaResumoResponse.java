/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Implementa: RF01 (listagem e busca de pessoas, consumindo a visão vw_perfil_pessoa)
 */
package br.ufjf.dcc.entregas.features.identidade.dto;

public record PessoaResumoResponse(
        Long idPessoa,
        String nome,
        String cpf,
        String email,
        boolean cliente,
        boolean lojista,
        boolean entregador,
        String tipoVeiculo,
        String telefones,
        long qtdEnderecos
) {}
