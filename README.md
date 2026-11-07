# Sistema de Roteamento de Pedidos — DCC060 & DCC061

Projeto integrado unindo o trabalho prático de **Banco de Dados (DCC060)** e as práticas de **Engenharia de Software (DCC061)** — UFJF.

---

## 👋 Bem-vindo(a)! Por onde começar?

Este repositório guarda o nosso **Sistema de Roteamento de Pedidos** — uma plataforma de entregas locais (parecida com o iFood), onde clientes fazem pedidos em lojas parceiras e entregadores realizam as entregas organizadas em rotas.

Se você acabou de chegar ao projeto (seja como integrante do grupo, professor ou avaliador), não precisa abrir todos os arquivos de uma vez. Preparamos abaixo um **roteiro simples de leitura** para você entender tudo passo a passo, sem complicação.

### 🧭 Roteiro Recomendado de Leitura (Passo a Passo)

1. **Primeiro, entenda as palavras que usamos:** Comece pelo **[Glossário de Domínio](./docs/es/glossario_de_dominio.md)**. Ele funciona como um pequeno dicionário do nosso negócio e explica o que significa cada termo (o que é um *Pedido*, uma *Entrega*, uma *Rota*, a *Taxa de Serviço*, etc.).
2. **Depois, veja como o sistema funciona como um todo:** Leia o **[Modelo de Domínio](./docs/es/modelo_dominio.md)** e os **[Casos de Uso](./docs/es/casos_de_uso.md)**. Eles mostram quem usa o sistema (Cliente, Lojista e Entregador), como essas partes se conectam e quais são as etapas pelas quais um pedido passa desde a compra até chegar na casa do cliente.
3. **Em seguida, conheça o que é guardado no banco:** O **[Dicionário de Dados](./docs/es/dicionario_dados.md)** lista todas as fichas/tabelas de informação que o sistema salva (dados de pessoas, lojas, produtos, pedidos e histórico).
4. **Entenda o "porquê" das nossas escolhas:** Na pasta de **[Decisões do Projeto (ADRs)](./docs/es/adrs/README.md)**, contamos a história por trás das decisões mais importantes que tomamos e por que descartamos outras ideias.
5. **Veja as regras do jogo e como evitamos erros:** A **[Especificação de Validações](./docs/es/especificacao_validacoes.md)** mostra todas as regras que o sistema fiscaliza (por exemplo: não deixar fazer pedido em loja fechada ou não deixar uma rota ter mais de duas entregas).

---

### 📂 Mapa dos Arquivos `.md` (O que tem em cada documento?)

Para facilitar sua busca, veja na tabela abaixo **qual pergunta cada arquivo responde**:

| Arquivo | Qual pergunta ele responde? | O que você vai encontrar lá dentro |
| :--- | :--- | :--- |
| 📖 **[`glossario_de_dominio.md`](./docs/es/glossario_de_dominio.md)** | *"O que significa cada palavra neste projeto?"* | Explicação simples de 22 termos usados no sistema (como *Pedido*, *Entrega*, *Rota* e divisão de valores) para que todo mundo fale a mesma língua. |
| 🧩 **[`modelo_dominio.md`](./docs/es/modelo_dominio.md)** | *"Como as partes do sistema se conectam?"* | Resumo do que o sistema faz, o que ficou de fora, como clientes, lojas e entregadores se relacionam e o passo a passo da vida de um pedido. |
| 👥 **[`casos_de_uso.md`](./docs/es/casos_de_uso.md)** | *"O que cada pessoa pode fazer no sistema?"* | Um desenho visual mostrando as ações que o Cliente, o Lojista e o Entregador podem realizar na plataforma. |
| 🗄️ **[`dicionario_dados.md`](./docs/es/dicionario_dados.md)** | *"Quais informações o sistema guarda?"* | A lista completa de todas as tabelas e campos salvos no banco de dados (nomes, preços, endereços, notas de avaliação, etc.). |
| 💡 **[`docs/es/adrs/`](./docs/es/adrs/README.md)** *(ADR-001 a 006)* | *"Por que o grupo decidiu fazer assim?"* | Seis textos curtos explicando o motivo das nossas escolhas principais (ex.: como garantimos que o preço de um pedido antigo nunca mude se a loja aumentar o preço depois). |
| 🛡️ **[`especificacao_validacoes.md`](./docs/es/especificacao_validacoes.md)** | *"Como o sistema impede dados errados?"* | Lista de todas as travas de segurança e regras do negócio, explicando quem faz cada checagem e como testamos se está funcionando. |
| ⚙️ **[`requisitos_nao_funcionais.md`](./docs/es/requisitos_nao_funcionais.md)** | *"Quais são os padrões de qualidade e segurança?"* | Regras sobre desempenho, proteção de senhas e funcionamento padronizado do ambiente da equipe. |
| 🗺️ **[`matriz_rastreabilidade.md`](./docs/es/matriz_rastreabilidade.md)** | *"Onde cada pedido do trabalho foi entregue?"* | Um mapa que liga cada funcionalidade e regra exigida no trabalho diretamente aos arquivos onde ela foi construída. |
| 📋 **[`PROJECT_MANAGEMENT.md`](./PROJECT_MANAGEMENT.md)** | *"Como a equipe se organiza e trabalha?"* | Nosso calendário de entregas, combinados de convivência do grupo e regras para começar e entregar cada tarefa no **[Quadro do GitHub Projects](https://github.com/users/JvAlmeidaQ/projects/1)**. |

---

## 🛠️ Ambiente Local (Docker)

O projeto utiliza Docker Compose para executar uma instância local do PostgreSQL 18.

### Configuração

Antes de iniciar o banco pela primeira vez, crie o arquivo `.env` na raiz do projeto a partir do modelo `.env.example`:

```bash
cp .env.example .env
```

*(Se quiser, você pode editar o `.env` para trocar a senha local do banco).*

Para iniciar o PostgreSQL:

```bash
docker compose -f docker/docker-compose.yml up -d
```

### Configuração do banco

| Configuração | Valor               |
| ------------ | ------------------- |
| Host         | `localhost`         |
| Porta        | `5432`              |
| Database     | `roteamento_db`     |
| Usuário      | `sistemaRoteamento` |
| Senha        | definida no `.env`  |

O arquivo `.env` contém informações locais e não deve ser enviado ao Git. O arquivo `.env.example` serve como modelo e deve ser mantido no repositório.

### Como testar os scripts SQL localmente

Os scripts SQL ficam na pasta `grupo10/sql/` e aparecem automaticamente dentro do container no caminho `/docker-entrypoint-initdb.d/`:

```text
01_esquema.sql
02_carga.sql
03_verificacao.sql
04_consultas.sql
05_visoes.sql
06_triggers.sql
07_indices.sql
```

Você pode testar seus scripts de duas formas:

#### Opção 1: Executar um arquivo `.sql` específico (ideal enquanto você está escrevendo o código)
Como a pasta `grupo10/sql/` está espelhada dentro do container, qualquer alteração que você salvar no seu editor pode ser testada na hora rodando:

```bash
# Exemplo: testar o 01_esquema.sql
docker exec -it postgres-dev psql \
  -U sistemaRoteamento \
  -d roteamento_db \
  -v ON_ERROR_STOP=1 \
  -f /docker-entrypoint-initdb.d/01_esquema.sql

# Exemplo: testar o 03_verificacao.sql
docker exec -it postgres-dev psql \
  -U sistemaRoteamento \
  -d roteamento_db \
  -v ON_ERROR_STOP=1 \
  -f /docker-entrypoint-initdb.d/03_verificacao.sql
```

#### Opção 2: Recriar o banco do zero (para testar todos os scripts em sequência)
> A execução automática de todos os scripts só acontece quando o banco é criado pela primeira vez. Se você alterou os arquivos SQL e quer testar tudo rodando do zero em um banco limpo, apague o volume com `-v` e suba novamente:

```bash
docker compose -f docker/docker-compose.yml down -v
docker compose -f docker/docker-compose.yml up -d
```

#### Comandos úteis para inspecionar o banco manualmente (`psql`)

Para abrir o terminal interativo do banco:

```bash
docker exec -it postgres-dev psql -U sistemaRoteamento -d roteamento_db
```

Dentro do `psql`, você pode usar:

```sql
\dt   -- Lista as tabelas criadas
\dv   -- Lista as views criadas
\di   -- Lista os índices criados
\q    -- Sai do terminal do banco
```

Para verificar os triggers cadastrados:

```sql
SELECT
    event_object_table AS tabela,
    trigger_name
FROM information_schema.triggers
ORDER BY event_object_table, trigger_name;
```

Para apenas desligar o container (mantendo os dados salvos):

```bash
docker compose -f docker/docker-compose.yml down
```

## 📦 Empacotamento de Entrega (DCC060)

O professor exige submissão estrita em formato compactado (`grupo10.zip`).

Para gerar o pacote de submissão:

```bash
./package.sh
```

## 🌿 Fluxo de Branches

* `main`: código e artefatos validados para as entregas oficiais.
* `develop`: ambiente de integração contínua do grupo.
* `feature/<nome-da-tarefa>`: branches de trabalho individuais criadas a partir de `develop`.
