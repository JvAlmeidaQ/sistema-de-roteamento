BEGIN;

CREATE FUNCTION logistica_validar_entrega()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_pedido status_pedido;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status IS DISTINCT FROM 'aguardando_entregador'::status_entrega THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_estado_inicial',
                MESSAGE = 'A entrega deve nascer aguardando entregador';
        END IF;

        SELECT status INTO v_status_pedido
        FROM pedido WHERE id_pedido = NEW.id_pedido
        FOR SHARE;

        IF FOUND AND v_status_pedido <> 'pronto' THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_pedido_pronto',
                MESSAGE = 'RN12: a entrega somente pode ser criada para pedido pronto';
        END IF;
    ELSE
        IF NEW.id_pedido IS DISTINCT FROM OLD.id_pedido THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_pedido_imutavel',
                MESSAGE = 'Uma entrega existente não pode ser transferida para outro pedido';
        END IF;

        IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IS NOT NULL THEN
            IF NOT (
                (OLD.status = 'aguardando_entregador' AND NEW.status = 'aceita')
                OR (OLD.status = 'aceita' AND NEW.status = 'a_caminho')
                OR (OLD.status = 'a_caminho' AND NEW.status = 'entregue')
            ) THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'ck_entrega_transicao_status',
                    MESSAGE = format('Transição inválida de entrega: %s -> %s', OLD.status, NEW.status);
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION logistica_limitar_entregas_rota()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id_rota IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.id_rota IS NOT DISTINCT FROM OLD.id_rota THEN
        RETURN NEW;
    END IF;

    PERFORM 1 FROM rota WHERE id_rota = NEW.id_rota FOR UPDATE;
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    UPDATE rota SET criada_em = criada_em WHERE id_rota = NEW.id_rota;

    IF (SELECT COUNT(*) FROM entrega
        WHERE id_rota = NEW.id_rota
          AND id_entrega IS DISTINCT FROM NEW.id_entrega) >= 2 THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'ck_rota_maximo_duas_entregas',
            MESSAGE = 'RN02: uma rota pode possuir no máximo duas entregas';
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION logistica_gerar_entrega()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_tempo_estimado INTEGER;
BEGIN
    IF NEW.status <> 'pronto' THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;

    SELECT tempo_entrega_estimado INTO STRICT v_tempo_estimado
    FROM loja WHERE id_loja = NEW.id_loja;

    INSERT INTO entrega (id_pedido, previsao_entrega)
    VALUES (
        NEW.id_pedido,
        statement_timestamp() + make_interval(mins => v_tempo_estimado)
    );

    RETURN NEW;
END;
$$;

CREATE FUNCTION logistica_concluir_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'entregue' AND NEW.status IS DISTINCT FROM OLD.status THEN
        UPDATE pedido SET status = 'concluido'
        WHERE id_pedido = NEW.id_pedido AND status = 'pronto';

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_conclusao_pedido',
                MESSAGE = 'A conclusão da entrega exige um pedido pronto';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_entrega_10_validar
BEFORE INSERT OR UPDATE OF status, id_pedido ON entrega
FOR EACH ROW EXECUTE FUNCTION logistica_validar_entrega();

CREATE TRIGGER trg_entrega_20_limitar_rota
BEFORE INSERT OR UPDATE OF id_rota ON entrega
FOR EACH ROW EXECUTE FUNCTION logistica_limitar_entregas_rota();

CREATE TRIGGER trg_entrega_30_concluir_pedido
AFTER UPDATE OF status ON entrega
FOR EACH ROW EXECUTE FUNCTION logistica_concluir_pedido();

CREATE TRIGGER trg_pedido_logistica_gerar_entrega
AFTER INSERT OR UPDATE OF status ON pedido
FOR EACH ROW EXECUTE FUNCTION logistica_gerar_entrega();

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM entrega WHERE id_rota IS NOT NULL
        GROUP BY id_rota HAVING COUNT(*) > 2
    ) THEN
        RAISE EXCEPTION 'RN02: existem rotas com mais de duas entregas antes da instalação';
    END IF;
END;
$$;

COMMIT;
