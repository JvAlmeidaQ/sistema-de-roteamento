BEGIN;

CREATE INDEX idx_entrega_rota ON entrega USING btree (id_rota);

CREATE INDEX idx_rota_entregador ON rota USING btree (id_entregador);

CREATE INDEX idx_entrega_ativa_previsao_pedido
    ON entrega USING btree (previsao_entrega, id_pedido)
    WHERE status IN ('aceita', 'a_caminho');

CREATE INDEX idx_pedido_pronto_fila
    ON pedido USING btree (data_pedido, id_pedido) INCLUDE (id_loja)
    WHERE status = 'pronto';

COMMIT;
