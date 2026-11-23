-- =============================================================================
-- VERIFICAÇÃO DOS GATILHOS — ENTREGA E6 (SEÇÃO 7.3)
-- Pré-requisito: 01_esquema.sql, 02_carga.sql e 06_triggers.sql.
-- O bloco de rastreio (DCC061) requer também as migrações 08 e 09.
-- Ordem dos subdomínios: Identidade e Contato -> Comércio e Finanças -> Logística
-- -> Auditoria (mesma sequência de 01_esquema.sql).
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
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =============================================================================

DO $$
DECLARE
    v_loja          RECORD;
    v_cliente       RECORD;
    v_end_alheio    BIGINT;
    v_prod_ativo    RECORD;
    v_prod_inativo  RECORD;
    v_entregador    BIGINT;
    v_rota          BIGINT;
    v_id_pedido     BIGINT;
    v_valor_total   NUMERIC(12,2);
    v_parcela_loja  NUMERIC(12,2);
    v_taxa_plat     NUMERIC(12,2);
BEGIN
    SELECT id_loja, taxa_entrega
      INTO STRICT v_loja
      FROM loja
     WHERE status_funcionamento = 'aberta'
     ORDER BY id_loja
     LIMIT 1;

    SELECT pe.id_pessoa AS id_cliente, pe.id_endereco
      INTO STRICT v_cliente
      FROM cliente c
      JOIN pessoa_endereco pe ON pe.id_pessoa = c.id_pessoa
     ORDER BY pe.id_pessoa, pe.id_endereco
     LIMIT 1;

    SELECT e.id_endereco
      INTO STRICT v_end_alheio
      FROM endereco e
     WHERE NOT EXISTS (
         SELECT 1 FROM pessoa_endereco pe
          WHERE pe.id_pessoa = v_cliente.id_cliente
            AND pe.id_endereco = e.id_endereco
     )
     ORDER BY e.id_endereco
     LIMIT 1;

    SELECT id_produto, preco
      INTO STRICT v_prod_ativo
      FROM produto
     WHERE id_loja = v_loja.id_loja
       AND ativo = TRUE
     ORDER BY id_produto
     LIMIT 1;

    SELECT id_loja, id_produto, preco
      INTO STRICT v_prod_inativo
      FROM produto
     WHERE ativo = FALSE
     ORDER BY id_loja, id_produto
     LIMIT 1;

    -- 1) Caso barrado (RR03): pedido com endereço que não pertence ao cliente.
    BEGIN
        INSERT INTO pedido (
            id_loja, id_cliente, id_endereco, status, forma_pagamento,
            subtotal, taxa_entrega, taxa_servico, valor_total
        ) VALUES (
            v_loja.id_loja, v_cliente.id_cliente, v_end_alheio, 'solicitado', 'pix',
            v_prod_ativo.preco, v_loja.taxa_entrega, 2.50,
            v_prod_ativo.preco + v_loja.taxa_entrega + 2.50
        );
        RAISE EXCEPTION 'Falhou: pedido com endereço de terceiros foi aceito';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RR03): %', SQLERRM;
    END;

    -- 2) Caso permitido (RR03): pedido com endereço vinculado ao próprio cliente.
    v_valor_total := v_prod_ativo.preco + v_loja.taxa_entrega + 2.50;
    INSERT INTO pedido (
        id_loja, id_cliente, id_endereco, status, forma_pagamento,
        subtotal, taxa_entrega, taxa_servico, valor_total
    ) VALUES (
        v_loja.id_loja, v_cliente.id_cliente, v_cliente.id_endereco, 'solicitado', 'pix',
        v_prod_ativo.preco, v_loja.taxa_entrega, 2.50, v_valor_total
    )
    RETURNING id_pedido INTO v_id_pedido;

    -- 3) Caso barrado (RR09): item_pedido com valor_unitario divergente do preço vigente.
    BEGIN
        INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
        VALUES (v_id_pedido, v_prod_ativo.id_produto, v_loja.id_loja, 1, v_prod_ativo.preco + 1.00);
        RAISE EXCEPTION 'Falhou: item com valor_unitario divergente do catálogo foi aceito';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RR09): %', SQLERRM;
    END;

    -- 4) Caso permitido (RN01/RR04 e RR09): item_pedido de produto ativo com preço vigente.
    INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
    VALUES (v_id_pedido, v_prod_ativo.id_produto, v_loja.id_loja, 1, v_prod_ativo.preco);

    -- 5) Caso barrado (RN01/RR04): tentativa de inserir item com produto inativo.
    DECLARE
        v_id_ped_inativo BIGINT;
    BEGIN
        INSERT INTO pedido (
            id_loja, id_cliente, id_endereco, status, forma_pagamento,
            subtotal, taxa_entrega, taxa_servico, valor_total
        ) VALUES (
            v_prod_inativo.id_loja, v_cliente.id_cliente, v_cliente.id_endereco, 'solicitado', 'pix',
            v_prod_inativo.preco, 5.00, 2.50, v_prod_inativo.preco + 7.50
        )
        RETURNING id_pedido INTO v_id_ped_inativo;

        INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
        VALUES (v_id_ped_inativo, v_prod_inativo.id_produto, v_prod_inativo.id_loja, 1, v_prod_inativo.preco);
        RAISE EXCEPTION 'Falhou: item com produto inativo foi aceito';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RN01/RR04): %', SQLERRM;
    END;

    -- 6) Caso barrado (RR06): salto inválido de status no pedido (solicitado -> pronto).
    BEGIN
        UPDATE pedido SET status = 'pronto' WHERE id_pedido = v_id_pedido;
        RAISE EXCEPTION 'Falhou: salto de status de pedido foi aceito';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RR06 pedido): %', SQLERRM;
    END;

    -- 7) Caso barrado (RN13/RR08): avaliação de loja e divisão antes da entrega concluída.
    BEGIN
        INSERT INTO avaliacao_loja (id_pedido, nota, comentario)
        VALUES (v_id_pedido, 5, 'Tentativa prematura');
        RAISE EXCEPTION 'Falhou: avaliação antes da conclusão foi aceita';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RN13/RR08 avaliacao): %', SQLERRM;
    END;

    -- Avança o fluxo válido: solicitado -> aceito -> pago -> em_preparacao -> pronto -> entrega entregue
    UPDATE pedido SET status = 'aceito' WHERE id_pedido = v_id_pedido;
    UPDATE pedido SET status = 'pago' WHERE id_pedido = v_id_pedido;
    UPDATE pedido SET status = 'em_preparacao' WHERE id_pedido = v_id_pedido;
    UPDATE pedido SET status = 'pronto' WHERE id_pedido = v_id_pedido;

    SELECT id_pessoa INTO STRICT v_entregador FROM entregador ORDER BY id_pessoa LIMIT 1;
    INSERT INTO rota (id_entregador) VALUES (v_entregador) RETURNING id_rota INTO v_rota;
    UPDATE entrega SET status = 'aceita', id_rota = v_rota WHERE id_pedido = v_id_pedido;
    UPDATE entrega SET status = 'a_caminho' WHERE id_pedido = v_id_pedido;
    UPDATE entrega SET status = 'entregue' WHERE id_pedido = v_id_pedido;

    -- 8) Caso barrado (RN05): divisão de pagamento com comissão divergente da taxa_entrega do pedido.
    v_parcela_loja := ROUND(v_prod_ativo.preco * 0.85, 2);
    v_taxa_plat    := v_valor_total - v_parcela_loja - v_loja.taxa_entrega;
    BEGIN
        INSERT INTO divisao_pagamento (
            id_pedido, valor_total, taxa_plataforma, parcela_loja, comissao_entregador
        ) VALUES (
            v_id_pedido, v_valor_total, v_taxa_plat + 1.00, v_parcela_loja, v_loja.taxa_entrega - 1.00
        );
        RAISE EXCEPTION 'Falhou: divisão divergente da taxa_entrega foi aceita';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'BARRADO (esperado - RN05): %', SQLERRM;
    END;

    -- 9) Casos permitidos (RN13/RR08 e RN05): avaliação e divisão após entrega concluída.
    INSERT INTO avaliacao_loja (id_pedido, nota, comentario)
    VALUES (v_id_pedido, 5, 'Pedido entregue no prazo.');
    INSERT INTO avaliacao_entregador (id_pedido, nota, comentario)
    VALUES (v_id_pedido, 5, 'Entregador cordial.');
    INSERT INTO divisao_pagamento (
        id_pedido, valor_total, taxa_plataforma, parcela_loja, comissao_entregador
    ) VALUES (
        v_id_pedido, v_valor_total, v_taxa_plat, v_parcela_loja, v_loja.taxa_entrega
    );

    RAISE NOTICE 'PASSOU: verificação dos gatilhos de Comércio e Finanças (RR03, RR04, RR06, RR08, RR09, RN05, RN13)';
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

    -- 6) Caso permitido (RR06 e sincronização Entrega -> Pedido): aceita -> a_caminho -> entregue conclui o pedido.
    UPDATE entrega SET status = 'a_caminho' WHERE id_pedido = v_pedido;
    UPDATE entrega SET status = 'entregue' WHERE id_pedido = v_pedido;

    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = v_pedido AND status = 'concluido') THEN
        RAISE EXCEPTION 'Falhou: entrega finalizada não concluiu o pedido';
    END IF;

    RAISE NOTICE 'PASSOU: verificação dos quatro gatilhos de Logística';
