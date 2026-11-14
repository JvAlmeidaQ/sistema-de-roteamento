-- L3 da seção 6: entregadores com entregas ativas atrasadas, apoio à RN03/RR05.
-- A consulta identifica atrasos; o bloqueio de nova atribuição pertence à aplicação.
-- Reproduz L3 de 04, adicionando EXPLAIN ANALYZE. Índice avaliado:
-- idx_entrega_ativa_previsao_pedido, sobre estados ativos e faixa de previsão.
-- EXPLAIN ANALYZE executa o SELECT e mostra o plano; não altera os dados.
-- CURRENT_TIMESTAMP varia com o tempo: medir as duas fases logo após a carga.
EXPLAIN ANALYZE
SELECT
    en.id_pessoa AS id_entregador,
    p.nome
FROM entregador AS en
INNER JOIN pessoa AS p ON p.id_pessoa = en.id_pessoa
WHERE EXISTS (
    SELECT 1
    FROM rota AS r
    INNER JOIN entrega AS e ON e.id_rota = r.id_rota
    WHERE r.id_entregador = en.id_pessoa
      AND e.status IN ('aceita', 'a_caminho')
      AND e.previsao_entrega < CURRENT_TIMESTAMP
)
ORDER BY en.id_pessoa;
