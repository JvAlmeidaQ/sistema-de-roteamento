/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.repository;

import br.ufjf.dcc.entregas.features.comercio.dto.DivisaoPagamentoResponse;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.Optional;

import static br.ufjf.dcc.entregas.jooq.Tables.DIVISAO_PAGAMENTO;

@Repository
public class DivisaoPagamentoRepository {

    private final DSLContext dsl;

    public DivisaoPagamentoRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public Optional<DivisaoPagamentoResponse> buscarPorPedido(Long idPedido) {
        return dsl.selectFrom(DIVISAO_PAGAMENTO)
                .where(DIVISAO_PAGAMENTO.ID_PEDIDO.eq(idPedido))
                .fetchOptional(record -> new DivisaoPagamentoResponse(
                        record.getIdPedido(),
                        record.getValorTotal(),
                        record.getParcelaLoja(),
                        record.getComissaoEntregador(),
                        record.getTaxaPlataforma(),
                        record.getCalculadaEm()
                ));
    }

    public DivisaoPagamentoResponse inserir(
            Long idPedido,
            BigDecimal valorTotal,
            BigDecimal parcelaLoja,
            BigDecimal comissaoEntregador,
            BigDecimal taxaPlataforma
    ) {
        var record = dsl.insertInto(DIVISAO_PAGAMENTO)
                .set(DIVISAO_PAGAMENTO.ID_PEDIDO, idPedido)
                .set(DIVISAO_PAGAMENTO.VALOR_TOTAL, valorTotal)
                .set(DIVISAO_PAGAMENTO.PARCELA_LOJA, parcelaLoja)
                .set(DIVISAO_PAGAMENTO.COMISSAO_ENTREGADOR, comissaoEntregador)
                .set(DIVISAO_PAGAMENTO.TAXA_PLATAFORMA, taxaPlataforma)
                .returning()
                .fetchOne();

        return new DivisaoPagamentoResponse(
                record.getIdPedido(),
                record.getValorTotal(),
                record.getParcelaLoja(),
                record.getComissaoEntregador(),
                record.getTaxaPlataforma(),
                record.getCalculadaEm()
        );
    }
}
