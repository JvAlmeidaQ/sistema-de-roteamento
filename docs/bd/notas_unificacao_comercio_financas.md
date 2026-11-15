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


---

## 3. Decisões e Justificativas da Consolidação Final da E4 (`01_esquema.sql`, `02_carga.sql`, `03_verificacao.sql`)

Após a integração dos 5 subdomínios (Identidade e Contato, Catálogo, Comércio e Finanças, Logística e Auditoria) e a auditoria frente ao `E4_e_issues.md` e ao `relatorioGrupo10.md`, foram consolidadas as seguintes decisões:

### 3.1. DDL (`grupo10/sql/01_esquema.sql`)
- **Remoção de `IF NOT EXISTS`:** removido das 5 tabelas de Comércio e Finanças (`pedido`, `item_pedido`, `avaliacao_loja`, `avaliacao_entregador`, `divisao_pagamento`) para padronizar com as demais 15 tabelas e garantir falha explícita caso o script seja executado em banco não vazio.
- **Ações referenciais explícitas (`ON UPDATE` / `ON DELETE`):** declaradas explicitamente em todas as FKs de Comércio e Finanças (`ON UPDATE RESTRICT ON DELETE RESTRICT`), alinhando com Logística e Auditoria.
  - *Justificativa do contraste entre subdomínios:* tabelas de composição/especialização em Identidade e Catálogo usam `ON DELETE CASCADE` (ex.: excluir `pessoa` remove `telefone`, `pessoa_endereco`, `entregador`, `cliente`, `lojista`; excluir `produto` remove `produto_categoria`) e `ON UPDATE CASCADE` no Catálogo; já tabelas transacionais e históricas (`pedido`, `item_pedido`, `avaliacao_*`, `divisao_pagamento`, `rota`, `entrega`, `historico_*`) usam `ON DELETE RESTRICT ON UPDATE RESTRICT` para impedir perda de histórico financeiro, logístico ou de auditoria.
- **Padronização de prefixos:** unificação para `uq_*` (`uq_loja_cnpj`, `uq_produto_loja_produto`, `uq_categoria_loja_categoria`, `uq_pedido_loja`) e `ck_*` (`ck_historico_pedido_data_hora`, `ck_historico_entrega_data_hora`).
- **Aderência estrita ao relatório:** não foram adicionados `CHECK (btrim(nome) <> '')` em `loja`/`produto`/`categoria` nem regex em `loja.telefone`, pois o `relatorioGrupo10.md` não especifica essas restrições no DDL (apenas CPF, CNPJ, CEP, UF e notas `RR15`).

### 3.2. Carga (`grupo10/sql/02_carga.sql`)
- **Reprodutibilidade (`SELECT setseed(0.42);`):** adicionada semente fixa no início do script para tornar a geração pseudoaleatória 100% determinística entre execuções, preservando distribuições realistas sem introduzir padrões periódicos artificiais nos experimentos de desempenho.
- **CEP compartilhado em `endereco`:** substituídos os 330 CEPs distintos por 10 CEPs compartilhados (1 por bairro), evidenciando a dependência transitiva `cep -> cidade, estado` que justifica a normalização discutida no relatório.
- **Eliminação de bloat em `pedido`:** em vez de inserir `subtotal = 0.00` e executar `UPDATE pedido` após `item_pedido` (o que duplicava a tabela para ~6.056 páginas e ~199.834 *dead rows*, distorcendo experimentos), os pedidos e itens são preparados em tabelas temporárias (`carga_comercio_pedidos` e `carga_comercio_itens` com `ON COMMIT DROP`) e inseridos já com `subtotal` e `valor_total` calculados (`3.029` páginas e `0` *dead rows*).
- **Transação única em Comércio e Finanças:** bloco envolvido por `BEGIN;` e `COMMIT;` para evitar carga parcial em caso de erro.
- **Coerência temporal e de domínio:**
  - `lojas_ativas` filtra `l.status_funcionamento = 'aberta'` (aderência à regra de loja aberta / `RN01`–`RR04`).
  - `pedido.status` sorteia todos os 7 valores de `status_pedido` (incluindo `'pago'` e `'recusado'`).
  - `entrega.previsao_entrega` (`p.data_pedido + INTERVAL '45 minutes'`) e `rota.criada_em` / `encerrada_em` são derivados de `data_pedido` (não de `CURRENT_TIMESTAMP`), eliminando desvios de meses no histórico.
  - `divisao_pagamento.calculada_em` (`+65 min` + offset) e `avaliacao_*.data_avaliacao` (`+2h` + offset) ocorrem sempre após o evento `'entregue'`.
  - Rotas abertas (`encerrada_em IS NULL`) limitadas a no máximo 1 por entregador (com até 2 entregas, `RR02`), removendo o `INSERT INTO rota` avulso.
  - Documentado em comentário que `0.85` na divisão de pagamento é parâmetro fixo de regra de negócio da plataforma (não atributo armazenado no banco).
- **Estatísticas globais (`ANALYZE;`):** removidos os `ANALYZE VERBOSE` por subdomínio e mantido apenas um `ANALYZE;` global como última linha do script, conforme solicitado no enunciado da E4.

### 3.3. Verificação (`grupo10/sql/03_verificacao.sql`)
- **Escopo estrito da E4:** removidos os testes dependentes de gatilhos da E6 (como imutabilidade de `historico_*` — `RN08`/`RR11`, e regras de gatilho `RN02`/`RN04`/`RN12`/`RN13`), que pertencem ao `06_triggers.sql`.
- **Cobertura completa do DDL e `SQLSTATE`:** adicionados `SQLSTATE esperado` em todos os testes e os testes faltantes (`ck_pessoa_nome`, `ck_pessoa_email`, `ck_telefone_numero`, `uq_endereco_logradouro_numero_cep`, `ck_loja_cnpj` 13 dígitos, `ck_pedido_taxa_entrega`, `ck_pedido_taxa_servico`, `fk_pedido_loja/cliente/endereco`, negativos de `divisao_pagamento`, PKs duplicadas de avaliações).
- **Testes independentes de IDs aleatórios:** substituídos IDs fixos frágeis (`54411`, `272`, `3`) por subconsultas determinísticas (`SELECT ... LIMIT 1`), garantindo zero falsos positivos (`UPDATE 0`, `UPDATE 1`, `INSERT 0 1`).
- **Demonstração de ações referenciais:** incluídos cenários isolados em `BEGIN; ... ROLLBACK;` de `ON DELETE CASCADE` (`pessoa` -> `telefone`/`pessoa_endereco`/papéis e `produto` -> `produto_categoria`) e teste de `ON UPDATE RESTRICT` em `pessoa_endereco -> cliente` (colunas `GENERATED ALWAYS AS IDENTITY` não aceitam `UPDATE` direto na própria PK no PostgreSQL 18).
- **Alinhamento de comentários ao relatório:** removidas todas as referências internas (`ADR-*`, `RR16`, `RR17`, `Seção 2.3/2.4/2.5`, `Seção 1`), citando exclusivamente as regras (`RN`/`RR`) e a Seção 2 do relatório.
