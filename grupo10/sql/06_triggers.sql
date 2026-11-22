-- =============================================================================
-- GATILHOS E FUNÇÕES — ENTREGA E6 (SEÇÃO 7.2)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Comércio e Finanças -> Logística -> Auditoria
-- (mesma sequência de 01_esquema.sql).
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
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =============================================================================

-- RR03 e RR06 (Seção 2): valida posse do endereço de entrega pelo cliente e
-- transições válidas da máquina de estados do pedido.
-- Por que CHECK não resolve: RR03 exige consultar a tabela pessoa_endereco
-- para confirmar que (id_cliente, id_endereco) pertence ao cliente; RR06 exige
-- comparar OLD.status com NEW.status durante o UPDATE.
CREATE FUNCTION comercio_validar_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       OR NEW.id_cliente IS DISTINCT FROM OLD.id_cliente
       OR NEW.id_endereco IS DISTINCT FROM OLD.id_endereco THEN
        IF NOT EXISTS (
            SELECT 1
              FROM pessoa_endereco pe
             WHERE pe.id_pessoa = NEW.id_cliente
               AND pe.id_endereco = NEW.id_endereco
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_pedido_endereco_cliente',
                MESSAGE = format(
                    'RR03: o endereço %s não está vinculado ao cliente %s',
                    NEW.id_endereco, NEW.id_cliente);
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status AND NEW.status IS NOT NULL THEN
        IF NOT (
            (OLD.status = 'solicitado' AND NEW.status IN ('aceito', 'recusado'))
            OR (OLD.status = 'aceito' AND NEW.status = 'pago')
            OR (OLD.status = 'pago' AND NEW.status = 'em_preparacao')
            OR (OLD.status = 'em_preparacao' AND NEW.status = 'pronto')
            OR (OLD.status = 'pronto' AND NEW.status = 'concluido')
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_pedido_transicao_status',
                MESSAGE = format('RR06: transição inválida de pedido: %s -> %s', OLD.status, NEW.status);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- RN01/RR04 e RR09 (Seção 2): garante que o produto incluído no item esteja ativo
-- e que o valor_unitario corresponda ao preço vigente no catálogo (snapshot).
-- Por que CHECK não resolve: restrições CHECK em item_pedido não podem consultar
-- as colunas ativo e preco na tabela produto.
CREATE FUNCTION comercio_validar_item_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_produto RECORD;
BEGIN
    SELECT ativo, preco
      INTO v_produto
      FROM produto
     WHERE id_loja = NEW.id_loja
       AND id_produto = NEW.id_produto;

    -- Se o produto não existir, a FK composta fk_item_produto_loja rejeita no DDL.
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF NOT v_produto.ativo THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'ck_item_pedido_produto_ativo',
            MESSAGE = format(
                'RN01/RR04: o produto %s da loja %s está inativo para novos pedidos',
                NEW.id_produto, NEW.id_loja);
    END IF;

    IF NEW.valor_unitario IS DISTINCT FROM v_produto.preco THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'ck_item_pedido_snapshot_preco',
            MESSAGE = format(
                'RR09: valor_unitario (%s) diverge do preço vigente (%s) do produto %s',
                NEW.valor_unitario, v_produto.preco, NEW.id_produto);
    END IF;

    RETURN NEW;
END;
$$;

-- RN13/RR08 e RN05 (Seção 2): avaliações (loja/entregador) e divisão de
-- pagamento só podem existir após o pedido concluído e a entrega em 'entregue';
-- na divisão de pagamento, confere também coerência com valor_total e taxa_entrega.
-- Por que CHECK não resolve: exige consultar status nas tabelas pedido e entrega
-- e comparar os valores monetários armazenados em pedido.
CREATE FUNCTION comercio_validar_pos_entrega()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_pedido RECORD;
BEGIN
    SELECT p.status, p.valor_total, p.taxa_entrega
      INTO v_pedido
      FROM pedido p
     WHERE p.id_pedido = NEW.id_pedido;

    -- Se o pedido não existir, a FK da respectiva tabela rejeita no DDL.
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    IF v_pedido.status <> 'concluido'
       OR NOT EXISTS (
           SELECT 1
             FROM entrega e
            WHERE e.id_pedido = NEW.id_pedido
              AND e.status = 'entregue'
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'ck_pos_entrega_pedido_concluido',
            MESSAGE = format(
                'RN13/RR08: o pedido %s precisa estar concluído com entrega realizada antes do registro pós-entrega',
                NEW.id_pedido);
    END IF;

    IF TG_TABLE_NAME = 'divisao_pagamento' THEN
        IF NEW.valor_total IS DISTINCT FROM v_pedido.valor_total
           OR NEW.comissao_entregador IS DISTINCT FROM v_pedido.taxa_entrega THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'ck_divisao_pagamento_valores_pedido',
                MESSAGE = format(
                    'RN05: divisão de pagamento do pedido %s diverge de valor_total ou taxa_entrega do pedido',
                    NEW.id_pedido);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pedido_10_validar
BEFORE INSERT OR UPDATE OF id_cliente, id_endereco, status ON pedido
FOR EACH ROW EXECUTE FUNCTION comercio_validar_pedido();

CREATE TRIGGER trg_item_pedido_10_validar
BEFORE INSERT OR UPDATE OF id_loja, id_produto, valor_unitario ON item_pedido
FOR EACH ROW EXECUTE FUNCTION comercio_validar_item_pedido();

CREATE TRIGGER trg_divisao_pagamento_10_validar
BEFORE INSERT OR UPDATE OF id_pedido, valor_total, comissao_entregador ON divisao_pagamento
FOR EACH ROW EXECUTE FUNCTION comercio_validar_pos_entrega();

CREATE TRIGGER trg_avaliacao_loja_10_validar
BEFORE INSERT OR UPDATE OF id_pedido ON avaliacao_loja
FOR EACH ROW EXECUTE FUNCTION comercio_validar_pos_entrega();

CREATE TRIGGER trg_avaliacao_entregador_10_validar
BEFORE INSERT OR UPDATE OF id_pedido ON avaliacao_entregador
FOR EACH ROW EXECUTE FUNCTION comercio_validar_pos_entrega();


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- RN12/RR07 e RR06 (Seção 2): valida origem, estado inicial, imutabilidade
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

    -- Serializa atribuições concorrentes à mesma rota.
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

-- RN12/RR07 (Seção 2): pedido pronto gera automaticamente a entrega inicial.
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

-- Sincronização de estados entre Entrega e Pedido: finalizar a entrega conclui
-- o pedido na mesma transação.
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


-- =============================================================================
-- SUBDOMÍNIO: AUDITORIA
-- =============================================================================

-- RN08/RR11 (Seção 2): bloqueio absoluto de UPDATE, DELETE e TRUNCATE nas
-- tabelas de trilha cronológica (historico_pedido e historico_entrega),
-- garantindo que o histórico de auditoria seja estritamente append-only (ADR-004).
-- Por que CHECK não resolve: restrições declarativas (CHECK, UNIQUE, FK) não
-- interceptam operações de remoção (DELETE/TRUNCATE) nem bloqueiam mutações
-- arbitrárias em registros históricos já persistidos. Apenas gatilhos BEFORE
-- (em nível de linha e de instrução) impedem qualquer alteração retroativa.
CREATE FUNCTION auditoria_bloquear_mutacao_historico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = '23514',
        CONSTRAINT = format('ck_%s_imutavel', TG_TABLE_NAME),
        MESSAGE = format(
            'RN08/RR11: registros da tabela %s são estritamente imutáveis (operação %s bloqueada)',
            TG_TABLE_NAME, TG_OP),
        HINT = 'A trilha de auditoria é append-only; registre apenas novas transições de estado.';
END;
$$;

-- RN04 (Seção 2): gravação automática de evento cronológico em historico_pedido
-- a cada criação ou mudança de status do pedido (ADR-004).
-- Por que CHECK não resolve: restrições CHECK apenas validam colunas da própria
-- linha e não inserem registros derivados na tabela historico_pedido.
CREATE FUNCTION auditoria_registrar_historico_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       OR (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN
        INSERT INTO historico_pedido (id_pedido, status, data_hora)
        VALUES (NEW.id_pedido, NEW.status, CURRENT_TIMESTAMP)
        ON CONFLICT (id_pedido, status) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

-- RN04 (Seção 2): gravação automática de evento cronológico em historico_entrega
-- a cada criação ou mudança de status da entrega (ADR-004).
-- Por que CHECK não resolve: restrições CHECK não propagam eventos de transição
-- de estado para a tabela historico_entrega.
CREATE FUNCTION auditoria_registrar_historico_entrega()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       OR (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN
        INSERT INTO historico_entrega (id_entrega, status, data_hora)
        VALUES (NEW.id_entrega, NEW.status, CURRENT_TIMESTAMP)
        ON CONFLICT (id_entrega, status) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_historico_pedido_10_imutavel
BEFORE UPDATE OR DELETE ON historico_pedido
FOR EACH ROW EXECUTE FUNCTION auditoria_bloquear_mutacao_historico();

CREATE TRIGGER trg_historico_pedido_20_imutavel_stmt
BEFORE UPDATE OR DELETE OR TRUNCATE ON historico_pedido
FOR EACH STATEMENT EXECUTE FUNCTION auditoria_bloquear_mutacao_historico();

CREATE TRIGGER trg_historico_entrega_10_imutavel
BEFORE UPDATE OR DELETE ON historico_entrega
FOR EACH ROW EXECUTE FUNCTION auditoria_bloquear_mutacao_historico();

CREATE TRIGGER trg_historico_entrega_20_imutavel_stmt
BEFORE UPDATE OR DELETE OR TRUNCATE ON historico_entrega
FOR EACH STATEMENT EXECUTE FUNCTION auditoria_bloquear_mutacao_historico();

CREATE TRIGGER trg_pedido_20_auditoria_registrar_historico
AFTER INSERT OR UPDATE OF status ON pedido
FOR EACH ROW EXECUTE FUNCTION auditoria_registrar_historico_pedido();

CREATE TRIGGER trg_entrega_25_auditoria_registrar_historico
AFTER INSERT OR UPDATE OF status ON entrega
FOR EACH ROW EXECUTE FUNCTION auditoria_registrar_historico_entrega();

-- Verificação preventiva da RN04 na instalação dos gatilhos.
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
        RAISE EXCEPTION 'RN04: existem pedidos sem registro do status atual em historico_pedido antes da instalação';
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
        RAISE EXCEPTION 'RN04: existem entregas sem registro do status atual em historico_entrega antes da instalação';
    END IF;
END;
$$;

COMMIT;