BEGIN;

INSERT INTO pedido (id_loja, id_cliente, id_endereco, status, data_pedido,
                    forma_pagamento, subtotal, taxa_entrega, taxa_servico, valor_total)
SELECT 1 + ((i / 1000) % 100), 1, 1,
       CASE WHEN i % 1000 IN (0, 1, 2) THEN 'pronto' ELSE 'concluido' END::status_pedido,
       TIMESTAMPTZ '2026-01-01 00:00:00+00' + i * INTERVAL '1 second',
       'pix', 40, 5, 2, 47
FROM generate_series(1, 500000) AS g(i);

INSERT INTO rota (id_entregador, criada_em, encerrada_em)
SELECT 1 + ((i - 1) % 1000), TIMESTAMPTZ '2026-01-01 00:00:00+00',
       CASE WHEN (2 * i - 1) % 1000 IN (1, 999) THEN NULL
            ELSE TIMESTAMPTZ '2026-01-08 00:00:00+00' END
FROM generate_series(1, 250000) AS g(i);

INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega)
SELECT i,
       CASE WHEN i % 1000 = 1 THEN NULL ELSE (i + 1) / 2 END,
       CASE WHEN i % 1000 = 1 THEN 'aguardando_entregador'
            WHEN i % 1000 = 2 THEN 'a_caminho' ELSE 'entregue' END::status_entrega,
       CASE WHEN i % 2000 = 2 THEN TIMESTAMPTZ '2026-02-01 11:00:00+00'
            ELSE TIMESTAMPTZ '2026-02-01 13:00:00+00' END
FROM generate_series(1, 500000) AS g(i)
WHERE i % 1000 <> 0;

COMMIT;
