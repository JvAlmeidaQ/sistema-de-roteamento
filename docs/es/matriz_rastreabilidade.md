# Matriz de Rastreabilidade Bidirecional

> **O que é:** Um artefato formal de Engenharia de Requisitos que mapeia a vida de cada necessidade do sistema, conectando a especificação funcional aos artefatos físicos de banco de dados e linhas de código da aplicação.

> Mapeamento estruturado conforme as diretrizes da **ISO/IEC/IEEE 29148:2018**, garantindo a rastreabilidade entre a especificação de requisitos, as regras de negócio e os artefatos de implementação (Banco de Dados e Aplicação).

## Rastreabilidade dos Requisitos Funcionais

| ID       | Requisito                                                                            | Regras de Negócio Relacionadas | Implementação             | Artefatos                                                          |
| -------- | ------------------------------------------------------------------------------------ | ------------------------------ | ------------------------- | ------------------------------------------------------------------ |
| **RF01** | CRUD de Clientes, Lojistas e Entregadores, incluindo múltiplos Telefones e Endereços | RN10, RN11                     | Aplicação / DDL           | `01_esquema.sql`, `UsuarioController.java`                         |
| **RF02** | Criação de Pedido com Produtos e respectivas quantidades                             | RN01, RN07, RN09               | Aplicação / DDL           | `01_esquema.sql`, `PedidoController.java`                          |
| **RF03** | Criação automática de Entrega vinculada ao Pedido                                    | RN12                           | Aplicação / Trigger       | `EntregaService.java`, `06_triggers.sql`                           |
| **RF04** | Visualização de entregas disponíveis e aceite pelo Entregador                        | RN02, RN03                     | Aplicação / SQL           | `04_consultas.sql`, `PainelEntregador.tsx`, `EntregaService.java`  |
| **RF05** | Consulta da linha do tempo e rastreio do Pedido e da Entrega                         | RN04, RN08                     | Aplicação / SQL / Trigger | `04_consultas.sql`, `RastreioPedido.tsx`, `06_triggers.sql`        |
| **RF06** | Atualização dos status de preparação e logística                                     | RN04, RN08                     | Aplicação / Trigger       | `AtualizarStatus.tsx`, `PedidoService.java`, `EntregaService.java` |
| **RF07** | Gerenciamento do funcionamento da Loja e pausa de Produtos                           | RN01                           | Aplicação / DDL           | `PainelLojista.tsx`, `LojaService.java`, `01_esquema.sql`          |
| **RF08** | Registro de Avaliação para Loja e Entregador                                         | RN06, RN13                     | Aplicação / DDL / Trigger | `Avaliacao.tsx`, `01_esquema.sql`, `06_triggers.sql`               |
| **RF09** | Cálculo e registro da divisão financeira entre Loja, Entregador e Plataforma         | RN05                           | Aplicação / DDL           | `PagamentoService.java`, `01_esquema.sql`                          |
| **RF10** | Consultas parametrizadas de pedidos concluídos e faturamento                         | —                              | Aplicação / SQL           | `05_visoes.sql`, `RelatorioLoja.tsx`                               |

## Rastreabilidade das Regras de Negócio

| ID       | Regra de Negócio                                                                | Requisitos Funcionais Relacionados | Implementação   | Artefato Físico       |
| -------- | ------------------------------------------------------------------------------- | ---------------------------------- | --------------- | --------------------- |
| **RN01** | Pedido só pode ser criado se a Loja estiver aberta                              | RF02, RF07                         | Aplicação       | `PedidoService.java`  |
| **RN02** | Rota pode conter no máximo duas Entregas                                        | RF04                               | Restrição (DDL) | `01_esquema.sql`      |
| **RN03** | Entregador com Entrega atrasada não pode assumir uma segunda Entrega            | RF04                               | Aplicação       | `EntregaService.java` |
| **RN04** | Alteração de status gera registro no respectivo Histórico                       | RF05, RF06                         | Gatilho         | `06_triggers.sql`     |
| **RN05** | Soma das parcelas da Loja, Entregador e Plataforma deve ser igual ao total pago | RF09                               | Restrição (DDL) | `01_esquema.sql`      |
| **RN06** | Nota da Avaliação deve ser um número inteiro entre 1 e 5                        | RF08                               | Restrição (DDL) | `01_esquema.sql`      |
| **RN07** | Pedido não pode conter Produtos de Lojas diferentes                             | RF02                               | Restrição (DDL) | `01_esquema.sql`      |
| **RN08** | Registros do Histórico de Status são imutáveis                                  | RF05, RF06                         | Gatilho         | `06_triggers.sql`     |
| **RN09** | Valor unitário e quantidade devem ser maiores que zero                          | RF02                               | Restrição (DDL) | `01_esquema.sql`      |
| **RN10** | CPF e CNPJ devem conter somente números e possuir quantidade correta de dígitos | RF01                               | Restrição (DDL) | `01_esquema.sql`      |
| **RN11** | CPF e CNPJ devem possuir dígitos verificadores válidos                          | RF01                               | Aplicação       | Validador de CPF/CNPJ |
| **RN12** | Entrega só pode ser criada após pagamento e confirmação da Loja                 | RF03                               | Gatilho         | `06_triggers.sql`     |
| **RN13** | Avaliação só pode ser registrada após finalização da Entrega                    | RF08                               | Gatilho         | `06_triggers.sql`     |
