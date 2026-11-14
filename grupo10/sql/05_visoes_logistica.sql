-- E5, seção 7.1: duas visões de leitura, após a criação das tabelas.
-- Executar uma vez; BEGIN/COMMIT instala ambas sem deixar definição parcial.
-- Na preparação isolada de 500 mil pedidos: painel com 249.651 linhas e fila com 700.
-- information_schema.views confirmou is_updatable = NO para ambas no PostgreSQL 18.
-- Ator: operação/gestor de Logística. Painel de rotas, entregas, atrasos e vagas.
-- Não é automaticamente atualizável: agrega várias tabelas com GROUP BY e COUNT.
BEGIN;

CREATE VIEW vw_painel_rotas_logistica AS
SELECT
    r.id_rota,
    r.id_entregador,
    p.nome AS nome_entregador,
    en.tipo_veiculo,
    r.criada_em,
    r.encerrada_em,
    -- RN02/RR02: COUNT da PK não conta a linha NULL do LEFT JOIN em rota vazia.
    COUNT(e.id_entrega) AS total_entregas,
    -- ADR-004: somente aceita/a_caminho contam como entregas ativas.
    COUNT(e.id_entrega) FILTER (
        WHERE e.status IN ('aceita', 'a_caminho')
    ) AS entregas_ativas,
    -- RN03/RR05: atraso é calculado na leitura; não é outro valor do ENUM.
    COUNT(e.id_entrega) FILTER (
        WHERE e.status IN ('aceita', 'a_caminho')
          AND e.previsao_entrega < CURRENT_TIMESTAMP
    ) AS entregas_atrasadas,
    -- RN02: vagas contam todos os vínculos, inclusive os concluídos.
    -- Rota encerrada não oferece vaga; GREATEST limita a exibição, não valida RN02.
    CASE
        WHEN r.encerrada_em IS NULL THEN GREATEST(0, 2 - COUNT(e.id_entrega))
        ELSE 0
    END AS vagas
FROM rota AS r
INNER JOIN entregador AS en ON en.id_pessoa = r.id_entregador
INNER JOIN pessoa AS p ON p.id_pessoa = en.id_pessoa
LEFT JOIN entrega AS e ON e.id_rota = r.id_rota
GROUP BY
    r.id_rota,
    r.id_entregador,
    p.nome,
    en.tipo_veiculo,
    r.criada_em,
    r.encerrada_em;

-- Ator: operador de despacho. Centraliza a fila, a loja e a previsão disponíveis
-- para priorizar pedidos prontos sem rota. Inclui os que ainda não possuem entrega.
-- Não é automaticamente atualizável: a consulta combina pedido, loja e entrega.
-- RN12/ADR-005: a fila inclui pedidos ainda sem entrega ou com entrega sem rota;
-- não autoriza assumir nova entrega sem a checagem da RN03 pela aplicação.
-- Escritas são nas tabelas-base. O consumidor aplica autorização e ORDER BY.
CREATE VIEW vw_fila_despacho_logistica AS
SELECT p.id_pedido, p.id_loja, l.nome AS nome_loja, p.data_pedido,
       e.id_entrega, e.previsao_entrega
FROM pedido p
JOIN loja l USING (id_loja)
LEFT JOIN entrega e USING (id_pedido)
WHERE p.status = 'pronto' AND e.id_rota IS NULL;

COMMIT;
