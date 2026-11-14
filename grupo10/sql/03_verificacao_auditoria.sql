-- =================================================================================
-- SCRIPT DE VERIFICAÇÃO DE INTEGRIDADE - SUBDOMÍNIO: AUDITORIA
-- Arquivo: 03_verificacao_auditoria.sql
-- Objetivo: Comandos de INSERT, UPDATE e DELETE que demonstram o funcionamento
--           dos controles de integridade criados no DDL
--           (01_esquema_auditoria.sql) e nos gatilhos de imutabilidade
--           (06_triggers_auditoria.sql), a partir da carga
--           (02_carga_auditoria.sql).
-- =================================================================================



-- ---------------------------------------------------------------------------------
-- RN04 / ADR-004 (Seção 2.5): A chave primária de Historico_Pedido é composta por
--        (id_pedido, status). Cada estado ocorre no máximo uma vez por pedido na
--        trilha cronológica.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave primária
--                     pk_historico_pedido (status 'solicitado' já registrado).
-- ---------------------------------------------------------------------------------
INSERT INTO historico_pedido (id_pedido, status, data_hora)
VALUES (1, 'solicitado', CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_historico_pedido"
-- DETAIL:  Key (id_pedido, status)=(1, solicitado) already exists.


-- ---------------------------------------------------------------------------------
-- RN04 / ADR-004 (Seção 2.5): A chave primária de Historico_Entrega é composta por
--        (id_entrega, status). Cada estado logístico ocorre no máximo uma vez por
--        entrega na trilha cronológica.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave primária
--                     pk_historico_entrega (status 'aguardando_entregador' já existe).
-- ---------------------------------------------------------------------------------
INSERT INTO historico_entrega (id_entrega, status, data_hora)
VALUES (1, 'aguardando_entregador', CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_historico_entrega"
-- DETAIL:  Key (id_entrega, status)=(1, aguardando_entregador) already exists.


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.5): Historico_Pedido.id_pedido References
--        Pedido.id_pedido. Todo registro de auditoria comercial deve pertencer a
--        um pedido existente.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_historico_pedido_pedido (pedido 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO historico_pedido (id_pedido, status, data_hora)
VALUES (999999, 'solicitado', CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "historico_pedido" violates foreign key constraint "fk_historico_pedido_pedido"
-- DETAIL:  Key (id_pedido)=(999999) is not present in table "pedido".


-- ---------------------------------------------------------------------------------
-- Esquema relacional (Seção 2.5): Historico_Entrega.id_entrega References
--        Entrega.id_entrega. Todo registro de auditoria logística deve pertencer a
--        uma entrega existente.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a chave estrangeira
--                     fk_historico_entrega_entrega (entrega 999999 não existe).
-- ---------------------------------------------------------------------------------
INSERT INTO historico_entrega (id_entrega, status, data_hora)
VALUES (999999, 'aguardando_entregador', CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "historico_entrega" violates foreign key constraint "fk_historico_entrega_entrega"
-- DETAIL:  Key (id_entrega)=(999999) is not present in table "entrega".


-- ---------------------------------------------------------------------------------
-- Domínio temporal (Seção 2.5): O carimbo de data e hora (data_hora) de um evento
--        de auditoria comercial não pode ser anterior ao início de operação da
--        plataforma ('2020-01-01 00:00:00+00').
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     chk_historico_pedido_data_hora.
-- ---------------------------------------------------------------------------------
INSERT INTO historico_pedido (id_pedido, status, data_hora)
VALUES (1, 'concluido', '1999-12-31 23:59:59+00');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "historico_pedido" violates check constraint "chk_historico_pedido_data_hora"
-- DETAIL:  Failing row contains (1, concluido, 1999-12-31 23:59:59+00).


-- ---------------------------------------------------------------------------------
-- Domínio temporal (Seção 2.5): O carimbo de data e hora (data_hora) de um evento
--        de auditoria logística não pode ser anterior ao início de operação da
--        plataforma ('2020-01-01 00:00:00+00').
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     chk_historico_entrega_data_hora.
-- ---------------------------------------------------------------------------------
INSERT INTO historico_entrega (id_entrega, status, data_hora)
VALUES (1, 'entregue', '1999-12-31 23:59:59+00');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "historico_entrega" violates check constraint "chk_historico_entrega_data_hora"
-- DETAIL:  Failing row contains (1, entregue, 1999-12-31 23:59:59+00).


-- ---------------------------------------------------------------------------------
-- Domínio ENUM (Seção 1): O status registrado em Historico_Pedido deve pertencer
--        estritamente aos valores válidos do tipo ENUM status_pedido.
-- Resultado esperado: O banco deve rejeitar a inserção, pois 'cancelado' não faz
--                     parte do domínio status_pedido.
-- ---------------------------------------------------------------------------------
INSERT INTO historico_pedido (id_pedido, status, data_hora)
VALUES (1, 'cancelado', CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  invalid input value for enum status_pedido: "cancelado"
-- LINE 2: VALUES (1, 'cancelado', CURRENT_TIMESTAMP);


-- ---------------------------------------------------------------------------------
-- Domínio ENUM (Seção 1): O status registrado em Historico_Entrega deve pertencer
--        estritamente aos valores válidos do tipo ENUM status_entrega.
-- Resultado esperado: O banco deve rejeitar a inserção, pois 'extraviada' não faz
--                     parte do domínio status_entrega.
-- ---------------------------------------------------------------------------------
INSERT INTO historico_entrega (id_entrega, status, data_hora)
VALUES (1, 'extraviada', CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  invalid input value for enum status_entrega: "extraviada"
-- LINE 2: VALUES (1, 'extraviada', CURRENT_TIMESTAMP);


-- ---------------------------------------------------------------------------------
-- Obrigatoriedade de dados (Seção 2.5): Nenhum evento de auditoria pode ser
--        inserido sem o status atingido pelo pedido (NOT NULL).
-- Resultado esperado: O banco deve rejeitar a inserção por violação de restrição
--                     NOT NULL na coluna status de historico_pedido.
-- ---------------------------------------------------------------------------------
INSERT INTO historico_pedido (id_pedido, status, data_hora)
VALUES (1, NULL, CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  null value in column "status" of relation "historico_pedido" violates not-null constraint
-- DETAIL:  Failing row contains (1, null, 2026-11-14 20:46:00+00).


-- ---------------------------------------------------------------------------------
-- Obrigatoriedade de dados (Seção 2.5): Nenhum evento de auditoria pode ser
--        inserido sem o carimbo cronológico data_hora (NOT NULL).
-- Resultado esperado: O banco deve rejeitar a inserção por violação de restrição
--                     NOT NULL na coluna data_hora de historico_entrega.
-- ---------------------------------------------------------------------------------
INSERT INTO historico_entrega (id_entrega, status, data_hora)
VALUES (1, 'entregue', NULL);

-- ERRO DO BANCO:
-- ERROR:  null value in column "data_hora" of relation "historico_entrega" violates not-null constraint
-- DETAIL:  Failing row contains (1, entregue, null).


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): Um pedido que possui eventos na trilha de
--        auditoria não pode ser excluído, evitando perda silenciosa ou cascata
--        do histórico (ON DELETE RESTRICT em fk_historico_pedido_pedido).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação de chave
--                     estrangeira (fk_historico_pedido_pedido).
-- ---------------------------------------------------------------------------------
DELETE FROM pedido
WHERE id_pedido = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "pedido" violates RESTRICT setting of foreign key constraint "fk_historico_pedido_pedido" on table "historico_pedido"
-- DETAIL:  Key (id_pedido)=(1) is still referenced from table "historico_pedido".


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): Uma entrega que possui eventos na trilha de
--        auditoria não pode ser excluída, preservando o histórico logístico
--        (ON DELETE RESTRICT em fk_historico_entrega_entrega).
-- Resultado esperado: O banco deve rejeitar a exclusão por violação de chave
--                     estrangeira (fk_historico_entrega_entrega).
-- ---------------------------------------------------------------------------------
DELETE FROM entrega
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "entrega" violates RESTRICT setting of foreign key constraint "fk_historico_entrega_entrega" on table "historico_entrega"
-- DETAIL:  Key (id_entrega)=(1) is still referenced from table "historico_entrega".


-- ---------------------------------------------------------------------------------
-- RN08 / RR11 / ADR-004: Os registros da tabela Historico_Pedido são estritamente
--        imutáveis (append-only). Não é permitido alterar o carimbo de data/hora ou
--        o status de um evento já registrado (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração por meio do gatilho de
--                     imutabilidade (trg_historico_pedido_imutavel).
-- ---------------------------------------------------------------------------------
UPDATE historico_pedido
SET data_hora = CURRENT_TIMESTAMP
WHERE id_pedido = 1 AND status = 'solicitado';

-- ERRO DO BANCO:
-- ERROR:  [RN08][RR11] Operação UPDATE bloqueada na tabela historico_pedido: registros de auditoria são imutáveis.


-- ---------------------------------------------------------------------------------
-- RN08 / RR11 / ADR-004: Os registros da tabela Historico_Pedido são estritamente
--        imutáveis (append-only). Não é permitido excluir eventos históricos já
--        gravados (DELETE inválido).
-- Resultado esperado: O banco deve rejeitar a exclusão por meio do gatilho de
--                     imutabilidade (trg_historico_pedido_imutavel).
-- ---------------------------------------------------------------------------------
DELETE FROM historico_pedido
WHERE id_pedido = 1 AND status = 'solicitado';

-- ERRO DO BANCO:
-- ERROR:  [RN08][RR11] Operação DELETE bloqueada na tabela historico_pedido: registros de auditoria são imutáveis.


-- ---------------------------------------------------------------------------------
-- RN08 / RR11 / ADR-004: Os registros da tabela Historico_Entrega são estritamente
--        imutáveis (append-only). Não é permitido alterar o carimbo de data/hora ou
--        o status de um evento logístico já registrado (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração por meio do gatilho de
--                     imutabilidade (trg_historico_entrega_imutavel).
-- ---------------------------------------------------------------------------------
UPDATE historico_entrega
SET data_hora = CURRENT_TIMESTAMP
WHERE id_entrega = 1 AND status = 'aguardando_entregador';

-- ERRO DO BANCO:
-- ERROR:  [RN08][RR11] Operação UPDATE bloqueada na tabela historico_entrega: registros de auditoria são imutáveis.


-- ---------------------------------------------------------------------------------
-- RN08 / RR11 / ADR-004: Os registros da tabela Historico_Entrega são estritamente
--        imutáveis (append-only). Não é permitido excluir eventos logísticos já
--        gravados (DELETE inválido).
-- Resultado esperado: O banco deve rejeitar a exclusão por meio do gatilho de
--                     imutabilidade (trg_historico_entrega_imutavel).
-- ---------------------------------------------------------------------------------
DELETE FROM historico_entrega
WHERE id_entrega = 1 AND status = 'aguardando_entregador';

-- ERRO DO BANCO:
-- ERROR:  [RN08][RR11] Operação DELETE bloqueada na tabela historico_entrega: registros de auditoria são imutáveis.