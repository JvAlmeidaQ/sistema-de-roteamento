BEGIN;

DO $$
DECLARE
    v_rota BIGINT;
    v_entrega BIGINT;
    v_inexistente BIGINT;
    v_criada_em TIMESTAMPTZ;
    v_teste RECORD;
    v_sqlstate TEXT;
    v_restricao TEXT;
    v_falhou BOOLEAN;
BEGIN
    SELECT id_entrega INTO STRICT v_entrega
    FROM entrega
    WHERE id_pedido = 6
      AND status = 'aguardando_entregador'
      AND id_rota IS NULL;

    IF NOT EXISTS (SELECT 1 FROM entrega WHERE id_pedido = 1) THEN
        RAISE EXCEPTION 'Pré-requisito ausente: entrega do pedido 1';
    END IF;

    SELECT candidato INTO v_inexistente
    FROM generate_series(-1::BIGINT, -1000::BIGINT, -1::BIGINT) AS ids(candidato)
    WHERE NOT EXISTS (SELECT 1 FROM entregador WHERE id_pessoa = candidato)
      AND NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = candidato)
      AND NOT EXISTS (SELECT 1 FROM rota WHERE id_rota = candidato)
    LIMIT 1;

    IF v_inexistente IS NULL THEN
        RAISE EXCEPTION 'Não foi possível reservar um ID inexistente para os testes';
    END IF;

    INSERT INTO rota (id_entregador)
    VALUES (1)
    RETURNING id_rota, criada_em INTO v_rota, v_criada_em;

    IF v_criada_em IS DISTINCT FROM CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Falha no valor padrão de rota.criada_em';
    END IF;

    UPDATE rota SET encerrada_em = criada_em WHERE id_rota = v_rota;
    UPDATE rota SET encerrada_em = NULL WHERE id_rota = v_rota;

    UPDATE entrega
    SET id_rota = v_rota, status = 'aceita'
    WHERE id_entrega = v_entrega;

    IF NOT EXISTS (
        SELECT 1 FROM entrega
        WHERE id_entrega = v_entrega AND id_rota = v_rota AND status = 'aceita'
    ) THEN
        RAISE EXCEPTION 'Falha na vinculação válida da entrega à rota';
    END IF;

    RAISE NOTICE 'PASSOU: criação de rota, valor padrão, encerramento válido e vinculação de entrega';

    FOR v_teste IN
        SELECT * FROM (VALUES
            (
                'PK duplicada de rota',
                format('INSERT INTO rota (id_rota, id_entregador) OVERRIDING SYSTEM VALUE VALUES (%s, 1)', v_rota),
                '23505', 'pk_rota'
            ),
            (
                'PK duplicada de entrega',
                format('INSERT INTO entrega (id_entrega, id_pedido, previsao_entrega) OVERRIDING SYSTEM VALUE VALUES (%s, 6, CURRENT_TIMESTAMP)', v_entrega),
                '23505', 'pk_entrega'
            ),
            (
                'Pedido duplicado na entrega',
                format('UPDATE entrega SET id_pedido = 1 WHERE id_entrega = %s', v_entrega),
                '23505', 'uq_entrega_pedido'
            ),
            (
                'Entregador inexistente',
                format('INSERT INTO rota (id_entregador) VALUES (%s)', v_inexistente),
                '23503', 'fk_rota_entregador'
            ),
            (
                'Pedido inexistente',
                format('UPDATE entrega SET id_pedido = %s WHERE id_entrega = %s', v_inexistente, v_entrega),
                '23503', 'fk_entrega_pedido'
            ),
            (
                'Rota inexistente',
                format('UPDATE entrega SET id_rota = %s WHERE id_entrega = %s', v_inexistente, v_entrega),
                '23503', 'fk_entrega_rota'
            ),
            (
                'Entregador obrigatório',
                'INSERT INTO rota (id_entregador) VALUES (NULL)',
                '23502', NULL
            ),
            (
                'Instante de criação obrigatório',
                'INSERT INTO rota (id_entregador, criada_em) VALUES (1, NULL)',
                '23502', NULL
            ),
            (
                'Pedido obrigatório',
                format('UPDATE entrega SET id_pedido = NULL WHERE id_entrega = %s', v_entrega),
                '23502', NULL
            ),
            (
                'Status obrigatório',
                format('UPDATE entrega SET status = NULL WHERE id_entrega = %s', v_entrega),
                '23502', NULL
            ),
            (
                'Previsão obrigatória',
                format('UPDATE entrega SET previsao_entrega = NULL WHERE id_entrega = %s', v_entrega),
                '23502', NULL
            ),
            (
                'Encerramento anterior à criação',
                format('UPDATE rota SET encerrada_em = criada_em - INTERVAL ''1 second'' WHERE id_rota = %s', v_rota),
                '23514', 'ck_rota_ordem_temporal'
            ),
            (
                'Entrega aguardando com rota preenchida',
                format('UPDATE entrega SET status = ''aguardando_entregador'' WHERE id_entrega = %s', v_entrega),
                '23514', 'ck_entrega_status_rota'
            ),
            (
                'Entrega aceita sem rota',
                format('UPDATE entrega SET id_rota = NULL WHERE id_entrega = %s', v_entrega),
                '23514', 'ck_entrega_status_rota'
            ),
            (
                'Status fora do enum',
                format('UPDATE entrega SET status = ''invalido'' WHERE id_entrega = %s', v_entrega),
                '22P02', NULL
            ),
            (
                'Exclusão de rota com entrega',
                format('DELETE FROM rota WHERE id_rota = %s', v_rota),
                '23001', 'fk_entrega_rota'
            )
        ) AS testes(descricao, comando, sqlstate_esperado, restricao_esperada)
    LOOP
        v_falhou := FALSE;

        BEGIN
            EXECUTE v_teste.comando;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_restricao = CONSTRAINT_NAME;

            IF v_sqlstate IS DISTINCT FROM v_teste.sqlstate_esperado
                OR (v_teste.restricao_esperada IS NOT NULL
                    AND v_restricao IS DISTINCT FROM v_teste.restricao_esperada) THEN
                RAISE EXCEPTION 'FALHOU: %. Esperado: % / %. Obtido: % / %',
                    v_teste.descricao,
                    v_teste.sqlstate_esperado, v_teste.restricao_esperada,
                    v_sqlstate, v_restricao;
            END IF;

            v_falhou := TRUE;
        END;

        IF NOT v_falhou THEN
            RAISE EXCEPTION 'FALHOU: %. A operação inválida foi aceita', v_teste.descricao;
        END IF;

        RAISE NOTICE 'PASSOU: % (SQLSTATE %)', v_teste.descricao, v_teste.sqlstate_esperado;
    END LOOP;
END;
$$;

ROLLBACK;
