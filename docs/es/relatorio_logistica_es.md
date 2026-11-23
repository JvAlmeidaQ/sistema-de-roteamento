# Entrega de ES — Logística

**Disciplina:** DCC061 (Engenharia de Software) · **Modo:** `VITE_APP_MODE=full`

- **Branch de trabalho:** `feature/logistica-es`; **base do PR:** `release/es` (`3749bae`).
- **Referências:** [Marco 1 — backend (#23)](https://github.com/JvAlmeidaQ/sistema-de-roteamento/issues/23), [Marco 2 — frontend (#33)](https://github.com/JvAlmeidaQ/sistema-de-roteamento/issues/33), [SQL da entrega anterior (#39)](https://github.com/JvAlmeidaQ/sistema-de-roteamento/pull/39) e [padrão de implementação de Comércio (#40)](https://github.com/JvAlmeidaQ/sistema-de-roteamento/pull/40). A [#18](https://github.com/JvAlmeidaQ/sistema-de-roteamento/issues/18) se refere à entrega anterior de BD.
- **Escopo:** painel e ciclo operacional de `Entrega` e `Rota`, mais o rastreio de Pedido e Entrega (`RF05`). A implementação reutiliza as tabelas e os gatilhos logísticos existentes. A migração [`08_historicos_rastreio.sql`](../../grupo10/sql/08_historicos_rastreio.sql) instala apenas os gatilhos necessários para registrar e preservar a trilha (`RN04`, `RN08`, `RR11`). Não altera migrações anteriores nem implementa um módulo geral de Auditoria. Split financeiro, avaliações e autenticação permanecem fora deste recorte.

## O que precisava ser feito e como verificar

| Requisito | Implementação | Como testar e o que esperar |
| --- | --- | --- |
| `RF04` — ver e assumir entregas | Fila paginada de entregas sem rota, vinculadas a pedidos `pronto`, com loja, bairro/cidade e previsão. O aceite tira a entrega da fila e a coloca na própria rota como `aceita`, exibindo coleta e destino com CEP somente ali. O seletor do modo `full` inclui também contas que só têm o papel de entregador. | Selecione a conta `#1` na carga de demonstração, abra o **Painel do entregador** e assuma uma entrega quando houver vaga e não houver atraso. Ela some da fila, aparece na rota e passa a mostrar os endereços com CEP. Testes `deveOferecerEntregadorExclusivoNaSessaoDeDemonstracao`, `deveListarFilaPaginadaSemExporEnderecoCompleto` e `deveAssumirEntregaEAbrirRotaComUmaVaga`. |
| `RN02` / `RR02` — até duas entregas por rota | A API cria uma rota só se não houver rota aberta e reutiliza a existente com vaga. Conta todos os vínculos, inclusive os já concluídos, como exige o gatilho existente. | Assuma duas entregas **dentro do prazo**. A terceira é bloqueada com `422` (`RN02`) mesmo após finalizar só a primeira. Conclua a segunda: a rota aparece em **Rotas encerradas** e outro aceite abre uma nova rota. Teste `deveManterLimiteAposPrimeiraConclusaoEAbrirOutraRotaSoDepoisDoEncerramento`. |
| `RN03` / `RR05` — atraso | Um aceite é bloqueado se o entregador tiver entrega `aceita` ou `a_caminho` cuja `previsao_entrega` venceu. Atraso não é um status persistido. | Em um banco de teste, deixe uma entrega da rota vencer e mantenha uma vaga livre. O painel sinaliza **Em atraso**, e o próximo aceite recebe `422` (`RN03`). Conclua a atrasada para liberar outro aceite. O teste `deveBloquearSegundaEntregaComAtrasoMesmoHavendoVaga` prepara esse cenário sem esperar o relógio. |
| `RF06` (parte logística) / `RR06` — retirada e conclusão | Só o entregador da rota pode fazer `aceita → a_caminho → entregue`. Na última entrega da rota, o backend preenche `encerrada_em`. O gatilho do banco sincroniza o pedido para `concluido`, na mesma transação. | Clique em **Registrar retirada** e depois **Finalizar**. Confira o estado **A caminho**, a rota encerrada ao terminar a última entrega e o pedido **Concluído** na conta do cliente ou do lojista. O salto `aceita → entregue` retorna `422`; um entregador de outra rota recebe `403`. Testes `deveRegistrarRetiradaEConcluirPedidoAoFinalizarUltimaEntrega` e `deveBloquearAlteracaoDeTerceiroESaltoDeStatus`. |
| `RF05` — rastrear pedido e entrega | Tela `/rastreio/:id` de leitura, com situação atual, previsão e eventos por ordem de data e hora. A consulta é restrita ao cliente do pedido, lojista da loja e entregador vinculado. Lacunas são sinalizadas sem inventar eventos. | Em **Gestão de Pedidos**, selecione um pedido e clique em **Ver rastreio**. No painel, o entregador também pode usar **Ver rastreio** na rota atual ou **Rastrear pedido** em **Rotas encerradas**. Ao mudar o estado do pedido ou da entrega, clique em **Atualizar rastreio** para ver o novo evento. Uma conta sem vínculo recebe `403`. Testes `deveRastrearPedidoEEntregaEmSequenciaCronologica`, `deveRegistrarENavegarTodoOCicloDeUmPedidoNovo` e `deveExplicitarLacunaDeEntregaLegadaSemCriarEventos`. |
| `RN04` / `RN08` / `RR11` — trilha imutável | O PostgreSQL registra o estado inicial e as mudanças reais de `Pedido` e `Entrega` na mesma transação. Bloqueia `UPDATE` e `DELETE` dos eventos de ambas as tabelas. | Percorra o ciclo de um pedido novo; cada etapa aparece uma vez. O teste `deveProtegerOsEventosRegistrados` verifica os dois comandos em cada tabela, com código `23001` e identificação `RN08/RR11`. O script `verificacao_dos_gatilhos.sql` também testa o fluxo completo e confirma que regravar o mesmo status não cria outro evento. |
| `RN12` / `RR07` — origem e previsão | A Logística não cadastra entregas manualmente. Consome as entregas criadas pelo gatilho `logistica_gerar_entrega` quando o pedido fica `pronto`, com a previsão já calculada pelo banco. | No fluxo já existente de **Gestão de Pedidos**, marque um pedido em preparação como pronto. Ele deve aparecer na fila ao atualizar o painel. Teste `deveMostrarEntregaGeradaPeloBancoQuandoPedidoFicaPronto`; o script `verificacao_dos_gatilhos.sql` também cobre a previsão e a rejeição de pedidos não prontos. |
| Concorrência e autorização do `RF04` / `RF06` | A transação bloqueia a linha do entregador (mesmo antes de criar uma rota) e a entrega disputada. Isso protege o aceite sem uma nova migração. O backend confere o papel e o vínculo com a rota; `X-User-Id` continua sendo o mecanismo demonstrativo do projeto, não autenticação de produção. | Execute `LogisticaConcorrenciaIntegrationTest`: dois entregadores disputam a mesma entrega (`204` e `409`); três entregas disputam uma única rota (`204`, `204`, `422`). Em duas transações diretas no PostgreSQL, a terceira vinculação espera pelo lock e falha com `23514` (`RN02`) após a segunda ser confirmada. `deveExigirPapelDeEntregadorEValidarParametros` cobre papel ausente, parâmetros inválidos e entrega inexistente. |
| `RNF02` e [`DESIGN.md`](./DESIGN.md) | O painel e o rastreio reutilizam os tokens de cor, Fustat e Inter Tight. Têm layout responsivo, estados de carregamento/erro/vazio, rótulos textuais e foco visível. Suas rotas, links e a consulta da sessão de entregadores entram só no modo `full`. As respostas das APIs de Logística são validadas com Zod antes da renderização. | Compare `npm run build` e `npm run build:bd`. Com `full`, abra o painel e o rastreio e navegue com teclado e em viewport móvel. Com `bd`, não deve haver link ou tela de Logística; ficam as telas `/` e `/relatorios`. |

Código principal: [`LogisticaController.java`](../../grupo10/app/backend/src/main/java/br/ufjf/dcc/entregas/features/logistica/controller/LogisticaController.java), [`EntregaService.java`](../../grupo10/app/backend/src/main/java/br/ufjf/dcc/entregas/features/logistica/service/EntregaService.java), [`EntregaRepository.java`](../../grupo10/app/backend/src/main/java/br/ufjf/dcc/entregas/features/logistica/repository/EntregaRepository.java) e [`PainelEntregadorPage.tsx`](../../grupo10/app/frontend/src/features/logistica/components/PainelEntregadorPage.tsx). O painel lê `vw_painel_rotas_logistica` e o estado atual das tabelas. A linha do tempo do pedido é uma consulta separada, via [`RastreioService.java`](../../grupo10/app/backend/src/main/java/br/ufjf/dcc/entregas/features/logistica/service/RastreioService.java) e [`RastreioPedido.tsx`](../../grupo10/app/frontend/src/features/logistica/components/RastreioPedido.tsx). Consulte também a [matriz de rastreabilidade](./matriz_rastreabilidade.md).

## Rodar em um ambiente local de testes

Use Java 21, Maven, Node 22 e PostgreSQL 18. Em um ambiente descartável, a partir da raiz do repositório:

```bash
# Cria o .env somente se ainda não existir. Defina POSTGRES_PASSWORD conforme o guia.
[ -f .env ] || cp .env.example .env
docker compose --env-file .env -f docker/docker-compose.yml up -d --wait
(cd grupo10/app/frontend && npm ci && npm run build)
(cd grupo10/app/backend && mvn clean verify && mvn spring-boot:run)
```

O Compose publica a porta `5433`; nesse modo, o próprio Maven aplica as migrações existentes. Abra [o painel](http://localhost:8080/painel-entregador). No seletor da sessão, use `#1` para conferir um entregador exclusivo ou `#41` para testar uma conta com os papéis de cliente **e** entregador. A carga inicial pode trazer rotas cheias e antigas: finalize as entregas pendentes dessa conta para liberar a rota. Para testar **dois aceites sem atraso**, coloque dois pedidos recém-preparados no estado `pronto` pelo fluxo de Comércio já existente e assuma esses pedidos enquanto suas previsões ainda estiverem no futuro. Os pedidos mais novos aparecem primeiro na fila.

### Testes focados (backend)

```bash
(cd grupo10/app/backend && mvn -Dtest='Logistica*IntegrationTest' test)
```

Os testes usam MockMvc e PostgreSQL real. Os cenários de painel e rastreio revertem suas alterações ao final de cada teste. A suíte concorrente confirma as fixtures em um banco descartável próprio, removido ao fechar o contexto de testes. Para essa suíte, o usuário de testes precisa poder acessar o banco `postgres` e ter permissão `CREATEDB` (o Compose já usa o usuário criado pelo contêiner). **Não execute as suítes contra uma base compartilhada ou com dados reais.** Para usar outra porta de banco, ajuste tanto a propriedade Maven `db.url` quanto `DB_URL` da aplicação. Veja o [guia de desenvolvimento](./GUIA_DESENVOLVIMENTO.md#43-executando-os-testes-e-verificações).

### Contrato HTTP para inspeção manual

Com exceção da listagem de contas para o seletor de demonstração, os endpoints exigem `X-User-Id`. O painel e as mutações exigem um entregador; a consulta de rastreio exige vínculo com o pedido:

| Método e caminho | Resposta esperada |
| --- | --- |
| `GET /api/logistica/sessao/entregadores` | `200`, com identificador e nome dos entregadores, sem e-mail ou endereço. Usado pelo seletor de demonstração no modo `full`. |
| `GET /api/logistica/pedidos/{idPedido}/rastreio` | `200`, com situação atual, previsão se houver entrega, eventos cronológicos e sinalização de histórico incompleto. `403` para quem não participa do pedido. |
| `GET /api/logistica/painel?paginaDisponiveis=1&paginaEncerradas=1` | `200`, com `rotaAtual` (ou `null`) e duas listas paginadas, 10 itens por página. Cada rota encerrada inclui os `idsPedidos` para navegar ao rastreio. |
| `POST /api/logistica/entregas/{idEntrega}/assumir` | `204` se assumida; `409` se não estiver mais disponível; `422` se houver atraso ou a rota estiver cheia. |
| `PATCH /api/logistica/entregas/{idEntrega}/status` | Envie JSON `{"novoStatus":"a_caminho"}` ou `{"novoStatus":"entregue"}`. Sucesso: `204`. Transição inválida: `422`. Rota própria já encerrada: `409`. |

Ausência do cabeçalho, paginação inválida ou formato inválido retorna `400`; papel ou vínculo insuficiente, `403`; ID de entrega inexistente, `404`. Use `idEntrega` das respostas do painel nas mutações, não `idPedido`.

## Aplicação da migração de rastreio

O Flyway aplica a versão `08` em bases na `07` e a [`09`](../../grupo10/sql/09_alinha_sqlstate_historico.sql) em bases na `08`. A versão `09` alinha o SQLSTATE da imutabilidade a `23001` sem editar a `08`. Não é preciso recriar a base nem editar SQL já aplicado pelo Flyway. A versão `08` mantém o histórico da carga, passa a registrar novos eventos e não inventa horários para fatos que não foram registrados. Ao integrar com o trabalho de Auditoria, reaproveite estes gatilhos em vez de instalar outro conjunto que também grave nas mesmas tabelas.

## Validação executada nesta branch

- `mvn -B clean verify` com banco descartável, PostgreSQL 18.7 e migrações do projeto: **26 testes passaram** (20 de Logística, incluindo disputa direta pela última vaga, e 6 de Comércio). O JDK local era 25, com alvo de compilação Java 21 configurado no projeto. O Flyway aplicou `09` tanto em uma base na versão `08` quanto em banco vazio.
- `npm run build` e `npm run build:bd`: ambos passaram. O JavaScript de BD não contém as rotas, links ou consultas de painel, rastreio e sessão de entregadores.
- Chromium em viewport móvel (`390 × 844`), com Spring Boot e PostgreSQL reais: o entregador exclusivo `#1` aceitou e finalizou uma entrega, conferiu os CEPs após o aceite e abriu o rastreio em **Rotas encerradas**. Uma resposta de rastreio inválida, simulada por uma requisição, mostrou mensagem de erro e a consulta funcionou na tentativa seguinte. O fluxo anterior também confirmou os 10 eventos de um pedido novo e a restrição de acesso a participantes.
- Os scripts consolidados `verificacao_dos_gatilhos.sql` e `04_consultas.sql` executaram sem falhas.
