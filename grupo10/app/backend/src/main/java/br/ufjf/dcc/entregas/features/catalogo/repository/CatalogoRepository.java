package br.ufjf.dcc.entregas.features.catalogo.repository;

import br.ufjf.dcc.entregas.features.catalogo.dto.CategoriaResponse;
import br.ufjf.dcc.entregas.features.catalogo.dto.LojaResponse;
import br.ufjf.dcc.entregas.features.catalogo.dto.ProdutoCatalogoResponse;
import br.ufjf.dcc.entregas.jooq.enums.StatusFuncionamento;
import br.ufjf.dcc.entregas.jooq.tables.records.CategoriaRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.LojaRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.ProdutoRecord;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static br.ufjf.dcc.entregas.jooq.Tables.CATEGORIA;
import static br.ufjf.dcc.entregas.jooq.Tables.ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO_CATEGORIA;
import static org.jooq.impl.DSL.count;

@Repository
public class CatalogoRepository {

    private final DSLContext dsl;

    public CatalogoRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public Optional<LojaResponse> buscarLojaPorLojista(Long idLojista) {
        return dsl.select(
                LOJA.ID_LOJA,
                LOJA.ID_LOJISTA,
                LOJA.ID_ENDERECO,
                LOJA.COMPLEMENTO_ENDERECO,
                LOJA.CNPJ,
                LOJA.NOME,
                LOJA.TELEFONE,
                LOJA.STATUS_FUNCIONAMENTO,
                LOJA.TEMPO_ENTREGA_ESTIMADO,
                LOJA.TAXA_ENTREGA,
                ENDERECO.LOGRADOURO,
                ENDERECO.NUMERO,
                ENDERECO.BAIRRO,
                ENDERECO.CIDADE,
                ENDERECO.ESTADO,
                ENDERECO.CEP
        )
        .from(LOJA)
        .join(ENDERECO).on(LOJA.ID_ENDERECO.eq(ENDERECO.ID_ENDERECO))
        .where(LOJA.ID_LOJISTA.eq(idLojista))
        .limit(1)
        .fetchOptional(this::mapearLojaResponse);
    }

    public Optional<LojaResponse> buscarLojaPorId(Long idLoja) {
        return dsl.select(
                LOJA.ID_LOJA,
                LOJA.ID_LOJISTA,
                LOJA.ID_ENDERECO,
                LOJA.COMPLEMENTO_ENDERECO,
                LOJA.CNPJ,
                LOJA.NOME,
                LOJA.TELEFONE,
                LOJA.STATUS_FUNCIONAMENTO,
                LOJA.TEMPO_ENTREGA_ESTIMADO,
                LOJA.TAXA_ENTREGA,
                ENDERECO.LOGRADOURO,
                ENDERECO.NUMERO,
                ENDERECO.BAIRRO,
                ENDERECO.CIDADE,
                ENDERECO.ESTADO,
                ENDERECO.CEP
        )
        .from(LOJA)
        .join(ENDERECO).on(LOJA.ID_ENDERECO.eq(ENDERECO.ID_ENDERECO))
        .where(LOJA.ID_LOJA.eq(idLoja))
        .fetchOptional(this::mapearLojaResponse);
    }

    private LojaResponse mapearLojaResponse(org.jooq.Record r) {
        return new LojaResponse(
                r.get(LOJA.ID_LOJA),
                r.get(LOJA.ID_LOJISTA),
                r.get(LOJA.ID_ENDERECO),
                r.get(LOJA.COMPLEMENTO_ENDERECO),
                r.get(LOJA.CNPJ),
                r.get(LOJA.NOME),
                r.get(LOJA.TELEFONE),
                r.get(LOJA.STATUS_FUNCIONAMENTO),
                r.get(LOJA.TEMPO_ENTREGA_ESTIMADO),
                r.get(LOJA.TAXA_ENTREGA),
                r.get(ENDERECO.LOGRADOURO),
                r.get(ENDERECO.NUMERO),
                r.get(ENDERECO.BAIRRO),
                r.get(ENDERECO.CIDADE),
                r.get(ENDERECO.ESTADO),
                r.get(ENDERECO.CEP)
        );
    }

    public Optional<LojaRecord> buscarLojaRecord(Long idLoja) {
        return dsl.selectFrom(LOJA)
                .where(LOJA.ID_LOJA.eq(idLoja))
                .fetchOptional();
    }

