-- =================================================================================
-- SCRIPT DE CARGA DE DADOS - SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- Arquivo: 02_carga_comercio_financas.sql
-- Objetivo: Popular pedido, item_pedido, divisao_pagamento, avaliacao_loja e
--           avaliacao_entregador antes da criação das triggers (06_triggers.sql),
--           respeitando todas as restrições de DDL (PK, FK, FK composta, CHECK)
--           e mantendo coerência com as regras de negócio (RR03, RR09, RR10, RN05-RN07).
-- Pré-requisitos: tabelas loja, cliente, pessoa_endereco e produto já populadas.
-- =================================================================================

-- 1. CARGA MASSIVA NA TABELA PEDIDO (200.000 linhas)
-- Inicializa subtotal = 0.00 e valor_total = taxa_entrega + taxa_servico para atender
-- ao CHECK de valor_total; ambos são recalculados no Passo 3 após inserir os itens.
-- Os pares (id_cliente, id_endereco) vêm de cliente JOIN pessoa_endereco (RR03),
-- e as lojas são filtradas para aquelas que possuem ao menos 1 produto ativo.
WITH lojas_ativas AS (
    SELECT
        ARRAY_AGG(l.id_loja ORDER BY l.id_loja) AS ids_loja,
        ARRAY_AGG(l.taxa_entrega ORDER BY l.id_loja) AS taxas_entrega
    FROM loja l
    WHERE EXISTS (
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
        (floor(random() * cardinality(la.ids_loja))::INT + 1) AS idx_loja,
        (floor(random() * cardinality(ce.ids_cliente))::INT + 1) AS idx_ce,
        (ARRAY['solicitado', 'aceito', 'em_preparacao', 'pronto', 'concluido']::status_pedido[])[floor(random() * 5 + 1)::INT] AS status_sorteado,
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
    ids_loja[idx_loja],
    ids_cliente[idx_ce],
    ids_endereco[idx_ce],
    complementos[idx_ce],
    referencias[idx_ce],
    status_sorteado,
    data_sorteada,
    forma_pagamento_sorteada,
    0.00,
    taxas_entrega[idx_loja],
    2.50,
    taxas_entrega[idx_loja] + 2.50
FROM sorteio;


-- 2. CARGA NA TABELA ITEM_PEDIDO (1 a 3 itens distintos por pedido)
-- Seleciona produtos reais e ativos da mesma loja do pedido (RN07 / FK composta)
-- usando aritmética modular para evitar colisão de PK (id_pedido, id_produto) e
-- copia o preço atual do produto para valor_unitario (snapshot RR09).
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
        p.id_pedido,
        p.id_loja,
        (((p.id_pedido + gs.n) % tl.total_produtos) + 1) AS rn_escolhido,
        floor(random() * 3 + 1)::INT AS quantidade
    FROM pedido p
    JOIN totais_loja tl ON tl.id_loja = p.id_loja
    CROSS JOIN LATERAL generate_series(1, LEAST(tl.total_produtos, floor(random() * 3 + 1)::INT)) AS gs(n)
)
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
SELECT
    pi.id_pedido,
    pn.id_produto,
    pi.id_loja,
    pi.quantidade,
    pn.preco
FROM pedidos_itens pi
JOIN produtos_numerados pn
  ON pn.id_loja = pi.id_loja
 AND pn.rn = pi.rn_escolhido;


-- 3. ATUALIZAÇÃO DE SUBTOTAL E VALOR_TOTAL NA TABELA PEDIDO (Coerência RR10)
-- Consolida a soma real de (quantidade * valor_unitario) dos itens de cada pedido.
UPDATE pedido p
SET
    subtotal = s.subtotal_calculado,
    valor_total = s.subtotal_calculado + p.taxa_entrega + p.taxa_servico
FROM (
    SELECT
        id_pedido,
        SUM(quantidade * valor_unitario) AS subtotal_calculado
    FROM item_pedido
    GROUP BY id_pedido
) s
WHERE p.id_pedido = s.id_pedido;


-- 4. CARGA NA TABELA DIVISAO_PAGAMENTO
-- Gerada apenas para pedidos concluídos, após o recálculo do subtotal/valor_total.
-- Garante (parcela_loja + comissao_entregador + taxa_plataforma) = valor_total (RN05).
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
    data_pedido + (random() * INTERVAL '2 hours') AS calculada_em
FROM pedido
WHERE status = 'concluido';


-- 5. CARGA NA TABELA AVALIACAO_LOJA
-- Sorteia até 1.500 pedidos concluídos com nota inteira de 1 a 5 (RN06).
WITH aval_loja_base AS (
    SELECT
        id_pedido,
        floor(random() * 5 + 1)::SMALLINT AS nota_sorteada,
        data_pedido + (random() * INTERVAL '5 days') AS data_aval
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
-- Sorteia até 1.500 pedidos concluídos com nota inteira de 1 a 5 (RN06).
WITH aval_entregador_base AS (
    SELECT
        id_pedido,
        floor(random() * 5 + 1)::SMALLINT AS nota_sorteada,
        data_pedido + (random() * INTERVAL '2 days') AS data_aval
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


-- 7. ATUALIZAÇÃO DE ESTATÍSTICAS DO OTIMIZADOR (ANALYZE)
ANALYZE VERBOSE pedido;
ANALYZE VERBOSE item_pedido;
ANALYZE VERBOSE divisao_pagamento;
ANALYZE VERBOSE avaliacao_loja;
ANALYZE VERBOSE avaliacao_entregador;

-- Resultado observado do ANALYZE VERBOSE (PostgreSQL 18):
-- pedido:               7273 pages | 200000 live rows | 200000 dead rows (devido ao UPDATE de subtotal/valor_total) | 30000 rows in sample | 200000 estimated total rows
-- item_pedido:          3334 pages | 400000 live rows | 0 dead rows | 30000 rows in sample | 400000 estimated total rows
-- divisao_pagamento:     357 pages |  39910 live rows | 0 dead rows | 30000 rows in sample |  39910 estimated total rows
-- avaliacao_loja:         14 pages |   1500 live rows | 0 dead rows |  1500 rows in sample |   1500 estimated total rows
-- avaliacao_entregador:   14 pages |   1500 live rows | 0 dead rows |  1500 rows in sample |   1500 estimated total rows
