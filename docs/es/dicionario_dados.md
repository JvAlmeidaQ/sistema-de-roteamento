# Dicionário de Dados Físico

**Disciplinas:** DCC060 (Banco de Dados) & DCC061 (Engenharia de Software) · **Sistema de Roteamento de Entregas**

## Sobre este Documento

Este documento especifica a **estrutura física proposta para o banco de dados relacional (PostgreSQL)**: convenções de tipagem, domínios (`ENUM`), tabelas, colunas, chaves primárias (`PK`), chaves estrangeiras (`FK`), chaves únicas (`UK`), nulabilidade (`NOT NULL`) e restrições de integridade (`CHECK` e gatilhos).

> **Artefatos Relacionados:**
> - **Significado dos termos de negócio:** consulte o [Glossário de Domínio](./glossario_de_dominio.md).
> - **Visão conceitual, cardinalidades e máquinas de estados:** consulte o [Modelo de Domínio](./modelo_dominio.md).
> - **Justificativas das decisões de modelagem e normalização:** consulte os [ADRs (Registros de Decisão Arquitetural)](./adrs/README.md).
> - **Regras de validação por camada (SGBD, Spring e Zod) e testes:** consulte a [Especificação de Validações](./especificacao_validacoes.md).
> - **Mapeamento para Requisitos e Regras de Negócio:** consulte a [Matriz de Rastreabilidade Bidirecional](./matriz_rastreabilidade.md).

---

## 1. Convenções Físicas e Domínios (`ENUM`)

- **Identificadores (`PK`):** `BIGINT GENERATED ALWAYS AS IDENTITY`, pois os identificadores internos não são expostos publicamente. As tabelas de papéis (`Cliente`, `Lojista`, `Entregador`) herdam a chave primária `id_pessoa` de `Pessoa` e, portanto, não possuem sequência própria ([ADR-003](./adrs/ADR-003-especializacao-pessoa-cardinalidade-minima.md)).
- **Valores Monetários:** `NUMERIC(12,2)`, nunca ponto flutuante (`FLOAT`/`REAL`), evitando erros de arredondamento na divisão financeira (`RN05`).
- **Datas e Carimbos de Tempo:** `TIMESTAMPTZ` (timestamp com fuso horário).
- **Nomenclatura:** `snake_case`, no singular e sem acentuação.
- **Documentos e Códigos Postais:** armazenados apenas com dígitos numéricos (`CHAR(11)` para CPF, `CHAR(14)` para CNPJ, `CHAR(8)` para CEP) e `CHAR(2)` para sigla de unidade federativa (`estado`).

### Tipos `ENUM` do PostgreSQL

- **`status_pedido`:** `'solicitado'`, `'aceito'`, `'recusado'`, `'pago'`, `'em_preparacao'`, `'pronto'`, `'concluido'`.
- **`status_entrega`:** `'aguardando_entregador'`, `'aceita'`, `'a_caminho'`, `'entregue'`.
- **`status_funcionamento`:** `'aberta'`, `'fechada'`.
- **`forma_pagamento`** *(valores sugeridos para o físico)*: `'pix'`, `'cartao_credito'`, `'cartao_debito'`, `'dinheiro'`.
- **`tipo_telefone`** *(valores sugeridos para o físico)*: `'celular'`, `'fixo'`, `'comercial'`.
- **`tipo_veiculo`** *(valores sugeridos para o físico)*: `'moto'`, `'bicicleta'`, `'carro'`.

---

## 2. Especificação das Tabelas e Atributos

> **Legenda:** `NN` = `NOT NULL`; `PK` = Chave Primária; `FK` = Chave Estrangeira; `UK` = Chave Única (`UNIQUE`).

### 2.1 Subdomínio: Identidade e Contato

#### `Pessoa` (dados cadastrais comuns a qualquer papel)
- `id_pessoa`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `nome`: `VARCHAR(120)`, **NN**.
- `cpf`: `CHAR(11)`, **NN**, **UK**. Restrição `CHECK` garantindo apenas 11 dígitos numéricos (`RN10`). Dígitos verificadores validados na aplicação (`RN11`).
- `email`: `VARCHAR(255)`, **NN**, **UK**.

#### `Cliente` (papel especializado de `Pessoa`)
- `id_pessoa`: `BIGINT`, **PK** e **FK** para `Pessoa(id_pessoa)`.
- `id_endereco_atual`: `BIGINT`, opcional (`NULL`). **FK composta** `(id_pessoa, id_endereco_atual)` referenciando `Pessoa_Endereco(id_pessoa, id_endereco)`, garantindo que o endereço selecionado pertença ao próprio cliente ([ADR-002](./adrs/ADR-002-snapshots-historicos-pedido-enderecos-imutaveis.md)).

