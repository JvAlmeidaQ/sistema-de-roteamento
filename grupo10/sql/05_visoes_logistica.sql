BEGIN;

CREATE VIEW vw_painel_rotas_logistica AS
SELECT
    r.id_rota,
    r.id_entregador,
    p.nome AS nome_entregador,
    en.tipo_veiculo,
    r.criada_em,
    r.encerrada_em,
    COUNT(e.id_entrega) AS total_entregas,
    COUNT(e.id_entrega) FILTER (
        WHERE e.status IN ('aceita', 'a_caminho')
    ) AS entregas_ativas,
    COUNT(e.id_entrega) FILTER (
        WHERE e.status IN ('aceita', 'a_caminho')
          AND e.previsao_entrega < CURRENT_TIMESTAMP
    ) AS entregas_atrasadas,
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

COMMIT;
