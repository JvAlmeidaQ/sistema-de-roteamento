# Glossário de Domínio — Sistema de Roteamento de Entregas

**Disciplinas:** DCC060 (Banco de Dados) & DCC061 (Engenharia de Software)

## Linguagem Ubíqua para Engenharia de Requisitos

> Este documento estabelece o **vocabulário padrão (Linguagem Ubíqua)** do projeto, garantindo que todos os membros da equipe, stakeholders (professores/avaliadores) e partes interessadas utilizem os mesmos termos com os mesmos significados, evitando ambiguidades durante a modelagem de dados, elicitação de requisitos e desenvolvimento do sistema.

---

## 1. Atores e Papéis

| Termo | Definição no Contexto do Sistema | Sinônimos / Termos Relacionados |
| :--- | :--- | :--- |
| **Pessoa** | Entidade base que concentra os dados cadastrais comuns (nome, CPF, e-mail e telefones) de qualquer indivíduo no sistema. Especializa-se de forma total e sobreposta em Cliente, Lojista e Entregador. | Usuário, Indivíduo |
| **Cliente** | Pessoa Física que realiza compras na plataforma e é destinatária final das Entregas. Possui um ou mais endereços vinculados e pode definir um endereço atual de entrega. | Consumidor, Comprador, Usuário Final |
| **Lojista** | Pessoa Física responsável legal e operacional por uma ou mais Lojas na plataforma. Gerencia o status de funcionamento, mantém o catálogo ativo e conduz o preparo dos pedidos. | Proprietário, Parceiro Comercial, Vendedor |
| **Loja** | Estabelecimento comercial (Pessoa Jurídica com CNPJ próprio) parceiro da plataforma que expõe um catálogo próprio de produtos, define suas categorias, preços, taxa fixa de entrega e tempo estimado. | Estabelecimento, Restaurante, Comércio Parceiro |
| **Entregador** | Pessoa Física parceira da plataforma responsável por assumir e executar Rotas, transportando as Entregas da Loja até o endereço do Cliente utilizando um Veículo cadastrado. | Motorista, Courier, Profissional de Logística |

---

## 2. Catálogo, Pedido e Logística

| Termo | Definição no Contexto do Sistema | Sinônimos / Termos Relacionados |
| :--- | :--- | :--- |
| **Pedido** | Entidade comercial que representa a intenção de compra de um Cliente em uma única Loja. Contém os itens escolhidos, valores e endereço de destino, possuindo ciclo de vida comercial autônomo (`solicitado` → `aceito`/`recusado` → `pago` → `em_preparacao` → `pronto` → `concluido`). | Encomenda, Compra, Transação Comercial |
| **Item (`Item_Pedido`)** | O desmembramento individual de um Pedido, contendo um Produto específico daquela Loja, a quantidade comprada e o preço unitário congelado (*snapshot*) no momento da compra. | Produto do Carrinho, Linha de Pedido |
| **Entrega / Corrida** | Etapa e instância logística de um Pedido. Nasce automaticamente quando o Pedido atinge o status `pronto` na Loja e representa o pacote físico a ser transportado até o Cliente (`aguardando_entregador` → `aceita` → `a_caminho` → `entregue`). Um pedido tem no máximo uma entrega. | Pacote, Frete, Tarefa de Transporte |
| **Rota** | Agrupamento lógico de até duas Entregas (`RN02`) assumidas por um único Entregador para otimizar o deslocamento. | Lote de Entregas, Trajeto, Jornada |
| **Veículo / Modal** | Meio de transporte (Moto, Bicicleta, Carro) cadastrado e utilizado pelo Entregador para realizar as Rotas. | Meio de Transporte, Modalidade |
| **Previsão de Entrega** | Horário limite estimado para conclusão da Entrega, calculado no instante em que o Pedido fica `pronto` somando-se o tempo estimado configurado pela Loja. Uma entrega que ultrapassa esse horário sem estar `entregue` é considerada **atrasada** (`RN03`). | Prazo Estimado, SLA de Entrega |

