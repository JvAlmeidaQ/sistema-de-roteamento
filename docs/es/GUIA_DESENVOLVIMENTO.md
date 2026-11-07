# 🚀 Guia Oficial de Onboarding, Arquitetura e Desenvolvimento

**Disciplinas:** DCC060 (Banco de Dados) & DCC061 (Engenharia de Software) — UFJF  
**Projeto:** Sistema de Roteamento de Entregas (`grupo10`)

---

## Boas-vindas à Equipe!

Este documento é o **guia definitivo de engenharia** do nosso monorepo. Se você acabou de clonar o repositório ou vai assumir uma nova *issue* no quadro Kanban, leia este guia do início ao fim. Ele explica como arquitetamos uma solução única capaz de atender, sem duplicação de código, às exigências rigorosas de duas disciplinas com focos distintos, além de detalhar o passo a passo técnico para criar funcionalidades de ponta a ponta.

> **Documentação de Apoio (Leitura Obrigatória):**
> 1. 📋 [Governança, DoR e DoD (`PROJECT_MANAGEMENT.md`)](../../PROJECT_MANAGEMENT.md)
> 2. 📖 [Glossário de Domínio (`glossario_de_dominio.md`)](./glossario_de_dominio.md)
> 3. 🧩 [Modelo de Domínio (`modelo_dominio.md`)](./modelo_dominio.md)
> 4. 🗄️ [Dicionário de Dados Físico (`dicionario_dados.md`)](./dicionario_dados.md)
> 5. 🏛️ [Registros de Decisão Arquitetural (`adrs/README.md`)](./adrs/README.md)
> 6. 🛡️ [Especificação de Validações (`especificacao_validacoes.md`)](./especificacao_validacoes.md)
> 7. 🗺️ [Matriz de Rastreabilidade (`matriz_rastreabilidade.md`)](./matriz_rastreabilidade.md)

---

## 1. Contexto do Projeto: Uma Base de Código, Duas Disciplinas

Nosso repositório foi desenhado como um **monorepo integrado** que serve simultaneamente a dois editais acadêmicos com escopos diferentes:

| Dimensão | Engenharia de Software (`DCC061`) | Banco de Dados (`DCC060`) |
| :--- | :--- | :--- |
| **Objetivo Central** | Processo de engenharia completo, arquitetura em camadas, qualidade, testes, gerência de configuração e rastreabilidade (`RF ↔ RN ↔ Código`). | Modelagem relacional rigorosa, integridade no SGBD (DDL, `CHECK`, FKs compostas, Triggers), carga de 200k+ tuplas, otimização e consultas analíticas. |
| **Escopo de Telas (Frontend)** | **Modo Completo (`VITE_APP_MODE=full`):** Todas as jornadas de Cliente, Lojista e Entregador (catálogo, criação de pedido, preparo, rotas, rastreio e avaliações). | **Modo Estrito (`VITE_APP_MODE=bd`):** Apenas as telas essenciais exigidas pelo edital de BD para comprovar inserções/transações reais e visualizar relatórios/visões SQL. |
| **Empacotamento** | Repositório completo com documentação em `docs/es/`, CI/CD e releases versionadas (`vX.Y.Z-es-*`). | Pacote `grupo10.zip` gerado via `./package.sh`, contendo `grupo10/sql/`, `grupo10/algebra/` e `grupo10/app/` com o build enxuto (`build:bd`) embutido no Spring Boot. |

### Estrutura Física do Monorepo

