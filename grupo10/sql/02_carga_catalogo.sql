/*
============================================================================
SUBDOMÍNIO: CATÁLOGO
Arquivo: 02_carga_catalogo.sql
SGBD: PostgreSQL 18 (compatível com PostgreSQL 14+)
Executar após 01_esquema_catalogo.sql, em banco recém-criado.

Carga gerada em lote: 375 registros
- 3 Pessoa
- 3 Lojista
- 3 Endereco
- 3 Loja
- 33 Categoria
- 150 Produto
- 180 Produto_Categoria

Em vez de escrever 150 produtos e 180 associações individualmente,
o script usa conjuntos-base, CROSS JOIN, generate_series/unnest e INSERT
... SELECT para gerar os registros.

A carga pressupõe tabelas vazias e IDs de Pessoa/Lojista/Endereco/Loja
iniciando normalmente pelas colunas IDENTITY. As associações são feitas
por loja e nome da categoria, sem depender de IDs fixos de Categoria.
============================================================================
*/

BEGIN;

-- ============================================================================
-- 1. PESSOA (3 registros)
-- São dados fixos de referência; por isso, permanecem em VALUES.
-- ============================================================================

INSERT INTO Pessoa (nome, cpf, email)
VALUES
    ('Ana Martins',   '11111111111', 'ana.martins@email.com'),
    ('Bruno Almeida', '22222222222', 'bruno.almeida@email.com'),
    ('Carla Souza',   '33333333333', 'carla.souza@email.com');


-- ============================================================================
-- 2. LOJISTA (3 registros)
-- Os lojistas são gerados a partir das Pessoas inseridas acima.
-- ============================================================================

INSERT INTO Lojista (id_pessoa)
SELECT p.id_pessoa
FROM Pessoa AS p
WHERE p.cpf IN ('11111111111', '22222222222', '33333333333')
ORDER BY p.cpf;


-- ============================================================================
-- 3. ENDERECO (3 registros)
-- São endereços fixos usados pelas três lojas.
-- ============================================================================

INSERT INTO Endereco (logradouro, numero, bairro, cidade, estado, cep)
VALUES
    ('Rua Halfeld',        '100', 'Centro',     'Juiz de Fora', 'MG', '36010000'),
    ('Avenida Rio Branco', '500', 'Centro',     'Juiz de Fora', 'MG', '36010010'),
    ('Rua São Mateus',     '250', 'São Mateus', 'Juiz de Fora', 'MG', '36025000');


-- ============================================================================
-- 4. LOJA (3 registros)
-- As FKs são localizadas pelos CPFs dos lojistas e pelos dados completos
-- dos endereços, sem assumir que seus IDs são necessariamente 1, 2 e 3.
-- ============================================================================

INSERT INTO Loja (
    id_lojista,
    id_endereco,
    complemento_endereco,
    cnpj,
    nome,
    telefone,
    status_funcionamento,
    tempo_entrega_estimado,
    taxa_entrega
)
SELECT
    lj.id_pessoa,
    e.id_endereco,
    dados.complemento_endereco,
    dados.cnpj,
    dados.nome,
    dados.telefone,
    dados.status_funcionamento::status_funcionamento,
    dados.tempo_entrega_estimado,
    dados.taxa_entrega
FROM (
    VALUES
        ('11111111111', 'Rua Halfeld',        '100', 'Centro',     'Juiz de Fora', 'MG', '36010000', 'Loja 12', '12345678000195', 'Mercado Central',       '(32) 3211-1000', 'aberta',  35, 5.00::NUMERIC),
        ('22222222222', 'Avenida Rio Branco', '500', 'Centro',     'Juiz de Fora', 'MG', '36010010', 'Sala 3',  '23456789000106', 'Empório do Bairro',     '(32) 3211-2000', 'aberta',  45, 5.00::NUMERIC),
        ('33333333333', 'Rua São Mateus',     '250', 'São Mateus', 'Juiz de Fora', 'MG', '36025000', NULL,      '34567890000117', 'Quitanda São Mateus',   '(32) 3211-3000', 'fechada', 30, 5.00::NUMERIC)
) AS dados(
    cpf_lojista, logradouro, numero, bairro, cidade, estado, cep,
    complemento_endereco, cnpj, nome, telefone, status_funcionamento,
    tempo_entrega_estimado, taxa_entrega
)
INNER JOIN Pessoa AS pe
    ON pe.cpf = dados.cpf_lojista
