# E6: índices e experimentos de Identidade e Contato

## Objetivo e reprodução

Comparar três consultas do subdomínio Identidade e Contato antes e depois dos três
índices de `07_indices_identidade.sql`, usando `EXPLAIN (ANALYZE, BUFFERS)`. Duas
consultas mostram o ganho do índice; a terceira mostra um índice que o otimizador
decide não usar.

A carga oficial (`02_carga.sql`) tem apenas 300 pessoas: nesse tamanho a tabela
inteira cabe em poucas páginas e as diferenças de tempo ficam em frações de
milissegundo. Por isso o roteiro `testes_identidade/experimentos.sql` acrescenta
200.000 pessoas, endereços, vínculos e telefones sintéticos com `generate_series`,
**somente no banco de experimento**. A carga oficial não é alterada.

Em banco novo e descartável, execute na raiz do repositório:

```sh
docker exec postgres-dev psql -U sistemaRoteamento -d postgres \
  -c "DROP DATABASE IF EXISTS identidade_experimentos;" \
  -c "CREATE DATABASE identidade_experimentos;"

cat grupo10/sql/01_esquema.sql grupo10/sql/02_carga.sql \
    grupo10/sql/testes_identidade/experimentos.sql \
  | docker exec -i postgres-dev psql -X -U sistemaRoteamento \
      -d identidade_experimentos -P pager=off
```

O roteiro executa o esquema e a carga oficiais, amplia a base, roda `ANALYZE`,
mede as três consultas (fase ANTES), cria os índices de `07_indices_identidade.sql`
e mede de novo (fase DEPOIS). Os gatilhos de `06` não são instalados, pois não
interferem nas consultas medidas. PKs, UNIQUEs, FKs e CHECKs estão ativos nas
duas fases.

Linhas nas tabelas usadas pelos experimentos (após a ampliação):

| Tabela | Linhas |
| --- | ---: |
| `pessoa` | 200.300 |
| `endereco` | 200.330 |
| `pessoa_endereco` | 200.350 |
| `telefone` | 220.495 |

## Índices e consultas beneficiadas

| Índice | Tabela e colunas | Tipo | Consulta ou operação |
| --- | --- | --- | --- |
| `idx_pessoa_endereco_endereco` | `pessoa_endereco(id_endereco)` | B-tree | Experimento 1: pessoas vinculadas a um endereço; checagem do `ON DELETE RESTRICT` de `fk_pessoa_endereco_endereco`. |
| `idx_pessoa_nome` | `pessoa(nome)` | B-tree | Experimento 2: busca de pessoa pelo nome. |
| `idx_telefone_tipo` | `telefone(tipo)` | B-tree | Experimento 3: telefones de um tipo (índice **não utilizado**). |

Os índices não duplicam PKs nem UNIQUEs. A PK de `pessoa_endereco` é
`(id_pessoa, id_endereco)` e começa por `id_pessoa`, por isso não serve para buscar
só por `id_endereco`; e a FK para `endereco` não cria índice automaticamente. Todo
índice tem custo de armazenamento e de manutenção nas escritas.

## Consultas medidas

```sql
-- Experimento 1: pessoas vinculadas ao endereço 101
SELECT p.id_pessoa, p.nome, pe.apelido
  FROM pessoa_endereco pe
INNER JOIN pessoa p
        ON (p.id_pessoa = pe.id_pessoa)
 WHERE pe.id_endereco = 101;

-- Experimento 2: busca de pessoa pelo nome
SELECT id_pessoa, nome, email
  FROM pessoa
 WHERE nome = 'Ana Silva 100000';

-- Experimento 3: telefones do tipo celular
SELECT id_pessoa, numero
  FROM telefone
 WHERE tipo = 'celular';
```

## Resultados observados

Execução em 19/11/2026, PostgreSQL 18 em Docker, uma medição por consulta em cada fase. Tempos do
executor (`Execution Time`), sem incluir o cliente nem a criação dos índices. Não
foi alterado o planejador para forçar ou proibir índices.

