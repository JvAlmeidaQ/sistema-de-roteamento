-- E5, seção 6: doze consultas distintas sobre a carga de 02, antes ou após 06.
-- 14/15 mantêm a numeração da álgebra; L1–L10 são consultas complementares.
-- Cada bloco informa pergunta, ator e técnica. Relatórios sem RN própria são
-- funcionalidades de consulta; não criam regras de negócio adicionais.
-- Cobertura: ON (14/15/L1–L5), USING (L7–L9), NATURAL JOIN (L8),
-- junção implícita (L10), CROSS JOIN (L9), LEFT JOIN (15/L1), RIGHT JOIN (L5),
-- diferença EXCEPT (L6), divisão por dupla negação (L7), GROUP BY/HAVING (L1/L2)
-- e subconsultas correlacionadas (L3/L4/L7).
-- Sobre a preparação isolada de 500 mil pedidos em 14/11/2026, todas retornaram dados:
-- 14=400, 15=1.001, L1=1, L2=1.000, L3=200, L4=700, L5=1.500, L6=300,
-- L7=400, L8=400, L9=3.000, L10=100. Atrasos variam com o tempo após a carga.
-- O formato de anotação específico do Classroom ainda requer conferência com seu modelo.

-- Consulta 14: quais rotas têm duas entregas ativas e quais são elas?
-- Ator: operação logística, RF04/RN02. Autojunção das entregas ativas da mesma rota.
-- id_entrega_1 < id_entrega_2 elimina autopares e pares em ordem inversa.
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

-- Consulta 15: quais entregadores estão cadastrados e quais rotas abertas têm?
-- Ator: operação logística, RF01/RF04. LEFT JOIN inclui entregadores sem rota aberta.
-- O filtro de rota aberta fica no ON para não eliminar esses entregadores.
-- DISTINCT mantém a projeção de conjuntos da álgebra, inclusive em caso de homônimos.
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

-- L1: quais rotas abertas ainda têm vagas?
-- Ator: operação logística. RN02/RR02 contam todos os vínculos, inclusive concluídos.
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

-- L2: quais entregadores já concluíram pelo menos duas entregas?
-- Ator: gestor de Logística. Relatório sem RN específica: conclusões por entregador.
-- GROUP BY/HAVING exige pelo menos duas; nome não é a chave do agrupamento.
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

-- L3: quais entregadores têm entregas ativas atrasadas?
-- Ator: operação logística. Apoia RN03/RR05; o bloqueio fica na aplicação.
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

-- L4: quais pedidos prontos ainda não têm entrega atribuída a uma rota?
-- Ator: operação logística, apoio a RF04/RN12. NOT EXISTS correlacionado inclui
-- pedido ainda sem entrega e entrega aguardando rota. Não altera o estado do pedido.
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

-- L5: qual é a situação logística de cada pedido pronto, inclusive sem entrega?
-- Ator: operador de despacho, apoio a RF04/RN12. RIGHT JOIN preserva pedidos
-- ainda não processados, com campos de entrega NULL. O filtro usa o lado preservado.
SELECT p.id_pedido, p.id_loja, e.id_entrega, e.status, e.id_rota
FROM entrega e RIGHT JOIN pedido p ON p.id_pedido = e.id_pedido
WHERE p.status = 'pronto'
ORDER BY p.id_pedido;

-- L6: quais pedidos prontos ainda não possuem entrega criada?
-- Ator: operador de despacho. Diferença com EXCEPT; distingue ausência de entrega
-- da fila L4, que também inclui entregas já criadas e ainda sem rota.
-- Apoia a conferência da geração da RN12 no snapshot anterior aos gatilhos;
-- no fluxo real, tornar o pedido pronto deve gerar a entrega automaticamente.
SELECT id_pedido FROM pedido WHERE status = 'pronto'
EXCEPT
SELECT id_pedido FROM entrega
ORDER BY id_pedido;

-- L7: quais entregadores possuem entregas em todos os status atribuídos da base?
-- Ator: gestor de Logística. Divisão relacional por dupla negação:
-- não pode existir status atribuído para o qual falte entrega desse entregador.
-- O divisor contém os estados efetivamente observados, excluindo os sem entregador.
-- Considera o estado atual das entregas, não o histórico de transições da Auditoria.
-- Se o divisor estiver vazio, a divisão aceita todos os entregadores, por definição.
SELECT en.id_pessoa AS id_entregador, p.nome
FROM entregador en JOIN pessoa p USING (id_pessoa)
WHERE NOT EXISTS (
    SELECT 1
    FROM (SELECT DISTINCT status FROM entrega WHERE id_rota IS NOT NULL) estados
    WHERE NOT EXISTS (
        SELECT 1 FROM rota r JOIN entrega e USING (id_rota)
        WHERE r.id_entregador = en.id_pessoa AND e.status = estados.status
    )
)
ORDER BY en.id_pessoa;

-- L8: quais entregas aguardam atribuição e qual é a estimativa da loja de origem?
-- Ator: operador de despacho. NATURAL JOIN recebe uma projeção controlada:
-- o único nome compartilhado entre pedido e a subconsulta é id_pedido.
-- USING une a loja pela FK id_loja. Apoia a atribuição prevista no ADR-005.
SELECT p.id_pedido, e.id_entrega, p.id_loja, l.tempo_entrega_estimado, e.previsao_entrega
FROM pedido p
NATURAL JOIN (
    SELECT id_pedido, id_entrega, previsao_entrega FROM entrega
    WHERE status = 'aguardando_entregador'
) e
JOIN loja l USING (id_loja)
ORDER BY e.previsao_entrega, p.id_pedido;

-- L9: quantas entregas cada entregador tem em cada status atribuído, incluindo zeros?
-- Ator: gestor de Logística. CROSS JOIN monta a matriz entregador × estado;
-- LEFT JOIN e COALESCE preservam o zero quando não há entrega naquele estado.
-- É uma distribuição dos estados atuais; não soma eventos dos históricos.
SELECT en.id_pessoa AS id_entregador, estados.status,
       COALESCE(t.total, 0) AS total_entregas
FROM entregador en
CROSS JOIN (VALUES ('aceita'::status_entrega), ('a_caminho'), ('entregue')) estados(status)
LEFT JOIN (
    SELECT r.id_entregador, e.status, COUNT(*) AS total
    FROM rota r JOIN entrega e USING (id_rota)
    GROUP BY r.id_entregador, e.status
) t ON t.id_entregador = en.id_pessoa AND t.status = estados.status
ORDER BY en.id_pessoa, estados.status;

-- L10: quais lojas possuem entregas concluídas em rotas encerradas e quantas são?
-- Ator: gestor de Logística. Junção implícita por produto cartesiano e filtro WHERE.
SELECT l.id_loja, l.nome, COUNT(*) AS entregas_concluidas
FROM loja l, pedido p, entrega e, rota r
WHERE p.id_loja = l.id_loja AND e.id_pedido = p.id_pedido AND r.id_rota = e.id_rota
  AND e.status = 'entregue' AND r.encerrada_em IS NOT NULL
GROUP BY l.id_loja, l.nome
ORDER BY l.id_loja;
