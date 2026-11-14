-- =============================================================================
-- 01_esquema_auditoria.sql — Subdomínio Auditoria (E4)
-- Pré-requisito: tabelas pedido e entrega já criadas no banco de dados.
--
-- Regras estruturais garantidas no DDL (RN04, RN08, RR11, ADR-004):
--   - PK composta (id_pedido, status) e (id_entrega, status): cada status
--     ocorre no máximo uma vez por pedido ou entrega na trilha cronológica.
--   - FK com ON DELETE RESTRICT: impede que um pedido ou entrega com histórico
--     registrado seja excluído em cascata.
--   - CHECK temporal: impede carimbos de data/hora anteriores à plataforma.
--   - A imutabilidade contra UPDATE/DELETE direto nas tabelas históricas é
--     aplicada na E6 (06_triggers_auditoria.sql).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tipos ENUM do domínio (criados apenas se ainda não existirem)
-- -----------------------------------------------------------------------------
BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_pedido') THEN
        CREATE TYPE status_pedido AS ENUM (
            'solicitado',
            'aceito',
            'recusado',
            'pago',
            'em_preparacao',
            'pronto',
            'concluido'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_entrega') THEN
        CREATE TYPE status_entrega AS ENUM (
            'aguardando_entregador',
            'aceita',
            'a_caminho',
            'entregue'
        );
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 2. Historico_Pedido
--    Registra cada mudança de status do pedido em ordem cronológica.
-- -----------------------------------------------------------------------------
CREATE TABLE historico_pedido (
    id_pedido BIGINT        NOT NULL,
    status    status_pedido NOT NULL,
    data_hora TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_historico_pedido
        PRIMARY KEY (id_pedido, status),

    CONSTRAINT fk_historico_pedido_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedido (id_pedido)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,

    CONSTRAINT chk_historico_pedido_data_hora
        CHECK (data_hora >= '2020-01-01 00:00:00+00'::timestamptz)
);

-- -----------------------------------------------------------------------------
-- 3. Historico_Entrega
--    Registra cada mudança de status da entrega em ordem cronológica.
-- -----------------------------------------------------------------------------
CREATE TABLE historico_entrega (
    id_entrega BIGINT         NOT NULL,
    status     status_entrega NOT NULL,
    data_hora  TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_historico_entrega
        PRIMARY KEY (id_entrega, status),

    CONSTRAINT fk_historico_entrega_entrega
        FOREIGN KEY (id_entrega)
        REFERENCES entrega (id_entrega)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,

    CONSTRAINT chk_historico_entrega_data_hora
        CHECK (data_hora >= '2020-01-01 00:00:00+00'::timestamptz)
);

COMMIT;