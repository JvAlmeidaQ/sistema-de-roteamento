# ADR-001: Integridade de loja via chaves estrangeiras compostas

## Status

Aceito

## Data

31/10/26 (Marco E2)

## Rastreabilidade e Escopo

- **Origem:** Comentário do professor na correção da E1 — a **RN07** só funciona em DDL se a loja fizer parte de uma chave estrangeira composta.
- **Requisitos e Regras Relacionadas:** RF02, RN07.
- **Relações Afetadas:** `Produto`, `Categoria`, `Pedido`, `Item_Pedido`, `Produto_Categoria`.

## Contexto

O sistema é um marketplace em que cada loja define seu próprio catálogo e seus próprios preços:

- Um pedido pertence a uma única loja, e todos os seus itens devem pertencer ao catálogo dessa mesma loja (**RN07**).
- Duas farmácias ou restaurantes que vendem o mesmo item possuem produtos distintos no banco, cada um com o preço da sua respectiva loja.
- Filiais e franquias possuem CNPJ diferente; portanto, cada CNPJ corresponde a uma `Loja` independente.

Precisamos garantir diretamente no esquema relacional (DDL) que um `Item_Pedido` nunca associe um `Pedido` da Loja A com um `Produto` da Loja B, e que `Produto_Categoria` nunca associe produtos e categorias de lojas distintas.

## Decisão

Adotar chaves únicas compostas incluindo `id_loja` nas tabelas base e referenciá-las via chaves estrangeiras compostas nas tabelas associativas:

1. `Produto`, `Categoria` e `Pedido` recebem uma chave única composta (`UNIQUE`) com a loja:
   - `Produto`: `UK (id_loja, id_produto)`
   - `Categoria`: `UK (id_loja, id_categoria)`
   - `Pedido`: `UK (id_loja, id_pedido)`
2. `Item_Pedido` inclui a coluna `id_loja` e define duas chaves estrangeiras compostas:
   - `FK (id_loja, id_pedido)` referenciando `Pedido (id_loja, id_pedido)`
   - `FK (id_loja, id_produto)` referenciando `Produto (id_loja, id_produto)`
3. `Produto_Categoria` inclui a coluna `id_loja` e referencia `Produto (id_loja, id_produto)` e `Categoria (id_loja, id_categoria)` da mesma forma.
4. Como o mesmo atributo `id_loja` participa de ambas as chaves estrangeiras na linha associativa, o próprio SGBD rejeita qualquer tentativa de relacionar registros de lojas diferentes.

## Alternativas Consideradas

### 1. Restrição `CHECK` com subconsulta a outra tabela

- **Prós:** Não exigiria repetir `id_loja` nas tabelas associativas.
- **Contras:** O PostgreSQL não suporta subconsultas (`SELECT`) dentro de cláusulas `CHECK`.
- **Motivo do descarte:** Inviabilidade técnica no SGBD adotado.

### 2. Gatilho (`TRIGGER`) que compara a loja do produto com a do pedido

- **Prós:** Mantém as tabelas associativas sem o atributo redundante `id_loja`.
- **Contras:** Retira a garantia estrutural do DDL, adiciona o custo de uma consulta extra por inserção e pode ser desativado acidentalmente.
- **Motivo do descarte:** O edital e a correção da E1 priorizam garantias declarativas em DDL sempre que viável.

### 3. Validação apenas na camada de aplicação

- **Prós:** Simplicidade no modelo físico.
- **Contras:** Nenhuma garantia de integridade no banco de dados caso ocorram inserções diretas ou bugs na aplicação.
- **Motivo do descarte:** Viola a diretriz de integridade relacional da disciplina de Banco de Dados.

### 4. Catálogo global com preço por loja

- **Prós:** Evitaria duplicação de cadastro de produtos comuns entre lojas.
- **Contras:** Contraria a autonomia de cada loja sobre seu próprio catálogo, descrições, categorias e preços.
- **Motivo do descarte:** Desalinhado com o modelo de negócio definido para o marketplace.

## Consequências

### Positivas

- A **RN07** passa a ser garantida declarativamente pelo próprio SGBD (em nível de DDL), sem depender de código procedural ou gatilhos.

### Negativas / Trade-offs

- `id_loja` torna-se funcionalmente dependente apenas de `id_pedido` (ou `id_produto`), sendo redundante em `Item_Pedido` e `Produto_Categoria`. Essa violação intencional da **2FN** foi documentada na etapa de normalização (E2, seção 3.3): a decomposição seria possível e sem perdas, mas removeria a garantia em DDL.
- A camada de aplicação (ou script de inserção) precisa informar o `id_loja` ao inserir registros em `Item_Pedido` e `Produto_Categoria`.
