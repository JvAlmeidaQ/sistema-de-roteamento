-- =============================================================================
-- 02_carga.sql — Povoamento completo da base de dados (E4)
-- Pré-requisito: 01_esquema.sql executado em banco vazio
--
-- Subdomínio 1: Identidade e Contato
--
-- Divisão de papéis (especialização total e sobreposta — Seção 2):
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

-- Semente fixa para tornar a carga pseudoaleatória 100% reproduzível entre execuções
-- sem introduzir padrões periódicos artificiais nos experimentos.
SELECT setseed(0.42);

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
--    Usa 10 CEPs compartilhados (1 por bairro) para evidenciar a redundância
--    transitiva cep -> cidade, estado; numero é único, evitando colisão na UQ.
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
    (ARRAY['36010010', '36025000', '36033300', '36010500', '36021300',
           '36026000', '36036900', '36090000', '36030000', '36045000'])[1 + i % 10],
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
--     relação N:N). O complemento é individual de cada morador (Seção 2).
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
-- 4a. Todas as pessoas têm um celular (ao menos um telefone por pessoa).
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
-- 5. Papéis (especialização total: toda pessoa assume ao menos um papel)
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
-- 6. Endereço atual do cliente (FK composta -> pessoa_endereco, Seção 2)
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


-- =============================================================================
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- Pré-requisito: cargas de Identidade e Contato e Catálogo executadas.
-- =============================================================================

BEGIN;

-- 1. PREPARAÇÃO DOS PEDIDOS E ITENS ANTES DA INSERÇÃO (evita UPDATE posterior e bloat em pedido)
CREATE TEMP TABLE carga_comercio_pedidos ON COMMIT DROP AS
WITH lojas_ativas AS (
    SELECT
        ARRAY_AGG(l.id_loja ORDER BY l.id_loja) AS ids_loja,
        ARRAY_AGG(l.taxa_entrega ORDER BY l.id_loja) AS taxas_entrega
    FROM loja l
    WHERE l.status_funcionamento = 'aberta'
      AND EXISTS (
        SELECT 1
        FROM produto pr
        WHERE pr.id_loja = l.id_loja
          AND pr.ativo = TRUE
    )
),
clientes_enderecos AS (
    SELECT
        ARRAY_AGG(c.id_pessoa ORDER BY c.id_pessoa, pe.id_endereco) AS ids_cliente,
        ARRAY_AGG(pe.id_endereco ORDER BY c.id_pessoa, pe.id_endereco) AS ids_endereco,
        ARRAY_AGG(pe.complemento ORDER BY c.id_pessoa, pe.id_endereco) AS complementos,
        ARRAY_AGG(pe.referencia ORDER BY c.id_pessoa, pe.id_endereco) AS referencias
    FROM cliente c
    JOIN pessoa_endereco pe ON pe.id_pessoa = c.id_pessoa
),
sorteio AS (
    SELECT
        gs AS seq_pedido,
        (floor(random() * cardinality(la.ids_loja))::INT + 1) AS idx_loja,
        (floor(random() * cardinality(ce.ids_cliente))::INT + 1) AS idx_ce,
        (ARRAY['solicitado', 'aceito', 'recusado', 'pago', 'em_preparacao', 'pronto', 'concluido']::status_pedido[])[floor(random() * 7 + 1)::INT] AS status_sorteado,
        CURRENT_TIMESTAMP - (random() * INTERVAL '365 days') AS data_sorteada,
        (ARRAY['pix', 'cartao_credito', 'cartao_debito', 'dinheiro']::forma_pagamento[])[floor(random() * 4 + 1)::INT] AS forma_pagamento_sorteada,
        la.ids_loja,
        la.taxas_entrega,
        ce.ids_cliente,
        ce.ids_endereco,
        ce.complementos,
        ce.referencias
    FROM generate_series(1, 200000) AS gs
    CROSS JOIN lojas_ativas la
    CROSS JOIN clientes_enderecos ce
)
SELECT
    seq_pedido,
    ids_loja[idx_loja] AS id_loja,
    ids_cliente[idx_ce] AS id_cliente,
    ids_endereco[idx_ce] AS id_endereco,
    complementos[idx_ce] AS complemento_entrega,
    referencias[idx_ce] AS referencia_entrega,
    status_sorteado AS status,
    data_sorteada AS data_pedido,
    forma_pagamento_sorteada AS forma_pagamento,
    taxas_entrega[idx_loja] AS taxa_entrega,
    2.50::NUMERIC(12,2) AS taxa_servico