    public void atualizarStatusFuncionamento(Long idLoja, StatusFuncionamento novoStatus) {
        dsl.update(LOJA)
                .set(LOJA.STATUS_FUNCIONAMENTO, novoStatus)
                .where(LOJA.ID_LOJA.eq(idLoja))
                .execute();
    }

    public void atualizarDadosLoja(Long idLoja, String telefone, String complemento, Integer tempoEstimado, BigDecimal taxaEntrega) {
        dsl.update(LOJA)
                .set(LOJA.TELEFONE, telefone)
                .set(LOJA.COMPLEMENTO_ENDERECO, complemento)
                .set(LOJA.TEMPO_ENTREGA_ESTIMADO, tempoEstimado)
                .set(LOJA.TAXA_ENTREGA, taxaEntrega)
                .where(LOJA.ID_LOJA.eq(idLoja))
                .execute();
    }

    public List<CategoriaResponse> listarCategoriasPorLoja(Long idLoja) {
        return dsl.select(
                CATEGORIA.ID_CATEGORIA,
                CATEGORIA.ID_LOJA,
                CATEGORIA.NOME,
                count(PRODUTO_CATEGORIA.ID_PRODUTO).as("total_produtos")
        )
        .from(CATEGORIA)
        .leftJoin(PRODUTO_CATEGORIA).on(
                CATEGORIA.ID_CATEGORIA.eq(PRODUTO_CATEGORIA.ID_CATEGORIA)
                .and(CATEGORIA.ID_LOJA.eq(PRODUTO_CATEGORIA.ID_LOJA))
        )
        .where(CATEGORIA.ID_LOJA.eq(idLoja))
        .groupBy(CATEGORIA.ID_CATEGORIA, CATEGORIA.ID_LOJA, CATEGORIA.NOME)
        .orderBy(CATEGORIA.NOME.asc())
        .fetch(r -> new CategoriaResponse(
                r.get(CATEGORIA.ID_CATEGORIA),
                r.get(CATEGORIA.ID_LOJA),
                r.get(CATEGORIA.NOME),
                r.get("total_produtos", Long.class)
        ));
    }

    public Long inserirCategoria(Long idLoja, String nome) {
        return dsl.insertInto(CATEGORIA)
                .set(CATEGORIA.ID_LOJA, idLoja)
                .set(CATEGORIA.NOME, nome)
                .returningResult(CATEGORIA.ID_CATEGORIA)
                .fetchOneInto(Long.class);
    }

    public boolean existeCategoriaComNomeNaLoja(Long idLoja, String nome) {
        return dsl.fetchExists(
                dsl.selectOne()
                        .from(CATEGORIA)
                        .where(CATEGORIA.ID_LOJA.eq(idLoja)
                                .and(CATEGORIA.NOME.equalIgnoreCase(nome)))
        );
    }

    public int contarProdutosComApenasEstaCategoria(Long idLoja, Long idCategoria) {
        var pc1 = PRODUTO_CATEGORIA.as("pc1");
        var pc2 = PRODUTO_CATEGORIA.as("pc2");
        return dsl.fetchCount(
                dsl.selectFrom(pc1)
                        .where(pc1.ID_LOJA.eq(idLoja)
                                .and(pc1.ID_CATEGORIA.eq(idCategoria))
                                .andNotExists(
                                        dsl.selectOne()
                                                .from(pc2)
                                                .where(pc2.ID_LOJA.eq(idLoja)
                                                        .and(pc2.ID_PRODUTO.eq(pc1.ID_PRODUTO))
                                                        .and(pc2.ID_CATEGORIA.ne(idCategoria)))
                                ))
        );
    }

    public Optional<CategoriaRecord> buscarCategoriaPorIdELoja(Long idCategoria, Long idLoja) {
        return dsl.selectFrom(CATEGORIA)
                .where(CATEGORIA.ID_CATEGORIA.eq(idCategoria).and(CATEGORIA.ID_LOJA.eq(idLoja)))
                .fetchOptional();
    }

    public void excluirCategoria(Long idCategoria, Long idLoja) {
        dsl.deleteFrom(CATEGORIA)
                .where(CATEGORIA.ID_CATEGORIA.eq(idCategoria).and(CATEGORIA.ID_LOJA.eq(idLoja)))
                .execute();
    }

