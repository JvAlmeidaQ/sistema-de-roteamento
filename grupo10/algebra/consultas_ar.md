# Entrega E3 — Consultas em Álgebra Relacional

**Tema:** Sistema de Roteamento de Entregas

## Grupo 10

- João Vitor Almeida Queiroz - 202435007
- Arthur de Souza Marques - 202435015
- Gustavo Bersan Moreira Campos - 202435019
- Murilo Lacerda Dutra - 202435023
- Theo Carvalho de Faria - 202435037

---

# 1. Identidade e Contato

## Consulta 1

**Pergunta:** Quais pessoas atuam como Lojista ou como Entregador e não possuem nenhum telefone do tipo celular (nome e e-mail)?

1. **Operacionais** ← π_id_pessoa(`Lojista`) ∪ π_id_pessoa(`Entregador`)
2. **ComCelular** ← π_id_pessoa(σ_tipo = 'celular'(`Telefone`))
3. **SemCelular** ← **Operacionais** − **ComCelular**
4. **Resultado** ← π_nome, email(**SemCelular** ⋈ `Pessoa`)

## Consulta 2

**Pergunta:** Quais pessoas são, ao mesmo tempo, Cliente e Entregador e possuem pelo menos um telefone de cada tipo cadastrado no sistema (nome e tipo de veículo)?

1. **Tipos** ← π_tipo(`Telefone`)
2. **PessoaTipo** ← π_id_pessoa, tipo(`Telefone`)
3. **TodosOsTipos** ← **PessoaTipo** ÷ **Tipos**
4. **ClienteEntreg** ← π_id_pessoa(`Cliente`) ∩ π_id_pessoa(`Entregador`)
5. **Alvo** ← **TodosOsTipos** ∩ **ClienteEntreg**
6. **Resultado** ← π_nome, tipo_veiculo((**Alvo** ⋈ `Pessoa`) ⋈ `Entregador`)

---

# 2. Catálogo

## Consulta 3

**Pergunta:** Quais produtos ativos pertencem a lojas abertas com entrega gratuita? Mostrar identificador, nome e preço do produto e o identificador da loja.

1. **LojasSelecionadas** ← σ_status_funcionamento = 'aberta' ∧ taxa_entrega = 0(`Loja`)
2. **ProdutosAtivos** ← σ_ativo = TRUE(`Produto`)
3. **LojasIds** ← π_id_loja(**LojasSelecionadas**)
4. **Resultado** ← π_id_produto, nome, preco, id_loja(**ProdutosAtivos** ⋈ **LojasIds**)

## Consulta 4

**Pergunta:** Quais produtos cadastrados nunca foram incluídos em nenhum pedido? Mostrar identificador, nome e identificador da loja.

1. **Cadastrados** ← π_id_produto(`Produto`)
2. **Pedidos** ← π_id_produto(`Item_Pedido`)
3. **NuncaPedidos** ← **Cadastrados** − **Pedidos**
4. **Resultado** ← π_id_produto, nome, id_loja(**NuncaPedidos** ⋈ `Produto`)

## Consulta 5

**Pergunta:** Qual a relação de todos os produtos com suas categorias? Produtos ainda sem categoria também devem aparecer. Mostrar nome do produto, preço e nome da categoria.

1. **ProdutosBase** ← π_id_loja, id_produto, nome, preco(`Produto`)
2. **Associacoes** ← π_id_loja, id_produto, id_categoria(`Produto_Categoria`)
3. **ComAssoc** ← **ProdutosBase** ⟕ **Associacoes**
4. **Categorias** ← ρ_Categorias(id_loja, id_categoria, nome_categoria)(π_id_loja, id_categoria, nome(`Categoria`))
5. **Resultado** ← π_nome, preco, nome_categoria(**ComAssoc** ⟕ **Categorias**)

## Consulta 6

**Pergunta:** Quais lojas possuem produtos associados a pelo menos duas categorias diferentes? Mostrar identificador e nome da loja.

1. **CategoriasProdutos** ← π_id_loja, id_categoria(`Produto_Categoria`)
2. C_1 ← ρ_C_1(id_loja_1, id_categoria_1)(**CategoriasProdutos**)
3. C_2 ← ρ_C_2(id_loja_2, id_categoria_2)(**CategoriasProdutos**)
4. **Pares** ← C_1 ⋈\_(id_loja_1 = id_loja_2 ∧ id_categoria_1 < id_categoria_2) C_2
5. **LojasSelecionadas** ← ρ_LojasSelecionadas(id_loja)(π_id_loja_1(**Pares**))
6. **Resultado** ← π_id_loja, nome(**LojasSelecionadas** ⋈ `Loja`)

