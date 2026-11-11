# E6 — Índices e experimentos de Logística (card #18)

## Objetivo e escopo

Avaliar índices com duas consultas operacionais que cruzam `pedido`, mantendo PKs, UNIQUEs, FKs e CHECKs ativos. Referências: `docs/es/dicionario_dados.md`, `01_esquema_logistica.sql`, `04_consultas_logistica.sql`, `05_visoes_logistica.sql` e o contrato de carga de `explicacoes_logistica.md`. Nenhum desses arquivos é alterado por este trabalho.

`07_indices_logistica.sql` deve executar **uma vez**, após o esquema consolidado e a carga inicial. Os quatro índices usam nomes explícitos e transação; não usamos `IF NOT EXISTS`, pois um índice homônimo com definição divergente não deve ser silenciosamente aceito. Na integração, é preciso que `pedido` já exista com os campos e o enum documentados. `CREATE INDEX` convencional bloqueia escritas durante a construção: esta é uma migração para a etapa inicial, não uma receita de implantação sem interrupção em produção. Os índices não substituem gatilhos ou bloqueios de concorrência.

## Índices propostos e justificativas

| Índice | Tabela / colunas | Tipo e predicado | Consulta ou operação atendida |
| --- | --- | --- | --- |
| `idx_entrega_rota` | `entrega(id_rota)` | B-tree completo | Busca/contagem de entregas de uma rota na RN02; junção de rotas com vagas (L1) e painel operacional. Inclui entregas concluídas porque o limite considera o total por rota. Também auxilia a verificação da FK ao excluir/alterar uma rota. |
| `idx_rota_entregador` | `rota(id_entregador)` | B-tree completo | Consulta 15 e L3: localizar rotas de um entregador; também FK para entregador. Não é UNIQUE: o entregador mantém várias rotas históricas. |
| `idx_entrega_ativa_previsao_pedido` | `entrega(previsao_entrega, id_pedido)` | B-tree parcial: `status IN ('aceita', 'a_caminho')` | Q1: faixa temporal de entregas ativas atrasadas, seguida de junção com `pedido` e `loja`. O mesmo filtro temporal/estado aparece em L3. A segunda chave ordena os pedidos dentro de previsões iguais. Não se usa `CURRENT_TIMESTAMP` no predicado do índice, pois não é imutável. |
| `idx_pedido_pronto_fila` | `pedido(data_pedido, id_pedido) INCLUDE (id_loja)` | B-tree parcial: `status = 'pronto'` | Q2: reprodução da L4, fila global de pedidos prontos sem rota atribuída. A ordem das chaves corresponde ao `ORDER BY`; `id_loja` cobre a projeção, permitindo index-only scan quando o mapa de visibilidade permite. |

A alternativa `pedido(id_loja, data_pedido, id_pedido) WHERE status='pronto'` seria coerente para uma fila **por loja** com igualdade sobre `id_loja`. Não é a consulta existente, por isso a versão global foi escolhida; não se adicionam os dois índices sem uma necessidade demonstrada.

Não se recriam índices sobre `rota.id_rota`, `entrega.id_entrega`, `pedido.id_pedido` nem `entrega.id_pedido`: PKs/UNIQUE já os fornecem. A FK, sozinha, não cria índice na coluna de origem, justificando os dois índices de relacionamento. O índice parcial de entregas não substitui o UNIQUE em `id_pedido`: tem outro prefixo e só contém estados ativos.

Todos os índices têm custo de armazenamento, escrita e manutenção. Os parciais reduzem esse custo quando a maioria dos registros é histórica; mudanças de status inserem/removem entradas. Não se promete ganho para consultas que leem todo o histórico ou para tabelas pequenas. Os dois índices de relacionamento têm justificativa estrutural; este experimento não mede latência da RN02 nem atribui a eles o ganho das consultas Q1/Q2.

## Consultas avaliadas

