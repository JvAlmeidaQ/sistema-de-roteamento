# ADR-002: Snapshots históricos no pedido e endereços imutáveis

## Status

Aceito

## Data

31/10/26 (Marco E2)

## Rastreabilidade e Escopo

- **Origem:** Requisitos de rastreabilidade e auditoria financeira/logística levantados na E1 e consolidados na E2.
- **Requisitos e Regras Relacionadas:** RF01, RF02, RF09, RN05, RN09.
- **Relações Afetadas:** `Pedido`, `Item_Pedido`, `Endereco`, `Pessoa_Endereco`, `Cliente`.

## Contexto

No operação contínua do marketplace, preços de produtos sofrem reajustes, taxas de entrega das lojas mudam, produtos são pausados e clientes editam ou trocam seus endereços cadastrados.

- A especificação da E1 destaca a rastreabilidade e a confiabilidade histórica como problemas centrais que o sistema resolve: um pedido já realizado não pode ter seu valor financeiro nem seu endereço de destino alterados retroativamente.
- Como as entregas são locais e de curta duração, não há caso de uso para alteração de endereço com o pedido em andamento.

## Decisão

Adotar a estratégia de **snapshots (cópias congeladas no momento da compra)** no pedido e de **imutabilidade para o logradouro (`Endereco`)**:

1. **Snapshots no momento da criação do pedido:**
   - `valor_unitario` em `Item_Pedido`: copia o preço vigente do produto no instante da compra.
   - `taxa_entrega` (da loja), `taxa_servico` (da plataforma) e `valor_total` em `Pedido`.
   - `complemento_entrega` e `referencia_entrega` em `Pedido`: copiam o complemento e a referência do cliente naquele momento.
   - `id_endereco` gravado diretamente em `Pedido`: se o cliente alterar seu `id_endereco_atual` posteriormente, os pedidos anteriores permanecem inalterados.
2. **Modelo de Endereços (inspirado no iFood):**
   - `Endereco` representa a localização física no nível da rua (`logradouro`, `numero`, `bairro`, `cep`, `cidade`, `estado`) e é **imutável** após cadastrado (protegido por gatilho). A mesma linha pode ser compartilhada por diferentes moradores por meio da tabela associativa `Pessoa_Endereco`.
   - `complemento`, `referencia` e `apelido` pertencem ao vínculo individual em `Pessoa_Endereco`, permitindo que cada pessoa edite esses dados sem afetar outros moradores nem pedidos passados.
   - O endereço selecionado pelo cliente (`id_endereco_atual` em `Cliente`) utiliza chave estrangeira composta `(id_pessoa, id_endereco_atual)` para `Pessoa_Endereco`, garantindo que o endereço atual pertença àquela pessoa.

## Alternativas Consideradas

### 1. Ler sempre os dados vivos das tabelas de catálogo e cadastro

- **Prós:** Zero redundância de dados; estrita aderência à 3FN sem ressalvas.
- **Contras:** Qualquer reajuste de preço na loja ou edição de endereço pelo cliente alteraria o valor e o histórico de pedidos já concluídos.
- **Motivo do descarte:** Inviabiliza auditoria financeira e histórica.

### 2. Tabelas de versionamento temporal para `Produto` e `Endereco`

- **Prós:** Preserva todo o histórico de preços e endereços sem copiar atributos para `Pedido` e `Item_Pedido`.
- **Contras:** Aumenta drasticamente a complexidade de consultas, chaves estrangeiras e manutenção para o escopo acadêmico do projeto.
- **Motivo do descarte:** Complexidade desproporcional ao escopo.

### 3. Endereço editável com propagação (`UPDATE`)

- **Prós:** Permite corrigir erros de digitação na própria linha de `Endereco`.
- **Contras:** Editar o endereço de um morador alteraria o endereço de outros moradores do mesmo imóvel e adulteraria o destino histórico de pedidos antigos.
- **Motivo do descarte:** Quebra o isolamento entre usuários e a imutabilidade do histórico de entregas.

### 4. Endereço exclusivo por pessoa (sem compartilhamento)

- **Prós:** Elimina a tabela associativa `Pessoa_Endereco`.
- **Contras:** Duplica linhas idênticas de logradouro/CEP para pessoas que residem no mesmo local ou quando uma loja e uma pessoa dividem o mesmo endereço.
- **Motivo do descarte:** A separação entre `Endereco` (imóvel) e `Pessoa_Endereco` (vínculo pessoal) modela melhor o domínio.

## Consequências

### Positivas

- Histórico financeiro e logístico de todos os pedidos permanece íntegro e auditável independentemente de alterações futuras no catálogo ou no cadastro do cliente.

### Negativas / Trade-offs

- **Redundâncias intencionais declaradas na normalização (E2):** `valor_unitario` em `Item_Pedido`, cópias de taxas/complemento em `Pedido`, e `valor_total` (que é derivado de `subtotal + taxa_entrega + taxa_servico`, configurando dependência transitiva / violação controlada da 3FN em `Pedido`).
- A aplicação **nunca deve recalcular** retroativamente esses campos a partir de `Loja`, `Produto` ou `Cliente` após a criação do pedido.
- Exige restrições adicionais de consistência (`CHECK` para `valor_total = subtotal + taxa_entrega + taxa_servico`, conferência do subtotal com os itens e verificação de posse do endereço).
