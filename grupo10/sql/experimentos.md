# E6 — Experimentos e Leitura do Plano de Execução (Seção 8.2)

## 1. Objetivo e Ambiente de Reprodução

Avaliar o impacto dos índices secundários definidos em `07_indices.sql` sobre a **base oficial consolidada da E4** (`01_esquema.sql` + `02_carga.sql`) no PostgreSQL 18 (Docker), comparando os planos de execução via `EXPLAIN (ANALYZE, BUFFERS)` **antes** e **depois** da criação dos índices e após `ANALYZE`.

- **Volume da base oficial (`02_carga.sql`):**
  - `entrega`: **51.315** linhas
  - `rota`: **14.366** linhas
  - `telefone`: **495** linhas
  - `pessoa`: **300** linhas

---

## 2. Resumo Comparativo (Base Oficial E4)

| Consulta | Linhas na tabela | Tempo sem índice | Tempo com índice | Operação antes | Operação depois |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Consulta 9 (entregadores com entregas ativas atrasadas) | `entrega`: 51.315 / `rota`: 14.366 | 4,276 ms | 1,098 ms | Seq Scan em `entrega` | Bitmap Index Scan (`idx_entrega_ativa_previsao_pedido`) + Bitmap Heap Scan em `entrega` |
| Consulta logística (rotas e entregas do entregador 101) | `entrega`: 51.315 / `rota`: 14.366 | 3,806 ms | 0,377 ms | Seq Scan em `rota` e `entrega` (Hash Join) | Bitmap Index Scan (`idx_rota_entregador`) + Index Scan (`idx_entrega_rota`) (Nested Loop) |
| Consulta de teste — índice não utilizado (`telefone` por `tipo = 'celular'`) | `telefone`: 495 | 0,065 ms | 0,062 ms | Seq Scan em `telefone` | Seq Scan em `telefone` (`idx_telefone_tipo` ignorado) |

---

## 3. Análise dos Planos de Execução

### 3.1 Consulta 9 — Entregadores com entregas ativas atrasadas (Logística)

- **Índice envolvido:** `idx_entrega_ativa_previsao_pedido` (parcial em `entrega(previsao_entrega, id_pedido) WHERE status IN ('aceita', 'a_caminho')`).
- **O que mudou no plano:**
  - **Antes:** `Seq Scan on entrega e` (custo estimado `0.00..1305.01`, `actual time=0.102..2.919 ms`) percorrendo todas as 51.315 linhas de `entrega`. Custo total da consulta: `1683.32`, tempo real: `4,276 ms`.
  - **Depois:** `Bitmap Index Scan on idx_entrega_ativa_previsao_pedido` + `Bitmap Heap Scan on entrega e` (custo estimado do nó `9.60..343.47`, `actual time=0.010..0.022 ms`, apenas 192 linhas lidas). Custo total da consulta: `721.74`, tempo real: `1,098 ms`.
- **Custo estimado vs. tempo real:** O custo estimado caiu ~57% (de `1683.32` para `721.74`) e o tempo real caiu ~74% (de `4,276 ms` para `1,098 ms`), pois o índice parcial evitou a varredura completa de `entrega`.

```text
-- ANTES (trecho principal em entrega):
Seq Scan on entrega e  (cost=0.00..1305.01 rows=190 width=8) (actual time=0.102..2.919 rows=192.00 loops=1)
Execution Time: 4.276 ms

-- DEPOIS (trecho principal em entrega):
Bitmap Heap Scan on entrega e  (cost=9.60..343.47 rows=188 width=8) (actual time=0.010..0.022 rows=192.00 loops=1)
  ->  Bitmap Index Scan on idx_entrega_ativa_previsao_pedido  (cost=0.00..9.56 rows=188 width=0) (actual time=0.005..0.005 rows=192.00 loops=1)
Execution Time: 1.098 ms
```

---

### 3.2 Consulta de Logística — Rotas e entregas de um entregador (Logística)

