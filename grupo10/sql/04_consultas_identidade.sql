-- =================================================================================
-- CONSULTAS SQL - SUBDOMÍNIO: IDENTIDADE E CONTATO (E5)
-- Arquivo: 04_consultas_identidade.sql
-- Pré-requisito: 01_esquema.sql e 02_carga.sql (base consolidada da E4).
--
-- Cada consulta segue o modelo de anotação dos slides da aula:
-- pergunta, tabelas usadas, expressão em álgebra relacional e observações.
--
-- Numeração provisória (ID = Identidade), renumerada na consolidação do 04:
--   ID-1  Diferença (EXCEPT) ................................ PENDENTE (ver fim do arquivo)
--   ID-2  Divisão + subconsulta correlacionada (NOT EXISTS)
--   ID-3  Junção externa (LEFT JOIN)
--   ID-4  Agrupamento (GROUP BY + HAVING)
--   ID-5  Junção escrita de quatro formas distintas
-- =================================================================================


-- =================================================================================
-- Consulta ID-2 — Divisão relacional, escrita com subconsulta correlacionada
--
-- Pergunta: Quais pessoas são, ao mesmo tempo, Cliente e Entregador e possuem
--           pelo menos um telefone de cada tipo cadastrado no sistema?
--           (nome e tipo de veículo) — Consulta 2 da E3.
--
-- Tabelas: pessoa, cliente, entregador, telefone
--
-- Álgebra (E3):
--   Tipos         ← π tipo (Telefone)
--   PessoaTipo    ← π id_pessoa, tipo (Telefone)
--   TodosOsTipos  ← PessoaTipo ÷ Tipos
--   ClienteEntreg ← π id_pessoa (Cliente) ∩ π id_pessoa (Entregador)
--   Alvo          ← TodosOsTipos ∩ ClienteEntreg
--   Resultado     ← π nome, tipo_veiculo ((Alvo ⋈ Pessoa) ⋈ Entregador)
--
-- Observação:
--   O SQL não tem um operador de divisão (÷). A forma clássica de escrevê-la é
--   com dois NOT EXISTS, lendo a divisão "pelo avesso":
--     "pessoas para as quais NÃO EXISTE um tipo de telefone
--      que ela NÃO possua".
--   - O NOT EXISTS externo percorre os tipos existentes (o divisor, "Tipos").
--   - O NOT EXISTS interno procura um telefone DESTA pessoa com AQUELE tipo.
--   As subconsultas são CORRELACIONADAS porque usam p.id_pessoa, que vem da
--   consulta de fora: elas são reavaliadas para cada pessoa da linha externa.
--   As junções com cliente e entregador fazem o papel da interseção
--   "ClienteEntreg": só passa quem tem os dois papéis.
--
-- Resultado esperado na carga: 5 linhas (pessoas 104, 108, 112, 116 e 120).
-- =================================================================================
SELECT p.id_pessoa,
       p.nome,
       e.tipo_veiculo
  FROM pessoa p
INNER JOIN cliente c
        ON (c.id_pessoa = p.id_pessoa)
INNER JOIN entregador e
        ON (e.id_pessoa = p.id_pessoa)
 WHERE NOT EXISTS (
           SELECT 1
             FROM (SELECT DISTINCT tipo FROM telefone) tipos
            WHERE NOT EXISTS (
                      SELECT 1
                        FROM telefone t
                       WHERE t.id_pessoa = p.id_pessoa
                         AND t.tipo = tipos.tipo
                  )
       )
 ORDER BY p.id_pessoa;


-- =================================================================================
-- Consulta ID-3 — Junção externa (LEFT JOIN)
--
-- Pergunta: Quais são todos os clientes, com o logradouro e o número do seu
--           endereço atual, incluindo os que ainda não escolheram um endereço?
--
-- Tabelas: cliente, pessoa, endereco
--
-- Álgebra:
--   ClientePessoa ← Cliente ⋈ Pessoa
--   Resultado     ← π id_pessoa, nome, logradouro, numero
--                     (ClientePessoa ⟕ (id_endereco_atual = id_endereco) Endereco)
--
-- Observação:
--   - A junção cliente–pessoa pode ser INNER: todo cliente é uma pessoa.
--   - A junção cliente–endereco PRECISA ser LEFT: o id_endereco_atual pode ser
--     NULL. Com INNER JOIN, os clientes sem endereço atual sumiriam (215 linhas);
--     com LEFT JOIN eles aparecem com logradouro e número NULL (220 linhas).
--
-- Resultado esperado na carga: 220 linhas; os clientes 296 a 300 vêm com
-- logradouro e numero NULL.
-- =================================================================================
SELECT c.id_pessoa,
       p.nome,
       e.logradouro,
       e.numero
  FROM cliente c
INNER JOIN pessoa p
        ON (p.id_pessoa = c.id_pessoa)
 LEFT JOIN endereco e
        ON (e.id_endereco = c.id_endereco_atual)
 ORDER BY c.id_pessoa;


