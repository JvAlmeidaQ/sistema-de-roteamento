# E6 — Experimentos e Leitura do Plano de Execução (Seção 8.2)

## 1. Objetivo e Ambiente de Reprodução

Avaliar o impacto dos índices secundários definidos em `07_indices.sql` sobre a **base oficial consolidada da E4** (`01_esquema.sql` + `02_carga.sql`) no PostgreSQL 18 (Docker), comparando os planos de execução via `EXPLAIN (ANALYZE, BUFFERS)` **antes** e **depois** da criação dos índices e após `ANALYZE`.

- **Volume da base oficial (`02_carga.sql`):**
  - `historico_pedido`: **656.757** linhas
  - `pedido`: **200.000** linhas
  - `historico_entrega`: **137.220** linhas
  - `entrega`: **51.315** linhas
  - `rota`: **14.366** linhas
  - `telefone`: **495** linhas
  - `pessoa`: **300** linhas

---

## 2. Resumo Comparativo (Base Oficial E4)

| Consulta | Linhas na tabela | Tempo sem índice | Tempo com índice | Operação antes | Operação depois |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Consulta 5 (lojas com pedidos concluídos em todas as formas de pagamento — Comércio e Finanças) | `pedido`: 200.000 | 44,172 ms | 3,538 ms | Parallel Seq Scan + Seq Scan em `pedido` | Index Only Scan (`idx_pedido_concluido_loja_forma`) em `pedido` |
| Consulta 9 (pedido concluído de maior valor total — Comércio e Finanças) | `pedido`: 200.000 | 282,066 ms | 206,142 ms | Parallel Index Scan (`pk_pedido`) + Seq Scan em `pedido p2` | Bitmap Index Scan + Index Only Scan (`idx_pedido_concluido_valor_total`) |
| Consulta 17 (entregadores com entregas ativas atrasadas — Logística) | `entrega`: 51.315 / `rota`: 14.366 | 5,384 ms | 2,644 ms | Seq Scan em `entrega` | Bitmap Index Scan (`idx_entrega_ativa_previsao_pedido`) + Bitmap Heap Scan em `entrega` |
| Consulta 20 (pedidos aceitos sem registro de pagamento — Auditoria) | `historico_pedido`: 656.757 | 72,005 ms | 61,438 ms | Parallel Seq Scan em `historico_pedido` (`hp_pago`) | Bitmap Index Scan (`idx_historico_pedido_status_data_hora`) + Parallel Bitmap Heap Scan |
| Consulta 21 (entregas concluídas após a previsão — Auditoria) | `historico_entrega`: 137.220 / `entrega`: 51.315 | 14,705 ms | 12,189 ms | Seq Scan em `historico_entrega` | Bitmap Index Scan (`idx_historico_entrega_status_data_hora`) + Bitmap Heap Scan |
| Consulta de teste — índice não utilizado (`telefone` por `tipo = 'celular'` — Identidade) | `telefone`: 495 | 0,269 ms | 0,065 ms | Seq Scan em `telefone` | Seq Scan em `telefone` (`idx_telefone_tipo` ignorado) |

---

## 3. Análise dos Planos de Execução

### 3.1 Consulta 5 — Lojas com pedidos concluídos em todas as formas de pagamento (Comércio e Finanças)

- **Índice envolvido:** `idx_pedido_concluido_loja_forma` (parcial em `pedido(id_loja, forma_pagamento) WHERE status = 'concluido'`).
- **O que mudou no plano:**
  - **Antes:** `Parallel Seq Scan on pedido` para listar as formas de pagamento distintas e `Seq Scan on pedido p` repetido no `Nested Loop Anti Join` para cada loja/forma. Custo total estimado: `33330.27`, tempo real: `44,172 ms`.
  - **Depois:** `Index Only Scan using idx_pedido_concluido_loja_forma` tanto para o levantamento das formas distintas quanto para o anti-join por `(id_loja, forma_pagamento)`, sem acessar o heap de `pedido`. Custo total estimado: `753.78`, tempo real: `3,538 ms`.
- **Custo estimado vs. tempo real:** O custo estimado caiu ~97,7% (de `33330.27` para `753.78`) e o tempo real caiu ~92% (de `44,172 ms` para `3,538 ms` — cerca de 12,5x mais rápido), refletindo diretamente a eliminação das varreduras sequenciais sobre os 200.000 pedidos.

```text
-- ANTES:
Nested Loop Anti Join  (cost=5541.54..33330.27 rows=60 width=44) (actual time=43.942..44.109 rows=90.00 loops=1)
  ...
  -> Parallel Seq Scan on pedido  (cost=0.00..4499.59 rows=16686 width=4)
  -> Seq Scan on pedido p  (cost=0.00..5529.00 rows=28367 width=12)
Execution Time: 44.172 ms

-- DEPOIS:
Sort  (cost=753.63..753.78 rows=60 width=44) (actual time=3.449..3.454 rows=90.00 loops=1)
  -> Nested Loop Anti Join  (cost=607.07..751.86 rows=60 width=44)
       -> Index Only Scan using idx_pedido_concluido_loja_forma on pedido  (cost=0.29..536.38 rows=28273 width=4)
       -> Index Only Scan using idx_pedido_concluido_loja_forma on pedido p  (cost=0.29..9.87 rows=79 width=0)
Execution Time: 3.538 ms
```