FROM sorteio;

CREATE TEMP TABLE carga_comercio_itens ON COMMIT DROP AS
WITH produtos_numerados AS (
    SELECT
        id_loja,
        id_produto,
        preco,
        ROW_NUMBER() OVER (PARTITION BY id_loja ORDER BY id_produto) AS rn
    FROM produto
    WHERE ativo = TRUE
),
totais_loja AS (
    SELECT
        id_loja,
        COUNT(*)::INT AS total_produtos
    FROM produtos_numerados
    GROUP BY id_loja
),
pedidos_itens AS (
    SELECT
        cp.seq_pedido,
        cp.id_loja,
        (((cp.seq_pedido + gs.n) % tl.total_produtos) + 1) AS rn_escolhido,
        floor(random() * 3 + 1)::INT AS quantidade
    FROM carga_comercio_pedidos cp
    JOIN totais_loja tl ON tl.id_loja = cp.id_loja
    CROSS JOIN LATERAL generate_series(1, LEAST(tl.total_produtos, floor(random() * 3 + 1)::INT)) AS gs(n)
)
SELECT
    pi.seq_pedido,
    pn.id_produto,
    pi.id_loja,
    pi.quantidade,
    pn.preco AS valor_unitario
FROM pedidos_itens pi
JOIN produtos_numerados pn
  ON pn.id_loja = pi.id_loja
 AND pn.rn = pi.rn_escolhido;


-- 2. CARGA MASSIVA NA TABELA PEDIDO (200.000 linhas já com subtotal e valor_total calculados — RR10)
INSERT INTO pedido (
    id_loja,
    id_cliente,
    id_endereco,
    complemento_entrega,
    referencia_entrega,
    status,
    data_pedido,
    forma_pagamento,
    subtotal,
    taxa_entrega,
    taxa_servico,
    valor_total
)
SELECT
    cp.id_loja,
    cp.id_cliente,
    cp.id_endereco,
    cp.complemento_entrega,
    cp.referencia_entrega,
    cp.status,
    cp.data_pedido,
    cp.forma_pagamento,
    s.subtotal_calculado,
    cp.taxa_entrega,
    cp.taxa_servico,
    s.subtotal_calculado + cp.taxa_entrega + cp.taxa_servico
FROM carga_comercio_pedidos cp
JOIN (
    SELECT
        seq_pedido,
        SUM(quantidade * valor_unitario) AS subtotal_calculado
    FROM carga_comercio_itens
    GROUP BY seq_pedido
) s ON s.seq_pedido = cp.seq_pedido
ORDER BY cp.seq_pedido;


-- 3. CARGA NA TABELA ITEM_PEDIDO (1 a 3 itens distintos por pedido)
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
SELECT
    seq_pedido,
    id_produto,
    id_loja,
    quantidade,
    valor_unitario
FROM carga_comercio_itens;


-- 4. CARGA NA TABELA DIVISAO_PAGAMENTO
--    Nota: 0.85 (85% para a loja, 15% taxa da plataforma sobre o subtotal) é um
--    parâmetro fixo de regra de negócio da plataforma (não é atributo armazenado no banco).
INSERT INTO divisao_pagamento (
    id_pedido,
    valor_total,
    parcela_loja,
    comissao_entregador,
    taxa_plataforma,
    calculada_em
)
SELECT
    id_pedido,
    valor_total,
    ROUND(subtotal * 0.85, 2) AS parcela_loja,
    taxa_entrega AS comissao_entregador,
    (valor_total - ROUND(subtotal * 0.85, 2) - taxa_entrega) AS taxa_plataforma,
    data_pedido + INTERVAL '65 minutes' + (random() * INTERVAL '2 hours') AS calculada_em
FROM pedido
WHERE status = 'concluido';


