-- 1. INSERT

-- RN10 — CNPJ deve conter exatamente 14 dígitos numéricos.
-- Esperado: rejeição pela CHECK ck_loja_cnpj.
-- Resultado: new row for relation "loja" violates check constraint "ck_loja_cnpj"
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (1, 1, '1234567890123X', 'LOJA CNPJ INVALIDO', '(32) 3000-0001',
        'aberta', 30, 5.00);

-- Regra de integridade — CNPJ deve ser único.
-- Esperado: rejeição pela UNIQUE uk_loja_cnpj.
-- SQLSTATE esperado: 23505 (unique_violation).
-- O CNPJ informado precisa ser igual ao de uma loja já cadastrada.
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (1, 1, '12345678000195', 'LOJA CNPJ DUPLICADO', '(32) 3000-0002',
        'aberta', 30, 5.00);

-- Regra de integridade — Loja deve referenciar um Lojista existente.
-- Esperado: rejeição pela FK fk_loja_lojista.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (-999999999, 1, '98765432000199', 'LOJA SEM LOJISTA', '(32) 3000-0003',
        'aberta', 30, 5.00);

-- RN09 — Preço do Produto deve ser maior que zero.
-- Esperado: rejeição pela CHECK ck_produto_preco.
-- SQLSTATE esperado: 23514 (check_violation).
INSERT INTO produto (id_loja, nome, descricao, preco, ativo)
VALUES (1, 'PRODUTO PRECO ZERO', 'Teste RN09', 0, TRUE);

-- Regra de integridade — Produto deve pertencer a uma Loja existente.
-- Esperado: rejeição pela FK fk_produto_loja.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
INSERT INTO produto (id_loja, nome, descricao, preco, ativo)
VALUES (-999999999, 'PRODUTO SEM LOJA', 'Teste de FK', 10.00, TRUE);

-- Regra de integridade — Nome da Categoria é obrigatório.
-- Esperado: rejeição por NOT NULL em categoria.nome.
-- SQLSTATE esperado: 23502 (not_null_violation).
INSERT INTO categoria (id_loja, nome)
VALUES (1, NULL);

-- RF07/RN01 — status_funcionamento aceita somente 'aberta' ou 'fechada'.
-- Esperado: rejeição pela enumeração status_funcionamento.
-- SQLSTATE esperado: 22P02 (invalid_text_representation).
INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
VALUES (1, 1, '98765432000270', 'LOJA STATUS INVALIDO', '(32) 3000-0004',
        'em_manutencao'::status_funcionamento, 30, 5.00);

-- ADR-001 — Produto e Categoria associados devem pertencer à mesma Loja.
-- Esperado: rejeição pela FK composta fk_produto_categoria_categoria.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
-- Premissa: Produto 1 pertence à Loja 1 e Categoria 2 à Loja 2.
INSERT INTO produto_categoria (id_loja, id_produto, id_categoria)
VALUES (1, 1, 2);

-- Regra de integridade — A associação Produto/Categoria não pode se repetir.
-- Esperado: rejeição pela PK pk_produto_categoria.
-- SQLSTATE esperado: 23505 (unique_violation).
-- Premissa: a associação (Produto 1, Categoria 1) já existe.
INSERT INTO produto_categoria (id_loja, id_produto, id_categoria)
VALUES (1, 1, 1);

-- 2. UPDATE

-- RN09 — Preço do Produto deve continuar maior que zero.
-- Esperado: rejeição pela CHECK ck_produto_preco.
-- SQLSTATE esperado: 23514 (check_violation).
UPDATE produto SET preco = -1.00 WHERE id_produto = 1;

-- Regra de integridade — Nome do Produto é obrigatório.
-- Esperado: rejeição por NOT NULL em produto.nome.
-- SQLSTATE esperado: 23502 (not_null_violation).
UPDATE produto SET nome = NULL WHERE id_produto = 1;

-- ADR-001 — A associação não pode apontar para loja diferente da loja
-- à qual Produto 1 e Categoria 1 pertencem.
-- Esperado: rejeição por uma das FKs compostas de Produto_Categoria.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
UPDATE produto_categoria
SET id_loja = 2
WHERE id_produto = 1 AND id_categoria = 1;

-- Regra de integridade — Tempo estimado de entrega deve ser positivo.
-- Esperado: rejeição pela CHECK ck_loja_tempo_entrega.
-- SQLSTATE esperado: 23514 (check_violation).
UPDATE loja SET tempo_entrega_estimado = 0 WHERE id_loja = 1;

-- Regra de integridade — Taxa de entrega não pode ser negativa.
-- Esperado: rejeição pela CHECK ck_loja_taxa_entrega.
-- SQLSTATE esperado: 23514 (check_violation).
UPDATE loja SET taxa_entrega = -0.01 WHERE id_loja = 1;

-- Regra de integridade — Categoria deve referenciar uma Loja existente.
-- Esperado: rejeição pela FK de Categoria para Loja.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
UPDATE categoria SET id_loja = -999999999 WHERE id_categoria = 1;

-- 3. DELETE

-- Regra de integridade — Não excluir Lojista que possui Loja (ON DELETE RESTRICT).
-- Esperado: rejeição pela FK fk_loja_lojista.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
DELETE FROM lojista WHERE id_pessoa = 1;

-- Regra de integridade — Não excluir Endereco utilizado por Loja (ON DELETE RESTRICT).
-- Esperado: rejeição pela FK fk_loja_endereco.
-- SQLSTATE esperado: 23503 (foreign_key_violation).
DELETE FROM endereco WHERE id_endereco = 1;
