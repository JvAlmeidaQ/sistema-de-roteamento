-- L4 da seção 6: pedidos prontos sem entrega atribuída a uma rota.
-- Apoia RF04/RN12, incluindo pedidos sem entrega e entregas aguardando rota.
-- Reproduz L4 de 04, adicionando EXPLAIN ANALYZE. Índice avaliado:
-- idx_pedido_pronto_fila, parcial para status pronto, na ordem data_pedido/id_pedido.
-- EXPLAIN ANALYZE executa o SELECT e mostra o plano; não altera os dados.
EXPLAIN ANALYZE
SELECT
    p.id_pedido,
    p.id_loja,
    p.data_pedido
FROM pedido AS p
WHERE p.status = 'pronto'
  AND NOT EXISTS (
      SELECT 1
      FROM entrega AS e
      WHERE e.id_pedido = p.id_pedido
        AND e.id_rota IS NOT NULL
  )
ORDER BY p.data_pedido, p.id_pedido;
