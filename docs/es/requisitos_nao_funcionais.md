# Requisitos Não Funcionais (RNF)

> Alinhado às diretrizes da norma **ISO/IEC/IEEE 29148:2018** e aos atributos de qualidade de software (ISO/IEC 25010), os Requisitos Não Funcionais a seguir estabelecem as restrições tecnológicas, de segurança e desempenho do projeto.

## Especificação dos Requisitos Não Funcionais

| ID        | Categoria (ISO 25010)             | Descrição do Requisito Não Funcional                                                                                                                                                                                    | Justificativa / Alinhamento Tecnológico                                                                                                                                             |
| :-------- | :-------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **RNF01** | Ambiente e Portabilidade          | O banco de dados deve ser implementado em **PostgreSQL (versão 18, compatível com 14+)**, encapsulado em contêineres Docker para execução determinística em diferentes máquinas.                                        | Atende à exigência do edital de BD (PostgreSQL 14+) e garante reprodutibilidade do ambiente. Implementação via `docker/compose.yaml`.                                               |
| **RNF02** | Manutenibilidade e Adaptabilidade | O frontend deve permitir ocultação dinâmica de rotas e componentes via variáveis de ambiente (_Feature Flags_, ex: `VITE_APP_MODE`).                                                                                    | Permite apresentação com 4 telas (ES) ou 2 telas (BD) sem duplicação de repositório.                                                                                                |
| **RNF03** | Segurança                         | O acesso às operações e consultas da aplicação deve exigir sessão ativa identificada e aplicar controle de autorização por papel (`Cliente`, `Lojista`, `Entregador`) e lista explícita de administradores, retornando `403 Forbidden` para acessos não autorizados sem expor identificadores técnicos na interface. | O esquema SQL oficial (`01_esquema.sql`) não armazena credenciais de senha; portanto, a segurança é garantida por isolamento de contexto (`X-User-Id` e `X-Active-Role`), `AdminAccessService` (`app.security.admin-user-ids`) e validação em cada controller/service. |
| **RNF04** | Eficiência e Desempenho           | Consultas em tabelas com alto volume (acima de 200.000 registros) devem ser otimizadas via índices secundários para evitar _Seq Scan_.                                                                                  | Alinha-se com edital de BD (Seção 8): otimização comprovada via `EXPLAIN ANALYZE`.                                                                                                  |
| **RNF05** | Confiabilidade e Rastreabilidade  | Evolução estrutural do esquema (DDL) deve ser versionada de forma sequencial e imutável pelas migrações numeradas de `grupo10/sql/` (`01`, `02`, `05` a `07`), rejeitando alterações manuais diretas no SGBD. | Garante versionamento determinístico validado em container limpo (`postgres:18`) pelo CI (`.github/workflows/ci.yml`) e compatível com execução automatizada via Flyway no backend. |

## Rastreabilidade: RNF → RF → Implementação

| ID RNF    | RF Impactados                      | Artefatos Principais                                                                                |
| :-------- | :--------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **RNF01** | RF01–RF10 (todos)                  | `docker/docker-compose.yml`, `Dockerfile`, `application.yml`, CI/CD                                 |
| **RNF02** | RF03, RF04, RF05, RF08             | `vite.config.ts`, `.env.bd`, `.env.full`, `package.json`                                            |
| **RNF03** | RF01–RF10 (controle de acesso)     | `AutenticacaoController.java`, `AdminAccessService.java`, `AdminSecurityProperties.java`, `application.yml` |
| **RNF04** | RF05, RF10 (Rastreio e Relatórios) | `01_esquema.sql` (índices), `04_consultas.sql`, `EXPLAIN ANALYZE`                                   |
| **RNF05** | RF01–RF10 (todos)                  | `grupo10/sql/` (migrações `01`, `02`, `05` a `07`), `pom.xml`, `flyway.conf`, `.github/workflows/ci.yml` |

## Critérios de Aceitação Testáveis

| ID RNF    | Critério 1                                                                | Critério 2                                                               | Critério 3                                                                 |
| :-------- | :------------------------------------------------------------------------ | :----------------------------------------------------------------------- | :------------------------------------------------------------------------- |
| **RNF01** | `docker compose up` inicia PostgreSQL 18 sem erros                        | Ambiente funciona em Ubuntu 22.04+ LTS                                   | `docker compose down` limpa containers                                     |
| **RNF02** | `.env.bd` / `.env.full` declaram `VITE_APP_MODE`                          | Com `VITE_APP_MODE=bd` (`build:bd`), telas exclusivas de ES não aparecem | Build não empacota componentes ocultos                                     |
| **RNF03** | Endpoints restringem ações e dados ao ator/loja autorizados             | Acessos indevidos entre papéis ou não administradores retornam `403 Forbidden` | Suítes de integração (`*IntegrationTest.java`) validam autorização end-to-end |
| **RNF04** | Sem índice: consulta com 200k registros > 2000ms                          | Com índice: < 50ms                                                       | `EXPLAIN ANALYZE` mostra redução de custo > 95%                            |
| **RNF05** | Migrações numeradas em `grupo10/sql/` (`01`, `02`, `05` a `07`) | CI (`.github/workflows/ci.yml`) valida em `postgres:18` limpo            | Flyway aplica `01`, `02` e `05` a `07` e valida os checksums já registrados |
