---
name: "Sistema de Roteamento de Pedidos"
description: "Linguagem visual de um sistema de gerenciamento e roteamento de pedidos. Uma interface leve, moderna e funcional que combina verde-lima, verde-escuro e a dupla tipográfica Fustat e Inter Tight, priorizando clareza operacional, produtividade e facilidade de navegação."
colors:
  brand:
    lime: "#9EEA6C"
    green: "#58C411"
    darkGreen: "#244C4E"
    pulp: "#89BA4F"
    outline: "#337D63"
    pit: "#804B35"
  semantic:
    action: "#9EEA6C"
    emphasis: "#58C411"
    textStrong: "#244C4E"
    text: "#4C5267"
    background: "#E2E7F1"
    surface: "#FFFFFF"
typography:
  headline:
    fontFamily: "Fustat, sans-serif"
    fontWeight: 600
    letterSpacing: "-0.03em"
  body:
    fontFamily: "Inter Tight, sans-serif"
    fontWeight: 500
    lineHeight: 1.8
rounded:
  sm: "8px"
  md: "16px"
  lg: "24px"
  pill: "999px"
spacing:
  xs: "8px"
  sm: "16px"
  md: "24px"
  lg: "32px"
  xl: "48px"
---

# Sistema de Roteamento de Pedidos

## Overview

O **Sistema de Roteamento de Pedidos** é uma plataforma voltada à organização, distribuição, acompanhamento e gerenciamento de pedidos ao longo de seu fluxo operacional.

Sua identidade visual privilegia uma comunicação simples, amigável e reconhecível. O verde-lima destaca ações importantes; o verde-escuro organiza títulos, navegação e elementos de alto contraste; e os tons suaves mantêm a interface leve e confortável durante o uso prolongado.

O sistema deve transmitir eficiência, organização e confiabilidade, evitando excesso de elementos visuais e priorizando a apresentação clara das informações.

A experiência deve permitir que usuários identifiquem rapidamente pedidos, compreendam seus estados, realizem ações e acompanhem o andamento das operações com o menor esforço possível.

A personalidade visual vem da combinação de cores naturais, formas arredondadas e uma estrutura minimalista, sem depender de efeitos visuais pesados.

### Princípios de design

1. **Clareza antes do detalhe** — apresente as informações mais importantes de cada pedido antes dos dados secundários.
2. **Verde com função** — reserve o verde-lima para ações principais, destaques e interações relevantes.
3. **Contraste preservado** — utilize o verde-escuro em títulos, textos importantes e elementos estruturais.
4. **Leveza estrutural** — superfícies brancas, fundos azul-acinzentados e bordas discretas reduzem a sobrecarga visual.
5. **Eficiência operacional** — minimize a quantidade de interações necessárias para localizar, rotear e gerenciar pedidos.
6. **Consistência de estados** — apresente informações de status, prioridade e andamento de maneira uniforme.
7. **Feedback imediato** — toda ação operacional deve apresentar confirmação visual clara.
8. **Interface orientada a dados** — priorize legibilidade, organização e hierarquia em tabelas, listas, filtros e painéis.

---

## Feature Flags & Discipline Headers

Este projeto atende simultaneamente às disciplinas **DCC060 (Banco de Dados — BD)** e **DCC061 (Engenharia de Software — ES)** em um único monorepo, utilizando *feature flags* de compilação no frontend (**RNF02**) e cabeçalhos explícitos de identificação nos arquivos.

### Confirmação obrigatória da disciplina

> [!IMPORTANT]
> **Antes de criar qualquer novo arquivo, tela, componente ou documento**, o autor (humano ou agente) deve **sempre confirmar explicitamente** a qual disciplina o artefato pertence: **BD (`DCC060`)**, **ES (`DCC061`)** ou **ambas (`BD & ES`)**. Nunca assuma o escopo sem confirmar.

### Feature flags (`VITE_APP_MODE`)

O controle de visibilidade de rotas, menus e componentes no frontend (`grupo10/app/frontend/`) é feito pela variável de ambiente `VITE_APP_MODE` (`.env.bd` e `.env.full`), com *tree-shaking* automático em tempo de build pelo Vite:

