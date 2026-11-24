-- =============================================================================
-- CONSULTAS SQL — ENTREGA E5 (SEÇÃO 6)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Comércio e Finanças -> Logística
-- (mesma sequência de 01_esquema.sql).
-- =============================================================================

-- =============================================================================
-- SUBDOMÍNIO: IDENTIDADE E CONTATO
-- =============================================================================

-- Consulta 1: "Quais pessoas são, ao mesmo tempo, Cliente e Entregador e possuem pelo menos um telefone de cada tipo cadastrado no sistema?"
-- Ator: Operação / Administração da plataforma (Consulta 2 da E3).
-- Técnica: Divisão relacional com subconsulta correlacionada (duplo NOT EXISTS) e interseção via INNER JOIN.
-- Tabelas: pessoa, cliente, entregador, telefone.
SELECT p.id_pessoa,
       p.nome,
       e.tipo_veiculo
  FROM pessoa p
INNER JOIN cliente c
        ON c.id_pessoa = p.id_pessoa
INNER JOIN entregador e
        ON e.id_pessoa = p.id_pessoa
 WHERE NOT EXISTS (
           SELECT 1
             FROM (SELECT DISTINCT tipo FROM telefone) tipos
            WHERE NOT EXISTS (
                      SELECT 1
                        FROM telefone t
                       WHERE t.id_pessoa = p.id_pessoa
                         AND t.tipo = tipos.tipo
                  )
       )
 ORDER BY p.id_pessoa;

-- Consulta 2: "Quais são todos os clientes, com o logradouro e o número do seu endereço atual, incluindo os que ainda não escolheram um endereço?"
-- Ator: Atendimento / Operação.
-- Técnica: Junção externa (LEFT JOIN) preservando clientes sem endereço atual (id_endereco_atual NULL).
-- Tabelas: cliente, pessoa, endereco.
SELECT c.id_pessoa,
       p.nome,
       e.logradouro,
       e.numero
  FROM cliente c
INNER JOIN pessoa p
        ON p.id_pessoa = c.id_pessoa
 LEFT JOIN endereco e
        ON e.id_endereco = c.id_endereco_atual
 ORDER BY c.id_pessoa;

-- Consulta 3: "Quais endereços são compartilhados por mais de uma pessoa, e quantas pessoas estão vinculadas a cada um deles?"
-- Ator: Análise de dados / Suporte.
-- Técnica: Agrupamento com GROUP BY e filtro de grupo com HAVING.
-- Tabelas: endereco, pessoa_endereco.
SELECT e.id_endereco,
       e.logradouro,
       e.numero,
       e.bairro,
       COUNT(*) AS moradores
  FROM endereco e
INNER JOIN pessoa_endereco pe
        ON pe.id_endereco = e.id_endereco
 GROUP BY e.id_endereco, e.logradouro, e.numero, e.bairro
HAVING COUNT(*) > 1
 ORDER BY e.id_endereco;

-- Consulta 4: "Quais são os entregadores cadastrados (nome, e-mail e tipo de veículo)?"
-- Ator: Operação logística / Administração.
-- Técnica: Junção escrita de quatro formas distintas (INNER JOIN ON, INNER JOIN USING, NATURAL JOIN e produto cartesiano com seleção no WHERE).
-- Tabelas: pessoa, entregador.

-- Forma 1 — INNER JOIN ... ON
SELECT p.id_pessoa,
       p.nome,
       p.email,
       e.tipo_veiculo
  FROM pessoa p
INNER JOIN entregador e
        ON e.id_pessoa = p.id_pessoa
 ORDER BY p.id_pessoa;

-- Forma 2 — INNER JOIN ... USING
SELECT id_pessoa,
       p.nome,
       p.email,
       e.tipo_veiculo
  FROM pessoa p
INNER JOIN entregador e
     USING (id_pessoa)
 ORDER BY id_pessoa;

-- Forma 3 — NATURAL JOIN
SELECT id_pessoa,
       nome,
       email,
       tipo_veiculo
  FROM pessoa
NATURAL JOIN entregador
 ORDER BY id_pessoa;

-- Forma 4 — Produto cartesiano + seleção (FROM com vírgula e condição no WHERE)
SELECT p.id_pessoa,
       p.nome,
       p.email,
       e.tipo_veiculo
  FROM pessoa p,
       entregador e
 WHERE p.id_pessoa = e.id_pessoa
 ORDER BY p.id_pessoa;


-- =============================================================================
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =============================================================================