---

### 3.2 Consulta 9 — Pedido concluído de maior valor total (Comércio e Finanças)

- **Índice envolvido:** `idx_pedido_concluido_valor_total` (parcial em `pedido(valor_total DESC) WHERE status = 'concluido'`).
- **O que mudou no plano:**
  - **Antes:** `Parallel Index Scan using pk_pedido` combinado com `Seq Scan on pedido p2` (custo total estimado `4749918.90`, tempo real `282,066 ms`).
  - **Depois:** `Parallel Bitmap Heap Scan` (via `idx_pedido_concluido_loja_forma`) + `Index Only Scan using idx_pedido_concluido_valor_total on pedido p2` com `Index Cond: (valor_total > p1.valor_total)` (custo total estimado `12463.87`, tempo real `206,142 ms`).
- **Custo estimado vs. tempo real:** O custo estimado caiu ~99,7% (de `4.749.918,90` para `12.463,87`), enquanto o tempo real caiu ~27% (`282,066 ms` para `206,142 ms`). A diferença proporcional ocorre porque, embora o `NOT EXISTS` pare no primeiro valor maior encontrado pelo índice, ele ainda é avaliado para os 28.539 pedidos concluídos da relação externa (`loops=28539`).

---

### 3.3 Consulta 17 — Entregadores com entregas ativas atrasadas (Logística)

- **Índice envolvido:** `idx_entrega_ativa_previsao_pedido` (parcial em `entrega(previsao_entrega, id_pedido) WHERE status IN ('aceita', 'a_caminho')`).
- **O que mudou no plano:**
  - **Antes:** `Seq Scan on entrega e` (custo estimado `0.00..1305.01`, `actual time=0.117..3.469 ms`) percorrendo todas as 51.315 linhas de `entrega`. Custo total: `1683.78`, tempo real: `5,384 ms`.
  - **Depois:** `Bitmap Index Scan on idx_entrega_ativa_previsao_pedido` + `Bitmap Heap Scan on entrega e` (custo estimado do nó `9.75..359.33`, `actual time=0.021..0.042 ms`, apenas 192 linhas lidas). Custo total: `738.00`, tempo real: `2,644 ms`.
- **Custo estimado vs. tempo real:** O custo estimado reduziu ~56% (`1683.78` para `738.00`) e o tempo real reduziu ~51% (`5,384 ms` para `2,644 ms`).

---

### 3.4 Consultas 20 e 21 — Trilha Cronológica e SLA de Entregas (Auditoria)

- **Índices envolvidos:** `idx_historico_pedido_status_data_hora` em `historico_pedido(status, data_hora)` e `idx_historico_entrega_status_data_hora` em `historico_entrega(status, data_hora)`.
- **O que mudou no plano:**
  - **Consulta 20 (`historico_pedido`: 656.757 linhas):** antes realizava `Parallel Seq Scan` em `historico_pedido` para ambos os lados do anti-join (`72,005 ms`, custo `28961.24`). Com o índice, a leitura de `hp_pago` passou para `Bitmap Index Scan using idx_historico_pedido_status_data_hora` + `Parallel Bitmap Heap Scan` (`61,438 ms`, custo `28777.46`).
  - **Consulta 21 (`historico_entrega`: 137.220 linhas):** antes executava `Seq Scan on historico_entrega he` (`14,705 ms`, custo `4749.62`). Com o índice, mudou para `Bitmap Index Scan using idx_historico_entrega_status_data_hora` + `Bitmap Heap Scan` (`12,189 ms`, custo `4061.41`).
- **Custo estimado vs. tempo real:** como os filtros `status = 'pago'` (114.062 linhas) e `status = 'entregue'` (28.539 linhas) selecionam uma fração significativa das tabelas históricas, o otimizador escolhe `Bitmap Index Scan` em vez de `Index Scan` puro, reduzindo o tempo real em ~15% e ~17%, respectivamente.

---

### 3.5 Caso em que o índice criado NÃO é utilizado (Identidade e Contato)

- **Consulta medida:**
  ```sql
  SELECT id_pessoa, numero
    FROM telefone
   WHERE tipo = 'celular';
  ```
- **Índice existente:** `idx_telefone_tipo` em `telefone USING btree (tipo)`.
- **Comportamento observado:** Tanto antes quanto depois da criação do índice, o otimizador escolheu **`Seq Scan on telefone`** (custo estimado `0.00..10.19`, tempo real `0,269 ms` antes e `0,065 ms` depois — diferença decorrente apenas de cache e variação de execução).
- **Justificativa técnica:** A coluna `tipo` possui baixa seletividade (apenas 3 valores possíveis), e `'celular'` representa **300 das 495 linhas** (~60,6% da tabela). Como a tabela ocupa poucas páginas em disco, ler o índice e depois visitar praticamente todas as páginas da tabela aleatoriamente seria mais caro do que uma única varredura sequencial (`Seq Scan`). Com base nas estatísticas coletadas pelo `ANALYZE`, o otimizador descarta `idx_telefone_tipo`.