| Modo (`VITE_APP_MODE`) | Disciplina | Escopo na interface |
| :--- | :--- | :--- |
| `bd` | **DCC060 (Banco de Dados)** | Modo estrito: exibe apenas as telas essenciais exigidas pelo edital de BD para comprovar inserções/transações reais e visualizar relatórios/visões SQL (`/` e `/relatorios`). |
| `full` | **DCC061 (Engenharia de Software)** | Modo completo: inclui todas as jornadas de Cliente, Lojista e Entregador (catálogo, criação de pedido, preparo, rotas, rastreio e avaliações). |

**Padrão de uso no código:**

```tsx
// Em modo 'bd', isBd é substituído estaticamente por true no bundle final (build:bd)
const isBd = import.meta.env.VITE_APP_MODE === 'bd'
```

- Componentes e rotas exclusivos de ES devem ser condicionados a `!isBd` para que sejam removidos do bundle final ao executar `npm run build:bd`.
- Elementos de navegação (barra lateral, atalhos do dashboard e ações rápidas) devem respeitar a mesma flag, evitando exibir links para rotas desabilitadas no modo `bd`.

### Cabeçalhos por disciplina

Todo arquivo destinado a uma disciplina específica (ou compartilhado entre ambas) deve declarar essa informação logo no cabeçalho, seguindo o padrão do tipo de arquivo:

- **Documentos Markdown (`docs/`):** incluir logo abaixo do título principal:
  - Exclusivo de BD: `**Disciplina:** DCC060 (Banco de Dados) · **Modo:** \`VITE_APP_MODE=bd\``
  - Exclusivo de ES: `**Disciplina:** DCC061 (Engenharia de Software) · **Modo:** \`VITE_APP_MODE=full\``
  - Compartilhado: `**Disciplinas:** DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)`
- **Componentes, páginas e módulos de código (`.ts`, `.tsx`, `.java`, `.sql`):** incluir comentário de cabeçalho no topo do arquivo indicando a disciplina e, no frontend, a flag aplicável:

```tsx
/**
 * Disciplina: DCC061 (Engenharia de Software)
 * Feature Flag: VITE_APP_MODE=full (!isBd)
 */
```

```sql
-- Disciplina: DCC060 (Banco de Dados)
```

---

## Colors

### Paleta principal

| Token | Hex | Uso |
| :--- | :--- | :--- |
| `brand.lime` | `#9EEA6C` | Ações principais, botões e destaques |
| `brand.green` | `#58C411` | Ênfase, indicadores e links |
| `brand.darkGreen` | `#244C4E` | Títulos, navegação e fundos escuros |
| `brand.pulp` | `#89BA4F` | Acentos complementares e elementos ilustrativos |
| `brand.outline` | `#337D63` | Contornos e elementos secundários |
| `brand.pit` | `#804B35` | Acentos complementares de uso restrito |
| `text.default` | `#4C5267` | Parágrafos, descrições e informações secundárias |
| `surface.background` | `#E2E7F1` | Fundo estrutural das páginas |
| `surface.default` | `#FFFFFF` | Cards, formulários e superfícies |

### Aplicação de cor

- Use `#9EEA6C` para ações principais, como criar, atribuir, confirmar ou encaminhar pedidos.
- Use `#244C4E` como cor de texto de alto contraste, títulos e elementos de navegação.
- Use `#4C5267` no corpo do texto, descrições e informações complementares.
- Equilibre áreas brancas com `#E2E7F1` nos planos de fundo.
- Utilize bordas discretas para separar informações sem criar excesso de elementos.
- Evite utilizar verde-lima em grandes áreas de texto.
- Não introduza degradês ou cores concorrentes sem necessidade funcional.

### Cores de estado

Além da paleta principal, o sistema pode utilizar cores semânticas para representar situações operacionais.

| Estado | Cor sugerida | Uso |
| :--- | :--- | :--- |
| Pendente | `#D9A441` | Pedidos aguardando processamento |
| Em andamento | `#337D63` | Pedidos em processamento ou roteamento |
| Concluído | `#58C411` | Pedidos finalizados com sucesso |
| Cancelado | `#D46A6A` | Pedidos cancelados |
| Erro | `#C74747` | Falhas ou ações que exigem atenção |
| Neutro | `#4C5267` | Informações sem estado operacional específico |