- **Q1 — Atrasos por pedido e loja:** detalhe operacional da condição de L3, com `entrega JOIN pedido JOIN loja`, filtro por estados ativos e previsão vencida, ordenado por previsão/pedido. O instante de corte é um literal fixo para reproduzir os mesmos resultados em qualquer data. A previsão armazenada é um snapshot, não uma previsão calculada a partir de `pedido.data_pedido`.
- **Q2 — Fila de despacho:** mesma consulta L4 de `04_consultas_logistica.sql`, sem acrescentar filtro por loja, `LIMIT` ou hints. O `NOT EXISTS` cruza `pedido` com `entrega`; um pedido com entrega ainda sem rota deve continuar na fila. O UNIQUE existente em `entrega.id_pedido` atende a busca do anti-join.

As consultas completas e os quatro planos completos (antes/depois para cada consulta) aparecem nos resultados abaixo. `testes_logistica/resultados.json` preserva **todos os dez planos por fase** (cinco por consulta), tempos e checksums.

## Fixture e isolamento

Os auxiliares estão em `testes_logistica/`, fora do nível raiz percorrido pelo bootstrap do Docker de produção. O harness envia os arquivos explicitamente via stdin ao `psql`; não monta a pasta de SQL nem executa scripts automaticamente.

- `fixtures/dependencias.sql`: dependências reais em PostgreSQL, com todos os campos documentados de `pessoa`, `entregador`, `loja` e `pedido`; inclui `cliente`, `lojista`, `endereco`, `pessoa_endereco`, enums, identities, PKs, UNIQUEs, CHECKs e FKs relevantes. Cria 1.000 pessoas/entregadores, 100 lojas, um cliente, um lojista e um endereço. Uma pessoa pode ter vários papéis. CPF/CNPJ sintéticos só atendem o CHECK de formato; não pretendem passar a validação dos dígitos na aplicação.
- `../01_esquema_logistica.sql`: DDL real de Logística, carregado diretamente pelo bootstrap após as dependências. Define `status_entrega`, `rota` e `entrega`; não há cópia do esquema nas fixtures nem carregamento de gatilhos.
- Banco `funcional`: dependências + `01_esquema_logistica.sql` + seis pedidos externos nos estados exigidos + `02_carga_logistica.sql` oficial. Aplica os índices, executa `03_verificacao_logistica.sql`, confere as seis consultas e a visão oficiais. É separado do volume; o harness não mistura as duas cargas.
- Banco `volume`: dependências + `01_esquema_logistica.sql` + `fixtures/carga_volume.sql`. Carga determinística de 500.000 pedidos e 250.000 rotas. IDs de pedidos são gerados em ordem; lojas são distribuídas por blocos, evitando que todos os pedidos ativos se concentrem numa única loja. Cada par consecutivo de pedidos aponta à mesma rota, com exceção dos ainda sem atribuição; nenhuma rota tem mais de duas entregas.
- Pedidos cujo ID módulo 1.000 é 0, 1 ou 2 estão prontos. Os de resto 0 não têm entrega; os de resto 1 aguardam entregador, sem rota; os de resto 2 têm entrega ativa em rota aberta. Os demais estão concluídos e entregues. Metade das entregas ativas está antes do corte da Q1. As demais datas/previsões são valores fixos de snapshot, não um histórico de transições.

**Não se carrega nenhum `06_*`, script novo de gatilhos ou índice geral**. Essa base representa o snapshot de carga anterior aos gatilhos, assim como a carga funcional oficial; mantém as constraints declarativas e verifica que não existem gatilhos não internos e que nenhuma rota excede a capacidade. Não mede auditoria, transições, cálculo automático de previsão ou concorrência da RN02. A fixture é reutilizável para o recorte relevante, mas não substitui o esquema integrado dos demais subdomínios: catálogo, itens, finanças, auditoria e invariantes de gatilhos estão fora do benchmark. Após a integração, os testes precisam ser repetidos com o esquema final.

