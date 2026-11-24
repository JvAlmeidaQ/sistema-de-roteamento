package br.ufjf.dcc.entregas.features.catalogo.dto;

import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import java.math.BigDecimal;

public record LojaResponse(
        Long idLoja,
        Long idLojista,
        Long idEndereco,
        String complementoEndereco,
        String cnpj,
        String nome,
        String telefone,
        StatusFuncionamento statusFuncionamento,
        Integer tempoEntregaEstimado,
        BigDecimal taxaEntrega,
        String logradouro,
        String numero,
        String bairro,
        String cidade,
        String estado,
        String cep
) {}