- **Consulta medida:**
  ```sql
  SELECT r.id_rota, e.id_entrega, e.status
    FROM rota r
  INNER JOIN entrega e ON e.id_rota = r.id_rota
   WHERE r.id_entregador = 101
   ORDER BY r.id_rota, e.id_entrega;
  ```
- **Índices envolvidos:** `idx_rota_entregador` em `rota(id_entregador)` e `idx_entrega_rota` em `entrega(id_rota)`.
- **O que mudou no plano:**
  - **Antes:** `Seq Scan on rota r` + `Seq Scan on entrega e` combinados por `Hash Join` (lendo todas as 14.366 rotas e todas as 51.315 entregas). Custo total: `1361.55`, tempo real: `3,806 ms`.
  - **Depois:** `Bitmap Index Scan using idx_rota_entregador` (119 rotas do entregador) combinado via `Nested Loop` com `Index Scan using idx_entrega_rota` (2 entregas por rota, 238 linhas no total). Custo total: `886.49`, tempo real: `0,377 ms`.
- **Custo estimado vs. tempo real:** O custo estimado reduziu ~35% (`1361.55` para `886.49`), enquanto o tempo real caiu ~90% (`3,806 ms` para `0,377 ms` — cerca de 10x mais rápido), pois o `Nested Loop` indexado acessa diretamente apenas as páginas das 119 rotas e 238 entregas do entregador.

```text
-- ANTES:
Sort  (cost=1360.49..1361.55 rows=425 width=20) (actual time=3.783..3.789 rows=238.00 loops=1)
  ->  Hash Join  (cost=287.06..1341.94 rows=425 width=20) (actual time=0.421..3.765 rows=238.00 loops=1)
        ->  Seq Scan on entrega e  (cost=0.00..920.15 rows=51315 width=20) (actual time=0.002..1.514 rows=51315.00 loops=1)
        ->  Hash  (cost=285.58..285.58 rows=119 width=8) (actual time=0.393..0.393 rows=119.00 loops=1)
              ->  Seq Scan on rota r  (cost=0.00..285.58 rows=119 width=8) (actual time=0.008..0.382 rows=119.00 loops=1)
Execution Time: 3.806 ms

-- DEPOIS:
Sort  (cost=885.42..886.49 rows=425 width=20) (actual time=0.356..0.362 rows=238.00 loops=1)
  ->  Nested Loop  (cost=5.50..866.87 rows=425 width=20) (actual time=0.045..0.337 rows=238.00 loops=1)
        ->  Bitmap Heap Scan on rota r  (cost=5.21..117.81 rows=119 width=8) (actual time=0.040..0.091 rows=119.00 loops=1)
              ->  Bitmap Index Scan on idx_rota_entregador  (cost=0.00..5.18 rows=119 width=0) (actual time=0.030..0.030 rows=119.00 loops=1)
        ->  Index Scan using idx_entrega_rota on entrega e  (cost=0.29..6.27 rows=2 width=20) (actual time=0.002..0.002 rows=2.00 loops=119)
Execution Time: 0.377 ms
```

---

### 3.3 Caso em que o índice criado NÃO é utilizado (Identidade e Contato)

- **Consulta medida:**
  ```sql
  SELECT id_pessoa, numero
    FROM telefone
   WHERE tipo = 'celular';
  ```
- **Índice existente:** `idx_telefone_tipo` em `telefone USING btree (tipo)`.
- **Comportamento observado:** Tanto antes quanto depois da criação do índice, o otimizador escolheu **`Seq Scan on telefone`** (custo estimado `0.00..10.19`, tempo real `0,065 ms` antes e `0,062 ms` depois — variação normal de execução).
- **Justificativa técnica:** A coluna `tipo` possui baixa seletividade (apenas 3 valores possíveis), e `'celular'` representa **300 das 495 linhas** (~60,6% da tabela). Além disso, a tabela cabe em poucas páginas de disco; ler o índice e depois acessar quase todas as páginas da tabela aleatoriamente seria mais custoso do que uma única varredura sequencial (`Seq Scan`). Com base nas estatísticas coletadas pelo `ANALYZE`, o otimizador descarta `idx_telefone_tipo`.
