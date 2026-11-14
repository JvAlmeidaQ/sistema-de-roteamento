-- =================================================================================
-- SCRIPT DE VERIFICAÇÃO DE INTEGRIDADE - SUBDOMÍNIO: IDENTIDADE E CONTATO
-- Arquivo: 03_verificacao_identidade_contato.sql
-- Objetivo: Comandos de INSERT, UPDATE e DELETE que demonstram o funcionamento
--           dos controles de integridade criados no DDL
--           (01_esquema_identidade_contato.sql), a partir da carga
--           (02_carga_identidade_contato.sql).
-- =================================================================================



-- ---------------------------------------------------------------------------------
-- RN10 / RR14: O CPF deve conter exatamente 11 dígitos numéricos.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pessoa_cpf (CPF com letra).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '0000000000A', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
-- DETAIL:  Failing row contains (301, Teste, 0000000000A, teste@exemplo.com).


-- ---------------------------------------------------------------------------------
-- RN10 / RR14: O CPF deve conter exatamente 11 dígitos numéricos.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pessoa_cpf (CPF com apenas 10 dígitos).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '1234567890', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
-- DETAIL:  Failing row contains (302, Teste, 1234567890 , teste@exemplo.com).


-- ---------------------------------------------------------------------------------
-- RN10: O CPF é único — duas pessoas não podem ter o mesmo CPF.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a unique constraint
--                     uq_pessoa_cpf (CPF da pessoa 1).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '00000000001', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_pessoa_cpf"
-- DETAIL:  Key (cpf)=(00000000001) already exists.


