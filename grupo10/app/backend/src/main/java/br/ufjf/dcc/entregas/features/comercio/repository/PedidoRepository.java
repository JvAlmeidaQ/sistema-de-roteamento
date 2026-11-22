/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.repository;

import br.ufjf.dcc.entregas.features.comercio.dto.AvaliacaoResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.DivisaoPagamentoResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.ItemPedidoResponse;
import br.ufjf.dcc.entregas.jooq.enums.FormaPagamento;
import br.ufjf.dcc.entregas.jooq.enums.StatusEntrega;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import br.ufjf.dcc.entregas.jooq.tables.records.LojaRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.PedidoRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.PessoaEnderecoRecord;
import br.ufjf.dcc.entregas.jooq.tables.records.ProdutoRecord;
import org.jooq.Condition;
import org.jooq.DSLContext;
import org.jooq.Record;
import org.jooq.impl.DSL;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import static br.ufjf.dcc.entregas.jooq.Tables.AVALIACAO_ENTREGADOR;
import static br.ufjf.dcc.entregas.jooq.Tables.AVALIACAO_LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.CLIENTE;
import static br.ufjf.dcc.entregas.jooq.Tables.DIVISAO_PAGAMENTO;
import static br.ufjf.dcc.entregas.jooq.Tables.ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.ENTREGA;
import static br.ufjf.dcc.entregas.jooq.Tables.ITEM_PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.LOJA;
import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA;
import static br.ufjf.dcc.entregas.jooq.Tables.PESSOA_ENDERECO;
import static br.ufjf.dcc.entregas.jooq.Tables.PRODUTO;

@Repository
public class PedidoRepository {

    private final DSLContext dsl;

    public PedidoRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public boolean clienteExiste(Long idCliente) {
        return dsl.fetchExists(
                dsl.selectOne().from(CLIENTE).where(CLIENTE.ID_PESSOA.eq(idCliente))
        );
    }

    public Optional<LojaRecord> buscarLoja(Long idLoja) {
        return dsl.selectFrom(LOJA)
                .where(LOJA.ID_LOJA.eq(idLoja))
                .fetchOptional();
    }

    public Optional<PessoaEnderecoRecord> buscarEnderecoDoCliente(Long idCliente, Long idEndereco) {
        return dsl.selectFrom(PESSOA_ENDERECO)
                .where(PESSOA_ENDERECO.ID_PESSOA.eq(idCliente))
                .and(PESSOA_ENDERECO.ID_ENDERECO.eq(idEndereco))
                .fetchOptional();
    }

    public Map<Long, ProdutoRecord> buscarProdutosPorIds(Collection<Long> idsProduto) {
        if (idsProduto == null || idsProduto.isEmpty()) {
            return Map.of();
        }
        return dsl.selectFrom(PRODUTO)
                .where(PRODUTO.ID_PRODUTO.in(idsProduto))
                .fetchMap(PRODUTO.ID_PRODUTO);
    }

    public Long inserirPedido(
            Long idLoja,
            Long idCliente,
            Long idEndereco,
            String complementoEntrega,
            String referenciaEntrega,
            String observacaoEntrega,
            FormaPagamento formaPagamento,
            BigDecimal subtotal,
            BigDecimal taxaEntrega,
            BigDecimal taxaServico,
            BigDecimal valorTotal
    ) {
        return dsl.insertInto(PEDIDO)
                .set(PEDIDO.ID_LOJA, idLoja)
                .set(PEDIDO.ID_CLIENTE, idCliente)
                .set(PEDIDO.ID_ENDERECO, idEndereco)
                .set(PEDIDO.COMPLEMENTO_ENTREGA, complementoEntrega)
                .set(PEDIDO.REFERENCIA_ENTREGA, referenciaEntrega)
                .set(PEDIDO.OBSERVACAO_ENTREGA, observacaoEntrega)
                .set(PEDIDO.STATUS, StatusPedido.solicitado)
                .set(PEDIDO.FORMA_PAGAMENTO, formaPagamento)
                .set(PEDIDO.SUBTOTAL, subtotal)
                .set(PEDIDO.TAXA_ENTREGA, taxaEntrega)
                .set(PEDIDO.TAXA_SERVICO, taxaServico)
                .set(PEDIDO.VALOR_TOTAL, valorTotal)
                .returningResult(PEDIDO.ID_PEDIDO)
                .fetchOneInto(Long.class);
    }

