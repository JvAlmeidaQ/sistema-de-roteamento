package br.ufjf.dcc.entregas.features.catalogo.dto;

public record CategoriaResponse(
        Long idCategoria,
        Long idLoja,
        String nome,
        Long totalProdutos
) {}
