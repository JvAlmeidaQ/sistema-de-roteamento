-- Dependências mínimas para validação isolada, enquanto os subdomínios não estão integrados.
-- Não substituir os esquemas oficiais por estas tabelas na consolidação.
-- Executar uma vez em banco vazio, antes de 01/02 de Logística. Os registros
-- iniciais de pessoa/endereco usam as identidades 1 porque o banco está vazio.
-- A fixture não implementa todas as regras dos outros subdomínios nem sua auditoria.
BEGIN;

-- ENUMs externos usados pelo esquema e pelos gatilhos; declarar uma vez na integração.
CREATE TYPE tipo_veiculo AS ENUM ('moto', 'bicicleta', 'carro');
CREATE TYPE status_pedido AS ENUM ('solicitado', 'aceito', 'recusado', 'pago', 'em_preparacao', 'pronto', 'concluido');
CREATE TYPE status_funcionamento AS ENUM ('aberta', 'fechada');
CREATE TYPE forma_pagamento AS ENUM ('pix', 'cartao_credito', 'cartao_debito', 'dinheiro');

-- RN10/RR14: aqui CPF/CNPJ só obedecem formato e unicidade.
-- Documentos sintéticos não validam dígitos verificadores da RN11, feita na aplicação.
CREATE TABLE pessoa (
    id_pessoa BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    cpf CHAR(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    email VARCHAR(255) NOT NULL UNIQUE
);

-- Especialização: entregador reutiliza a PK de pessoa, como no modelo lógico.
CREATE TABLE entregador (
    id_pessoa BIGINT PRIMARY KEY REFERENCES pessoa (id_pessoa),
    tipo_veiculo tipo_veiculo NOT NULL
);

-- Endereço e seus vínculos fornecem FKs válidas para os pedidos de teste.
-- A imutabilidade de endereços e as outras regras de Identidade não são simuladas.
CREATE TABLE endereco (
    id_endereco BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    logradouro VARCHAR(150) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    bairro VARCHAR(80) NOT NULL,
    cep CHAR(8) NOT NULL CHECK (cep ~ '^[0-9]{8}$'),
    cidade VARCHAR(80) NOT NULL,
    estado CHAR(2) NOT NULL,
    UNIQUE (logradouro, numero, cep)
);

CREATE TABLE pessoa_endereco (
    id_pessoa BIGINT NOT NULL REFERENCES pessoa (id_pessoa),
    id_endereco BIGINT NOT NULL REFERENCES endereco (id_endereco),
    apelido VARCHAR(40),
    complemento VARCHAR(80),
    referencia VARCHAR(150),
    PRIMARY KEY (id_pessoa, id_endereco)
);

CREATE TABLE cliente (
    id_pessoa BIGINT PRIMARY KEY REFERENCES pessoa (id_pessoa),
    id_endereco_atual BIGINT,
    FOREIGN KEY (id_pessoa, id_endereco_atual)
        REFERENCES pessoa_endereco (id_pessoa, id_endereco)
);

CREATE TABLE lojista (
    id_pessoa BIGINT PRIMARY KEY REFERENCES pessoa (id_pessoa)
);

-- RN03/ADR-005: tempo_entrega_estimado permite calcular a previsão da entrega.
-- A taxa é copiada para os pedidos; não há gatilhos externos nesta preparação.
CREATE TABLE loja (
    id_loja BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_lojista BIGINT NOT NULL REFERENCES lojista (id_pessoa),
    id_endereco BIGINT NOT NULL REFERENCES endereco (id_endereco),
    complemento_endereco VARCHAR(80),
    cnpj CHAR(14) NOT NULL UNIQUE CHECK (cnpj ~ '^[0-9]{14}$'),
    nome VARCHAR(120) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    status_funcionamento status_funcionamento NOT NULL,
    tempo_entrega_estimado INTEGER NOT NULL CHECK (tempo_entrega_estimado > 0),
    taxa_entrega NUMERIC(12,2) NOT NULL CHECK (taxa_entrega >= 0)
);

-- Estrutura externa necessária à Logística; não é o DDL definitivo de Comércio.
-- RR10: CHECK confere apenas a aritmética dos totais da linha, não a soma de itens.
-- forma_pagamento NOT NULL acompanha o DDL comercial disponível nesta etapa.
CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_loja BIGINT NOT NULL REFERENCES loja (id_loja),
    id_cliente BIGINT NOT NULL REFERENCES cliente (id_pessoa),
    id_endereco BIGINT NOT NULL REFERENCES endereco (id_endereco),
    complemento_entrega VARCHAR(80),
    referencia_entrega VARCHAR(150),
    observacao_entrega VARCHAR(255),
    status status_pedido NOT NULL DEFAULT 'solicitado',
    data_pedido TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    forma_pagamento forma_pagamento NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    taxa_entrega NUMERIC(12,2) NOT NULL CHECK (taxa_entrega >= 0),
    taxa_servico NUMERIC(12,2) NOT NULL CHECK (taxa_servico >= 0),
    valor_total NUMERIC(12,2) NOT NULL CHECK (valor_total = subtotal + taxa_entrega + taxa_servico),
    UNIQUE (id_loja, id_pedido)
);

