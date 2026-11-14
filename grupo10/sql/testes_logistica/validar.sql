-- Validação isolada em banco vazio e descartável, via psql.
-- Na raiz do repositório, com acesso local ao PostgreSQL configurado:
-- createdb -U sistemaRoteamento logistica_validacao
-- psql -X -U sistemaRoteamento -d logistica_validacao -f grupo10/sql/testes_logistica/validar.sql
-- Não usar o banco de desenvolvimento. Este roteiro não cria nem apaga bancos.
-- Na integração, utilizar os esquemas e cargas reais em vez da fixture.
-- ON_ERROR_STOP interrompe falhas inesperadas. Os casos negativos de 03 e da E6
-- capturam os erros esperados e imprimem sua mensagem, sem interromper o roteiro.
-- RN02/RR02, RN12/RR07 e RR06 são verificadas pelos arquivos incluídos abaixo.
-- Este roteiro usa metacomandos de psql; não executar como uma consulta de API.
\set ON_ERROR_STOP on
\ir fixtures/dependencias.sql
\ir ../01_esquema_logistica.sql

\ir ../02_carga_logistica.sql

-- Os testes terminam em ROLLBACK: registrar apenas as contagens para conferir isso.
SELECT COUNT(*) AS pedidos FROM pedido \gset carga_
SELECT COUNT(*) AS rotas FROM rota \gset carga_
SELECT COUNT(*) AS entregas FROM entrega \gset carga_
\ir ../03_verificacao_logistica.sql
\ir ../04_consultas_logistica.sql
\ir ../05_visoes_logistica.sql
\ir ../06_triggers_logistica.sql
\ir ../07_indices_logistica.sql
\ir ../verificacao_dos_gatilhos_logistica.sql

-- Volume da seção 5.2 e preservação da carga após as verificações.
-- Esperado: pelo menos 200 mil pedidos e contagens inalteradas após ROLLBACK.
-- A falha imprime a mensagem abaixo e encerra psql com status 1; não é erro de RN.
SELECT (SELECT COUNT(*) FROM pedido) = :carga_pedidos
   AND (SELECT COUNT(*) FROM rota) = :carga_rotas
   AND (SELECT COUNT(*) FROM entrega) = :carga_entregas
   AND :carga_pedidos >= 200000 AS carga_preservada \gset
\if :carga_preservada
\echo 'PASSOU: volume mínimo e carga preservada após os testes'
\else
\echo 'FALHOU: volume insuficiente ou testes alteraram a carga'
\quit 1
\endif

-- Consultas e visões devem retornar dados sobre a mesma carga da E4.
-- LIMIT reduz apenas a saída de inspeção, não as definições das visões da E5.
SELECT * FROM vw_painel_rotas_logistica ORDER BY id_rota LIMIT 5;
SELECT * FROM vw_fila_despacho_logistica ORDER BY id_pedido LIMIT 5;
