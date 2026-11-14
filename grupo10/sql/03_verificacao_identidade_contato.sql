-- =============================================================================
-- 03_verificacao_identidade_contato.sql — Subdomínio Identidade e Contato (E4)
-- Pré-requisito: 01_esquema_identidade_contato.sql e 02_carga_identidade_contato.sql.
--
-- Cada teste traz: regra (Seção 2), resultado esperado e mensagem literal do SGBD.
-- Os testes de violação rodam dentro de blocos com tratamento de exceção, então o
-- script não para com ON_ERROR_STOP=1. Um teste só "PASSA" se o SGBD recusar a
-- operação com o SQLSTATE e a constraint esperados; se a operação for aceita ou
-- falhar por outro motivo, o script aborta com "FALHOU".
-- Tudo roda numa transação desfeita no fim (ROLLBACK): a carga não é alterada.
--
-- SQLSTATE usados:
--   23514 check_violation        23505 unique_violation
--   23503 foreign_key_violation  23001 restrict_violation (ON DELETE RESTRICT, PG 18)
--   23502 not_null_violation     22P02 invalid_text_representation (ENUM)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Parte 1 — Casos válidos: as regras não bloqueiam operações corretas
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    -- Regra: RN10/RR14 — pessoa com nome, CPF de 11 dígitos e e-mail válidos
    -- Esperado: SUCESSO
    INSERT INTO pessoa (nome, cpf, email)
    VALUES ('Pessoa Válida', '12345678909', 'valida@exemplo.com');

    -- Regra: RR14 — telefone fixo só com dígitos (DDD + 8)
    -- Esperado: SUCESSO
    INSERT INTO telefone (id_pessoa, numero, tipo)
    VALUES (2, '3233334444', 'fixo');

    -- Regra: ADR-002 — cliente troca o endereço atual por outro endereço DELE
    -- (cliente 111 usava o trabalho; passa a usar a casa, endereço 111)
    -- Esperado: SUCESSO
    UPDATE cliente SET id_endereco_atual = 111 WHERE id_pessoa = 111;
    IF NOT EXISTS (SELECT 1 FROM cliente
                   WHERE id_pessoa = 111 AND id_endereco_atual = 111) THEN
        RAISE EXCEPTION 'FALHOU: troca válida de endereço atual do cliente 111';
    END IF;

    -- Regra: ADR-002 (MATCH SIMPLE) — endereço atual é opcional (NULL)
    -- Esperado: SUCESSO
    UPDATE cliente SET id_endereco_atual = NULL WHERE id_pessoa = 112;

    -- Regra: ADR-003 (sobreposição) — uma pessoa pode acumular papéis
    -- (pessoa 71, já lojista, passa a ser também entregadora)
    -- Esperado: SUCESSO
    INSERT INTO entregador (id_pessoa, tipo_veiculo) VALUES (71, 'bicicleta');

    RAISE NOTICE 'PASSOU: casos válidos (pessoa, telefone, troca e remoção de endereço atual, papel sobreposto)';
END;
$$;

-- -----------------------------------------------------------------------------
-- Parte 2 — Violações: cada operação deve ser RECUSADA pelo SGBD
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_teste     RECORD;
    v_sqlstate  TEXT;
    v_restricao TEXT;
    v_falhou    BOOLEAN;
