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
--                     ck_endereco_cep (CEP com hífen).
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('Rua Teste', '1', 'Centro', '36000-00', 'Juiz de Fora', 'MG');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_cep"
-- DETAIL:  Failing row contains (331, Rua Teste, 1, Centro, 36000-00, Juiz de Fora, MG).


-- ---------------------------------------------------------------------------------
-- RR14: A sigla do estado (UF) deve ter 2 caracteres.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_endereco_estado (UF com 1 caractere).
-- ---------------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('Rua Teste', '1', 'Centro', '36000000', 'Juiz de Fora', 'M');

-- ERRO DO BANCO:
-- ERROR:  new row for relation "endereco" violates check constraint "ck_endereco_estado"
-- DETAIL:  Failing row contains (332, Rua Teste, 1, Centro, 36000000, Juiz de Fora, M ).


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



-- =================================================================================
-- SUBDOMÍNIO: CATÁLOGO
-- =================================================================================

-- =================================================================================
-- 1. INSERT
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- RN10 — CNPJ deve conter exatamente 14 dígitos numéricos.
-- Esperado: rejeição pela CHECK ck_loja_cnpj.
-- Resultado: new row for relation "loja" violates check constraint "ck_loja_cnpj"
-- ---------------------------------------------------------------------------------
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (1, 1, '1234567890123X', 'LOJA CNPJ INVALIDO', '(32) 3000-0001',
        'aberta', 30, 5.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "loja" violates check constraint "ck_loja_cnpj"
-- DETAIL:  Failing row contains (121, 1, 1, null, 1234567890123X, LOJA CNPJ INVALIDO, (32) 3000-0001, aberta, 30, 5.00).


-- ---------------------------------------------------------------------------------
-- Regra de integridade — CNPJ deve ser único.
-- Esperado: rejeição pela UNIQUE uk_loja_cnpj.
-- SQLSTATE esperado: 23505 (unique_violation).
-- O CNPJ informado precisa ser igual ao de uma loja já cadastrada.
-- ---------------------------------------------------------------------------------
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (1, 1, '12345678000195', 'LOJA CNPJ DUPLICADO', '(32) 3000-0002',
        'aberta', 30, 5.00);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uk_loja_cnpj"
-- DETAIL:  Key (cnpj)=(12345678000195) already exists.


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Loja deve referenciar um Lojista existente.
-- Esperado: rejeição pela FK fk_loja_lojista.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- ---------------------------------------------------------------------------------
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (-999999999, 1, '98765432000199', 'LOJA SEM LOJISTA', '(32) 3000-0003',
        'aberta', 30, 5.00);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "loja" violates foreign key constraint "fk_loja_lojista"
-- DETAIL:  Key (id_lojista)=(-999999999) is not present in table "lojista".


-- ---------------------------------------------------------------------------------
-- RN09 — Preço do Produto deve ser maior que zero.
-- Esperado: rejeição pela CHECK ck_produto_preco.
-- SQLSTATE esperado: 23514 (check_violation).
-- ---------------------------------------------------------------------------------
INSERT INTO produto (id_loja, nome, descricao, preco, ativo)
VALUES (1, 'PRODUTO PRECO ZERO', 'Teste RN09', 0, TRUE);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "produto" violates check constraint "ck_produto_preco"
-- DETAIL:  Failing row contains (601, 1, PRODUTO PRECO ZERO, Teste RN09, 0.00, t).


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Produto deve pertencer a uma Loja existente.
-- Esperado: rejeição pela FK fk_produto_loja.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- ---------------------------------------------------------------------------------
INSERT INTO produto (id_loja, nome, descricao, preco, ativo)
VALUES (-999999999, 'PRODUTO SEM LOJA', 'Teste de FK', 10.00, TRUE);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "produto" violates foreign key constraint "fk_produto_loja"
-- DETAIL:  Key (id_loja)=(-999999999) is not present in table "loja".


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Nome da Categoria é obrigatório.
-- Esperado: rejeição por NOT NULL em categoria.nome.
-- SQLSTATE esperado: 23502 (not_null_violation).
-- ---------------------------------------------------------------------------------
INSERT INTO categoria (id_loja, nome)
VALUES (1, NULL);

-- ERRO DO BANCO:
-- ERROR:  null value in column "nome" of relation "categoria" violates not-null constraint
-- DETAIL:  Failing row contains (601, 1, null).


-- ---------------------------------------------------------------------------------
-- RF07/RN01 — status_funcionamento aceita somente 'aberta' ou 'fechada'.
-- Esperado: rejeição pela enumeração status_funcionamento.
-- SQLSTATE esperado: 22P02 (invalid_text_representation).
-- ---------------------------------------------------------------------------------
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (1, 1, '98765432000270', 'LOJA STATUS INVALIDO', '(32) 3000-0004',
        'em_manutencao'::status_funcionamento, 30, 5.00);

-- ERRO DO BANCO:
-- ERROR:  invalid input value for enum status_funcionamento: "em_manutencao"
-- LINE 4:         'em_manutencao'::status_funcionamento, 30, 5.00);


