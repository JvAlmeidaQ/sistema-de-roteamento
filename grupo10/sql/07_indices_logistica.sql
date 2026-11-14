-- E6, seção 8.1: executar uma vez após a carga.
-- Na comparação de planos, instalar somente após a fase sem índices secundários.
-- Justificativas por tabela, colunas, tipo e consulta beneficiada estão abaixo.
-- PKs e UNIQUEs já possuem índices; FKs não criam índice na coluna de origem.
-- Não duplicar índices de id_rota, id_entrega e id_pedido já fornecidos pelo DDL.
-- Índices têm custo de escrita/armazenamento e não substituem CHECKs ou gatilhos.
-- Planos reais antes/depois de L3/L4: experimentos.md.
BEGIN;

-- Tabela entrega, coluna id_rota, B-tree completo.
-- RN02/RR02: acelera a contagem por rota; atende L1 e a visão do painel.
-- Inclui entregas concluídas porque todas ocupam o limite de vínculos da rota.
CREATE INDEX idx_entrega_rota ON entrega USING btree (id_rota);

-- Tabela rota, coluna id_entregador, B-tree completo.
-- Atende consulta 15 e associação de rotas ao entregador em L3.
-- Não é UNIQUE: um entregador pode ter diversas rotas no histórico.
CREATE INDEX idx_rota_entregador ON rota USING btree (id_entregador);

-- Tabela entrega, colunas previsao_entrega/id_pedido, B-tree parcial.
-- L3/RN03: busca a faixa de previsões vencidas apenas entre estados ativos.
-- CURRENT_TIMESTAMP fica na consulta, não no predicado do índice, que deve
-- ser imutável. O índice não aplica o bloqueio de atribuição da RN03.
CREATE INDEX idx_entrega_ativa_previsao_pedido
    ON entrega USING btree (previsao_entrega, id_pedido)
    WHERE status IN ('aceita', 'a_caminho');

-- Tabela pedido, colunas data_pedido/id_pedido e inclusão de id_loja, B-tree parcial.
-- L4: filtra prontos; as chaves acompanham a ordem da fila global.
-- INCLUDE cobre a projeção, mas Index Only Scan depende do plano e da visibilidade
-- das linhas. O experimento pode escolher Bitmap Heap Scan, sem ganho garantido.
CREATE INDEX idx_pedido_pronto_fila
    ON pedido USING btree (data_pedido, id_pedido) INCLUDE (id_loja)
    WHERE status = 'pronto';

COMMIT;
