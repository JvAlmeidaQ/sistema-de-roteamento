-- =============================================================================
-- 02_carga_identidade_contato.sql — Subdomínio Identidade e Contato (E4)
-- Pré-requisito: 01_esquema_identidade_contato.sql executado em banco vazio
-- (os IDs gerados pelas colunas IDENTITY começam em 1).
--
-- Divisão de papéis (especialização total e sobreposta — ADR-003):
--   1–40    entregador
--   41–50   entregador + cliente
--   51–60   entregador + lojista
--   61–70   entregador + lojista + cliente
--   71–100  lojista
--   101–110 lojista + cliente
--   111–300 cliente
-- Totais: 70 entregadores (1–70), 60 lojistas (51–110), 220 clientes.
-- Os entregadores 1, 2 e 3 são usados pela carga da Logística.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Pessoa (300 linhas)
--    CPF = número sequencial com zeros à esquerda: passa no CHECK de 11 dígitos
--    (RN10). O dígito verificador (RN11) é validado na aplicação, não no banco.
-- -----------------------------------------------------------------------------
INSERT INTO pessoa (nome, cpf, email)
SELECT
    (ARRAY['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Felipe', 'Gabriela',
           'Henrique', 'Isabela', 'João', 'Larissa', 'Marcos', 'Natália',
           'Otávio', 'Paula', 'Rafael', 'Sofia', 'Thiago', 'Vanessa', 'Lucas'])[1 + i % 20]
    || ' ' ||
    (ARRAY['Silva', 'Souza', 'Oliveira', 'Santos', 'Pereira', 'Costa',
           'Almeida', 'Ferreira', 'Rodrigues', 'Gomes', 'Martins', 'Barbosa',
           'Ribeiro', 'Carvalho', 'Moreira', 'Teixeira', 'Rocha'])[1 + (i / 20) % 17],
    lpad(i::TEXT, 11, '0'),
    'pessoa' || i || '@exemplo.com'
FROM generate_series(1, 300) AS g(i);

-- -----------------------------------------------------------------------------
-- 2a. Cep (30 linhas) — cada CEP guarda sua cidade e seu estado uma única vez
-- -----------------------------------------------------------------------------
INSERT INTO cep (cep, cidade, estado)
SELECT '360' || lpad((k * 1037)::TEXT, 5, '0'), 'Juiz de Fora', 'MG'
FROM generate_series(1, 30) AS g(k);

-- -----------------------------------------------------------------------------
-- 2b. Endereco (330 linhas)
--     1–280: casas; 281–330: endereços de trabalho.
--     Vários endereços compartilham o mesmo CEP (330 endereços em 30 CEPs).
--     O número é único por linha, então a UK (logradouro, numero, cep) nunca colide.
-- -----------------------------------------------------------------------------
INSERT INTO endereco (logradouro, numero, bairro, cep)
SELECT
    (ARRAY['Rua Halfeld', 'Avenida Barão do Rio Branco', 'Rua São Mateus',
           'Avenida Presidente Itamar Franco', 'Rua Santo Antônio',
           'Rua Marechal Deodoro', 'Avenida dos Andradas', 'Rua Batista de Oliveira',
           'Rua Espírito Santo', 'Avenida Getúlio Vargas', 'Rua Chanceler Oswaldo Aranha',
           'Rua Morais e Castro'])[1 + i % 12],
    (10 + i)::TEXT,
    (ARRAY['Centro', 'São Mateus', 'Cascatinha', 'Granbery', 'Bom Pastor',
           'Alto dos Passos', 'São Pedro', 'Benfica', 'Santa Luzia', 'Manoel Honório'])[1 + i % 10],
    '360' || lpad(((1 + i % 30) * 1037)::TEXT, 5, '0')
FROM generate_series(1, 330) AS g(i);

-- -----------------------------------------------------------------------------
-- 3. Pessoa_Endereco (350 linhas)
-- -----------------------------------------------------------------------------
-- 3a. Pessoas 1–280: cada uma com sua casa (endereço de mesmo número).
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido, complemento, referencia)
SELECT
    i,
    i,
    'Casa',
    CASE WHEN i % 3 = 0 THEN 'Apto ' || (100 + i % 400) END,
    CASE WHEN i % 5 = 0 THEN 'Próximo à padaria' END
FROM generate_series(1, 280) AS g(i);

-- 3b. Pessoas 281–300: dividem a casa com as pessoas 101–120 (mesmo imóvel,
--     relação N:N). O complemento é individual de cada morador (ADR-002).
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido, complemento)
SELECT
    i,
    i - 180,
    'Casa',
    'Quarto ' || (i - 280)
