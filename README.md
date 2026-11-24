# Sistema de Roteamento de Pedidos — DCC060 & DCC061

Plataforma web de entregas locais desenvolvida pelo **Grupo 10** para as disciplinas de **Banco de Dados (DCC060)** e **Engenharia de Software (DCC061)** — Universidade Federal de Juiz de Fora (UFJF).

O sistema conecta **Clientes**, **Lojistas** e **Entregadores** em um fluxo completo: catálogo de lojas e produtos, realização de pedidos, controle de preparo, roteamento e rastreamento de entregas, divisão financeira e avaliações pós-entrega.

---

## Equipe — Grupo 10

| Integrante | Matrícula |
| :--- | :--- |
| João Vitor Almeida Queiroz | `202435007` |
| Arthur de Souza Marques | `202435015` |
| Gustavo Bersan Moreira Campos | `202435019` |
| Murilo Lacerda Dutra | `202435023` |
| Theo Carvalho de Faria | `202435037` |

---

## Pré-requisitos

- **Docker** e **Docker Compose** (PostgreSQL 18)
- **Java 21** e **Maven 3.9+**
- **Node.js 20+** e **npm** *(opcional — necessário apenas para rodar o Front-end em modo desenvolvimento ou gerar novo bundle)*

---

## Como Executar o Sistema

### 1. Configurar variáveis de ambiente e iniciar o banco de dados

Na raiz do repositório, crie o arquivo `.env` a partir do modelo e suba o container do PostgreSQL:

```bash
cp .env.example .env
docker compose --env-file .env -f docker/docker-compose.yml up -d --wait
```

| Configuração do Banco | Valor |
| :--- | :--- |
| Host | `localhost` |
| Porta | `5433` |
| Database | `roteamento_db` |
| Usuário | `sistemaRoteamento` |
| Senha | Definida no arquivo `.env` |

### 2. Iniciar o Back-end (aplicação completa em `http://localhost:8080`)

```bash
cd grupo10/app/backend
mvn spring-boot:run
```

Ao iniciar, o Back-end:
1. Aplica automaticamente as migrações SQL via **Flyway** (`01_esquema.sql`, `02_carga.sql`, `05_visoes.sql`, `06_triggers.sql`, `07_indices.sql`).
2. Serve a API REST (`/api/...`) e a interface web compilada diretamente em **`http://localhost:8080`**.

### 3. (Opcional) Rodar o Front-end em modo desenvolvimento

Caso queira executar o servidor de desenvolvimento do Vite com *hot reload* (com proxy para a API na porta `8080`):

```bash
cd grupo10/app/frontend
npm install
npm run dev
```

Para gerar uma nova build de produção (que atualiza os arquivos estáticos servidos pelo Spring Boot em `grupo10/app/backend/src/main/resources/static/`):

```bash
cd grupo10/app/frontend
npm run build
```

---

## Guia de Navegação no Sistema (Para Avaliação)

Ao acessar **`http://localhost:8080`**, você será direcionado para a tela de entrada (`/entrar`).

### 1. Entrada, Cadastro e Contas Multi-papel

- **Entrar (`/entrar`):**
  - Informe um **e-mail** ou **CPF** já cadastrado, **ou** escolha diretamente uma das contas listadas em **Contas cadastradas** (acesso rápido para avaliação de Cliente, Lojista e Entregador).
- **Criar nova conta (`/cadastro`):**
  - Permite cadastrar uma nova pessoa informando dados pessoais, telefones, endereços e escolhendo um ou mais papéis (**Cliente**, **Lojista** com primeira loja, **Entregador** com tipo de veículo).
  - Se o e-mail ou CPF informado já existir, o sistema impede a duplicidade e direciona para a tela de entrada com o identificador preenchido.
- **Troca de papel na sessão:**
  - Contas que possuem mais de um papel exibem o seletor **Papel** no cabeçalho superior, permitindo alternar entre suas visões (ex.: `Cliente`, `Entregador`, `Lojista`) sem precisar sair da conta.

### 2. Navegação por Papel

Cada perfil visualiza exclusivamente suas telas e operações, com validação tanto na interface quanto nos endpoints do Back-end (`403 Forbidden` para acessos não autorizados):

| Papel | Rotas Disponíveis | O que é possível fazer |
| :--- | :--- | :--- |
| **Cliente** | `/` (Lojas), `/pedidos` (Meus pedidos), `/rastreio/:id`, `/perfis/:id` | Escolher loja aberta, montar carrinho de loja única, escolher endereço e forma de pagamento, confirmar pagamento de pedidos aceitos, acompanhar linha do tempo da entrega e avaliar loja e entregador após a conclusão. |
| **Lojista** | `/catalogo` (Minha loja), `/pedidos` (Pedidos), `/relatorios` (Relatórios), `/rastreio/:id`, `/perfis/:id` | Abrir/fechar a loja, cadastrar e pausar produtos, gerenciar categorias, aceitar/recusar pedidos, iniciar preparo, marcar pedido como pronto, calcular repasse financeiro e consultar relatórios e análises exclusivas da própria loja. |
| **Entregador** | `/painel-entregador` (Entregas), `/rastreio/:id`, `/perfis/:id` | Visualizar entregas disponíveis (com região de destino), assumir até 2 entregas na rota atual, registrar retirada (*A caminho*) e finalizar entrega (*Entregue*), além de consultar rotas encerradas. |
| **Administrador** | `/relatorios` (Financeiro), `/perfis` (Perfis), `/perfis/:id`, `/rastreio/:id` | Consultar o resumo financeiro consolidado de todas as lojas, filtrar relatórios por qualquer loja, executar análises gerenciais globais e buscar/inspecionar a listagem geral de perfis cadastrados. |

