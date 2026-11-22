/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: DTO estritamente de leitura para seleção de sessão do usuário (X-User-Id) na interface.
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

public record UsuarioSessaoResponse(
        Long idPessoa,
        String nome,
        String email,
        boolean perfilCliente,
        boolean perfilLojista,
        Long idLoja,
        String nomeLoja
) {
}
