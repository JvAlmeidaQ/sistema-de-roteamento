BEGIN;

WITH rota_dupla AS (
    INSERT INTO rota (id_entregador, criada_em)
    VALUES (1, CURRENT_TIMESTAMP - INTERVAL '10 minutes')
    RETURNING id_rota
)
INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega)
SELECT 1, id_rota, 'aceita'::status_entrega, CURRENT_TIMESTAMP + INTERVAL '30 minutes'
FROM rota_dupla
UNION ALL
SELECT 2, id_rota, 'a_caminho', CURRENT_TIMESTAMP + INTERVAL '20 minutes'
FROM rota_dupla;

WITH rota_atrasada AS (
    INSERT INTO rota (id_entregador, criada_em)
    VALUES (2, CURRENT_TIMESTAMP - INTERVAL '1 hour')
    RETURNING id_rota
)
INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega)
SELECT 3, id_rota, 'a_caminho', CURRENT_TIMESTAMP - INTERVAL '10 minutes'
FROM rota_atrasada;

WITH rota_encerrada AS (
    INSERT INTO rota (id_entregador, criada_em, encerrada_em)
    VALUES (
        3,
        CURRENT_TIMESTAMP - INTERVAL '1 day',
        CURRENT_TIMESTAMP - INTERVAL '23 hours'
    )
    RETURNING id_rota
)
INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega)
SELECT 4, id_rota, 'entregue'::status_entrega, CURRENT_TIMESTAMP - INTERVAL '23 hours'
FROM rota_encerrada
UNION ALL
SELECT 5, id_rota, 'entregue', CURRENT_TIMESTAMP - INTERVAL '23 hours'
FROM rota_encerrada;

INSERT INTO entrega (id_pedido, previsao_entrega)
VALUES (6, CURRENT_TIMESTAMP + INTERVAL '45 minutes');

ANALYZE rota;
ANALYZE entrega;

COMMIT;