#### `Lojista` (papel especializado de `Pessoa`)
- `id_pessoa`: `BIGINT`, **PK** e **FK** para `Pessoa(id_pessoa)`. Sem atributos específicos; deve possuir ao menos uma `Loja` vinculada (gatilho de restrição adiado — [ADR-003](./adrs/ADR-003-especializacao-pessoa-cardinalidade-minima.md)).

#### `Entregador` (papel especializado de `Pessoa`)
- `id_pessoa`: `BIGINT`, **PK** e **FK** para `Pessoa(id_pessoa)`.
- `tipo_veiculo`: `ENUM tipo_veiculo`, **NN**.

#### `Telefone` (entidade fraca de `Pessoa`)
- `id_pessoa`: `BIGINT`, **NN**, **FK** para `Pessoa(id_pessoa)`. Parte da **PK composta** `(id_pessoa, numero)`.
- `numero`: `VARCHAR(20)`, **NN**. Parte da **PK composta** (impede cadastro duplicado do mesmo número para a mesma pessoa).
- `tipo`: `ENUM tipo_telefone`, **NN**.

#### `Endereco` (localização física no nível da rua — imutável)
- `id_endereco`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `logradouro`: `VARCHAR(150)`, **NN**.
- `numero`: `VARCHAR(10)`, **NN** (aceita alfanuméricos como `'120A'` ou `'S/N'`).
- `bairro`: `VARCHAR(80)`, **NN**.
- `cep`: `CHAR(8)`, **NN** (`CHECK` apenas 8 dígitos).
- `cidade`: `VARCHAR(80)`, **NN**.
- `estado`: `CHAR(2)`, **NN**.
- **Regras de integridade:** registros em `Endereco` são **imutáveis** após inseridos (protegidos via gatilho contra `UPDATE`). Recomendada **UK composta** `(logradouro, numero, cep)` para compartilhamento do mesmo imóvel ([ADR-002](./adrs/ADR-002-snapshots-historicos-pedido-enderecos-imutaveis.md)).

#### `Pessoa_Endereco` (associação N:N entre `Pessoa` e `Endereco`)
- `id_pessoa`: `BIGINT`, **NN**, **FK** para `Pessoa(id_pessoa)`. Parte da **PK composta** `(id_pessoa, id_endereco)`.
- `id_endereco`: `BIGINT`, **NN**, **FK** para `Endereco(id_endereco)`. Parte da **PK composta**.
- `apelido`: `VARCHAR(40)`, opcional (ex.: `'Casa'`, `'Trabalho'`).
- `complemento`: `VARCHAR(80)`, opcional (editável individualmente por morador).
- `referencia`: `VARCHAR(150)`, opcional (editável individualmente por morador).

---

### 2.2 Subdomínio: Catálogo

#### `Loja`
- `id_loja`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `id_lojista`: `BIGINT`, **NN**, **FK** para `Lojista(id_pessoa)`.
- `id_endereco`: `BIGINT`, **NN**, **FK** para `Endereco(id_endereco)`.
- `complemento_endereco`: `VARCHAR(80)`, opcional (ex.: `'Loja 12'`, `'Sala 3'`).
- `cnpj`: `CHAR(14)`, **NN**, **UK**. Restrição `CHECK` para 14 dígitos numéricos (`RN10`); validação de dígitos verificadores na aplicação (`RN11`).
- `nome`: `VARCHAR(120)`, **NN**.
- `telefone`: `VARCHAR(20)`, **NN**.
- `status_funcionamento`: `ENUM status_funcionamento`, **NN** (`'aberta'` ou `'fechada'`, `RF07`, `RN01`).
- `tempo_entrega_estimado`: `INTEGER`, **NN**, `CHECK (tempo_entrega_estimado > 0)` (em minutos).
- `taxa_entrega`: `NUMERIC(12,2)`, **NN**, `CHECK (taxa_entrega >= 0)`. Valor fixo para toda a cidade.

#### `Produto` (pertence exclusivamente a uma `Loja`)
- `id_produto`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `id_loja`: `BIGINT`, **NN**, **FK** para `Loja(id_loja)`.
- `nome`: `VARCHAR(120)`, **NN**.
- `descricao`: `TEXT`, opcional.
- `preco`: `NUMERIC(12,2)`, **NN**, `CHECK (preco > 0)` (`RN09`).
- `ativo`: `BOOLEAN`, **NN**, `DEFAULT TRUE` (permite pausar a venda sem excluir o registro — `RF07`).
- **Chave Única Adicional:** **UK composta** `(id_loja, id_produto)` para suportar as FKs compostas de `Item_Pedido` e `Produto_Categoria` ([ADR-001](./adrs/ADR-001-integridade-loja-chaves-estrangeiras-compostas.md)).

