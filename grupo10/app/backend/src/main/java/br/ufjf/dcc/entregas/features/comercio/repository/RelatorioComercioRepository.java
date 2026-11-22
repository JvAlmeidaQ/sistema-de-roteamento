/**
 * Disciplinas: DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)
 * Subdomínio: Comércio e Finanças
 */
package br.ufjf.dcc.entregas.features.comercio.repository;

import br.ufjf.dcc.entregas.features.comercio.dto.ConsultaEstrategicaResponse;
import br.ufjf.dcc.entregas.features.comercio.dto.ResumoFinanceiroLojaResponse;
import br.ufjf.dcc.entregas.jooq.enums.StatusPedido;
import org.jooq.Condition;
import org.jooq.DSLContext;
import org.jooq.Field;
import org.jooq.Record;
import org.jooq.Result;
import org.jooq.impl.DSL;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;
import static br.ufjf.dcc.entregas.jooq.Tables.VW_RESUMO_FINANCEIRO_LOJA;

@Repository
public class RelatorioComercioRepository {

    private final DSLContext dsl;

    public RelatorioComercioRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public List<ResumoFinanceiroLojaResponse> listarResumoFinanceiroLojas(Long idLoja) {
        var query = dsl.selectFrom(VW_RESUMO_FINANCEIRO_LOJA);
        var filtered = idLoja != null
                ? query.where(VW_RESUMO_FINANCEIRO_LOJA.ID_LOJA.eq(idLoja))
                : query;

        return filtered
                .orderBy(VW_RESUMO_FINANCEIRO_LOJA.ID_LOJA.asc())
                .limit(50)
                .fetch(record -> new ResumoFinanceiroLojaResponse(
                        record.getIdLoja(),
                        record.getNomeLoja(),
                        record.getPedidosConcluidos(),
                        record.getFaturamentoBruto(),
                        record.getRepasseTotalLoja(),
                        record.getTotalComissaoEntregadores(),
                        record.getReceitaPlataforma(),
                        record.getMediaAvaliacaoLoja()
                ));
    }

    public AgregadoPedidosLoja calcularAgregadosPedidosLoja(
            Long idLoja,
            StatusPedido status,
            OffsetDateTime dataInicio,
            OffsetDateTime dataFim
    ) {
        List<Condition> conditions = new ArrayList<>();
        conditions.add(PEDIDO.ID_LOJA.eq(idLoja));
        if (status != null) {
            conditions.add(PEDIDO.STATUS.eq(status));
        }
        if (dataInicio != null) {
            conditions.add(PEDIDO.DATA_PEDIDO.greaterOrEqual(dataInicio));
        }
        if (dataFim != null) {
            conditions.add(PEDIDO.DATA_PEDIDO.lessOrEqual(dataFim));
        }

        var row = dsl.select(
                        DSL.count(PEDIDO.ID_PEDIDO),
                        DSL.coalesce(DSL.sum(PEDIDO.VALOR_TOTAL), BigDecimal.ZERO),
                        DSL.coalesce(DSL.avg(PEDIDO.VALOR_TOTAL), BigDecimal.ZERO)
                )
                .from(PEDIDO)
                .where(DSL.and(conditions))
                .fetchOne();

        return new AgregadoPedidosLoja(
                row.value1().longValue(),
                row.value2(),
                row.value3()
        );
    }