## Reprodução e metodologia

Requisitos: Docker acessível pelo usuário, imagem `postgres:18` (o Docker poderá baixá-la se ausente), Python 3 padrão, espaço/memória para a carga e nome `logistica-benchmark-test` livre. Não há dependência Python externa nem conexão de rede da aplicação. A senha é apenas do container descartável, sem porta publicada.

Na raiz do repositório:

```sh
python3 grupo10/sql/testes_logistica/benchmark.py
```

O harness:

1. Cria exclusivamente `logistica-benchmark-test`, sem volumes de desenvolvimento ou bind mounts, usando `tmpfs` em `/var/lib/postgresql`. Se o nome já existir, falha sem remover o container existente.
2. Aguarda a mensagem **`PostgreSQL init process complete; ready for start up.` nos logs e um `SELECT 1` bem-sucedido**. Não usa somente `pg_isready`, pois o servidor temporário do entrypoint poderia responder antes da inicialização definitiva.
3. Executa a validação funcional isolada, cria o banco de volume e executa `VACUUM (FREEZE, ANALYZE)` após a carga. Isso estabiliza a visibilidade para index-only scans e coleta estatísticas antes das duas fases. A construção de índices não muda os dados ou essas estatísticas; não há nova amostragem entre as fases.
4. Mede **antes** com os índices de PK/UNIQUE presentes, mas nenhum dos quatro novos índices. Para cada consulta verifica o resultado, faz um aquecimento e cinco `EXPLAIN (ANALYZE, BUFFERS, SETTINGS, SUMMARY, FORMAT TEXT)`.
5. Aplica exatamente `07_indices_logistica.sql` e repete o mesmo protocolo. Compara SHA-256 e número de linhas dos resultados ordenados, falhando se houver diferença. Não desabilita seqscan, paralelismo ou JIT, nem altera custos do planejador.
6. Substitui apenas a seção de resultados deste Markdown e `testes_logistica/resultados.json`; remove o container com `docker rm -f -v` em `finally`, inclusive em falhas após a criação. Uma interrupção que mate o próprio Python abruptamente pode exigir limpeza manual com o mesmo comando para esse nome exclusivo.

São medições locais com cache aquecido, sem concorrência, em tmpfs. As fases são sequenciais (antes e depois), não um ensaio randomizado de cache frio. O `VACUUM FREEZE` favorece cobertura por visibilidade, que pode ser menor numa fila com atualizações frequentes. A distribuição é sintética e seletiva, dominada por histórico; não extrapolar as razões para produção. Os tempos são os do executor do PostgreSQL com instrumentação, não a latência de rede/API. A primeira medição completa de cada fase é mostrada, **não** um plano inventado para representar a mediana; os cinco tempos sustentam a mediana apresentada. Tamanhos, versão, parâmetros e digest da imagem da execução estão registrados nos resultados. A tag 18 pode mudar: para repetir a mesma imagem, obtenha o digest registrado e use-o como `IMAGE` no harness.

## Interpretação dos planos e limites das conclusões

Na execução registrada, a Q1 substituiu `Parallel Seq Scan` sobre `entrega` por `Index Scan using idx_entrega_ativa_previsao_pedido`, mantendo as buscas pelas PKs de pedido e loja. A ordenação passou a ser atendida pela ordem do índice e das junções, sem o `Sort` anterior. A Q2 substituiu `Parallel Seq Scan` sobre `pedido` e a ordenação por `Index Only Scan using idx_pedido_pronto_fila`, com `Heap Fetches: 0`, conservando o anti-join apoiado no `uq_entrega_pedido` já existente. Os buffers e tempos completos constam abaixo.

