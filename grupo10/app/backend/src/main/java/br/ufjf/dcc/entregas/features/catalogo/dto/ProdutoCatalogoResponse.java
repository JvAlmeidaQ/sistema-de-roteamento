package br.ufjf.dcc.entregas.features.catalogo.dto;

import java.math.BigDecimal;
import java.util.List;

public record ProdutoCatalogoResponse(
        Long idProduto,
        Long idLoja,
        String nome,
        String descricao,
        BigDecimal preco,
        Boolean ativo,
        List<CategoriaSimplesResponse> categorias
) {
    public record CategoriaSimplesResponse(
            Long idCategoria,
            String nome
    ) {}
}