| Consulta | Linhas retornadas | Custo estimado antes | Custo estimado depois | Tempo antes | Tempo depois | Operação antes | Operação depois |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| E1: vinculados ao endereço 101 | 2 | 3.789,81 | 16,88 | 5,287 ms | 0,034 ms | Seq Scan em pessoa_endereco | Index Scan em idx_pessoa_endereco_endereco |
| E2: pessoa pelo nome | 1 | 4.803,75 | 8,44 | 6,372 ms | 0,022 ms | Seq Scan em pessoa | Index Scan em idx_pessoa_nome |
| E3: telefones celular | 200.300 | 4.161,19 | 4.161,19 | 13,959 ms | 14,124 ms | Seq Scan em telefone | Seq Scan em telefone (índice ignorado) |

### Experimento 1: operação que mudou

Antes do índice, o nó `Seq Scan on pessoa_endereco` lia a tabela inteira
(1.277 páginas, 200.348 linhas descartadas pelo filtro) para encontrar 2 vínculos.
Depois, o mesmo nó virou `Index Scan using idx_pessoa_endereco_endereco`, que lê
apenas 5 páginas. A busca em `pessoa` pela PK (`Index Scan using pk_pessoa`) e a
junção `Nested Loop` não mudaram. O custo estimado do nó raiz caiu de 3.789,81
para 16,88 (cerca de 225 vezes) e o tempo real caiu de 5,287 para 0,034 ms
(cerca de 155 vezes).

### Experimento 2: operação que mudou

`Seq Scan on pessoa` (2.300 páginas lidas, 200.299 linhas descartadas) foi
substituído por `Index Scan using idx_pessoa_nome` (4 páginas). O custo estimado
caiu de 4.803,75 para 8,44 (cerca de 570 vezes) e o tempo real de 6,372 para
0,022 ms (cerca de 290 vezes).

### Experimento 3: índice criado e não utilizado

Mesmo com `idx_telefone_tipo` disponível, o plano continuou `Seq Scan on telefone`,
com o mesmo custo estimado (4.161,19) e tempo equivalente (13,959 e 14,124 ms; a
diferença é variação natural entre execuções). O filtro `tipo = 'celular'` retorna
200.300 das 220.495 linhas, cerca de 91% da tabela. A coluna `tipo` tem só três
valores possíveis, ou seja, baixa seletividade. Para devolver quase todas as
linhas pelo índice, o banco teria que percorrer o índice **e** visitar
praticamente todas as páginas da tabela em ordem aleatória, o que é mais caro do
que lê-las uma única vez em sequência. O otimizador estima esse custo com base
nas estatísticas coletadas pelo `ANALYZE` (que mostram a frequência de cada tipo)
e escolhe a varredura sequencial. O índice só seria vantajoso para um tipo raro,
e ainda assim teria custo de manutenção em toda inserção de telefone.

### Custo estimado e tempo real

O custo do otimizador é medido em unidades arbitrárias (baseadas no custo de ler
uma página em sequência), não em milissegundos, por isso os valores não podem ser
comparados diretamente com o tempo. O que se compara é a **proporção**: nos
experimentos 1 e 2, a queda do custo estimado (225 e 570 vezes) indicou
corretamente uma queda grande do tempo real (155 e 290 vezes), mas as proporções
não são iguais. Os tempos também dependem do cache: as páginas já estavam na
memória (`shared hit`), então a varredura sequencial ficou mais rápida do que
seria lendo do disco. No experimento 3 o custo estimado não mudou porque o plano
não mudou, e o tempo real também ficou igual. Uma única execução por fase, em
base sintética, não permite generalizar os tempos absolutos.

## Planos completos

### Experimento 1 antes do índice

