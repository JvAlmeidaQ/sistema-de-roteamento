-- E6, seção 7.3: executar após 06_triggers_logistica.sql.
-- Casos sequenciais com dados temporários. A carga e os registros externos
-- são preservados pelo ROLLBACK; as sequências de identidade podem avançar.
-- Pré-requisitos: ao menos um pedido com vínculos válidos, um entregador e
-- os quatro gatilhos instalados. Os comentários transcrevem SQLERRM do PostgreSQL 18.
-- Falhas das verificações levantam P0001; rejeições das regras usam 23514.
BEGIN;
-- Clona apenas vínculos e valores válidos; generate_series cria três pedidos
-- para demonstrar duas vagas permitidas e uma atribuição barrada pela RN02.
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
        RAISE EXCEPTION 'A verificação exige ao menos um pedido externo para copiar os vínculos';
    END IF;
    SELECT MIN(id_pedido) INTO v_pedido FROM pedidos_teste_logistica;
    SELECT id_pessoa INTO STRICT v_entregador FROM entregador ORDER BY id_pessoa LIMIT 1;
    INSERT INTO rota (id_entregador) VALUES (v_entregador) RETURNING id_rota INTO v_rota;

    -- RN12/RR07: pedido em preparação não pode originar entrega.
    -- Esperado: nenhuma entrega automática e rejeição da criação manual.
    -- SGBD [SQLSTATE 23514]: RN12: a entrega somente pode ser criada para pedido pronto
    IF EXISTS (SELECT 1 FROM entrega WHERE id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica)) THEN
        RAISE EXCEPTION 'Falhou: pedido em preparação gerou entrega';
    END IF;
    BEGIN
        INSERT INTO entrega (id_pedido, previsao_entrega) VALUES (v_pedido, CURRENT_TIMESTAMP);
        RAISE EXCEPTION 'Falhou: entrega de pedido em preparação foi aceita';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- RN12/RR07 e ADR-004/005: ao ficar pronto, cada pedido gera uma entrega
    -- aguardando entregador, sem rota, com previsão calculada pela estimativa da loja.
    -- Esperado: três entregas criadas com esses valores.
    UPDATE pedido SET status = 'pronto'
    WHERE id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica);
    IF (SELECT COUNT(*) FROM entrega e JOIN pedido p USING (id_pedido)
        JOIN loja l USING (id_loja)
        WHERE e.id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica)
          AND e.status = 'aguardando_entregador' AND e.id_rota IS NULL
          AND e.previsao_entrega = statement_timestamp() + make_interval(mins => l.tempo_entrega_estimado)) <> 3 THEN
        RAISE EXCEPTION 'Falhou: geração automática ou cálculo da previsão';
    END IF;

    -- RR06: não pode saltar de aguardando entregador para a caminho.
    -- Esperado: rejeição. SGBD [SQLSTATE 23514]: Transição inválida de entrega: aguardando_entregador -> a_caminho
    BEGIN
        UPDATE entrega SET status = 'a_caminho', id_rota = v_rota WHERE id_pedido = v_pedido;
        RAISE EXCEPTION 'Falhou: salto de status foi aceito';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- RN02/RR02: a primeira e a segunda entregas cabem na rota.
    -- RR06: aguardando entregador -> aceita é uma transição válida.
    -- Esperado: duas entregas vinculadas, sem erro.
    UPDATE entrega SET status = 'aceita', id_rota = v_rota
    WHERE id_pedido IN (SELECT id_pedido FROM pedidos_teste_logistica ORDER BY id_pedido LIMIT 2);
    IF (SELECT COUNT(*) FROM entrega WHERE id_rota = v_rota) <> 2 THEN
        RAISE EXCEPTION 'Falhou: primeira ou segunda entrega foi bloqueada';
    END IF;

    -- RN02/RR02: a terceira entrega ultrapassa o limite da rota.
    -- Esperado: rejeição, mantendo apenas duas entregas vinculadas.
    -- SGBD [SQLSTATE 23514]: RN02: uma rota pode possuir no máximo duas entregas
    BEGIN
        UPDATE entrega SET status = 'aceita', id_rota = v_rota
        WHERE id_pedido = (SELECT MAX(id_pedido) FROM pedidos_teste_logistica);
        RAISE EXCEPTION 'Falhou: terceira entrega foi aceita';
    EXCEPTION WHEN check_violation THEN RAISE NOTICE '%', SQLERRM;
    END;

    -- RR06 e sincronização do ADR-004: aceita -> a caminho -> entregue.
    -- Esperado: transições aceitas e pedido atualizado para concluído.
    UPDATE entrega SET status = 'a_caminho' WHERE id_pedido = v_pedido;
    UPDATE entrega SET status = 'entregue' WHERE id_pedido = v_pedido;
    IF NOT EXISTS (SELECT 1 FROM pedido WHERE id_pedido = v_pedido AND status = 'concluido') THEN
        RAISE EXCEPTION 'Falhou: entrega finalizada não concluiu o pedido';
    END IF;
    RAISE NOTICE 'PASSOU: verificação dos quatro gatilhos de Logística';
END;
$$;
ROLLBACK;
