-- =============================================================================
-- 02_carga_identidade_contato.sql — Subdomínio Identidade e Contato (E4)
-- Pré-requisito: 01_esquema_identidade_contato.sql executado em banco vazio
-- (os IDs gerados pelas colunas IDENTITY começam em 1).
--
-- Divisão de papéis (especialização total e sobreposta — ADR-003):
--   1–40    entregador
--   41–50   entregador + cliente
--   51–60   entregador
--   61–70   entregador + cliente
--   71–80   entregador
--   81–100  entregador + lojista
--   101–120 entregador + lojista + cliente
--   121–200 lojista + cliente
--   201–300 cliente
-- Totais: 120 entregadores (1–120), 120 lojistas (81–200), 220 clientes.
-- Os entregadores 1, 2 e 3 são usados pela carga da Logística.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Pessoa (300 linhas)
--    CPF = número sequencial com zeros à esquerda: passa no CHECK de 11 dígitos
--    (RN10). O dígito verificador (RN11) é validado na aplicação, não no banco.
-- -----------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
SELECT
    (ARRAY['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Felipe', 'Gabriela',
           'Henrique', 'Isabela', 'João', 'Larissa', 'Marcos', 'Natália',
           'Otávio', 'Paula', 'Rafael', 'Sofia', 'Thiago', 'Vanessa', 'Lucas'])[1 + i % 20]
    || ' ' ||
    (ARRAY['Silva', 'Souza', 'Oliveira', 'Santos', 'Pereira', 'Costa',
           'Almeida', 'Ferreira', 'Rodrigues', 'Gomes', 'Martins', 'Barbosa',
           'Ribeiro', 'Carvalho', 'Moreira', 'Teixeira', 'Rocha'])[1 + (i / 20) % 17],
    lpad(i::TEXT, 11, '0'),
    'pessoa' || i || '@exemplo.com'
FROM generate_series(1, 300) AS g(i);

-- -----------------------------------------------------------------------------
-- 2. Endereco (330 linhas)
--    1–280: casas; 281–330: endereços de trabalho.
--    O número é único por linha, então a UK (logradouro, numero, cep) nunca colide.
-- -----------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
SELECT
    (ARRAY['Rua Halfeld', 'Avenida Barão do Rio Branco', 'Rua São Mateus',
           'Avenida Presidente Itamar Franco', 'Rua Santo Antônio',
           'Rua Marechal Deodoro', 'Avenida dos Andradas', 'Rua Batista de Oliveira',
           'Rua Espírito Santo', 'Avenida Getúlio Vargas', 'Rua Chanceler Oswaldo Aranha',
           'Rua Morais e Castro'])[1 + i % 12],
    (10 + i)::TEXT,
    (ARRAY['Centro', 'São Mateus', 'Cascatinha', 'Granbery', 'Bom Pastor',
           'Alto dos Passos', 'São Pedro', 'Benfica', 'Santa Luzia', 'Manoel Honório'])[1 + i % 10],
    '360' || lpad(((i * 37) % 100000)::TEXT, 5, '0'),
    'Juiz de Fora',
    'MG'
FROM generate_series(1, 330) AS g(i);

-- -----------------------------------------------------------------------------
-- 3. Pessoa_Endereco (350 linhas)
-- -----------------------------------------------------------------------------
-- 3a. Pessoas 1–280: cada uma com sua casa (endereço de mesmo número).
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido, complemento, referencia)
SELECT
    i,
    i,
    'Casa',
    CASE WHEN i % 3 = 0 THEN 'Apto ' || (100 + i % 400) END,
    CASE WHEN i % 5 = 0 THEN 'Próximo à padaria' END
FROM generate_series(1, 280) AS g(i);

-- 3b. Pessoas 281–300: dividem a casa com as pessoas 101–120 (mesmo imóvel,
--     relação N:N). O complemento é individual de cada morador (ADR-002).
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido, complemento)
SELECT
    i,
    i - 180,
    'Casa',
    'Quarto ' || (i - 280)
FROM generate_series(281, 300) AS g(i);

-- 3c. Pessoas 111–160: segundo endereço (trabalho), endereços 281–330.
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido, complemento)
SELECT
    i,
    280 + (i - 110),
    'Trabalho',
    'Sala ' || (i - 110)
FROM generate_series(111, 160) AS g(i);

-- -----------------------------------------------------------------------------
-- 4. Telefone (≈435 linhas) — só dígitos: DDD + 8 (fixo) ou 9 (celular)
-- -----------------------------------------------------------------------------
-- 4a. Todas as pessoas têm um celular (RR17: ao menos um telefone).
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT i, '3299' || lpad(i::TEXT, 7, '0'), 'celular'
FROM generate_series(1, 300) AS g(i);

