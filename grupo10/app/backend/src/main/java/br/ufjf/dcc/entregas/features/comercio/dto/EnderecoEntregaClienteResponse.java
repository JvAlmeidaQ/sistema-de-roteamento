/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 * Observação: DTO estritamente de leitura para seleção de endereço do cliente no checkout (RF02, RR03).
 */
package br.ufjf.dcc.entregas.features.comercio.dto;

public record EnderecoEntregaClienteResponse(
        Long idEndereco,
        String apelido,
        String logradouro,
        String numero,
        String bairro,
        String cep,
        String cidade,
        String estado,
        String complemento,
        String referencia,
        boolean enderecoAtual
) {
}