```text
trabalho-banco-de-dados-sql/
├── docker/
│   └── docker-compose.yml          # Container PostgreSQL 18 (porta 5432)
├── docs/es/                        # Artefatos de Engenharia de Software (Requisitos, ADRs, Dicionário, Validações)
├── grupo10/                        # Diretório oficial empacotado para submissão (package.sh)
│   ├── algebra/                    # Consultas em Álgebra Relacional (E3)
│   ├── sql/                        # Scripts SQL oficiais (fonte única da verdade do banco!)
│   │   ├── 01_esquema.sql          # DDL completo (Tabelas, ENUMs, PKs, FKs compostas, CHECKs)
│   │   ├── 02_carga.sql            # Carga inicial de dados
│   │   ├── 03_verificacao.sql      # Suite de testes de integridade SQL
│   │   ├── 04_consultas.sql        # Consultas estratégicas e operacionais
│   │   ├── 05_visoes.sql           # Views de negócio
│   │   ├── 06_triggers.sql         # Gatilhos imediatos e CONSTRAINT TRIGGERs adiados
│   │   └── 07_indices.sql          # Índices de performance (EXPLAIN ANALYZE)
│   └── app/
│       ├── backend/                # API Java 21 + Spring Boot 3.5 + Flyway + jOOQ
│       └── frontend/               # SPA React 19 + TypeScript + Vite + TailwindCSS 4 + Zod
├── package.sh                      # Script gerador do grupo10.zip
└── PROJECT_MANAGEMENT.md           # Governança, DoR, DoD e fluxo Git
```

---

## 2. Stack Tecnológica e Paradigma *Database-First*

### 2.1 Backend: Java 21 + Spring Boot 3.5 (Sem Hibernate/JPA!)

Tomamos uma decisão arquitetural deliberada: **NÃO utilizamos ORMs tradicionais (como Hibernate/JPA)**. Em vez disso, adotamos o paradigma **Database-First** puro com **Flyway** + **jOOQ**:

1. **Fonte Única da Verdade em SQL (`grupo10/sql/`):**
   - Não mantemos duas versões dos scripts SQL. O `maven-resources-plugin` no `pom.xml` copia os scripts oficiais da pasta `grupo10/sql/` para `target/classes/db/migration` durante o build.
   - O **Flyway** está configurado com `sqlMigrationPrefix=""` e `sqlMigrationSeparator="_"`, o que permite executar diretamente `01_esquema.sql` e `02_carga.sql` mantendo os nomes exatos exigidos pelo edital de Banco de Dados.
2. **Geração de Código Type-Safe com jOOQ (`br.ufjf.dcc.entregas.jooq`):**
   - Durante a fase `generate-sources` do Maven, o Flyway aplica os scripts SQL no PostgreSQL e, imediatamente em seguida, o plugin `jooq-codegen-maven` inspeciona o catálogo real do PostgreSQL (`public`) e gera classes Java fortemente tipadas para cada tabela, coluna, `ENUM` e `Record`.
   - Se alguém alterar o nome de uma coluna em `01_esquema.sql`, o código Java que a referencia **para de compilar imediatamente**, eliminando erros de SQL em tempo de execução.