INNER JOIN Lojista AS lj
    ON lj.id_pessoa = pe.id_pessoa
INNER JOIN Endereco AS e
    ON e.logradouro = dados.logradouro
   AND e.numero = dados.numero
   AND e.bairro = dados.bairro
   AND e.cidade = dados.cidade
   AND e.estado = dados.estado
   AND e.cep = dados.cep
ORDER BY dados.cnpj;


-- ============================================================================
-- 5. CATEGORIA (33 registros)
--
-- Primeiro são inseridas as categorias iniciais das três lojas. Isso mantém
-- a mesma distribuição de dados da carga anterior: Bebidas para as lojas 1
-- e 2 e Hortifruti para a loja 3.
-- Depois, generate_series(1, 10) gera as outras dez categorias de cada loja.
-- Resultado: 11 categorias por loja, 33 no total.
-- ============================================================================

-- Categoria inicial de cada loja.
INSERT INTO Categoria (id_loja, nome)
SELECT l.id_loja, dados.nome_categoria
FROM (
    VALUES
        ('12345678000195', 'Bebidas'),
        ('23456789000106', 'Bebidas'),
        ('34567890000117', 'Hortifruti')
) AS dados(cnpj, nome_categoria)
INNER JOIN Loja AS l
    ON l.cnpj = dados.cnpj
ORDER BY l.id_loja;

-- Dez categorias adicionais por loja, geradas a partir de uma sequência.
INSERT INTO Categoria (id_loja, nome)
SELECT
    l.id_loja,
    (ARRAY[
        'Padaria',
        'Mercearia',
        'Limpeza',
        'Higiene',
        'Congelados',
        'Snacks',
        'Laticínios',
        'Doces',
        'Enlatados',
        'Ofertas'
    ])[serie.ordem] AS nome_categoria
FROM Loja AS l
CROSS JOIN generate_series(1, 10) AS serie(ordem)
WHERE l.cnpj IN ('12345678000195', '23456789000106', '34567890000117')
ORDER BY l.id_loja, serie.ordem;


-- ============================================================================
-- 6. PRODUTO (150 registros)
--
-- A lista abaixo contém somente 50 produtos-base.
-- O CROSS JOIN com as três lojas gera 150 registros (50 por loja).
-- Os preços das lojas 2 e 3 recebem acréscimos de R$ 0,35 e R$ 0,70,
-- respectivamente, preservando a variação da carga original.
-- Os produtos de ordem 9, 19, 29, 39 e 49 são inativos em cada loja.
-- ============================================================================

