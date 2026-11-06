# ADR-003: Especialização de Pessoa e regras de cardinalidade mínima

## Status

Aceito

## Data

31/10/26 (Marco E2)

## Rastreabilidade e Escopo

- **Origem:** Modelagem conceitual (DER) e mapeamento lógico da E2.
- **Requisitos e Regras Relacionadas:** RF01, RF02, RN10, RN11.
- **Relações Afetadas:** `Pessoa`, `Cliente`, `Lojista`, `Entregador`, `Loja`, `Pedido`, `Item_Pedido`, `Produto_Categoria`, `Telefone`.

## Contexto

No domínio do sistema, a entidade `Pessoa` se especializa em `Cliente`, `Lojista` e `Entregador` de forma **total e sobreposta**:

- Toda pessoa cadastrada possui ao menos um papel no sistema (totalidade).
- A mesma pessoa física (mesmo CPF) pode desempenhar mais de um papel simultaneamente — por exemplo, ser `Cliente` e `Lojista` (sobreposição).
- O banco de dados precisa impedir que um `Pedido` aponte para uma pessoa que não seja `Cliente`, que uma `Loja` aponte para quem não seja `Lojista` ou que uma `Rota` aponte para quem não seja `Entregador`.
- Além disso, o DER estabelece cardinalidades mínimas iguais a 1 em diversos relacionamentos (ex.: todo lojista possui ao menos uma loja; todo pedido possui ao menos um item; toda pessoa possui ao menos um telefone e ao menos um papel), que chaves estrangeiras simples não conseguem impor sozinhas.

## Decisão

1. **Estratégia de mapeamento da herança (uma relação por entidade):**
   - `Pessoa` armazena os atributos comuns (`id_pessoa`, `nome`, `cpf`, `email`).
   - Cada papel (`Cliente`, `Lojista`, `Entregador`) é mapeado como uma tabela própria cuja chave primária (`id_pessoa`) é também chave estrangeira para `Pessoa(id_pessoa)`.
   - `Pedido` referencia `Cliente(id_pessoa)`, `Loja` referencia `Lojista(id_pessoa)` e `Rota` referencia `Entregador(id_pessoa)`, garantindo a integridade do papel via FK.
2. **Garantia de cardinalidade mínima 1:**
   - Para as regras de participação obrigatória (pessoa com ao menos um papel, lojista com ao menos uma loja, pedido com ao menos um item, produto com ao menos uma categoria, pessoa com ao menos um telefone), adotam-se **gatilhos de restrição adiados (`CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`)**, avaliados apenas no momento do `COMMIT` da transação.

## Alternativas Consideradas

### 1. Tabela única (`Pessoa`) com colunas booleanas (flags) por papel

- **Prós:** Dispensa `JOIN`s para consultar dados de papéis.
- **Contras:** Gera atributos nulos (`id_endereco_atual`, `tipo_veiculo`) para papéis que não os utilizam e impede que chaves estrangeiras simples garantam que um `Pedido` aponte apenas para um `Cliente`.
- **Motivo do descarte:** Perda de integridade referencial por papel.

### 2. Apenas tabelas para as subclasses (sem tabela `Pessoa`)

- **Prós:** Elimina a junção com a superclasse `Pessoa`.
- **Contras:** Como a especialização é sobreposta, duplicaria `nome`, `cpf`, `email` e telefones para indivíduos que acumulam mais de um papel, além de impedir unicidade global de CPF via constraint simples.
- **Motivo do descarte:** Anomalias de atualização e duplicação de dados pessoais.

### 3. Gatilho imediato (`BEFORE/AFTER INSERT` convencional) para cardinalidade mínima

- **Prós:** Mais simples de declarar que um `CONSTRAINT TRIGGER` adiado.
- **Contras:** Cria dependência circular (impasse do ovo e da galinha): não seria possível inserir o `Lojista` antes da `Loja`, nem a `Loja` antes do `Lojista`.
- **Motivo do descarte:** Inviabiliza a inserção em duas etapas dentro da mesma transação.

### 4. Validar cardinalidade mínima apenas na aplicação

- **Prós:** Simplifica os scripts de gatilhos no banco.
- **Contras:** Permite estados inconsistentes no banco (como pedidos sem itens ou pessoas sem papel) caso ocorram falhas ou inserções fora da camada de serviço.
- **Motivo do descarte:** Prioridade à integridade garantida pelo SGBD.

## Consequências

### Positivas

- Papéis estritamente garantidos por chaves estrangeiras e atributos específicos isolados em suas respectivas tabelas.
- Sem duplicação de CPF, e-mail ou telefones quando uma pessoa possui múltiplos papéis.

### Negativas / Trade-offs

- Operações de cadastro e criação de pedido precisam ocorrer **dentro de uma mesma transação (`BEGIN ... COMMIT`)**, inserindo a entidade principal e seus dependentes obrigatórios antes do `COMMIT`.
- Consultas que precisam de dados pessoais (como `nome` e `cpf`) de clientes, lojistas ou entregadores exigem `JOIN` com a tabela `Pessoa`.
- Testes de integração do banco e da aplicação devem exercitar o `COMMIT` da transação para validar as restrições adiadas.
