-- =============================================================================
-- 02_carga_auditoria.sql — Subdomínio Auditoria (E4)
-- Pré-requisito: 01_esquema_auditoria.sql e cargas de Pedido e Entrega já
-- executados antes da ativação dos gatilhos da E6 (06_triggers_auditoria.sql).
--
-- Regras de reconstituição da trilha cronológica (RN04, RN12, ADR-004):
--   - Pedidos recusados:  solicitado -> recusado (2 eventos).
--   - Pedidos normais:    solicitado -> aceito -> pago -> em_preparacao
--                         -> pronto -> concluido (1 a 6 eventos).
--   - Entregas:           aguardando_entregador -> aceita -> a_caminho
--                         -> entregue (1 a 4 eventos), iniciando quando o
--                         pedido fica 'pronto' (data_pedido + 22 min).
--   - Sincronização:      pedidos 'concluido' compartilham o mesmo timestamp
--                         de 'entregue' da sua entrega; 20% das entregas
--                         concluídas (id_entrega % 5 = 0) simulam atraso real
--                         para alimentar a Consulta 17 e relatórios de SLA.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Historico_Pedido (trilha cronológica do ciclo comercial)
--    Os eventos são gerados a partir de Pedido sem assumir IDs fixos,
--    respeitando os dois ramos possíveis da máquina de estados (ADR-004).
-- -----------------------------------------------------------------------------

-- 1a. Pedidos recusados: gera apenas 'solicitado' e 'recusado'.
INSERT INTO historico_pedido (id_pedido, status, data_hora)
SELECT
    p.id_pedido,
    etapa.status,
    p.data_pedido + etapa.deslocamento
FROM pedido p
CROSS JOIN (
    VALUES
        ('solicitado'::status_pedido, INTERVAL '0 minutes'),
        ('recusado'::status_pedido,   INTERVAL '3 minutes')
) AS etapa(status, deslocamento)
WHERE p.status = 'recusado';

-- 1b. Pedidos do fluxo normal: gera eventos cumulativos até o status atual.
--     Quando o pedido está 'concluido', alinha o timestamp com o término
--     da entrega correspondente.
INSERT INTO historico_pedido (id_pedido, status, data_hora)
SELECT
    p.id_pedido,
    etapa.status,
    CASE
        WHEN etapa.status = 'concluido' AND e.id_entrega IS NOT NULL THEN
            CASE
                WHEN e.id_entrega % 5 = 0 THEN
                    GREATEST(p.data_pedido + INTERVAL '33 minutes', e.previsao_entrega + INTERVAL '12 minutes')
                ELSE
                    GREATEST(
                        p.data_pedido + INTERVAL '33 minutes',
                        LEAST(p.data_pedido + INTERVAL '45 minutes', e.previsao_entrega - INTERVAL '2 minutes')
                    )
            END
        ELSE p.data_pedido + etapa.deslocamento
    END
FROM pedido p
LEFT JOIN entrega e
    ON e.id_pedido = p.id_pedido
CROSS JOIN (
    VALUES
        (1, 'solicitado'::status_pedido,    INTERVAL '0 minutes'),
        (2, 'aceito'::status_pedido,        INTERVAL '2 minutes'),
        (3, 'pago'::status_pedido,          INTERVAL '5 minutes'),
        (4, 'em_preparacao'::status_pedido, INTERVAL '8 minutes'),
        (5, 'pronto'::status_pedido,        INTERVAL '22 minutes'),
        (6, 'concluido'::status_pedido,     INTERVAL '45 minutes')
) AS etapa(ordem, status, deslocamento)
WHERE p.status <> 'recusado'
  AND etapa.ordem <= CASE p.status
      WHEN 'solicitado'    THEN 1
      WHEN 'aceito'        THEN 2
      WHEN 'pago'          THEN 3
      WHEN 'em_preparacao' THEN 4
      WHEN 'pronto'        THEN 5
      WHEN 'concluido'     THEN 6
  END;

-- -----------------------------------------------------------------------------
-- 2. Historico_Entrega (trilha cronológica do ciclo logístico)
--    A entrega nasce no instante em que o pedido fica 'pronto' (RN12),
--    equivalente a data_pedido + 22 minutos.
-- -----------------------------------------------------------------------------

-- 2a. Etapas até 'a_caminho' (aguardando_entregador, aceita, a_caminho).
INSERT INTO historico_entrega (id_entrega, status, data_hora)
SELECT
    e.id_entrega,
    etapa.status,
    p.data_pedido + INTERVAL '22 minutes' + etapa.deslocamento
FROM entrega e
INNER JOIN pedido p
    ON p.id_pedido = e.id_pedido
CROSS JOIN (
    VALUES
        (1, 'aguardando_entregador'::status_entrega, INTERVAL '0 minutes'),
        (2, 'aceita'::status_entrega,                INTERVAL '3 minutes'),
        (3, 'a_caminho'::status_entrega,             INTERVAL '7 minutes')
) AS etapa(ordem, status, deslocamento)
WHERE etapa.ordem <= CASE e.status
    WHEN 'aguardando_entregador' THEN 1
    WHEN 'aceita'                THEN 2
    WHEN 'a_caminho'             THEN 3
    WHEN 'entregue'              THEN 3
END;

-- 2b. Etapa final ('entregue'): 20% das entregas concluídas recebem carimbo
--     posterior à previsao_entrega (atraso) e 80% concluem dentro do prazo.
INSERT INTO historico_entrega (id_entrega, status, data_hora)
SELECT
    e.id_entrega,
    'entregue'::status_entrega,
    CASE
        WHEN e.id_entrega % 5 = 0 THEN
            GREATEST(p.data_pedido + INTERVAL '33 minutes', e.previsao_entrega + INTERVAL '12 minutes')
        ELSE
            GREATEST(
                p.data_pedido + INTERVAL '33 minutes',
                LEAST(p.data_pedido + INTERVAL '45 minutes', e.previsao_entrega - INTERVAL '2 minutes')
            )
    END
FROM entrega e
INNER JOIN pedido p
    ON p.id_pedido = e.id_pedido
WHERE e.status = 'entregue';

-- -----------------------------------------------------------------------------
-- 3. Conferência da carga: todo pedido e entrega possuem trilha coerente (RN04).
--    A geração automática e a imutabilidade (RN08) viram gatilhos na E6;
--    aqui garantimos que a carga histórica já reflete os estados atuais.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pedido p
        WHERE NOT EXISTS (
            SELECT 1
            FROM historico_pedido hp
            WHERE hp.id_pedido = p.id_pedido
              AND hp.status = p.status
        )
    ) THEN
        RAISE EXCEPTION 'Carga inválida: existe pedido sem o registro do seu status atual em historico_pedido (RN04)';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM entrega e
        WHERE NOT EXISTS (
            SELECT 1
            FROM historico_entrega he
            WHERE he.id_entrega = e.id_entrega
              AND he.status = e.status
        )
    ) THEN
        RAISE EXCEPTION 'Carga inválida: existe entrega sem o registro do seu status atual em historico_entrega (RN04)';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM historico_pedido hp_ini
        INNER JOIN historico_pedido hp_fim
            ON hp_fim.id_pedido = hp_ini.id_pedido
        WHERE hp_ini.status = 'solicitado'
          AND hp_fim.status <> 'solicitado'
          AND hp_fim.data_hora < hp_ini.data_hora
    ) THEN
        RAISE EXCEPTION 'Carga inválida: ordem cronológica violada em historico_pedido';
    END IF;
END $$;

COMMIT;

ANALYZE historico_pedido;
ANALYZE historico_entrega;