WITH produtos_base (
    ordem, nome_base, descricao, preco_base, ativo
) AS (
    VALUES
        ( 1, 'Água mineral 500 ml',                 'Água mineral sem gás, garrafa de 500 ml.',                         2.50::NUMERIC, TRUE),
        ( 2, 'Água com gás 500 ml',                 'Água mineral gaseificada, garrafa de 500 ml.',                     3.00::NUMERIC, TRUE),
        ( 3, 'Refrigerante cola 2 L',               'Refrigerante sabor cola, embalagem de 2 litros.',                 8.99::NUMERIC, TRUE),
        ( 4, 'Refrigerante guaraná 2 L',            'Refrigerante sabor guaraná, embalagem de 2 litros.',              7.99::NUMERIC, TRUE),
        ( 5, 'Suco de laranja 1 L',                 'Suco de laranja, embalagem de 1 litro.',                           9.90::NUMERIC, TRUE),
        ( 6, 'Pão francês (kg)',                    'Pão francês vendido por quilograma.',                             14.00::NUMERIC, TRUE),
        ( 7, 'Pão integral',                        'Pão integral fatiado.',                                            8.50::NUMERIC, TRUE),
        ( 8, 'Pão de queijo 400 g',                 'Pão de queijo congelado, pacote de 400 g.',                       12.90::NUMERIC, TRUE),
        ( 9, 'Bolo de cenoura',                     'Bolo de cenoura com cobertura de chocolate.',                    18.00::NUMERIC, FALSE),
        (10, 'Biscoito de polvilho 200 g',          'Biscoito de polvilho, pacote de 200 g.',                           7.50::NUMERIC, TRUE),
        (11, 'Arroz tipo 1 5 kg',                   'Arroz tipo 1, pacote de 5 kg.',                                   27.90::NUMERIC, TRUE),
        (12, 'Feijão carioca 1 kg',                 'Feijão carioca, pacote de 1 kg.',                                  8.90::NUMERIC, TRUE),
        (13, 'Macarrão espaguete 500 g',            'Massa tipo espaguete, pacote de 500 g.',                           5.50::NUMERIC, TRUE),
        (14, 'Farinha de trigo 1 kg',               'Farinha de trigo tradicional, pacote de 1 kg.',                   6.80::NUMERIC, TRUE),
        (15, 'Óleo de soja 900 ml',                 'Óleo de soja, garrafa de 900 ml.',                                 7.20::NUMERIC, TRUE),
        (16, 'Detergente neutro 500 ml',            'Detergente líquido neutro, frasco de 500 ml.',                    2.79::NUMERIC, TRUE),
        (17, 'Água sanitária 1 L',                  'Água sanitária, frasco de 1 litro.',                               5.90::NUMERIC, TRUE),
        (18, 'Sabão em pó 1 kg',                    'Sabão em pó para roupas, pacote de 1 kg.',                        12.50::NUMERIC, TRUE),
        (19, 'Desinfetante lavanda 2 L',            'Desinfetante perfumado, embalagem de 2 litros.',                  6.99::NUMERIC, FALSE),
        (20, 'Esponja multiuso',                    'Esponja de limpeza multiuso.',                                    2.50::NUMERIC, TRUE),
        (21, 'Sabonete 90 g',                       'Sabonete em barra, unidade de 90 g.',                             2.30::NUMERIC, TRUE),
        (22, 'Shampoo 350 ml',                      'Shampoo para uso diário, frasco de 350 ml.',                     14.90::NUMERIC, TRUE),
        (23, 'Condicionador 350 ml',                'Condicionador para uso diário, frasco de 350 ml.',               16.90::NUMERIC, TRUE),
        (24, 'Creme dental 90 g',                   'Creme dental, tubo de 90 g.',                                     4.50::NUMERIC, TRUE),
        (25, 'Papel higiênico 12 rolos',            'Pacote de papel higiênico com 12 rolos.',                         18.90::NUMERIC, TRUE),
        (26, 'Ervilha congelada 300 g',             'Ervilha congelada, pacote de 300 g.',                             8.50::NUMERIC, TRUE),
        (27, 'Pizza de mussarela congelada',        'Pizza de mussarela congelada.',                                  19.90::NUMERIC, TRUE),
        (28, 'Lasanha bolonhesa 600 g',             'Lasanha bolonhesa congelada, bandeja de 600 g.',                 21.90::NUMERIC, TRUE),
        (29, 'Batata palito congelada 1 kg',        'Batata palito congelada, pacote de 1 kg.',                       16.50::NUMERIC, FALSE),
        (30, 'Hambúrguer bovino congelado',         'Hambúrguer bovino congelado.',                                   18.90::NUMERIC, TRUE),
        (31, 'Amendoim torrado 150 g',              'Amendoim torrado, pacote de 150 g.',                              7.90::NUMERIC, TRUE),
        (32, 'Salgadinho de milho 100 g',           'Salgadinho de milho, pacote de 100 g.',                           5.50::NUMERIC, TRUE),
        (33, 'Chocolate ao leite 90 g',             'Chocolate ao leite, barra de 90 g.',                              6.90::NUMERIC, TRUE),
        (34, 'Barra de cereal',                     'Barra de cereal, unidade.',                                       2.50::NUMERIC, TRUE),
        (35, 'Pipoca para micro-ondas',             'Milho para pipoca de micro-ondas.',                               4.90::NUMERIC, TRUE),
        (36, 'Leite integral 1 L',                  'Leite integral UHT, embalagem de 1 litro.',                       5.80::NUMERIC, TRUE),
        (37, 'Queijo minas 300 g',                  'Queijo minas frescal, embalagem de 300 g.',                      19.90::NUMERIC, TRUE),
        (38, 'Mussarela fatiada 200 g',             'Queijo mussarela fatiado, pacote de 200 g.',                    12.90::NUMERIC, TRUE),
        (39, 'Iogurte natural 170 g',               'Iogurte natural, pote de 170 g.',                                 3.50::NUMERIC, FALSE),
        (40, 'Manteiga 200 g',                      'Manteiga com sal, embalagem de 200 g.',                           11.90::NUMERIC, TRUE),
        (41, 'Goiabada 300 g',                      'Goiabada cascão, embalagem de 300 g.',                            8.90::NUMERIC, TRUE),
        (42, 'Doce de leite 400 g',                 'Doce de leite cremoso, pote de 400 g.',                           12.90::NUMERIC, TRUE),
        (43, 'Geleia de morango 250 g',             'Geleia de morango, pote de 250 g.',                              10.50::NUMERIC, TRUE),
        (44, 'Paçoca 150 g',                        'Doce de amendoim, pacote de 150 g.',                              5.90::NUMERIC, TRUE),
        (45, 'Pudim de leite',                      'Pudim de leite pronto para consumo.',                             8.50::NUMERIC, TRUE),
        (46, 'Milho verde em conserva 170 g',       'Milho verde em conserva, lata de 170 g.',                        3.80::NUMERIC, TRUE),
        (47, 'Ervilha em conserva 170 g',           'Ervilha em conserva, lata de 170 g.',                             4.20::NUMERIC, TRUE),
        (48, 'Atum ralado 170 g',                   'Atum em conserva, lata de 170 g.',                                9.90::NUMERIC, TRUE),
        (49, 'Sardinha em óleo 125 g',              'Sardinha em óleo, lata de 125 g.',                                7.50::NUMERIC, FALSE),
        (50, 'Molho de tomate 300 g',               'Molho de tomate, sachê de 300 g.',                                3.99::NUMERIC, TRUE)
),
lojas_carga AS (
    SELECT
        l.id_loja,
        l.nome AS nome_loja,
        CASE l.cnpj
            WHEN '12345678000195' THEN 0.00::NUMERIC
            WHEN '23456789000106' THEN 0.35::NUMERIC
            WHEN '34567890000117' THEN 0.70::NUMERIC
        END AS acrescimo_preco
    FROM Loja AS l
    WHERE l.cnpj IN ('12345678000195', '23456789000106', '34567890000117')
)
INSERT INTO Produto (id_loja, nome, descricao, preco, ativo)
SELECT
    l.id_loja,
    pb.nome_base || ' - ' || l.nome_loja,
    pb.descricao,
    (pb.preco_base + l.acrescimo_preco)::NUMERIC(12,2),
    pb.ativo
