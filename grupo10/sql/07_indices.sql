-- =============================================================================
-- ÍNDICES SECUNDÁRIOS — ENTREGA E6 (SEÇÃO 8.1)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Comércio e Finanças -> Logística
-- (mesma sequência de 01_esquema.sql).
-- Observação: PKs e UNIQUEs já possuem índices no DDL e não são duplicados.
-- =============================================================================

BEGIN;

-- =============================================================================
-- SUBDOMÍNIO: IDENTIDADE E CONTATO
-- =============================================================================

-- Tabela: pessoa_endereco | Coluna: id_endereco | Tipo: B-tree
-- Benefício: Acelera a busca de moradores por endereço (apoia Consulta 3 e
-- checagem do ON DELETE RESTRICT de fk_pessoa_endereco_endereco), pois a PK
-- composta (id_pessoa, id_endereco) começa por id_pessoa.
CREATE INDEX idx_pessoa_endereco_endereco
    ON pessoa_endereco USING btree (id_endereco);

-- Tabela: pessoa | Coluna: nome | Tipo: B-tree
-- Benefício: Acelera buscas por nome exato ou prefixo no atendimento
-- (suporte às consultas de Identidade e Visão 1/Visão 2).
CREATE INDEX idx_pessoa_nome
    ON pessoa USING btree (nome);

-- Tabela: telefone | Coluna: tipo | Tipo: B-tree
-- Benefício pretendido: Filtragem de telefones por tipo (usado em experimentos.md
-- para demonstrar caso em que o otimizador decide NÃO usar o índice devido à
-- baixa seletividade do valor 'celular').
CREATE INDEX idx_telefone_tipo
    ON telefone USING btree (tipo);


-- =============================================================================
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =============================================================================

-- Tabela: pedido | Coluna: valor_total DESC | Tipo: B-tree parcial (status = 'concluido')
-- Benefício: Acelera a Consulta 9 (pedido concluído de maior valor total) e a
-- Consulta 11 (pedidos concluídos acima de R$ 250,00 ordenados por valor).
CREATE INDEX idx_pedido_concluido_valor_total
    ON pedido USING btree (valor_total DESC)
    WHERE status = 'concluido';

-- Tabela: pedido | Colunas: (id_loja, forma_pagamento) | Tipo: B-tree parcial (status = 'concluido')
-- Benefício: Acelera a Consulta 5 (divisão relacional de lojas com pedidos
-- concluídos em todas as formas de pagamento) e o resumo financeiro (Visão 3).
CREATE INDEX idx_pedido_concluido_loja_forma
    ON pedido USING btree (id_loja, forma_pagamento)
    WHERE status = 'concluido';

-- Tabela: pedido | Colunas: (forma_pagamento, id_cliente) | Tipo: B-tree parcial (status = 'concluido')
-- Benefício: Acelera a Consulta 10 (clientes por forma de pagamento em pedidos
-- concluídos).
CREATE INDEX idx_pedido_concluido_cliente_forma
    ON pedido USING btree (forma_pagamento, id_cliente)
    WHERE status = 'concluido';


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- Tabela: entrega | Coluna: id_rota | Tipo: B-tree
-- Benefício: Acelera a contagem de vínculos por rota (RN02/RR02), a Consulta 15
-- e a Visão 4 (vw_painel_rotas_logistica).
CREATE INDEX idx_entrega_rota
    ON entrega USING btree (id_rota);

-- Tabela: rota | Coluna: id_entregador | Tipo: B-tree
-- Benefício: Atende a Consulta 14 (rotas abertas por entregador) e a associação
-- de rotas ao entregador na Consulta 17.
CREATE INDEX idx_rota_entregador
    ON rota USING btree (id_entregador);

-- Tabela: entrega | Colunas: (previsao_entrega, id_pedido) | Tipo: B-tree parcial
-- Benefício: Atende a Consulta 17 (entregadores com entregas ativas atrasadas)
-- indexando apenas linhas nos estados ativos ('aceita', 'a_caminho').
CREATE INDEX idx_entrega_ativa_previsao_pedido
    ON entrega USING btree (previsao_entrega, id_pedido)
    WHERE status IN ('aceita', 'a_caminho');

COMMIT;