-- Consulta 5: "Quais lojas (nome e CNPJ) já tiveram pedidos concluídos com todas as formas de pagamento usadas na plataforma?"
-- Ator: Administração financeira / Comercial (Consulta 8 da E3, RF05).
-- Técnica: Divisão relacional por dupla negação (NOT EXISTS / NOT EXISTS) com subconsulta correlacionada.
-- Tabelas: loja, pedido.
SELECT l.id_loja,
       l.nome,
       l.cnpj
  FROM loja l
 WHERE NOT EXISTS (
           SELECT 1
             FROM (SELECT DISTINCT forma_pagamento
                     FROM pedido
                    WHERE status = 'concluido') formas
            WHERE NOT EXISTS (
                      SELECT 1
                        FROM pedido p
                       WHERE p.id_loja = l.id_loja
                         AND p.status = 'concluido'
                         AND p.forma_pagamento = formas.forma_pagamento
                  )
       )
 ORDER BY l.id_loja;

-- Consulta 6: "Quais pedidos (exibindo id_pedido e valor_total) geraram comissão ao entregador estritamente maior que a parcela repassada à loja?"
-- Ator: Auditoria financeira / Administração (Consulta 9 da E3, RN05).
-- Técnica: Seleção e projeção sobre a divisão de pagamento.
-- Tabelas: divisao_pagamento.
SELECT dp.id_pedido,
       dp.valor_total
  FROM divisao_pagamento dp
 WHERE dp.comissao_entregador > dp.parcela_loja
 ORDER BY dp.id_pedido;

-- Consulta 7: "Quais pedidos tiveram valor total superior a R$ 100,00 e receberam avaliação ruim da loja (nota 1 ou 2)?"
-- Ator: Qualidade e suporte comercial (Consulta 10 da E3, RF06/RN06).
-- Técnica: Junção interna (INNER JOIN) com filtros de valor e nota.
-- Tabelas: pedido, avaliacao_loja.
SELECT p.id_pedido,
       p.id_loja,
       p.valor_total,
       al.nota
  FROM pedido p
INNER JOIN avaliacao_loja al
        ON al.id_pedido = p.id_pedido
 WHERE p.valor_total > 100.00
   AND al.nota <= 2
 ORDER BY p.id_pedido;

-- Consulta 8: "Quais pedidos já foram entregues, mas ainda não receberam a avaliação da loja, do entregador ou de ambos? Mostrar o identificador do pedido e do cliente."
-- Ator: Engajamento / Pós-venda (Consulta 11 da E3, RF06/RN13).
-- Técnica: Operações de conjuntos (INTERSECT e EXCEPT) combinadas com INNER JOIN em pedido.
-- Tabelas: entrega, avaliacao_loja, avaliacao_entregador, pedido.
SELECT p.id_pedido,
       p.id_cliente
  FROM (
           SELECT e.id_pedido
             FROM entrega e
            WHERE e.status = 'entregue'
           EXCEPT
           (
               SELECT al.id_pedido FROM avaliacao_loja al
               INTERSECT
               SELECT ae.id_pedido FROM avaliacao_entregador ae
           )
       ) pendentes
INNER JOIN pedido p
        ON p.id_pedido = pendentes.id_pedido
 ORDER BY p.id_pedido;

-- Consulta 9: "Qual o pedido concluído de maior valor total?"
-- Ator: Administração financeira (Consulta 12 da E3).
-- Técnica: Subconsulta correlacionada com NOT EXISTS (tradução direta da álgebra relacional sem agregação).
-- Tabelas: pedido.
SELECT p1.id_pedido,
       p1.id_loja,
       p1.id_cliente,
       p1.valor_total
  FROM pedido p1
 WHERE p1.status = 'concluido'
   AND NOT EXISTS (
           SELECT 1
             FROM pedido p2
            WHERE p2.status = 'concluido'
              AND p2.valor_total > p1.valor_total
       )
 ORDER BY p1.id_pedido;

-- Consulta 10: "Quais clientes têm pelo menos um pedido concluído pago com Pix ou dinheiro e pelo menos um pago com cartão de crédito? Mostrar nome e e-mail."
-- Ator: Comercial / Marketing (Consulta 13 da E3).
-- Técnica: União (UNION), Interseção (INTERSECT) e junção interna com pessoa.
-- Tabelas: pedido, pessoa.
SELECT pe.id_pessoa,
       pe.nome,
       pe.email
  FROM (
           (
               SELECT p.id_cliente
                 FROM pedido p
                WHERE p.status = 'concluido'
                  AND p.forma_pagamento IN ('pix', 'dinheiro')
           )
           INTERSECT
           (
               SELECT p.id_cliente
                 FROM pedido p
                WHERE p.status = 'concluido'
                  AND p.forma_pagamento = 'cartao_credito'
           )
       ) clientes_alvo
