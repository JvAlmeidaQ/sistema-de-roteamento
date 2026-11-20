-- =================================================================================
-- EXPERIMENTOS DE ÍNDICES - SUBDOMÍNIO: IDENTIDADE E CONTATO (E6)
-- Arquivo: testes_identidade/experimentos.sql
--
-- Executar em um banco NOVO, VAZIO e DESCARTÁVEL (nunca na base oficial).
-- Na raiz do repositório:
--   docker exec postgres-dev psql -U sistemaRoteamento -d postgres \
--     -c "DROP DATABASE IF EXISTS identidade_experimentos;" \
--     -c "CREATE DATABASE identidade_experimentos;"
--   cat grupo10/sql/01_esquema.sql grupo10/sql/02_carga.sql \
--       grupo10/sql/testes_identidade/experimentos.sql \
--     | docker exec -i postgres-dev psql -X -U sistemaRoteamento \
--         -d identidade_experimentos -P pager=off
--
-- O cat junta esquema + carga oficial + este roteiro e envia tudo ao psql do
-- container (só 01 e 02 estão montados nele; por isso não usamos \ir).
-- Os gatilhos (06) não são instalados: não interferem nas consultas medidas.
--
-- Fases:
--   1. Ampliação da base: a carga oficial tem só 300 pessoas, pequena demais
--      para medir índices. Acrescentamos 200.000 pessoas, endereços, vínculos e
--      telefones sintéticos, apenas neste banco de experimento.
--   2. ANTES: EXPLAIN ANALYZE das três consultas, sem os índices de 07.
--   3. Criação dos índices de 07_indices_identidade.sql.
--   4. DEPOIS: as mesmas três consultas, com os índices.
-- =================================================================================
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------------
-- Fase 1 — Ampliação da base (200.000 linhas por tabela)
-- ---------------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
SELECT
    (ARRAY['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Felipe', 'Gabriela',
           'Henrique', 'Isabela', 'João', 'Larissa', 'Marcos', 'Natália',
           'Otávio', 'Paula', 'Rafael', 'Sofia', 'Thiago', 'Vanessa', 'Lucas'])[1 + i % 20]
    || ' ' ||
    (ARRAY['Silva', 'Souza', 'Oliveira', 'Santos', 'Pereira', 'Costa',
           'Almeida', 'Ferreira', 'Rodrigues', 'Gomes', 'Martins', 'Barbosa',
           'Ribeiro', 'Carvalho', 'Moreira', 'Teixeira', 'Rocha', 'Lima',
           'Araújo', 'Cardoso', 'Pinto', 'Mendes', 'Castro', 'Nunes', 'Freitas'])[1 + (i / 20) % 25]
    || ' ' || i,
    lpad((10000000 + i)::TEXT, 11, '0'),
    'exp' || i || '@exemplo.com'
FROM generate_series(1, 200000) AS g(i);

INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
SELECT 'Rua Experimento ' || (i % 500),
       (100000 + i)::TEXT,
       'Bairro ' || (i % 50),
       '361' || lpad((i % 100000)::TEXT, 5, '0'),
       'Juiz de Fora',
       'MG'
FROM generate_series(1, 200000) AS g(i);

-- Cada pessoa sintética é vinculada ao endereço sintético de mesmo número.
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido)
SELECT p.id_pessoa, e.id_endereco, 'Casa'
  FROM generate_series(1, 200000) AS g(i)
INNER JOIN pessoa p
        ON (p.cpf = lpad((10000000 + g.i)::TEXT, 11, '0'))
INNER JOIN endereco e
        ON (e.logradouro = 'Rua Experimento ' || (g.i % 500)
            AND e.numero = (100000 + g.i)::TEXT
            AND e.cep = '361' || lpad((g.i % 100000)::TEXT, 5, '0'));

-- Todos têm celular; uma em cada dez pessoas também tem telefone fixo.
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT id_pessoa, '3298' || lpad(id_pessoa::TEXT, 7, '0'), 'celular'
  FROM pessoa
 WHERE email LIKE 'exp%';

INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT id_pessoa, '3231' || lpad(id_pessoa::TEXT, 6, '0'), 'fixo'
  FROM pessoa
 WHERE email LIKE 'exp%' AND id_pessoa % 10 = 0;

ANALYZE pessoa;
ANALYZE endereco;
ANALYZE pessoa_endereco;
ANALYZE telefone;

-- Quantidade de linhas NAS TABELAS usadas pelos experimentos.
SELECT 'pessoa' AS tabela, COUNT(*) AS linhas FROM pessoa
UNION ALL SELECT 'endereco', COUNT(*) FROM endereco
UNION ALL SELECT 'pessoa_endereco', COUNT(*) FROM pessoa_endereco
UNION ALL SELECT 'telefone', COUNT(*) FROM telefone;

-- ---------------------------------------------------------------------------------
-- Fase 2 — ANTES dos índices
-- ---------------------------------------------------------------------------------
\echo '===== ANTES DOS ÍNDICES ====='

\echo '--- Experimento 1: pessoas vinculadas a um endereço ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_pessoa, p.nome, pe.apelido
  FROM pessoa_endereco pe
INNER JOIN pessoa p
        ON (p.id_pessoa = pe.id_pessoa)
 WHERE pe.id_endereco = 101;

\echo '--- Experimento 2: busca de pessoa pelo nome ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pessoa, nome, email
  FROM pessoa
 WHERE nome = 'Ana Silva 100000';

\echo '--- Experimento 3: telefones do tipo celular ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pessoa, numero
  FROM telefone
 WHERE tipo = 'celular';

-- ---------------------------------------------------------------------------------
-- Fase 3 — Criação dos índices (mesmo conteúdo de 07_indices_identidade.sql)
-- ---------------------------------------------------------------------------------
CREATE INDEX idx_pessoa_endereco_endereco ON pessoa_endereco USING btree (id_endereco);
CREATE INDEX idx_pessoa_nome ON pessoa USING btree (nome);
CREATE INDEX idx_telefone_tipo ON telefone USING btree (tipo);

-- ---------------------------------------------------------------------------------
-- Fase 4 — DEPOIS dos índices
-- ---------------------------------------------------------------------------------
\echo '===== DEPOIS DOS ÍNDICES ====='

\echo '--- Experimento 1: pessoas vinculadas a um endereço ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_pessoa, p.nome, pe.apelido
  FROM pessoa_endereco pe
INNER JOIN pessoa p
        ON (p.id_pessoa = pe.id_pessoa)
 WHERE pe.id_endereco = 101;

\echo '--- Experimento 2: busca de pessoa pelo nome ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pessoa, nome, email
  FROM pessoa
 WHERE nome = 'Ana Silva 100000';

\echo '--- Experimento 3: telefones do tipo celular ---'
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pessoa, numero
  FROM telefone
 WHERE tipo = 'celular';
