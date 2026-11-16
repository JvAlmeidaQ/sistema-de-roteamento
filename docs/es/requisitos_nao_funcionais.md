# Requisitos Não Funcionais (RNF)

> Alinhado às diretrizes da norma **ISO/IEC/IEEE 29148:2018** e aos atributos de qualidade de software (ISO/IEC 25010), os Requisitos Não Funcionais a seguir estabelecem as restrições tecnológicas, de segurança e desempenho do projeto.

## Especificação dos Requisitos Não Funcionais

| ID        | Categoria (ISO 25010)             | Descrição do Requisito Não Funcional                                                                                                                                     | Justificativa / Alinhamento Tecnológico                                                                                              |
| :-------- | :-------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------- |
| **RNF01** | Ambiente e Portabilidade          | O banco de dados deve ser implementado em **PostgreSQL (versão 18, compatível com 14+)**, encapsulado em contêineres Docker para execução determinística em diferentes máquinas. | Atende à exigência do edital de BD (PostgreSQL 14+) e garante reprodutibilidade do ambiente. Implementação via `docker/compose.yaml`. |
| **RNF02** | Manutenibilidade e Adaptabilidade | O frontend deve permitir ocultação dinâmica de rotas e componentes via variáveis de ambiente (_Feature Flags_, ex: `VITE_APP_MODE`).                                     | Permite apresentação com 4 telas (ES) ou 2 telas (BD) sem duplicação de repositório.                                                 |
| **RNF03** | Segurança                         | Senhas de usuários não podem ser armazenadas em texto limpo, devendo utilizar _hashing_ irreversível (BCrypt) na camada de aplicação.                                    | Requisito de confidencialidade em ES. Implementação no Spring Boot antes do INSERT no banco.                                         |
| **RNF04** | Eficiência e Desempenho           | Consultas em tabelas com alto volume (acima de 200.000 registros) devem ser otimizadas via índices secundários para evitar _Seq Scan_.                                   | Alinha-se com edital de BD (Seção 8): otimização comprovada via `EXPLAIN ANALYZE`.                                                   |
| **RNF05** | Confiabilidade e Rastreabilidade  | Evolução estrutural do esquema (DDL) deve ser versionada de forma sequencial e imutável pelos scripts numerados em `grupo10/sql/` (`01_esquema.sql` a `07_indices.sql`), rejeitando alterações manuais diretas no SGBD. | Garante versionamento determinístico validado em container limpo (`postgres:18`) pelo CI (`.github/workflows/ci.yml`) e compatível com execução automatizada via Flyway no backend. |

## Rastreabilidade: RNF → RF → Implementação

| ID RNF    | RF Impactados                      | Artefatos Principais                                                |
| :-------- | :--------------------------------- | :------------------------------------------------------------------ |
| **RNF01** | RF01–RF10 (todos)                  | `docker-compose.yml`, `Dockerfile`, `application.properties`, CI/CD |
| **RNF02** | RF03, RF04, RF05, RF08             | `vite.config.ts`, `.env.example`, `Router.tsx`                      |
| **RNF03** | RF01 (CRUD de Usuários)            | `UsuarioService.java`, `SecurityConfig.java`, `01_esquema.sql`      |
| **RNF04** | RF05, RF10 (Rastreio e Relatórios) | `01_esquema.sql` (índices), `04_consultas.sql`, `EXPLAIN ANALYZE`   |
| **RNF05** | RF01–RF10 (todos)                  | `grupo10/sql/01_esquema.sql`–`07_indices.sql`, `pom.xml`, `flyway.conf`, `.github/workflows/ci.yml` |

## Critérios de Aceitação Testáveis

| ID RNF    | Critério 1                                                                | Critério 2                                                        | Critério 3                                        |
| :-------- | :------------------------------------------------------------------------ | :---------------------------------------------------------------- | :------------------------------------------------ |
| **RNF01** | `docker compose up` inicia PostgreSQL 18 sem erros                        | Ambiente funciona em Ubuntu 22.04+ LTS                            | `docker compose down` limpa containers            |
| **RNF02** | `.env.example` declara `VITE_APP_MODE`                                    | Com `minimalBD`, 2 telas extras não aparecem                      | Build não empacota componentes ocultos            |
| **RNF03** | Senha nunca salva em texto limpo no banco                                 | Hash BCrypt (60+ caracteres, começa com `$2a$`, `$2b$` ou `$2y$`) | Teste unitário `UsuarioServiceTest` passa         |
| **RNF04** | Sem índice: consulta com 200k registros > 2000ms                          | Com índice: < 50ms                                                | `EXPLAIN ANALYZE` mostra redução de custo > 95%   |
| **RNF05** | Scripts numerados em `grupo10/sql/` (`01_esquema.sql` a `07_indices.sql`) | CI (`.github/workflows/ci.yml`) valida em `postgres:18` limpo    | Flyway no backend (`pom.xml` / `flyway_schema_history`) aplica `01` e `02` |
