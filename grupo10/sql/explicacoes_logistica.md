# Explicações — Logística

## Escopo e referências

Os artefatos de Logística atendem ao card #18 e seguem a seção 2.4 do dicionário de dados, a especificação de validações e o ADR-005 em `docs/es/`. As explicações ficam neste documento para manter os arquivos SQL sem comentários. Este material também serve de apoio à redação do relatório; não substitui o relatório oficial.

## E4 — Esquema

`01_esquema_logistica.sql` cria `status_entrega`, `rota` e `entrega`. Depende da existência de `entregador(id_pessoa BIGINT PRIMARY KEY)` e `pedido(id_pedido BIGINT PRIMARY KEY)`, implementados pelos respectivos subdomínios.

As PKs são `BIGINT GENERATED ALWAYS AS IDENTITY`. A unicidade de `entrega.id_pedido` impede duas entregas para o mesmo pedido; não obriga todo pedido a possuir uma entrega. A entrega nasce sem rota, com status `aguardando_entregador`. Um `CHECK` exige rota preenchida nos demais status. Outro `CHECK` impede o encerramento da rota antes de sua criação.

### Ações das chaves estrangeiras

Foi escolhido `ON UPDATE RESTRICT ON DELETE RESTRICT` para impedir alterações das chaves referenciadas e exclusões que romperiam vínculos operacionais. Por exemplo, excluir uma rota não deve apagar suas entregas. Identificadores técnicos não devem ser alterados depois de referenciados. Essa escolha não impede a exclusão de registros sem dependentes e não substitui regras específicas de auditoria.

### Regras que não pertencem ao DDL desta etapa

- **RN02:** o limite de duas entregas por rota exige um gatilho que bloqueie a linha da rota antes de contar os vínculos, conforme o ADR-005. O limite considera todas as entregas vinculadas, não apenas as ativas.
- **RN03:** impedir que um entregador com atraso assuma uma segunda entrega pertence à aplicação.
- **RN12 e ciclo de vida:** a exigência de pedido pronto na criação da entrega e as transições válidas são tratadas em `06_triggers_logistica.sql`.
- A geração e a imutabilidade dos históricos pertencem ao subdomínio de Auditoria.

## E4 — Carga funcional

`02_carga_logistica.sql` representa um snapshot de estados operacionais e deve ser executado uma única vez, após as cargas externas e antes dos gatilhos. Ele não simula todas as transições de status.

### Contrato dos dados externos

Os IDs abaixo são pré-requisitos explícitos da carga de demonstração, não valores determinados pelo dicionário de dados. Devem ser conciliados com as cargas dos demais subdomínios na integração.

| Registro externo | Situação esperada |
| --- | --- |
| Entregador 1 | Responsável pela rota com duas entregas ativas. |
| Entregador 2 | Responsável pela rota com uma entrega atrasada. |
| Entregador 3 | Responsável pela rota encerrada; sem rota aberta. |
| Pedidos 1, 2, 3 e 6 | Prontos e ainda sem entrega antes desta carga. |
| Pedidos 4 e 5 | Concluídos e ainda sem entrega antes desta carga inicial. |

As pessoas correspondentes aos entregadores também devem existir para as consultas que exibem nomes. Os scripts de Logística não criam nem alteram esses dados externos.

### Cenários

| Rota | Pedidos | Situação |
| --- | --- | --- |
| Aberta, entregador 1 | 1 e 2 | Entregas `aceita` e `a_caminho`, dentro da previsão. |
| Aberta, entregador 2 | 3 | Entrega `a_caminho`, com previsão ultrapassada. |
| Encerrada, entregador 3 | 4 e 5 | Duas entregas `entregue`. |
| Sem rota | 6 | Entrega `aguardando_entregador`. |

São criadas três rotas e seis entregas. Os IDs das rotas são obtidos por `RETURNING`, sem pressupor valores iniciais de sequências. Os horários são relativos ao início da transação. A classificação de atraso muda com a passagem do tempo.