-- generate_series fornece mil pessoas/entregadores e cem lojas para distribuição.
-- Isso permite consultas com entregadores sem rota ativa e histórico por loja.
INSERT INTO pessoa (nome, cpf, email)
SELECT 'Pessoa ' || i, lpad(i::TEXT, 11, '0'), 'pessoa' || i || '@example.invalid'
FROM generate_series(1, 1000) AS g(i);

INSERT INTO entregador (id_pessoa, tipo_veiculo)
SELECT id_pessoa, 'moto' FROM pessoa;

INSERT INTO endereco (logradouro, numero, bairro, cep, cidade, estado)
VALUES ('Rua de teste', '1', 'Centro', '36000000', 'Juiz de Fora', 'MG');

INSERT INTO pessoa_endereco (id_pessoa, id_endereco) VALUES (1, 1);
INSERT INTO cliente (id_pessoa, id_endereco_atual) VALUES (1, 1);
INSERT INTO lojista (id_pessoa) VALUES (1);

INSERT INTO loja (id_lojista, id_endereco, cnpj, nome, telefone,
                  status_funcionamento, tempo_entrega_estimado, taxa_entrega)
SELECT 1, 1, lpad(i::TEXT, 14, '0'), 'Loja ' || i, '32999999999', 'aberta', 45, 5
FROM generate_series(1, 100) AS g(i);

COMMIT;

-- Preparação EXTERNA de pedidos para a validação isolada da carga oficial.
-- A integração usará a carga real de Comércio/Finanças em vez deste bloco.
-- As séries não são IDs: os vínculos vêm das tabelas previamente carregadas.
-- Distribuição de demonstração: três prontos em cada mil e os demais concluídos.
-- 500 mil linhas atendem à seção 5.2; não representam uma regra do domínio.
-- RN12/RR07 e a coerência das entregas correspondentes serão tratadas pela carga 02.
INSERT INTO pedido (id_loja, id_cliente, id_endereco, status, data_pedido,
                    forma_pagamento, subtotal, taxa_entrega, taxa_servico, valor_total)
SELECT l.id_loja, c.id_pessoa, c.id_endereco,
       CASE WHEN g.numero % 1000 IN (0, 1, 2) THEN 'pronto' ELSE 'concluido' END::status_pedido,
       CURRENT_TIMESTAMP - INTERVAL '7 days' + g.numero * INTERVAL '1 second',
       'pix', 40, l.taxa_entrega, 2, 42 + l.taxa_entrega
FROM generate_series(1, 500000) AS g(numero)
CROSS JOIN (SELECT ARRAY_AGG(id_loja ORDER BY id_loja) AS ids FROM loja) lojas
JOIN loja l ON l.id_loja = lojas.ids[((g.numero - 1) % cardinality(lojas.ids) + 1)::INT]
CROSS JOIN (SELECT c.id_pessoa, pe.id_endereco FROM cliente c
            JOIN pessoa_endereco pe USING (id_pessoa)
            ORDER BY c.id_pessoa, pe.id_endereco LIMIT 1) c;
-- Estatísticas dos dados externos antes de carregar e medir a Logística.
ANALYZE pessoa;
ANALYZE entregador;
ANALYZE loja;
ANALYZE pedido;
