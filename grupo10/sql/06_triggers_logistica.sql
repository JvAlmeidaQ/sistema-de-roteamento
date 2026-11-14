-- E6, seção 7.2: funções e gatilhos de Logística, instalados após a carga E4.
-- Dependências: pedido, loja(tempo_entrega_estimado), rota, entrega e seus ENUMs.
-- Funções e gatilhos são criados uma vez, na mesma transação.
-- Erros de negócio usam SQLSTATE 23514 e CONSTRAINT para identificar a proteção.
-- Os testes permitidos/barrados estão em verificacao_dos_gatilhos_logistica.sql.
BEGIN;

-- RN12/RR07, RR06 e ADR-004/005: valida origem, estado inicial e transições.
-- CHECK não resolve: RN12 consulta pedido e RR06 compara OLD com NEW.
-- Estado inicial e imutabilidade de id_pedido são proteções complementares,
-- sem RN numerada própria; não correspondem à RN08 de imutabilidade dos históricos.
CREATE FUNCTION logistica_validar_entrega()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_pedido status_pedido;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- ADR-004/005: nascer aguardando entregador evita pular o fluxo de aceite.
        -- Rejeição: 23514 / ck_entrega_estado_inicial, com a mensagem abaixo.
        IF NEW.status IS DISTINCT FROM 'aguardando_entregador'::status_entrega THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_estado_inicial',
                MESSAGE = 'A entrega deve nascer aguardando entregador';
        END IF;

        -- RN12: FOR SHARE impede mudança concorrente do pedido durante a checagem.
        -- Se o pedido não existir, a FK fk_entrega_pedido rejeita a inserção.
        SELECT status INTO v_status_pedido
        FROM pedido WHERE id_pedido = NEW.id_pedido
        FOR SHARE;

        -- RR07/ADR-004: pronto pressupõe o fluxo comercial anterior de pagamento.
        -- Esta função checa o estado atual, não consulta o histórico comercial.
        IF FOUND AND v_status_pedido <> 'pronto' THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_pedido_pronto',
                MESSAGE = 'RN12: a entrega somente pode ser criada para pedido pronto';
        END IF;
    ELSE
        -- Proteção complementar: não transferir uma entrega existente a outro pedido.
        -- Rejeição: 23514 / ck_entrega_pedido_imutavel.
        IF NEW.id_pedido IS DISTINCT FROM OLD.id_pedido THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_pedido_imutavel',
                MESSAGE = 'Uma entrega existente não pode ser transferida para outro pedido';
        END IF;

        -- RR06: permite avançar uma etapa ou repetir o estado atual.
        -- Saltos/retrocessos: 23514 / ck_entrega_transicao_status.
        -- NULL continua sob responsabilidade da restrição NOT NULL do DDL.
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

-- RN02/RR02: no máximo duas entregas por rota, inclusive as concluídas.
-- CHECK não resolve porque seria preciso contar linhas de outra tabela.
CREATE FUNCTION logistica_limitar_entregas_rota()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Entrega aguardando não ocupa vaga; manter o vínculo não ocupa vaga adicional.
    IF NEW.id_rota IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.id_rota IS NOT DISTINCT FROM OLD.id_rota THEN
        RETURN NEW;
    END IF;

    -- ADR-005: serializa atribuições à mesma rota antes de contar seus vínculos.
    -- Rota inexistente será rejeitada por fk_entrega_rota no DDL.
    PERFORM 1 FROM rota WHERE id_rota = NEW.id_rota FOR UPDATE;
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Atualização técnica de MVCC: cria uma versão da linha sem mudar a data.
    -- Em REPEATABLE READ/SERIALIZABLE, uma transação com snapshot antigo pode
    -- receber 40001 em vez de admitir a terceira entrega por uma contagem antiga.
    -- Futuros gatilhos de rota devem distinguir esta escrita de alterações de negócio.
    UPDATE rota SET criada_em = criada_em WHERE id_rota = NEW.id_rota;

    -- Desconsidera a própria entrega; o limite vale para todos os status.
    -- Rejeição: 23514 / ck_rota_maximo_duas_entregas, mensagem RN02 abaixo.
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

-- RN12/RR07 e sincronização do ADR-004/005: pedido pronto gera a entrega inicial.
-- CHECK não cria linhas em outra tabela nem lê a estimativa cadastrada na loja.
-- Esta função é responsável pela criação automática; a aplicação consulta a
-- entrega gerada, sem inserir outra. UNIQUE(id_pedido) barra duplicação.
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

    -- Atualizar pronto para pronto não cria outra entrega.
    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;

    -- O vínculo com loja é uma FK do pedido; STRICT exige uma estimativa existente.
    SELECT tempo_entrega_estimado INTO STRICT v_tempo_estimado
    FROM loja WHERE id_loja = NEW.id_loja;

    -- ADR-005: snapshot do início do comando de prontidão + estimativa em minutos.
    -- Não usar data_pedido ou início da transação como instante da prontidão.
    -- Alterar a estimativa da loja depois não recalcula entregas já criadas.
    INSERT INTO entrega (id_pedido, previsao_entrega)
    VALUES (
        NEW.id_pedido,
        statement_timestamp() + make_interval(mins => v_tempo_estimado)
    );

    RETURN NEW;
END;
$$;

-- Sincronização do ADR-004, sem RN própria numerada na seção 2:
-- finalizar a entrega conclui seu pedido na mesma transação.
-- CHECK não altera outra tabela; esta sincronização usa um gatilho AFTER UPDATE.
CREATE FUNCTION logistica_concluir_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'entregue' AND NEW.status IS DISTINCT FROM OLD.status THEN
        UPDATE pedido SET status = 'concluido'
        WHERE id_pedido = NEW.id_pedido AND status = 'pronto';

        -- Se não houver pedido pronto para concluir, desfaz também a entrega.
        -- Rejeição: 23514 / ck_entrega_conclusao_pedido.
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_entrega_conclusao_pedido',
                MESSAGE = 'A conclusão da entrega exige um pedido pronto';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- BEFORE valida o estado antes da persistência; nomes 10/20 ordenam os gatilhos
-- BEFORE da entrega quando ambos são acionados pelo mesmo evento.
CREATE TRIGGER trg_entrega_10_validar
BEFORE INSERT OR UPDATE OF status, id_pedido ON entrega
FOR EACH ROW EXECUTE FUNCTION logistica_validar_entrega();

-- RN02: cobre tanto INSERT quanto transferência de uma entrega para outra rota.
CREATE TRIGGER trg_entrega_20_limitar_rota
BEFORE INSERT OR UPDATE OF id_rota ON entrega
FOR EACH ROW EXECUTE FUNCTION logistica_limitar_entregas_rota();

-- AFTER sincroniza o pedido somente após a atualização válida da entrega.
CREATE TRIGGER trg_entrega_30_concluir_pedido
AFTER UPDATE OF status ON entrega
FOR EACH ROW EXECUTE FUNCTION logistica_concluir_pedido();

-- RN12: cobre pedido inserido pronto e pedido que acaba de mudar para pronto.
CREATE TRIGGER trg_pedido_logistica_gerar_entrega
AFTER INSERT OR UPDATE OF status ON pedido
FOR EACH ROW EXECUTE FUNCTION logistica_gerar_entrega();

-- Verificação preventiva da RN02 na instalação: gatilhos não validam retroativamente
-- os vínculos da carga. Não corrigir/apagar dados inválidos silenciosamente.
-- Erro de instalação: P0001, mensagem "RN02: existem rotas com mais de duas entregas antes da instalação".
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