    public List<ProdutoCatalogoResponse> listarProdutosLoja(Long idLoja, Long idCategoria, Boolean ativo) {
        var baseQuery = dsl.select(
                PRODUTO.ID_PRODUTO,
                PRODUTO.ID_LOJA,
                PRODUTO.NOME,
                PRODUTO.DESCRICAO,
                PRODUTO.PRECO,
                PRODUTO.ATIVO,
                CATEGORIA.ID_CATEGORIA,
                CATEGORIA.NOME
        )
        .from(PRODUTO)
        .leftJoin(PRODUTO_CATEGORIA).on(
                PRODUTO.ID_PRODUTO.eq(PRODUTO_CATEGORIA.ID_PRODUTO)
                .and(PRODUTO.ID_LOJA.eq(PRODUTO_CATEGORIA.ID_LOJA))
        )
        .leftJoin(CATEGORIA).on(
                PRODUTO_CATEGORIA.ID_CATEGORIA.eq(CATEGORIA.ID_CATEGORIA)
                .and(PRODUTO_CATEGORIA.ID_LOJA.eq(CATEGORIA.ID_LOJA))
        )
        .where(PRODUTO.ID_LOJA.eq(idLoja));

        if (ativo != null) {
            baseQuery = baseQuery.and(PRODUTO.ATIVO.eq(ativo));
        }

        if (idCategoria != null) {
            baseQuery = baseQuery.and(PRODUTO.ID_PRODUTO.in(
                    dsl.select(PRODUTO_CATEGORIA.ID_PRODUTO)
                            .from(PRODUTO_CATEGORIA)
                            .where(PRODUTO_CATEGORIA.ID_LOJA.eq(idLoja)
                                    .and(PRODUTO_CATEGORIA.ID_CATEGORIA.eq(idCategoria)))
            ));
        }

        var rows = baseQuery.orderBy(PRODUTO.NOME.asc(), CATEGORIA.NOME.asc()).fetch();

        Map<Long, ProdutoCatalogoResponse> agrupados = new LinkedHashMap<>();
        for (var r : rows) {
            Long idProd = r.get(PRODUTO.ID_PRODUTO);
            agrupados.computeIfAbsent(idProd, k -> new ProdutoCatalogoResponse(
                    idProd,
                    r.get(PRODUTO.ID_LOJA),
                    r.get(PRODUTO.NOME),
                    r.get(PRODUTO.DESCRICAO),
                    r.get(PRODUTO.PRECO),
                    r.get(PRODUTO.ATIVO),
                    new ArrayList<>()
            ));

            Long idCat = r.get(CATEGORIA.ID_CATEGORIA);
            if (idCat != null) {
                agrupados.get(idProd).categorias().add(
                        new ProdutoCatalogoResponse.CategoriaSimplesResponse(idCat, r.get(CATEGORIA.NOME))
                );
            }
        }

        return new ArrayList<>(agrupados.values());
    }

    public Optional<ProdutoCatalogoResponse> buscarProdutoCatalogoPorIdELoja(Long idProduto, Long idLoja) {
        var rows = dsl.select(
                PRODUTO.ID_PRODUTO,
                PRODUTO.ID_LOJA,
                PRODUTO.NOME,
                PRODUTO.DESCRICAO,
                PRODUTO.PRECO,
                PRODUTO.ATIVO,
                CATEGORIA.ID_CATEGORIA,
                CATEGORIA.NOME
        )
        .from(PRODUTO)
        .leftJoin(PRODUTO_CATEGORIA).on(
                PRODUTO.ID_PRODUTO.eq(PRODUTO_CATEGORIA.ID_PRODUTO)
                .and(PRODUTO.ID_LOJA.eq(PRODUTO_CATEGORIA.ID_LOJA))
        )
        .leftJoin(CATEGORIA).on(
                PRODUTO_CATEGORIA.ID_CATEGORIA.eq(CATEGORIA.ID_CATEGORIA)
                .and(PRODUTO_CATEGORIA.ID_LOJA.eq(CATEGORIA.ID_LOJA))
        )
        .where(PRODUTO.ID_LOJA.eq(idLoja).and(PRODUTO.ID_PRODUTO.eq(idProduto)))
        .orderBy(CATEGORIA.NOME.asc())
        .fetch();

        if (rows.isEmpty()) {
            return Optional.empty();
        }

        var r0 = rows.get(0);
        List<ProdutoCatalogoResponse.CategoriaSimplesResponse> categorias = new ArrayList<>();
        for (var r : rows) {
            Long idCat = r.get(CATEGORIA.ID_CATEGORIA);
            if (idCat != null) {
                categorias.add(new ProdutoCatalogoResponse.CategoriaSimplesResponse(idCat, r.get(CATEGORIA.NOME)));
            }
        }

        return Optional.of(new ProdutoCatalogoResponse(
                r0.get(PRODUTO.ID_PRODUTO),
                r0.get(PRODUTO.ID_LOJA),
                r0.get(PRODUTO.NOME),
                r0.get(PRODUTO.DESCRICAO),
                r0.get(PRODUTO.PRECO),
                r0.get(PRODUTO.ATIVO),
                categorias
        ));
    }

