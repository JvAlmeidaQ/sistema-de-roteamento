# CLAUDE.local.md — Sistema de Roteamento de Pedidos

Instruções pessoais (não versionadas) para o Claude Code neste repositório.

## Visão geral
- Projeto integrado **DCC060 (Banco de Dados)** + **DCC061 (Engenharia de Software)** — UFJF, **grupo 10**.
- Plataforma de entregas locais: **Cliente** faz pedidos em lojas do **Lojista**; **Entregador** entrega
  em **Rotas** (máx. 2 entregas por rota — ADR-005).
- Responda, escreva documentação e mensagens de commit em **português do Brasil**.

## Estrutura
- `grupo10/` — tudo que vai no zip de entrega. A estrutura é imposta pelo edital de BD: **não renomear nem mover** arquivos.
  - `grupo10/sql/01_esquema.sql` … `07_indices.sql` — executados **em ordem numérica**; cada um depende dos anteriores.
  - `grupo10/sql/experimentos.md` — registro de experimentos (índices/desempenho).
  - `grupo10/algebra/consultas_ar.md` — consultas em álgebra relacional (E3).
  - `Relatorio_grupo10.pdf`, `der.png`, `modelo_sistema_roteamento.drawio` — artefatos já entregues; não alterar sem pedido explícito.
- `docs/es/` — documentação de Engenharia de Software (ver "Fontes da verdade").
- `backend/` (Spring Boot + jOOQ) e `frontend/` (React + Zod) — ainda ignorados no `.gitignore`; entram em fases futuras.
- `PROJECT_MANAGEMENT.md` — cronograma (E0–E6, Marcos ES), DoR/DoD, branches e versionamento. Consulte lá os prazos; não duplicar aqui.

## Fontes da verdade (consultar antes de escrever SQL ou código)
- `docs/es/glossario_de_dominio.md` — use exatamente esses termos de negócio.
- `docs/es/dicionario_dados.md` — tabelas, colunas, tipos e chaves.
- `docs/es/especificacao_validacoes.md` — RN01–RN13, RR01–RR19, camada de cada regra (DDL/gatilho/aplicação) e contrato SQLSTATE → HTTP.
- `docs/es/adrs/` — ADR-001 a ADR-006 (FKs compostas de loja, snapshots imutáveis, especialização de pessoa, histórico de status, rotas, modelo financeiro).
- Ao criar ou alterar um artefato, atualize `docs/es/matriz_rastreabilidade.md` (DoD 4.1).
- Se o código divergir desses documentos, aponte a divergência em vez de escolher um lado em silêncio.

## Banco local (PostgreSQL 18 via Docker)
```bash
cp .env.example .env                                   # só na primeira vez
docker compose -f docker/docker-compose.yml up -d      # sobe o container postgres-dev

# rodar um script específico (grupo10/sql está montado em /docker-entrypoint-initdb.d)
docker exec -it postgres-dev psql -U sistemaRoteamento -d roteamento_db \
  -v ON_ERROR_STOP=1 -f /docker-entrypoint-initdb.d/01_esquema.sql

# recriar do zero (roda todos os scripts em sequência) — APAGA os dados locais
docker compose -f docker/docker-compose.yml down -v && docker compose -f docker/docker-compose.yml up -d

# shell interativo
docker exec -it postgres-dev psql -U sistemaRoteamento -d roteamento_db
```
- Em comandos não interativos (rodados pelo Claude), use `docker exec` **sem** `-it`.
- Peça confirmação antes de `down -v`.

## Regras para SQL
- Alvo: **PostgreSQL 18**. Todo script precisa rodar do zero, num banco vazio, com `ON_ERROR_STOP=1`.
- O CI (`.github/workflows/ci.yml`) valida `01_esquema`, `02_carga` e `03_verificacao` em PRs para `develop`/`main`; falha se o arquivo estiver vazio.
- Carga (E4): no mínimo **200 mil linhas** no total, verificadas em `03_verificacao.sql`.
- Valide localmente antes de considerar uma tarefa SQL concluída.

## Git
- Fluxo: `feature/<tarefa>` criada a partir de `develop` → PR para `develop`. `main`, `main-bd` e `release/*` só recebem merges de entrega.
- Mensagem de commit: `tipo(escopo): descrição [#CARD-XX]` (ex.: `feat(ddl): implementa constraints de preco_unitario [#CARD-08]`).
- **Não** adicione `Co-Authored-By: Claude` nem outra atribuição de IA em commits ou PRs.
- Só faça commit ou push quando eu pedir. Nunca commite `.env` ou `*.zip`.

## Entrega
- `./package.sh` gera `grupo10.zip` (submissão de BD). Releases seguem `vX.Y.Z-<bd|es>-<marco>` (ver `PROJECT_MANAGEMENT.md` §5).