-- 4b. Uma em cada quatro pessoas também tem telefone fixo.
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT i, '3232' || lpad(i::TEXT, 6, '0'), 'fixo'
FROM generate_series(1, 300) AS g(i)
WHERE i % 4 = 0;

-- 4c. Lojistas (81–200) têm telefone comercial.
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT i, '3230' || lpad(i::TEXT, 6, '0'), 'comercial'
FROM generate_series(81, 200) AS g(i);

-- -----------------------------------------------------------------------------
-- 5. Papéis (RR16: toda pessoa com ao menos um papel)
-- -----------------------------------------------------------------------------
-- 5a. Entregadores: 1–120, com o tipo de veículo alternando.
INSERT INTO entregador (id_pessoa, tipo_veiculo)
SELECT
    id_pessoa,
    (ARRAY['moto', 'bicicleta', 'carro']::tipo_veiculo[])[1 + id_pessoa % 3]
FROM pessoa
WHERE id_pessoa BETWEEN 1 AND 120;

-- 5b. Lojistas: 81–200.
INSERT INTO lojista (id_pessoa)
SELECT id_pessoa
FROM pessoa
WHERE id_pessoa BETWEEN 81 AND 200;

-- 5c. Clientes: 41–50, 61–70 e 101–300, ainda sem endereço atual.
INSERT INTO cliente (id_pessoa)
SELECT id_pessoa
FROM pessoa
WHERE id_pessoa BETWEEN 41 AND 50
   OR id_pessoa BETWEEN 61 AND 70
   OR id_pessoa >= 101;

-- -----------------------------------------------------------------------------
-- 6. Endereço atual do cliente (FK composta → pessoa_endereco, ADR-002)
--    - Clientes 111–130 usam o endereço de trabalho.
--    - Clientes 296–300 ficam sem endereço atual (NULL é aceito: MATCH SIMPLE).
--    - Os demais usam a casa.
-- -----------------------------------------------------------------------------
UPDATE cliente c
SET id_endereco_atual = pe.id_endereco
FROM pessoa_endereco pe
WHERE pe.id_pessoa = c.id_pessoa
  AND pe.apelido = CASE WHEN c.id_pessoa BETWEEN 111 AND 130
                        THEN 'Trabalho' ELSE 'Casa' END
  AND c.id_pessoa NOT BETWEEN 296 AND 300;

COMMIT;

-- -----------------------------------------------------------------------------
-- 7. Estatísticas para o planejador de consultas (ANALYZE)
-- -----------------------------------------------------------------------------
ANALYZE VERBOSE pessoa;
ANALYZE VERBOSE endereco;
ANALYZE VERBOSE pessoa_endereco;
ANALYZE VERBOSE telefone;
ANALYZE VERBOSE entregador;
ANALYZE VERBOSE lojista;
ANALYZE VERBOSE cliente;

-- Resultado observado do ANALYZE VERBOSE (PostgreSQL 18):
-- pessoa:          4 pages | 300 live rows |   0 dead rows | 300 rows in sample | 300 estimated total rows
-- endereco:        5 pages | 330 live rows |   0 dead rows | 330 rows in sample | 330 estimated total rows
-- pessoa_endereco: 3 pages | 350 live rows |   0 dead rows | 350 rows in sample | 350 estimated total rows
-- telefone:        4 pages | 495 live rows |   0 dead rows | 495 rows in sample | 495 estimated total rows
-- entregador:      1 page  | 120 live rows |   0 dead rows | 120 rows in sample | 120 estimated total rows
-- lojista:         1 page  | 120 live rows |   0 dead rows | 120 rows in sample | 120 estimated total rows
-- cliente:         3 pages | 220 live rows | 215 dead rows (devido ao UPDATE de id_endereco_atual) | 220 rows in sample | 220 estimated total rows