---

## 3. Modelo Financeiro (Composição e Split)

| Termo | Definição no Contexto do Sistema | Sinônimos / Termos Relacionados |
| :--- | :--- | :--- |
| **Subtotal** | Soma financeira dos itens do pedido (quantidade multiplicada pelo valor unitário de cada item). | Valor dos Produtos, Total Bruto dos Itens |
| **Taxa de Entrega** | Valor fixo definido por cada Loja, igual para qualquer endereço da cidade. É congelado no Pedido e repassado integralmente ao Entregador. | Frete, Custo de Entrega |
| **Taxa de Serviço** | Valor fixo cobrado pela plataforma diretamente do Cliente em cada Pedido. | Taxa de Conveniência, Taxa de Intermediação |
| **Valor Total** | Montante final pago pelo Cliente no Pedido, correspondente exatamente à soma: `Subtotal + Taxa de Entrega + Taxa de Serviço`. | Total do Pedido, Valor Pago |
| **Repasse / Split Financeiro** | Processo de divisão de pagamentos registrado em `Divisao_Pagamento` após a conclusão da Entrega (`entregue`), fracionando o Valor Total entre Loja, Entregador e Plataforma (`RN05`). | Divisão de Pagamento, Comissionamento |
| **Parcela da Loja** | Valor líquido que a Loja recebe pelo pedido, calculado como o `Subtotal` menos o percentual de comissão retido pela plataforma. | Receita Líquida da Loja, Repasse ao Lojista |
| **Comissão do Entregador** | Valor que o Entregador recebe pela execução da entrega, correspondente a 100% da `Taxa de Entrega`. | Ganho do Entregador, Repasse Logístico |
| **Taxa da Plataforma** | Receita total retida pela plataforma na operação, correspondente à `Taxa de Serviço` somada ao valor retido sobre o `Subtotal`. | Receita da Plataforma, Take Rate |

---

## 4. Endereçamento, Auditoria e Rastreabilidade

| Termo | Definição no Contexto do Sistema | Sinônimos / Termos Relacionados |
| :--- | :--- | :--- |
| **Endereço** | Localização física no nível da rua (`logradouro`, `numero`, `bairro`, `cep`, `cidade`, `estado`). É imutável após cadastrado e compartilhável entre pessoas que residem no mesmo imóvel. | Logradouro, Localização Física |
| **Vínculo de Endereço (`Pessoa_Endereco`)** | Associação entre uma Pessoa e um Endereço, onde ficam os dados particulares de cada morador (`apelido`, `complemento` e `referencia`), editáveis sem afetar terceiros. | Endereço Pessoal, Complemento do Morador |
| **Endereço Atual** | O endereço que o Cliente deixou selecionado em seu perfil no aplicativo. No momento da compra, o endereço escolhido é gravado diretamente no Pedido. | Endereço Selecionado, Endereço Padrão |
| **Snapshot** | Cópia congelada de um dado mutável (como preço unitário do produto, taxa de entrega da loja, complemento e referência de endereço) gravada no Pedido no instante da compra para preservar a integridade histórica. | Dado Congelado, Fotografia Histórica |
| **Histórico de Status** | Registros de auditoria imutáveis (`Historico_Pedido` e `Historico_Entrega`) preenchidos por gatilho com carimbo de tempo (*timestamp*) a cada transição de estado (`RN04`, `RN08`). | Linha do Tempo, Rastreio, Trilha de Auditoria |

---

## Notas de Governança

- Todos os termos desta tabela devem ser utilizados consistentemente nos documentos de requisitos, nos scripts SQL, no código-fonte da aplicação e nos testes.
- Para consultar os tipos de dados físicos, chaves e restrições de cada tabela, veja o [Dicionário de Dados](./dicionario_dados.md).
- Para consultar os relacionamentos, cardinalidades e ciclos de vida das entidades, veja o [Modelo de Domínio](./modelo_dominio.md).