-- 5. CARGA NA TABELA AVALIACAO_LOJA
WITH aval_loja_base AS (
    SELECT
        id_pedido,
        floor(random() * 5 + 1)::SMALLINT AS nota_sorteada,
        data_pedido + INTERVAL '2 hours' + (random() * INTERVAL '5 days') AS data_aval
    FROM pedido
    WHERE status = 'concluido'
    ORDER BY random()
    LIMIT 1500
)
INSERT INTO avaliacao_loja (id_pedido, nota, comentario, data_avaliacao)
SELECT
    id_pedido,
    nota_sorteada,
    CASE nota_sorteada
        WHEN 1 THEN (ARRAY['Péssima experiência.', 'Chegou tudo revirado.', 'Faltou item no meu pedido.'])[floor(random() * 3 + 1)::INT]
        WHEN 2 THEN (ARRAY['Deixou muito a desejar.', 'Comida fria.', 'Atrasou bastante.'])[floor(random() * 3 + 1)::INT]
        WHEN 3 THEN (ARRAY['Ok, mas nada demais.', 'Pelo preço, esperava mais.', 'Mediano.'])[floor(random() * 3 + 1)::INT]
        WHEN 4 THEN (ARRAY['Muito bom!', 'Gostei bastante, recomendo.', 'Comida saborosa e quentinha.'])[floor(random() * 3 + 1)::INT]
        WHEN 5 THEN (ARRAY['Excelente! Comprarei novamente.', 'Perfeito, prato delicioso!', 'A melhor loja do app.'])[floor(random() * 3 + 1)::INT]
    END AS comentario,
    data_aval
FROM aval_loja_base;


-- 6. CARGA NA TABELA AVALIACAO_ENTREGADOR
WITH aval_entregador_base AS (
    SELECT
        id_pedido,
        floor(random() * 5 + 1)::SMALLINT AS nota_sorteada,
        data_pedido + INTERVAL '2 hours' + (random() * INTERVAL '2 days') AS data_aval
    FROM pedido
    WHERE status = 'concluido'
    ORDER BY random()
    LIMIT 1500
)
INSERT INTO avaliacao_entregador (id_pedido, nota, comentario, data_avaliacao)
SELECT
    id_pedido,
    nota_sorteada,
    CASE nota_sorteada
        WHEN 1 THEN (ARRAY['Entregador grosseiro.', 'Derramou meu refrigerante.', 'Se recusou a subir.'])[floor(random() * 3 + 1)::INT]
        WHEN 2 THEN (ARRAY['Demorou muito para achar o endereço.', 'Falta de educação.', 'Veio sem a bag térmica.'])[floor(random() * 3 + 1)::INT]
        WHEN 3 THEN (ARRAY['Entrega normal.', 'Ok.', 'Fez o básico.'])[floor(random() * 3 + 1)::INT]
        WHEN 4 THEN (ARRAY['Muito educado.', 'Chegou no tempo certo.', 'Gente boa, respeitou a portaria.'])[floor(random() * 3 + 1)::INT]
        WHEN 5 THEN (ARRAY['Entregador super rápido e simpático!', 'Excelente atendimento.', 'Chegou voando, nota 10!'])[floor(random() * 3 + 1)::INT]
    END AS comentario,
    data_aval
FROM aval_entregador_base;

COMMIT;


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- Pré-requisito: cargas de Identidade e Contato (entregador) e Comércio e
--                Finanças (pedido) executadas, antes dos gatilhos.
-- =============================================================================

BEGIN;

CREATE TEMP TABLE carga_logistica_pedidos ON COMMIT DROP AS
WITH qtd_entregadores AS (
    SELECT COUNT(*)::INT AS total FROM entregador
),
candidatos AS (
    SELECT p.id_pedido, p.status, p.data_pedido,
           ROW_NUMBER() OVER (PARTITION BY p.status ORDER BY p.id_pedido) AS numero
    FROM pedido p
    WHERE p.status IN ('pronto', 'concluido')
      AND NOT EXISTS (SELECT 1 FROM entrega e WHERE e.id_pedido = p.id_pedido)
)
SELECT c.id_pedido,
       c.data_pedido,
       CASE WHEN c.status = 'concluido' THEN 'entregue'
            WHEN c.numero <= qe.total * 2 AND c.numero % 2 = 1 THEN 'aceita'
            WHEN c.numero <= qe.total * 2 AND c.numero % 2 = 0 THEN 'a_caminho'
            ELSE 'aguardando_entregador' END::status_entrega AS status