-- =============================================================================
-- SUBDOMÍNIO: CATÁLOGO
-- Pré-requisito: carga de Identidade e Contato (lojista 81..200, endereco 1..330)
-- Volumes: loja (120), categoria (600), produto (600), produto_categoria (720)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. LOJA (120 registros via generate_series)
--    1 loja para cada lojista (id_pessoa 81..200), usando endereços 1..120.
--    A Loja 1 preserva o CNPJ '12345678000195' para o teste de UK no 03_verificacao.
-- -----------------------------------------------------------------------------
INSERT INTO loja (
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
    80 + i,
    i,
    CASE WHEN i % 2 = 0 THEN 'Loja ' || i END,
    CASE
        WHEN i = 1 THEN '12345678000195'
        ELSE '10000000' || lpad(i::TEXT, 6, '0')
    END,
    (ARRAY['Mercado', 'Empório', 'Padaria', 'Quitanda', 'Bistrô', 'Armazém'])[1 + i % 6]
        || ' ' ||
    (ARRAY['Central', 'do Bairro', 'São Mateus', 'Real', 'Bom Pastor', 'Mineiro'])[1 + (i / 6) % 6]
        || ' #' || i,
    '3232' || lpad((100000 + i)::TEXT, 6, '0'),
    (ARRAY['aberta', 'aberta', 'aberta', 'fechada']::status_funcionamento[])[1 + i % 4],
    20 + (i % 40),
    ROUND((4.00 + (i % 10) * 0.75)::NUMERIC, 2)
FROM generate_series(1, 120) AS g(i);


-- -----------------------------------------------------------------------------
-- 2. CATEGORIA (600 registros: 120 lojas x 5 categorias via generate_series)
-- -----------------------------------------------------------------------------
INSERT INTO categoria (id_loja, nome)
SELECT
    l.id_loja,
    (ARRAY['Bebidas', 'Padaria', 'Mercearia', 'Lanches', 'Ofertas'])[c.ordem]
FROM loja l
CROSS JOIN generate_series(1, 5) AS c(ordem)
ORDER BY l.id_loja, c.ordem;


-- -----------------------------------------------------------------------------
-- 3. PRODUTO (600 registros: 120 lojas x 5 produtos via generate_series)
--    Produtos de ordem 5 em lojas múltiplas de 4 ficam inativos (ativo = FALSE).
-- -----------------------------------------------------------------------------
INSERT INTO produto (id_loja, nome, descricao, preco, ativo)
SELECT
    l.id_loja,
    (ARRAY[
        'Água mineral 500 ml',
        'Pão de queijo 400 g',
        'Arroz tipo 1 5 kg',
        'Sanduíche natural',
        'Combo promocional'
    ])[p.ordem] || ' - Loja ' || l.id_loja,
    'Produto de catálogo #' || p.ordem || ' da loja ' || l.id_loja,
    ROUND((5.50 + ((l.id_loja + p.ordem) % 25) * 1.75)::NUMERIC, 2),
    NOT (p.ordem = 5 AND l.id_loja % 4 = 0)
FROM loja l
CROSS JOIN generate_series(1, 5) AS p(ordem)
ORDER BY l.id_loja, p.ordem;


-- -----------------------------------------------------------------------------
-- 4. PRODUTO_CATEGORIA (720 registros)
--    Cada um dos 600 produtos recebe sua categoria correspondente (1..5),
--    e o 1º produto de cada uma das 120 lojas também recebe a categoria 'Ofertas'.
-- -----------------------------------------------------------------------------
WITH produtos_ord AS (
    SELECT
        id_loja,
        id_produto,
        ROW_NUMBER() OVER (PARTITION BY id_loja ORDER BY id_produto) AS ordem
    FROM produto
),
categorias_ord AS (
    SELECT
        id_loja,
        id_categoria,
        ROW_NUMBER() OVER (PARTITION BY id_loja ORDER BY id_categoria) AS ordem
    FROM categoria
)
INSERT INTO produto_categoria (id_loja, id_produto, id_categoria)
SELECT
    p.id_loja,
    p.id_produto,
    c.id_categoria
FROM produtos_ord p
JOIN categorias_ord c
  ON c.id_loja = p.id_loja
 AND c.ordem = p.ordem

UNION ALL

SELECT
    p.id_loja,
    p.id_produto,
    c.id_categoria
FROM produtos_ord p
JOIN categorias_ord c
  ON c.id_loja = p.id_loja
 AND c.ordem = 5
WHERE p.ordem = 1;

COMMIT;

-- -----------------------------------------------------------------------------
-- 5. Estatísticas para o planejador de consultas (ANALYZE)
-- -----------------------------------------------------------------------------
ANALYZE VERBOSE loja;
ANALYZE VERBOSE categoria;
ANALYZE VERBOSE produto;
ANALYZE VERBOSE produto_categoria;

-- Resultado observado do ANALYZE VERBOSE (PostgreSQL 18):
-- loja:              2 pages | 120 live rows | 0 dead rows | 120 rows in sample | 120 estimated total rows
-- categoria:         4 pages | 600 live rows | 0 dead rows | 600 rows in sample | 600 estimated total rows
-- produto:           9 pages | 600 live rows | 0 dead rows | 600 rows in sample | 600 estimated total rows
-- produto_categoria: 5 pages | 720 live rows | 0 dead rows | 720 rows in sample | 720 estimated total rows
