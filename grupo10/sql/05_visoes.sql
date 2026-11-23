-- =============================================================================
-- VISÕES — ENTREGA E5 (SEÇÃO 7.1)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Comércio e Finanças -> Logística
-- (mesma sequência de 01_esquema.sql).
-- =============================================================================

BEGIN;

-- =============================================================================
-- SUBDOMÍNIO: IDENTIDADE E CONTATO
-- =============================================================================

-- Visão 1: "Administrador / equipe de suporte da plataforma"
-- Objetivo: Uma pessoa pode acumular papéis de cliente, lojista e entregador, com dados distribuídos em seis tabelas (pessoa, cliente, lojista, entregador, telefone e pessoa_endereco). A visão consolida em uma única linha os papéis exercidos, o tipo de veículo, os telefones e a quantidade de endereços vinculados, simplificando o atendimento de chamados.
-- Atualizável? Justifique: Não. A visão combina múltiplas tabelas no FROM com junções externas (LEFT JOIN), utiliza GROUP BY e funções de agregação (COUNT, string_agg) e projeta colunas calculadas (e_cliente, e_lojista, e_entregador, telefones, qtd_enderecos). No PostgreSQL, qualquer INSERT, UPDATE ou DELETE sobre ela é recusado; alterações devem ocorrer nas tabelas-base.
CREATE OR REPLACE VIEW vw_perfil_pessoa AS
SELECT p.id_pessoa,
       p.nome,
       p.cpf,
       p.email,
       (c.id_pessoa IS NOT NULL) AS e_cliente,
       (l.id_pessoa IS NOT NULL) AS e_lojista,
       (e.id_pessoa IS NOT NULL) AS e_entregador,
       e.tipo_veiculo,
       (SELECT string_agg(t.numero || ' (' || t.tipo || ')', ', ' ORDER BY t.tipo)
          FROM telefone t
         WHERE t.id_pessoa = p.id_pessoa) AS telefones,
       COUNT(pe.id_endereco) AS qtd_enderecos
  FROM pessoa p
  LEFT JOIN cliente c
         ON c.id_pessoa = p.id_pessoa
  LEFT JOIN lojista l
         ON l.id_pessoa = p.id_pessoa
  LEFT JOIN entregador e
         ON e.id_pessoa = p.id_pessoa
  LEFT JOIN pessoa_endereco pe
         ON pe.id_pessoa = p.id_pessoa
 GROUP BY p.id_pessoa, p.nome, p.cpf, p.email,
          c.id_pessoa, l.id_pessoa, e.id_pessoa, e.tipo_veiculo;

-- Visão 2: "Equipe de atendimento e telas da aplicação que exibem dados de contato"
-- Objetivo: Expõe apenas identificador, nome e e-mail da pessoa, ocultando o CPF (dado pessoal sensível, seguindo o princípio da minimização de dados da LGPD). Com permissões restritas à visão, o ator consulta e corrige dados de contato sem acessar o CPF.
-- Atualizável? Justifique: Sim (automaticamente atualizável para UPDATE e DELETE, com restrição para INSERT). A consulta possui exatamente uma tabela no FROM (pessoa), sem junções, DISTINCT, GROUP BY ou agregações, e todas as colunas são referências diretas. UPDATE e DELETE funcionam normalmente respeitando CHECK e UNIQUE; porém, INSERT falha na tabela-base porque a coluna obrigatória cpf (NOT NULL) não integra a visão.
CREATE OR REPLACE VIEW vw_contato_pessoa AS
SELECT p.id_pessoa,
       p.nome,
       p.email
  FROM pessoa p;


-- =============================================================================
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =============================================================================

-- Visão 3: "Lojista e administração financeira da plataforma (painel de faturamento, repasses e reputação por loja)"
-- Objetivo: Consolida por loja a quantidade de pedidos concluídos, o faturamento bruto (valor_total), o total líquido repassado à loja (parcela_loja), o total de comissões de entrega (comissao_entregador), a receita retida pela plataforma (taxa_plataforma) e a média de avaliações recebidas pela loja (RF05, RF06, RN05, RN06), evitando que o consumidor reescreva múltiplas junções e agregações.
-- Atualizável? Justifique: Não. A definição combina quatro tabelas no FROM (loja, pedido, divisao_pagamento e avaliacao_loja), utiliza GROUP BY e funções de agregação (COUNT, SUM, AVG, COALESCE). No PostgreSQL, is_updatable = NO; inserções e alterações devem ser feitas nas tabelas-base.
CREATE OR REPLACE VIEW vw_resumo_financeiro_loja AS
SELECT l.id_loja,
       l.nome AS nome_loja,
       COUNT(dp.id_pedido) AS pedidos_concluidos,
       COALESCE(SUM(dp.valor_total), 0.00) AS faturamento_bruto,
       COALESCE(SUM(dp.parcela_loja), 0.00) AS repasse_total_loja,
       COALESCE(SUM(dp.comissao_entregador), 0.00) AS total_comissao_entregadores,
       COALESCE(SUM(dp.taxa_plataforma), 0.00) AS receita_plataforma,
       ROUND(AVG(al.nota), 2) AS media_avaliacao_loja
  FROM loja l
  LEFT JOIN pedido p
         ON p.id_loja = l.id_loja
        AND p.status = 'concluido'
  LEFT JOIN divisao_pagamento dp
         ON dp.id_pedido = p.id_pedido
  LEFT JOIN avaliacao_loja al
         ON al.id_pedido = p.id_pedido
 GROUP BY l.id_loja, l.nome;


