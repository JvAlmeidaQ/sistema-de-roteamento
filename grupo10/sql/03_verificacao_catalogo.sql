BEGIN;

DO $$
DECLARE
    v_teste RECORD;
    v_sqlstate TEXT;
    v_restricao TEXT;
    v_falhou BOOLEAN;
BEGIN
    FOR v_teste IN
        SELECT * FROM (VALUES
            -- 1. INSERT
            (
                'RN10 — CNPJ deve conter exatamente 14 dígitos numéricos',
                'INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone, status_funcionamento, tempo_entrega_estimado, taxa_entrega) VALUES (1, 1, ''1234567890123X'', ''LOJA CNPJ INVALIDO'', ''(32) 3000-0001'', ''aberta'', 30, 5.00)',
                '23514', 'ck_loja_cnpj'
            ),
            (
                'Regra de integridade — CNPJ deve ser único',
                'INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone, status_funcionamento, tempo_entrega_estimado, taxa_entrega) VALUES (1, 1, ''12345678000195'', ''LOJA CNPJ DUPLICADO'', ''(32) 3000-0002'', ''aberta'', 30, 5.00)',
                '23505', 'uk_loja_cnpj'
            ),
            (
                'Regra de integridade — Loja deve referenciar um Lojista existente',
                'INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone, status_funcionamento, tempo_entrega_estimado, taxa_entrega) VALUES (-999999999, 1, ''98765432000199'', ''LOJA SEM LOJISTA'', ''(32) 3000-0003'', ''aberta'', 30, 5.00)',
                '23503', 'fk_loja_lojista'
            ),
            (
                'RN09 — Preço do Produto deve ser maior que zero',
                'INSERT INTO produto (id_loja, nome, descricao, preco, ativo) VALUES (1, ''PRODUTO PRECO ZERO'', ''Teste RN09'', 0, TRUE)',
                '23514', 'ck_produto_preco'
            ),
            (
                'Regra de integridade — Produto deve pertencer a uma Loja existente',
                'INSERT INTO produto (id_loja, nome, descricao, preco, ativo) VALUES (-999999999, ''PRODUTO SEM LOJA'', ''Teste de FK'', 10.00, TRUE)',
                '23503', 'fk_produto_loja'
            ),
            (
                'Regra de integridade — Nome da Categoria é obrigatório',
                'INSERT INTO categoria (id_loja, nome) VALUES (1, NULL)',
                '23502', NULL
            ),
            (
                'RF07/RN01 — status_funcionamento aceita somente ''aberta'' ou ''fechada''',
                'INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone, status_funcionamento, tempo_entrega_estimado, taxa_entrega) VALUES (1, 1, ''98765432000270'', ''LOJA STATUS INVALIDO'', ''(32) 3000-0004'', ''em_manutencao''::status_funcionamento, 30, 5.00)',
                '22P02', NULL
            ),
            (
                'ADR-001 — Produto e Categoria associados devem pertencer à mesma Loja',
                'INSERT INTO produto_categoria (id_loja, id_produto, id_categoria) VALUES (1, 1, 2)',
                '23503', 'fk_produto_categoria_categoria'
            ),
            (
                'Regra de integridade — A associação Produto/Categoria não pode se repetir',
                'INSERT INTO produto_categoria (id_loja, id_produto, id_categoria) VALUES (1, 1, 1)',
                '23505', 'pk_produto_categoria'
            ),

            -- 2. UPDATE
            (
                'RN09 — Preço do Produto deve continuar maior que zero',
                'UPDATE produto SET preco = -1.00 WHERE id_produto = 1',
                '23514', 'ck_produto_preco'
            ),
            (
                'Regra de integridade — Nome do Produto é obrigatório',
                'UPDATE produto SET nome = NULL WHERE id_produto = 1',
                '23502', NULL
            ),
            (
                'ADR-001 — A associação não pode apontar para loja diferente da loja à qual Produto 1 e Categoria 1 pertencem',
                'UPDATE produto_categoria SET id_loja = 2 WHERE id_produto = 1 AND id_categoria = 1',
                '23503', 'fk_produto_categoria_produto'
            ),
            (
                'Regra de integridade — Tempo estimado de entrega deve ser positivo',
                'UPDATE loja SET tempo_entrega_estimado = 0 WHERE id_loja = 1',
                '23514', 'ck_loja_tempo_entrega'
            ),
            (
                'Regra de integridade — Taxa de entrega não pode ser negativa',
                'UPDATE loja SET taxa_entrega = -0.01 WHERE id_loja = 1',
                '23514', 'ck_loja_taxa_entrega'
            ),
            (
                'Regra de integridade — Categoria deve referenciar uma Loja existente',
                'UPDATE categoria SET id_loja = -999999999 WHERE id_categoria = 1',
                '23503', 'fk_categoria_loja'
            ),

            -- 3. DELETE
            (
                'Regra de integridade — Não excluir Lojista que possui Loja (ON DELETE RESTRICT)',
                'DELETE FROM lojista WHERE id_pessoa = 1',
                '23001', 'fk_loja_lojista'
            ),
            (
                'Regra de integridade — Não excluir Endereco utilizado por Loja (ON DELETE RESTRICT)',
                'DELETE FROM endereco WHERE id_endereco = 1',
                '23001', 'fk_loja_endereco'
            )
        ) AS testes(descricao, comando, sqlstate_esperado, restricao_esperada)
    LOOP
        v_falhou := FALSE;

        BEGIN
            EXECUTE v_teste.comando;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_restricao = CONSTRAINT_NAME;

            IF v_sqlstate IS DISTINCT FROM v_teste.sqlstate_esperado
                OR (v_teste.restricao_esperada IS NOT NULL
                    AND v_restricao IS DISTINCT FROM v_teste.restricao_esperada) THEN
                RAISE EXCEPTION 'FALHOU: %. Esperado: % / %. Obtido: % / %',
                    v_teste.descricao,
                    v_teste.sqlstate_esperado, v_teste.restricao_esperada,
                    v_sqlstate, v_restricao;
            END IF;

            v_falhou := TRUE;
        END;

        IF NOT v_falhou THEN
            RAISE EXCEPTION 'FALHOU: %. A operação inválida foi aceita', v_teste.descricao;
        END IF;

        RAISE NOTICE 'PASSOU: % (SQLSTATE %)', v_teste.descricao, v_teste.sqlstate_esperado;
    END LOOP;
END;
$$;

ROLLBACK;
