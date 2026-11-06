# ADR-004: Ciclos de status autônomos (Pedido e Entrega) com histórico imutável

## Status

Aceito

## Data

31/10/26 (Marco E2)

## Rastreabilidade e Escopo

- **Origem:** Introdução da E1 (processos comercial e logístico autônomos), **RF05**, **RF06**, **RN04**, **RN08** e **RN12**. Referência de mercado: separação entre fluxo do pedido na loja e eventos de logística da entrega.
- **Requisitos e Regras Relacionadas:** RF03, RF05, RF06, RN04, RN08, RN12.
- **Relações Afetadas:** `Pedido`, `Entrega`, `Historico_Pedido`, `Historico_Entrega`.

## Contexto

No domínio do sistema, o lojista é responsável pelo aceite e preparo do pedido (domínio comercial), enquanto o entregador é responsável pelo transporte (domínio logístico).

- A especificação exige que as duas áreas evoluam de forma autônoma, que toda mudança de status seja registrada em tabela de histórico (**RN04**) e que os registros de histórico sejam estritamente imutáveis (**RN08**).

## Decisão

Separar os ciclos de vida em duas máquinas de estados independentes, utilizando tipos `ENUM` do PostgreSQL e auditoria automática via gatilhos:

1. **Ciclo de status de `Pedido` (`status_pedido`):**
   - Fluxo: `solicitado` → (`recusado` | `aceito`) → `pago` → `em_preparacao` → `pronto` → `concluido`.
   - A loja decide (aceita ou recusa) **antes** do pagamento e só inicia o preparo após o status `pago`.
   - `recusado` e `concluido` são estados finais (pedidos recusados não exigem reembolso, pois o pagamento ainda não ocorreu).
2. **Ciclo de status de `Entrega` (`status_entrega`):**
   - Fluxo: `aguardando_entregador` → `aceita` → `a_caminho` → `entregue`.
   - A `Entrega` só é criada quando o `Pedido` atinge o status `pronto` (**RN12**).
   - Não há status de entrega não realizada ou devolução (fora do escopo do projeto).
3. **Pontos de sincronização entre os ciclos:**
   - Quando `Pedido` passa para `pronto`, nasce a `Entrega` em `aguardando_entregador`.
   - Quando `Entrega` passa para `entregue`, o `Pedido` é atualizado para `concluido` e a divisão de pagamento é habilitada.
4. **Tabelas de Histórico e Imutabilidade:**
   - `Historico_Pedido (id_pedido, status, data_hora)` e `Historico_Entrega (id_entrega, status, data_hora)`, onde a chave primária é composta por `(id_dono, status)`.
   - Preenchimento automático por **gatilho (`TRIGGER`)** a cada inserção ou alteração de status (**RN04**).
   - Operações de `UPDATE` e `DELETE` nas tabelas de histórico são bloqueadas por gatilho (**RN08**).
   - A validade das transições de estados é imposta por gatilho.

## Alternativas Consideradas

### 1. Status único na tabela `Pedido` englobando etapas logísticas

- **Prós:** Uma única coluna de status e uma única tabela de histórico no banco.
- **Contras:** Quebra a autonomia entre os domínios comercial e logístico, torna a entidade `Entrega` um mero agrupador sem ciclo de vida próprio e desalinha com **RF05**, **RF06** e **RN04**.
- **Motivo do descarte:** Viola a separação conceitual estabelecida desde a E1.

### 2. Chave primária artificial (`id_historico` ou `seq`) nas tabelas de histórico

- **Prós:** Permitiria que um pedido ou entrega passasse pelo mesmo status mais de uma vez.
- **Contras:** Como os fluxos definidos são estritamente progressivos (sem retrocesso de status), a chave natural `(id_dono, status)` é mais enxuta e impede registros duplicados acidentais para o mesmo estado.
- **Motivo do descarte:** A chave composta natural expressa melhor a regra do fluxo linear.

### 3. Registrar o autor da mudança de status no histórico

- **Prós:** Rastreabilidade de qual usuário executou a transição.
- **Contras:** Como o histórico é gravado por gatilho no banco, o SGBD conhece apenas a sessão de conexão da aplicação, não o `id_pessoa` autenticado (exigiria variáveis de sessão customizadas).
- **Motivo do descarte:** Fora do escopo; o ator responsável já é implícito pelo próprio estado do fluxo (loja vs. entregador).

### 4. Tabelas de domínio auxiliar em vez de `ENUM`

- **Prós:** Permite adicionar ou renomear status com `INSERT/UPDATE` simples.
- **Contras:** Como as máquinas de estados são fixas e validadas em código/gatilhos, tabelas extras apenas adicionariam `JOIN`s desnecessários.
- **Motivo do descarte:** O tipo `ENUM` do PostgreSQL oferece validação nativa e excelente legibilidade.

## Consequências

### Positivas

- Autonomia clara entre as responsabilidades da loja e do entregador.
- Rastreabilidade completa e à prova de adulteração garantida diretamente por gatilhos no SGBD (**RN04** e **RN08**).

### Negativas / Trade-offs

- Como a PK do histórico é `(id_dono, status)`, cada status só pode ocorrer **uma única vez** por pedido ou entrega. Caso o sistema futuramente passe a admitir retrocesso de estado, a chave primária deverá incluir `data_hora` ou um sequencial.
- Tipos `ENUM` no PostgreSQL permitem adição de novos valores, mas não remoção direta de valores existentes sem recriação do tipo.
- A ordem cronológica dos eventos deve ser lida pelo atributo `data_hora`.
