BEGIN;

CREATE FUNCTION pg_temp.logistica_esperar_erro(p_descricao TEXT, p_sql TEXT, p_restricao TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo TEXT;
    v_restricao TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_codigo = RETURNED_SQLSTATE, v_restricao = CONSTRAINT_NAME;
        IF v_codigo <> '23514' OR v_restricao IS DISTINCT FROM p_restricao THEN
            RAISE EXCEPTION 'FALHOU: %. Erro inesperado: % / %', p_descricao, v_codigo, v_restricao;
        END IF;
        RAISE NOTICE 'PASSOU: %', p_descricao;
        RETURN;
    END;
    RAISE EXCEPTION 'FALHOU: %. A operação inválida foi aceita', p_descricao;
END;
$$;

CREATE FUNCTION pg_temp.logistica_novo_pedido(p_status status_pedido)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO pedido (
        id_loja, id_cliente, id_endereco, status,
        subtotal, taxa_entrega, taxa_servico, valor_total
    )
    SELECT id_loja, id_cliente, id_endereco, p_status,
        subtotal, taxa_entrega, taxa_servico, valor_total
    FROM pedido WHERE id_pedido = 6
    RETURNING id_pedido INTO STRICT v_id;
    RETURN v_id;
END;
$$;

DO $$
DECLARE
    v_pedidos BIGINT[] := ARRAY[]::BIGINT[];
    v_entregas BIGINT[] := ARRAY[]::BIGINT[];
    v_pedido BIGINT;
    v_entrega BIGINT;
    v_rota1 BIGINT;
    v_rota2 BIGINT;
    v_rota3 BIGINT;
    v_previsao TIMESTAMPTZ;
    v_minutos INTEGER;
    i INTEGER;
BEGIN
    IF (SELECT COUNT(*) FROM pg_trigger
        WHERE tgname IN (
            'trg_entrega_10_validar', 'trg_entrega_20_limitar_rota',
            'trg_entrega_30_concluir_pedido', 'trg_pedido_logistica_gerar_entrega'
        ) AND tgenabled = 'O') <> 4 THEN
        RAISE EXCEPTION 'Os quatro gatilhos de Logística devem estar instalados e habilitados';
    END IF;

    v_pedido := pg_temp.logistica_novo_pedido('em_preparacao');
    IF EXISTS (SELECT 1 FROM entrega WHERE id_pedido = v_pedido) THEN
        RAISE EXCEPTION 'Pedido em preparação gerou entrega';
    END IF;

    PERFORM pg_temp.logistica_esperar_erro(
        'RN12 bloqueia entrega de pedido em preparação',
        format('INSERT INTO entrega (id_pedido, previsao_entrega) VALUES (%s, CURRENT_TIMESTAMP)', v_pedido),
        'ck_entrega_pedido_pronto'
    );

    UPDATE pedido SET status = 'pronto' WHERE id_pedido = v_pedido;
    SELECT id_entrega, previsao_entrega INTO STRICT v_entrega, v_previsao
    FROM entrega
    WHERE id_pedido = v_pedido AND status = 'aguardando_entregador' AND id_rota IS NULL;
    SELECT l.tempo_entrega_estimado INTO STRICT v_minutos
    FROM pedido p JOIN loja l USING (id_loja) WHERE p.id_pedido = v_pedido;

    IF v_previsao IS DISTINCT FROM statement_timestamp() + make_interval(mins => v_minutos) THEN
        RAISE EXCEPTION 'Previsão diferente do instante de prontidão mais estimativa da loja';
    END IF;
    v_pedidos := array_append(v_pedidos, v_pedido);
    v_entregas := array_append(v_entregas, v_entrega);
    RAISE NOTICE 'PASSOU: pedido pronto gera entrega inicial com previsão calculada';

    FOR i IN 2..6 LOOP
        v_pedido := pg_temp.logistica_novo_pedido('pronto');
        SELECT id_entrega INTO STRICT v_entrega FROM entrega WHERE id_pedido = v_pedido;
        v_pedidos := array_append(v_pedidos, v_pedido);
        v_entregas := array_append(v_entregas, v_entrega);
    END LOOP;
    RAISE NOTICE 'PASSOU: inserção de pedido pronto também gera entrega';

    UPDATE pedido SET status = status WHERE id_pedido = v_pedidos[1];
    IF (SELECT COUNT(*) FROM entrega WHERE id_pedido = v_pedidos[1]) <> 1 THEN
        RAISE EXCEPTION 'Atualização sem mudança de status duplicou entrega';
    END IF;
    RAISE NOTICE 'PASSOU: status pronto sem mudança não duplica entrega';

    INSERT INTO rota (id_entregador) VALUES (1) RETURNING id_rota INTO v_rota1;
    INSERT INTO rota (id_entregador) VALUES (2) RETURNING id_rota INTO v_rota2;
    INSERT INTO rota (id_entregador) VALUES (3) RETURNING id_rota INTO v_rota3;

    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite pular de aguardando para a caminho',
        format('UPDATE entrega SET status = ''a_caminho'', id_rota = %s WHERE id_entrega = %s', v_rota1, v_entregas[1]),
        'ck_entrega_transicao_status'
    );
    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite pular de aguardando para entregue',
        format('UPDATE entrega SET status = ''entregue'', id_rota = %s WHERE id_entrega = %s', v_rota1, v_entregas[1]),
        'ck_entrega_transicao_status'
    );

    UPDATE entrega SET status = 'aceita', id_rota = v_rota1
    WHERE id_entrega IN (v_entregas[1], v_entregas[2]);
    IF (SELECT COUNT(*) FROM entrega WHERE id_rota = v_rota1) <> 2 THEN
        RAISE EXCEPTION 'Falha ao vincular duas entregas à mesma rota';
    END IF;
    RAISE NOTICE 'PASSOU: primeira e segunda entregas permitidas';

    PERFORM pg_temp.logistica_esperar_erro(
        'RN02 bloqueia terceira entrega via UPDATE',
        format('UPDATE entrega SET status = ''aceita'', id_rota = %s WHERE id_entrega = %s', v_rota1, v_entregas[3]),
        'ck_rota_maximo_duas_entregas'
    );
    PERFORM pg_temp.logistica_esperar_erro(
        'RN02 protege também INSERT com rota cheia',
        format('INSERT INTO entrega (id_pedido, id_rota, previsao_entrega) VALUES (%s, %s, CURRENT_TIMESTAMP)', v_pedidos[3], v_rota1),
        'ck_rota_maximo_duas_entregas'
    );

    UPDATE entrega SET id_rota = id_rota, status = status WHERE id_entrega = v_entregas[1];
    RAISE NOTICE 'PASSOU: atualização sem mudança em rota cheia';

    UPDATE entrega SET status = 'aceita', id_rota = v_rota2
    WHERE id_entrega IN (v_entregas[3], v_entregas[4]);
    PERFORM pg_temp.logistica_esperar_erro(
        'RN02 bloqueia transferência para rota cheia',
        format('UPDATE entrega SET id_rota = %s WHERE id_entrega = %s', v_rota2, v_entregas[1]),
        'ck_rota_maximo_duas_entregas'
    );
    UPDATE entrega SET id_rota = v_rota3 WHERE id_entrega = v_entregas[3];
    UPDATE entrega SET id_rota = v_rota2 WHERE id_entrega = v_entregas[1];
    RAISE NOTICE 'PASSOU: transferência para rota com vaga';

    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite retorno de aceita para aguardando',
        format('UPDATE entrega SET status = ''aguardando_entregador'', id_rota = NULL WHERE id_entrega = %s', v_entregas[2]),
        'ck_entrega_transicao_status'
    );
    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite pular de aceita para entregue',
        format('UPDATE entrega SET status = ''entregue'' WHERE id_entrega = %s', v_entregas[2]),
        'ck_entrega_transicao_status'
    );
    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite trocar o pedido de uma entrega existente',
        format('UPDATE entrega SET id_pedido = %s WHERE id_entrega = %s', v_pedidos[5], v_entregas[2]),
        'ck_entrega_pedido_imutavel'
    );

    UPDATE entrega SET status = 'a_caminho' WHERE id_entrega = v_entregas[2];
    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite retorno de a caminho para aceita',
        format('UPDATE entrega SET status = ''aceita'' WHERE id_entrega = %s', v_entregas[2]),
        'ck_entrega_transicao_status'
    );
    UPDATE entrega SET status = 'entregue' WHERE id_entrega = v_entregas[2];
    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = v_pedidos[2] AND status = 'concluido') THEN
        RAISE EXCEPTION 'Entrega concluída não concluiu o pedido';
    END IF;
    RAISE NOTICE 'PASSOU: fluxo completo da entrega conclui o pedido';

    UPDATE entrega SET status = status WHERE id_entrega = v_entregas[2];
    PERFORM pg_temp.logistica_esperar_erro(
        'Estado entregue é terminal',
        format('UPDATE entrega SET status = ''a_caminho'' WHERE id_entrega = %s', v_entregas[2]),
        'ck_entrega_transicao_status'
    );

    UPDATE loja SET tempo_entrega_estimado = tempo_entrega_estimado + 1
    WHERE id_loja = (SELECT id_loja FROM pedido WHERE id_pedido = v_pedidos[1]);
    IF (SELECT previsao_entrega FROM entrega WHERE id_entrega = v_entregas[1]) IS DISTINCT FROM v_previsao THEN
        RAISE EXCEPTION 'Alteração da loja modificou o snapshot de previsão';
    END IF;
    v_pedido := pg_temp.logistica_novo_pedido('pronto');
    IF (SELECT previsao_entrega FROM entrega WHERE id_pedido = v_pedido)
        IS DISTINCT FROM statement_timestamp() + make_interval(mins => v_minutos + 1) THEN
        RAISE EXCEPTION 'Nova entrega não usou a estimativa atualizada da loja';
    END IF;
    RAISE NOTICE 'PASSOU: previsão antiga preservada e nova previsão usa estimativa atual';

    v_pedido := pg_temp.logistica_novo_pedido('em_preparacao');
    PERFORM pg_temp.logistica_esperar_erro(
        'Não permite criar entrega diretamente aceita',
        format('INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega) VALUES (%s, %s, ''aceita'', CURRENT_TIMESTAMP)', v_pedido, v_rota3),
        'ck_entrega_estado_inicial'
    );
END;
$$;

ROLLBACK;