As previsões da carga são valores explícitos de demonstração. No fluxo real, a previsão deve ser calculada com o instante em que o pedido ficou pronto e o tempo estimado da loja, conforme o ADR-005. Não se deve usar `pedido.data_pedido` como se fosse o instante da transição para pronto.

### Justificativa do ANALYZE para o relatório

Após o povoamento, foram executados os comandos `ANALYZE rota` e `ANALYZE entrega` para atualizar as estatísticas utilizadas pelo planejador de consultas do PostgreSQL. Essas estatísticas auxiliam na estimativa da quantidade de linhas retornadas por filtros e junções, permitindo escolher planos de execução com custos estimados mais adequados à base carregada. O `ANALYZE` não cria índices nem obriga sua utilização; em tabelas pequenas, uma varredura sequencial pode ser a alternativa de menor custo.

## E4 — Verificação das restrições

`03_verificacao_logistica.sql` deve ser executado depois do esquema e da carga funcional, antes dos gatilhos. Ele verifica as restrições locais de E4; não atesta regras ainda não implementadas em E6.

O script exige os cenários dos pedidos 1 e 6 e cria uma rota de teste com identidade gerada pelo banco. Um bloco PL/pgSQL executa comandos inválidos e compara o `SQLSTATE` e, quando informado, o nome da restrição. Uma operação aceita indevidamente ou um erro diferente do esperado faz o teste falhar.

| Verificação | Resultado esperado |
| --- | --- |
| Inserção de rota com entregador existente | Permitida, com criação preenchida automaticamente. |
| Encerramento em instante igual ao da criação | Permitido. |
| Vinculação da entrega aguardando a uma nova rota e mudança para `aceita` | Permitida no mesmo comando. |
| PK duplicada em rota ou entrega | `23505`, na respectiva PK. |
| Pedido repetido na entrega | `23505`, `uq_entrega_pedido`. |
| Entregador, pedido ou rota inexistente | `23503`, na respectiva FK. |
| Campo obrigatório nulo | `23502`. |
| Encerramento anterior à criação | `23514`, `ck_rota_ordem_temporal`. |
| Entrega aguardando com rota ou aceita sem rota | `23514`, `ck_entrega_status_rota`. |
| Status fora do enum | `22P02`. |
| Exclusão de rota com entrega | `23001`, `fk_entrega_rota`. |

A execução bem-sucedida termina com `ROLLBACK`: os registros e alterações de teste não permanecem. Sequências de identidade podem avançar mesmo com rollback. Portanto, preservar a carga não significa preservar os contadores das sequências.

### Validação executada

O esquema, a carga e a verificação foram executados em PostgreSQL 18 via Docker, em container descartável com tabelas mínimas de `entregador` e `pedido`. A verificação passou duas vezes consecutivas, incluindo 16 operações inválidas rejeitadas por execução. A comparação integral dos registros das quatro tabelas antes e depois confirmou a preservação dos dados.

Como teste do próprio mecanismo de verificação, a restrição temporal foi removida somente no banco descartável. O script detectou que a operação inválida passou a ser aceita e falhou como esperado. Os dados também foram preservados após essa falha, com o encerramento da conexão de teste.

## E5 — Consultas SQL

`04_consultas_logistica.sql` contém seis consultas: primeiro as traduções das consultas 14 e 15 de `grupo10/algebra/consultas_ar.md`, depois quatro consultas complementares de Logística. Os resultados são ordenados para facilitar a conferência; a ordenação não altera as relações obtidas.

### Consulta 14 — Rotas com duas entregas ativas

A CTE `pendentes` seleciona somente entregas `aceita` ou `a_caminho`. A autojunção combina entregas da mesma rota, e a condição `e1.id_entrega < e2.id_entrega` impede tanto o pareamento de uma entrega consigo mesma quanto a repetição do mesmo par em ordem inversa. A junção com `rota` identifica o entregador responsável.