INNER JOIN pessoa pe
        ON pe.id_pessoa = clientes_alvo.id_cliente
 ORDER BY pe.id_pessoa;

-- Consulta 11: "Quais são os pedidos concluídos com valor total acima de R$ 250,00 e a nota da avaliação da loja, incluindo os pedidos que ainda não foram avaliados?"
-- Ator: Qualidade / Pós-venda (RF06/RN06).
-- Técnica: Junção externa à direita (RIGHT JOIN) preservando pedidos concluídos sem avaliação registrada.
-- Tabelas: avaliacao_loja, pedido.
SELECT p.id_pedido,
       p.id_loja,
       p.valor_total,
       al.nota
  FROM avaliacao_loja al
 RIGHT JOIN pedido p
         ON p.id_pedido = al.id_pedido
 WHERE p.status = 'concluido'
   AND p.valor_total > 250.00
 ORDER BY p.valor_total DESC, p.id_pedido;

-- Consulta 12: "Quais lojas acumularam repasse líquido total (soma de parcela_loja nas divisões de pagamento) superior a R$ 15.000,00 em pedidos concluídos, e qual a quantidade de pedidos e o ticket médio de cada uma?"
-- Ator: Administração financeira / Lojista (RN05).
-- Técnica: Junções internas + agrupamento com GROUP BY e filtro agregado com HAVING.
-- Tabelas: loja, pedido, divisao_pagamento.
SELECT l.id_loja,
       l.nome,
       COUNT(dp.id_pedido) AS qtd_pedidos,
       SUM(dp.parcela_loja) AS repasse_total_loja,
       ROUND(AVG(dp.valor_total), 2) AS ticket_medio
  FROM loja l
INNER JOIN pedido p
        ON p.id_loja = l.id_loja
INNER JOIN divisao_pagamento dp
        ON dp.id_pedido = p.id_pedido
 WHERE p.status = 'concluido'
 GROUP BY l.id_loja, l.nome
HAVING SUM(dp.parcela_loja) > 15000.00
 ORDER BY repasse_total_loja DESC, l.id_loja;


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- Consulta 13: "Quais rotas têm duas entregas ativas e quais são elas?"
-- Ator: Operação logística (Consulta 14 da E3, RF04/RN02).
-- Técnica: Autojunção das entregas ativas da mesma rota via CTE (id_entrega_1 < id_entrega_2 elimina autopares).
-- Tabelas: entrega, rota.
WITH pendentes AS (
    SELECT id_entrega, id_rota
    FROM entrega
    WHERE status IN ('aceita', 'a_caminho')
)
SELECT r.id_rota,
       r.id_entregador,
       e1.id_entrega AS id_entrega_1,
       e2.id_entrega AS id_entrega_2
  FROM pendentes AS e1
INNER JOIN pendentes AS e2
        ON e1.id_rota = e2.id_rota
       AND e1.id_entrega < e2.id_entrega
INNER JOIN rota AS r
        ON r.id_rota = e1.id_rota
 ORDER BY r.id_rota, e1.id_entrega, e2.id_entrega;

-- Consulta 14: "Quais entregadores estão cadastrados e quais rotas abertas têm?"
-- Ator: Operação logística (Consulta 15 da E3, RF01/RF04).
-- Técnica: LEFT JOIN com filtro de rota aberta no ON para preservar entregadores sem rota aberta.
-- Tabelas: entregador, pessoa, rota.
SELECT DISTINCT
       p.nome,
       e.tipo_veiculo,
       r.id_rota
  FROM entregador AS e
INNER JOIN pessoa AS p
        ON p.id_pessoa = e.id_pessoa
 LEFT JOIN rota AS r
        ON r.id_entregador = e.id_pessoa
       AND r.encerrada_em IS NULL
 ORDER BY p.nome, e.tipo_veiculo, r.id_rota NULLS LAST;

-- Consulta 15: "Quais rotas possuem menos de duas entregas vinculadas?"
-- Ator: Operação logística (RN02/RR02).
-- Técnica: LEFT JOIN + GROUP BY + HAVING contando todos os vínculos de entrega da rota.
-- Tabelas: rota, entrega.
SELECT r.id_rota,
       r.id_entregador,
       r.encerrada_em,
       COUNT(e.id_entrega) AS total_entregas,
       2 - COUNT(e.id_entrega) AS vagas
  FROM rota AS r
 LEFT JOIN entrega AS e
        ON e.id_rota = r.id_rota
 GROUP BY r.id_rota, r.id_entregador, r.encerrada_em
