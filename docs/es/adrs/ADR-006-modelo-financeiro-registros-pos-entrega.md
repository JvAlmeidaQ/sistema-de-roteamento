# ADR-006: Modelo financeiro e registros pós-entrega (divisão e avaliações)

## Status

Aceito

## Data

31/10/26 (Marco E2)

## Rastreabilidade e Escopo

- **Origem:** Especificação dos requisitos financeiros e de avaliação da E1 (**RF08**, **RF09**, **RN05**, **RN06**, **RN13**), tendo o modelo operacional do iFood como referência de domínio.
- **Requisitos e Regras Relacionadas:** RF08, RF09, RN05, RN06, RN13.
- **Relações Afetadas:** `Pedido`, `Divisao_Pagamento`, `Avaliacao_Loja`, `Avaliacao_Entregador`, `Loja`.

## Contexto

O sistema precisa discriminar, para cada pedido entregue, a parcela financeira destinada à loja, a comissão do entregador e a taxa retida pela plataforma (**RF09**), garantindo que a soma das três partes seja exatamente igual ao valor total pago pelo cliente (**RN05**). Além disso, após a conclusão da entrega, o cliente pode avaliar separadamente a loja e o entregador com nota de 1 a 5 (**RF08**, **RN06**, **RN13**).

## Decisão

1. **Composição do valor total do Pedido:**
   - `valor_total = subtotal + taxa_entrega + taxa_servico` (garantido por restrição `CHECK` em `Pedido`).
   - `taxa_entrega`: valor fixo definido por cada `Loja`, válido para qualquer endereço na cidade.
   - `taxa_servico`: valor fixo cobrado pela plataforma, gravado no pedido.
2. **Regra de Divisão de Pagamento (Split Financeiro):**
   - `parcela_loja`: `subtotal` menos o valor retido pela plataforma (percentual sobre o subtotal).
   - `comissao_entregador`: recebe integralmente o valor da `taxa_entrega`.
   - `taxa_plataforma`: `taxa_servico` somada ao valor retido do `subtotal`.
   - O percentual de retenção da plataforma é um **parâmetro único da aplicação** (igual para todas as lojas), não uma coluna de configuração por loja.
3. **Persistência e Validação em `Divisao_Pagamento`:**
   - A aplicação calcula e insere o registro em `Divisao_Pagamento` (relação 1:1 com `Pedido`, PK `id_pedido`) **somente quando a entrega atinge o status `entregue`**.
   - `Divisao_Pagamento` armazena uma cópia de `valor_total` para viabilizar declarativamente em DDL a restrição `CHECK (parcela_loja + comissao_entregador + taxa_plataforma = valor_total)` (**RN05**), acompanhada de gatilho que confere a igualdade desse `valor_total` com o registrado em `Pedido`.
4. **Pagamento como etapa do Pedido:**
   - O pagamento é representado pela transição para o status `pago` no próprio `Pedido` e pelo atributo `forma_pagamento`, sem criar uma entidade `Pagamento` separada.
5. **Avaliações pós-entrega (`Avaliacao_Loja` e `Avaliacao_Entregador`):**
   - Modeladas em duas tabelas independentes, cada uma com chave primária `id_pedido` (permitindo no máximo uma avaliação de loja e uma de entregador por pedido).
   - Restrição `CHECK (nota BETWEEN 1 AND 5)` (**RN06**) em ambas as tabelas.
   - Gatilho garante que avaliações só possam ser inseridas se a entrega correspondente estiver no status `entregue` (**RN13**).
   - A loja e o entregador avaliados são identificados por navegação a partir de `id_pedido`, sem duplicar chaves estrangeiras diretas para `Loja` ou `Entregador`.

## Alternativas Consideradas

### 1. Relacionamento ternário `Pedido–Loja–Entregador` para a divisão de pagamento

- **Prós:** Liga diretamente os três participantes financeiros na tabela de divisão.
- **Contras:** Como `Pedido` já determina univocamente a `Loja` e (por meio de `Entrega` e `Rota`) o `Entregador`, incluir `id_loja` e `id_entregador` em `Divisao_Pagamento` geraria dependências transitivas desnecessárias.
- **Motivo do descarte:** Derivável sem perda a partir de `id_pedido`.

### 2. Percentual de comissão variável por loja

- **Prós:** Maior flexibilidade comercial (similar a planos diferenciados de marketplace).
- **Contras:** Adiciona atributos e regras extras não exigidos pelos requisitos do trabalho.
- **Motivo do descarte:** Parâmetro global na aplicação atende integralmente ao **RF09** com menor complexidade.

### 3. Entidade `Pagamento` separada de `Pedido`

- **Prós:** Permitiria múltiplas tentativas de pagamento, estornos parciais ou divisão em múltiplos cartões.
- **Contras:** Reembolso, estorno e múltiplos meios de pagamento por pedido estão fora do escopo definido na E1.
- **Motivo do descarte:** Sobre-engenharia para o escopo atual.

### 4. Tabela única `Avaliacao` com duas notas (`nota_loja` e `nota_entregador`)

- **Prós:** Uma tabela a menos no esquema.
- **Contras:** O cliente pode optar por avaliar apenas a loja, apenas o entregador, ou realizá-las em momentos distintos; juntar em uma tabela exigiria colunas anuláveis e regras condicionais mais confusas.
- **Motivo do descarte:** Duas tabelas refletem melhor a independência entre a avaliação comercial e a logística.

## Consequências

### Positivas

- A soma exata do split financeiro (**RN05**) e os limites de notas de avaliação (**RN06**) são garantidos declarativamente via `CHECK` no DDL.
- Preservação histórica: alterações futuras no percentual da plataforma não afetam divisões já registradas em `Divisao_Pagamento`.

### Negativas / Trade-offs

- `valor_total` é repetido em `Divisao_Pagamento` exclusivamente para viabilizar o `CHECK` da **RN05** em nível de linha (redundância controlada e declarada na documentação de normalização).
- Cenários de entrega não realizada, devolução e reembolso financeiro não são contemplados pelo modelo.
