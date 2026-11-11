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
