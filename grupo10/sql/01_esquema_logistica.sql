
BEGIN;

CREATE TYPE status_entrega AS ENUM (
    'aguardando_entregador',
    'aceita',
    'a_caminho',
    'entregue'
);

CREATE TABLE rota (
    id_rota BIGINT GENERATED ALWAYS AS IDENTITY,
    id_entregador BIGINT NOT NULL,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    encerrada_em TIMESTAMPTZ,

    CONSTRAINT pk_rota PRIMARY KEY (id_rota),
    CONSTRAINT fk_rota_entregador FOREIGN KEY (id_entregador)
        REFERENCES entregador (id_pessoa)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_rota_ordem_temporal CHECK (
        encerrada_em IS NULL OR encerrada_em >= criada_em
    )
);

CREATE TABLE entrega (
    id_entrega BIGINT GENERATED ALWAYS AS IDENTITY,
    id_pedido BIGINT NOT NULL,
    id_rota BIGINT,
    status status_entrega NOT NULL DEFAULT 'aguardando_entregador',
    previsao_entrega TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_entrega PRIMARY KEY (id_entrega),
    CONSTRAINT uq_entrega_pedido UNIQUE (id_pedido),
    CONSTRAINT fk_entrega_pedido FOREIGN KEY (id_pedido)
        REFERENCES pedido (id_pedido)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_entrega_rota FOREIGN KEY (id_rota)
        REFERENCES rota (id_rota)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_entrega_status_rota CHECK (
        (status = 'aguardando_entregador' AND id_rota IS NULL)
        OR (status <> 'aguardando_entregador' AND id_rota IS NOT NULL)
    )
);


COMMIT;