São retornados `id_rota`, `id_entregador`, `id_entrega_1` e `id_entrega_2`. Na carga funcional, o resultado é um único par: as entregas dos pedidos 1 e 2, na rota do entregador 1. A rota com apenas uma entrega ativa e a rota com entregas concluídas não aparecem.

Não foi adicionado filtro de encerramento da rota, pois ele não existe na expressão de Álgebra Relacional. O limite de duas entregas por rota é garantido pelo gatilho da RN02; sem esse gatilho, uma base inválida com três entregas ativas produziria três pares, como na expressão original.

### Consulta 15 — Entregadores e rotas abertas

A junção entre `entregador` e `pessoa` obtém nome e tipo de veículo. O `LEFT JOIN` com `rota` mantém entregadores sem rota aberta. O filtro `encerrada_em IS NULL` fica na condição da junção, não no `WHERE`: assim, um entregador que possui apenas rotas encerradas continua aparecendo, com `id_rota` nulo.

São retornados `nome`, `tipo_veiculo` e `id_rota`. Na carga funcional, os entregadores 1 e 2 aparecem com suas rotas abertas; o entregador 3 aparece com rota nula. Entregadores adicionais sem nenhuma rota também aparecem.

O `DISTINCT` preserva a semântica de conjuntos da projeção em Álgebra Relacional. Se dois entregadores homônimos tiverem o mesmo tipo de veículo e nenhuma rota aberta, as colunas projetadas serão idênticas e aparecerão uma única vez. A consulta não adiciona o identificador do entregador porque ele não faz parte da projeção original.

### Validação das consultas

As duas consultas foram executadas em PostgreSQL 18 via Docker, em container descartável com as dependências externas mínimas, usando o tipo `tipo_veiculo` e os nomes de campos documentados. O esquema, a carga e a verificação de E4 também foram executados nesse ambiente antes das consultas.

A consulta 14 retornou um único par na carga funcional, sem autopares ou inversões. Foram confirmados pares com status mistos, duas entregas aceitas e duas a caminho; uma entrega concluída deixou de formar par. A consulta 15 preservou entregadores com apenas rota encerrada, sem nenhuma rota e com múltiplas rotas abertas. Também foi conferida a eliminação de projeções idênticas para homônimos sem rota aberta. As sequências foram previamente avançadas para confirmar que as consultas não dependem dos IDs iniciais das rotas e entregas.

### Consulta complementar L1 — Rotas abertas com vagas

Ator: operação logística. Objetivo: listar rotas abertas que ainda não atingiram duas entregas vinculadas. O `LEFT JOIN` inclui rotas vazias; `COUNT(e.id_entrega)` não conta a linha nula da junção externa. `GROUP BY` agrupa por rota e `HAVING COUNT(e.id_entrega) < 2` seleciona aquelas com vaga. A contagem inclui entregas concluídas, em conformidade com a RN02: a vaga não é liberada apenas pela mudança do status.

Na carga funcional, retorna a rota do entregador 2, com uma entrega e uma vaga. Não é uma autorização para assumir nova entrega: a RN03 ainda deve ser verificada pela aplicação, pois esse entregador possui atraso.

### Consulta complementar L2 — Entregadores com pelo menos duas entregas concluídas

Ator: gestor de Logística. Objetivo: identificar entregadores com pelo menos duas entregas concluídas em todo o histórico disponível, sem recorte de período. As junções associam pessoa, entregador, rota e entrega. O filtro seleciona `entregue`, e `GROUP BY`/`HAVING` agrupam por identificador e nome do entregador e exigem contagem mínima de dois. Entregadores homônimos não são agrupados como uma só pessoa.

Na carga funcional, retorna o entregador 3, com duas entregas concluídas.

### Consulta complementar L3 — Entregadores com entregas ativas atrasadas

Ator: operação logística e aplicação responsável pela RN03. Objetivo: identificar entregadores que possuem ao menos uma entrega `aceita` ou `a_caminho` com previsão anterior ao instante atual. A subconsulta `EXISTS` é correlacionada por `r.id_entregador = en.id_pessoa` e não repete um entregador quando ele possui vários atrasos.