END;
$$;


-- =============================================================================
-- DCC061: AUDITORIA DE RASTREIO (RN04, RN08 e RR11)
-- =============================================================================

DO $$
DECLARE
    v_id_pedido      BIGINT;
    v_id_entrega     BIGINT;
    v_id_rota        BIGINT;
    v_fluxo_pedido   CONSTANT status_pedido[] :=
        ARRAY['solicitado', 'aceito', 'pago', 'em_preparacao', 'pronto']::status_pedido[];
    v_fluxo_entrega  CONSTANT status_entrega[] :=
        ARRAY['aguardando_entregador', 'aceita', 'a_caminho', 'entregue']::status_entrega[];
    v_operacao       TEXT;
    v_constraint     TEXT;
BEGIN
    -- Reaproveita os vínculos da fixture de Logística, sem copiar eventos legados.
    INSERT INTO pedido (id_loja, id_cliente, id_endereco, forma_pagamento,
                        subtotal, taxa_entrega, taxa_servico, valor_total)
    SELECT p.id_loja, p.id_cliente, p.id_endereco, p.forma_pagamento,
           p.subtotal, p.taxa_entrega, p.taxa_servico, p.valor_total
      FROM pedidos_teste_logistica t
      JOIN pedido p USING (id_pedido)
     ORDER BY p.id_pedido
     LIMIT 1
    RETURNING id_pedido INTO STRICT v_id_pedido;

    -- O primeiro passo verifica o INSERT; os demais verificam cada transição.
    FOR v_etapa IN 1..cardinality(v_fluxo_pedido) LOOP
        IF v_etapa > 1 THEN
            UPDATE pedido SET status = v_fluxo_pedido[v_etapa] WHERE id_pedido = v_id_pedido;
        END IF;

        IF (SELECT array_agg(status ORDER BY status) FROM historico_pedido WHERE id_pedido = v_id_pedido)
            IS DISTINCT FROM v_fluxo_pedido[1:v_etapa] THEN
            RAISE EXCEPTION 'Falhou (RN04): histórico do pedido não corresponde ao fluxo até %',
                v_fluxo_pedido[v_etapa];
        END IF;
    END LOOP;

    UPDATE pedido SET status = status WHERE id_pedido = v_id_pedido;
    IF NOT FOUND OR
        (SELECT array_agg(status ORDER BY status) FROM historico_pedido WHERE id_pedido = v_id_pedido)
            IS DISTINCT FROM v_fluxo_pedido THEN
        RAISE EXCEPTION 'Falhou (RN04): regravar o mesmo status do pedido deve preservar o histórico';
    END IF;

    -- Usa a entrega criada pelo fluxo RN12 e uma rota exclusiva desta fixture.
    SELECT id_entrega INTO STRICT v_id_entrega FROM entrega WHERE id_pedido = v_id_pedido;
    INSERT INTO rota (id_entregador)
    SELECT id_pessoa FROM entregador ORDER BY id_pessoa LIMIT 1
    RETURNING id_rota INTO STRICT v_id_rota;

    FOR v_etapa IN 1..cardinality(v_fluxo_entrega) LOOP
        IF v_etapa = 2 THEN
            UPDATE entrega SET status = v_fluxo_entrega[v_etapa], id_rota = v_id_rota
             WHERE id_entrega = v_id_entrega;
        ELSIF v_etapa > 2 THEN
            UPDATE entrega SET status = v_fluxo_entrega[v_etapa] WHERE id_entrega = v_id_entrega;
        END IF;

        IF (SELECT array_agg(status ORDER BY status) FROM historico_entrega WHERE id_entrega = v_id_entrega)
            IS DISTINCT FROM v_fluxo_entrega[1:v_etapa] THEN
            RAISE EXCEPTION 'Falhou (RN04): histórico da entrega não corresponde ao fluxo até %',
                v_fluxo_entrega[v_etapa];
        END IF;
    END LOOP;

    IF (SELECT array_agg(status ORDER BY status) FROM historico_pedido WHERE id_pedido = v_id_pedido)
        IS DISTINCT FROM (v_fluxo_pedido || 'concluido'::status_pedido) THEN
        RAISE EXCEPTION 'Falhou (RN04): finalizar a entrega deve acrescentar concluido ao histórico do pedido';
    END IF;

    UPDATE entrega SET status = status WHERE id_entrega = v_id_entrega;
    IF NOT FOUND OR
        (SELECT array_agg(status ORDER BY status) FROM historico_entrega WHERE id_entrega = v_id_entrega)
            IS DISTINCT FROM v_fluxo_entrega THEN
        RAISE EXCEPTION 'Falhou (RN04): regravar o mesmo status da entrega deve preservar o histórico';
    END IF;

    -- Cada tentativa atinge um evento inicial cuja existência foi verificada acima.
    -- A migração 08 usa 23514: não o capture, pois a 09 deve alinhar o código a 23001.
    FOREACH v_operacao IN ARRAY ARRAY[
        'UPDATE historico_pedido', 'DELETE historico_pedido',
        'UPDATE historico_entrega', 'DELETE historico_entrega'
    ] LOOP
        BEGIN
            CASE v_operacao
                WHEN 'UPDATE historico_pedido' THEN
                    UPDATE historico_pedido SET data_hora = data_hora + INTERVAL '1 second'
                     WHERE id_pedido = v_id_pedido AND status = 'solicitado';
                WHEN 'DELETE historico_pedido' THEN
                    DELETE FROM historico_pedido WHERE id_pedido = v_id_pedido AND status = 'solicitado';
                WHEN 'UPDATE historico_entrega' THEN
                    UPDATE historico_entrega SET data_hora = data_hora + INTERVAL '1 second'
                     WHERE id_entrega = v_id_entrega AND status = 'aguardando_entregador';
                WHEN 'DELETE historico_entrega' THEN
                    DELETE FROM historico_entrega WHERE id_entrega = v_id_entrega AND status = 'aguardando_entregador';
            END CASE;
            RAISE EXCEPTION 'Falhou (RN08/RR11): % não foi recusado com SQLSTATE 23001', v_operacao;
        EXCEPTION
            WHEN restrict_violation THEN  -- SQLSTATE 23001
                GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
                IF v_constraint IS DISTINCT FROM 'ck_historico_imutavel'
                   AND SQLERRM NOT LIKE '%RN08/RR11%' THEN
                    RAISE EXCEPTION 'Falhou (RN08/RR11): % retornou 23001 sem identificar a regra (constraint: %, mensagem: %)',
                        v_operacao, v_constraint, SQLERRM;
                END IF;
        END;
    END LOOP;

    RAISE NOTICE 'PASSOU: verificação dos gatilhos de rastreio (RN04, RN08, RR11)';
END;
$$;

ROLLBACK;