-- ---------------------------------------------------------------------------------
-- RN10: O CPF é único (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a unique constraint
--                     uq_pessoa_cpf (pessoa 1 recebendo o CPF da pessoa 2).
-- ---------------------------------------------------------------------------------
UPDATE pessoa
SET cpf = '00000000002'
WHERE id_pessoa = 1;

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_pessoa_cpf"
-- DETAIL:  Key (cpf)=(00000000002) already exists.


-- ---------------------------------------------------------------------------------
-- Unicidade do e-mail: duas pessoas não podem ter o mesmo e-mail.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a unique constraint
--                     uq_pessoa_email (e-mail da pessoa 1).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '99999999999', 'pessoa1@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_pessoa_email"
-- DETAIL:  Key (email)=(pessoa1@exemplo.com) already exists.


-- ---------------------------------------------------------------------------------
-- Formato do e-mail: deve seguir o padrão básico algo@dominio.ext.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pessoa_email (e-mail sem @).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '99999999999', 'teste.exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_email"
-- DETAIL:  Failing row contains (305, Teste, 99999999999, teste.exemplo.com).


-- ---------------------------------------------------------------------------------
-- Nome obrigatório e não vazio: o NOT NULL não barra texto só com espaços.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pessoa_nome.
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('   ', '99999999999', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_nome"
-- DETAIL:  Failing row contains (306,    , 99999999999, teste@exemplo.com).


-- ---------------------------------------------------------------------------------
-- Nome obrigatório (NOT NULL).
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a restrição NOT NULL
--                     da coluna nome.
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES (NULL, '99999999999', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  null value in column "nome" of relation "pessoa" violates not-null constraint
-- DETAIL:  Failing row contains (307, null, 99999999999, teste@exemplo.com).


-- ---------------------------------------------------------------------------------
-- RR14: O CEP deve conter exatamente 8 dígitos numéricos.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_endereco_cep (CEP com hífen).
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('Rua Teste', '1', 'Centro', '36000-00', 'Juiz de Fora', 'MG');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_cep"
-- DETAIL:  Failing row contains (331, Rua Teste, 1, Centro, 36000-00, Juiz de Fora, MG).


-- ---------------------------------------------------------------------------------
-- RR14: A sigla do estado (UF) deve ter 2 letras maiúsculas.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_endereco_estado (UF em minúsculas).
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('Rua Teste', '1', 'Centro', '36000000', 'Juiz de Fora', 'mg');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_estado"
-- DETAIL:  Failing row contains (332, Rua Teste, 1, Centro, 36000000, Juiz de Fora, mg).


-- ---------------------------------------------------------------------------------
-- Logradouro obrigatório e não vazio.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_endereco_logradouro.
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('  ', '1', 'Centro', '36000000', 'Juiz de Fora', 'MG');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_logradouro"
-- DETAIL:  Failing row contains (333,   , 1, Centro, 36000000, Juiz de Fora, MG).


-- ---------------------------------------------------------------------------------
-- ADR-002: O mesmo imóvel (logradouro, número, CEP) é cadastrado uma única vez
--       e compartilhado entre os moradores.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a unique constraint
--                     uq_endereco_logradouro_numero_cep (repete o endereço 1).
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('Avenida Barão do Rio Branco', '11', 'Centro', '36000037', 'Juiz de Fora', 'MG');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_endereco_logradouro_numero_cep"
-- DETAIL:  Key (logradouro, numero, cep)=(Avenida Barão do Rio Branco, 11, 36000037) already exists.


-- ---------------------------------------------------------------------------------
-- Telefone: o mesmo número não pode ser cadastrado duas vezes para a mesma pessoa.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave primária
--                     pk_telefone (celular já cadastrado da pessoa 1).
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
VALUES (1, '32990000001', 'celular');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_telefone"
-- DETAIL:  Key (id_pessoa, numero)=(1, 32990000001) already exists.


-- ---------------------------------------------------------------------------------
-- Telefone: apenas dígitos (DDD + 8 ou 9 dígitos), sem máscara.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_telefone_numero.
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
VALUES (1, '(32) 99999-0000', 'celular');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "telefone" violates check constraint "ck_telefone_numero"
-- DETAIL:  Failing row contains (1, (32) 99999-0000, celular).


-- ---------------------------------------------------------------------------------
-- Telefone é entidade fraca: só existe vinculado a uma pessoa existente.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_telefone_pessoa (pessoa 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
VALUES (999999, '32999999999', 'celular');

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "telefone" violates foreign key constraint "fk_telefone_pessoa"
-- DETAIL:  Key (id_pessoa)=(999999) is not present in table "pessoa".


-- ---------------------------------------------------------------------------------
-- Domínio tipo_telefone: aceita apenas 'celular', 'fixo' ou 'comercial'.
-- Resultado esperado: O banco deve rejeitar a inserção, pois o valor não pertence ao ENUM
--                     tipo_telefone.
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
VALUES (1, '32999999999', 'whatsapp');

-- ERRO DO BANCO:
-- ERROR:  invalid input value for enum tipo_telefone: "whatsapp"


-- ---------------------------------------------------------------------------------
-- Pessoa_Endereco: o mesmo vínculo pessoa–endereço não pode se repetir.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave primária
--                     pk_pessoa_endereco.
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa_endereco (id_pessoa, id_endereco)
VALUES (1, 1);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_pessoa_endereco"
-- DETAIL:  Key (id_pessoa, id_endereco)=(1, 1) already exists.


-- ---------------------------------------------------------------------------------
-- Pessoa_Endereco: o vínculo só pode apontar para um endereço existente.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_pessoa_endereco_endereco (endereço 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa_endereco (id_pessoa, id_endereco)
VALUES (1, 999999);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "pessoa_endereco" violates foreign key constraint "fk_pessoa_endereco_endereco"
-- DETAIL:  Key (id_endereco)=(999999) is not present in table "endereco".


-- ---------------------------------------------------------------------------------
-- ADR-003: Uma pessoa possui no máximo um registro por papel.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave primária
--                     pk_entregador (pessoa 1 já é entregadora).
-- ---------------------------------------------------------------------------------
INSERT INTO entregador (id_pessoa, tipo_veiculo)
VALUES (1, 'moto');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_entregador"
-- DETAIL:  Key (id_pessoa)=(1) already exists.


-- ---------------------------------------------------------------------------------
-- Domínio tipo_veiculo: aceita apenas 'moto', 'bicicleta' ou 'carro'.
-- Resultado esperado: O banco deve rejeitar a inserção, pois o valor não pertence ao ENUM
--                     tipo_veiculo.
-- ---------------------------------------------------------------------------------
INSERT INTO entregador (id_pessoa, tipo_veiculo)
VALUES (72, 'patinete');

-- ERRO DO BANCO:
-- ERROR:  invalid input value for enum tipo_veiculo: "patinete"


-- ---------------------------------------------------------------------------------
-- Tipo de veículo obrigatório (NOT NULL).
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a restrição NOT NULL
--                     da coluna tipo_veiculo.
-- ---------------------------------------------------------------------------------
INSERT INTO entregador (id_pessoa, tipo_veiculo)
VALUES (72, NULL);

-- ERRO DO BANCO:
-- ERROR:  null value in column "tipo_veiculo" of relation "entregador" violates not-null constraint
-- DETAIL:  Failing row contains (72, null).


-- ---------------------------------------------------------------------------------
-- ADR-003: Um papel só pode ser atribuído a uma pessoa existente.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_lojista_pessoa (pessoa 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO lojista (id_pessoa)
VALUES (999999);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "lojista" violates foreign key constraint "fk_lojista_pessoa"
-- DETAIL:  Key (id_pessoa)=(999999) is not present in table "pessoa".


-- ---------------------------------------------------------------------------------
-- ADR-003: Um papel só pode ser atribuído a uma pessoa existente.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_cliente_pessoa (pessoa 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO cliente (id_pessoa)
VALUES (999999);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_pessoa"
-- DETAIL:  Key (id_pessoa)=(999999) is not present in table "pessoa".


-- ---------------------------------------------------------------------------------
-- ADR-002: O endereço atual do cliente deve ser um dos endereços DELE.
--       O endereço 2 existe, mas pertence à pessoa 2, e não ao cliente 101.
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a FK composta
--                     fk_cliente_endereco_atual.
-- ---------------------------------------------------------------------------------
UPDATE cliente
SET id_endereco_atual = 2
WHERE id_pessoa = 101;

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_endereco_atual"
-- DETAIL:  Key (id_pessoa, id_endereco_atual)=(101, 2) is not present in table "pessoa_endereco".


-- ---------------------------------------------------------------------------------
-- ADR-002: O endereço atual do cliente deve ser um dos endereços DELE (INSERT).
--       A pessoa 1 não é cliente nem possui o endereço 2.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a FK composta
--                     fk_cliente_endereco_atual.
-- ---------------------------------------------------------------------------------
INSERT INTO cliente (id_pessoa, id_endereco_atual)
VALUES (1, 2);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_endereco_atual"
-- DETAIL:  Key (id_pessoa, id_endereco_atual)=(1, 2) is not present in table "pessoa_endereco".


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE) — ADR-002: Um endereço em uso não pode ser
--       excluído (ON DELETE RESTRICT em fk_pessoa_endereco_endereco).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação de chave estrangeira
--                     (fk_pessoa_endereco_endereco).
-- ---------------------------------------------------------------------------------
DELETE FROM endereco
WHERE id_endereco = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "endereco" violates RESTRICT setting of foreign key constraint "fk_pessoa_endereco_endereco" on table "pessoa_endereco"
-- DETAIL:  Key (id_endereco)=(1) is referenced from table "pessoa_endereco".


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE) — ADR-002: O vínculo que é o endereço atual
--       de um cliente não pode ser excluído antes de o cliente trocar de endereço
--       (ON DELETE NO ACTION em fk_cliente_endereco_atual).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação da FK composta
--                     (fk_cliente_endereco_atual).
-- ---------------------------------------------------------------------------------
DELETE FROM pessoa_endereco
WHERE id_pessoa = 101 AND id_endereco = 101;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "pessoa_endereco" violates foreign key constraint "fk_cliente_endereco_atual" on table "cliente"
-- DETAIL:  Key (id_pessoa, id_endereco)=(101, 101) is still referenced from table "cliente".


-- ---------------------------------------------------------------------------------
-- Caso válido — RN10 / RR14: Pessoa com nome, CPF de 11 dígitos e e-mail válidos.
-- Resultado esperado: O banco deve aceitar a inserção.
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Pessoa Válida', '12345678909', 'valida@exemplo.com');

-- RESULTADO DO BANCO:
-- INSERT 0 1


-- ---------------------------------------------------------------------------------
-- Caso válido — ADR-003 (sobreposição): a mesma pessoa recebe telefone, endereço
--       e dois papéis (entregador e cliente), com o endereço atual sendo um endereço dela.
--       O endereço 1 já é usado pela pessoa 1: o imóvel é compartilhado (ADR-002).
-- Resultado esperado: O banco deve aceitar todas as inserções.
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT id_pessoa, '32988887777', 'celular' FROM pessoa WHERE cpf = '12345678909';

INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido)
SELECT id_pessoa, 1, 'Casa' FROM pessoa WHERE cpf = '12345678909';

INSERT INTO entregador (id_pessoa, tipo_veiculo)
SELECT id_pessoa, 'bicicleta' FROM pessoa WHERE cpf = '12345678909';

INSERT INTO cliente (id_pessoa, id_endereco_atual)
SELECT id_pessoa, 1 FROM pessoa WHERE cpf = '12345678909';

-- RESULTADO DO BANCO:
-- INSERT 0 1
-- INSERT 0 1
-- INSERT 0 1
-- INSERT 0 1


-- ---------------------------------------------------------------------------------
-- Caso válido — ADR-002 (MATCH SIMPLE): o endereço atual do cliente é opcional.
-- Resultado esperado: O banco deve aceitar a alteração para NULL.
-- ---------------------------------------------------------------------------------
UPDATE cliente
SET id_endereco_atual = NULL
WHERE id_pessoa = (SELECT id_pessoa FROM pessoa WHERE cpf = '12345678909');

-- RESULTADO DO BANCO:
-- UPDATE 1


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE) — ON DELETE CASCADE: ao excluir a pessoa,
--       seus telefones, papéis e vínculos de endereço são excluídos junto.
--       O endereço 1 continua existindo (é compartilhado e imutável).
-- Resultado esperado: O banco deve aceitar a exclusão e a consulta seguinte deve retornar
--                     zero dependentes e o endereço 1 ainda cadastrado.
-- ---------------------------------------------------------------------------------
DELETE FROM pessoa
WHERE cpf = '12345678909';

SELECT
    (SELECT count(*) FROM pessoa          WHERE cpf = '12345678909')      AS pessoa,
    (SELECT count(*) FROM telefone        WHERE numero = '32988887777')   AS telefone,
    (SELECT count(*) FROM entregador e
       WHERE NOT EXISTS (SELECT 1 FROM pessoa p WHERE p.id_pessoa = e.id_pessoa)) AS entregador_orfao,
    (SELECT count(*) FROM endereco        WHERE id_endereco = 1)          AS endereco_1;

-- RESULTADO DO BANCO:
-- DELETE 1
--  pessoa | telefone | entregador_orfao | endereco_1 
-- --------+----------+------------------+------------
--       0 |        0 |                0 |          1
-- (1 row)
