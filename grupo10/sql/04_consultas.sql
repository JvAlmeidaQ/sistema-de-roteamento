-- =============================================================================
-- CONSULTAS SQL — ENTREGA E5 (SEÇÃO 6)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Logística (mesma de 01_esquema.sql).
-- =============================================================================

-- =============================================================================
-- SUBDOMÍNIO: IDENTIDADE E CONTATO
-- =============================================================================

-- Consulta 1: "Quais pessoas são, ao mesmo tempo, Cliente e Entregador e possuem pelo menos um telefone de cada tipo cadastrado no sistema?"
-- Ator: Operação / Administração da plataforma.
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
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- Consulta 5: "Quais rotas têm duas entregas ativas e quais são elas?"
-- Ator: Operação logística (RF04/RN02).
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

-- Consulta 6: "Quais entregadores estão cadastrados e quais rotas abertas têm?"
-- Ator: Operação logística (RF01/RF04).
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

-- Consulta 7: "Quais rotas possuem menos de duas entregas vinculadas?"
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

-- Consulta 8: "Quais entregadores já concluíram pelo menos duas entregas?"
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

-- Consulta 9: "Quais entregadores têm entregas ativas atrasadas?"
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

-- Consulta 10: "Quais entregadores possuem entregas em todos os status atribuídos existentes na base?"
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

-- Consulta 11: "Quantas entregas cada entregador tem em cada status atribuído, incluindo zeros?"
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