Há erro de cardinalidade nos planos: a Q1 estima uma linha, mas retorna 250; o anti-join da Q2 também subestima o resultado. As estatísticas padrão não capturam bem a correlação entre estado, previsão e atribuição da carga sintética. Não foram adicionadas estatísticas estendidas ou ajustados parâmetros para fabricar um plano melhor. Essa limitação reforça a necessidade de repetir com distribuições reais, não apenas comparar custos estimados. Os ganhos observados são das duas consultas e do conjunto de índices, não uma demonstração de melhoria de cada índice individual nem de todas as operações do sistema.

## Resultados da execução real

Início (UTC): `2026-11-11T11:41:53.982725+00:00`.

### Validação funcional separada

Carga oficial: 3 rotas, 6 entregas; verificação oficial executada sem erro após criar os índices (cenários positivos e negativos, com rollback). Contagens das seis consultas: `[1, 1000, 1, 1, 1, 1]`; visão: 3 linhas. A fixture possui 1.000 entregadores, inclusive os IDs 1, 2 e 3 exigidos pela carga.

### Ambiente

Host: `Linux-7.0.0-42-generic-x86_64-with-glibc2.43`; arquitetura `x86_64`.

Imagem: `["postgres@sha256:e3d24f6906d0760bf4da0dae872415391ededefad23fd471c47dc53b0ddf3c42"]`. Armazenamento descartável em tmpfs; sem portas publicadas.

```text
PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
default_statistics_target=100
effective_cache_size=524288 8kB
enable_seqscan=on
jit=on
max_parallel_workers_per_gather=2
random_page_cost=4
seq_page_cost=1
shared_buffers=16384 8kB
work_mem=4096 kB
```

### Volume e tamanhos anteriores (tabela | heap | total com índices)

```text
rota|250000
entrega|499500
pedido pronto|1500
pedido|500000
entrega ativa|500
entrega|33 MB|54 MB
pedido|52 MB|79 MB
rota|14 MB|20 MB
```

### Resumo dos tempos do executor

Uma execução de aquecimento por consulta/fase, seguida de cinco medições. O checksum também executa a consulta antes do aquecimento. Tempos abaixo são `Execution Time`, sem o tempo de inicialização do cliente/docker. Resultados ordenados e SHA-256 idênticos antes/depois.

| Consulta | Linhas | Antes (ms, 5 execuções) | Depois (ms, 5 execuções) | Medianas antes/depois (ms) | Razão antes/depois |
| --- | ---: | --- | --- | --- | ---: |
| Q1 — Entregas ativas atrasadas por pedido e loja | 250 | [51.776, 45.349, 41.086, 44.831, 44.229] | [6.756, 7.281, 4.896, 6.722, 6.247] | 44.831 / 6.722 | 6.67x |
| Q2 — Fila global de pedidos prontos (L4) | 1000 | [50.052, 52.047, 45.902, 52.564, 43.091] | [7.177, 8.186, 11.285, 11.699, 7.776] | 50.052 / 8.186 | 6.11x |

### Índices criados (definição e tamanho real)

```text
idx_entrega_ativa_previsao_pedido|CREATE INDEX idx_entrega_ativa_previsao_pedido ON public.entrega USING btree (previsao_entrega, id_pedido) WHERE (status = ANY (ARRAY['aceita'::status_entrega, 'a_caminho'::status_entrega]))
idx_entrega_rota|CREATE INDEX idx_entrega_rota ON public.entrega USING btree (id_rota)
idx_pedido_pronto_fila|CREATE INDEX idx_pedido_pronto_fila ON public.pedido USING btree (data_pedido, id_pedido) INCLUDE (id_loja) WHERE (status = 'pronto'::status_pedido)
idx_rota_entregador|CREATE INDEX idx_rota_entregador ON public.rota USING btree (id_entregador)
idx_entrega_ativa_previsao_pedido|32 kB
idx_entrega_rota|9896 kB
idx_pedido_pronto_fila|80 kB
idx_rota_entregador|1800 kB
```

### Q1 — Entregas ativas atrasadas por pedido e loja