As cores semânticas devem ser utilizadas com moderação, preferencialmente em badges, ícones e indicadores.

**Nunca dependa exclusivamente da cor para transmitir um estado.** Utilize também rótulos textuais e, quando necessário, ícones.

---

## Typography

### Famílias

| Papel | Família | Especificação |
| :--- | :--- | :--- |
| Títulos | Fustat | Semibold, tracking apertado, verde-escuro |
| Texto | Inter Tight | Medium, entrelinha confortável, cinza `#4C5267` |

```css
font-family: "Fustat", sans-serif; /* títulos */
font-family: "Inter Tight", sans-serif; /* UI e corpo */
```

### Hierarquia sugerida

| Token | Tamanho | Peso | Uso |
| :--- | ---: | ---: | :--- |
| `display` | 48–64px | 600 | Apresentações e páginas introdutórias |
| `heading` | 28–40px | 600 | Títulos de páginas e seções |
| `title` | 20–24px | 600 | Títulos de componentes e cards |
| `body` | 16–18px | 500 | Textos explicativos |
| `label` | 12–14px | 600 | Labels, navegação e metadados |

### Diretrizes tipográficas

- Utilize títulos curtos, objetivos e facilmente identificáveis.
- Prefira linguagem direta e orientada à ação.
- Mantenha o texto em português brasileiro.
- Utilize `line-height` próximo de `1.8` para textos explicativos.
- Em tabelas e componentes densos, utilize entrelinhas mais compactas, preservando a legibilidade.
- Diferencie informações primárias e secundárias por tamanho, peso e contraste.
- Evite utilizar muitos pesos tipográficos diferentes na mesma tela.

### Formatação de dados

Informações operacionais devem seguir padrões consistentes:

- **Datas:** `DD/MM/AAAA`
- **Horários:** formato de 24 horas
- **Identificadores:** `#000123`
- **Quantidades:** números alinhados e facilmente comparáveis
- **Status:** rótulos curtos e padronizados
- **Responsáveis:** nomes legíveis, com informações complementares quando necessário

---

## Layout

O sistema utiliza composição arejada, grids responsivos e cartões com espaçamento interno confortável.

A interface deve equilibrar densidade informacional e facilidade de leitura, considerando que usuários podem trabalhar com grandes volumes de pedidos.

A escala principal de espaçamento segue incrementos de 8px: `8`, `16`, `24`, `32` e `48px`.

### Estrutura responsiva

- **Mobile:** margens laterais de 16–24px, ações acessíveis e componentes empilhados.
- **Tablet:** duas colunas quando apropriado, com navegação adaptável.
- **Desktop:** área central organizada, com largura adaptável ao conteúdo.
- **Tabelas:** podem ocupar larguras maiores para preservar a visibilidade das informações.
- **Bordas:** `#E2E7F1`, 1px, sem contrastes agressivos.

### Estrutura principal

A interface pode ser organizada em três regiões:

#### 1. Navegação

Responsável pelo acesso às principais áreas do sistema.

Exemplos:

- Dashboard
- Pedidos
- Roteamento
- Histórico
- Configurações

#### 2. Área de conteúdo

Apresenta as informações e ferramentas relacionadas à funcionalidade ativa.

Deve conter:

- Título da página
- Descrição breve, quando necessária
- Ação principal
- Filtros e ferramentas contextuais
- Conteúdo organizado em tabelas, cards ou painéis

#### 3. Área contextual

Utilizada para detalhes de pedidos, informações adicionais, histórico e ações específicas.

Pode ser apresentada por meio de:

- Drawers laterais
- Modais
- Painéis expansíveis
- Páginas de detalhes

### Densidade informacional

O sistema deve priorizar a visualização rápida de informações relevantes.

Evite distribuir informações essenciais entre várias telas quando elas puderem ser apresentadas claramente em uma única visualização.

Utilize espaçamento maior entre seções e espaçamento menor entre elementos diretamente relacionados.

---

## Elevation & Depth

