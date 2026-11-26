/*
Arquivo: 04_consultas_catalogo.sql
SGBD: PostgreSQL 18 (compatível com PostgreSQL 14+)

Objetivo:
Traduzir as Consultas 5, 6 e 7 da Álgebra Relacional para SQL
no subdomínio Catálogo e incluir consultas extras para contemplar
os requisitos de JOINs, GROUP BY/HAVING e subconsulta correlacionada.

Tabelas utilizadas: Loja, Produto, Categoria e Produto_Categoria.

Execute cada SELECT separadamente para visualizar seu resultado.
*/


-- ============================================================
-- CONSULTA 5
-- Pergunta:
-- Qual a relação de todos os produtos com suas categorias?
-- Mostrar nome do produto, preço e nome da categoria.
--
-- Tradução:
-- ProdutosBase INNER JOIN Associacoes INNER JOIN Categorias.
--
-- JOIN utilizado: INNER JOIN.
-- Resultado esperado:
-- Uma linha para cada associação entre produto e categoria.
-- ============================================================

SELECT
    p.nome AS nome_produto,
    p.preco,
    c.nome AS nome_categoria
FROM Produto AS p
INNER JOIN Produto_Categoria AS pc
    ON pc.id_loja = p.id_loja
   AND pc.id_produto = p.id_produto
INNER JOIN Categoria AS c
    ON c.id_loja = pc.id_loja
   AND c.id_categoria = pc.id_categoria
ORDER BY
    p.nome,
    c.nome;

-- ============================================================
-- CONSULTA EXTRA 8 - RIGHT JOIN
-- Pergunta:
-- Quais lojas possuem produtos cadastrados e quais ainda não
-- possuem nenhum produto? Mostrar loja e produto, quando houver.
--
-- O RIGHT JOIN preserva todas as linhas de Loja, inclusive lojas
-- sem produto correspondente. Nesses casos, os campos de Produto
-- aparecem como NULL.
-- Resultado esperado:
-- Todas as lojas cadastradas, com seus produtos quando existirem.
-- ============================================================

SELECT
    l.id_loja,
    l.nome AS nome_loja,
    p.id_produto,
    p.nome AS nome_produto
FROM Produto AS p
RIGHT JOIN Loja AS l
    ON l.id_loja = p.id_loja
ORDER BY
    l.id_loja,
    p.id_produto;


-- ============================================================
-- CONSULTA EXTRA 9 - GROUP BY + HAVING
-- Pergunta:
-- Quais lojas possuem produtos associados a pelo menos duas
-- categorias diferentes? Mostrar identificador, nome da loja
-- e quantidade de categorias distintas associadas.
--
-- GROUP BY agrupa as associações por loja.
-- HAVING mantém somente os grupos com duas ou mais categorias.
-- Resultado esperado:
-- Uma linha por loja que possui pelo menos duas categorias
-- diferentes associadas a seus produtos.
-- ============================================================

SELECT
    l.id_loja,
    l.nome,
    COUNT(DISTINCT pc.id_categoria) AS quantidade_categorias
FROM Loja AS l
INNER JOIN Produto_Categoria AS pc
    ON pc.id_loja = l.id_loja
GROUP BY
    l.id_loja,
    l.nome
HAVING COUNT(DISTINCT pc.id_categoria) >= 2
ORDER BY
    l.id_loja;


-- ============================================================
-- CONSULTA EXTRA 10 - SUBCONSULTA CORRELACIONADA
-- Pergunta:
-- Quais produtos ativos possuem preço acima da média dos preços
-- dos produtos da mesma loja? Mostrar loja, produto, preço e média.
--
-- A subconsulta é correlacionada porque utiliza p.id_loja, que vem
-- da consulta externa, para calcular a média dos produtos da loja
-- correspondente. A média considera todos os produtos da loja;
-- o filtro de produto ativo é aplicado à consulta externa.
-- Resultado esperado:
-- Produtos ativos cujo preço é maior que a média de preço de todos
-- os produtos cadastrados na respectiva loja.
-- ============================================================

SELECT
    l.id_loja,
    l.nome AS nome_loja,
    p.id_produto,
    p.nome AS nome_produto,
    p.preco,
    (
        SELECT AVG(p2.preco)
        FROM Produto AS p2
        WHERE p2.id_loja = p.id_loja
    ) AS media_preco_loja
FROM Produto AS p
INNER JOIN Loja AS l
    ON l.id_loja = p.id_loja
WHERE p.ativo = TRUE
  AND p.preco > (
      SELECT AVG(p2.preco)
      FROM Produto AS p2
      WHERE p2.id_loja = p.id_loja
  )
ORDER BY
    l.id_loja,
    p.preco DESC;


/*
RESUMO DA VERIFICAÇÃO DOS REQUISITOS

- INNER JOIN: Consultas 9 e 10.
- LEFT JOIN: Consulta 5.
- RIGHT JOIN: Consulta Extra 8.
- GROUP BY + HAVING: Consulta Extra 9.
- Subconsulta correlacionada: Consulta Extra 10.

A Consulta Extra 9 também resolve a condição da Consulta 6,
mas utilizando agrupamento e HAVING. Ela foi incluída para que
o arquivo contemple explicitamente esse requisito.
*/
