-- =============================================================================
-- GATILHOS E FUNÇÕES — ENTREGA E6 (SEÇÃO 7.2)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Logística (mesma de 01_esquema.sql).
-- Padrão de erro de negócio: SQLSTATE '23514' (check_violation) com CONSTRAINT.
-- =============================================================================

BEGIN;

-- =============================================================================
-- SUBDOMÍNIO: IDENTIDADE E CONTATO
-- Nota de escopo: As demais regras do subdomínio (formato e unicidade de CPF,
-- e-mail, tipo de veículo e vínculo de papéis) já são garantidas de forma
-- declarativa no DDL (01_esquema.sql) via CHECK, UNIQUE e FOREIGN KEY.
-- Apenas a RR12 exige gatilho por depender da comparação entre OLD e NEW.
-- =============================================================================

-- RR12 — Imutabilidade dos dados de localização do endereço
-- Regra (Seção 2): "Dados de localização (logradouro, numero, cep) na tabela
-- Endereco não podem sofrer alterações após sua inserção."
-- Por que CHECK não resolve: restrições declarativas (CHECK, UNIQUE, FK)
-- avaliam apenas o estado novo da linha. Somente um gatilho BEFORE UPDATE tem
-- acesso simultâneo a OLD e NEW para impedir mudanças mantendo alterações em
-- colunas não protegidas (bairro, cidade, estado) ou regravação do mesmo valor.
CREATE FUNCTION identidade_bloquear_alteracao_endereco()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.logradouro IS DISTINCT FROM OLD.logradouro
       OR NEW.numero  IS DISTINCT FROM OLD.numero
       OR NEW.cep     IS DISTINCT FROM OLD.cep THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'ck_endereco_localizacao_imutavel',
            MESSAGE = format(
                'RR12: logradouro, número e CEP do endereço %s não podem ser alterados',
                OLD.id_endereco),
            HINT = 'Cadastre um novo endereço e vincule-o à pessoa em pessoa_endereco.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_endereco_localizacao_imutavel
BEFORE UPDATE OF logradouro, numero, cep ON endereco
FOR EACH ROW
EXECUTE FUNCTION identidade_bloquear_alteracao_endereco();


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- RN12/RR07, RR06 e ADR-004/005: valida origem, estado inicial, imutabilidade
-- de id_pedido e transições válidas de status da entrega.
-- Por que CHECK não resolve: RN12 consulta o status na tabela pedido e RR06
-- exige comparar o estado anterior (OLD.status) com o novo (NEW.status).
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

        -- FOR SHARE impede mudança concorrente do pedido durante a checagem.
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

-- RN02/RR02: no máximo duas entregas por rota, inclusive as concluídas.
-- Por que CHECK não resolve: exige contagem agregada de linhas em outra tabela
-- (entrega) associadas à mesma rota, com serialização concorrente em rota.
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

    -- Serializa atribuições concorrentes à mesma rota (ADR-005).
    PERFORM 1 FROM rota WHERE id_rota = NEW.id_rota FOR UPDATE;
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Atualização técnica de MVCC para detectar conflito em REPEATABLE READ/SERIALIZABLE.
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

-- RN12/RR07 e ADR-004/005: pedido pronto gera automaticamente a entrega inicial.
-- Por que CHECK não resolve: restrições declarativas não inserem linhas em
-- outra tabela nem consultam tempo_entrega_estimado na tabela loja.
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

-- Sincronização ADR-004: finalizar a entrega conclui o pedido na mesma transação.
-- Por que CHECK não resolve: exige atualização em outra tabela (pedido).
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

-- Verificação preventiva da RN02 na instalação dos gatilhos.
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