A hierarquia visual é predominantemente plana.

Diferencie blocos utilizando fundo, borda e espaçamento antes de recorrer a sombras.

Quando necessárias, as sombras devem ser discretas e utilizadas principalmente em elementos flutuantes, menus e cards interativos.

```css
--shadow-low: 0 2px 8px rgba(36, 76, 78, 0.08);
--shadow-hover: 0 8px 24px rgba(36, 76, 78, 0.14);
```

### Diretrizes

- Evite sombras fortes em tabelas e listas.
- Utilize bordas para separar cards e superfícies.
- Prefira mudanças discretas de fundo em estados de hover.
- Reserve elevação para componentes sobrepostos.
- Evite efeitos 3D, brilho excessivo e ornamentação desnecessária.

---

## Shapes

O sistema utiliza formas arredondadas e suaves, mantendo uma aparência moderna e amigável.

### Raios de borda

| Token | Valor | Uso |
| :--- | :--- | :--- |
| `rounded.sm` | `8px` | Elementos compactos, badges e pequenos controles |
| `rounded.md` | `16px` | Cards, inputs e painéis |
| `rounded.lg` | `24px` | Blocos de destaque e componentes maiores |
| `rounded.pill` | `999px` | Botões, filtros e indicadores |

### Diretrizes

- Utilize bordas arredondadas de maneira consistente.
- Evite misturar componentes excessivamente rígidos com elementos muito arredondados.
- Prefira formas simples e funcionais.
- Preserve a geometria dos ícones e componentes em diferentes resoluções.
- Evite elementos decorativos que prejudiquem a leitura de informações.

---

## Components

### Botões

#### Primário

- Fundo: `#9EEA6C`
- Texto: `#244C4E`
- Formato: pill
- Peso: 600

Utilizado para ações principais, como:

- Criar pedido
- Confirmar roteamento
- Salvar alterações
- Atribuir responsável

#### Secundário

- Fundo branco ou transparente
- Borda `#244C4E`
- Texto `#244C4E`
- Formato arredondado

Utilizado para ações complementares.

#### Terciário

- Fundo transparente
- Texto `#244C4E`
- Hover discreto
- Sem bordas desnecessárias

Utilizado em ações de menor prioridade.

#### Destrutivo

- Utiliza uma cor semântica de erro.
- Deve comunicar claramente o impacto da ação.
- Quando necessário, exige confirmação explícita.

#### Estados dos botões

Todo botão deve possuir estados visuais definidos:

- Default
- Hover
- Focus
- Active
- Disabled
- Loading

As ações em processamento devem apresentar feedback visual e evitar execuções duplicadas.

---

### Cards

Cards devem apresentar informações agrupadas de forma clara.

**Especificações:**

- Fundo: `#FFFFFF`
- Borda: `1px solid #E2E7F1`
- Raio: `16px`
- Padding: `24–32px`
- Sombra: opcional e discreta

#### Cards de indicadores

Utilizados principalmente no dashboard para apresentar métricas operacionais.

Exemplos:

- Total de pedidos
- Pedidos pendentes
- Pedidos em andamento
- Pedidos concluídos
- Pedidos com erro

Cada card deve apresentar:

1. Identificação da métrica
2. Valor principal em destaque
3. Informação complementar, quando relevante
4. Indicador visual opcional

Evite excesso de ícones e cores em cards de indicadores.

---

### Tabelas

Tabelas são componentes centrais do sistema e devem priorizar legibilidade e eficiência operacional.

#### Estrutura sugerida

| Pedido | Origem | Destino | Status | Responsável | Criado em | Ações |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `#000123` | Unidade A | Unidade B | Em andamento | João Silva | 15/11/2026 | Visualizar |
| `#000124` | Unidade C | Unidade A | Pendente | Não atribuído | 15/11/2026 | Visualizar |
| `#000125` | Unidade B | Unidade D | Concluído | Maria Souza | 14/11/2026 | Visualizar |

As colunas são exemplos e devem ser adaptadas ao modelo de roteamento utilizado.

#### Diretrizes