-- =============================================================================
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- Visão 4: "Operação / gestor de Logística (painel de acompanhamento de rotas)"
-- Objetivo: Centralizar o painel operacional das rotas com dados do entregador, total de entregas vinculadas, entregas ativas, entregas atrasadas e vagas disponíveis segundo a RN02/RR02 (máximo de duas entregas por rota, inclusive concluídas).
-- Atualizável? Justifique: Não. A definição combina múltiplas tabelas no FROM (rota, entregador, pessoa, entrega), utiliza GROUP BY e funções de agregação (COUNT e COUNT FILTER) além de coluna calculada (CASE para vagas). No PostgreSQL, is_updatable = NO; escritas devem ser realizadas diretamente nas tabelas-base.
CREATE OR REPLACE VIEW vw_painel_rotas_logistica AS
SELECT r.id_rota,
       r.id_entregador,
       p.nome AS nome_entregador,
       en.tipo_veiculo,
       r.criada_em,
       r.encerrada_em,
       COUNT(e.id_entrega) AS total_entregas,
       COUNT(e.id_entrega) FILTER (
           WHERE e.status IN ('aceita', 'a_caminho')
       ) AS entregas_ativas,
       COUNT(e.id_entrega) FILTER (
           WHERE e.status IN ('aceita', 'a_caminho')
             AND e.previsao_entrega < CURRENT_TIMESTAMP
       ) AS entregas_atrasadas,
       CASE
           WHEN r.encerrada_em IS NULL THEN GREATEST(0, 2 - COUNT(e.id_entrega))
           ELSE 0
       END AS vagas
  FROM rota AS r
INNER JOIN entregador AS en
        ON en.id_pessoa = r.id_entregador
INNER JOIN pessoa AS p
        ON p.id_pessoa = en.id_pessoa
  LEFT JOIN entrega AS e
         ON e.id_rota = r.id_rota
 GROUP BY r.id_rota,
          r.id_entregador,
          p.nome,
          en.tipo_veiculo,
          r.criada_em,
          r.encerrada_em;


-- =============================================================================
-- SUBDOMÍNIO: AUDITORIA
-- =============================================================================

-- Visão 5: "Cliente, Lojista, Entregador e Administração / Auditoria do Sistema"
-- Objetivo: Consolidar, em uma única linha do tempo cronológica, os marcos do ciclo comercial (historico_pedido) e do ciclo logístico (historico_entrega) associados a cada pedido, permitindo consultar o rastreio completo passo a passo sem reescrever junções e uniões entre os dois subdomínios (RF05, RN04).
-- Atualizável? Justifique: Não. A definição utiliza o operador de conjunto UNION ALL, combina múltiplas tabelas no FROM com junções internas (INNER JOIN) e projeta colunas derivadas por literais e conversões de tipo (dominio_evento, status_evento), fazendo com que is_updatable = NO no PostgreSQL. Além disso, pela regra de negócio (RN08, RR11), as tabelas de auditoria são estritamente append-only e imutáveis, devendo ser alimentadas exclusivamente pelos gatilhos de transição de estado.
CREATE OR REPLACE VIEW vw_auditoria_linha_tempo_pedido AS
SELECT p.id_pedido,
       p.id_loja,
       p.id_cliente,
       'COMERCIAL'::VARCHAR(15) AS dominio_evento,
       hp.status::TEXT          AS status_evento,
       hp.data_hora
  FROM historico_pedido hp
INNER JOIN pedido p
        ON p.id_pedido = hp.id_pedido

UNION ALL

SELECT e.id_pedido,
       p.id_loja,
       p.id_cliente,
       'LOGISTICO'::VARCHAR(15) AS dominio_evento,
       he.status::TEXT          AS status_evento,
       he.data_hora
  FROM historico_entrega he
INNER JOIN entrega e
        ON e.id_entrega = he.id_entrega
INNER JOIN pedido p
        ON p.id_pedido = e.id_pedido;

-- Visão 6: "Lojista e Administração / Auditoria Operacional (painel de pontualidade e SLA de entregas)"
-- Objetivo: Cruzar o carimbo real de conclusão registrado na trilha de auditoria (historico_entrega com status 'entregue') com a previsão contratada (entrega.previsao_entrega) e os dados do pedido e da loja, expondo de forma pronta para relatórios se houve atraso e o desvio em minutos (RF06, RF10, RN03, RN04).
-- Atualizável? Justifique: Não. A consulta combina quatro tabelas no FROM por meio de junções internas (historico_entrega, entrega, pedido e loja) e projeta colunas calculadas por expressões booleanas e aritméticas (atrasada e desvio_minutos), tornando-a somente leitura no PostgreSQL (is_updatable = NO) e preservando a imutabilidade dos registros de auditoria (RN08, RR11).
CREATE OR REPLACE VIEW vw_auditoria_sla_entregas AS
SELECT e.id_entrega,
       e.id_pedido,
       p.id_loja,
       l.nome AS nome_loja,
       e.id_rota,
       p.data_pedido,
       e.previsao_entrega,
       he.data_hora AS entregue_em,
       (he.data_hora > e.previsao_entrega) AS atrasada,
       ROUND(EXTRACT(EPOCH FROM (he.data_hora - e.previsao_entrega)) / 60.0, 2) AS desvio_minutos
  FROM historico_entrega he
INNER JOIN entrega e
        ON e.id_entrega = he.id_entrega
INNER JOIN pedido p
        ON p.id_pedido = e.id_pedido
INNER JOIN loja l
        ON l.id_loja = p.id_loja
 WHERE he.status = 'entregue';


COMMIT;
