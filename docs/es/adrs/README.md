# ADRs — Registros de Decisão Arquitetural

**Disciplinas:** DCC060 (Banco de Dados) & DCC061 (Engenharia de Software) · **Sistema de Roteamento de Entregas**

## Sobre este Diretório

Um **Architecture Decision Record (ADR)** registra uma decisão arquitetural ou de modelagem relevante, o contexto e as restrições em que ela foi tomada, as alternativas que foram consideradas (e descartadas) e as consequências (positivas e trade-offs) assumidas pela equipe.

Estes registros atendem diretamente ao **Tema 2 de Engenharia de Software (Gerência de Configuração e Manutenção do Software)** e à **Engenharia de Requisitos (Tema 1)**, garantindo que:
- Novos integrantes, avaliadores e agentes compreendam o **porquê** o modelo de dados e a arquitetura foram construídos desta forma.
- Decisões de design (como desnormalizações controladas para garantir integridade em DDL ou separação de máquinas de estados) tenham rastreabilidade explícita até os Requisitos Funcionais (`RF`) e Regras de Negócio (`RN`).

> **Ordem de leitura recomendada:** Leia primeiro o [Glossário de Domínio](../glossario_de_dominio.md), o [Modelo de Domínio](../modelo_dominio.md) e o [Dicionário de Dados](../dicionario_dados.md), pois os ADRs referenciam entidades, atributos e regras definidos nesses artefatos. Para ver como cada decisão é validada em código e no SGBD, consulte a [Especificação de Validações](../especificacao_validacoes.md).

---

## Índice de ADRs

| ID | Título da Decisão | Status | Marco | Requisitos / Regras Impactados |
| :--- | :--- | :---: | :---: | :--- |
| **[ADR-001](./ADR-001-integridade-loja-chaves-estrangeiras-compostas.md)** | Integridade de loja via chaves estrangeiras compostas | Aceito | E2 | RF02, RN07 |
| **[ADR-002](./ADR-002-snapshots-historicos-pedido-enderecos-imutaveis.md)** | Snapshots históricos no pedido e endereços imutáveis | Aceito | E2 | RF01, RF02, RF09, RN05, RN09 |
| **[ADR-003](./ADR-003-especializacao-pessoa-cardinalidade-minima.md)** | Especialização de Pessoa e regras de cardinalidade mínima | Aceito | E2 | RF01, RF02, RN10, RN11 |
| **[ADR-004](./ADR-004-ciclos-status-autonomos-historico-imutavel.md)** | Ciclos de status autônomos (Pedido e Entrega) com histórico imutável | Aceito | E2 | RF03, RF05, RF06, RN04, RN08, RN12 |
| **[ADR-005](./ADR-005-rotas-limite-duas-entregas-previsao-entrega.md)** | Rotas, limite de duas entregas e previsão de entrega | Aceito | E2 | RF04, RN02, RN03, RN12 |
| **[ADR-006](./ADR-006-modelo-financeiro-registros-pos-entrega.md)** | Modelo financeiro e registros pós-entrega (divisão e avaliações) | Aceito | E2 | RF08, RF09, RN05, RN06, RN13 |

---

## Ciclo de Vida de um ADR

```text
PROPOSTO → ACEITO → (SUBSTITUÍDO POR ADR-XXX | DEPRECIADO)
```

- **Nunca apague ADRs antigos:** eles preservam o contexto histórico da evolução do projeto.
- Quando uma decisão arquitetural mudar, crie um novo ADR na sequência numérica (`ADR-007`, etc.) referenciando o anterior e atualize o status do antigo para `Substituído por ADR-00X`.

---

## Decisões Ainda em Aberto (Para Próximos Marcos)

As seguintes definições herdadas da E2 poderão originar novos ADRs à medida que o modelo físico (E4) e a aplicação de Engenharia de Software avançarem:

1. **Valores definitivos dos tipos `ENUM`:** `forma_pagamento`, `tipo_telefone` e `tipo_veiculo`.
2. **Parâmetro de retenção da plataforma:** definição do percentual exato retido pela plataforma no cálculo do split financeiro.
3. **Estratégia de autenticação e credenciais:** definição de armazenamento de hash de senha (conforme **RNF03**) no modelo físico.
4. **Decomposição física de CEP:** decidir se o script DDL adotará uma relação separada para `Cep` (conforme discutido na normalização da E2) ou manterá `cep`, `cidade` e `estado` diretamente em `Endereco`.

---

## Template para Novos ADRs

Para criar um novo ADR neste diretório, utilize a nomenclatura `ADR-NNN-titulo-descritivo.md` e siga a estrutura abaixo:

```markdown
# ADR-NNN: Título curto da decisão

## Status
Proposto | Aceito | Substituído por ADR-XXX | Depreciado

## Data
YYYY-MM-DD

## Rastreabilidade e Escopo
- **Origem:** Motivação ou feedback que originou a discussão.
- **Requisitos e Regras Relacionadas:** RFxx, RNyy, RNFzz.
- **Relações / Componentes Afetados:** Tabelas, módulos ou serviços impactados.

## Contexto
Qual é o problema, restrição técnica ou necessidade de negócio que exige uma decisão?

## Decisão
O que foi decidido fazer e como funcionará?

## Alternativas Consideradas

### 1. Nome da alternativa
- **Prós:** ...
- **Contras:** ...
- **Motivo do descarte:** ...

## Consequências

### Positivas
- Benefícios diretos alcançados com a escolha.

### Negativas / Trade-offs
- Custos técnicos, redundâncias assumidas ou cuidados exigidos na manutenção.
```
