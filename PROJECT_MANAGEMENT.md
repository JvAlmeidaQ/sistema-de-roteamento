# 📋 Governança de Projeto, DoR e DoD

## Gestão do Projeto

Este documento reúne o modelo de trabalho, o cronograma, os critérios de qualidade (DoR e DoD) e os acordos de convivência da equipe no desenvolvimento do **Sistema de Roteamento de Pedidos**, projeto integrado das disciplinas **DCC060 (Banco de Dados)** e **DCC061 (Engenharia de Software)**.

---

## 1. Cronograma de Entregas

| Marco          | Data  | Escopo                                                             |
| -------------- | ----- | ------------------------------------------------------------------ |
| **E0** (BD)    | 10/09 | Equipe e tema aprovado                                             |
| **E1** (BD)    | 24/09 | Requisitos e regras de negócio (Seções 1 e 2)                      |
| **E2** (BD)    | 16/10 | DER, modelo lógico e normalização (Seção 3)                        |
| **E3** (BD)    | 06/11 | Consultas em álgebra relacional (Seção 4)                          |
| **E4** (BD)    | 13/11 | DDL, carga (200k+ linhas) e verificação (Seção 5)                  |
| **E5** (BD)    | 27/11 | Consultas SQL e visões (Seções 6 e 7.1)                            |
| **Final** (ES) | 29/11 | Entrega final de Engenharia de Software                            |
| **E6** (BD)    | 11/12 | Gatilhos, índices e relatório consolidado (Seções 7.2, 7.3, 8 e 9) |

---

## 2. Modelo de Processo e Fluxo de Trabalho

- **Metodologia:** desenvolvimento iterativo e incremental, guiado pelos marcos da tabela acima. Não há sprints de duração fixa.
- **Gestão de tarefas:** todas as atividades são mapeadas como cartões no **GitHub Projects** da equipe. Hoje os cartões são Drafts e serão convertidos em Issues quando o grupo julgar adequado.
- **Rastreabilidade de commits:** cada commit e Pull Request referencia a issue correspondente do Backlog.
  - Padrão: `tipo(escopo): descrição [#CARD-XX]`
  - Exemplo: `feat(ddl): implementa constraints de preco_unitario [#CARD-08]`
  - Após a conversão dos cartões em Issues, passa-se a referenciar o número da Issue (`#N`).

---

## 3. Definition of Ready (DoR): critérios para iniciar uma tarefa

Uma tarefa só sai de `Backlog` para `A Fazer` quando atender a todos os itens:

1. **Identificação e escopo:** título claro, descrição objetiva do entregável e responsável atribuído.
2. **Vínculo com a entrega oficial:** indica a qual marco pertence (E1 a E6 de BD ou a entrega final de ES).
3. **Mapeamento de requisito:** tarefas de modelagem, banco ou tela indicam o requisito correspondente (`RFxx` ou `RNyy`). Este item passa a valer assim que os requisitos forem mapeados (E1-BD).
4. **Camada definida:** para regras de negócio, a camada de implementação (`DDL`, `Gatilho` ou `Aplicação`) já terá sido decidida na (E1-BD).

---

## 4. Definition of Done (DoD): critérios para concluir uma tarefa

Uma tarefa só vai para `Concluído`, e seu Pull Request só entra em `develop`, quando atender aos **critérios comuns** e aos **critérios do tipo de artefato** produzido.

### 4.1 Critérios comuns (todas as tarefas)

1. **Revisão por pares:** o PR foi analisado e aprovado por pelo menos um colega da equipe.
2. **CI verde:** o PR passa sem ressalvas pelo pipeline do GitHub Actions (`ci.yml`).
3. **Conformidade de pastas:** a estrutura e a nomenclatura dos arquivos dentro de `grupoNN/` respeitam a árvore exigida na Seção 2 do edital de BD.
4. **Rastreabilidade atualizada:** a `docs/es/matriz_rastreabilidade.md` reflete o artefato produzido e o status da entrega (aplicável a partir do mapeamento dos requisitos).

