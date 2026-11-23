-- Disciplina: DCC061 (Engenharia de Software)
-- RF05 / RN04 / RN08 / RR11: trilha de rastreio de pedido e entrega.
-- Não reconstitui eventos anteriores à instalação: seus horários podem ser desconhecidos.

CREATE FUNCTION rastreio_registrar_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
            RETURN NEW;
        END IF;
    END IF;

    -- Os dois eventos de uma transição sincronizada compartilham o instante da instrução.
    IF TG_TABLE_NAME = 'pedido' THEN
        INSERT INTO historico_pedido (id_pedido, status, data_hora)
        VALUES (NEW.id_pedido, NEW.status, statement_timestamp());
    ELSE
        INSERT INTO historico_entrega (id_entrega, status, data_hora)
        VALUES (NEW.id_entrega, NEW.status, statement_timestamp());
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pedido_rastreio_status
AFTER INSERT OR UPDATE OF status ON pedido
FOR EACH ROW EXECUTE FUNCTION rastreio_registrar_status();

CREATE TRIGGER trg_entrega_rastreio_status
AFTER INSERT OR UPDATE OF status ON entrega
FOR EACH ROW EXECUTE FUNCTION rastreio_registrar_status();

CREATE FUNCTION rastreio_impedir_alteracao_de_evento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = '23514',
        CONSTRAINT = 'ck_historico_imutavel',
        MESSAGE = 'RN08/RR11: eventos de rastreio não podem ser alterados ou excluídos';
END;
$$;

CREATE TRIGGER trg_historico_pedido_imutavel
BEFORE UPDATE OR DELETE ON historico_pedido
FOR EACH ROW EXECUTE FUNCTION rastreio_impedir_alteracao_de_evento();

CREATE TRIGGER trg_historico_entrega_imutavel
BEFORE UPDATE OR DELETE ON historico_entrega
FOR EACH ROW EXECUTE FUNCTION rastreio_impedir_alteracao_de_evento();
