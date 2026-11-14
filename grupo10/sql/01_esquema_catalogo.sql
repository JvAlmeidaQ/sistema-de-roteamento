BEGIN;

-- ------------------------------------------------------------
-- 01. PESSOA
-- Tabela-base da especialização da qual Lojista faz parte.
-- ------------------------------------------------------------
CREATE TABLE pessoa (
    id_pessoa BIGINT GENERATED ALWAYS AS IDENTITY,
    nome      VARCHAR(120) NOT NULL,
    cpf       CHAR(11) NOT NULL,
    email     VARCHAR(254),

    CONSTRAINT pk_pessoa PRIMARY KEY (id_pessoa),
    CONSTRAINT uk_pessoa_cpf UNIQUE (cpf),
    CONSTRAINT ck_pessoa_cpf CHECK (cpf ~ '^[0-9]{11}$')
);

-- ------------------------------------------------------------
-- 02. LOJISTA
-- Subtipo de Pessoa: a PK também é FK para pessoa.
-- ------------------------------------------------------------
CREATE TABLE lojista (
    id_pessoa BIGINT NOT NULL,

    CONSTRAINT pk_lojista PRIMARY KEY (id_pessoa),
    CONSTRAINT fk_lojista_pessoa
        FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 03. ENDERECO
-- Tabela necessária para a FK de Loja.
-- O CEP aparece uma única vez, apesar de estar duplicado
-- graficamente no DER fornecido.
-- ------------------------------------------------------------
CREATE TABLE endereco (
    id_endereco BIGINT GENERATED ALWAYS AS IDENTITY,
    logradouro  VARCHAR(120) NOT NULL,
    numero      VARCHAR(20) NOT NULL,
    bairro      VARCHAR(80) NOT NULL,
    cidade      VARCHAR(80) NOT NULL,
    estado      VARCHAR(50) NOT NULL,
    cep         CHAR(8) NOT NULL,

    CONSTRAINT pk_endereco PRIMARY KEY (id_endereco),
    CONSTRAINT ck_endereco_cep CHECK (cep ~ '^[0-9]{8}$')
);

-- ------------------------------------------------------------
-- 04. ENUM STATUS_FUNCIONAMENTO
-- ------------------------------------------------------------
CREATE TYPE status_funcionamento AS ENUM ('aberta', 'fechada');

-- ------------------------------------------------------------
-- 05. LOJA
-- ------------------------------------------------------------
CREATE TABLE loja (
    id_loja                BIGINT GENERATED ALWAYS AS IDENTITY,
    id_lojista             BIGINT NOT NULL,
    id_endereco            BIGINT NOT NULL,
    complemento_endereco   VARCHAR(80),
    cnpj                   CHAR(14) NOT NULL,
    nome                   VARCHAR(120) NOT NULL,
    telefone               VARCHAR(20) NOT NULL,
    status_funcionamento   status_funcionamento NOT NULL,
    tempo_entrega_estimado INTEGER NOT NULL,
    taxa_entrega           NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_loja PRIMARY KEY (id_loja),
    CONSTRAINT uk_loja_cnpj UNIQUE (cnpj),
    CONSTRAINT ck_loja_cnpj CHECK (cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT ck_loja_tempo_entrega
        CHECK (tempo_entrega_estimado > 0),
    CONSTRAINT ck_loja_taxa_entrega
        CHECK (taxa_entrega >= 0),
    CONSTRAINT fk_loja_lojista
        FOREIGN KEY (id_lojista)
        REFERENCES lojista (id_pessoa)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_loja_endereco
        FOREIGN KEY (id_endereco)
        REFERENCES endereco (id_endereco)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 06. PRODUTO
-- O UNIQUE (id_loja, id_produto) permite a FK composta
-- utilizada por Produto_Categoria.
-- ------------------------------------------------------------
CREATE TABLE produto (
    id_produto BIGINT GENERATED ALWAYS AS IDENTITY,
    id_loja    BIGINT NOT NULL,
    nome       VARCHAR(120) NOT NULL,
    descricao  TEXT,
    preco      NUMERIC(12,2) NOT NULL,
    ativo      BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_produto PRIMARY KEY (id_produto),
    CONSTRAINT uk_produto_loja_produto UNIQUE (id_loja, id_produto),
    CONSTRAINT ck_produto_preco CHECK (preco > 0),
    CONSTRAINT fk_produto_loja
        FOREIGN KEY (id_loja)
        REFERENCES loja (id_loja)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 07. CATEGORIA
-- O UNIQUE (id_loja, id_categoria) permite a FK composta
-- utilizada por Produto_Categoria.
-- ------------------------------------------------------------
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY,
    id_loja      BIGINT NOT NULL,
    nome         VARCHAR(80) NOT NULL,

    CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
    CONSTRAINT uk_categoria_loja_categoria
        UNIQUE (id_loja, id_categoria),
    CONSTRAINT fk_categoria_loja
        FOREIGN KEY (id_loja)
        REFERENCES loja (id_loja)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 08. PRODUTO_CATEGORIA
-- As duas FKs compostas garantem que produto e categoria
-- associados pertençam à mesma loja.
-- ------------------------------------------------------------
CREATE TABLE produto_categoria (
    id_produto   BIGINT NOT NULL,
    id_categoria BIGINT NOT NULL,
    id_loja      BIGINT NOT NULL,

    CONSTRAINT pk_produto_categoria
        PRIMARY KEY (id_produto, id_categoria),
    CONSTRAINT fk_produto_categoria_produto
        FOREIGN KEY (id_loja, id_produto)
        REFERENCES produto (id_loja, id_produto)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_produto_categoria_categoria
        FOREIGN KEY (id_loja, id_categoria)
        REFERENCES categoria (id_loja, id_categoria)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

COMMIT;
