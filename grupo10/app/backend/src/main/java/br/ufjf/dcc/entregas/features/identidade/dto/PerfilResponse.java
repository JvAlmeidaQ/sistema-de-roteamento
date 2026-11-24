/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Subdomínio: Identidade e Contato
 * Implementa: RF01 (visualização completa do perfil de uma Pessoa)
 */
package br.ufjf.dcc.entregas.features.identidade.dto;

import java.util.List;

public record PerfilResponse(
        Long idPessoa,
        String nome,
        String cpf,
        String email,
        boolean cliente,
        boolean lojista,
        boolean entregador,
        String tipoVeiculo,
        List<Telefone> telefones,
        List<Endereco> enderecos,
        List<Loja> lojas,
        Restricoes restricoes
) {

    public record Telefone(String numero, String tipo) {}

    public record Endereco(
            Long idEndereco,
            String logradouro,
            String numero,
            String bairro,
            String cep,
            String cidade,
            String estado,
            String apelido,
            String complemento,
            String referencia,
            boolean atual
    ) {}

    public record Loja(Long idLoja, String nome, String cnpj, String statusFuncionamento) {}

    /**
     * Indica quais papéis não podem ser removidos por já possuírem histórico,
     * permitindo que a interface desabilite a opção e explique o motivo.
     */
    public record Restricoes(
            boolean clienteComPedidos,
            boolean lojistaComLojas,
            boolean entregadorComRotas
    ) {}
}
