CREATE TYPE tipo_telefone AS ENUM ('celular', 'fixo', 'comercial');
CREATE TYPE tipo_veiculo AS ENUM ('moto', 'bicicleta', 'carro');

CREATE TABLE pessoa (
    id_pessoa BIGINT GENERATED ALWAYS AS IDENTITY,
    nome VARCHAR(120) NOT NULL,
    cpf CHAR(11) NOT NULL,
    email VARCHAR(255) NOT NULL,

    CONSTRAINT pk_pessoa       PRIMARY KEY (id_pessoa),
    CONSTRAINT uq_pessoa_cpf   UNIQUE (cpf),
    CONSTRAINT uq_pessoa_email UNIQUE (email),
    CONSTRAINT ck_pessoa_nome CHECK (btrim(nome) <> ''),
    CONSTRAINT ck_pessoa_cpf   CHECK (cpf ~ '^[0-9]{11}$'),
    CONSTRAINT ck_pessoa_email CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

CREATE TABLE telefone (
    id_pessoa BIGINT NOT NULL,
    numero VARCHAR(20) NOT NULL,
    tipo tipo_telefone NOT NULL,

    CONSTRAINT pk_telefone        PRIMARY KEY (id_pessoa, numero),
    CONSTRAINT fk_telefone_pessoa FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_telefone_numero CHECK (numero ~ '^[0-9]{10,11}$')
);

CREATE TABLE endereco (
    id_endereco BIGINT GENERATED ALWAYS AS IDENTITY,
    logradouro VARCHAR(150) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    bairro VARCHAR(80) NOT NULL,
    cep CHAR(8) NOT NULL,
    cidade VARCHAR(80) NOT NULL,
    estado CHAR(2) NOT NULL,

    CONSTRAINT pk_endereco PRIMARY KEY (id_endereco),
    CONSTRAINT uq_endereco_logradouro_numero_cep UNIQUE (logradouro, numero, cep),
    CONSTRAINT ck_endereco_logradouro CHECK (btrim(logradouro) <> ''),
    CONSTRAINT ck_endereco_numero     CHECK (btrim(numero) <> ''),
    CONSTRAINT ck_endereco_bairro     CHECK (btrim(bairro) <> ''),
    CONSTRAINT ck_endereco_cep CHECK (cep ~ '^[0-9]{8}$'),
    CONSTRAINT ck_endereco_cidade     CHECK (btrim(cidade) <> ''),
    CONSTRAINT ck_endereco_estado CHECK (estado ~ '^[A-Z]{2}$')
);

CREATE TABLE pessoa_endereco (
    id_pessoa BIGINT NOT NULL,
    id_endereco BIGINT NOT NULL,
    apelido VARCHAR(40),
    complemento VARCHAR(80),
    referencia VARCHAR(150),

    CONSTRAINT pk_pessoa_endereco PRIMARY KEY (id_pessoa, id_endereco),
    CONSTRAINT fk_pessoa_endereco_pessoa FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_pessoa_endereco_endereco FOREIGN KEY (id_endereco)
         REFERENCES endereco (id_endereco)
         ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE entregador (
    id_pessoa BIGINT NOT NULL,
    tipo_veiculo tipo_veiculo NOT NULL,

    CONSTRAINT pk_entregador PRIMARY KEY (id_pessoa),
    CONSTRAINT fk_entregador_pessoa FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa)
        ON UPDATE RESTRICT ON DELETE CASCADE
);

CREATE TABLE cliente (
    id_pessoa         BIGINT NOT NULL,
    id_endereco_atual BIGINT,

    CONSTRAINT pk_cliente PRIMARY KEY (id_pessoa),
    CONSTRAINT fk_cliente_pessoa FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_cliente_endereco_atual FOREIGN KEY (id_pessoa, id_endereco_atual)
        REFERENCES pessoa_endereco (id_pessoa, id_endereco)
        ON UPDATE RESTRICT ON DELETE NO ACTION
);

CREATE TABLE lojista (
    id_pessoa BIGINT NOT NULL,

    CONSTRAINT pk_lojista PRIMARY KEY (id_pessoa),
    CONSTRAINT fk_lojista_pessoa FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa)
        ON UPDATE RESTRICT ON DELETE CASCADE
);