Fonte: `testes_logistica/atrasos.sql`.

```sql
SELECT
    e.id_entrega,
    e.previsao_entrega,
    p.id_pedido,
    p.id_loja,
    l.nome AS nome_loja,
    l.tempo_entrega_estimado
FROM entrega AS e
INNER JOIN pedido AS p ON p.id_pedido = e.id_pedido
INNER JOIN loja AS l ON l.id_loja = p.id_loja
WHERE e.status IN ('aceita', 'a_caminho')
  AND e.previsao_entrega < TIMESTAMPTZ '2026-02-01 12:00:00+00'
ORDER BY e.previsao_entrega, p.id_pedido;
```

SHA-256 do resultado psql ordenado: `bbae21530fda4b0dd245f725a14d36887691990fd5da6bfd1d7e58fe828489a1`.

#### Antes: plano completo da primeira medição

```text
Sort  (cost=8293.59..8293.59 rows=1 width=43) (actual time=48.061..51.599 rows=250.00 loops=1)
  Sort Key: e.previsao_entrega, p.id_pedido
  Sort Method: quicksort  Memory: 40kB
  Buffers: shared hit=5675
  ->  Nested Loop  (cost=1000.57..8293.58 rows=1 width=43) (actual time=0.910..51.168 rows=250.00 loops=1)
        Buffers: shared hit=5669
        ->  Nested Loop  (cost=1000.42..8293.42 rows=1 width=32) (actual time=0.889..49.903 rows=250.00 loops=1)
              Buffers: shared hit=5169
              ->  Gather  (cost=1000.00..8284.98 rows=1 width=24) (actual time=0.842..44.561 rows=250.00 loops=1)
                    Workers Planned: 2
                    Workers Launched: 2
                    Buffers: shared hit=4169
                    ->  Parallel Seq Scan on entrega e  (cost=0.00..7284.88 rows=1 width=24) (actual time=0.378..36.679 rows=83.33 loops=3)
                          Filter: ((status = ANY ('{aceita,a_caminho}'::status_entrega[])) AND (previsao_entrega < '2026-02-01 12:00:00+00'::timestamp with time zone))
                          Rows Removed by Filter: 166417
                          Buffers: shared hit=4169
              ->  Index Scan using pedido_pkey on pedido p  (cost=0.42..8.44 rows=1 width=16) (actual time=0.019..0.019 rows=1.00 loops=250)
                    Index Cond: (id_pedido = e.id_pedido)
                    Index Searches: 250
                    Buffers: shared hit=1000
        ->  Index Scan using loja_pkey on loja l  (cost=0.14..0.16 rows=1 width=19) (actual time=0.003..0.003 rows=1.00 loops=250)
              Index Cond: (id_loja = p.id_loja)
              Index Searches: 250
              Buffers: shared hit=500
Planning:
  Buffers: shared hit=265
Planning Time: 1.822 ms
Execution Time: 51.776 ms
```

#### Depois: plano completo da primeira medição

```text
Nested Loop  (cost=0.84..16.89 rows=1 width=43) (actual time=0.087..6.566 rows=250.00 loops=1)
  Buffers: shared hit=1752
  ->  Nested Loop  (cost=0.70..16.73 rows=1 width=32) (actual time=0.066..5.777 rows=250.00 loops=1)
        Buffers: shared hit=1252
        ->  Index Scan using idx_entrega_ativa_previsao_pedido on entrega e  (cost=0.27..8.29 rows=1 width=24) (actual time=0.041..1.978 rows=250.00 loops=1)
              Index Cond: (previsao_entrega < '2026-02-01 12:00:00+00'::timestamp with time zone)
              Index Searches: 1
              Buffers: shared hit=252
        ->  Index Scan using pedido_pkey on pedido p  (cost=0.42..8.44 rows=1 width=16) (actual time=0.014..0.014 rows=1.00 loops=250)
              Index Cond: (id_pedido = e.id_pedido)
              Index Searches: 250
              Buffers: shared hit=1000
  ->  Index Scan using loja_pkey on loja l  (cost=0.14..0.16 rows=1 width=19) (actual time=0.002..0.002 rows=1.00 loops=250)
        Index Cond: (id_loja = p.id_loja)
        Index Searches: 250
        Buffers: shared hit=500
Planning:
  Buffers: shared hit=319
Planning Time: 2.462 ms
Execution Time: 6.756 ms
```