### 3. Acesso Administrativo

As contas administrativas são configuradas em `app.security.admin-user-ids` no arquivo [application.yml](./grupo10/app/backend/src/main/resources/application.yml) (correspondentes ao final das matrículas dos integrantes do grupo). Por segurança, essas contas **não aparecem no acesso rápido** e entram **exclusivamente digitando o CPF** na tela `/entrar`:

- `00000000007` (João Vitor Almeida Queiroz)
- `00000000015` (Arthur de Souza Marques)
- `00000000019` (Gustavo Bersan Moreira Campos)
- `00000000023` (Murilo Lacerda Dutra)
- `00000000037` (Theo Carvalho de Faria)

### 4. Roteiro Rápido Ponta a Ponta (5 passos)

1. **Criar pedido (Cliente):** Entre com uma conta de **Cliente**, escolha uma loja **Aberta** em **Lojas**, adicione itens ao carrinho e clique em **Confirmar pedido**.
2. **Aceitar pedido (Lojista):** Entre com o **Lojista** daquela loja, abra **Pedidos**, selecione o pedido criado e clique em **Aceitar pedido**.
3. **Confirmar pagamento (Cliente):** Volte para a conta do **Cliente**, abra **Meus pedidos** e clique em **Confirmar pagamento**.
4. **Preparar e liberar para entrega (Lojista):** Na conta do **Lojista**, clique em **Iniciar preparo** e depois em **Marcar como pronto**.
5. **Assumir e concluir entrega (Entregador) + Avaliar (Cliente):** Entre com um **Entregador**, assuma a entrega disponível em **Entregas**, clique em **Registrar retirada** e depois em **Finalizar**. Por fim, com o **Cliente**, avalie a loja e o entregador em **Meus pedidos** (e confira o repasse financeiro com o **Lojista**).

---

## Testes Automatizados

Com o PostgreSQL em execução na porta `5433`:

```bash
# Testes de integração do Back-end (JUnit 5 + MockMvc + PostgreSQL real)
cd grupo10/app/backend
mvn -B test
```

```bash
# Verificação de tipos TypeScript e build de produção do Front-end
cd grupo10/app/frontend
npm run build
```

---

## Documentação do Projeto

| Documento | Conteúdo |
| :--- | :--- |
| **[`docs/es/DESIGN.md`](./docs/es/DESIGN.md)** | Identidade visual, paleta de cores, tipografia (`Fustat` e `Inter Tight`), componentes e diretrizes de UX. |
| **[`docs/es/glossario_de_dominio.md`](./docs/es/glossario_de_dominio.md)** | Definições dos termos de negócio do domínio. |
| **[`docs/es/modelo_dominio.md`](./docs/es/modelo_dominio.md)** | Visão geral do domínio e ciclo de vida dos pedidos e entregas. |
| **[`docs/es/casos_de_uso.md`](./docs/es/casos_de_uso.md)** | Atores e casos de uso do sistema. |
| **[`docs/es/dicionario_dados.md`](./docs/es/dicionario_dados.md)** | Estrutura completa das tabelas e atributos do banco de dados. |
| **[`docs/es/especificacao_validacoes.md`](./docs/es/especificacao_validacoes.md)** | Regras de negócio, restrições e validações implementadas. |
| **[`docs/es/requisitos_nao_funcionais.md`](./docs/es/requisitos_nao_funcionais.md)** | Padrões de qualidade, segurança e arquitetura. |
| **[`docs/es/matriz_rastreabilidade.md`](./docs/es/matriz_rastreabilidade.md)** | Rastreabilidade entre requisitos, regras e artefatos de código. |
| **[`PROJECT_MANAGEMENT.md`](./PROJECT_MANAGEMENT.md)** | Organização do grupo, fluxo de trabalho e sprints. |

---

## Scripts SQL e Empacotamento (DCC060)

Os scripts SQL ficam em `grupo10/sql/` e são montados em `/sql/` (somente leitura) no container `postgres-dev`.

Para executar scripts manualmente no `psql`:

```bash
docker exec -it postgres-dev psql -U sistemaRoteamento -d roteamento_db -v ON_ERROR_STOP=1 -f /sql/04_consultas.sql
```

Para recriar o banco do zero:

```bash
docker compose --env-file .env -f docker/docker-compose.yml down -v
docker compose --env-file .env -f docker/docker-compose.yml up -d --wait
```

Para gerar o pacote de entrega da disciplina de Banco de Dados (`grupo10.zip`):

```bash
./package.sh
```

---

## Fluxo de Branches

- `main`: versões estáveis e validadas.
- `develop`: integração contínua de Banco de Dados.
- `release/es`: branch de integração do módulo de Engenharia de Software.
- `release/bd`: branch de entrega do módulo de Banco de Dados.
- `feat/*`, `refactor/*`, `fix/*`: branches de trabalho criadas a partir da respectiva branch de integração.