## Consulta 7

**Pergunta:** Quais lojas possuem pelo menos um produto ativo em cada faixa de preço: econômico (até R\$ 20), intermediário (acima de R\$ 20 até R\$ 50) e premium (acima de R\$ 50)? Mostrar nome e CNPJ da loja.

1. **LojasEconomicas** ← π_id_loja(σ_ativo = TRUE ∧ preco ≤ 20(`Produto`))
2. **LojasIntermediarias** ← π_id_loja(σ_ativo = TRUE ∧ preco > 20 ∧ preco ≤ 50(`Produto`))
3. **LojasPremium** ← π_id_loja(σ_ativo = TRUE ∧ preco > 50(`Produto`))
4. **EcoEInter** ← **LojasEconomicas** ∩ **LojasIntermediarias**
5. **TodasFaixas** ← **EcoEInter** ∩ **LojasPremium**
6. **Resultado** ← π_nome, cnpj(**TodasFaixas** ⋈ `Loja`)

---

# 3. Comércio e Finanças

## Consulta 8

**Pergunta:** Quais lojas (nome e CNPJ) já tiveram pedidos concluídos com todas as formas de pagamento usadas na plataforma?

1. **Concluidos** ← σ_status = 'concluido'(`Pedido`)
2. **LojasFormas** ← π_id_loja, forma_pagamento(**Concluidos**)
3. **Formas** ← π_forma_pagamento(**Concluidos**)
4. **Todas** ← **LojasFormas** ÷ **Formas**
5. **Resultado** ← π_nome, cnpj(**Todas** ⋈ `Loja`)

## Consulta 9

**Pergunta:** Quais pedidos (exibindo id_pedido e valor_total) geraram comissão ao entregador estritamente maior que a parcela repassada à loja?

1. **DivisaoFiltrada** ← σ_comissao_entregador > parcela_loja(`Divisao_Pagamento`)
2. **Resultado** ← π_id_pedido, valor_total(**DivisaoFiltrada**)

## Consulta 10

**Pergunta:** Quais pedidos tiveram valor total superior a R\$ 100,00 e receberam avaliação ruim da loja (nota 1 ou 2)?

1. **PedidosCaros** ← σ_valor_total > 100(`Pedido`)
2. **AvaliacoesRuins** ← σ_nota ≤ 2(`Avaliacao_Loja`)
3. **Resultado** ← π_id_pedido, id_loja, valor_total, nota(**PedidosCaros** ⋈ **AvaliacoesRuins**)

## Consulta 11

**Pergunta:** Quais pedidos já foram entregues, mas ainda não receberam a avaliação da loja, do entregador ou de ambos? Mostrar o identificador do pedido e do cliente.

1. **Entregues** ← π_id_pedido(σ_status = 'entregue'(`Entrega`))
2. **ComAvalLoja** ← π_id_pedido(`Avaliacao_Loja`)
3. **ComAvalEntreg** ← π_id_pedido(`Avaliacao_Entregador`)
4. **Completas** ← **ComAvalLoja** ∩ **ComAvalEntreg**
5. **Pendentes** ← **Entregues** − **Completas**
6. **Resultado** ← π_id_pedido, id_cliente(**Pendentes** ⋈ `Pedido`)

## Consulta 12

**Pergunta:** Qual o pedido concluído de maior valor total?

1. **Concluidos** ← σ_status = 'concluido'(`Pedido`)
2. P_1 ← ρ_P_1(**Concluidos**)
3. P_2 ← ρ_P_2(**Concluidos**)
4. **Menores** ← ρ_id_pedido(π_P_1.id_pedido(σ_P_1.valor_total < P_2.valor_total(P_1 × P_2)))
5. **Resultado** ← π_id_pedido(**Concluidos**) − **Menores**

## Consulta 13

**Pergunta:** Quais clientes têm pelo menos um pedido concluído pago com Pix ou dinheiro e pelo menos um pago com cartão de crédito? Mostrar nome e e-mail.