BEGIN
    FOR v_teste IN
        SELECT * FROM (VALUES

            -- ===================== PESSOA =====================

            -- Regra: RN10/RR14 — CPF deve ter exatamente 11 dígitos numéricos
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
            (
                'CPF com letra',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES ('Teste', '0000000000A', 'teste@exemplo.com')$q$,
                '23514', 'ck_pessoa_cpf'
            ),

            -- Regra: RN10/RR14 — CPF deve ter exatamente 11 dígitos numéricos
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
            (
                'CPF com 10 dígitos',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES ('Teste', '1234567890', 'teste@exemplo.com')$q$,
                '23514', 'ck_pessoa_cpf'
            ),

            -- Regra: RN10 — CPF é único
            -- Esperado: ERRO (violação de UNIQUE)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "uq_pessoa_cpf"
            (
                'CPF repetido (INSERT)',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES ('Teste', '00000000001', 'teste@exemplo.com')$q$,
                '23505', 'uq_pessoa_cpf'
            ),

            -- Regra: RN10 — CPF é único, também na alteração
            -- Esperado: ERRO (violação de UNIQUE)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "uq_pessoa_cpf"
            (
                'CPF repetido (UPDATE)',
                $q$UPDATE pessoa SET cpf = '00000000002' WHERE id_pessoa = 1$q$,
                '23505', 'uq_pessoa_cpf'
            ),

            -- Regra: e-mail é único
            -- Esperado: ERRO (violação de UNIQUE)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "uq_pessoa_email"
            (
                'E-mail repetido',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES ('Teste', '99999999999', 'pessoa1@exemplo.com')$q$,
                '23505', 'uq_pessoa_email'
            ),

            -- Regra: e-mail no formato básico algo@dominio.ext
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_email"
            (
                'E-mail sem @',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES ('Teste', '99999999999', 'teste.exemplo.com')$q$,
                '23514', 'ck_pessoa_email'
            ),

            -- Regra: nome obrigatório e não vazio
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_nome"
            (
                'Nome só com espaços',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES ('   ', '99999999999', 'teste@exemplo.com')$q$,
                '23514', 'ck_pessoa_nome'
            ),

            -- Regra: nome obrigatório
            -- Esperado: ERRO (violação de NOT NULL)
            -- Mensagem do SGBD: ERROR:  null value in column "nome" of relation "pessoa" violates not-null constraint
            (
                'Nome nulo',
                $q$INSERT INTO pessoa (nome, cpf, email) VALUES (NULL, '99999999999', 'teste@exemplo.com')$q$,
                '23502', NULL
            ),

            -- ===================== ENDERECO =====================

            -- Regra: RR14 — CEP com exatamente 8 dígitos numéricos
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_cep"
            (
                'CEP com hífen e 7 dígitos',
                $q$INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado) VALUES ('Rua Teste', '1', 'Centro', '36000-00', 'Juiz de Fora', 'MG')$q$,
                '23514', 'ck_endereco_cep'
            ),

            -- Regra: RR14 — UF com 2 letras maiúsculas
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_estado"
            (
                'UF em minúsculas',
                $q$INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado) VALUES ('Rua Teste', '1', 'Centro', '36000000', 'Juiz de Fora', 'mg')$q$,
                '23514', 'ck_endereco_estado'
            ),

            -- Regra: logradouro obrigatório e não vazio
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_logradouro"
            (
                'Logradouro vazio',
                $q$INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado) VALUES ('  ', '1', 'Centro', '36000000', 'Juiz de Fora', 'MG')$q$,
                '23514', 'ck_endereco_logradouro'
            ),

            -- Regra: ADR-002 — o mesmo imóvel (logradouro, número, CEP) é cadastrado uma única vez
            -- Esperado: ERRO (violação de UNIQUE composta)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "uq_endereco_logradouro_numero_cep"
            (
                'Endereço duplicado',
                $q$INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado) VALUES ('Avenida Barão do Rio Branco', '11', 'Centro', '36000037', 'Juiz de Fora', 'MG')$q$,
                '23505', 'uq_endereco_logradouro_numero_cep'
            ),

            -- ===================== TELEFONE =====================

            -- Regra: o mesmo número não se repete para a mesma pessoa
            -- Esperado: ERRO (violação de PK composta)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "pk_telefone"
            (
                'Telefone duplicado para a mesma pessoa',
                $q$INSERT INTO telefone (id_pessoa, numero, tipo) VALUES (1, '32990000001', 'celular')$q$,
                '23505', 'pk_telefone'
            ),

            -- Regra: telefone só com dígitos (DDD + 8 ou 9 dígitos), sem máscara
            -- Esperado: ERRO (violação de CHECK)
            -- Mensagem do SGBD: ERROR:  new row for relation "telefone" violates check constraint "ck_telefone_numero"
            (
                'Telefone com máscara',
                $q$INSERT INTO telefone (id_pessoa, numero, tipo) VALUES (1, '(32) 99999-0000', 'celular')$q$,
                '23514', 'ck_telefone_numero'
            ),

            -- Regra: telefone pertence a uma pessoa existente (entidade fraca)
            -- Esperado: ERRO (violação de FK)
            -- Mensagem do SGBD: ERROR:  insert or update on table "telefone" violates foreign key constraint "fk_telefone_pessoa"
            (
                'Telefone de pessoa inexistente',
                $q$INSERT INTO telefone (id_pessoa, numero, tipo) VALUES (999999, '32999999999', 'celular')$q$,
                '23503', 'fk_telefone_pessoa'
            ),

            -- Regra: tipo de telefone restrito ao domínio tipo_telefone
            -- Esperado: ERRO (valor fora do ENUM)
            -- Mensagem do SGBD: ERROR:  invalid input value for enum tipo_telefone: "whatsapp"
            (
                'Tipo de telefone fora do ENUM',
                $q$INSERT INTO telefone (id_pessoa, numero, tipo) VALUES (1, '32999999999', 'whatsapp')$q$,
                '22P02', NULL
            ),

            -- ===================== PESSOA_ENDERECO =====================

            -- Regra: o vínculo pessoa–endereço não se repete
            -- Esperado: ERRO (violação de PK composta)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "pk_pessoa_endereco"
            (
                'Vínculo pessoa-endereço duplicado',
                $q$INSERT INTO pessoa_endereco (id_pessoa, id_endereco) VALUES (1, 1)$q$,
                '23505', 'pk_pessoa_endereco'
            ),

            -- Regra: vínculo só com endereço existente
            -- Esperado: ERRO (violação de FK)
            -- Mensagem do SGBD: ERROR:  insert or update on table "pessoa_endereco" violates foreign key constraint "fk_pessoa_endereco_endereco"
            (
                'Vínculo com endereço inexistente',
                $q$INSERT INTO pessoa_endereco (id_pessoa, id_endereco) VALUES (1, 999999)$q$,
                '23503', 'fk_pessoa_endereco_endereco'
            ),

            -- ===================== PAPÉIS =====================

            -- Regra: ADR-003 — cada pessoa tem no máximo um registro por papel
            -- Esperado: ERRO (violação de PK)
            -- Mensagem do SGBD: ERROR:  duplicate key value violates unique constraint "pk_entregador"
            (
                'Entregador duplicado',
                $q$INSERT INTO entregador (id_pessoa, tipo_veiculo) VALUES (1, 'moto')$q$,
                '23505', 'pk_entregador'
            ),

            -- Regra: tipo de veículo restrito ao domínio tipo_veiculo
            -- Esperado: ERRO (valor fora do ENUM)
            -- Mensagem do SGBD: ERROR:  invalid input value for enum tipo_veiculo: "patinete"
            (
                'Tipo de veículo fora do ENUM',
                $q$INSERT INTO entregador (id_pessoa, tipo_veiculo) VALUES (72, 'patinete')$q$,
                '22P02', NULL
            ),

            -- Regra: tipo de veículo obrigatório
            -- Esperado: ERRO (violação de NOT NULL)
            -- Mensagem do SGBD: ERROR:  null value in column "tipo_veiculo" of relation "entregador" violates not-null constraint
            (
                'Tipo de veículo nulo',
                $q$INSERT INTO entregador (id_pessoa, tipo_veiculo) VALUES (72, NULL)$q$,
                '23502', NULL
            ),

            -- Regra: ADR-003 — papel só para pessoa existente
            -- Esperado: ERRO (violação de FK)
            -- Mensagem do SGBD: ERROR:  insert or update on table "lojista" violates foreign key constraint "fk_lojista_pessoa"
            (
                'Lojista sem pessoa',
                $q$INSERT INTO lojista (id_pessoa) VALUES (999999)$q$,
                '23503', 'fk_lojista_pessoa'
            ),

            -- Regra: ADR-003 — papel só para pessoa existente
            -- Esperado: ERRO (violação de FK)
            -- Mensagem do SGBD: ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_pessoa"
            (
                'Cliente sem pessoa',
                $q$INSERT INTO cliente (id_pessoa) VALUES (999999)$q$,
                '23503', 'fk_cliente_pessoa'
            ),

            -- ===================== CLIENTE: ENDEREÇO ATUAL (ADR-002) =====================

            -- Regra: ADR-002 — o endereço atual do cliente deve ser um endereço DELE
            -- (o endereço 2 existe, mas pertence à pessoa 2, não ao cliente 101)
            -- Esperado: ERRO (violação de FK composta)
            -- Mensagem do SGBD: ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_endereco_atual"
            --                   DETAIL:  Key (id_pessoa, id_endereco_atual)=(101, 2) is not present in table "pessoa_endereco".
            (
                'Endereço atual de outra pessoa (UPDATE)',
                $q$UPDATE cliente SET id_endereco_atual = 2 WHERE id_pessoa = 101$q$,
                '23503', 'fk_cliente_endereco_atual'
            ),

            -- Regra: ADR-002 — idem, no cadastro de um novo cliente
            -- (pessoa 1 é só entregadora; o endereço 2 é da pessoa 2)
            -- Esperado: ERRO (violação de FK composta)
            -- Mensagem do SGBD: ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_endereco_atual"
            (
                'Endereço atual de outra pessoa (INSERT)',
                $q$INSERT INTO cliente (id_pessoa, id_endereco_atual) VALUES (1, 2)$q$,
                '23503', 'fk_cliente_endereco_atual'
            ),

            -- ===================== AÇÕES REFERENCIAIS (DELETE) =====================

            -- Regra: ADR-002 — endereço em uso não pode ser apagado (ON DELETE RESTRICT)
            -- Esperado: ERRO (violação de RESTRICT). O PostgreSQL 18 devolve 23001
            -- (restrict_violation); versões até a 17 devolvem 23503. O teste aceita os dois.
            -- Mensagem do SGBD (PG 16): ERROR:  update or delete on table "endereco" violates foreign key constraint "fk_pessoa_endereco_endereco" on table "pessoa_endereco"
            (
                'Exclusão de endereço em uso',
                $q$DELETE FROM endereco WHERE id_endereco = 1$q$,
                '23001|23503', 'fk_pessoa_endereco_endereco'
            ),

            -- Regra: ADR-002 — o vínculo que é o endereço atual do cliente não pode ser
            -- apagado antes de o cliente trocar de endereço (ON DELETE NO ACTION)
            -- Esperado: ERRO (violação de FK composta)
            -- Mensagem do SGBD: ERROR:  update or delete on table "pessoa_endereco" violates foreign key constraint "fk_cliente_endereco_atual" on table "cliente"
            (
                'Exclusão do endereço atual do cliente',
                $q$DELETE FROM pessoa_endereco WHERE id_pessoa = 101 AND id_endereco = 101$q$,
                '23503', 'fk_cliente_endereco_atual'
            )

        ) AS testes(descricao, comando, sqlstate_esperado, restricao_esperada)
    LOOP
        v_falhou := FALSE;
        BEGIN
            EXECUTE v_teste.comando;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate  = RETURNED_SQLSTATE,
                v_restricao = CONSTRAINT_NAME;
            -- sqlstate_esperado pode listar alternativas separadas por '|'
            IF v_sqlstate IS NULL
               OR NOT (v_sqlstate = ANY (string_to_array(v_teste.sqlstate_esperado, '|')))
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

        RAISE NOTICE 'PASSOU: % (SQLSTATE %)', v_teste.descricao, v_sqlstate;
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- Parte 3 — ON DELETE CASCADE: apagar a pessoa apaga seus dependentes
-- -----------------------------------------------------------------------------
-- Regra: telefone é entidade fraca; papéis e vínculos de endereço não existem sem a pessoa
-- Pessoa 41: entregadora + cliente, com celular e casa (endereço 41)
-- Esperado: SUCESSO; telefone, entregador, cliente e pessoa_endereco da pessoa 41
--           somem; o endereço 41 continua existindo (endereço é imutável e compartilhável)
DO $$
BEGIN
    DELETE FROM pessoa WHERE id_pessoa = 41;

    IF EXISTS (SELECT 1 FROM telefone        WHERE id_pessoa = 41)
       OR EXISTS (SELECT 1 FROM entregador   WHERE id_pessoa = 41)
       OR EXISTS (SELECT 1 FROM cliente      WHERE id_pessoa = 41)
       OR EXISTS (SELECT 1 FROM pessoa_endereco WHERE id_pessoa = 41) THEN
        RAISE EXCEPTION 'FALHOU: o CASCADE não removeu os dependentes da pessoa 41';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM endereco WHERE id_endereco = 41) THEN
        RAISE EXCEPTION 'FALHOU: o endereço 41 foi apagado junto com a pessoa';
    END IF;

    RAISE NOTICE 'PASSOU: exclusão de pessoa propaga para telefone, papéis e vínculos (CASCADE)';
END;
$$;

-- Desfaz todas as alterações feitas pelos testes
ROLLBACK;