Na carga funcional, imediatamente após o povoamento, retorna o entregador 2. Entregas concluídas não contam como atraso ativo, mesmo que sua previsão esteja no passado. A consulta apenas identifica a situação; não implementa o bloqueio da RN03.

### Consulta complementar L4 — Pedidos prontos sem entregador atribuído

Ator: operação logística. Objetivo: listar pedidos prontos que ainda não possuem entrega vinculada a uma rota. A subconsulta `NOT EXISTS` é correlacionada por `e.id_pedido = p.id_pedido`. Inclui tanto pedidos com entrega `aguardando_entregador` quanto pedidos cuja entrega ainda não foi criada, permitindo também identificar essa lacuna operacional. Pedidos em outro status e pedidos já atribuídos ficam de fora.

Na carga funcional, retorna o pedido 6, com seu identificador de loja e data do pedido. Depende de `pedido.id_loja`, `pedido.status` e `pedido.data_pedido` conforme o dicionário de dados, além da PK já usada no esquema.

### Cobertura da E5 de Logística

| Exigência do card #18 | Artefato |
| --- | --- |
| Tradução da Álgebra Relacional | Consultas 14 e 15. |
| Junções | Autojunção, `INNER JOIN` e `LEFT JOIN`. |
| `GROUP BY` com `HAVING` | L1 e L2. |
| Subconsultas correlacionadas | L3 com `EXISTS` e L4 com `NOT EXISTS`. |
| Pelo menos uma visão útil | `vw_painel_rotas_logistica`. |

Todas as seis consultas têm resultado não vazio com o contrato de carga documentado, imediatamente após o povoamento. Os quantitativos globais de consultas e visões e a cobertura de `RIGHT JOIN` do projeto devem ser conferidos na consolidação dos subdomínios; não são todos atribuídos ao card de Logística.

## E5 — Visão operacional

`05_visoes_logistica.sql` cria `vw_painel_rotas_logistica`.

- **Ator consumidor:** operação/gestor de Logística e painel de acompanhamento do entregador. O filtro de acesso por entregador deve ser aplicado pela aplicação; a visão não implementa autorização.
- **Objetivo:** apresentar uma linha por rota, aberta ou encerrada, com identificação do entregador, veículo, horários, total de entregas, quantidade de ativas, quantidade de atrasadas e vagas. Centraliza junções e cálculos que seriam repetidos no painel.
- **Semântica das vagas:** são calculadas pelo total de vínculos da rota, não somente pelas entregas ativas. Rotas encerradas têm zero vagas. `GREATEST` evita exibir vagas negativas se uma base inválida ultrapassar o limite, mas não esconde o total nem substitui o gatilho da RN02.
- **Rotas vazias:** são preservadas pelo `LEFT JOIN` e exibem contagens zero; se abertas, têm duas vagas.
- **Atraso:** considera somente entregas `aceita` ou `a_caminho` com previsão menor que `CURRENT_TIMESTAMP`. O valor é calculado na leitura, não armazenado; em PostgreSQL, `CURRENT_TIMESTAMP` representa o início da transação.
- **Atualizável:** não é automaticamente atualizável. A definição reúne múltiplas tabelas, possui `GROUP BY` e funções agregadas (`COUNT` com e sem `FILTER`). As contagens não correspondem a uma única linha de uma tabela-base que possa ser modificada sem ambiguidade. Não foram criados gatilhos `INSTEAD OF` nem regras para permitir escrita; alterações devem ocorrer nas tabelas-base pelos fluxos próprios.
- **Ordenação:** a visão não impõe ordem. O consumidor deve usar `ORDER BY`, por exemplo por `id_rota`.

Na carga funcional, os totais esperados imediatamente após o povoamento são:

| Entregador | Total de entregas | Ativas | Atrasadas | Vagas |
| --- | --- | --- | --- | --- |
| 1 | 2 | 2 | 0 | 0 |
| 2 | 1 | 1 | 1 | 1 |
| 3 | 2 | 0 | 0 | 0 |

