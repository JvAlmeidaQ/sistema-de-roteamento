# Glossário do Sistema de Roteamento de Pedidos

## Linguagem Comum para Engenharia de Requisitos

> Este documento estabelece os **termos padrão** do projeto, garantindo que todos os membros da equipe, stakeholders (professores/avaliadores) e partes interessadas utilizem os mesmos termos com os mesmos significados, evitando ambiguidades durante a modelagem de dados, elicitação de requisitos e desenvolvimento das funcionalidades do sistema.

| Termo                          | Definição no Contexto do Sistema                                                                                                                                                                                                                                     | Sinônimos / Termos Relacionados                    |
| :----------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------- |
| **Pedido**                     | Entidade comercial que representa a intenção de compra de um Cliente em uma única Loja. Contém os produtos escolhidos, quantidade e valor total a ser pago. Fica restrito ao ambiente virtual até ser preparado pela Loja e gera uma Entrega após confirmação.       | Encomenda, Compra, Transação Comercial             |
| **Item (Item_Pedido)**         | O desmembramento individual de um Pedido, contendo um Produto específico, a quantidade desejada e o preço unitário congelado no momento da compra. Grava de forma imutável esses dados para auditoria.                                                               | Produto do Carrinho, Linha de Pedido               |
| **Loja / Lojista**             | **Loja** é o estabelecimento comercial (Pessoa Jurídica) parceira da plataforma que expõe um catálogo de produtos. **Lojista** é o responsável (Pessoa Física) que gerencia o status da Loja, mantém o catálogo ativo e prepara fisicamente os produtos solicitados. | Estabelecimento, Parceiro, Vendedor                |
| **Entrega / Corrida**          | Abstração logística e instância física gerada automaticamente após a confirmação de um Pedido. Representa o pacote físico que precisa ser transportado do endereço da Loja até o endereço do Cliente.                                                                | Pacote, Frete, Tarefa de Transporte                |
| **Rota**                       | Agrupamento lógico de uma ou mais Entregas (limitado a duas por regra de negócio) atribuídas simultaneamente a um único Entregador. Otimiza o trajeto e a eficiência logística.                                                                                      | Lote de Entregas, Trajeto, Jornada                 |
| **Véiculo / Modal**            | O tipo de meio de transporte (Bicicleta, Moto, Carro) registrado e utilizado pelo Entregador para realizar a Rota. Impacta o raio de alcance logístico e as restrições operacionais.                                                                                 | Meio de Transporte, Modalidade                     |
| **Repasse / Split Financeiro** | Processo de divisão de pagamentos executado automaticamente pelo sistema após a conclusão da Entrega, onde o valor total pago pelo cliente é fracionado e destinado aos atores envolvidos: receita da Loja, comissão do Entregador e taxa retida pela plataforma.    | Divisão de Pagamento, Comissionamento, Faturamento |
| **Histórico de Status**        | Tabela de auditoria imutável que registra, com carimbo de tempo (timestamp), cada mudança de fase pela qual um Pedido ou uma Entrega passou, garantindo rastreabilidade completa e conformidade.                                                                     | Linha do Tempo, Rastreio, Trilha de Auditoria      |
| **Cliente**                    | Pessoa Física que realiza compras através da plataforma e é destinatário final das Entregas. Possui endereço de entrega cadastrado.                                                                                                                                  | Consumidor, Comprador, Usuário Final               |
| **Entregador**                 | Pessoa Física parceira da plataforma responsável por executar as Rotas, transportando as Entregas até os endereços dos Clientes utilizando um Veículo específico.                                                                                                    | Motorista, Courier, Profissional de Logística      |

---

## Notas Importantes

- Todos os termos desta tabela devem ser utilizados consistentemente em documentação, requisitos, testes e comunicação do projeto.
- Alterações neste glossário devem ser documentadas e comunicadas a toda a equipe para manter a coesão da linguagem comum a todos.
- O glossário serve como referência para validação de requisitos funcionais e não-funcionais do sistema.