## Entrega 4 (E4) — Planejamento: Identidade e Contato (issue #15, prazo 14/11)
### Contexto
Sua parte da E4 é o subdomínio **Identidade e Contato**: tabelas `pessoa`, `cliente`, `lojista`,
`entregador`, `telefone`, `endereco` e `pessoa_endereco`. Você quer **aprender fazendo**, então este
plano diz *o que* fazer, *o que estudar* e *como conferir*. Você escreve o SQL, e eu explico,
dou dicas e reviso o que você fizer (só escrevo código se você pedir).

Fontes que valem como regra (já li e resumi abaixo):
- Professor: scripts em PG ≥ 14, executados em ordem a partir de um banco vazio; PK, FK **com ação
  referencial**, NOT NULL, UNIQUE e CHECK no DDL; `ANALYZE` no fim da carga; cada teste do 03 com
  comentário dizendo **regra da Seção 2 + resultado esperado + mensagem de erro do SGBD**.
- Issue #15: arquivos-fragmento `*_identidade_contato.sql`, carga **pequena** (100–1.000 linhas).
  Os 200 mil ficam numa tabela de experimentos (Pedido/Histórico), sob responsabilidade de outro subdomínio.
- `docs/es/dicionario_dados.md` §2.1 (colunas e tipos), `matriz_rastreabilidade.md` (RN10, RR14, RR12, RR01, RR16, RR17), ADR-002 e ADR-003.
- Referência de estilo: a branch `origin/feature/logistica` (PR #26), com `BEGIN;` … `COMMIT;`,
  constraints nomeadas (`pk_`, `fk_`, `uq_`, `ck_`) e `ON UPDATE/ON DELETE` explícitos.
  Use `git show origin/feature/logistica:grupo10/sql/01_esquema_logistica.sql`.

### Etapa 0 — Preparação (15 min)
- `git switch feature/identidade` (já está nela) e `git pull origin develop` para ficar atualizado.
- Subir o banco: `cp .env.example .env` e depois `docker compose -f docker/docker-compose.yml up -d`.
- Criar os arquivos em `grupo10/sql/`: `01_esquema_identidade_contato.sql`,
  `02_carga_identidade_contato.sql` e `03_verificacao_identidade_contato.sql`.
- **Estudar:** como rodar um arquivo com `psql -v ON_ERROR_STOP=1 -f` (o comando está no README).

### Etapa 1 — `01_esquema_identidade_contato.sql` (DDL) (~2–3 h)
**Ordem de criação** (uma tabela só pode referenciar outra que já existe):
1. ENUMs `tipo_telefone` e `tipo_veiculo`
2. `pessoa`, depois `endereco`
3. `telefone` e `pessoa_endereco`
4. `cliente` (depende de `pessoa_endereco`), `lojista` e `entregador`

**Restrições que cada tabela precisa ter** (do dicionário de dados):
| Tabela | O que declarar |
|---|---|
| pessoa | PK identity; `cpf` UNIQUE + CHECK regex 11 dígitos (RN10/RR14); `email` UNIQUE; NOT NULL |
| endereco | PK identity; CHECK `cep` 8 dígitos e `estado` 2 letras maiúsculas (RR14); UNIQUE `(logradouro, numero, cep)` |
| telefone | PK composta `(id_pessoa, numero)`; FK → pessoa |
| pessoa_endereco | PK composta; FK → pessoa e FK → endereco |
| cliente | PK = FK → pessoa; **FK composta** `(id_pessoa, id_endereco_atual)` → `pessoa_endereco` (ADR-002) |
| lojista | PK = FK → pessoa |
| entregador | PK = FK → pessoa; `tipo_veiculo` NOT NULL |

**Decisões para você tomar e justificar** (vão para o relatório):
- **Ação referencial de cada FK.** Pergunta-guia: "se eu apagar a pessoa, o que deve acontecer com
  isto?". Telefone é entidade fraca (CASCADE faz sentido?). E Endereco usado por um pedido?
  (RESTRICT, pela ADR-002.)
- **CHECKs extras que valem a pena:** nome não vazio (`btrim(nome) <> ''`)? E-mail com `@`?
- **Armadilha para estudar:** na FK composta de `cliente`, `ON DELETE SET NULL` sem lista de
  colunas anularia também o `id_pessoa`, que é PK. O PG 15+ aceita `SET NULL (id_endereco_atual)`,
  mas o professor pede compatibilidade com PG 14. Avalie RESTRICT/NO ACTION.
- **Ficam fora do E4** (são gatilhos, E6): RR12 (endereço imutável), RR01, RR16 e RR17 (cardinalidade mínima).
  Só anote isso num comentário.

**Estudar:** `CREATE TYPE … AS ENUM`, `GENERATED ALWAYS AS IDENTITY`, `CONSTRAINT … CHECK (col ~ '^[0-9]{11}$')`,
FK composta, `MATCH SIMPLE` (por que um `id_endereco_atual` NULL não é checado), diferença entre `RESTRICT` e `NO ACTION`.

**Checkpoint:** rode o arquivo num banco limpo, depois `\d pessoa` e `\d cliente` no psql, e me
mostre o resultado para revisão.

### Etapa 2 — `02_carga_identidade_contato.sql` (~1,5 h)
- Volume pequeno (~200 a 1.000 pessoas), gerado com `generate_series()` em vez de digitar linha por linha.
- CPFs únicos de 11 dígitos: `lpad(n::text, 11, '0')`. Atenção: o dígito verificador (RN11) é
  validado na aplicação, não no banco. Explique isso no relatório.
- Papéis com **sobreposição** (ADR-003): algumas pessoas que são cliente e lojista ao mesmo tempo.
  Toda pessoa com pelo menos 1 papel e 1 telefone, para a carga já obedecer RR16/RR17.
- Ordem: pessoa → endereco → pessoa_endereco → telefone → papéis → `cliente.id_endereco_atual`.
- **Combinar com o grupo:** os outros subdomínios usam IDs fixos (a Logística usa entregador 1 e 2,
  pedido 1..6). Defina faixas de IDs, por exemplo "pessoas 1–50 são entregadores", e avise os colegas.
  Lojistas precisam de Loja (Catálogo).
- No fim: `ANALYZE;`. Escreva um parágrafo para o relatório: as estatísticas que o planejador de
  consultas usa para estimar cardinalidade e escolher o plano (seq scan, index scan, tipo de join).
- **Estudar:** `INSERT … SELECT FROM generate_series`, `random()`, `(ARRAY[...])[1 + floor(random()*n)]`, `pg_stats`.

**Checkpoint:** `SELECT count(*)` por tabela, e conferir que nenhuma pessoa ficou sem papel nem sem telefone.

### Etapa 3 — `03_verificacao_identidade_contato.sql` (~1,5 h)
Um bloco por regra, cada um com um comentário neste formato:
```
-- Regra: RN10/RR14 — CPF deve ter 11 dígitos numéricos
-- Esperado: ERRO (violação de CHECK)
-- Mensagem do SGBD: ERROR:  new row for relation "pessoa" violates check constraint "ck_pessoa_cpf" ...
```
Casos mínimos a cobrir (INSERT, UPDATE e DELETE):
- CPF com letra ou 10 dígitos (CHECK), CPF repetido (UNIQUE), e-mail repetido, nome NULL (NOT NULL).
- CEP inválido e UF inválida (CHECK); endereço duplicado (UNIQUE composta).
- Telefone duplicado para a mesma pessoa (PK); telefone de uma pessoa inexistente (FK).
- `cliente.id_endereco_atual` apontando para um endereço que **não é dele** (FK composta, ADR-002). É o teste mais interessante.
- DELETE de uma pessoa ou endereço referenciado (comprova a ação referencial escolhida).
- Pelo menos **um caso válido** que passa, para mostrar que a regra não bloqueia demais.

**Problema prático:** com `ON_ERROR_STOP=1`, o primeiro erro para o script, e o CI falha. Duas saídas para estudar:
1. Envolver cada teste num bloco `DO $$ BEGIN … EXCEPTION WHEN check_violation THEN RAISE NOTICE … END $$;`
   (é o que a Logística fez).
2. Usar `SAVEPOINT` / `ROLLBACK TO SAVEPOINT` entre os testes.

Copie a mensagem **literal** que o PostgreSQL devolve (rode cada teste sem o tratamento uma vez) para o comentário e para a Seção 5.3 do relatório.

### Etapa 4 — Fechamento (~1 h)
- Teste do zero: `docker compose … down -v`, `up -d`, e rode 01 → 02 → 03 sem nenhuma edição manual.
- Atualize `docs/es/matriz_rastreabilidade.md` com o artefato e o status (DoD 4.1).
- Texto para o relatório (Seção 5): decisões de ações referenciais, o parágrafo do `ANALYZE` e as mensagens de erro.
- Commit no padrão `feat(identidade): … [#15]`, sem co-autoria de IA, e PR para `develop` pedindo revisão.
- Marque os itens E4 da issue #15.

### Pontos de atenção para levar ao grupo
- O professor pede o pacote `grupoNN_E4.zip` com `sql/`, mas o `package.sh` gera `grupo10.zip`. Alguém precisa ajustar isso.
- Os fragmentos ainda precisam ser **consolidados** em `01_esquema.sql`, `02_carga.sql` e `03_verificacao.sql`,
  que o CI exige não vazios. Identidade vem **primeiro** na ordem, porque todos os outros subdomínios dependem dela.
- Os ENUMs devem ser declarados uma única vez na consolidação.

### Verificação final
- Banco vazio, scripts 01, 02 e 03 com `ON_ERROR_STOP=1`, saída sem erro não tratado.
- `\d+` de cada tabela mostra todas as constraints nomeadas.
- Cada teste do 03 tem regra, resultado esperado e mensagem literal.