A visão apenas expõe dados para acompanhamento. Uma vaga calculada não garante que a atribuição seja permitida: a aplicação ainda precisa aplicar a RN03 e o banco deve proteger a RN02.

### Validação final da E5

As seis consultas e a visão foram executadas em PostgreSQL 18 via Docker, com dependências externas mínimas e os tipos `tipo_veiculo` e `status_pedido` conforme a documentação. A verificação da E4 passou novamente antes dessa execução. Todas as seis consultas retornaram resultados não vazios na carga funcional, com os resultados descritos nas respectivas seções.

Também foram confirmados: rota vazia com duas vagas; pedido pronto sem entrega incluído em L4; pedido não pronto excluído de L4; múltiplos atrasos sem duplicação de entregador em L3; entregas concluídas excluídas dos atrasos ativos; conclusão sem liberação de vaga em rota cheia; agregação de novas conclusões em L2; atualização imediata das contagens da visão após mudanças nas tabelas-base; e zero vagas para rota encerrada, mesmo vazia.

O catálogo `information_schema.views` retornou `is_updatable = NO` e `is_insertable_into = NO` para a visão. Tentativas de `INSERT`, `UPDATE` e `DELETE` foram rejeitadas com `SQLSTATE 55000`, confirmando que a visão não aceita escrita sem regras ou gatilhos específicos. O container usado na validação foi removido; não houve alteração do banco de desenvolvimento.

A integração com as tabelas reais dos demais subdomínios e a transcrição dos resultados para o relatório oficial continuam sendo etapas da consolidação do grupo.

## E6 — Gatilhos

`06_triggers_logistica.sql` cria quatro funções e quatro gatilhos. Deve ser executado uma vez, depois do snapshot de carga. A instalação é transacional e rejeita uma base que já tenha rotas com mais de duas entregas; não corrige nem apaga dados automaticamente.

| Gatilho | Evento | Garantia |
| --- | --- | --- |
| `trg_entrega_10_validar` | `BEFORE INSERT OR UPDATE OF status, id_pedido` em entrega | RN12, estado inicial, associação estável ao pedido e transições de status. |
| `trg_entrega_20_limitar_rota` | `BEFORE INSERT OR UPDATE OF id_rota` em entrega | RN02, no máximo duas entregas vinculadas por rota. |
| `trg_entrega_30_concluir_pedido` | `AFTER UPDATE OF status` em entrega | A transição para entregue conclui o pedido na mesma transação. |
| `trg_pedido_logistica_gerar_entrega` | `AFTER INSERT OR UPDATE OF status` em pedido | Pedido pronto gera uma entrega aguardando entregador e sua previsão. |

### RN02 e concorrência

Antes de admitir uma entrega em uma nova rota, o gatilho adquire `SELECT ... FOR UPDATE` na linha da rota e conta os vínculos existentes, desconsiderando a própria entrega. Entregas concluídas também contam. Uma atribuição à mesma rota, sem mudança do vínculo, não ocupa outra vaga. Transferências para uma rota cheia são barradas com `23514` e a restrição identificada como `ck_rota_maximo_duas_entregas`.

Depois do lock, `UPDATE rota SET criada_em = criada_em` cria deliberadamente uma nova versão MVCC da linha sem alterar seu valor de negócio. Isso não é redundante: em `REPEATABLE READ`, apenas bloquear a linha não renova o snapshot usado na contagem. A atualização técnica provoca conflito de serialização em transações com snapshot anterior à admissão concorrente, impedindo que uma contagem antiga permita a terceira entrega. Em `READ COMMITTED`, a sessão que aguarda o lock enxerga a admissão já confirmada e falha pela RN02; nos isolamentos mais fortes, pode falhar com `40001`.

Esse mecanismo gera escrita e contenção por rota. Futuros gatilhos de UPDATE em `rota` devem distinguir mudanças efetivas de atualizações técnicas para não gerar notificações ou auditoria de negócio indevidas. Operações envolvendo várias rotas ou pedidos podem sofrer deadlocks: os serviços devem adotar ordem consistente de bloqueios e repetir a transação inteira ao receber `40001` ou `40P01`, não somente o último comando.

