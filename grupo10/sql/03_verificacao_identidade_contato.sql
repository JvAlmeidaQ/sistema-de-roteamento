-- =================================================================================
-- SCRIPT DE VERIFICAÇÃO DE INTEGRIDADE - SUBDOMÍNIO: IDENTIDADE E CONTATO
-- Arquivo: 03_verificacao_identidade_contato.sql
-- Objetivo: Comandos de INSERT, UPDATE e DELETE que demonstram o funcionamento
--           dos controles de integridade criados no DDL
--           (01_esquema_identidade_contato.sql), a partir da carga
--           (02_carga_identidade_contato.sql).
-- =================================================================================



-- ---------------------------------------------------------------------------------
-- RN10 / RR14: O CPF deve conter apenas números e ter exatamente 11 dígitos.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pessoa_cpf (CPF com letra).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '0000000000A', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
-- DETAIL:  Failing row contains (301, Teste, 0000000000A, teste@exemplo.com).


-- ---------------------------------------------------------------------------------
-- RN10 / RR14: O CPF deve conter apenas números e ter exatamente 11 dígitos.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pessoa_cpf (CPF com 10 dígitos).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '1234567890', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
-- DETAIL:  Failing row contains (302, Teste, 1234567890 , teste@exemplo.com).


-- ---------------------------------------------------------------------------------
-- RN10 / RR14: O CPF deve conter apenas números e ter exatamente 11 dígitos
--       (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a check constraint
--                     ck_pessoa_cpf (CPF com máscara).
-- ---------------------------------------------------------------------------------
UPDATE pessoa
SET cpf = '000.000.001'
WHERE id_pessoa = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf"
-- DETAIL:  Failing row contains (1, Bruno Silva, 000.000.001, pessoa1@exemplo.com).


-- ---------------------------------------------------------------------------------
-- Chave candidata de Pessoa (Seção 2.4.1): o CPF é único — duas pessoas não
--       podem ter o mesmo CPF.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a unique constraint
--                     uq_pessoa_cpf (CPF da pessoa 1).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
VALUES ('Teste', '00000000001', 'teste@exemplo.com');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_pessoa_cpf"
-- DETAIL:  Key (cpf)=(00000000001) already exists.


-- ---------------------------------------------------------------------------------
-- Chave candidata de Pessoa (Seção 2.4.1): o e-mail é único (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a unique constraint
--                     uq_pessoa_email (pessoa 2 recebendo o e-mail da pessoa 1).
-- ---------------------------------------------------------------------------------
UPDATE pessoa
SET email = 'pessoa1@exemplo.com'
WHERE id_pessoa = 2;

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_pessoa_email"
-- DETAIL:  Key (email)=(pessoa1@exemplo.com) already exists.


-- ---------------------------------------------------------------------------------
-- RR14: O CEP deve ser numérico e ter exatamente 8 dígitos.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_cep_cep (CEP com hífen).
-- ---------------------------------------------------------------------------------
INSERT INTO cep (cep, cidade, estado)
VALUES ('36000-00', 'Juiz de Fora', 'MG');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "cep" violates check constraint "ck_cep_cep"
-- DETAIL:  Failing row contains (36000-00, Juiz de Fora, MG).


-- ---------------------------------------------------------------------------------
-- RR14: A sigla do estado (UF) deve ter 2 caracteres.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_cep_estado (UF com 1 caractere).
-- ---------------------------------------------------------------------------------
INSERT INTO cep (cep, cidade, estado)
VALUES ('36099999', 'Juiz de Fora', 'M');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "cep" violates check constraint "ck_cep_estado"
-- DETAIL:  Failing row contains (36099999, Juiz de Fora, M ).


-- ---------------------------------------------------------------------------------
-- Decomposição de Endereco (Seção 2.4.3): Endereco.cep References Cep.cep.
--       Um endereço só pode usar um CEP cadastrado em Cep.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_endereco_cep (CEP 99999999 não cadastrado).
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep)
VALUES ('Rua Teste', '1', 'Centro', '99999999');

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "endereco" violates foreign key constraint "fk_endereco_cep"
-- DETAIL:  Key (cep)=(99999999) is not present in table "cep".


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.3.1): Telefone.id_pessoa References Pessoa.id_pessoa.
--       Todo telefone pertence a uma pessoa cadastrada.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_telefone_pessoa (pessoa 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
VALUES (999999, '32999999999', 'celular');

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "telefone" violates foreign key constraint "fk_telefone_pessoa"
-- DETAIL:  Key (id_pessoa)=(999999) is not present in table "pessoa".


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.3.1): a chave de Telefone é (id_pessoa, numero).
--       A mesma pessoa não pode cadastrar o mesmo número duas vezes.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave primária
--                     pk_telefone (celular já cadastrado da pessoa 1).
-- ---------------------------------------------------------------------------------
INSERT INTO telefone (id_pessoa, numero, tipo)
VALUES (1, '32990000001', 'celular');

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_telefone"
-- DETAIL:  Key (id_pessoa, numero)=(1, 32990000001) already exists.


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.3.1): Pessoa_Endereco.id_endereco References
--       Endereco.id_endereco. Só é possível vincular uma pessoa a um endereço cadastrado.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_pessoa_endereco_endereco (endereço 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa_endereco (id_pessoa, id_endereco)
VALUES (1, 999999);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "pessoa_endereco" violates foreign key constraint "fk_pessoa_endereco_endereco"
-- DETAIL:  Key (id_endereco)=(999999) is not present in table "endereco".


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.3.1): Entregador.id_pessoa References Pessoa.id_pessoa.
--       O papel de entregador só pode ser atribuído a uma pessoa cadastrada.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_entregador_pessoa (pessoa 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO entregador (id_pessoa, tipo_veiculo)
VALUES (999999, 'moto');

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "entregador" violates foreign key constraint "fk_entregador_pessoa"
-- DETAIL:  Key (id_pessoa)=(999999) is not present in table "pessoa".


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.3.1): Lojista.id_pessoa References Pessoa.id_pessoa.
--       O papel de lojista só pode ser atribuído a uma pessoa cadastrada.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_lojista_pessoa (pessoa 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO lojista (id_pessoa)
VALUES (999999);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "lojista" violates foreign key constraint "fk_lojista_pessoa"
-- DETAIL:  Key (id_pessoa)=(999999) is not present in table "pessoa".


-- ---------------------------------------------------------------------------------
-- Endereço atual do cliente (Seção 2.3.2): a chave estrangeira composta
--       (id_pessoa, id_endereco_atual) References Pessoa_Endereco garante que o
--       endereço atual seja um dos endereços cadastrados pela própria pessoa.
--       O endereço 2 existe, mas pertence à pessoa 2, e não ao cliente 101.
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a chave estrangeira
--                     composta fk_cliente_endereco_atual.
-- ---------------------------------------------------------------------------------
UPDATE cliente
SET id_endereco_atual = 2
WHERE id_pessoa = 101;

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_endereco_atual"
-- DETAIL:  Key (id_pessoa, id_endereco_atual)=(101, 2) is not present in table "pessoa_endereco".


-- ---------------------------------------------------------------------------------
-- Endereço atual do cliente (Seção 2.3.2): mesma regra, no cadastro de um novo
--       cliente. A pessoa 1 não possui o endereço 2.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     composta fk_cliente_endereco_atual.
-- ---------------------------------------------------------------------------------
INSERT INTO cliente (id_pessoa, id_endereco_atual)
VALUES (1, 2);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "cliente" violates foreign key constraint "fk_cliente_endereco_atual"
-- DETAIL:  Key (id_pessoa, id_endereco_atual)=(1, 2) is not present in table "pessoa_endereco".


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): um endereço vinculado a alguma pessoa não
--       pode ser excluído (ON DELETE RESTRICT em fk_pessoa_endereco_endereco).
--       Os endereços são imutáveis e compartilhados entre moradores (Seção 2.3.2).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação de chave estrangeira
--                     (fk_pessoa_endereco_endereco).
-- ---------------------------------------------------------------------------------
DELETE FROM endereco
WHERE id_endereco = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "endereco" violates RESTRICT setting of foreign key constraint "fk_pessoa_endereco_endereco" on table "pessoa_endereco"
-- DETAIL:  Key (id_endereco)=(1) is referenced from table "pessoa_endereco".


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): um CEP usado por algum endereço não pode
--       ser excluído (ON DELETE RESTRICT em fk_endereco_cep).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação de chave estrangeira
--                     (fk_endereco_cep).
-- ---------------------------------------------------------------------------------
DELETE FROM cep
WHERE cep = '36001037';

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "cep" violates RESTRICT setting of foreign key constraint "fk_endereco_cep" on table "endereco"
-- DETAIL:  Key (cep)=(36001037) is referenced from table "endereco".


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): o vínculo que é o endereço atual de um
--       cliente não pode ser excluído enquanto o cliente o estiver usando
--       (ON DELETE NO ACTION em fk_cliente_endereco_atual).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação da chave estrangeira
--                     composta (fk_cliente_endereco_atual).
-- ---------------------------------------------------------------------------------
DELETE FROM pessoa_endereco
WHERE id_pessoa = 101 AND id_endereco = 101;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "pessoa_endereco" violates foreign key constraint "fk_cliente_endereco_atual" on table "cliente"
-- DETAIL:  Key (id_pessoa, id_endereco)=(101, 101) is still referenced from table "cliente".
