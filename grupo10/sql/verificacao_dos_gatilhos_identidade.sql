-- =================================================================================
-- VERIFICAÇÃO DOS GATILHOS - SUBDOMÍNIO: IDENTIDADE E CONTATO (E6)
-- Arquivo: verificacao_dos_gatilhos_identidade.sql
-- Pré-requisito: 01_esquema.sql, 02_carga.sql e 06_triggers_identidade.sql.
-- Executar SEM ON_ERROR_STOP: os casos barrados geram erro de propósito.
-- Ao final, a carga volta ao estado original (o caso que altera dados é desfeito).
-- =================================================================================


-- ---------------------------------------------------------------------------------
-- RR12: Logradouro, número e CEP de um endereço não podem ser alterados.
-- Resultado esperado: BARRADO pelo gatilho trg_endereco_localizacao_imutavel
--                     (alteração do número do endereço 1).
-- ---------------------------------------------------------------------------------
UPDATE endereco
SET numero = '999'
WHERE id_endereco = 1;

-- ERRO DO BANCO:
-- ERROR:  RR12: logradouro, número e CEP do endereço 1 não podem ser alterados
-- HINT:  Cadastre um novo endereço e vincule-o à pessoa em pessoa_endereco.
-- CONTEXT:  PL/pgSQL function identidade_bloquear_alteracao_endereco() line 7 at RAISE


-- ---------------------------------------------------------------------------------
-- RR12: Logradouro, número e CEP de um endereço não podem ser alterados.
-- Resultado esperado: BARRADO pelo gatilho trg_endereco_localizacao_imutavel
--                     (alteração do CEP de todos os endereços do bairro Centro).
-- ---------------------------------------------------------------------------------
UPDATE endereco
SET cep = '36000000'
WHERE bairro = 'Centro';

-- ERRO DO BANCO:
-- ERROR:  RR12: logradouro, número e CEP do endereço 10 não podem ser alterados
-- HINT:  Cadastre um novo endereço e vincule-o à pessoa em pessoa_endereco.
-- CONTEXT:  PL/pgSQL function identidade_bloquear_alteracao_endereco() line 7 at RAISE
-- (o gatilho barra a primeira linha alterada, o endereço 10; o comando inteiro
--  é desfeito e nenhum endereço do bairro Centro tem o CEP alterado)


-- ---------------------------------------------------------------------------------
-- RR12 (caso permitido): o UPDATE cita uma coluna protegida, mas regrava o
-- mesmo valor. Não há alteração real da localização.
-- Resultado esperado: PERMITIDO (UPDATE 1).
-- ---------------------------------------------------------------------------------
UPDATE endereco
SET numero = numero
WHERE id_endereco = 1;

-- RESULTADO DO BANCO:
-- UPDATE 1


-- ---------------------------------------------------------------------------------
-- RR12 (caso permitido): o bairro não faz parte dos dados protegidos pela RR12.
-- Resultado esperado: PERMITIDO (UPDATE 1). O segundo comando devolve o bairro
-- original, para não alterar a carga.
-- ---------------------------------------------------------------------------------
UPDATE endereco
SET bairro = 'Bairro Corrigido'
WHERE id_endereco = 1;

UPDATE endereco
SET bairro = 'São Mateus'
WHERE id_endereco = 1;

-- RESULTADO DO BANCO:
-- UPDATE 1
-- UPDATE 1
