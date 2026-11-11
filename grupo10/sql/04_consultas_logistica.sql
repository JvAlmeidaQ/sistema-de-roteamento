WITH pendentes AS (
    SELECT id_entrega, id_rota
    FROM entrega
    WHERE status IN ('aceita', 'a_caminho')
)
SELECT
    r.id_rota,
    r.id_entregador,
    e1.id_entrega AS id_entrega_1,
    e2.id_entrega AS id_entrega_2
FROM pendentes AS e1
INNER JOIN pendentes AS e2
    ON e1.id_rota = e2.id_rota
    AND e1.id_entrega < e2.id_entrega
INNER JOIN rota AS r ON r.id_rota = e1.id_rota
ORDER BY r.id_rota, e1.id_entrega, e2.id_entrega;

SELECT DISTINCT
    p.nome,
    e.tipo_veiculo,
    r.id_rota
FROM entregador AS e
INNER JOIN pessoa AS p ON p.id_pessoa = e.id_pessoa
LEFT JOIN rota AS r
    ON r.id_entregador = e.id_pessoa
    AND r.encerrada_em IS NULL
ORDER BY p.nome, e.tipo_veiculo, r.id_rota NULLS LAST;

SELECT
    r.id_rota,
    r.id_entregador,
    COUNT(e.id_entrega) AS total_entregas,
    2 - COUNT(e.id_entrega) AS vagas
FROM rota AS r
LEFT JOIN entrega AS e ON e.id_rota = r.id_rota
WHERE r.encerrada_em IS NULL
GROUP BY r.id_rota, r.id_entregador
HAVING COUNT(e.id_entrega) < 2
ORDER BY r.id_rota;

SELECT
    en.id_pessoa AS id_entregador,
    p.nome,
    COUNT(e.id_entrega) AS entregas_concluidas
FROM entregador AS en
INNER JOIN pessoa AS p ON p.id_pessoa = en.id_pessoa
INNER JOIN rota AS r ON r.id_entregador = en.id_pessoa
INNER JOIN entrega AS e ON e.id_rota = r.id_rota
WHERE e.status = 'entregue'
GROUP BY en.id_pessoa, p.nome
HAVING COUNT(e.id_entrega) >= 2
ORDER BY entregas_concluidas DESC, en.id_pessoa;

SELECT
    en.id_pessoa AS id_entregador,
    p.nome
FROM entregador AS en
INNER JOIN pessoa AS p ON p.id_pessoa = en.id_pessoa
WHERE EXISTS (
    SELECT 1
    FROM rota AS r
    INNER JOIN entrega AS e ON e.id_rota = r.id_rota
    WHERE r.id_entregador = en.id_pessoa
      AND e.status IN ('aceita', 'a_caminho')
      AND e.previsao_entrega < CURRENT_TIMESTAMP
)
ORDER BY en.id_pessoa;

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
