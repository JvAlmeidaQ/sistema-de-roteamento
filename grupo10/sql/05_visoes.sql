-- =============================================================================
-- VISÕES — ENTREGA E5 (SEÇÃO 7.1)
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
-- Ordem dos subdomínios: Identidade e Contato -> Logística (mesma de 01_esquema.sql).
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
-- SUBDOMÍNIO: LOGÍSTICA
-- =============================================================================

-- Visão 3: "Operação / gestor de Logística (painel de acompanhamento de rotas)"
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

COMMIT;