3. **Validação e Tratamento de Erros:**
   - **Bean Validation (`spring-boot-starter-validation`):** Valida DTOs de entrada (`@NotNull`, `@Positive`, `@Min`, `@Max`).
   - **Tradução de `SQLSTATE`:** Erros de integridade levantados pelo PostgreSQL (`23505`, `23503`, `23514`, `P0001`) são interceptados em um `@RestControllerAdvice` e convertidos para os códigos HTTP documentados na [Especificação de Validações](./especificacao_validacoes.md#3-contrato-de-traducao-de-erros-sgbd-sqlstate--api-http).

### 2.2 Frontend: React 19 + TypeScript + Vite + Zod + TailwindCSS 4

- **Vite 8 & React Router 7:** Roteamento SPA com proxy de desenvolvimento configurado (`/api` → `http://localhost:8080`).
- **React Hook Form + Zod (`@hookform/resolvers`):** Toda entrada de formulário é validada no cliente com schemas **Zod** espelhando as regras de negócio da [Especificação de Validações](./especificacao_validacoes.md).
- **Axios (`src/lib/api.ts`):** Instância centralizada apontando para `/api`, com interceptor automático que injeta o cabeçalho `X-User-Id` a partir do `sessionStorage` para simular o contexto do ator logado (Cliente, Lojista ou Entregador).
- **TailwindCSS v4 (`@tailwindcss/vite`):** Estilização utilitária moderna com suporte a `clsx` e `tailwind-merge` (`src/lib/cn.ts`).

---

## 3. Fluxo de Desenvolvimento Passo a Passo (Como Criar uma Feature)

Sempre que você assumir uma tarefa (ex.: *"Implementar criação de Pedido — RF02"*), siga rigorosamente os **4 passos** abaixo:

### Passo 1 — Camada de Banco de Dados (`grupo10/sql/`)

Toda evolução começa no banco de dados. Consulte o [Dicionário de Dados](./dicionario_dados.md) e a [Especificação de Validações](./especificacao_validacoes.md):

1. Escreva ou ajuste as tabelas, tipos `ENUM`, chaves estrangeiras compostas e cláusulas `CHECK` em `grupo10/sql/01_esquema.sql`.
2. Se a regra exigir gatilho imediato ou adiado (`CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`), implemente a função PL/pgSQL e o trigger em `grupo10/sql/06_triggers.sql`.
3. Adicione os casos de teste positivos e negativos correspondentes em `grupo10/sql/03_verificacao.sql`.

---

### Passo 2 — Geração de Classes com Flyway + jOOQ

Com o container do PostgreSQL rodando (veja a Seção 4), gere as classes Java a partir do seu SQL (o Maven lê automaticamente a senha do arquivo `.env` da raiz via `properties-maven-plugin`):

```bash
cd grupo10/app/backend
mvn generate-sources
```

**O que acontece nesse comando?**
1. O Maven copia `01_esquema.sql` e `02_carga.sql` para `target/classes/db/migration`.
2. O `flyway-maven-plugin` aplica as migrações no banco `roteamento_db`.
3. O `jooq-codegen-maven` lê o banco atualizado e gera as classes em `target/generated-sources/jooq` sob o pacote `br.ufjf.dcc.entregas.jooq` (ex.: `Tables.PEDIDO`, `Tables.ITEM_PEDIDO`, `PedidoRecord`).

---

### Passo 3 — Camada de Backend (`grupo10/app/backend/src/main/java/br/ufjf/dcc/entregas/`)

Organize o código Java respeitando a separação de responsabilidades:

#### 3.1. `@Repository` (Acesso a Dados com jOOQ `DSLContext`)
Injete o `DSLContext` autoconfigurado pelo Spring Boot e escreva consultas SQL type-safe usando as tabelas geradas pelo jOOQ:

```java
package br.ufjf.dcc.entregas.repository;

import br.ufjf.dcc.entregas.jooq.tables.records.PedidoRecord;
import org.jooq.DSLContext;
import org.springframework.stereotype.Repository;

import static br.ufjf.dcc.entregas.jooq.Tables.PEDIDO;

@Repository
public class PedidoRepository {

    private final DSLContext dsl;

    public PedidoRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public Long inserirPedido(Long idLoja, Long idCliente, Long idEndereco, ...) {
        return dsl.insertInto(PEDIDO)
                .set(PEDIDO.ID_LOJA, idLoja)
                .set(PEDIDO.ID_CLIENTE, idCliente)
                .set(PEDIDO.ID_ENDERECO, idEndereco)
                // ... demais campos de snapshot
                .returningResult(PEDIDO.ID_PEDIDO)
                .fetchOneInto(Long.class);
    }
}
```

#### 3.2. `@Service` (Regras de Negócio e Fronteira Transacional)
A camada de serviço é **obrigatória** para:
- Validar regras de aplicação (ex.: `RN01` — verificar se a loja está aberta; `RN03` — verificar se o entregador tem entrega atrasada; `RN11` — validar dígitos verificadores de CPF/CNPJ).
- Garantir atomicidade com `@Transactional`: lembre-se do [ADR-003](./adrs/ADR-003-especializacao-pessoa-cardinalidade-minima.md)! Como usamos `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` para cardinalidades mínimas (ex.: todo `Pedido` exige ao menos 1 `Item_Pedido`, toda `Pessoa` exige ao menos 1 `Telefone` e 1 papel), **o cabeçalho e os filhos devem ser inseridos dentro do mesmo método `@Transactional`**, pois o PostgreSQL validará a regra no `COMMIT`.

```java
@Service
public class PedidoService {

    @Transactional
    public PedidoResponse criarPedido(Long idCliente, CriarPedidoRequest req) {
        // 1. Valida RN01 (loja aberta e produtos ativos)
        // 2. Calcula snapshots (taxa_entrega da loja, taxa_servico, subtotal, valor_total)
        // 3. Insere Pedido e todos os Item_Pedido na mesma transação!
        // No final do método, o Spring executa o COMMIT e dispara os gatilhos adiados.
    }
}
```

#### 3.3. `@RestController` (Contrato HTTP e Bean Validation)
Exponha os endpoints sob o prefixo `/api/...` (para casar com o proxy do Vite e com a instância `api` do Axios), validando os DTOs de entrada com `@Valid`:

```java
@RestController
@RequestMapping("/api/pedidos")
public class PedidoController {

    private final PedidoService pedidoService;

    public PedidoController(PedidoService pedidoService) {
        this.pedidoService = pedidoService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PedidoResponse criar(
            @RequestHeader("X-User-Id") Long idCliente,
            @Valid @RequestBody CriarPedidoRequest request) {
        return pedidoService.criarPedido(idCliente, request);
    }
}
```

---

### Passo 4 — Camada de Frontend (`grupo10/app/frontend/`) e Roteamento Condicional (`VITE_APP_MODE`)

Para atender ao **RNF02** (ocultação dinâmica de telas entre as entregas de ES e BD sem duplicar o repositório), utilizamos variáveis de ambiente de build do Vite (`.env.full` e `.env.bd`):

1. Defina a constante de modo a partir de `import.meta.env.VITE_APP_MODE`:
   ```tsx
   // Em modo 'bd', isBd será substituído estaticamente por true no bundle final
   const isBd = import.meta.env.VITE_APP_MODE === 'bd'
   ```
2. Declare as rotas exclusivas de Engenharia de Software condicionalmente (`!isBd`):
   ```tsx
   <Routes>
     {/* Rotas comuns (presentes em BD e ES: inserção principal e relatórios SQL) */}
     <Route path="/" element={<HomePage />} />
     <Route path="/relatorios" element={<RelatorioLoja />} />

     {/* Rotas exclusivas do escopo completo de Engenharia de Software */}
     {!isBd && (
       <>
         <Route path="/painel-lojista" element={<PainelLojista />} />
         <Route path="/painel-entregador" element={<PainelEntregador />} />
         <Route path="/rastreio/:id" element={<RastreioPedido />} />
         <Route path="/avaliacao/:id" element={<AvaliacaoPage />} />
       </>
     )}
   </Routes>
   ```
3. **Tree-Shaking Automático (Eliminação de Código Morto):** Como `import.meta.env.VITE_APP_MODE` é substituído por uma string literal (`"bd"` ou `"full"`) em tempo de compilação pelo Vite, quando rodamos `npm run build:bd`, a expressão `!isBd` torna-se `false` e o bundler remove completamente os componentes exclusivos de ES do pacote JavaScript final!

---

## 4. Infraestrutura, Execução Local e a "Mágica" da Entrega Final

### 4.1 Subindo o Banco de Dados (PostgreSQL 18 via Docker)

Na raiz do repositório, configure seu arquivo `.env` (baseado no `.env.example`) com `POSTGRES_PASSWORD` e inicie o container:

```bash
# 1. Crie o .env na raiz (se ainda não existir)
cp .env.example .env

# 2. Suba o PostgreSQL 18 em background
docker compose --env-file .env -f docker/docker-compose.yml up -d

# 3. Verifique se o container está saudável (healthy)
docker ps
```

> **Dica de Reset do Banco:** Caso precise recriar o banco completamente do zero durante o desenvolvimento das migrations, derrube o container removendo o volume com:
> ```bash
> docker compose -f docker/docker-compose.yml down -v
> ```

### 4.2 Rodando em Modo de Desenvolvimento (Hot-Reload)

Durante o desenvolvimento diário, você pode rodar o Backend na porta `8080` e o servidor de desenvolvimento do Vite na porta `5173` (que já possui proxy automático de `/api` para `http://localhost:8080`):

**Terminal 1 — Backend (Spring Boot):**
```bash
cd grupo10/app/backend
mvn spring-boot:run
```
*(O Spring Boot e o Maven carregam automaticamente o arquivo `.env` da raiz do repositório — não é necessário rodar `export POSTGRES_PASSWORD` no terminal).*

**Terminal 2 — Frontend (Vite Dev Server):**
```bash
cd grupo10/app/frontend
npm install
npm run dev
# Acesse http://localhost:5173
```

### 4.3 Executando os Testes e Verificações

```bash
# Executar o ciclo completo do Backend (Flyway + jOOQ codegen + Testes JUnit)
cd grupo10/app/backend
mvn clean verify

# Executar o script oficial de verificação SQL (03_verificacao.sql) direto no container
docker exec -it postgres-dev psql \
  -U sistemaRoteamento \
  -d roteamento_db \
  -v ON_ERROR_STOP=1 \
  -f /sql/03_verificacao.sql
```

### 4.4 A "Mágica" da Entrega Final (Frontend Embutido no Spring Boot)

Para que os professores e avaliadores possam executar toda a aplicação com **um único comando** sem precisar instalar Node.js ou subir dois servidores, nosso `grupo10/app/frontend/vite.config.ts` já está configurado com:

```ts
build: { outDir: '../backend/src/main/resources/static', emptyOutDir: true }
```

Isso significa que, ao compilar o frontend, o Vite limpa e deposita automaticamente o `index.html` e os assets otimizados diretamente dentro de `grupo10/app/backend/src/main/resources/static/`! O Tomcat embutido do Spring Boot serve esses arquivos estáticos na raiz (`http://localhost:8080/`).

#### Para gerar o Build de Engenharia de Software (Modo Completo — `full`):
```bash
# 1. Compila o React com todas as telas e injeta em backend/src/main/resources/static
cd grupo10/app/frontend
npm run build

# 2. Sobe a aplicação monolítica completa na porta 8080
cd ../backend
mvn spring-boot:run
```

#### Para gerar o Build de Banco de Dados (Modo Estrito — `bd`) e empacotar:
```bash
# 1. Compila o React apenas com as telas de BD (tree-shaking remove as telas extras)
cd grupo10/app/frontend
npm run build:bd

# 2. (Opcional) Testa a aplicação unificada em http://localhost:8080
cd ../backend
mvn spring-boot:run

# 3. Na raiz do repositório, gera o pacote grupo10.zip para envio
cd ../../..
./package.sh
```

---

## 5. Notas Técnicas de Arquitetura (Boas Práticas)

1. **Integração Direta Vite → Spring Boot (`static/`):** O `vite.config.ts` já aponta `outDir` diretamente para `../backend/src/main/resources/static`. Portanto, não é necessário copiar pastas manualmente após rodar `npm run build` ou `npm run build:bd`.
2. **Fallback de Rotas SPA no Spring Boot:** Como o frontend usa `BrowserRouter` (`react-router-dom`), se o usuário recarregar a página (F5) em uma rota como `http://localhost:8080/relatorios` quando estiver rodando pelo Spring Boot na porta `8080`, o Tomcat tentará buscar um recurso físico `/relatorios` e retornará `404` se não houver redirecionamento para `index.html`. Recomendamos incluir um controlador simples no Spring Boot (ex.: `SpaForwardController`) que encaminhe rotas de interface (`!path.startsWith("/api")`) para `forward:/index.html`.
3. **Caminhos Relativos Sincronizados (`grupo10`):**
   - No `grupo10/app/backend/pom.xml`, a propriedade `<sql.dir>` aponta para `${project.basedir}/../../sql` (`grupo10/sql/`).
   - Em `docker/docker-compose.yml` e `.github/workflows/ci.yml`, os volumes e steps apontam para `grupo10/sql` e `grupo10/app/backend`.