1. **Concluidos** ← σ_status = 'concluido'(`Pedido`)
2. **ClientesPix** ← π_id_cliente(σ_forma_pagamento = 'pix'(**Concluidos**))
3. **ClientesDinheiro** ← π_id_cliente(σ_forma_pagamento = 'dinheiro'(**Concluidos**))
4. **ClientesCredito** ← π_id_cliente(σ_forma_pagamento = 'cartao_credito'(**Concluidos**))
5. **PixOuDinheiro** ← **ClientesPix** ∪ **ClientesDinheiro**
6. **AmbasOpcoes** ← **PixOuDinheiro** ∩ **ClientesCredito**
7. **Resultado** ← π_nome, email(**AmbasOpcoes** ⋈\_(id_cliente = id_pessoa) `Pessoa`)

---

# 4. Logística

## Consulta 14

**Pergunta:** Quais rotas possuem duas entregas aceitas ou a caminho? Mostrar a rota, o entregador e as duas entregas.

1. **Pendentes** ← π_id_entrega, id_rota(σ_status = 'aceita' ∨ status = 'a_caminho'(`Entrega`))
2. E_1 ← ρ_E_1(id_entrega_1, id_rota_1)(**Pendentes**)
3. E_2 ← ρ_E_2(id_entrega_2, id_rota_2)(**Pendentes**)
4. **Pares** ← σ_id_rota_1 = id_rota_2 ∧ id_entrega_1 < id_entrega_2(E_1 × E_2)
5. **Duplas** ← ρ_Duplas(id_rota, id_entrega_1, id_entrega_2)(π_id_rota_1, id_entrega_1, id_entrega_2(**Pares**))
6. **Responsaveis** ← π_id_rota, id_entregador(`Rota`)
7. **Resultado** ← π_id_rota, id_entregador, id_entrega_1, id_entrega_2(**Duplas** ⋈ **Responsaveis**)

## Consulta 15

**Pergunta:** Quais entregadores estão cadastrados e quais rotas abertas têm? Mostrar nome, tipo de veículo e rota, incluindo entregadores sem rota aberta.

1. **EntregadoresPessoa** ← π_id_pessoa, nome, tipo_veiculo(`Entregador` ⋈ `Pessoa`)
2. **RotasAbertas** ← π_id_rota, id_entregador(σ_encerrada_em IS NULL(`Rota`))
3. **ComRotas** ← **EntregadoresPessoa** ⟕\_(id_pessoa = id_entregador) **RotasAbertas**
4. **Resultado** ← π_nome, tipo_veiculo, id_rota(**ComRotas**)

---

# 5. Auditoria

## Consulta 16

**Pergunta:** Quais pedidos foram aceitos pela loja, mas ainda não têm registro de pagamento? Mostrar pedido, loja e cliente.

1. **Aceitos** ← π_id_pedido(σ_status = 'aceito'(`Historico_Pedido`))
2. **Pagos** ← π_id_pedido(σ_status = 'pago'(`Historico_Pedido`))
3. **AceitosNaoPagos** ← **Aceitos** − **Pagos**
4. **Resultado** ← π_id_pedido, id_loja, id_cliente(**AceitosNaoPagos** ⋈ `Pedido`)

## Consulta 17

**Pergunta:** Quais entregas foram concluídas depois da previsão de entrega? Mostrar entrega, pedido, previsão e data real de entrega.

1. **HistEntregues** ← σ_status = 'entregue'(`Historico_Entrega`)
2. **Entregues** ← ρ_Entregues(id_entrega_h, data_entrega)(π_id_entrega, data_hora(**HistEntregues**))
3. **Previsoes** ← π_id_entrega, id_pedido, previsao_entrega(`Entrega`)
4. **Atrasadas** ← **Entregues** ⋈\_(id_entrega_h = id_entrega ∧ data_entrega > previsao_entrega) **Previsoes**
5. **Resultado** ← π_id_entrega, id_pedido, previsao_entrega, data_entrega(**Atrasadas**)

---

# 6. Cobertura dos operadores

| Operador                  | Consultas                                     |
| ------------------------- | --------------------------------------------- |
| União                     | 1, 13                                         |
| Interseção                | 2, 7, 11, 13                                  |
| Diferença                 | 1, 4, 11, 12, 16                              |
| Produto cartesiano        | 12, 14                                        |
| Seleção                   | 1, 3, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 |
| Projeção                  | 1 a 17                                        |
| Junção natural            | 1, 2, 3, 4, 6, 7, 8, 10, 11, 14, 15, 16       |
| Junção theta              | 6, 17                                         |
| Equi-junção               | 13                                            |
| Junção externa à esquerda | 5, 15                                         |
| Divisão                   | 2, 8                                          |
