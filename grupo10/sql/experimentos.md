# E6: índices e experimentos de Logística

## Objetivo e reprodução

Comparar L3 e L4 de `04_consultas_logistica.sql`, antes e depois dos quatro
índices de `07_indices_logistica.sql`. O roteiro SQL executa uma medição por
consulta em cada fase, com `EXPLAIN ANALYZE`. Não há Python, aquecimento, hashes,
arquivo JSON ou geração automática deste documento.

Em banco novo e descartável, execute na raiz do repositório:

```sh
createdb -U sistemaRoteamento logistica_experimentos
psql -X -U sistemaRoteamento -d logistica_experimentos -f grupo10/sql/testes_logistica/experimentos.sql
```

O roteiro prepara os dados externos em `fixtures/dependencias.sql`, com
500.000 pedidos via `generate_series`, e executa `01_esquema_logistica.sql` e
`02_carga_logistica.sql`. É o mesmo caminho utilizado na validação da E4/E5.
Não há uma segunda carga de rotas e entregas exclusiva do experimento.

Sobre os pedidos disponíveis, 02 gera 249.651 rotas e 499.700 entregas e termina
com ANALYZE em pedido, rota e entrega. As três tabelas superam 200 mil registros.
Os gatilhos ainda não são instalados nesta fase; PKs, FKs e CHECKs estão ativos.
A preparação externa continua temporária até a integração dos subdomínios.
Na consolidação, esses pedidos virão da carga oficial de Comércio/Finanças,
sem copiar as tabelas auxiliares nem gerar pedidos novamente em Logística.

## Índices e consultas beneficiadas

| Índice | Tabela e colunas | Tipo | Consulta ou operação |
| --- | --- | --- | --- |
| `idx_entrega_rota` | `entrega(id_rota)` | B-tree | Contagem da RN02, L1 e junções do painel. |
| `idx_rota_entregador` | `rota(id_entregador)` | B-tree | Consulta 15 e associação de rotas ao entregador em L3. |
| `idx_entrega_ativa_previsao_pedido` | `entrega(previsao_entrega, id_pedido)` | B-tree parcial para `aceita`/`a_caminho` | Filtro de atrasos de L3. |
| `idx_pedido_pronto_fila` | `pedido(data_pedido, id_pedido) INCLUDE (id_loja)` | B-tree parcial para `pronto` | Seleção e ordenação da fila L4. |

Os índices secundários não duplicam PKs/UNIQUEs. Têm custo de armazenamento e
manutenção na escrita. O experimento demonstra os planos das duas consultas;
não comprova ganho de cada um dos quatro índices individualmente.

## Resultados observados

Execução em 14/11/2026, PostgreSQL 18 em Docker, armazenamento descartável em
memória. Tempos do executor, sem incluir o cliente ou a criação dos índices.
As fases ocorreram em sequência; diferenças de cache também influenciam os tempos.
Não foi executado `VACUUM FREEZE`, nem alterado o planejador para forçar índices.

| Consulta | Tabela de volume e linhas | Tempo sem índices secundários | Tempo com índices secundários | Operação antes | Operação depois |
| --- | --- | ---: | ---: | --- | --- |
| L3: entregadores com atrasos ativos | `entrega`: 499.700 | 21,980 ms | 0,992 ms | Parallel Seq Scan em entrega | Index Scan em entrega |
| L4: pedidos prontos sem rota | `pedido`: 500.000 | 22,333 ms | 15,321 ms | Parallel Seq Scan em pedido | Bitmap Index Scan + Parallel Bitmap Heap Scan em pedido |

L3 retorna 200 entregadores e L4 retorna 700 pedidos. Esses resultados não são
o número de linhas das tabelas informado acima.

Em L3, o custo total estimado do nó raiz caiu de 11.183,64 para 6.650,42, e o
tempo real passou de 21,980 para 0,992 ms. A varredura paralela de entrega foi
substituída pelo índice parcial por previsão, que encontrou 400 entregas atrasadas.
A busca das rotas continuou usando a PK; os nós de junção e ordenação também
mudaram. O ganho observado pertence ao plano completo, não a cada índice isolado.

Em L4, o custo total estimado caiu de 14.111,01 para 9.925,37, e o tempo passou
de 22,333 para 15,321 ms. O índice parcial localizou os pedidos prontos por bitmap;
o anti-join manteve a busca pelo UNIQUE de `entrega.id_pedido`. O Sort continuou
necessário: a execução observada não usou Index Only Scan.

Custos do otimizador são unidades estimadas, não milissegundos. As estimativas
de cardinalidade ainda divergem das linhas reais. Uma execução por fase, caches
diferentes e uma base sintética não permitem generalizar os tempos. As duas
consultas ficaram mais rápidas nesta execução, com reduções proporcionais distintas
das reduções de custo estimado.

