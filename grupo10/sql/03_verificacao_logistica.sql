-- E4: executar após 01/02 e antes dos gatilhos. Cada caso negativo captura
-- apenas o tipo de erro esperado; se a operação for aceita, o teste falha.
-- Pré-requisitos: um entregador e uma entrega aguardando atribuição na carga 02.
-- Ausência desses dados é falha de preparação, não rejeição esperada de uma RN.
-- As mensagens abaixo são o texto principal observado no PostgreSQL 18.
-- DETAIL pode variar conforme os IDs gerados e o idioma configurado no servidor.
-- Os NOTICEs reproduzem SQLERRM; ROLLBACK preserva os dados, mas não as sequências.
BEGIN;
DO $$
DECLARE
    v_rota BIGINT;
    v_entrega BIGINT;
    v_pedido BIGINT;
    v_entregador BIGINT;
BEGIN
    SELECT id_entrega, id_pedido INTO STRICT v_entrega, v_pedido
    FROM entrega WHERE status = 'aguardando_entregador' ORDER BY id_entrega LIMIT 1;
    SELECT id_pessoa INTO STRICT v_entregador FROM entregador ORDER BY id_pessoa LIMIT 1;

    -- Regra complementar do ADR-005 e integridade estrutural: criação de rota
    -- e vínculo coerente com o status, antes dos gatilhos de RN12/RR06.
    -- Esperado: INSERT e UPDATE aceitos, com data de criação preenchida.
    INSERT INTO rota (id_entregador) VALUES (v_entregador) RETURNING id_rota INTO v_rota;
    UPDATE entrega SET status = 'aceita', id_rota = v_rota WHERE id_entrega = v_entrega;
    IF NOT EXISTS (SELECT 1 FROM rota WHERE id_rota = v_rota AND criada_em IS NOT NULL)
       OR NOT EXISTS (SELECT 1 FROM entrega WHERE id_entrega = v_entrega
                      AND id_rota = v_rota AND status = 'aceita') THEN
        RAISE EXCEPTION 'Falha na criação de rota ou vinculação válida';
    END IF;

    -- PK de rota: identificador único, sem RN própria na seção 2.
    -- Esperado: rejeição. SGBD [SQLSTATE 23505]: duplicate key value violates unique constraint "pk_rota"
    BEGIN
        INSERT INTO rota (id_rota, id_entregador) OVERRIDING SYSTEM VALUE
        VALUES (v_rota, v_entregador);
        RAISE EXCEPTION 'Falhou: PK duplicada foi aceita';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- Associação Pedido–Entrega 1:1 do modelo lógico, uq_entrega_pedido.
    -- Esperado: rejeição. SGBD [SQLSTATE 23505]: duplicate key value violates unique constraint "uq_entrega_pedido"
    BEGIN
        INSERT INTO entrega (id_pedido, previsao_entrega) VALUES (v_pedido, CURRENT_TIMESTAMP);
        RAISE EXCEPTION 'Falhou: segunda entrega do pedido foi aceita';
    EXCEPTION WHEN unique_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- FK rota→entregador: toda rota referencia um entregador existente.
    -- Esperado: rejeição. SGBD [SQLSTATE 23503]: insert or update on table "rota" violates foreign key constraint "fk_rota_entregador"
    BEGIN
        INSERT INTO rota (id_entregador) SELECT COALESCE(MAX(id_pessoa), 0) + 1 FROM entregador;
        RAISE EXCEPTION 'Falhou: entregador inexistente foi aceito';
    EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- FK entrega→pedido: toda entrega referencia um pedido existente.
    -- Esperado: rejeição. SGBD [SQLSTATE 23503]: insert or update on table "entrega" violates foreign key constraint "fk_entrega_pedido"
    BEGIN
        UPDATE entrega SET id_pedido = (SELECT MAX(id_pedido) + 1 FROM pedido)
        WHERE id_entrega = v_entrega;
        RAISE EXCEPTION 'Falhou: pedido inexistente foi aceito';
    EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- FK entrega→rota: um vínculo preenchido precisa apontar para rota existente.
    -- Esperado: rejeição. SGBD [SQLSTATE 23503]: insert or update on table "entrega" violates foreign key constraint "fk_entrega_rota"
    BEGIN
        UPDATE entrega SET id_rota = (SELECT MAX(id_rota) + 1 FROM rota)
        WHERE id_entrega = v_entrega;
        RAISE EXCEPTION 'Falhou: rota inexistente foi aceita';
    EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- NOT NULL de previsao_entrega, necessária para identificar atrasos na RN03/RR05.
    -- Esperado: rejeição. SGBD [SQLSTATE 23502]: null value in column "previsao_entrega" of relation "entrega" violates not-null constraint
    BEGIN
        UPDATE entrega SET previsao_entrega = NULL WHERE id_entrega = v_entrega;
        RAISE EXCEPTION 'Falhou: previsão nula foi aceita';
    EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- Regra complementar: encerramento não pode anteceder a criação da rota.
    -- Esperado: rejeição. SGBD [SQLSTATE 23514]: new row for relation "rota" violates check constraint "ck_rota_ordem_temporal"
    BEGIN
        UPDATE rota SET encerrada_em = criada_em - INTERVAL '1 second' WHERE id_rota = v_rota;
        RAISE EXCEPTION 'Falhou: encerramento anterior à criação foi aceito';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- ADR-005: entrega aceita exige rota, ck_entrega_status_rota.
    -- Esperado: rejeição. SGBD [SQLSTATE 23514]: new row for relation "entrega" violates check constraint "ck_entrega_status_rota"
    BEGIN
        UPDATE entrega SET id_rota = NULL WHERE id_entrega = v_entrega;
        RAISE EXCEPTION 'Falhou: entrega aceita sem rota foi aceita';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- ADR-005: entrega aguardando entregador ainda não possui rota.
    -- Esperado: rejeição. SGBD [SQLSTATE 23514]: new row for relation "entrega" violates check constraint "ck_entrega_status_rota"
    BEGIN
        UPDATE entrega SET status = 'aguardando_entregador' WHERE id_entrega = v_entrega;
        RAISE EXCEPTION 'Falhou: entrega aguardando com rota foi aceita';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- Domínio do status, usado pelo fluxo RR06; aqui é verificado apenas o ENUM.
    -- Esperado: rejeição. SGBD [SQLSTATE 22P02]: invalid input value for enum status_entrega: "invalido"
    BEGIN
        UPDATE entrega SET status = 'invalido' WHERE id_entrega = v_entrega;
        RAISE EXCEPTION 'Falhou: status fora do ENUM foi aceito';
    EXCEPTION WHEN invalid_text_representation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- Ação referencial RESTRICT: excluir uma rota não deve apagar suas entregas.
    -- Esperado: rejeição. SGBD [SQLSTATE 23001]: update or delete on table "rota" violates RESTRICT setting of foreign key constraint "fk_entrega_rota" on table "entrega"
    BEGIN
        DELETE FROM rota WHERE id_rota = v_rota;
        RAISE EXCEPTION 'Falhou: rota referenciada foi excluída';
    EXCEPTION WHEN restrict_violation THEN RAISE NOTICE '%', SQLERRM;
    END;
    RAISE NOTICE 'PASSOU: verificação das restrições de Logística';
END;
$$;
ROLLBACK;
