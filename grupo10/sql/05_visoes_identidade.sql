-- =================================================================================
-- VISÕES - SUBDOMÍNIO: IDENTIDADE E CONTATO (E5)
-- Arquivo: 05_visoes_identidade.sql
--
-- Para cada visão: ator que a acessa, justificativa e análise de atualização.
--
-- Regra geral do PostgreSQL para uma visão ser AUTOMATICAMENTE atualizável
-- (aceitar INSERT, UPDATE e DELETE sem gatilhos):
--   - ter exatamente UMA tabela (ou visão atualizável) no FROM;
--   - não usar GROUP BY, HAVING, DISTINCT, funções de agregação, LIMIT/OFFSET,
--     UNION/INTERSECT/EXCEPT nem WITH;
--   - só as colunas que são referências diretas a colunas da tabela podem ser
--     alteradas (colunas calculadas ficam somente leitura).
-- =================================================================================


-- =================================================================================
-- Visão 1 — vw_perfil_pessoa
--
-- Ator: Administrador / suporte da plataforma.
--
-- Justificativa: Uma pessoa pode acumular os papéis de cliente, lojista e
-- entregador, e as informações ficam espalhadas em seis tabelas (pessoa,
-- cliente, lojista, entregador, telefone e pessoa_endereco). Para atender um
-- chamado, o suporte precisa ver tudo em uma única linha: quais papéis a pessoa
-- exerce, o veículo (se for entregadora), seus telefones e quantos endereços
-- tem cadastrados. A visão esconde essas junções e agregações do ator.
--
-- Análise de atualização: NÃO é atualizável.
--   - Usa várias tabelas no FROM (junções externas).
--   - Usa GROUP BY e funções de agregação (string_agg, COUNT).
--   - As colunas e_cliente, e_lojista, e_entregador, telefones e
--     qtd_enderecos são calculadas: não correspondem a nenhuma coluna real
--     que o SGBD possa alterar.
--   Qualquer INSERT, UPDATE ou DELETE na visão é recusado. Exemplo:
--     UPDATE vw_perfil_pessoa SET nome = 'Teste' WHERE id_pessoa = 1;
--     ERROR:  cannot update view "vw_perfil_pessoa"
--     DETAIL:  Views that do not select from a single table or view are not automatically updatable.
--   As alterações devem ser feitas nas tabelas de origem.
-- =================================================================================
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
         ON (c.id_pessoa = p.id_pessoa)
  LEFT JOIN lojista l
         ON (l.id_pessoa = p.id_pessoa)
  LEFT JOIN entregador e
         ON (e.id_pessoa = p.id_pessoa)
  LEFT JOIN pessoa_endereco pe
         ON (pe.id_pessoa = p.id_pessoa)
 GROUP BY p.id_pessoa, p.nome, p.cpf, p.email,
          c.id_pessoa, l.id_pessoa, e.id_pessoa, e.tipo_veiculo;

-- Exemplo de uso: perfil das pessoas que exercem os três papéis.
-- Resultado esperado na carga: 20 linhas (pessoas 101 a 120).
SELECT *
  FROM vw_perfil_pessoa
 WHERE e_cliente AND e_lojista AND e_entregador
 ORDER BY id_pessoa;


-- =================================================================================
-- Visão 2 — vw_contato_pessoa
--
-- Ator: Equipe de atendimento (e telas da aplicação que exibem dados de
-- contato, como o nome do entregador para o cliente).
--
-- Justificativa: O atendimento precisa do nome e do e-mail para contatar uma
-- pessoa, mas não precisa do CPF, que é dado pessoal sensível. Seguindo o
-- princípio da minimização de dados da LGPD, a visão expõe apenas id, nome e
-- e-mail; com permissões (GRANT) só na visão, esse ator nunca acessa o CPF.
--
-- Análise de atualização: É atualizável (automaticamente), com uma ressalva.
--   - Tem uma única tabela no FROM (pessoa), sem junção, agregação, DISTINCT
--     nem GROUP BY, e todas as colunas são referências diretas a pessoa.
--   - UPDATE: funciona. Ex.: corrigir o e-mail de uma pessoa pela visão
--       UPDATE vw_contato_pessoa SET email = 'novo@exemplo.com' WHERE id_pessoa = 1;
--       UPDATE 1
--     As restrições da tabela continuam valendo (CHECK e UNIQUE do e-mail).
--   - DELETE: funciona e apaga a linha em pessoa (com o CASCADE das FKs para
--     telefone, papéis e vínculos de endereço). Na prática, a permissão de
--     DELETE não seria concedida a esse ator.
--   - INSERT: é aceito pela visão, mas falha na tabela, porque a coluna cpf é
--     NOT NULL e não está na visão (fica NULL):
--       INSERT INTO vw_contato_pessoa (nome, email) VALUES ('Teste', 'teste@exemplo.com');
--       ERROR:  null value in column "cpf" of relation "pessoa" violates not-null constraint
--     Ou seja: a visão é atualizável para UPDATE e DELETE, mas não serve para
--     cadastrar pessoas, o que é coerente com o ator (atendimento não cadastra).
-- =================================================================================
CREATE OR REPLACE VIEW vw_contato_pessoa AS
SELECT p.id_pessoa,
       p.nome,
       p.email
  FROM pessoa p;

-- Exemplo de uso: contato dos entregadores que usam moto.
-- Resultado esperado na carga: 40 linhas.
SELECT vc.id_pessoa,
       vc.nome,
       vc.email
  FROM vw_contato_pessoa vc
INNER JOIN entregador e
        ON (e.id_pessoa = vc.id_pessoa)
 WHERE e.tipo_veiculo = 'moto'
 ORDER BY vc.id_pessoa;