### 4.2 Scripts SQL (DDL, carga, consultas, visões, gatilhos, índices)

- Todos os scripts executam do zero, sem erros de sintaxe ou integridade, a partir de um banco vazio no PostgreSQL 18 via Docker. O CI já faz essa verificação.
- Para a carga (E4), o volume mínimo de 200k+ linhas deve ter sido atingido e verificado.

### 4.3 Aplicação (Spring)

- Quando o CI passar a executar a aplicação (`mvn`), o build e a inicialização ocorrem sem erros.

---

## 5. Política de Branches, Versionamento e Releases

### 5.1. Política de Branches

- `main`: contém somente versões consolidadas para entrega oficial de Engenharia de Software.
- `main-bd`: ramo de trabalho oficial para as etapas de Banco de Dados após a entrega de Engenharia de Software.
- `develop`: ramo de integração do time.
- `feature/<nome-da-tarefa>`: branches temporárias criadas a partir de `develop`, uma por tarefa.

**Fluxo de integração:** o autor faz o merge da feature em `develop` após a aprovação do PR e a execução bem-sucedida do CI. A promoção de `develop` para `main` ocorre somente na entrega de um marco, por meio de Pull Request. A tag correspondente é criada sobre o commit de merge em `main`.

### 5.2. Política de Versionamento Semântico

O projeto adota uma adaptação do padrão **Semantic Versioning (SemVer)**, utilizando o formato:

`vX.Y.Z-<disciplina>-<marco>`

Essa convenção permite identificar a evolução técnica do projeto e, simultaneamente, associar cada versão à disciplina e ao marco acadêmico correspondente.

#### 5.2.1. Estrutura Numérica

- **X (Major):** representa grandes marcos arquiteturais ou fases do projeto, como mudanças estruturais significativas ou a consolidação de uma nova fase.
- **Y (Minor):** representa a conclusão de Sprints, a inclusão de novas funcionalidades ou a consolidação de entregas parciais.
- **Z (Patch):** reservado para correções pontuais, _hotfixes_ ou pequenos ajustes que não alterem significativamente o escopo da versão.

#### 5.2.2. Sufixos de Identificação

Os identificadores de disciplina e marco são utilizados para distinguir as entregas acadêmicas:

- **Banco de Dados (DCC060):** `-bd-<marco>`
  - `v1.0.0-bd-e1`
  - `v1.1.0-bd-e2`
  - `v2.0.0-bd-final`

- **Engenharia de Software (DCC061):** `-es-<marco>`
  - `v2.0.0-es-final`

### 5.3. Política de Releases Oficiais

Toda tag associada a uma submissão oficial deve ser promovida a uma **GitHub Release** no repositório.

A Release constitui a **linha de base (baseline)** auditável daquela entrega e deve permanecer vinculada ao commit identificado pela respectiva tag.

Cada Release oficial deve conter:

1. **Release Notes:** resumo dos principais artefatos produzidos, alterações realizadas e requisitos atendidos na versão.
2. **Relatório:** arquivo `relatorio.pdf` correspondente à entrega.
3. **Código-fonte:** arquivo `grupoNN.zip`, gerado pelo script oficial de submissão.

Os assets da Release devem representar exatamente o estado do projeto correspondente à tag, permitindo que os avaliadores obtenham os artefatos da entrega sem depender de compilações ou preparações manuais adicionais.

---

## 6. Acordos de Convivência

- **Comunicação:** o canal oficial da equipe é o grupo do WhatsApp.
- **Revisão de PR:** prazo máximo de **2 dias** para o primeiro retorno do revisor. Se o prazo estourar, o autor avisa no grupo e outro integrante assume a revisão.
- **Autonomia:** cada integrante pode pegar tarefas que estejam em `A Fazer`, desde que registre o responsável no cartão antes de começar.