## Planos completos

Os arquivos `testes_logistica/atrasos.sql` e `fila_prontos.sql` repetem exatamente
as consultas L3 e L4, acrescentando `EXPLAIN ANALYZE` para reproduzir as duas fases.
As previsões são relativas ao instante da carga oficial; L3 usa o mesmo
CURRENT_TIMESTAMP da consulta entregue na seção 6. As duas fases devem ser
executadas em seguida para evitar mudanças de resultado pela passagem do tempo.

### L3 antes dos índices

```text
 Merge Join  (cost=10967.08..11183.64 rows=831 width=18) (actual time=18.745..21.949 rows=200.00 loops=1)
   Merge Cond: (en.id_pessoa = p.id_pessoa)
   Buffers: shared hit=4782 read=1015 written=94
   ->  Merge Semi Join  (cost=10966.81..11120.48 rows=831 width=16) (actual time=18.720..21.849 rows=200.00 loops=1)
         Merge Cond: (en.id_pessoa = r.id_entregador)
         Buffers: shared hit=4779 read=1010 written=94
         ->  Index Only Scan using entregador_pkey on entregador en  (cost=0.28..44.27 rows=1000 width=8) (actual time=0.011..0.061 rows=401.00 loops=1)
               Heap Fetches: 401
               Index Searches: 1
               Buffers: shared hit=3 read=3
         ->  Gather Merge  (cost=10966.53..11063.31 rows=831 width=8) (actual time=18.701..21.745 rows=400.00 loops=1)
               Workers Planned: 2
               Workers Launched: 2
               Buffers: shared hit=4776 read=1007 written=94
               ->  Sort  (cost=9966.51..9967.37 rows=346 width=8) (actual time=10.005..10.009 rows=133.33 loops=3)
                     Sort Key: r.id_entregador
                     Sort Method: quicksort  Memory: 25kB
                     Buffers: shared hit=4776 read=1007 written=94
                     Worker 0:  Sort Method: quicksort  Memory: 25kB
                     Worker 1:  Sort Method: quicksort  Memory: 25kB
                     ->  Nested Loop  (cost=0.42..9951.91 rows=346 width=8) (actual time=0.242..9.984 rows=133.33 loops=3)
                           Buffers: shared hit=4760 read=1007 written=94
                           ->  Parallel Seq Scan on entrega e  (cost=0.00..7808.65 rows=346 width=8) (actual time=0.226..9.808 rows=133.33 loops=3)
                                 Filter: ((status = ANY ('{aceita,a_caminho}'::status_entrega[])) AND (previsao_entrega < CURRENT_TIMESTAMP))
                                 Rows Removed by Filter: 166433
                                 Buffers: shared hit=3158 read=1007 written=94
                           ->  Index Scan using pk_rota on rota r  (cost=0.42..6.19 rows=1 width=16) (actual time=0.001..0.001 rows=1.00 loops=400)
                                 Index Cond: (id_rota = e.id_rota)
                                 Index Searches: 400
                                 Buffers: shared hit=1602
   ->  Index Scan using pessoa_pkey on pessoa p  (cost=0.28..50.27 rows=1000 width=18) (actual time=0.023..0.063 rows=400.00 loops=1)
         Index Searches: 1
         Buffers: shared hit=3 read=5
 Planning:
   Buffers: shared hit=85 read=22 dirtied=3 written=22
 Planning Time: 0.811 ms
 Execution Time: 21.980 ms
```

### L4 antes dos índices

```text
 Sort  (cost=14111.01..14111.01 rows=2 width=24) (actual time=18.650..22.304 rows=700.00 loops=1)
   Sort Key: p.data_pedido, p.id_pedido
   Sort Method: quicksort  Memory: 52kB
   Buffers: shared hit=11755 read=614 written=275
   ->  Gather  (cost=1000.42..14111.00 rows=2 width=24) (actual time=0.163..22.200 rows=700.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=11755 read=614 written=275
         ->  Nested Loop Anti Join  (cost=0.42..13110.80 rows=1 width=24) (actual time=0.059..10.601 rows=233.33 loops=3)
               Buffers: shared hit=11755 read=614 written=275
               ->  Parallel Seq Scan on pedido p  (cost=0.00..9271.17 rows=590 width=24) (actual time=0.033..9.002 rows=500.00 loops=3)
                     Filter: (status = 'pronto'::status_pedido)
                     Rows Removed by Filter: 166167
                     Buffers: shared hit=6667
               ->  Index Scan using uq_entrega_pedido on entrega e  (cost=0.42..6.50 rows=1 width=8) (actual time=0.003..0.003 rows=0.53 loops=1500)
                     Index Cond: (id_pedido = p.id_pedido)
                     Filter: (id_rota IS NOT NULL)
                     Rows Removed by Filter: 0
                     Index Searches: 1500
                     Buffers: shared hit=5088 read=614 written=275
 Planning:
   Buffers: shared hit=27 read=7
 Planning Time: 0.188 ms
 Execution Time: 22.333 ms
```