### Q2 — Fila global de pedidos prontos (L4)

Fonte: `testes_logistica/fila_prontos.sql`.

```sql
SELECT
    p.id_pedido,
    p.id_loja,
    p.data_pedido
FROM pedido AS p
WHERE p.status = 'pronto'
  AND NOT EXISTS (
      SELECT 1
      FROM entrega AS e
      WHERE e.id_pedido = p.id_pedido
        AND e.id_rota IS NOT NULL
  )
ORDER BY p.data_pedido, p.id_pedido;
```

SHA-256 do resultado psql ordenado: `1ad7b393acbd09b2ff54c70359cf22bd87702b421278eaf3ca367f423857cf3a`.

#### Antes: plano completo da primeira medição

```text
Gather Merge  (cost=14110.83..14111.07 rows=2 width=24) (actual time=43.671..49.798 rows=1000.00 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=12201
  ->  Sort  (cost=13110.81..13110.81 rows=1 width=24) (actual time=36.091..36.132 rows=333.33 loops=3)
        Sort Key: p.data_pedido, p.id_pedido
        Sort Method: quicksort  Memory: 47kB
        Buffers: shared hit=12201
        Worker 0:  Sort Method: quicksort  Memory: 38kB
        Worker 1:  Sort Method: quicksort  Memory: 28kB
        ->  Nested Loop Anti Join  (cost=0.42..13110.80 rows=1 width=24) (actual time=0.262..35.826 rows=333.33 loops=3)
              Buffers: shared hit=12169
              ->  Parallel Seq Scan on pedido p  (cost=0.00..9271.17 rows=590 width=24) (actual time=0.213..31.189 rows=500.00 loops=3)
                    Filter: (status = 'pronto'::status_pedido)
                    Rows Removed by Filter: 166167
                    Buffers: shared hit=6667
              ->  Index Scan using uq_entrega_pedido on entrega e  (cost=0.42..6.50 rows=1 width=8) (actual time=0.008..0.008 rows=0.33 loops=1500)
                    Index Cond: (id_pedido = p.id_pedido)
                    Filter: (id_rota IS NOT NULL)
                    Rows Removed by Filter: 0
                    Index Searches: 1500
                    Buffers: shared hit=5502
Planning:
  Buffers: shared hit=178
Planning Time: 1.601 ms
Execution Time: 50.052 ms
```

#### Depois: plano completo da primeira medição

```text
Nested Loop Anti Join  (cost=0.70..9283.15 rows=3 width=24) (actual time=0.076..7.068 rows=1000.00 loops=1)
  Buffers: shared hit=5510
  ->  Index Only Scan using idx_pedido_pronto_fila on pedido p  (cost=0.28..61.53 rows=1417 width=24) (actual time=0.038..0.296 rows=1500.00 loops=1)
        Heap Fetches: 0
        Index Searches: 1
        Buffers: shared hit=10
  ->  Index Scan using uq_entrega_pedido on entrega e  (cost=0.42..6.50 rows=1 width=8) (actual time=0.004..0.004 rows=0.33 loops=1500)
        Index Cond: (id_pedido = p.id_pedido)
        Filter: (id_rota IS NOT NULL)
        Rows Removed by Filter: 0
        Index Searches: 1500
        Buffers: shared hit=5500
Planning:
  Buffers: shared hit=236
Planning Time: 1.818 ms
Execution Time: 7.177 ms
```
