BEGIN;

CREATE TYPE tipo_veiculo AS ENUM ('moto', 'bicicleta', 'carro');
CREATE TYPE status_pedido AS ENUM ('solicitado', 'aceito', 'recusado', 'pago', 'em_preparacao', 'pronto', 'concluido');
CREATE TYPE status_funcionamento AS ENUM ('aberta', 'fechada');
CREATE TYPE forma_pagamento AS ENUM ('pix', 'cartao_credito', 'cartao_debito', 'dinheiro');

CREATE TABLE pessoa (
    id_pessoa BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    cpf CHAR(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE entregador (
    id_pessoa BIGINT PRIMARY KEY REFERENCES pessoa (id_pessoa),
    tipo_veiculo tipo_veiculo NOT NULL
);

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
    forma_pagamento forma_pagamento,
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    taxa_entrega NUMERIC(12,2) NOT NULL CHECK (taxa_entrega >= 0),
    taxa_servico NUMERIC(12,2) NOT NULL CHECK (taxa_servico >= 0),
    valor_total NUMERIC(12,2) NOT NULL CHECK (valor_total = subtotal + taxa_entrega + taxa_servico),
    UNIQUE (id_loja, id_pedido)
);

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
