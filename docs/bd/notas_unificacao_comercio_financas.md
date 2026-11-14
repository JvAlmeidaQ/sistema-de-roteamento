# Notas de Implementação e Unificação — Subdomínio: Comércio e Finanças

**Artefatos relacionados:**
- [`grupo10/sql/01_esquema_comercio_financas.sql`](../../grupo10/sql/01_esquema_comercio_financas.sql)
- [`grupo10/sql/02_carga_comercio_financas.sql`](../../grupo10/sql/02_carga_comercio_financas.sql)
- [`docs/es/dicionario_dados.md`](./dicionario_dados.md) · [`docs/es/especificacao_validacoes.md`](./especificacao_validacoes.md)

---

## 1. Decisões Tomadas na Correção do `02_carga_comercio_financas.sql`

Considerando que a carga (`02_carga.sql`) é executada **antes** da criação das triggers (`06_triggers.sql`), o script foi estruturado para respeitar todas as restrições de DDL ativas (`PK`, `UK`, `FK`, `FK composta`, `ENUM`, `NOT NULL` e `CHECK`) e, ao mesmo tempo, deixar os dados **semanticamente consistentes** com as regras de negócio:

1. **Dependência dinâmica de dados reais (`Loja`, `Cliente`, `Pessoa_Endereco`, `Produto`):**
   - Em vez de sortear IDs fixos (`1..50` ou `1..1000`), o script lê em arrays os registros já existentes de `loja` (filtrada para lojas com ao menos 1 `produto` ativo) e dos pares válidos `(cliente.id_pessoa, pessoa_endereco.id_endereco)`.
   - **Por quê:** garante que nenhuma `FK` quebre independentemente dos IDs gerados pelas cargas dos outros subdomínios, copia `taxa_entrega`, `complemento` e `referencia` reais (`RR09`) e assegura que o endereço do pedido pertença ao cliente (`RR03`).

2. **Seleção de `Item_Pedido` via `ROW_NUMBER()` e aritmética modular:**
   - Os produtos ativos de cada loja são numerados por `id_loja` (`1..total_produtos`), e cada pedido recebe de `1` a `LEAST(total_produtos, 3)` itens usando `((p.id_pedido + gs.n) % total_produtos) + 1`.
   - **Por quê:** elimina qualquer risco de colisão na `PK (id_pedido, id_produto)` e garante 100% de aderência à `FK composta (id_loja, id_produto)` (`RN07`), mantendo alta performance para 200.000 pedidos sem usar `ORDER BY random()` por linha. O `valor_unitario` é copiado de `produto.preco` (`RR09`).

3. **Inserção em duas etapas para `subtotal` e `valor_total` (`RR10`):**
   - No Passo 1, `pedido` é inserido com `subtotal = 0.00` e `valor_total = taxa_entrega + taxa_servico` (satisfazendo `CHECK (valor_total = subtotal + taxa_entrega + taxa_servico)`).
   - No Passo 3, após `item_pedido` ser populado, um `UPDATE` consolida `subtotal = SUM(quantidade * valor_unitario)` e recalcula `valor_total`.
   - **Por quê:** evita divergência entre o cabeçalho do pedido e a soma real de seus itens mesmo sem a trigger adiada de `RR10` ativa durante a carga.

4. **`Divisao_Pagamento` calculada após o `UPDATE` de totais (`RN05`):**
   - Inserida apenas no Passo 4 (para `status = 'concluido'`), usando os valores finais de `subtotal`, `taxa_entrega` e `valor_total`. `taxa_plataforma` é calculada por diferença (`valor_total - ROUND(subtotal * 0.85, 2) - taxa_entrega`) para evitar erro de arredondamento no `CHECK` de soma exata.

5. **Ajuste de tipos e `ENUM`:**
   - Cast explícito dos arrays para `status_pedido[]` e `forma_pagamento[]` com índice `[floor(...)::INT]`, incluindo `'cartao_debito'`.
   - `forma_pagamento` mantida `NULL` quando `status` está em `'solicitado'` ou `'aceito'`, alinhado ao [Dicionário de Dados](./dicionario_dados.md#pedido).
   - `nota` nas avaliações corrigida para `SMALLINT` uniforme entre `1` e `5` (`RN06`).

---

## 2. Checklist de Atenção e Verificação na Unificação dos Arquivos

Ao consolidar os arquivos por subdomínio em `grupo10/sql/01_esquema.sql` e `grupo10/sql/02_carga.sql`, verifique os seguintes pontos:

### Na unificação do DDL (`01_esquema.sql`)
- [ ] **Ordem de criação das tabelas:** `01_esquema_comercio_financas.sql` deve vir **depois** de:
  - `pessoa`, `cliente`, `endereco` (Identidade e Contato);
  - `loja`, `produto` (Catálogo).
- [ ] **Chave única em `Produto` (`ADR-001`):** confirmar que a tabela `produto` possui `CONSTRAINT uk_produto_loja UNIQUE (id_loja, id_produto)` (nessa ordem de colunas), exigida pela `FK` de `item_pedido`.
- [ ] **Unicidade de `CREATE TYPE`:** verificar se `forma_pagamento` ou `status_pedido` não foram declarados em duplicidade em outro arquivo de subdomínio (especialmente `status_pedido`, usado também em `historico_pedido`).

### Na unificação da carga (`02_carga.sql`)
- [ ] **Ordem de execução das cargas:** a carga de Comércio e Finanças **deve rodar após** as cargas de `pessoa`, `cliente`, `endereco`, `pessoa_endereco`, `loja` e `produto`.
- [ ] **Pré-condição mínima das tabelas pai:** deve existir ao menos 1 registro em `cliente JOIN pessoa_endereco` e ao menos 1 `loja` com `produto.ativo = TRUE` antes do bloco de Comércio e Finanças; caso contrário, os `ARRAY_AGG` retornarão `NULL` e nenhum pedido será inserido.
- [ ] **Integração com Logística (`Rota` e `Entrega`):** a carga gera pedidos nos status `'solicitado'`, `'aceito'`, `'em_preparacao'`, `'pronto'` e `'concluido'`. A carga do subdomínio de Logística deve criar registros em `entrega` (e `rota`) para os pedidos em `'pronto'` e `'concluido'` (com `entrega.status = 'entregue'` para os concluídos), garantindo consistência antes de `03_verificacao.sql` e `06_triggers.sql` (`RN12`, `RN13`, `RR07`, `RR08`).
- [ ] **Integração com Auditoria (`Historico_Pedido`):** como as triggers de `RN04` só serão criadas em `06_triggers.sql`, a carga de Auditoria precisará popular `historico_pedido` para os pedidos inseridos no `02_carga.sql`.
- [ ] **Teste limpo no Docker:** após unificar, validar a subida do zero conforme o `README.md`:
  ```bash
  docker compose -f docker/docker-compose.yml down -v
  docker compose -f docker/docker-compose.yml up -d
  ```
