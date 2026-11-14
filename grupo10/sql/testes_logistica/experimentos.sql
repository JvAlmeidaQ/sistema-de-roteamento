-- E6: executar via psql em OUTRO banco vazio e descartável.
-- Na raiz do repositório, com acesso local ao PostgreSQL configurado:
-- createdb -U sistemaRoteamento logistica_experimentos
-- psql -X -U sistemaRoteamento -d logistica_experimentos -f grupo10/sql/testes_logistica/experimentos.sql
-- Planos medidos e análise exigida pela seção 8.2: ../experimentos.md.
-- Este roteiro não cria nem apaga bancos; a criação dos índices altera o schema.
-- Produz os quatro planos exigidos pela seção 8.2, sem alterar o Markdown.
-- Usa a mesma carga 02 da E4; não instalar 06 ou 07 antes da fase ANTES.
-- PKs/UNIQUEs continuam indexados na fase ANTES; só os índices secundários de 07
-- são adicionados na fase DEPOIS. Não alterar dados nem estatísticas entre as fases.
-- Esperado: resultado lógico preservado; comparar custo, tempo e operação nos planos.
-- Ganho de tempo não é garantido pelo CREATE INDEX; registrar o plano observado.
-- Falhas inesperadas encerram psql por ON_ERROR_STOP; as medições não violam RNs.
\set ON_ERROR_STOP on
\ir fixtures/dependencias.sql
\ir ../01_esquema_logistica.sql
\ir ../02_carga_logistica.sql

-- A tabela do relatório pede linhas NA TABELA, não linhas retornadas pela consulta.
SELECT 'pedido' AS tabela, COUNT(*) AS linhas FROM pedido
UNION ALL SELECT 'rota', COUNT(*) FROM rota
UNION ALL SELECT 'entrega', COUNT(*) FROM entrega;

\echo 'ANTES DOS ÍNDICES: L3 e L4 de 04_consultas_logistica.sql'
\ir atrasos.sql
\ir fila_prontos.sql
\ir ../07_indices_logistica.sql
\echo 'DEPOIS DOS ÍNDICES: L3 e L4 de 04_consultas_logistica.sql'
\ir atrasos.sql
\ir fila_prontos.sql