- Utilize cabeçalhos claros e objetivos.
- Permita ordenação quando fizer sentido.
- Mantenha alinhamento consistente entre colunas.
- Destaque informações importantes sem comprometer a leitura.
- Utilize divisores discretos entre linhas.
- Apresente estados por meio de badges.
- Ofereça ações contextuais de maneira previsível.
- Utilize paginação ou carregamento progressivo para grandes volumes de dados.
- Preserve cabeçalhos visíveis quando apropriado.

#### Interações

- Hover discreto nas linhas.
- Seleção múltipla quando houver ações em lote.
- Menu contextual para ações secundárias.
- Clique para acessar os detalhes de um pedido.
- Feedback imediato após alterações.

---

### Formulários

Formulários devem ser simples, objetivos e organizados em grupos lógicos.

**Inputs:**

- Fundo branco
- Texto `#244C4E`
- Borda `#E2E7F1`
- Raio `16px`
- Label sempre visível
- Outline de foco perceptível

#### Diretrizes

- Utilize labels acima dos campos.
- Evite depender exclusivamente de placeholders.
- Agrupe campos relacionados.
- Identifique campos obrigatórios.
- Apresente validações próximas aos campos correspondentes.
- Preserve dados preenchidos em caso de erro.
- Evite formulários excessivamente longos quando puderem ser divididos logicamente.

#### Campos comuns

- Identificador do pedido
- Origem
- Destino
- Responsável
- Prioridade
- Status
- Data de criação
- Observações

Os campos efetivamente disponíveis dependem das regras de negócio.

---

### Filtros e busca

A localização rápida de pedidos deve ser uma prioridade.

#### Componentes sugeridos

- Campo de busca
- Filtros por status
- Filtros por período
- Filtros por origem e destino
- Filtros por responsável
- Filtros por prioridade
- Ordenação

#### Diretrizes

- Posicione os filtros próximos à listagem.
- Apresente filtros ativos de maneira visível.
- Permita limpar filtros facilmente.
- Preserve filtros durante a navegação quando apropriado.
- Evite exigir múltiplas interações para filtros frequentes.
- Utilize chips ou pills para filtros rápidos.

---

### Badges e indicadores

Badges devem comunicar estados de maneira compacta e legível.

**Especificações:**

- Raio: `999px`
- Padding horizontal: `8–12px`
- Padding vertical: `4–6px`
- Tipografia: 12–14px
- Peso: 600

#### Diretrizes

- Utilize fundos suaves e textos de alto contraste.
- Evite badges excessivamente saturados.
- Mantenha consistência entre cores e significados.
- Utilize textos curtos.
- Não dependa apenas da cor para indicar estados.

---

### Modais e drawers

Modais devem ser reservados para decisões pontuais ou ações que exigem atenção concentrada.

Drawers laterais são preferíveis quando o usuário precisa consultar informações sem perder o contexto da tela principal.

#### Casos de uso

**Modal:**

- Confirmar cancelamento
- Confirmar exclusão
- Exibir alertas importantes
- Solicitar confirmação de ações irreversíveis

**Drawer:**

- Visualizar detalhes de pedidos
- Alterar informações
- Consultar histórico
- Atribuir responsáveis
- Inspecionar dados de roteamento

#### Diretrizes

- Evite modais para informações que poderiam aparecer diretamente na interface.
- Permita fechar componentes de maneira previsível.
- Preserve o contexto de navegação.
- Utilize títulos claros e ações objetivas.
- Mantenha ações destrutivas visualmente distintas.

---

### Navegação

A navegação deve ser simples, curta e consistente.

Em aplicações desktop, utilize preferencialmente uma barra lateral para organizar as principais funcionalidades.

#### Estrutura sugerida

**Principal:**

- Dashboard
- Pedidos
- Roteamento
- Histórico

**Sistema:**

- Configurações
- Perfil

#### Diretrizes

- Destaque claramente a seção ativa.
- Utilize ícones simples e consistentes.
- Mantenha rótulos textuais.
- Evite menus excessivamente profundos.
- Permita navegação por teclado.
- Adapte a barra lateral para telas menores.
- Preserve o contexto da página atual durante ações secundárias.

---

## Dashboard

O dashboard deve oferecer uma visão geral da operação.