### RN12, criação automática e previsão

Uma nova entrega deve nascer `aguardando_entregador`. Seu pedido precisa estar `pronto`; o gatilho consulta o pedido com `FOR SHARE` para impedir mudança concorrente de status durante essa verificação. FKs e restrições declarativas continuam ativas.

Ao inserir um pedido já pronto ou atualizar seu status para pronto, o gatilho calcula `statement_timestamp() + make_interval(mins => loja.tempo_entrega_estimado)` e cria a entrega. `statement_timestamp()` representa o início do comando que tornou o pedido pronto, evitando usar o início de uma transação potencialmente longa ou a data original do pedido. A previsão é um snapshot: mudar a estimativa da loja não altera entregas anteriores. Atualizar pronto para pronto não gera outra entrega.

A criação automática tem um único responsável: **este gatilho**. Depois da mudança de status, a aplicação deve consultar a entrega gerada, não inserir outra. Outro gatilho ou serviço que também tente criá-la causará conflito de unicidade e rollback; essa duplicação deve ser removida na consolidação. Caso se opte por criar manualmente a entrega de um pedido legado pronto, a previsão é obrigatória e deve ser fornecida pelo chamador conforme o ADR-005.

O vínculo `entrega.id_pedido` é tratado como imutável após a criação. Essa proteção complementar impede transferir status e futuro histórico de uma entrega existente para outro pedido, inclusive para contornar a RN12 ou a conclusão sincronizada. A correção de vínculos incorretos deve ser explícita, não uma troca silenciosa do pedido.

### Status e conclusão

A entrega só avança por `aguardando_entregador → aceita → a_caminho → entregue`. Repetir o mesmo status é permitido e não dispara nova conclusão; saltos e retrocessos são rejeitados com `23514` e `ck_entrega_transicao_status`. A associação à rota deve acompanhar a passagem para aceita no mesmo comando, conforme o CHECK da E4.

Ao alcançar entregue, o pedido deve estar pronto e passa para concluído na mesma transação. Se a sincronização não puder ocorrer, a alteração da entrega também é revertida. A máquina de estados comercial de `pedido`, as avaliações, a divisão financeira e os históricos permanecem sob responsabilidade dos respectivos subdomínios; o teste isolado não substitui a integração desses gatilhos. Em particular, o módulo comercial deve impedir alterações posteriores incompatíveis no pedido.

### Verificação e resultados

`verificacao_dos_gatilhos_logistica.sql` usa a estrutura completa documentada de `pedido` e `loja`, clona os vínculos externos válidos do pedido 6 e cria registros de teste com identidades geradas. Confere a presença dos quatro gatilhos, cenários permitidos e barrados, primeira/segunda/terceira entrega, transferências, atualizações sem mudança, geração automática, previsão, snapshot e conclusão. Confere o SQLSTATE e o nome da restrição esperados. Termina com rollback, inclusive das funções auxiliares temporárias. Como nas verificações da E4, as sequências podem avançar.

O runner `testes_logistica/verificar.py` prepara dependências externas de teste em PostgreSQL 18 descartável, aplica os arquivos oficiais e executa a verificação duas vezes, comparando todos os registros de rota, entrega, pedido e loja antes e depois. Também valida as 16 combinações possíveis de status, operações multirregistro e concorrência real em duas sessões. A sessão perdedora precisa efetivamente aguardar o bloqueio antes da confirmação da vencedora.

Resultados executados:

| Cenário | Resultado |
| --- | --- |
| Verificação E4 antes dos gatilhos | Passou. |
| Verificação SQL E6, duas execuções | Passou; carga integralmente preservada. |
| Seis consultas, visão e instalação dos índices | Executadas sem erro após os gatilhos. |
| Matriz de 16 transições, incluindo repetições | Somente repetições e avanços de uma etapa permitidos. |
| Última vaga, `READ COMMITTED` | Vencedora confirmou; perdedora recebeu `23514`; duas entregas na rota. |
| Última vaga, `REPEATABLE READ` | Vencedora confirmou; perdedora recebeu `40001`; duas entregas na rota. |
| Última vaga, `SERIALIZABLE` | Vencedora confirmou; perdedora recebeu `40001`; duas entregas na rota. |
| Três atribuições em um só UPDATE para rota vazia | Comando rejeitado integralmente; nenhuma atribuição parcial. |
| Duas entregas concluídas na rota | Terceira atribuição continua bloqueada pela RN02. |

Para reproduzir na raiz do repositório, com Docker e Python 3 disponíveis:

```sh
python3 grupo10/sql/testes_logistica/verificar.py
```

O runner usa o container exclusivo `logistica-gatilhos-test`, sem portas publicadas, sem acesso à rede e sem volumes de desenvolvimento. Se o nome já estiver ocupado, não remove o container existente. O container criado é removido ao final, inclusive em falhas tratadas.

## E6 — Índices e experimentos

`07_indices_logistica.sql` cria quatro índices B-tree: `entrega(id_rota)`, `rota(id_entregador)`, um parcial de entregas ativas por previsão/pedido e um parcial de pedidos prontos na ordem da fila, incluindo a loja. Não duplica os índices já fornecidos por PKs e UNIQUEs.

As justificativas por tabela, coluna, tipo e consulta, a carga volumosa reproduzível, os planos reais antes/depois, os tempos e as limitações estão em `experimentos_logistica.md`. Os auxiliares ficam em `testes_logistica/`, fora da sequência automática de SQLs da raiz. São necessários para reproduzir a validação e os experimentos, não para a execução integrada da aplicação.

O benchmark usa banco separado e snapshot anterior aos gatilhos para não misturar testes de integridade com medições de leitura. Mantém as restrições declarativas e confere o limite de duas entregas por rota. A validação funcional/concorrente dos gatilhos é feita pelo runner específico acima. Para reproduzir os experimentos:

```sh
python3 grupo10/sql/testes_logistica/benchmark.py
```

## Execução e integração

Use `psql -v ON_ERROR_STOP=1` para interromper a execução quando houver erro. A ordem desta etapa é:

1. Esquemas externos necessários.
2. `01_esquema_logistica.sql`.
3. Cargas externas necessárias.
4. `02_carga_logistica.sql`.
5. `03_verificacao_logistica.sql`.
6. `04_consultas_logistica.sql`, também com `pessoa`, `entregador.tipo_veiculo` e os campos documentados de `pedido` disponíveis.
7. `05_visoes_logistica.sql`.
8. `06_triggers_logistica.sql`, também com `loja.tempo_entrega_estimado` e todos os campos documentados de `pedido` disponíveis.
9. `07_indices_logistica.sql`.
10. `verificacao_dos_gatilhos_logistica.sql`, em transação de teste própria.

O Docker Compose monta `grupo10/sql/` em `/docker-entrypoint-initdb.d/`. Na primeira inicialização, os SQLs são executados em ordem alfabética. Enquanto os scripts gerais estiverem vazios, os pré-requisitos externos não estarão disponíveis para essa inicialização automática. Os testes isolados devem carregar explicitamente suas dependências em ambiente descartável, sem apagar volumes de desenvolvimento.

Na consolidação, os tipos devem ser declarados uma única vez e as tabelas ordenadas pelas dependências. Os delimitadores `BEGIN`/`COMMIT` dos scripts de esquema e carga devem ser unificados se os arquivos finais usarem uma transação única por etapa. O rollback da verificação deve permanecer isolado para não desfazer a carga oficial.

A validação com tabelas mínimas externas comprova apenas as restrições locais. É necessário repetir os testes após a integração com as implementações reais dos demais subdomínios. Os resultados reais dos experimentos de desempenho estão registrados em `experimentos_logistica.md`.