HAVING COUNT(e.id_entrega) < 2
 ORDER BY r.id_rota;

-- Consulta 16: "Quais entregadores já concluíram pelo menos duas entregas?"
-- Ator: Gestor de Logística.
-- Técnica: Junções internas + GROUP BY + HAVING exigindo mínimo de duas entregas concluídas.
-- Tabelas: entregador, pessoa, rota, entrega.
SELECT en.id_pessoa AS id_entregador,
       p.nome,
       COUNT(e.id_entrega) AS entregas_concluidas
  FROM entregador AS en
INNER JOIN pessoa AS p
        ON p.id_pessoa = en.id_pessoa
INNER JOIN rota AS r
        ON r.id_entregador = en.id_pessoa
INNER JOIN entrega AS e
        ON e.id_rota = r.id_rota
 WHERE e.status = 'entregue'
 GROUP BY en.id_pessoa, p.nome
HAVING COUNT(e.id_entrega) >= 2
 ORDER BY entregas_concluidas DESC, en.id_pessoa;

-- Consulta 17: "Quais entregadores têm entregas ativas atrasadas?"
-- Ator: Operação logística (apoio à RN03/RR05).
-- Técnica: Subconsulta correlacionada com EXISTS filtrando previsões vencidas em status ativos.
-- Tabelas: entregador, pessoa, rota, entrega.
SELECT en.id_pessoa AS id_entregador,
       p.nome
  FROM entregador AS en
INNER JOIN pessoa AS p
        ON p.id_pessoa = en.id_pessoa
 WHERE EXISTS (
           SELECT 1
             FROM rota AS r
           INNER JOIN entrega AS e
                   ON e.id_rota = r.id_rota
            WHERE r.id_entregador = en.id_pessoa
              AND e.status IN ('aceita', 'a_caminho')
              AND e.previsao_entrega < CURRENT_TIMESTAMP
       )
 ORDER BY en.id_pessoa;

-- Consulta 18: "Quais entregadores possuem entregas em todos os status atribuídos existentes na base?"
-- Ator: Gestor de Logística.
-- Técnica: Divisão relacional por dupla negação (NOT EXISTS / NOT EXISTS) com USING.
-- Tabelas: entregador, pessoa, rota, entrega.
SELECT en.id_pessoa AS id_entregador,
       p.nome
  FROM entregador en
  JOIN pessoa p USING (id_pessoa)
 WHERE NOT EXISTS (
           SELECT 1
             FROM (SELECT DISTINCT status FROM entrega WHERE id_rota IS NOT NULL) estados
            WHERE NOT EXISTS (
                      SELECT 1
                        FROM rota r
                        JOIN entrega e USING (id_rota)
                       WHERE r.id_entregador = en.id_pessoa
                         AND e.status = estados.status
                  )
       )
 ORDER BY en.id_pessoa;

-- Consulta 19: "Quantas entregas cada entregador tem em cada status atribuído, incluindo zeros?"
-- Ator: Gestor de Logística.
-- Técnica: CROSS JOIN para matriz entregador x status + LEFT JOIN com COALESCE.
-- Tabelas: entregador, rota, entrega.
SELECT en.id_pessoa AS id_entregador,
       estados.status,
       COALESCE(t.total, 0) AS total_entregas
  FROM entregador en
 CROSS JOIN (VALUES ('aceita'::status_entrega), ('a_caminho'), ('entregue')) estados(status)
  LEFT JOIN (
           SELECT r.id_entregador, e.status, COUNT(*) AS total
             FROM rota r
             JOIN entrega e USING (id_rota)
            GROUP BY r.id_entregador, e.status
       ) t
    ON t.id_entregador = en.id_pessoa
   AND t.status = estados.status
 ORDER BY en.id_pessoa, estados.status;


-- =============================================================================
-- SUBDOMÍNIO: AUDITORIA
-- =============================================================================

-- Consulta 20: "Quais pedidos foram aceitos pela loja, mas ainda não têm registro de pagamento? Mostrar pedido, loja e cliente."
-- Ator: Operação / Administração financeira (Consulta 16 da E3, RF05/RN04).
-- Técnica: Junção interna (INNER JOIN) + subconsulta correlacionada com NOT EXISTS (tradução da diferença relacional).
-- Tabelas: historico_pedido, pedido.
SELECT p.id_pedido,
       p.id_loja,
       p.id_cliente,
       hp_aceito.data_hora AS aceito_em
  FROM historico_pedido hp_aceito