FROM generate_series(281, 300) AS g(i);

-- 3c. Pessoas 111–160: segundo endereço (trabalho), endereços 281–330.
INSERT INTO pessoa_endereco (id_pessoa, id_endereco, apelido, complemento)
SELECT
    i,
    280 + (i - 110),
    'Trabalho',
    'Sala ' || (i - 110)
FROM generate_series(111, 160) AS g(i);

-- -----------------------------------------------------------------------------
-- 4. Telefone (≈435 linhas) — só dígitos: DDD + 8 (fixo) ou 9 (celular)
-- -----------------------------------------------------------------------------
-- 4a. Todas as pessoas têm um celular (RR17: ao menos um telefone).
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT i, '3299' || lpad(i::TEXT, 7, '0'), 'celular'
FROM generate_series(1, 300) AS g(i);

-- 4b. Uma em cada quatro pessoas também tem telefone fixo.
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT i, '3232' || lpad(i::TEXT, 6, '0'), 'fixo'
FROM generate_series(1, 300) AS g(i)
WHERE i % 4 = 0;

-- 4c. Lojistas (51–110) têm telefone comercial.
INSERT INTO telefone (id_pessoa, numero, tipo)
SELECT i, '3230' || lpad(i::TEXT, 6, '0'), 'comercial'
FROM generate_series(51, 110) AS g(i);

-- -----------------------------------------------------------------------------
-- 5. Papéis (RR16: toda pessoa com ao menos um papel)
-- -----------------------------------------------------------------------------
-- 5a. Entregadores: 1–70, com o tipo de veículo alternando.
INSERT INTO entregador (id_pessoa, tipo_veiculo)
SELECT
    id_pessoa,
    (ARRAY['moto', 'bicicleta', 'carro']::tipo_veiculo[])[1 + id_pessoa % 3]
FROM pessoa
WHERE id_pessoa BETWEEN 1 AND 70;

-- 5b. Lojistas: 51–110.
INSERT INTO lojista (id_pessoa)
SELECT id_pessoa
FROM pessoa
WHERE id_pessoa BETWEEN 51 AND 110;

-- 5c. Clientes: 41–50, 61–70 e 101–300, ainda sem endereço atual.
INSERT INTO cliente (id_pessoa)
SELECT id_pessoa
FROM pessoa
WHERE id_pessoa BETWEEN 41 AND 50
   OR id_pessoa BETWEEN 61 AND 70
   OR id_pessoa >= 101;

-- -----------------------------------------------------------------------------
-- 6. Endereço atual do cliente (FK composta → pessoa_endereco, ADR-002)
--    - Clientes 111–130 usam o endereço de trabalho.
--    - Clientes 296–300 ficam sem endereço atual (NULL é aceito: MATCH SIMPLE).
--    - Os demais usam a casa.
-- -----------------------------------------------------------------------------
UPDATE cliente c
SET id_endereco_atual = pe.id_endereco
FROM pessoa_endereco pe
WHERE pe.id_pessoa = c.id_pessoa
  AND pe.apelido = CASE WHEN c.id_pessoa BETWEEN 111 AND 130
                        THEN 'Trabalho' ELSE 'Casa' END
  AND c.id_pessoa NOT BETWEEN 296 AND 300;

-- -----------------------------------------------------------------------------
-- 7. Conferência da carga: toda pessoa tem papel e telefone (RR16/RR17).
--    Essas regras viram gatilhos na E6; aqui só garantimos que a carga já as cumpre.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pessoa p
        WHERE NOT EXISTS (SELECT 1 FROM cliente    c WHERE c.id_pessoa = p.id_pessoa)
          AND NOT EXISTS (SELECT 1 FROM lojista    l WHERE l.id_pessoa = p.id_pessoa)
          AND NOT EXISTS (SELECT 1 FROM entregador e WHERE e.id_pessoa = p.id_pessoa)
    ) THEN
        RAISE EXCEPTION 'Carga inválida: existe pessoa sem nenhum papel (RR16)';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pessoa p
        WHERE NOT EXISTS (SELECT 1 FROM telefone t WHERE t.id_pessoa = p.id_pessoa)
    ) THEN
        RAISE EXCEPTION 'Carga inválida: existe pessoa sem telefone (RR17)';
    END IF;
END $$;

COMMIT;

-- -----------------------------------------------------------------------------
-- 8. Estatísticas para o planejador de consultas
-- -----------------------------------------------------------------------------
ANALYZE pessoa;
ANALYZE cep;
ANALYZE endereco;
ANALYZE pessoa_endereco;
ANALYZE telefone;
ANALYZE entregador;
ANALYZE lojista;
ANALYZE cliente;