    public ConsultaEstrategicaResponse executarConsultaEstrategica(int numero) {
        return switch (numero) {
            case 5 -> executarSql(
                    5,
                    "Lojas com pedidos concluídos em todas as formas de pagamento",
                    "Divisão relacional (NOT EXISTS / NOT EXISTS) sobre loja e pedido (RF10).",
                    """
                    SELECT l.id_loja, l.nome, l.cnpj
                      FROM loja l
                     WHERE NOT EXISTS (
                               SELECT 1
                                 FROM (SELECT DISTINCT forma_pagamento FROM pedido WHERE status = 'concluido') formas
                                WHERE NOT EXISTS (
                                          SELECT 1
                                            FROM pedido p
                                           WHERE p.id_loja = l.id_loja
                                             AND p.status = 'concluido'
                                             AND p.forma_pagamento = formas.forma_pagamento
                                      )
                           )
                     ORDER BY l.id_loja
                     LIMIT 100
                    """
            );
            case 6 -> executarSql(
                    6,
                    "Pedidos com comissão do entregador maior que a parcela da loja",
                    "Auditoria financeira sobre divisao_pagamento (RN05).",
                    """
                    SELECT dp.id_pedido, dp.valor_total
                      FROM divisao_pagamento dp
                     WHERE dp.comissao_entregador > dp.parcela_loja
                     ORDER BY dp.id_pedido
                     LIMIT 100
                    """
            );
            case 7 -> executarSql(
                    7,
                    "Pedidos acima de R$ 100,00 com avaliação ruim da loja (nota <= 2)",
                    "Junção interna entre pedido e avaliacao_loja (RF08/RN06).",
                    """
                    SELECT p.id_pedido, p.id_loja, p.valor_total, al.nota
                      FROM pedido p
                     INNER JOIN avaliacao_loja al ON al.id_pedido = p.id_pedido
                     WHERE p.valor_total > 100.00
                       AND al.nota <= 2
                     ORDER BY p.id_pedido
                     LIMIT 100
                    """
            );
            case 8 -> executarSql(
                    8,
                    "Pedidos entregues sem avaliação da loja, do entregador ou de ambos",
                    "Operações de conjuntos (EXCEPT e INTERSECT) entre entrega e avaliações (RF08/RN13).",
                    """
                    SELECT p.id_pedido, p.id_cliente
                      FROM (
                               SELECT e.id_pedido FROM entrega e WHERE e.status = 'entregue'
                               EXCEPT
                               (
                                   SELECT al.id_pedido FROM avaliacao_loja al
                                   INTERSECT
                                   SELECT ae.id_pedido FROM avaliacao_entregador ae
                               )
                           ) pendentes
                     INNER JOIN pedido p ON p.id_pedido = pendentes.id_pedido
                     ORDER BY p.id_pedido
                     LIMIT 100
                    """
            );
            case 9 -> executarSql(
                    9,
                    "Pedido concluído de maior valor total",
                    "Subconsulta correlacionada com NOT EXISTS sobre pedido.",
                    """
                    SELECT p1.id_pedido, p1.id_loja, p1.id_cliente, p1.valor_total
                      FROM pedido p1
                     WHERE p1.status = 'concluido'
                       AND NOT EXISTS (
                               SELECT 1
                                 FROM pedido p2
                                WHERE p2.status = 'concluido'
                                  AND p2.valor_total > p1.valor_total
                           )
                     ORDER BY p1.id_pedido
                     LIMIT 100
                    """
            );
            case 10 -> executarSql(
                    10,
                    "Clientes com pedidos concluídos em Pix/dinheiro e cartão de crédito",
                    "Interseção de conjuntos (INTERSECT) sobre pedido e pessoa.",
                    """
                    SELECT pe.id_pessoa, pe.nome, pe.email
                      FROM (
                               (SELECT p.id_cliente FROM pedido p WHERE p.status = 'concluido' AND p.forma_pagamento IN ('pix', 'dinheiro'))
                               INTERSECT
                               (SELECT p.id_cliente FROM pedido p WHERE p.status = 'concluido' AND p.forma_pagamento = 'cartao_credito')
                           ) clientes_alvo
                     INNER JOIN pessoa pe ON pe.id_pessoa = clientes_alvo.id_cliente
                     ORDER BY pe.id_pessoa
                     LIMIT 100
                    """
            );
            case 11 -> executarSql(
                    11,
                    "Pedidos concluídos acima de R$ 250,00 com nota da loja (incluindo não avaliados)",
                    "Junção externa (RIGHT JOIN) preservando pedidos sem avaliação (RF08/RN06).",
                    """
                    SELECT p.id_pedido, p.id_loja, p.valor_total, al.nota
                      FROM avaliacao_loja al
                     RIGHT JOIN pedido p ON p.id_pedido = al.id_pedido
                     WHERE p.status = 'concluido'
                       AND p.valor_total > 250.00
                     ORDER BY p.valor_total DESC, p.id_pedido
                     LIMIT 100
                    """
            );
            case 12 -> executarSql(
                    12,
                    "Lojas com repasse líquido acumulado superior a R$ 15.000,00",
                    "Agrupamento (GROUP BY / HAVING) com quantidade e ticket médio (RN05/RF10).",
                    """
                    SELECT l.id_loja,
                           l.nome,
                           COUNT(dp.id_pedido) AS qtd_pedidos,
                           SUM(dp.parcela_loja) AS repasse_total_loja,
                           ROUND(AVG(dp.valor_total), 2) AS ticket_medio
                      FROM loja l
                     INNER JOIN pedido p ON p.id_loja = l.id_loja
                     INNER JOIN divisao_pagamento dp ON dp.id_pedido = p.id_pedido
                     WHERE p.status = 'concluido'
                     GROUP BY l.id_loja, l.nome
                    HAVING SUM(dp.parcela_loja) > 15000.00
                     ORDER BY repasse_total_loja DESC, l.id_loja
                     LIMIT 100
                    """
            );
            default -> throw new IllegalArgumentException("Consulta inválida: " + numero);
        };
    }

    private ConsultaEstrategicaResponse executarSql(int numero, String titulo, String descricao, String sql) {
        Result<Record> result = dsl.fetch(sql);
        List<String> colunas = Arrays.stream(result.fields())
                .map(Field::getName)
                .toList();

        List<Map<String, Object>> linhas = new ArrayList<>(result.size());
        for (Record record : result) {
            Map<String, Object> row = new LinkedHashMap<>();
            for (Field<?> field : result.fields()) {
                row.put(field.getName(), record.get(field));
            }
            linhas.add(row);
        }
        return new ConsultaEstrategicaResponse(numero, titulo, descricao, colunas, linhas);
    }

    public record AgregadoPedidosLoja(
            Long totalPedidos,
            BigDecimal faturamentoTotal,
            BigDecimal ticketMedio
    ) {
    }
}