INNER JOIN pedido p
        ON p.id_pedido = hp_aceito.id_pedido
 WHERE hp_aceito.status = 'aceito'
   AND NOT EXISTS (
           SELECT 1
             FROM historico_pedido hp_pago
            WHERE hp_pago.id_pedido = hp_aceito.id_pedido
              AND hp_pago.status = 'pago'
       )
 ORDER BY hp_aceito.data_hora DESC, p.id_pedido;

-- Consulta 21: "Quais entregas foram concluídas depois da previsão de entrega? Mostrar entrega, pedido, previsão e data real de entrega."
-- Ator: Operação logística / Auditoria de SLA (Consulta 17 da E3, RF06/RN04).
-- Técnica: Junção interna com condição theta temporal (INNER JOIN ... ON he.data_hora > e.previsao_entrega).
-- Tabelas: historico_entrega, entrega.
SELECT e.id_entrega,
       e.id_pedido,
       e.previsao_entrega,
       he.data_hora AS data_entrega,
       ROUND(EXTRACT(EPOCH FROM (he.data_hora - e.previsao_entrega)) / 60.0, 2) AS atraso_minutos
  FROM historico_entrega he
INNER JOIN entrega e
        ON e.id_entrega = he.id_entrega
       AND he.data_hora > e.previsao_entrega
 WHERE he.status = 'entregue'
 ORDER BY atraso_minutos DESC, e.id_entrega;

-- Consulta 22: "Quais lojas acumularam pelo menos 5 entregas concluídas em atraso, exibindo o identificador e o nome da loja, o total de entregas atrasadas e o atraso médio em minutos?"
-- Ator: Administração / Auditoria de SLA (RF10/RN04).
-- Técnica: Múltiplas junções internas (INNER JOIN) + agrupamento com GROUP BY e filtro agregado com HAVING.
-- Tabelas: historico_entrega, entrega, pedido, loja.
SELECT l.id_loja,
       l.nome,
       COUNT(e.id_entrega) AS total_entregas_atrasadas,
       ROUND(AVG(EXTRACT(EPOCH FROM (he.data_hora - e.previsao_entrega)) / 60.0), 2) AS media_atraso_minutos
  FROM historico_entrega he
INNER JOIN entrega e
        ON e.id_entrega = he.id_entrega
INNER JOIN pedido p
        ON p.id_pedido = e.id_pedido
INNER JOIN loja l
        ON l.id_loja = p.id_loja
 WHERE he.status = 'entregue'
   AND he.data_hora > e.previsao_entrega
 GROUP BY l.id_loja, l.nome
HAVING COUNT(e.id_entrega) >= 5
 ORDER BY total_entregas_atrasadas DESC, media_atraso_minutos DESC, l.id_loja;

-- Consulta 23: "Quais pedidos concluídos tiveram tempo total entre 'solicitado' e 'concluido' superior ao tempo médio de conclusão dos pedidos da mesma loja?"
-- Ator: Administração / Auditoria operacional (RF05/RF10/RN04).
-- Técnica: Junções internas + subconsulta correlacionada escalar comparando a duração do pedido com a média da própria loja.
-- Tabelas: pedido, historico_pedido.
SELECT p.id_pedido,
       p.id_loja,
       hp_ini.data_hora AS solicitado_em,
       hp_fim.data_hora AS concluido_em,
       ROUND(EXTRACT(EPOCH FROM (hp_fim.data_hora - hp_ini.data_hora)) / 60.0, 2) AS duracao_total_minutos
  FROM pedido p
INNER JOIN historico_pedido hp_ini
        ON hp_ini.id_pedido = p.id_pedido
       AND hp_ini.status = 'solicitado'
INNER JOIN historico_pedido hp_fim
        ON hp_fim.id_pedido = p.id_pedido
       AND hp_fim.status = 'concluido'
 WHERE EXTRACT(EPOCH FROM (hp_fim.data_hora - hp_ini.data_hora)) > (
           SELECT AVG(EXTRACT(EPOCH FROM (hp2_fim.data_hora - hp2_ini.data_hora)))
             FROM pedido p2
           INNER JOIN historico_pedido hp2_ini
                   ON hp2_ini.id_pedido = p2.id_pedido
                  AND hp2_ini.status = 'solicitado'
           INNER JOIN historico_pedido hp2_fim
                   ON hp2_fim.id_pedido = p2.id_pedido
                  AND hp2_fim.status = 'concluido'
            WHERE p2.id_loja = p.id_loja
       )
 ORDER BY duracao_total_minutos DESC, p.id_pedido;