FROM candidatos c
CROSS JOIN qtd_entregadores qe
WHERE c.status = 'concluido' OR c.numero % 5 <> 0;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM entregador)
       OR NOT EXISTS (SELECT 1 FROM carga_logistica_pedidos) THEN
        RAISE EXCEPTION 'Carga logística exige entregadores e pedidos prontos/concluídos sem entrega';
    END IF;
END;
$$;

CREATE TEMP TABLE carga_logistica_vinculos ON COMMIT DROP AS
SELECT id_pedido, data_pedido, status = 'entregue' AS encerrada,
       (ROW_NUMBER() OVER (PARTITION BY (status = 'entregue') ORDER BY id_pedido) + 1) / 2 AS numero_rota
FROM carga_logistica_pedidos
WHERE status <> 'aguardando_entregador';

CREATE TEMP TABLE carga_logistica_rotas ON COMMIT DROP AS
WITH entregadores AS (
    SELECT ARRAY_AGG(id_pessoa ORDER BY id_pessoa) AS ids FROM entregador
), grupos AS (
    SELECT encerrada,
           numero_rota,
           MIN(data_pedido) AS min_data_pedido,
           MAX(data_pedido) AS max_data_pedido
    FROM carga_logistica_vinculos
    GROUP BY encerrada, numero_rota
), novas AS (
    INSERT INTO rota (id_entregador, criada_em, encerrada_em)
    SELECT en.ids[((gr.numero_rota - 1) % cardinality(en.ids) + 1)::INT],
           gr.min_data_pedido + INTERVAL '25 minutes',
           CASE WHEN gr.encerrada THEN gr.max_data_pedido + INTERVAL '60 minutes' END
    FROM grupos gr
    CROSS JOIN entregadores en
    ORDER BY gr.encerrada, gr.numero_rota
    RETURNING id_rota, encerrada_em
)
SELECT id_rota, encerrada_em IS NOT NULL AS encerrada,
       ROW_NUMBER() OVER (PARTITION BY (encerrada_em IS NOT NULL) ORDER BY id_rota) AS numero_rota
FROM novas;

INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega)
SELECT p.id_pedido, r.id_rota, p.status,
       p.data_pedido + INTERVAL '45 minutes'
FROM carga_logistica_pedidos p
LEFT JOIN carga_logistica_vinculos v USING (id_pedido)
LEFT JOIN carga_logistica_rotas r USING (encerrada, numero_rota);

COMMIT;


-- =============================================================================
-- SUBDOMÍNIO: AUDITORIA
-- Regras de reconstituição da trilha cronológica (RN04, RN12, Seção 2):
--   - Pedidos recusados:  solicitado -> recusado (2 eventos).
--   - Pedidos normais:    solicitado -> aceito -> pago -> em_preparacao
--                         -> pronto -> concluido (1 a 6 eventos).
--   - Entregas:           aguardando_entregador -> aceita -> a_caminho
--                         -> entregue (1 a 4 eventos), iniciando quando o
--                         pedido fica 'pronto' (data_pedido + 22 min).
--   - Sincronização:      pedidos 'concluido' compartilham o mesmo timestamp
--                         de 'entregue' da sua entrega; 20% das entregas
--                         concluídas (id_entrega % 5 = 0) simulam atraso real
--                         para alimentar relatórios de SLA.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Historico_Pedido (trilha cronológica do ciclo comercial)
-- -----------------------------------------------------------------------------

-- 1a. Pedidos recusados: gera apenas 'solicitado' e 'recusado'.
INSERT INTO historico_pedido (id_pedido, status, data_hora)
SELECT
    p.id_pedido,
    etapa.status,
    p.data_pedido + etapa.deslocamento
FROM pedido p
CROSS JOIN (
    VALUES
        ('solicitado'::status_pedido, INTERVAL '0 minutes'),
        ('recusado'::status_pedido,   INTERVAL '3 minutes')
) AS etapa(status, deslocamento)
WHERE p.status = 'recusado';