Seu objetivo é permitir que o usuário compreenda rapidamente a situação atual dos pedidos e identifique possíveis necessidades de intervenção.

### Estrutura sugerida

#### 1. Cabeçalho

- Título da página
- Descrição breve
- Ação principal

#### 2. Indicadores

- Total de pedidos
- Pedidos pendentes
- Pedidos em andamento
- Pedidos concluídos

#### 3. Visão operacional

- Distribuição dos pedidos por status
- Pedidos recentes
- Pedidos que exigem atenção

#### 4. Ações rápidas

- Criar pedido
- Consultar pedidos
- Acessar roteamento

### Diretrizes

- Priorize indicadores relevantes.
- Evite gráficos puramente decorativos.
- Utilize visualizações somente quando facilitarem a interpretação.
- Mantenha consistência visual entre métricas.
- Evite sobrecarregar a página inicial com informações secundárias.

---

## Order Routing

O fluxo de roteamento deve ser uma das experiências centrais do sistema.

A interface deve permitir compreender a situação de um pedido, identificar seu destino e acompanhar sua movimentação ao longo do processo.

### Princípios

1. **Visibilidade** — o usuário deve identificar facilmente o estado atual do pedido.
2. **Rastreabilidade** — alterações importantes devem ser apresentadas de maneira compreensível.
3. **Previsibilidade** — ações semelhantes devem produzir comportamentos consistentes.
4. **Controle** — alterações de roteamento devem apresentar feedback e confirmação quando necessário.
5. **Eficiência** — operações frequentes devem exigir o menor número possível de interações.

### Visualização de roteamento

Quando aplicável, apresente:

- Origem
- Destino
- Estado atual
- Responsável
- Histórico de movimentações
- Data e horário das alterações
- Próximas ações disponíveis

### Representação visual

O fluxo pode ser apresentado utilizando:

- Listas estruturadas
- Etapas sequenciais
- Timelines
- Diagramas de fluxo
- Indicadores de progresso

A escolha depende da complexidade das regras de negócio.

Evite diagramas elaborados quando uma lista ou tabela comunicar a mesma informação com maior clareza.

---

## Feedback & States

Toda operação deve oferecer feedback perceptível.

### Estados de interface

#### Loading

- Utilize skeletons para conteúdos estruturados.
- Utilize indicadores de progresso para ações específicas.
- Evite mudanças bruscas de layout.

#### Empty State

- Explique brevemente a ausência de informações.
- Apresente uma ação quando apropriado.
- Evite mensagens genéricas.

> **Exemplo:** "Nenhum pedido encontrado. Experimente ajustar os filtros."

#### Success

- Confirme que a operação foi concluída.
- Utilize mensagens curtas e objetivas.

> **Exemplo:** "Pedido roteado com sucesso."

#### Error

- Explique o que não funcionou.
- Indique uma possível ação corretiva.
- Preserve os dados do usuário sempre que possível.

> **Exemplo:** "Não foi possível atualizar o pedido. Tente novamente."

#### Warning

- Destaque situações que exigem atenção.
- Evite alarmes visuais desnecessários.

### Notificações

Utilize notificações discretas para operações rotineiras.

Prefira:

- Toasts para confirmações rápidas
- Mensagens inline para validações
- Alertas para situações importantes
- Modais para decisões críticas

---

## Accessibility

A interface deve ser acessível e utilizável em diferentes dispositivos e contextos.

### Diretrizes

- Garanta contraste adequado entre texto e fundo.
- Utilize estados de foco visíveis.
- Permita navegação por teclado.
- Utilize labels associados aos campos.
- Não dependa apenas de cores para comunicar informações.
- Utilize ícones acompanhados de texto quando necessário.
- Mantenha áreas de toque confortáveis.
- Preserve a legibilidade em diferentes níveis de zoom.
- Utilize mensagens de erro compreensíveis.
- Respeite preferências de movimento reduzido.

### Contraste

As cores da paleta devem ser utilizadas respeitando os requisitos de acessibilidade.

O verde-lima deve ser utilizado principalmente como fundo de ações ou destaque, acompanhado de texto escuro.

