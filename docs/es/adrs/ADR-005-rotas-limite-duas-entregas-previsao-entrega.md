# ADR-005: Rotas, limite de duas entregas e previsão de entrega

## Status

Aceito

## Data

31/10/26 (Marco E2)

## Rastreabilidade e Escopo

- **Origem:** Comentário do professor na correção da E1 — contar linhas de outra tabela não é suportado em cláusula `CHECK`, devendo ser implementado via gatilho (**RN02**).
- **Requisitos e Regras Relacionadas:** RF04, RN02, RN03, RN12.
- **Relações Afetadas:** `Rota`, `Entrega`, `Loja`.

## Contexto

O entregador pode agrupar até duas entregas simultâneas em uma mesma `Rota` (**RN02**), sendo que cada `Entrega` corresponde a um único `Pedido` (1:1).

- O escopo do projeto não inclui integração com mapas ou rastreamento GPS em tempo real, mas o sistema precisa determinar objetivamente quando uma entrega está **atrasada**, pois a **RN03** impede que o entregador assuma uma segunda entrega caso possua entrega em atraso.

## Decisão

1. **Associação Entrega–Rota:**
   - `Entrega` possui relacionamento 1:1 com `Pedido` (`id_pedido` `UNIQUE NOT NULL`).
   - A `Entrega` nasce com `id_rota` nulo (`aguardando_entregador`) e recebe o `id_rota` somente quando um entregador a assume.
2. **Limite de duas entregas por rota (`RN02`):**
   - Implementado por **gatilho (`TRIGGER`)** em `Entrega`, que contabiliza quantas entregas já estão vinculadas àquele `id_rota` antes de permitir a vinculação.
   - Para evitar condição de corrida (_race condition_) entre transações concorrentes, o gatilho deve realizar bloqueio na linha da rota (`SELECT ... FOR UPDATE` em `Rota`).
3. **Cálculo de previsão de entrega e conceito de atraso (`RN03`):**
   - Ao criar a `Entrega` (quando o pedido fica `pronto`), grava-se o atributo `previsao_entrega` somando o `tempo_entrega_estimado` (em minutos, cadastrado na `Loja`) ao instante em que o pedido ficou pronto.
   - Uma entrega é considerada **atrasada** quando o horário atual ultrapassa `previsao_entrega` e seu status ainda é diferente de `entregue`.
   - A verificação da **RN03** (impedir segunda entrega se houver atraso) fica sob responsabilidade da camada de aplicação.

## Alternativas Consideradas

### 1. Coluna de posição na Entrega (`posicao_rota IN (1, 2)` com `UNIQUE (id_rota, posicao_rota)`)

- **Prós:** Garantiria o limite de duas entregas por rota puramente via DDL (`CHECK` + `UNIQUE`), sem necessidade de gatilho.
- **Contras:** Na correção da E1, o professor classificou explicitamente a **RN02** como regra a ser implementada via gatilho.
- **Motivo do descarte:** Alinhamento com a diretriz de avaliação da disciplina (mantida como alternativa documentada caso necessário).

### 2. Prazo fixo global hardcoded na aplicação

- **Prós:** Não exigiria a coluna `tempo_entrega_estimado` na tabela `Loja`.
- **Contras:** Desconsidera que lojas de nichos diferentes (ex.: lanchonete rápida vs. restaurante artesanal) possuem tempos médios distintos.
- **Motivo do descarte:** Menor aderência ao domínio real.

### 3. Estimativa dinâmica por distância/GPS

- **Prós:** Maior precisão logística.
- **Contras:** Exige geocodificação e integração com APIs externas de rotas/mapas.
- **Motivo do descarte:** Explicitamente fora do escopo do projeto.

## Consequências

### Positivas

- Critério determinístico e simples para identificar entregas atrasadas (**RN03**), configurável por loja e independente de APIs externas de geolocalização.

### Negativas / Trade-offs

- `previsao_entrega` funciona como um snapshot calculado na criação da entrega: alterar o `tempo_entrega_estimado` da loja posteriormente não recalcula entregas já geradas.
- O gatilho da **RN02** exige atenção ao controle de concorrência (lock na linha de `Rota`).
- A estimativa por loja não diferencia a distância específica do endereço do cliente dentro da cidade.
