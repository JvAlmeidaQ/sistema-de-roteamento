# Sistema de Roteamento de Pedidos

Repositório de desenvolvimento do trabalho prático de Banco de Dados (DCC060 - 2026.3).

## 🛠️ Ambiente Local (Docker)

O projeto utiliza Docker Compose para executar uma instância local do PostgreSQL 18.

### Configuração

Antes de iniciar o banco, crie o arquivo `.env` a partir do `.env.example`:

Edite o `.env` e defina as credenciais do banco de dados.

Para iniciar o PostgreSQL:

```bash
docker compose --env-file .env -f docker/compose.yaml up
```

### Configuração do banco

| Configuração | Valor               |
| ------------ | ------------------  |
| Host         | `localhost`         |
| Porta        | `5432`              |
| Database     | `roteamento_db`     |
| Usuário      | `sistemaRoteamento` |
| Senha        | definida no `.env`  |

O arquivo `.env` contém informações sensíveis e não deve ser versionado. O arquivo `.env.example` serve como modelo de configuração e deve ser mantido no repositório.

### Verificação do banco

Após iniciar o PostgreSQL, é possível acessar o banco diretamente pelo container:

```bash
docker exec -it postgres-dev psql -U sistemaRoteamento -d roteamento_db
```

Dentro do `psql`, alguns comandos úteis para verificar a estrutura criada são:

```sql
\dt - Lista as tabelas do banco.
```



```sql
\dv - Lista as views criadas.
```



```sql
\di - Lista os índices.
```

Para verificar os triggers:

```sql
SELECT
    event_object_table AS tabela,
    trigger_name
FROM information_schema.triggers
ORDER BY event_object_table, trigger_name;
```

Também é possível executar o script de verificação fornecido pelo trabalho:

```bash
docker exec -it postgres-dev psql \
  -U sistemaRoteamento \
  -d roteamento_db \
  -f /docker-entrypoint-initdb.d/03_verificacao.sql
```

Os scripts SQL localizados em `grupoNN/sql/` são disponibilizados no container em `/docker-entrypoint-initdb.d/` e são executados automaticamente durante a primeira inicialização do banco, seguindo a ordem dos nomes dos arquivos.

```text
01_esquema.sql
02_carga.sql
03_verificacao.sql
04_consultas.sql
05_visoes.sql
06_triggers.sql
07_indices.sql
```

> A execução automática dos scripts de inicialização ocorre somente quando o banco é criado pela primeira vez. Se o volume `postgres_data` já existir, alterações nos arquivos SQL não serão executadas automaticamente. Para recriar o banco do zero, utilize `docker compose -f docker/compose.yaml down -v` e depois suba o container novamente.


Para encerrar o contêiner:

```bash
docker compose -f docker/compose.yaml down
```

## 📦 Empacotamento de Entrega (DCC060)

O professor exige submissão estrita em formato compactado (`grupoNN.zip`).

Para gerar o pacote de submissão:

```bash
./package.sh
```

## 🌿 Fluxo de Branches

* `main`: código e artefatos validados para as entregas oficiais.
* `develop`: ambiente de integração contínua do grupo.
* `feature/<nome-da-tarefa>`: branches de trabalho individuais criadas a partir de `develop`.
