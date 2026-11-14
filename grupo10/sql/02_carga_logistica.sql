-- E4: carga única da Logística, após as cargas externas e antes dos gatilhos.
-- Usa pedidos prontos/concluídos sem entrega e entregadores existentes.
-- O volume depende da carga de pedidos: ao menos uma tabela dos experimentos
-- deve ter 200 mil linhas. O roteiro de validação fornece 500 mil pedidos.
-- É um snapshot anterior aos gatilhos, não uma simulação das transições RR06.
-- A transação evita carga parcial; tabelas temporárias são removidas no COMMIT.
BEGIN;

-- Numera os pedidos reais para distribuir os cenários sem assumir IDs consecutivos.
-- Um em cada cinco prontos fica sem entrega, permitindo consultar a diferença L6.
-- Nos demais, o módulo 3 distribui os estados iniciais/ativos. São cenários de
-- demonstração da seção 6, não uma regra adicional de criação no fluxo real.
CREATE TEMP TABLE carga_logistica_pedidos ON COMMIT DROP AS
WITH candidatos AS (
    SELECT p.id_pedido, p.status,
           ROW_NUMBER() OVER (PARTITION BY p.status ORDER BY p.id_pedido) AS numero
    FROM pedido p
    WHERE p.status IN ('pronto', 'concluido')
      AND NOT EXISTS (SELECT 1 FROM entrega e WHERE e.id_pedido = p.id_pedido)
)
SELECT id_pedido,
       CASE WHEN status = 'concluido' THEN 'entregue'
            WHEN numero % 3 = 1 THEN 'aguardando_entregador'
            WHEN numero % 3 = 2 THEN 'aceita'
            ELSE 'a_caminho' END::status_entrega AS status
FROM candidatos
WHERE status = 'concluido' OR numero % 5 <> 0;

-- Pré-condição da carga, sem RN própria. Se faltar dado externo, aborta tudo.
-- Erro P0001: Carga logística exige entregadores e pedidos prontos/concluídos sem entrega
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM entregador)
       OR NOT EXISTS (SELECT 1 FROM carga_logistica_pedidos) THEN
        RAISE EXCEPTION 'Carga logística exige entregadores e pedidos prontos/concluídos sem entrega';
    END IF;
END;
$$;

-- RN02/RR02: agrupa os pedidos atribuídos em pares, separando rotas ativas
-- das históricas. Entregas aguardando entregador continuam sem rota.
-- (ROW_NUMBER + 1) / 2 faz cada par compartilhar a mesma rota; o último pode
-- ficar sozinho. A contagem vale também para as entregas concluídas.
CREATE TEMP TABLE carga_logistica_vinculos ON COMMIT DROP AS
SELECT id_pedido, status = 'entregue' AS encerrada,
       (ROW_NUMBER() OVER (PARTITION BY (status = 'entregue') ORDER BY id_pedido) + 1) / 2 AS numero_rota
FROM carga_logistica_pedidos
WHERE status <> 'aguardando_entregador';

-- generate_series cria apenas as rotas necessárias a cada grupo.
-- Os entregadores são distribuídos pelos IDs existentes em ordem, ciclicamente.
-- RETURNING recupera as IDs reais; a numeração por grupo preserva o pareamento
-- da inserção ordenada sem exigir que a sequência de rota comece em 1 ou seja contínua.
CREATE TEMP TABLE carga_logistica_rotas ON COMMIT DROP AS
WITH entregadores AS (
    SELECT ARRAY_AGG(id_pessoa ORDER BY id_pessoa) AS ids FROM entregador
), grupos AS (
    SELECT encerrada, MAX(numero_rota) AS total FROM carga_logistica_vinculos GROUP BY encerrada
), novas AS (
    INSERT INTO rota (id_entregador, criada_em, encerrada_em)
    SELECT en.ids[((g.numero - 1) % cardinality(en.ids) + 1)::INT],
           CURRENT_TIMESTAMP - CASE WHEN gr.encerrada THEN INTERVAL '1 day' ELSE INTERVAL '10 minutes' END,
           CASE WHEN gr.encerrada THEN CURRENT_TIMESTAMP - INTERVAL '23 hours' END
    FROM grupos gr
    CROSS JOIN LATERAL generate_series(1, gr.total) AS g(numero)
    CROSS JOIN entregadores en
    ORDER BY gr.encerrada, g.numero
    RETURNING id_rota, encerrada_em
)
SELECT id_rota, encerrada_em IS NOT NULL AS encerrada,
       ROW_NUMBER() OVER (PARTITION BY (encerrada_em IS NOT NULL) ORDER BY id_rota) AS numero_rota
FROM novas;

-- RN12/RR07: prontos geram entregas pendentes/ativas; concluídos representam
-- entregas históricas finalizadas. Metade das rotas ativas recebe previsão vencida
-- para L3/RN03; a outra metade recebe previsão futura. O critério usa a numeração
-- das rotas, não a paridade dos IDs externos. Os horários mudam de significado
-- com o tempo: os resultados de atraso devem ser observados logo após a carga.
INSERT INTO entrega (id_pedido, id_rota, status, previsao_entrega)
SELECT p.id_pedido, r.id_rota, p.status,
       CURRENT_TIMESTAMP + CASE
           WHEN p.status = 'entregue' THEN INTERVAL '-23 hours'
           WHEN p.status = 'aguardando_entregador' THEN INTERVAL '45 minutes'
           WHEN v.numero_rota % 2 = 0 THEN INTERVAL '-10 minutes'
           ELSE INTERVAL '30 minutes' END
FROM carga_logistica_pedidos p
LEFT JOIN carga_logistica_vinculos v USING (id_pedido)
LEFT JOIN carga_logistica_rotas r USING (encerrada, numero_rota);

-- Uma rota aberta vazia representa capacidade disponível para o próximo despacho.
-- Garante também um resultado para a consulta de vagas, mesmo com os pares completos.
INSERT INTO rota (id_entregador) SELECT MIN(id_pessoa) FROM entregador;

-- Seção 5.2: ANALYZE atualiza cardinalidade e distribuição para o planejador.
-- As estatísticas são da mesma base utilizada nas consultas e nos experimentos;
-- sem elas, os custos estimados antes/depois poderiam partir de dados desatualizados.
ANALYZE pedido;
ANALYZE rota;
ANALYZE entrega;
COMMIT;
