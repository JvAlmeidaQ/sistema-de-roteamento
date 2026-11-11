SELECT
    e.id_entrega,
    e.previsao_entrega,
    p.id_pedido,
    p.id_loja,
    l.nome AS nome_loja,
    l.tempo_entrega_estimado
FROM entrega AS e
INNER JOIN pedido AS p ON p.id_pedido = e.id_pedido
INNER JOIN loja AS l ON l.id_loja = p.id_loja
WHERE e.status IN ('aceita', 'a_caminho')
  AND e.previsao_entrega < TIMESTAMPTZ '2026-02-01 12:00:00+00'
ORDER BY e.previsao_entrega, p.id_pedido;