FROM lojas_carga AS l
CROSS JOIN produtos_base AS pb
ORDER BY l.id_loja, pb.ordem;


-- ============================================================================
-- 7. PRODUTO_CATEGORIA (180 registros)
--
-- Cada produto recebe uma categoria principal.
-- A cada grupo de cinco produtos, o primeiro também recebe a categoria
-- Ofertas. Assim, são 50 + 10 associações por loja = 60 por loja.
-- O CTE usa ROW_NUMBER para descobrir a posição do produto em sua loja.
-- As categorias são localizadas pelo nome e pelo id_loja, respeitando as FKs
-- compostas e evitando depender dos IDs gerados para Categoria.
-- ============================================================================

WITH produtos_numerados AS (
    SELECT
        p.id_loja,
        p.id_produto,
        l.cnpj,
        ROW_NUMBER() OVER (
            PARTITION BY p.id_loja
            ORDER BY p.id_produto
        ) AS ordem_produto
    FROM Produto AS p
    INNER JOIN Loja AS l
        ON l.id_loja = p.id_loja
    WHERE l.cnpj IN ('12345678000195', '23456789000106', '34567890000117')
),
produtos_com_categoria_principal AS (
    SELECT
        pn.id_loja,
        pn.id_produto,
        CASE
            WHEN pn.ordem_produto BETWEEN 1 AND 5 THEN
                CASE
                    WHEN pn.cnpj = '34567890000117' THEN 'Hortifruti'
                    ELSE 'Bebidas'
                END
            WHEN pn.ordem_produto BETWEEN 6 AND 10 THEN 'Padaria'
            WHEN pn.ordem_produto BETWEEN 11 AND 15 THEN 'Mercearia'
            WHEN pn.ordem_produto BETWEEN 16 AND 20 THEN 'Limpeza'
            WHEN pn.ordem_produto BETWEEN 21 AND 25 THEN 'Higiene'
            WHEN pn.ordem_produto BETWEEN 26 AND 30 THEN 'Congelados'
            WHEN pn.ordem_produto BETWEEN 31 AND 35 THEN 'Snacks'
            WHEN pn.ordem_produto BETWEEN 36 AND 40 THEN 'Laticínios'
            WHEN pn.ordem_produto BETWEEN 41 AND 45 THEN 'Doces'
            WHEN pn.ordem_produto BETWEEN 46 AND 50 THEN 'Enlatados'
        END AS nome_categoria
    FROM produtos_numerados AS pn
),
associacoes AS (
    -- Associação principal: todos os 150 produtos recebem uma categoria.
    SELECT
        pcp.id_loja,
        pcp.id_produto,
        pcp.nome_categoria
    FROM produtos_com_categoria_principal AS pcp

    UNION ALL

    -- Associação adicional: o primeiro produto de cada grupo de cinco
    -- também é associado à categoria Ofertas (10 por loja).
    SELECT
        pn.id_loja,
        pn.id_produto,
        'Ofertas' AS nome_categoria
    FROM produtos_numerados AS pn
    WHERE MOD(pn.ordem_produto - 1, 5) = 0
)
INSERT INTO Produto_Categoria (id_loja, id_produto, id_categoria)
SELECT
    a.id_loja,
    a.id_produto,
    c.id_categoria
FROM associacoes AS a
INNER JOIN Categoria AS c
    ON c.id_loja = a.id_loja
   AND c.nome = a.nome_categoria
ORDER BY a.id_loja, a.id_produto, c.id_categoria;


COMMIT;

-- Atualiza as estatísticas das tabelas após a carga.
-- O planejador do PostgreSQL usa essas estatísticas para estimar a quantidade
-- de registros e escolher planos de execução para filtros, JOINs e agrupamentos.
ANALYZE;


-- ============================================================================
-- CONFERÊNCIA DO VOLUME GERADO
-- Total esperado: 375 registros.
-- ============================================================================

SELECT 'Pessoa' AS tabela, COUNT(*) AS quantidade FROM Pessoa
UNION ALL
SELECT 'Lojista', COUNT(*) FROM Lojista
UNION ALL
SELECT 'Endereco', COUNT(*) FROM Endereco
UNION ALL
SELECT 'Loja', COUNT(*) FROM Loja
UNION ALL
SELECT 'Categoria', COUNT(*) FROM Categoria
UNION ALL
SELECT 'Produto', COUNT(*) FROM Produto
UNION ALL
SELECT 'Produto_Categoria', COUNT(*) FROM Produto_Categoria
ORDER BY tabela;
