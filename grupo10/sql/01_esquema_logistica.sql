-- E4, seção 5.1: esquema de Logística. PostgreSQL 14 ou superior.
-- Pré-requisitos: entregador(id_pessoa) e pedido(id_pedido) já criados.
-- Executar uma vez, antes de 02_carga_logistica.sql; a transação evita DDL parcial.
-- PK/FK/UNIQUE/NOT NULL são restrições estruturais do modelo lógico, sem RN própria.
-- RN02/RR02, RN12/RR07 e RR06 dependem dos gatilhos de 06, não deste DDL.
BEGIN;

-- RR06/ADR-004: ENUM limita os valores possíveis, mas não impede saltos entre eles.
-- O fluxo permitido é validado em logistica_validar_entrega, na E6.
CREATE TYPE status_entrega AS ENUM (
    'aguardando_entregador',
    'aceita',
    'a_caminho',
    'entregue'
);

-- Toda rota tem entregador e instante de criação; encerrada_em NULL indica rota aberta.
CREATE TABLE rota (
    id_rota BIGINT GENERATED ALWAYS AS IDENTITY,
    id_entregador BIGINT NOT NULL,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    encerrada_em TIMESTAMPTZ,

    CONSTRAINT pk_rota PRIMARY KEY (id_rota),
    -- RESTRICT preserva os vínculos: alterar/excluir o entregador não apaga rotas.
    CONSTRAINT fk_rota_entregador FOREIGN KEY (id_entregador)
        REFERENCES entregador (id_pessoa)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    -- Regra complementar: encerramento não pode anteceder a criação.
    -- CHECK basta, pois os dois instantes estão na mesma linha.
    CONSTRAINT ck_rota_ordem_temporal CHECK (
        encerrada_em IS NULL OR encerrada_em >= criada_em
    )
);

CREATE TABLE entrega (
    id_entrega BIGINT GENERATED ALWAYS AS IDENTITY,
    id_pedido BIGINT NOT NULL,
    id_rota BIGINT,
    status status_entrega NOT NULL DEFAULT 'aguardando_entregador',
    -- RN03/RR05: a previsão permite identificar atraso; o bloqueio é da aplicação.
    previsao_entrega TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_entrega PRIMARY KEY (id_entrega),
    -- ADR-005/modelo lógico: cada pedido pode ter no máximo uma entrega.
    -- Não obriga todos os pedidos a terem entrega, nem comprova RN12 sozinho.
    CONSTRAINT uq_entrega_pedido UNIQUE (id_pedido),
    -- RESTRICT impede exclusão/alteração de pedidos ou rotas ainda referenciados.
    -- A FK permite rota NULL enquanto a entrega aguarda atribuição.
    CONSTRAINT fk_entrega_pedido FOREIGN KEY (id_pedido)
        REFERENCES pedido (id_pedido)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_entrega_rota FOREIGN KEY (id_rota)
        REFERENCES rota (id_rota)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    -- Regra complementar do ADR-005: aguardando exige rota NULL; demais estados
    -- exigem rota preenchida. A atribuição deve alterar rota e status no mesmo UPDATE.
    CONSTRAINT ck_entrega_status_rota CHECK (
        (status = 'aguardando_entregador' AND id_rota IS NULL)
        OR (status <> 'aguardando_entregador' AND id_rota IS NOT NULL)
    )
);


COMMIT;
