-- =================================================================================
-- SCRIPT DE VERIFICAÇÃO DE INTEGRIDADE - SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- Arquivo: 03_verificacao_comercio_financas.sql
-- Objetivo: Comandos de INSERT, UPDATE e DELETE que demonstram o funcionamento
--           dos controles de integridade criados no DDL.
-- =================================================================================


-- ---------------------------------------------------------------------------------
-- RR10: Coerência aritmética dos totais do Pedido (valor_total = subtotal + taxa_entrega + taxa_servico)
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pedido_valor_total.
-- ---------------------------------------------------------------------------------
INSERT INTO pedido (id_loja, id_cliente, id_endereco, forma_pagamento,
                    subtotal, taxa_entrega, taxa_servico, valor_total)
VALUES (1, 1, 1, 'pix', 80.00, 7.00, 5.00, 100.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pedido" violates check constraint "ck_pedido_valor_total"
-- DETAIL:  Failing row contains (200001, 1, 1, 1, null, null, null, solicitado, 2026-11-14 03:34:36.041321+00, pix, 80.00, 7.00, 5.00, 100.00).


-- ---------------------------------------------------------------------------------
-- RR10 / RN09: Subtotal negativo em Pedido (UPDATE inválido)
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a check constraint
--                     ck_pedido_subtotal.
-- ---------------------------------------------------------------------------------
UPDATE pedido
SET subtotal = -10.00
WHERE id_pedido = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pedido" violates check constraint "ck_pedido_subtotal"
-- DETAIL:  Failing row contains (1, 1, 3, 3, Apto 300, Próximo à praça 3, null, pronto, 2026-02-25 05:42:02.22318+00, cartao_debito, -10.00, 7.00, 2.50, 50.00).


-- ---------------------------------------------------------------------------------
-- RN05: A soma da parcela da loja, da comissão do entregador e da taxa da plataforma
--       deve ser igual ao valor total pago pelo pedido.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_divisao_pagamento_soma.
-- ---------------------------------------------------------------------------------
INSERT INTO divisao_pagamento (id_pedido, valor_total, parcela_loja,
                               comissao_entregador, taxa_plataforma)
VALUES (1, 100.00, 80.00, 10.00, 5.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "divisao_pagamento" violates check constraint "ck_divisao_pagamento_soma"
-- DETAIL:  Failing row contains (1, 100.00, 5.00, 80.00, 10.00, 2026-11-14 03:34:36.042968+00).


-- ---------------------------------------------------------------------------------
-- RN07: Um pedido não pode misturar Produtos de lojas diferentes.
--       Todos os itens do pedido devem pertencer ao catálogo da mesma Loja.
-- Cenário A: Pedido 1 é da Loja 1 e Produto 21 é da Loja 2 (informando id_loja = 2).
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a FK composta
--                     fk_item_pedido_loja.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (1, 21, 2, 1, 25.00);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "item_pedido" violates foreign key constraint "fk_item_pedido_loja"
-- DETAIL:  Key (id_loja, id_pedido)=(2, 1) is not present in table "pedido".


-- ---------------------------------------------------------------------------------
-- RN07: Um pedido não pode misturar Produtos de lojas diferentes (Cenário B).
-- Cenário B: Pedido 1 é da Loja 1 e Produto 21 é da Loja 2 (tentando forçar id_loja = 1).
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a FK composta
--                     fk_item_produto_loja.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (1, 21, 1, 1, 25.00);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "item_pedido" violates foreign key constraint "fk_item_produto_loja"
-- DETAIL:  Key (id_loja, id_produto)=(1, 21) is not present in table "produto".


-- ---------------------------------------------------------------------------------
-- RN06: A nota dada na Avaliação (para a Loja ou para o Entregador) deve ser
--       obrigatoriamente um número inteiro de 1 a 5.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_avaliacao_loja_nota.
-- ---------------------------------------------------------------------------------
INSERT INTO avaliacao_loja (id_pedido, nota, comentario)
VALUES (1, -5, 'muito bom o lanche');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "avaliacao_loja" violates check constraint "ck_avaliacao_loja_nota"
-- DETAIL:  Failing row contains (1, -5, muito bom o lanche, 2026-11-14 03:34:36.04507+00).


-- ---------------------------------------------------------------------------------
-- RN06: Nota fora do intervalo 1 a 5 na Avaliação do Entregador (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a check constraint
--                     ck_avaliacao_entregador_nota.
-- ---------------------------------------------------------------------------------
UPDATE avaliacao_entregador
SET nota = 6
WHERE id_pedido = 174864;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "avaliacao_entregador" violates check constraint "ck_avaliacao_entregador_nota"
-- DETAIL:  Failing row contains (174864, 6, Derramou meu refrigerante., 2026-10-31 07:51:58.253167+00).


-- ---------------------------------------------------------------------------------
-- RN09: A quantidade comprada no Item do Pedido deve ser estritamente maior que zero.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_item_pedido_quantidade.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (1, 1, 1, 0, 33.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "item_pedido" violates check constraint "ck_item_pedido_quantidade"
-- DETAIL:  Failing row contains (1, 1, 1, 0, 33.00).


-- ---------------------------------------------------------------------------------
-- RN09: O valor unitário no Item do Pedido deve ser estritamente maior que zero.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_item_pedido_valor_unitario.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (1, 1, 1, 2, -33.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "item_pedido" violates check constraint "ck_item_pedido_valor_unitario"
-- DETAIL:  Failing row contains (1, 1, 1, 2, -33.00).


-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): Não permitir excluir um Pedido que já possui
-- itens ou divisão de pagamento vinculados.
-- Resultado esperado: O banco deve rejeitar a exclusão por violação de chave estrangeira
--                     (fk_item_pedido_loja / fk_divisao_pagamento_pedido).
-- ---------------------------------------------------------------------------------
DELETE FROM pedido
WHERE id_pedido = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "pedido" violates foreign key constraint "fk_item_pedido_loja" on table "item_pedido"
-- DETAIL:  Key (id_loja, id_pedido)=(1, 1) is still referenced from table "item_pedido".
