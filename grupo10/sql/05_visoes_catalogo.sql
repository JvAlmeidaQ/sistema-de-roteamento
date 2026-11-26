/*
Arquivo: 05_visoes_catalogo.sql
SGBD: PostgreSQL 18 (compatível com PostgreSQL 14+)

Objetivo:
Criar visões úteis para os atores que consultam e administram
o catálogo de produtos das lojas.

Visões definidas:
1. vw_produtos_ativos
2. vw_catalogo_produtos_categorias

Observação:
As visões pressupõem que o esquema do subdomínio Catálogo já foi
criado e que existem as tabelas Produto, Categoria e Produto_Categoria.
*/


-- ============================================================
-- VISÃO 1: vw_produtos_ativos
--
-- Ator:
-- Aplicação do catálogo / usuário responsável por consultar
-- os produtos disponíveis de uma loja.
--
-- Objetivo:
-- Expor somente produtos ativos, com suas informações principais.
-- A aplicação pode utilizar esta visão para montar a listagem de
-- produtos disponíveis, sem precisar repetir o filtro ativo = TRUE.
--
-- Definição:
-- Seleciona dados de uma única tabela (Produto) e filtra os produtos
-- ativos.
--
-- Atualizável? SIM.
-- Justificativa:
-- É uma visão simples baseada em apenas uma tabela, sem JOIN,
-- GROUP BY, DISTINCT, agregações ou operações de conjunto. Portanto,
-- o PostgreSQL permite operações INSERT, UPDATE e DELETE por meio
-- dela, respeitando as restrições da tabela original.
--
-- O WITH LOCAL CHECK OPTION impede que uma operação feita por meio
-- desta visão torne um produto invisível nela, por exemplo,
-- alterando ativo para FALSE.
-- ============================================================

CREATE OR REPLACE VIEW vw_produtos_ativos AS
SELECT
    id_loja,
    id_produto,
    nome,
    descricao,
    preco,
    ativo
FROM Produto
WHERE ativo = TRUE
WITH LOCAL CHECK OPTION;


-- ============================================================
-- VISÃO 2: vw_catalogo_produtos_categorias
--
-- Ator:
-- Aplicação cliente (frontend/API) responsável por apresentar
-- o catálogo de produtos com suas respectivas categorias.
--
-- Objetivo:
-- Reunir em uma única consulta o nome e o preço do produto,
-- além do nome da categoria associada. O LEFT JOIN garante que
-- produtos ainda sem categoria também sejam apresentados.
--
-- Definição:
-- Combina Produto, Produto_Categoria e Categoria, relacionando
-- os registros pela loja, pelo produto e pela categoria.
--
-- Atualizável? NÃO (não é automaticamente atualizável).
-- Justificativa:
-- A visão utiliza JOIN entre mais de uma tabela. O PostgreSQL não
-- a considera automaticamente atualizável. Além disso, um produto
-- pode aparecer em várias linhas quando possui várias categorias,
-- o que torna ambíguo determinar qual tabela/linha deveria ser
-- alterada por uma operação feita diretamente na visão.
-- Para permitir alterações por ela, seria necessário implementar
-- uma lógica específica, por exemplo, com trigger INSTEAD OF.
-- ============================================================

CREATE OR REPLACE VIEW vw_catalogo_produtos_categorias AS
SELECT
    p.id_loja,
    p.id_produto,
    p.nome AS nome_produto,
    p.preco,
    c.id_categoria,
    c.nome AS nome_categoria
FROM Produto AS p
LEFT JOIN Produto_Categoria AS pc
    ON pc.id_loja = p.id_loja
   AND pc.id_produto = p.id_produto
LEFT JOIN Categoria AS c
    ON c.id_loja = pc.id_loja
   AND c.id_categoria = pc.id_categoria;


/*
RESUMO

- vw_produtos_ativos:
  Ator: aplicação do catálogo / responsável pela consulta de produtos.
  Objetivo: listar somente produtos ativos.
  Atualizável: SIM, por ser baseada em uma única tabela.
  CHECK OPTION: mantém os registros dentro do filtro da visão.

- vw_catalogo_produtos_categorias:
  Ator: aplicação cliente (frontend/API).
  Objetivo: apresentar produtos e suas categorias, incluindo produtos
  ainda sem categoria.
  Atualizável: NÃO automaticamente, pois utiliza JOINs.
*/