    public void inserirItensPedido(Long idPedido, Long idLoja, List<ItemParaInsercao> itens) {
        if (itens.isEmpty()) {
            return;
        }
        var insert = dsl.insertInto(
                ITEM_PEDIDO,
                ITEM_PEDIDO.ID_PEDIDO,
                ITEM_PEDIDO.ID_PRODUTO,
                ITEM_PEDIDO.ID_LOJA,
                ITEM_PEDIDO.QUANTIDADE,
                ITEM_PEDIDO.VALOR_UNITARIO
        );
        for (ItemParaInsercao item : itens) {
            insert = insert.values(idPedido, item.idProduto(), idLoja, item.quantidade(), item.valorUnitario());
        }
        insert.execute();
    }

    public Optional<PedidoRecord> buscarPedidoPorId(Long idPedido) {
        return dsl.selectFrom(PEDIDO)
                .where(PEDIDO.ID_PEDIDO.eq(idPedido))
                .fetchOptional();
    }

    public Optional<PedidoRecord> buscarPedidoPorIdForUpdate(Long idPedido) {
        return dsl.selectFrom(PEDIDO)
                .where(PEDIDO.ID_PEDIDO.eq(idPedido))
                .forUpdate()
                .fetchOptional();
    }

    public Optional<PedidoDetalhadoRow> buscarDetalhesPedido(Long idPedido) {
        return dsl.select(
                        PEDIDO.ID_PEDIDO,
                        PEDIDO.ID_LOJA,
                        LOJA.NOME,
                        LOJA.ID_LOJISTA,
                        PEDIDO.ID_CLIENTE,
                        PESSOA.NOME,
                        PEDIDO.ID_ENDERECO,
                        ENDERECO.LOGRADOURO,
                        ENDERECO.NUMERO,
                        ENDERECO.BAIRRO,
                        ENDERECO.CIDADE,
                        ENDERECO.ESTADO,
                        PEDIDO.COMPLEMENTO_ENTREGA,
                        PEDIDO.REFERENCIA_ENTREGA,
                        PEDIDO.OBSERVACAO_ENTREGA,
                        PEDIDO.STATUS,
                        ENTREGA.STATUS,
                        PEDIDO.DATA_PEDIDO,
                        PEDIDO.FORMA_PAGAMENTO,
                        PEDIDO.SUBTOTAL,
                        PEDIDO.TAXA_ENTREGA,
                        PEDIDO.TAXA_SERVICO,
                        PEDIDO.VALOR_TOTAL,
                        DIVISAO_PAGAMENTO.ID_PEDIDO,
                        DIVISAO_PAGAMENTO.VALOR_TOTAL,
                        DIVISAO_PAGAMENTO.PARCELA_LOJA,
                        DIVISAO_PAGAMENTO.COMISSAO_ENTREGADOR,
                        DIVISAO_PAGAMENTO.TAXA_PLATAFORMA,
                        DIVISAO_PAGAMENTO.CALCULADA_EM,
                        AVALIACAO_LOJA.ID_PEDIDO,
                        AVALIACAO_LOJA.NOTA,
                        AVALIACAO_LOJA.COMENTARIO,
                        AVALIACAO_LOJA.DATA_AVALIACAO,
                        AVALIACAO_ENTREGADOR.ID_PEDIDO,
                        AVALIACAO_ENTREGADOR.NOTA,
                        AVALIACAO_ENTREGADOR.COMENTARIO,
                        AVALIACAO_ENTREGADOR.DATA_AVALIACAO
                )
                .from(PEDIDO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .join(PESSOA).on(PESSOA.ID_PESSOA.eq(PEDIDO.ID_CLIENTE))
                .join(ENDERECO).on(ENDERECO.ID_ENDERECO.eq(PEDIDO.ID_ENDERECO))
                .leftJoin(ENTREGA).on(ENTREGA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(DIVISAO_PAGAMENTO).on(DIVISAO_PAGAMENTO.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(AVALIACAO_LOJA).on(AVALIACAO_LOJA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(AVALIACAO_ENTREGADOR).on(AVALIACAO_ENTREGADOR.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .where(PEDIDO.ID_PEDIDO.eq(idPedido))
                .fetchOptional(this::mapPedidoDetalhado);
    }

    public List<PedidoDetalhadoRow> listarPedidos(
            Long idLoja,
            Long idCliente,
            Long idUsuarioAutenticado,
            StatusPedido status,
            OffsetDateTime dataInicio,
            OffsetDateTime dataFim,
            int limit
    ) {
        List<Condition> conditions = new ArrayList<>();
        if (idLoja != null) {
            conditions.add(PEDIDO.ID_LOJA.eq(idLoja));
        }
        if (idCliente != null) {
            conditions.add(PEDIDO.ID_CLIENTE.eq(idCliente));
        }
        if (idUsuarioAutenticado != null && idLoja == null && idCliente == null) {
            conditions.add(PEDIDO.ID_CLIENTE.eq(idUsuarioAutenticado)
                    .or(LOJA.ID_LOJISTA.eq(idUsuarioAutenticado)));
        }
        if (status != null) {
            conditions.add(PEDIDO.STATUS.eq(status));
        }
        if (dataInicio != null) {
            conditions.add(PEDIDO.DATA_PEDIDO.greaterOrEqual(dataInicio));
        }
        if (dataFim != null) {
            conditions.add(PEDIDO.DATA_PEDIDO.lessOrEqual(dataFim));
        }

        int safeLimit = Math.min(Math.max(limit, 1), 200);

        return dsl.select(
                        PEDIDO.ID_PEDIDO,
                        PEDIDO.ID_LOJA,
                        LOJA.NOME,
                        LOJA.ID_LOJISTA,
                        PEDIDO.ID_CLIENTE,
                        PESSOA.NOME,
                        PEDIDO.ID_ENDERECO,
                        ENDERECO.LOGRADOURO,
                        ENDERECO.NUMERO,
                        ENDERECO.BAIRRO,
                        ENDERECO.CIDADE,
                        ENDERECO.ESTADO,
                        PEDIDO.COMPLEMENTO_ENTREGA,
                        PEDIDO.REFERENCIA_ENTREGA,
                        PEDIDO.OBSERVACAO_ENTREGA,
                        PEDIDO.STATUS,
                        ENTREGA.STATUS,
                        PEDIDO.DATA_PEDIDO,
                        PEDIDO.FORMA_PAGAMENTO,
                        PEDIDO.SUBTOTAL,
                        PEDIDO.TAXA_ENTREGA,
                        PEDIDO.TAXA_SERVICO,
                        PEDIDO.VALOR_TOTAL,
                        DIVISAO_PAGAMENTO.ID_PEDIDO,
                        DIVISAO_PAGAMENTO.VALOR_TOTAL,
                        DIVISAO_PAGAMENTO.PARCELA_LOJA,
                        DIVISAO_PAGAMENTO.COMISSAO_ENTREGADOR,
                        DIVISAO_PAGAMENTO.TAXA_PLATAFORMA,
                        DIVISAO_PAGAMENTO.CALCULADA_EM,
                        AVALIACAO_LOJA.ID_PEDIDO,
                        AVALIACAO_LOJA.NOTA,
                        AVALIACAO_LOJA.COMENTARIO,
                        AVALIACAO_LOJA.DATA_AVALIACAO,
                        AVALIACAO_ENTREGADOR.ID_PEDIDO,
                        AVALIACAO_ENTREGADOR.NOTA,
                        AVALIACAO_ENTREGADOR.COMENTARIO,
                        AVALIACAO_ENTREGADOR.DATA_AVALIACAO
                )
                .from(PEDIDO)
                .join(LOJA).on(LOJA.ID_LOJA.eq(PEDIDO.ID_LOJA))
                .join(PESSOA).on(PESSOA.ID_PESSOA.eq(PEDIDO.ID_CLIENTE))
                .join(ENDERECO).on(ENDERECO.ID_ENDERECO.eq(PEDIDO.ID_ENDERECO))
                .leftJoin(ENTREGA).on(ENTREGA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(DIVISAO_PAGAMENTO).on(DIVISAO_PAGAMENTO.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(AVALIACAO_LOJA).on(AVALIACAO_LOJA.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .leftJoin(AVALIACAO_ENTREGADOR).on(AVALIACAO_ENTREGADOR.ID_PEDIDO.eq(PEDIDO.ID_PEDIDO))
                .where(DSL.and(conditions))
                .orderBy(PEDIDO.ID_PEDIDO.desc())
                .limit(safeLimit)
                .fetch(this::mapPedidoDetalhado);
    }

    public Map<Long, List<ItemPedidoResponse>> listarItensPorPedidos(Collection<Long> idsPedido) {
        if (idsPedido == null || idsPedido.isEmpty()) {
            return Map.of();
        }

        return dsl.select(
                        ITEM_PEDIDO.ID_PEDIDO,
                        ITEM_PEDIDO.ID_PRODUTO,
                        PRODUTO.NOME,
                        ITEM_PEDIDO.QUANTIDADE,
                        ITEM_PEDIDO.VALOR_UNITARIO
                )
                .from(ITEM_PEDIDO)
                .join(PRODUTO).on(
                        PRODUTO.ID_LOJA.eq(ITEM_PEDIDO.ID_LOJA)
                                .and(PRODUTO.ID_PRODUTO.eq(ITEM_PEDIDO.ID_PRODUTO))
                )
                .where(ITEM_PEDIDO.ID_PEDIDO.in(idsPedido))
                .orderBy(ITEM_PEDIDO.ID_PEDIDO.asc(), ITEM_PEDIDO.ID_PRODUTO.asc())
                .fetch()
                .stream()
                .collect(Collectors.groupingBy(
                        record -> record.get(ITEM_PEDIDO.ID_PEDIDO),
                        Collectors.mapping(record -> {
                            Integer quantidade = record.get(ITEM_PEDIDO.QUANTIDADE);
                            BigDecimal valorUnitario = record.get(ITEM_PEDIDO.VALOR_UNITARIO).setScale(2, RoundingMode.HALF_UP);
                            BigDecimal subtotalItem = valorUnitario
                                    .multiply(BigDecimal.valueOf(quantidade))
                                    .setScale(2, RoundingMode.HALF_UP);
                            return new ItemPedidoResponse(
                                    record.get(ITEM_PEDIDO.ID_PRODUTO),
                                    record.get(PRODUTO.NOME),
                                    quantidade,
                                    valorUnitario,
                                    subtotalItem
                            );
                        }, Collectors.toList())
                ));
    }

    public int atualizarStatus(Long idPedido, StatusPedido statusAtualEsperado, StatusPedido novoStatus) {
        return dsl.update(PEDIDO)
                .set(PEDIDO.STATUS, novoStatus)
                .where(PEDIDO.ID_PEDIDO.eq(idPedido))
                .and(PEDIDO.STATUS.eq(statusAtualEsperado))
                .execute();
    }

    public boolean entregaEstaConcluida(Long idPedido) {
        return dsl.fetchExists(
                dsl.selectOne()
                        .from(ENTREGA)
                        .where(ENTREGA.ID_PEDIDO.eq(idPedido))
                        .and(ENTREGA.STATUS.eq(StatusEntrega.entregue))
        );
    }

    private PedidoDetalhadoRow mapPedidoDetalhado(Record record) {
        DivisaoPagamentoResponse divisao = record.get(DIVISAO_PAGAMENTO.ID_PEDIDO) != null
                ? new DivisaoPagamentoResponse(
                record.get(DIVISAO_PAGAMENTO.ID_PEDIDO),
                record.get(DIVISAO_PAGAMENTO.VALOR_TOTAL),
                record.get(DIVISAO_PAGAMENTO.PARCELA_LOJA),
                record.get(DIVISAO_PAGAMENTO.COMISSAO_ENTREGADOR),
                record.get(DIVISAO_PAGAMENTO.TAXA_PLATAFORMA),
                record.get(DIVISAO_PAGAMENTO.CALCULADA_EM)
        )
                : null;

        AvaliacaoResponse avaliacaoLoja = record.get(AVALIACAO_LOJA.ID_PEDIDO) != null
                ? new AvaliacaoResponse(
                record.get(AVALIACAO_LOJA.ID_PEDIDO),
                record.get(AVALIACAO_LOJA.NOTA),
                record.get(AVALIACAO_LOJA.COMENTARIO),
                record.get(AVALIACAO_LOJA.DATA_AVALIACAO)
        )
                : null;

        AvaliacaoResponse avaliacaoEntregador = record.get(AVALIACAO_ENTREGADOR.ID_PEDIDO) != null
                ? new AvaliacaoResponse(
                record.get(AVALIACAO_ENTREGADOR.ID_PEDIDO),
                record.get(AVALIACAO_ENTREGADOR.NOTA),
                record.get(AVALIACAO_ENTREGADOR.COMENTARIO),
                record.get(AVALIACAO_ENTREGADOR.DATA_AVALIACAO)
        )
                : null;

        return new PedidoDetalhadoRow(
                record.get(PEDIDO.ID_PEDIDO),
                record.get(PEDIDO.ID_LOJA),
                record.get(LOJA.NOME),
                record.get(LOJA.ID_LOJISTA),
                record.get(PEDIDO.ID_CLIENTE),
                record.get(PESSOA.NOME),
                record.get(PEDIDO.ID_ENDERECO),
                record.get(ENDERECO.LOGRADOURO) + ", " + record.get(ENDERECO.NUMERO)
                        + " - " + record.get(ENDERECO.BAIRRO)
                        + " (" + record.get(ENDERECO.CIDADE) + "/" + record.get(ENDERECO.ESTADO) + ")",
                record.get(PEDIDO.COMPLEMENTO_ENTREGA),
                record.get(PEDIDO.REFERENCIA_ENTREGA),
                record.get(PEDIDO.OBSERVACAO_ENTREGA),
                record.get(PEDIDO.STATUS),
                record.get(ENTREGA.STATUS) != null ? record.get(ENTREGA.STATUS).getLiteral() : null,
                record.get(PEDIDO.DATA_PEDIDO),
                record.get(PEDIDO.FORMA_PAGAMENTO),
                record.get(PEDIDO.SUBTOTAL),
                record.get(PEDIDO.TAXA_ENTREGA),
                record.get(PEDIDO.TAXA_SERVICO),
                record.get(PEDIDO.VALOR_TOTAL),
                divisao,
                avaliacaoLoja,
                avaliacaoEntregador
        );
    }

    public record ItemParaInsercao(Long idProduto, Integer quantidade, BigDecimal valorUnitario) {
    }

    public record PedidoDetalhadoRow(
            Long idPedido,
            Long idLoja,
            String nomeLoja,
            Long idLojista,
            Long idCliente,
            String nomeCliente,
            Long idEndereco,
            String resumoEndereco,
            String complementoEntrega,
            String referenciaEntrega,
            String observacaoEntrega,
            StatusPedido status,
            String statusEntrega,
            OffsetDateTime dataPedido,
            FormaPagamento formaPagamento,
            BigDecimal subtotal,
            BigDecimal taxaEntrega,
            BigDecimal taxaServico,
            BigDecimal valorTotal,
            DivisaoPagamentoResponse divisaoPagamento,
            AvaliacaoResponse avaliacaoLoja,
            AvaliacaoResponse avaliacaoEntregador
    ) {
    }
}