Evite verde-lima como cor de texto sobre superfícies brancas.

---

## Responsive Behavior

O sistema deve funcionar adequadamente em diferentes tamanhos de tela.

### Mobile

- Navegação recolhível
- Cards empilhados
- Ações principais facilmente acessíveis
- Formulários em coluna única
- Filtros compactos
- Tabelas adaptadas ou com rolagem horizontal

### Tablet

- Navegação compacta
- Layouts de até duas colunas
- Painéis redimensionáveis quando apropriado
- Formulários organizados em grupos

### Desktop

- Navegação lateral persistente quando houver espaço
- Tabelas completas
- Painéis contextuais
- Layouts com múltiplas colunas
- Uso eficiente de áreas horizontais

A responsividade não deve apenas reorganizar elementos visualmente: também deve preservar a usabilidade dos fluxos operacionais.

---

## Motion & Interactions

As animações devem ser discretas, rápidas e funcionais.

### Diretrizes

- Utilize transições suaves em hover e focus.
- Evite animações decorativas prolongadas.
- Prefira transições entre 150ms e 250ms.
- Preserve a sensação de resposta imediata.
- Utilize animações para comunicar mudanças de estado.
- Evite movimentações que prejudiquem a leitura de dados.

```css
--transition-fast: 150ms ease;
--transition-default: 200ms ease;
--transition-slow: 250ms ease;
```

### Exemplos

- Hover em botões
- Expansão de menus
- Abertura de drawers
- Atualização de indicadores
- Exibição de notificações
- Transições entre estados de carregamento

---

## Do's and Don'ts

### Faça

- Utilize a paleta de cores de maneira consistente.
- Preserve a hierarquia visual.
- Utilize Fustat nos títulos e Inter Tight no corpo.
- Destaque as ações principais com verde-lima.
- Priorize clareza e eficiência operacional.
- Mantenha cards e páginas organizados.
- Utilize tabelas legíveis e filtros acessíveis.
- Apresente estados de pedidos de maneira consistente.
- Ofereça feedback imediato após ações.
- Mantenha textos curtos e objetivos.
- Utilize espaçamento para agrupar informações relacionadas.
- Preserve a experiência em dispositivos menores.

### Não faça

- Não utilize cores vibrantes indiscriminadamente.
- Não sobrecarregue o dashboard com métricas irrelevantes.
- Não utilize sombras ou efeitos visuais excessivos.
- Não esconda informações essenciais atrás de múltiplas interações.
- Não dependa exclusivamente de cores para indicar estados.
- Não utilize verde-lima em textos longos.
- Não introduza elementos decorativos sem função.
- Não crie fluxos de navegação desnecessariamente complexos.
- Não utilize modais para operações simples.
- Não misture padrões diferentes para a mesma interação.
- Não apresente mensagens de erro vagas.
- Não sacrifique a legibilidade em favor da densidade informacional.

---

## Design Philosophy

O sistema deve transmitir três características fundamentais:

### Simplicidade

Uma interface que apresenta apenas o necessário, sem comprometer a disponibilidade de informações relevantes.

### Eficiência

Uma experiência construída para reduzir o esforço necessário para consultar, organizar e rotear pedidos.

### Confiabilidade

Uma linguagem visual consistente, com feedback claro e estados previsíveis, permitindo que o usuário compreenda o resultado de suas ações.

O objetivo é construir uma ferramenta operacional moderna e agradável, mantendo uma identidade visual própria sem comprometer a produtividade.

A interface deve parecer simples mesmo quando estiver lidando com processos complexos.

---

## Attribution

| Campo | Valor |
| :--- | :--- |
| Design System | Sistema de Roteamento de Pedidos |
| Visual Inspiration | AbacatePay |
| Reference | [abacatepay.com/design](https://www.abacatepay.com/design) |
| Adaptation | Interface de gerenciamento e roteamento de pedidos |
| Language | Português brasileiro |
| Style | Minimalista, funcional e responsivo |

A identidade visual foi adaptada a partir das referências públicas de design da AbacatePay, preservando sua paleta cromática, tipografia e princípios estéticos.

Este documento não representa uma afiliação ou parceria com a marca original.
