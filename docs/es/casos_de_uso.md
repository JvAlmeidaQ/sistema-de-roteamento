# Diagrama de Casos de Uso

```mermaid
flowchart LR

    %% Atores
    C["Cliente"]
    L["Lojista"]
    E["Entregador"]

    %% Fronteira do sistema
    subgraph Sistema["Sistema de Roteamento de Pedidos"]
        direction TB

        UC1(["Cadastrar e Gerenciar Conta"])
        UC2(["Gerenciar Loja e Catálogo"])
        UC3(["Criar Pedido e Realizar Pagamento"])
        UC4(["Rastrear Pedido e Entrega"])
        UC5(["Atualizar Status de Preparação"])
        UC6(["Visualizar e Assumir Rota de Entrega"])
        UC7(["Atualizar Status Logístico"])
        UC8(["Avaliar Lojista e Entregador"])
        UC9(["Visualizar Relatórios de Desempenho e Faturamento"])
        UC10(["Calcular Divisão Financeira (Split)"])
    end

    %% Relacionamentos - Cliente
    C --- UC1
    C --- UC3
    C --- UC4
    C --- UC8

    %% Relacionamentos - Lojista
    L --- UC1
    L --- UC2
    L --- UC4
    L --- UC5
    L --- UC9

    %% Relacionamentos - Entregador
    E --- UC1
    E --- UC4
    E --- UC6
    E --- UC7

    %% Relacionamento entre casos de uso
    %% A conclusão da entrega dispara o cálculo do Split
    UC7 -.->|include| UC10

    %% Atores
    classDef actor fill:#FFFFFF,stroke:#FFFFFF,stroke-width:2px,color:#000000,font-weight:bold;

    %% Casos de uso
    classDef usecase fill:#1565C0,stroke:#90CAF9,stroke-width:2px,color:#FFFFFF,font-weight:bold;

    %% Fronteira do sistema
    classDef system fill:#1E1E1E,stroke:#FFFFFF,stroke-width:2px,color:#FFFFFF;

    class C,L,E actor;
    class UC1,UC2,UC3,UC4,UC5,UC6,UC7,UC8,UC9,UC10 usecase;

    style Sistema fill:#1E1E1E,stroke:#FFFFFF,stroke-width:2px,stroke-dasharray:5 5,color:#FFFFFF;
```

### Mapeamento: Casos de Uso Principais vs. Entidades Envolvidas

Para garantir a rastreabilidade entre os fluxos de interação e o modelo de banco de dados, mapeamos as entidades manipuladas pelos 3 Casos de Uso críticos do sistema:

1. **Fazer Pedido (UC1)**
   - **Ator:** Cliente
   - **Entidades Envolvidas:** `Cliente` (quem faz), `Loja` (de onde compra), `Produto` (o que compra), `Pedido` (a transação), `Item_Pedido` (as quantidades e preços) e `Endereço` (destino).

2. **Aceitar Corrida / Assumir Rota (UC8)**
   - **Ator:** Entregador
   - **Entidades Envolvidas:** `Entregador` (quem aceita), `Rota` (o agrupador logístico), `Entrega` (a tarefa) e `Historico_Status_Entrega` (auditoria do aceite).

3. **Finalizar Entrega / Atualizar Status (UC9)**
   - **Ator:** Entregador
   - **Entidades Envolvidas:** `Entrega` (atualização do status final), `Historico_Status_Entrega` (auditoria da conclusão) e o acionamento via _include_ da `Divisao_Pagamento` (Split).