    public Optional<ProdutoRecord> buscarProdutoPorIdELoja(Long idProduto, Long idLoja) {
        return dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_PRODUTO.eq(idProduto).and(PRODUTO.ID_LOJA.eq(idLoja)))
                .fetchOptional();
    }

    public Long inserirProduto(Long idLoja, String nome, String descricao, BigDecimal preco) {
        return dsl.insertInto(PRODUTO)
                .set(PRODUTO.ID_LOJA, idLoja)
                .set(PRODUTO.NOME, nome)
                .set(PRODUTO.DESCRICAO, descricao)
                .set(PRODUTO.PRECO, preco)
                .set(PRODUTO.ATIVO, true)
                .returningResult(PRODUTO.ID_PRODUTO)
                .fetchOneInto(Long.class);
    }

    public void atualizarProduto(Long idProduto, Long idLoja, String nome, String descricao, BigDecimal preco) {
        dsl.update(PRODUTO)
                .set(PRODUTO.NOME, nome)
                .set(PRODUTO.DESCRICAO, descricao)
                .set(PRODUTO.PRECO, preco)
                .where(PRODUTO.ID_PRODUTO.eq(idProduto).and(PRODUTO.ID_LOJA.eq(idLoja)))
                .execute();
    }

    public void atualizarAtivoProduto(Long idProduto, Long idLoja, Boolean ativo) {
        dsl.update(PRODUTO)
                .set(PRODUTO.ATIVO, ativo)
                .where(PRODUTO.ID_PRODUTO.eq(idProduto).and(PRODUTO.ID_LOJA.eq(idLoja)))
                .execute();
    }

    public void associarProdutoCategorias(Long idLoja, Long idProduto, List<Long> categoriasIds) {
        // Remove associações anteriores
        dsl.deleteFrom(PRODUTO_CATEGORIA)
                .where(PRODUTO_CATEGORIA.ID_LOJA.eq(idLoja)
                        .and(PRODUTO_CATEGORIA.ID_PRODUTO.eq(idProduto)))
                .execute();

        // Insere as novas associações desduplicadas
        if (categoriasIds != null && !categoriasIds.isEmpty()) {
            List<Long> categoriasUnicas = categoriasIds.stream()
                    .filter(java.util.Objects::nonNull)
                    .distinct()
                    .toList();

            if (!categoriasUnicas.isEmpty()) {
                var insert = dsl.insertInto(
                        PRODUTO_CATEGORIA,
                        PRODUTO_CATEGORIA.ID_PRODUTO,
                        PRODUTO_CATEGORIA.ID_CATEGORIA,
                        PRODUTO_CATEGORIA.ID_LOJA
                );
                for (Long idCat : categoriasUnicas) {
                    insert = insert.values(idProduto, idCat, idLoja);
                }
                insert.execute();
            }
        }
    }

    public List<Long> validarCategoriasPertencemALoja(Long idLoja, List<Long> categoriasIds) {
        if (categoriasIds == null || categoriasIds.isEmpty()) {
            return Collections.emptyList();
        }
        return dsl.select(CATEGORIA.ID_CATEGORIA)
                .from(CATEGORIA)
                .where(CATEGORIA.ID_LOJA.eq(idLoja).and(CATEGORIA.ID_CATEGORIA.in(categoriasIds)))
                .fetchInto(Long.class);
    }
}