-- =================================================================================
-- Consulta ID-4 — Agrupamento (GROUP BY + HAVING)
--
-- Pergunta: Quais endereços são compartilhados por mais de uma pessoa, e
--           quantas pessoas estão vinculadas a cada um deles?
--
-- Tabelas: endereco, pessoa_endereco
--
-- Álgebra:
--   Vinculos   ← Endereco ⋈ Pessoa_Endereco
--   Contagem   ← id_endereco, logradouro, numero, bairro γ COUNT(id_pessoa) → moradores (Vinculos)
--   Resultado  ← σ moradores > 1 (Contagem)
--
-- Observação:
--   - GROUP BY junta as linhas de pessoa_endereco que têm o mesmo endereço;
--     COUNT(*) conta quantas linhas (pessoas) caíram em cada grupo.
--   - WHERE filtra LINHAS antes de agrupar; HAVING filtra GRUPOS depois de
--     agrupar. Por isso a condição "mais de uma pessoa" (COUNT(*) > 1) só pode
--     ficar no HAVING: antes do agrupamento a contagem ainda não existe.
--   - Toda coluna do SELECT que não está dentro de uma função de agregação
--     precisa aparecer no GROUP BY.
--   - γ (gama) é o operador de agrupamento/agregação da álgebra estendida.
--
-- Resultado esperado na carga: 20 linhas (endereços 101 a 120, com 2 moradores
-- cada).
-- =================================================================================
SELECT e.id_endereco,
       e.logradouro,
       e.numero,
       e.bairro,
       COUNT(*) AS moradores
  FROM endereco e
INNER JOIN pessoa_endereco pe
        ON (pe.id_endereco = e.id_endereco)
 GROUP BY e.id_endereco, e.logradouro, e.numero, e.bairro
HAVING COUNT(*) > 1
 ORDER BY e.id_endereco;


-- =================================================================================
-- Consulta ID-5 — Junção escrita de quatro formas distintas
--
-- Pergunta: Quais são os entregadores cadastrados (nome, e-mail e tipo de
--           veículo)?
--
-- Tabelas: pessoa, entregador
--
-- Álgebra:
--   Resultado ← π id_pessoa, nome, email, tipo_veiculo (Pessoa ⋈ Entregador)
--
-- Observação:
--   As quatro versões abaixo retornam exatamente o mesmo resultado; só muda a
--   forma de escrever a junção. Todas usam a chave estrangeira
--   entregador.id_pessoa → pessoa.id_pessoa.
--
-- Resultado esperado na carga: 120 linhas em cada uma das quatro formas.
-- =================================================================================

-- ---------------------------------------------------------------------------------
-- Forma 1 — INNER JOIN ... ON
-- A condição de junção é escrita explicitamente.
-- E funciona mesmo quando as colunas têm nomes diferentes nas duas tabelas.
-- ---------------------------------------------------------------------------------
SELECT p.id_pessoa,
       p.nome,
       p.email,
       e.tipo_veiculo
  FROM pessoa p
INNER JOIN entregador e
        ON (e.id_pessoa = p.id_pessoa)
 ORDER BY p.id_pessoa;

-- ---------------------------------------------------------------------------------
-- Forma 2 — INNER JOIN ... USING
-- Atalho para quando a coluna de ligação tem o MESMO nome nas duas tabelas.
-- A coluna id_pessoa aparece uma única vez no resultado, por isso é escrita
-- sem apelido de tabela no SELECT.
-- ---------------------------------------------------------------------------------
SELECT id_pessoa,
       p.nome,
       p.email,
       e.tipo_veiculo
  FROM pessoa p
INNER JOIN entregador e
     USING (id_pessoa)
 ORDER BY id_pessoa;

-- ---------------------------------------------------------------------------------
-- Forma 3 — NATURAL JOIN
-- O SGBD liga automaticamente TODAS as colunas de mesmo nome. Aqui a única
-- coluna em comum é id_pessoa, então equivale às formas 1 e 2.
-- Cuidado: se as tabelas tivessem outra coluna de mesmo nome (por exemplo,
-- "nome" nas duas), ela também entraria na condição de junção sem aviso.
-- ---------------------------------------------------------------------------------
SELECT id_pessoa,
       nome,
       email,
       tipo_veiculo
  FROM pessoa
NATURAL JOIN entregador
 ORDER BY id_pessoa;

-- ---------------------------------------------------------------------------------
-- Forma 4 — Produto cartesiano + seleção (FROM com vírgula e condição no WHERE)
-- Corresponde diretamente à álgebra σ p.id_pessoa = e.id_pessoa (Pessoa × Entregador).
-- Sem a condição no WHERE, o resultado seria o produto cartesiano
-- (300 pessoas × 120 entregadores = 36.000 linhas).
-- ---------------------------------------------------------------------------------
SELECT p.id_pessoa,
       p.nome,
       p.email,
       e.tipo_veiculo
  FROM pessoa p,
       entregador e
 WHERE p.id_pessoa = e.id_pessoa
 ORDER BY p.id_pessoa;


-- =================================================================================
-- Consulta ID-1 — Diferença (EXCEPT) — PENDENTE
--
-- Pergunta (Consulta 1 da E3): Quais pessoas atuam como Lojista ou como
-- Entregador e não possuem nenhum telefone do tipo celular (nome e e-mail)?
--
-- Pendente: na carga atual toda pessoa tem celular, então a consulta não
-- retornaria nenhuma linha. Aguardando decisão do grupo sobre o ajuste na
-- carga (algumas pessoas sem celular) antes de incluí-la.
-- =================================================================================
