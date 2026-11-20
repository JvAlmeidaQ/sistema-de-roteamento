-- =================================================================================
-- ÍNDICES - SUBDOMÍNIO: IDENTIDADE E CONTATO (E6)
-- Arquivo: 07_indices_identidade.sql
-- Experimentos (EXPLAIN ANALYZE antes e depois): experimentos.md e
-- testes_identidade/experimentos.sql.
--
-- Observações gerais:
--   - PRIMARY KEY e UNIQUE já criam índices automaticamente (pk_pessoa,
--     uq_pessoa_cpf, uq_pessoa_email, pk_pessoa_endereco...). Não duplicamos.
--   - FOREIGN KEY NÃO cria índice na coluna de origem: por isso
--     pessoa_endereco.id_endereco não tem índice próprio no DDL.
--   - Todo índice tem custo: ocupa espaço e torna INSERT/UPDATE/DELETE mais
--     lentos, porque o índice também precisa ser atualizado.
-- =================================================================================

BEGIN;

-- ---------------------------------------------------------------------------------
-- Tabela pessoa_endereco, coluna id_endereco, B-tree.
-- Consulta beneficiada: "quem está vinculado ao endereço X?" (Experimento 1).
-- A PK (id_pessoa, id_endereco) começa por id_pessoa, então não ajuda a buscar
-- só por id_endereco: um índice B-tree composto só é eficiente a partir da sua
-- primeira coluna. Também acelera a checagem do ON DELETE RESTRICT de
-- fk_pessoa_endereco_endereco quando alguém tenta apagar um endereço.
-- ---------------------------------------------------------------------------------
CREATE INDEX idx_pessoa_endereco_endereco
    ON pessoa_endereco USING btree (id_endereco);

-- ---------------------------------------------------------------------------------
-- Tabela pessoa, coluna nome, B-tree.
-- Consulta beneficiada: busca de pessoas pelo nome no atendimento
-- (Experimento 2). Sem índice, o banco precisa ler a tabela inteira.
-- ---------------------------------------------------------------------------------
CREATE INDEX idx_pessoa_nome
    ON pessoa USING btree (nome);

-- ---------------------------------------------------------------------------------
-- Tabela telefone, coluna tipo, B-tree.
-- Consulta pretendida: listar os telefones de um tipo (Experimento 3).
-- Mantido para o experimento do índice NÃO utilizado: a coluna tem só três
-- valores, e 'celular' corresponde à maior parte das linhas. Para esse filtro,
-- ler a tabela inteira é mais barato do que percorrer o índice, então o
-- otimizador ignora o índice (ver experimentos.md).
-- ---------------------------------------------------------------------------------
CREATE INDEX idx_telefone_tipo
    ON telefone USING btree (tipo);

COMMIT;
