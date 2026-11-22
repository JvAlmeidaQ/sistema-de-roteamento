-- =============================================================================
-- VERIFICAÇÃO DOS GATILHOS — ENTREGA E6 (SEÇÃO 7.3)
-- Pré-requisito: 01_esquema.sql, 02_carga.sql e 06_triggers.sql.
-- Ordem dos subdomínios: Identidade e Contato -> Logística (mesma de 01_esquema.sql).
-- Todos os testes rodam em transação com ROLLBACK ao final, preservando a carga.
-- =============================================================================

BEGIN;

-- =============================================================================
-- SUBDOMÍNIO: IDENTIDADE E CONTATO
-- =============================================================================

DO $$
DECLARE
    v_id_endereco_centro BIGINT;
BEGIN
    -- 1) Caso barrado (RR12): alteração de numero em endereco.
    -- Esperado: SQLSTATE 23514 (ck_endereco_localizacao_imutavel).
    BEGIN
        UPDATE endereco
           SET numero = '999'
         WHERE id_endereco = 1;
        RAISE EXCEPTION 'Falhou: alteração de numero em endereco foi aceita';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RR12 numero): %', SQLERRM;
    END;

    -- 2) Caso barrado (RR12): alteração em lote de cep em endereco.
    -- Esperado: SQLSTATE 23514 (ck_endereco_localizacao_imutavel).
    SELECT MIN(id_endereco) INTO STRICT v_id_endereco_centro
      FROM endereco
     WHERE bairro = 'Centro';

    BEGIN
        UPDATE endereco
           SET cep = '36000000'
         WHERE bairro = 'Centro';
        RAISE EXCEPTION 'Falhou: alteração de CEP em endereco foi aceita';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RR12 cep): %', SQLERRM;
    END;

    -- 3) Caso permitido (RR12): regravação do mesmo valor em coluna protegida.
    UPDATE endereco
       SET numero = numero
     WHERE id_endereco = 1;

    -- 4) Caso permitido (RR12): atualização de coluna não protegida (bairro).
    UPDATE endereco
       SET bairro = 'Bairro Corrigido'
     WHERE id_endereco = 1;

    RAISE NOTICE 'PASSOU: verificação do gatilho de Identidade e Contato (RR12)';
END;
$$;


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- Clona apenas vínculos e valores válidos da carga para testar dois vínculos
-- permitidos e a terceira atribuição barrada pela RN02.
CREATE TEMP TABLE pedidos_teste_logistica ON COMMIT DROP AS
WITH novos AS (
    INSERT INTO pedido (id_loja, id_cliente, id_endereco, status, forma_pagamento,
                        subtotal, taxa_entrega, taxa_servico, valor_total)
    SELECT p.id_loja, p.id_cliente, p.id_endereco, 'em_preparacao', p.forma_pagamento,
           p.subtotal, p.taxa_entrega, p.taxa_servico, p.valor_total
      FROM (SELECT * FROM pedido ORDER BY id_pedido LIMIT 1) p
     CROSS JOIN generate_series(1, 3)
    RETURNING id_pedido
)
SELECT id_pedido FROM novos;

DO $$
DECLARE
    v_pedido BIGINT;
    v_rota BIGINT;
    v_entregador BIGINT;
BEGIN
    IF (SELECT COUNT(*) FROM pedidos_teste_logistica) <> 3 THEN
        RAISE EXCEPTION 'A verificação exige ao menos um pedido na base para copiar os vínculos';
    END IF;

    SELECT MIN(id_pedido) INTO v_pedido FROM pedidos_teste_logistica;
    SELECT id_pessoa INTO STRICT v_entregador FROM entregador ORDER BY id_pessoa LIMIT 1;
    INSERT INTO rota (id_entregador) VALUES (v_entregador) RETURNING id_rota INTO v_rota;

    -- 1) Caso barrado (RN12/RR07): pedido em preparação não pode originar entrega.
    IF EXISTS (SELECT 1 FROM entrega WHERE id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica)) THEN
        RAISE EXCEPTION 'Falhou: pedido em preparação gerou entrega automática';
    END IF;

    BEGIN
        INSERT INTO entrega (id_pedido, previsao_entrega) VALUES (v_pedido, CURRENT_TIMESTAMP);
        RAISE EXCEPTION 'Falhou: entrega de pedido em preparação foi aceita';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RN12): %', SQLERRM;
    END;

    -- 2) Caso permitido (RN12/RR07): ao ficar pronto, cada pedido gera entrega
    -- aguardando entregador, sem rota e com previsão calculada pela loja.
    UPDATE pedido SET status = 'pronto'
     WHERE id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica);

    IF (SELECT COUNT(*)
          FROM entrega e
          JOIN pedido p USING (id_pedido)
          JOIN loja l USING (id_loja)
         WHERE e.id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica)
           AND e.status = 'aguardando_entregador'
           AND e.id_rota IS NULL
           AND e.previsao_entrega = statement_timestamp() + make_interval(mins => l.tempo_entrega_estimado)) <> 3 THEN
        RAISE EXCEPTION 'Falhou: geração automática de entrega ou cálculo da previsão';
    END IF;

    -- 3) Caso barrado (RR06): salto de aguardando_entregador para a_caminho.
    BEGIN
        UPDATE entrega SET status = 'a_caminho', id_rota = v_rota WHERE id_pedido = v_pedido;
        RAISE EXCEPTION 'Falhou: salto inválido de status foi aceito';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RR06): %', SQLERRM;
    END;

    -- 4) Caso permitido (RN02/RR02 e RR06): duas entregas cabem na mesma rota.
    UPDATE entrega SET status = 'aceita', id_rota = v_rota
     WHERE id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica ORDER BY id_pedido LIMIT 2);

    IF (SELECT COUNT(*) FROM entrega WHERE id_rota = v_rota) <> 2 THEN
        RAISE EXCEPTION 'Falhou: primeira ou segunda entrega foi bloqueada';
    END IF;

    -- 5) Caso barrado (RN02/RR02): terceira entrega na mesma rota é rejeitada.
    BEGIN
        UPDATE entrega SET status = 'aceita', id_rota = v_rota
         WHERE id_pedido = (SELECT MAX(id_pedido) FROM pedidos_teste_logistica);
        RAISE EXCEPTION 'Falhou: terceira entrega na mesma rota foi aceita';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RN02): %', SQLERRM;
    END;

    -- 6) Caso permitido (RR06 e sincronização ADR-004): aceita -> a_caminho -> entregue conclui o pedido.
    UPDATE entrega SET status = 'a_caminho' WHERE id_pedido = v_pedido;
    UPDATE entrega SET status = 'entregue' WHERE id_pedido = v_pedido;

    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = v_pedido AND status = 'concluido') THEN
        RAISE EXCEPTION 'Falhou: entrega finalizada não concluiu o pedido';
    END IF;

    RAISE NOTICE 'PASSOU: verificação dos quatro gatilhos de Logística';
END;
$$;

ROLLBACK;