#### `Categoria` (definida por cada `Loja`)
- `id_categoria`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `id_loja`: `BIGINT`, **NN**, **FK** para `Loja(id_loja)`.
- `nome`: `VARCHAR(80)`, **NN**.
- **Chave Única Adicional:** **UK composta** `(id_loja, id_categoria)` para suportar a FK composta de `Produto_Categoria` ([ADR-001](./adrs/ADR-001-integridade-loja-chaves-estrangeiras-compostas.md)).

#### `Produto_Categoria` (associação N:N entre `Produto` e `Categoria`)
- `id_produto`: `BIGINT`, **NN**. Parte da **PK composta** `(id_produto, id_categoria)`.
- `id_categoria`: `BIGINT`, **NN**. Parte da **PK composta**.
- `id_loja`: `BIGINT`, **NN**.
- **Chaves Estrangeiras Compostas:** `FK (id_loja, id_produto)` referenciando `Produto(id_loja, id_produto)` e `FK (id_loja, id_categoria)` referenciando `Categoria(id_loja, id_categoria)`, impedindo via DDL a associação entre produto e categoria de lojas diferentes ([ADR-001](./adrs/ADR-001-integridade-loja-chaves-estrangeiras-compostas.md)).

---

### 2.3 Subdomínio: Comércio e Finanças

#### `Pedido`
- `id_pedido`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `id_loja`: `BIGINT`, **NN**, **FK** para `Loja(id_loja)`.
- `id_cliente`: `BIGINT`, **NN**, **FK** para `Cliente(id_pessoa)`.
- `id_endereco`: `BIGINT`, **NN**, **FK** para `Endereco(id_endereco)` (endereço congelado no ato do pedido — [ADR-002](./adrs/ADR-002-snapshots-historicos-pedido-enderecos-imutaveis.md)).
- `complemento_entrega`: `VARCHAR(80)`, opcional (**snapshot** do complemento no momento do pedido).
- `referencia_entrega`: `VARCHAR(150)`, opcional (**snapshot** da referência no momento do pedido).
- `observacao_entrega`: `VARCHAR(255)`, opcional.
- `status`: `ENUM status_pedido`, **NN**, `DEFAULT 'solicitado'`.
- `data_pedido`: `TIMESTAMPTZ`, **NN**, `DEFAULT CURRENT_TIMESTAMP`.
- `forma_pagamento`: `ENUM forma_pagamento`, opcional até a confirmação do pagamento.
- `subtotal`: `NUMERIC(12,2)`, **NN**, `CHECK (subtotal >= 0)`.
- `taxa_entrega`: `NUMERIC(12,2)`, **NN**, `CHECK (taxa_entrega >= 0)` (**snapshot** da taxa da loja no momento da compra).
- `taxa_servico`: `NUMERIC(12,2)`, **NN**, `CHECK (taxa_servico >= 0)` (valor fixo da plataforma congelado no pedido).
- `valor_total`: `NUMERIC(12,2)`, **NN**, `CHECK (valor_total = subtotal + taxa_entrega + taxa_servico)`.
- **Chave Única Adicional:** **UK composta** `(id_loja, id_pedido)` para suportar a FK composta de `Item_Pedido` (`RN07`, [ADR-001](./adrs/ADR-001-integridade-loja-chaves-estrangeiras-compostas.md)).

#### `Item_Pedido` (associação entre `Pedido` e `Produto`)
- `id_pedido`: `BIGINT`, **NN**. Parte da **PK composta** `(id_pedido, id_produto)`.
- `id_produto`: `BIGINT`, **NN**. Parte da **PK composta**.
- `id_loja`: `BIGINT`, **NN**.
- `quantidade`: `INTEGER`, **NN**, `CHECK (quantidade > 0)` (`RN09`).
- `valor_unitario`: `NUMERIC(12,2)`, **NN**, `CHECK (valor_unitario > 0)` (`RN09`, **snapshot** do preço do produto no momento da compra — [ADR-002](./adrs/ADR-002-snapshots-historicos-pedido-enderecos-imutaveis.md)).
- **Chaves Estrangeiras Compostas:** `FK (id_loja, id_pedido)` para `Pedido(id_loja, id_pedido)` e `FK (id_loja, id_produto)` para `Produto(id_loja, id_produto)`, garantindo em DDL que todos os itens pertençam à mesma loja do pedido (`RN07`, [ADR-001](./adrs/ADR-001-integridade-loja-chaves-estrangeiras-compostas.md)).