-- ---------------------------------------------------------------------------------
-- ADR-001 — Produto e Categoria associados devem pertencer à mesma Loja.
-- Esperado: rejeição pela FK composta fk_produto_categoria_categoria.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- Premissa: Produto 1 pertence à Loja 1 e Categoria 6 à Loja 2.
-- ---------------------------------------------------------------------------------
INSERT INTO produto_categoria (id_loja, id_produto, id_categoria)
VALUES (1, 1, 6);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "produto_categoria" violates foreign key constraint "fk_produto_categoria_categoria"
-- DETAIL:  Key (id_loja, id_categoria)=(1, 6) is not present in table "categoria".


-- ---------------------------------------------------------------------------------
-- Regra de integridade — A associação Produto/Categoria não pode se repetir.
-- Esperado: rejeição pela PK pk_produto_categoria.
-- SQLSTATE esperado: 23505 (unique_violation).
-- Premissa: a associação (Produto 1, Categoria 1) já existe.
-- ---------------------------------------------------------------------------------
INSERT INTO produto_categoria (id_loja, id_produto, id_categoria)
VALUES (1, 1, 1);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_produto_categoria"
-- DETAIL:  Key (id_produto, id_categoria)=(1, 1) already exists.


-- =================================================================================
-- 2. UPDATE
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- RN09 — Preço do Produto deve continuar maior que zero.
-- Esperado: rejeição pela CHECK ck_produto_preco.
-- SQLSTATE esperado: 23514 (check_violation).
-- ---------------------------------------------------------------------------------
UPDATE produto SET preco = -1.00 WHERE id_produto = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "produto" violates check constraint "ck_produto_preco"
-- DETAIL:  Failing row contains (1, 1, Água mineral 500 ml - Loja 1, Produto de catálogo #1 da loja 1, -1.00, t).


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Nome do Produto é obrigatório.
-- Esperado: rejeição por NOT NULL em produto.nome.
-- SQLSTATE esperado: 23502 (not_null_violation).
-- ---------------------------------------------------------------------------------
UPDATE produto SET nome = NULL WHERE id_produto = 1;

-- ERRO DO BANCO:
-- ERROR:  null value in column "nome" of relation "produto" violates not-null constraint
-- DETAIL:  Failing row contains (1, 1, null, Produto de catálogo #1 da loja 1, 9.00, t).


-- ---------------------------------------------------------------------------------
-- ADR-001 — A associação não pode apontar para loja diferente da loja
-- à qual Produto 1 e Categoria 1 pertencem.
-- Esperado: rejeição por uma das FKs compostas de Produto_Categoria.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- ---------------------------------------------------------------------------------
UPDATE produto_categoria
SET id_loja = 2
WHERE id_produto = 1 AND id_categoria = 1;

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "produto_categoria" violates foreign key constraint "fk_produto_categoria_produto"
-- DETAIL:  Key (id_loja, id_produto)=(2, 1) is not present in table "produto".


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Tempo estimado de entrega deve ser positivo.
-- Esperado: rejeição pela CHECK ck_loja_tempo_entrega.
-- SQLSTATE esperado: 23514 (check_violation).
-- ---------------------------------------------------------------------------------
UPDATE loja SET tempo_entrega_estimado = 0 WHERE id_loja = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "loja" violates check constraint "ck_loja_tempo_entrega"
-- DETAIL:  Failing row contains (1, 81, 1, null, 12345678000195, Empório Central #1, 3232100001, aberta, 0, 4.75).


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Taxa de entrega não pode ser negativa.
-- Esperado: rejeição pela CHECK ck_loja_taxa_entrega.
-- SQLSTATE esperado: 23514 (check_violation).
-- ---------------------------------------------------------------------------------
UPDATE loja SET taxa_entrega = -0.01 WHERE id_loja = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "loja" violates check constraint "ck_loja_taxa_entrega"
-- DETAIL:  Failing row contains (1, 81, 1, null, 12345678000195, Empório Central #1, 3232100001, aberta, 21, -0.01).


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Categoria deve referenciar uma Loja existente.
-- Esperado: rejeição pela FK de Categoria para Loja.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- ---------------------------------------------------------------------------------
UPDATE categoria SET id_loja = -999999999 WHERE id_categoria = 1;

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "categoria" violates foreign key constraint "fk_categoria_loja"
-- DETAIL:  Key (id_loja)=(-999999999) is not present in table "loja".


-- =================================================================================
-- 3. DELETE
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- Regra de integridade — Não excluir Lojista que possui Loja (ON DELETE RESTRICT).
-- Esperado: rejeição pela FK fk_loja_lojista.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- ---------------------------------------------------------------------------------
DELETE FROM lojista WHERE id_pessoa = 81;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "lojista" violates RESTRICT setting of foreign key constraint "fk_loja_lojista" on table "loja"
-- DETAIL:  Key (id_pessoa)=(81) is referenced from table "loja".


-- ---------------------------------------------------------------------------------
-- Regra de integridade — Não excluir Endereco utilizado por Loja (ON DELETE RESTRICT).
-- Esperado: rejeição pela FK fk_loja_endereco.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- ---------------------------------------------------------------------------------
DELETE FROM endereco WHERE id_endereco = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "endereco" violates RESTRICT setting of foreign key constraint "fk_loja_endereco" on table "loja"
-- DETAIL:  Key (id_endereco)=(1) is referenced from table "loja".



-- =================================================================================
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- RR10: Coerência aritmética dos totais do Pedido (valor_total = subtotal + taxa_entrega + taxa_servico)
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_pedido_valor_total.
-- ---------------------------------------------------------------------------------
INSERT INTO pedido (id_loja, id_cliente, id_endereco, forma_pagamento,
                    subtotal, taxa_entrega, taxa_servico, valor_total)
VALUES (1, 101, 101, 'pix', 80.00, 7.00, 5.00, 100.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "pedido" violates check constraint "ck_pedido_valor_total"
-- DETAIL:  Failing row contains (200001, 1, 101, 101, null, null, null, solicitado, 2026-11-15 02:21:00.379717+00, pix, 80.00, 7.00, 5.00, 100.00).


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
-- DETAIL:  Failing row contains (1, 59, 70, 70, null, Próximo à padaria, null, pronto, 2026-08-02 16:55:50.004124+00, dinheiro, -10.00, 10.75, 2.50, 39.75).


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
-- DETAIL:  Failing row contains (1, 100.00, 5.00, 80.00, 10.00, 2026-11-15 02:21:00.380202+00).


-- ---------------------------------------------------------------------------------
-- RN07: Um pedido não pode misturar Produtos de lojas diferentes.
--       Todos os itens do pedido devem pertencer ao catálogo da mesma Loja.
-- Cenário A: Pedido 272 é da Loja 1 e Produto 6 é da Loja 2 (informando id_loja = 2).
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a FK composta
--                     fk_item_pedido_loja.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (272, 6, 2, 1, 25.00);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "item_pedido" violates foreign key constraint "fk_item_pedido_loja"
-- DETAIL:  Key (id_loja, id_pedido)=(2, 272) is not present in table "pedido".


-- ---------------------------------------------------------------------------------
-- RN07: Um pedido não pode misturar Produtos de lojas diferentes (Cenário B).
-- Cenário B: Pedido 272 é da Loja 1 e Produto 6 é da Loja 2 (tentando forçar id_loja = 1).
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a FK composta
--                     fk_item_produto_loja.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (272, 6, 1, 1, 25.00);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "item_pedido" violates foreign key constraint "fk_item_produto_loja"
-- DETAIL:  Key (id_loja, id_produto)=(1, 6) is not present in table "produto".


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
-- DETAIL:  Failing row contains (1, -5, muito bom o lanche, 2026-11-15 02:21:00.380912+00).


-- ---------------------------------------------------------------------------------
-- RN06: Nota fora do intervalo 1 a 5 na Avaliação do Entregador (UPDATE inválido).
-- Resultado esperado: O banco deve rejeitar a alteração, pois viola a check constraint
--                     ck_avaliacao_entregador_nota.
-- ---------------------------------------------------------------------------------
UPDATE avaliacao_entregador
SET nota = 6
WHERE id_pedido = 54411;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "avaliacao_entregador" violates check constraint "ck_avaliacao_entregador_nota"
-- DETAIL:  Failing row contains (54411, 6, Derramou meu refrigerante., 2026-06-10 11:08:41.914046+00).


-- ---------------------------------------------------------------------------------
-- RN09: A quantidade comprada no Item do Pedido deve ser estritamente maior que zero.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_item_pedido_quantidade.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (272, 1, 1, 0, 33.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "item_pedido" violates check constraint "ck_item_pedido_quantidade"
-- DETAIL:  Failing row contains (272, 1, 1, 0, 33.00).


-- ---------------------------------------------------------------------------------
-- RN09: O valor unitário no Item do Pedido deve ser estritamente maior que zero.
-- Resultado esperado: O banco deve rejeitar a inserção, pois viola a check constraint
--                     ck_item_pedido_valor_unitario.
-- ---------------------------------------------------------------------------------
INSERT INTO item_pedido (id_pedido, id_produto, id_loja, quantidade, valor_unitario)
VALUES (272, 1, 1, 2, -33.00);

-- ERRO DO BANCO:
-- ERROR:  new row for relation "item_pedido" violates check constraint "ck_item_pedido_valor_unitario"
-- DETAIL:  Failing row contains (272, 1, 1, 2, -33.00).


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
-- DETAIL:  Key (id_loja, id_pedido)=(59, 1) is still referenced from table "item_pedido".



-- =================================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =================================================================================

-- =================================================================================
-- 1. INSERT
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- PK de Rota: identificador único da rota não pode se repetir.
-- Resultado esperado: rejeição pela PK pk_rota (SQLSTATE 23505).
-- ---------------------------------------------------------------------------------
INSERT INTO rota (id_rota, id_entregador) OVERRIDING SYSTEM VALUE
VALUES (1, 1);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "pk_rota"
-- DETAIL:  Key (id_rota)=(1) already exists.


-- ---------------------------------------------------------------------------------
-- ADR-005 / Modelo lógico: associação Pedido-Entrega 1:1 (uq_entrega_pedido).
-- Premissa: pedido 3 já possui entrega cadastrada (id_entrega = 1).
-- Resultado esperado: rejeição pela UNIQUE uq_entrega_pedido (SQLSTATE 23505).
-- ---------------------------------------------------------------------------------
INSERT INTO entrega (id_pedido, previsao_entrega)
VALUES (3, CURRENT_TIMESTAMP);

-- ERRO DO BANCO:
-- ERROR:  duplicate key value violates unique constraint "uq_entrega_pedido"
-- DETAIL:  Key (id_pedido)=(3) already exists.


-- ---------------------------------------------------------------------------------
-- FK rota -> entregador: toda rota deve referenciar um entregador existente.
-- Resultado esperado: rejeição pela FK fk_rota_entregador (SQLSTATE 23503).
-- ---------------------------------------------------------------------------------
INSERT INTO rota (id_entregador)
VALUES (999999);

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "rota" violates foreign key constraint "fk_rota_entregador"
-- DETAIL:  Key (id_entregador)=(999999) is not present in table "entregador".


-- =================================================================================
-- 2. UPDATE
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- FK entrega -> pedido: toda entrega deve referenciar um pedido existente.
-- Resultado esperado: rejeição pela FK fk_entrega_pedido (SQLSTATE 23503).
-- ---------------------------------------------------------------------------------
UPDATE entrega
SET id_pedido = 999999
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "entrega" violates foreign key constraint "fk_entrega_pedido"
-- DETAIL:  Key (id_pedido)=(999999) is not present in table "pedido".


-- ---------------------------------------------------------------------------------
-- FK entrega -> rota: vínculo preenchido precisa apontar para rota existente.
-- Resultado esperado: rejeição pela FK fk_entrega_rota (SQLSTATE 23503).
-- ---------------------------------------------------------------------------------
UPDATE entrega
SET id_rota = 999999
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  insert or update on table "entrega" violates foreign key constraint "fk_entrega_rota"
-- DETAIL:  Key (id_rota)=(999999) is not present in table "rota".


-- ---------------------------------------------------------------------------------
-- NOT NULL de previsao_entrega (necessária para identificar atrasos na RN03/RR05).
-- Resultado esperado: rejeição por NOT NULL em entrega.previsao_entrega (SQLSTATE 23502).
-- ---------------------------------------------------------------------------------
UPDATE entrega
SET previsao_entrega = NULL
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  null value in column "previsao_entrega" of relation "entrega" violates not-null constraint
-- DETAIL:  Failing row contains (1, 3, 10655, entregue, null).


-- ---------------------------------------------------------------------------------
-- Regra complementar: encerramento não pode anteceder a criação da rota.
-- Resultado esperado: rejeição pela CHECK ck_rota_ordem_temporal (SQLSTATE 23514).
-- ---------------------------------------------------------------------------------
UPDATE rota
SET encerrada_em = criada_em - INTERVAL '1 second'
WHERE id_rota = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "rota" violates check constraint "ck_rota_ordem_temporal"
-- DETAIL:  Failing row contains (1, 1, 2026-11-15 02:29:03.255907+00, 2026-11-15 02:29:02.255907+00).


-- ---------------------------------------------------------------------------------
-- ADR-005: entrega com status diferente de 'aguardando_entregador' exige rota preenchida.
-- Premissa: entrega 1 está 'entregue' e vinculada a uma rota.
-- Resultado esperado: rejeição pela CHECK ck_entrega_status_rota (SQLSTATE 23514).
-- ---------------------------------------------------------------------------------
UPDATE entrega
SET id_rota = NULL
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "entrega" violates check constraint "ck_entrega_status_rota"
-- DETAIL:  Failing row contains (1, 3, null, entregue, 2026-11-14 03:39:03.255907+00).


-- ---------------------------------------------------------------------------------
-- ADR-005: entrega 'aguardando_entregador' exige id_rota NULL.
-- Premissa: entrega 1 possui id_rota preenchido.
-- Resultado esperado: rejeição pela CHECK ck_entrega_status_rota (SQLSTATE 23514).
-- ---------------------------------------------------------------------------------
UPDATE entrega
SET status = 'aguardando_entregador'
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  new row for relation "entrega" violates check constraint "ck_entrega_status_rota"
-- DETAIL:  Failing row contains (1, 3, 10655, aguardando_entregador, 2026-11-14 03:39:03.255907+00).


-- ---------------------------------------------------------------------------------
-- Domínio de status_entrega (usado pelo fluxo RR06): apenas valores do ENUM.
-- Resultado esperado: rejeição pela enumeração status_entrega (SQLSTATE 22P02).
-- ---------------------------------------------------------------------------------
UPDATE entrega
SET status = 'invalido'
WHERE id_entrega = 1;

-- ERRO DO BANCO:
-- ERROR:  invalid input value for enum status_entrega: "invalido"
-- LINE 2: SET status = 'invalido'


-- =================================================================================
-- 3. DELETE
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- Integridade Referencial (DELETE): excluir uma rota não deve apagar suas entregas
-- (ON DELETE RESTRICT em fk_entrega_rota).
-- Resultado esperado: rejeição pela FK fk_entrega_rota (SQLSTATE 23001).
-- ---------------------------------------------------------------------------------
DELETE FROM rota
WHERE id_rota = 1;

-- ERRO DO BANCO:
-- ERROR:  update or delete on table "rota" violates RESTRICT setting of foreign key constraint "fk_entrega_rota" on table "entrega"
-- DETAIL:  Key (id_rota)=(1) is referenced from table "entrega".