### L3 depois dos índices

```text
 Sort  (cost=6648.34..6650.42 rows=831 width=18) (actual time=0.960..0.968 rows=200.00 loops=1)
   Sort Key: en.id_pessoa
   Sort Method: quicksort  Memory: 32kB
   Buffers: shared hit=1814 read=11
   ->  Hash Join  (cost=63.70..6608.04 rows=831 width=18) (actual time=0.352..0.941 rows=200.00 loops=1)
         Hash Cond: (en.id_pessoa = p.id_pessoa)
         Buffers: shared hit=1814 read=11
         ->  Hash Right Semi Join  (cost=29.20..6571.35 rows=831 width=16) (actual time=0.155..0.717 rows=200.00 loops=1)
               Hash Cond: (r.id_entregador = en.id_pessoa)
               Buffers: shared hit=1808 read=5
               ->  Nested Loop  (cost=0.70..6532.98 rows=831 width=8) (actual time=0.016..0.526 rows=400.00 loops=1)
                     Buffers: shared hit=1804 read=3
                     ->  Index Scan using idx_entrega_ativa_previsao_pedido on entrega e  (cost=0.28..1385.42 rows=831 width=8) (actual time=0.013..0.161 rows=400.00 loops=1)
                           Index Cond: (previsao_entrega < CURRENT_TIMESTAMP)
                           Index Searches: 1
                           Buffers: shared hit=204 read=3
                     ->  Index Scan using pk_rota on rota r  (cost=0.42..6.19 rows=1 width=16) (actual time=0.001..0.001 rows=1.00 loops=400)
                           Index Cond: (id_rota = e.id_rota)
                           Index Searches: 400
                           Buffers: shared hit=1600
               ->  Hash  (cost=16.00..16.00 rows=1000 width=8) (actual time=0.137..0.137 rows=1000.00 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 48kB
                     Buffers: shared hit=4 read=2
                     ->  Seq Scan on entregador en  (cost=0.00..16.00 rows=1000 width=8) (actual time=0.003..0.058 rows=1000.00 loops=1)
                           Buffers: shared hit=4 read=2
         ->  Hash  (cost=22.00..22.00 rows=1000 width=18) (actual time=0.194..0.195 rows=1000.00 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 63kB
               Buffers: shared hit=6 read=6
               ->  Seq Scan on pessoa p  (cost=0.00..22.00 rows=1000 width=18) (actual time=0.004..0.113 rows=1000.00 loops=1)
                     Buffers: shared hit=6 read=6
 Planning:
   Buffers: shared hit=96 read=11
 Planning Time: 0.539 ms
 Execution Time: 0.992 ms
```

### L4 depois dos índices

```text
 Sort  (cost=9925.36..9925.37 rows=2 width=24) (actual time=13.336..15.290 rows=700.00 loops=1)
   Sort Key: p.data_pedido, p.id_pedido
   Sort Method: quicksort  Memory: 52kB
   Buffers: shared hit=6387 read=9
   ->  Gather  (cost=1048.14..9925.35 rows=2 width=24) (actual time=0.503..15.218 rows=700.00 loops=1)
         Workers Planned: 1
         Workers Launched: 1
         Buffers: shared hit=6387 read=9
         ->  Nested Loop Anti Join  (cost=48.14..8925.15 rows=1 width=24) (actual time=0.223..1.260 rows=350.00 loops=2)
               Buffers: shared hit=6387 read=9
               ->  Parallel Bitmap Heap Scan on pedido p  (cost=47.72..3497.60 rows=834 width=24) (actual time=0.221..0.403 rows=750.00 loops=2)
                     Recheck Cond: (status = 'pronto'::status_pedido)
                     Heap Blocks: exact=667
                     Buffers: shared hit=687 read=9
                     ->  Bitmap Index Scan on idx_pedido_pronto_fila  (cost=0.00..47.36 rows=1417 width=0) (actual time=0.347..0.347 rows=1500.00 loops=1)
                           Index Searches: 1
                           Buffers: shared read=9
               ->  Index Scan using uq_entrega_pedido on entrega e  (cost=0.42..6.50 rows=1 width=8) (actual time=0.001..0.001 rows=0.53 loops=1500)
                     Index Cond: (id_pedido = p.id_pedido)
                     Filter: (id_rota IS NOT NULL)
                     Rows Removed by Filter: 0
                     Index Searches: 1500
                     Buffers: shared hit=5700
 Planning:
   Buffers: shared hit=45 read=1
 Planning Time: 0.160 ms
 Execution Time: 15.321 ms
```