#### `Avaliacao_Loja` e `Avaliacao_Entregador` (no máximo uma de cada por `Pedido`)
- `id_pedido`: `BIGINT`, **PK** e **FK** para `Pedido(id_pedido)`.
- `nota`: `SMALLINT`, **NN**, `CHECK (nota BETWEEN 1 AND 5)` (`RN06`).
- `comentario`: `TEXT`, opcional.
- `data_avaliacao`: `TIMESTAMPTZ`, **NN**, `DEFAULT CURRENT_TIMESTAMP`.
- **Regra de Negócio Associada:** inserção permitida somente se a entrega do pedido estiver com status `'entregue'` (`RN13`, validada por gatilho — [ADR-006](./adrs/ADR-006-modelo-financeiro-registros-pos-entrega.md)).

#### `Divisao_Pagamento` (relação 1:1 com `Pedido`, criada quando a entrega é concluída)
- `id_pedido`: `BIGINT`, **PK** e **FK** para `Pedido(id_pedido)`.
- `valor_total`: `NUMERIC(12,2)`, **NN** (cópia do `valor_total` de `Pedido` validada por gatilho para permitir a constraint `CHECK` da `RN05`).
- `parcela_loja`: `NUMERIC(12,2)`, **NN**, `CHECK (parcela_loja >= 0)`.
- `comissao_entregador`: `NUMERIC(12,2)`, **NN**, `CHECK (comissao_entregador >= 0)`.
- `taxa_plataforma`: `NUMERIC(12,2)`, **NN**, `CHECK (taxa_plataforma >= 0)`.
- `calculada_em`: `TIMESTAMPTZ`, **NN**, `DEFAULT CURRENT_TIMESTAMP`.
- **Restrição de Soma (`RN05`):** `CHECK (parcela_loja + comissao_entregador + taxa_plataforma = valor_total)` ([ADR-006](./adrs/ADR-006-modelo-financeiro-registros-pos-entrega.md)).

---

### 2.4 Subdomínio: Logística

#### `Rota`
- `id_rota`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `id_entregador`: `BIGINT`, **NN**, **FK** para `Entregador(id_pessoa)`.
- `criada_em`: `TIMESTAMPTZ`, **NN**, `DEFAULT CURRENT_TIMESTAMP`.
- `encerrada_em`: `TIMESTAMPTZ`, opcional, `CHECK (encerrada_em IS NULL OR encerrada_em >= criada_em)`.
- **Regra de Negócio Associada:** limite máximo de 2 entregas por rota imposto por gatilho (`RN02`, [ADR-005](./adrs/ADR-005-rotas-limite-duas-entregas-previsao-entrega.md)).

#### `Entrega`
- `id_entrega`: `BIGINT`, **PK**, `GENERATED ALWAYS AS IDENTITY`.
- `id_pedido`: `BIGINT`, **NN**, **UK**, **FK** para `Pedido(id_pedido)` (relacionamento 1:1).
- `id_rota`: `BIGINT`, opcional (`NULL` enquanto aguarda entregador), **FK** para `Rota(id_rota)`.
- `status`: `ENUM status_entrega`, **NN**, `DEFAULT 'aguardando_entregador'`.
- `previsao_entrega`: `TIMESTAMPTZ`, **NN**.
- **Restrição de Consistência:** `CHECK ((status = 'aguardando_entregador' AND id_rota IS NULL) OR (status <> 'aguardando_entregador' AND id_rota IS NOT NULL))`.

---

### 2.5 Subdomínio: Auditoria (Imutável)

#### `Historico_Pedido`
- `id_pedido`: `BIGINT`, **NN**, **FK** para `Pedido(id_pedido)`. Parte da **PK composta** `(id_pedido, status)`.
- `status`: `ENUM status_pedido`, **NN**. Parte da **PK composta** (cada status ocorre no máximo uma vez por pedido).
- `data_hora`: `TIMESTAMPTZ`, **NN**, `DEFAULT CURRENT_TIMESTAMP` (define a ordem cronológica dos eventos).

#### `Historico_Entrega`
- `id_entrega`: `BIGINT`, **NN**, **FK** para `Entrega(id_entrega)`. Parte da **PK composta** `(id_entrega, status)`.
- `status`: `ENUM status_entrega`, **NN**. Parte da **PK composta**.
- `data_hora`: `TIMESTAMPTZ`, **NN**, `DEFAULT CURRENT_TIMESTAMP`.

> **Garantias de Auditoria ([ADR-004](./adrs/ADR-004-ciclos-status-autonomos-historico-imutavel.md)):** `Historico_Pedido` e `Historico_Entrega` são populados automaticamente via gatilho a cada mudança de status (`RN04`) e bloqueiam qualquer tentativa de `UPDATE` ou `DELETE` (`RN08`).