-- 1b. Pedidos do fluxo normal: gera eventos cumulativos até o status atual.
--     Quando o pedido está 'concluido', alinha o timestamp com o término
--     da entrega correspondente.
INSERT INTO historico_pedido (id_pedido, status, data_hora)
SELECT
    p.id_pedido,
    etapa.status,
    CASE
        WHEN etapa.status = 'concluido' AND e.id_entrega IS NOT NULL THEN
            CASE
                WHEN e.id_entrega % 5 = 0 THEN
                    GREATEST(p.data_pedido + INTERVAL '33 minutes', e.previsao_entrega + INTERVAL '12 minutes')
                ELSE
                    GREATEST(
                        p.data_pedido + INTERVAL '33 minutes',
                        LEAST(p.data_pedido + INTERVAL '45 minutes', e.previsao_entrega - INTERVAL '2 minutes')
                    )
            END
        ELSE p.data_pedido + etapa.deslocamento
    END
FROM pedido p
LEFT JOIN entrega e
    ON e.id_pedido = p.id_pedido
CROSS JOIN (
    VALUES
        (1, 'solicitado'::status_pedido,    INTERVAL '0 minutes'),
        (2, 'aceito'::status_pedido,        INTERVAL '2 minutes'),
        (3, 'pago'::status_pedido,          INTERVAL '5 minutes'),
        (4, 'em_preparacao'::status_pedido, INTERVAL '8 minutes'),
        (5, 'pronto'::status_pedido,        INTERVAL '22 minutes'),
        (6, 'concluido'::status_pedido,     INTERVAL '45 minutes')
) AS etapa(ordem, status, deslocamento)
WHERE p.status <> 'recusado'
  AND etapa.ordem <= CASE p.status
      WHEN 'solicitado'    THEN 1
      WHEN 'aceito'        THEN 2
      WHEN 'pago'          THEN 3
      WHEN 'em_preparacao' THEN 4
      WHEN 'pronto'        THEN 5
      WHEN 'concluido'     THEN 6
  END;

-- -----------------------------------------------------------------------------
-- 2. Historico_Entrega (trilha cronológica do ciclo logístico)
--    A entrega nasce no instante em que o pedido fica 'pronto' (RN12),
--    equivalente a data_pedido + 22 minutos.
-- -----------------------------------------------------------------------------

-- 2a. Etapas até 'a_caminho' (aguardando_entregador, aceita, a_caminho).
INSERT INTO historico_entrega (id_entrega, status, data_hora)
SELECT
    e.id_entrega,
    etapa.status,
    p.data_pedido + INTERVAL '22 minutes' + etapa.deslocamento
FROM entrega e
INNER JOIN pedido p
    ON p.id_pedido = e.id_pedido
CROSS JOIN (
    VALUES
        (1, 'aguardando_entregador'::status_entrega, INTERVAL '0 minutes'),
        (2, 'aceita'::status_entrega,                INTERVAL '3 minutes'),
        (3, 'a_caminho'::status_entrega,             INTERVAL '7 minutes')
) AS etapa(ordem, status, deslocamento)
WHERE etapa.ordem <= CASE e.status
    WHEN 'aguardando_entregador' THEN 1
    WHEN 'aceita'                THEN 2
    WHEN 'a_caminho'             THEN 3
    WHEN 'entregue'              THEN 3
END;

-- 2b. Etapa final ('entregue'): 20% das entregas concluídas recebem carimbo
--     posterior à previsao_entrega (atraso) e 80% concluem dentro do prazo.
INSERT INTO historico_entrega (id_entrega, status, data_hora)
SELECT
    e.id_entrega,
    'entregue'::status_entrega,
    CASE
        WHEN e.id_entrega % 5 = 0 THEN
            GREATEST(p.data_pedido + INTERVAL '33 minutes', e.previsao_entrega + INTERVAL '12 minutes')
        ELSE
            GREATEST(
                p.data_pedido + INTERVAL '33 minutes',
                LEAST(p.data_pedido + INTERVAL '45 minutes', e.previsao_entrega - INTERVAL '2 minutes')
            )
    END
FROM entrega e
INNER JOIN pedido p
    ON p.id_pedido = e.id_pedido
WHERE e.status = 'entregue';

COMMIT;

ANALYZE;
