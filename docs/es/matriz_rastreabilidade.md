# Matriz de Rastreabilidade Bidirecional

> **O que é:** Um artefato formal de Engenharia de Requisitos que mapeia a vida de cada necessidade do sistema, conectando a especificação funcional aos artefatos físicos de banco de dados e linhas de código da aplicação.

| ID Requisito | Descrição Resumida | Destino (E1 BD) | Artefato Físico / Localização | Status |
| :--- | :--- | :--- | :--- | :--- |
| **RF01** | O sistema deve permitir a criação de pedidos vinculando cliente, estabelecimento e itens | Aplicação / DDL | `grupoNN/sql/01_esquema.sql`, `grupoNN/app/backend/.../PedidoController.java` | Planejado |
| **RF02** | O sistema deve permitir o rastreamento parametrizado de pedidos por identificador | Aplicação / SQL | `grupoNN/sql/04_consultas.sql`, `grupoNN/app/frontend/.../ConsultarPedidoView.tsx` | Planejado |
| **RF03** | O sistema deve listar pedidos disponíveis para aceitação por entregadores | Aplicação / SQL | `grupoNN/sql/05_visoes.sql`, `grupoNN/app/frontend/.../PainelEntregadorView.tsx` | Planejado |
| **RF04** | O sistema deve gerar relatórios consolidados de vendas por estabelecimento parceiro | Aplicação / SQL | `grupoNN/sql/05_visoes.sql`, `grupoNN/app/frontend/.../RelatorioLojaView.tsx` | Planejado |
| **RN01** | Um entregador não pode aceitar uma nova corrida se já possuir uma com status 'EM_TRANSITO' | Gatilho (Trigger) | `grupoNN/sql/06_triggers.sql` (`trg_valida_corrida_duplicada`), `03_verificacao.sql` | Planejado |
| **RN02** | O valor unitário de um item no catálogo e no pedido deve ser estritamente maior que zero | DDL (Restrição) | `grupoNN/sql/01_esquema.sql` (`CHECK (preco_unitario > 0)`), `03_verificacao.sql` | Planejado |
| **RN03** | O campo de documento (CPF ou CNPJ) deve ser validado quanto ao formato antes da submissão | Código da Aplicação | `grupoNN/app/frontend/.../schemas/pedidoSchema.ts` (Zod), `backend/.../dto/` | Planejado |
| **RN04** | A alteração de status de um pedido deve registrar uma tupla imutável com carimbo temporal | Gatilho / DDL | `grupoNN/sql/01_esquema.sql` (tabela `historico_status`), `06_triggers.sql` | Planejado |
| **RNXX** | [...] | Onde vai ser Implementado | Arquivo e localização no Codigo | Status |