```text
                                                          QUERY PLAN                                                          
------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.42..3789.81 rows=1 width=33) (actual time=0.013..5.275 rows=2.00 loops=1)
   Buffers: shared hit=1285
   ->  Seq Scan on pessoa_endereco pe  (cost=0.00..3781.38 rows=1 width=13) (actual time=0.009..5.267 rows=2.00 loops=1)
         Filter: (id_endereco = 101)
         Rows Removed by Filter: 200348
         Buffers: shared hit=1277
   ->  Index Scan using pk_pessoa on pessoa p  (cost=0.42..8.44 rows=1 width=28) (actual time=0.002..0.002 rows=1.00 loops=2)
         Index Cond: (id_pessoa = pe.id_pessoa)
         Index Searches: 2
         Buffers: shared hit=8
 Planning:
   Buffers: shared hit=36 read=4
 Planning Time: 0.215 ms
 Execution Time: 5.287 ms
```

### Experimento 1 depois do índice

```text
                                                                        QUERY PLAN                                                                         
-----------------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.84..16.88 rows=1 width=33) (actual time=0.018..0.021 rows=2.00 loops=1)
   Buffers: shared hit=10 read=3
   ->  Index Scan using idx_pessoa_endereco_endereco on pessoa_endereco pe  (cost=0.42..8.44 rows=1 width=13) (actual time=0.012..0.013 rows=2.00 loops=1)
         Index Cond: (id_endereco = 101)
         Index Searches: 1
         Buffers: shared hit=2 read=3
   ->  Index Scan using pk_pessoa on pessoa p  (cost=0.42..8.44 rows=1 width=28) (actual time=0.002..0.002 rows=1.00 loops=2)
         Index Cond: (id_pessoa = pe.id_pessoa)
         Index Searches: 2
         Buffers: shared hit=8
 Planning:
   Buffers: shared hit=55 read=2
 Planning Time: 0.205 ms
 Execution Time: 0.034 ms
```

### Experimento 2 antes do índice

```text
                                              QUERY PLAN                                               
-------------------------------------------------------------------------------------------------------
 Seq Scan on pessoa  (cost=0.00..4803.75 rows=1 width=49) (actual time=3.244..6.367 rows=1.00 loops=1)
   Filter: ((nome)::text = 'Ana Silva 100000'::text)
   Rows Removed by Filter: 200299
   Buffers: shared hit=2300
 Planning Time: 0.026 ms
 Execution Time: 6.372 ms
```

### Experimento 2 depois do índice

```text
                                                         QUERY PLAN                                                         
----------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_pessoa_nome on pessoa  (cost=0.42..8.44 rows=1 width=49) (actual time=0.019..0.019 rows=1.00 loops=1)
   Index Cond: ((nome)::text = 'Ana Silva 100000'::text)
   Index Searches: 1
   Buffers: shared hit=1 read=3
 Planning Time: 0.021 ms
 Execution Time: 0.022 ms
```

### Experimento 3 antes do índice

```text
                                                     QUERY PLAN                                                     
--------------------------------------------------------------------------------------------------------------------
 Seq Scan on telefone  (cost=0.00..4161.19 rows=200180 width=19) (actual time=0.005..10.320 rows=200300.00 loops=1)
   Filter: (tipo = 'celular'::tipo_telefone)
   Rows Removed by Filter: 20195
   Buffers: shared hit=1405
 Planning:
   Buffers: shared hit=8
 Planning Time: 0.036 ms
 Execution Time: 13.959 ms
```

### Experimento 3 depois do índice

```text
                                                     QUERY PLAN                                                     
--------------------------------------------------------------------------------------------------------------------
 Seq Scan on telefone  (cost=0.00..4161.19 rows=200180 width=19) (actual time=0.006..10.461 rows=200300.00 loops=1)
   Filter: (tipo = 'celular'::tipo_telefone)
   Rows Removed by Filter: 20195
   Buffers: shared hit=1405
 Planning:
   Buffers: shared hit=16 read=1
 Planning Time: 0.045 ms
 Execution Time: 14.124 ms
```
