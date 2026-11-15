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


-- =============================================================================
-- SUBDOMÍNIO: CATÁLOGO
-- =============================================================================

CREATE TYPE status_funcionamento AS ENUM ('aberta', 'fechada');

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
    CONSTRAINT ck_loja_tempo_entrega CHECK (tempo_entrega_estimado > 0),
    CONSTRAINT ck_loja_taxa_entrega CHECK (taxa_entrega >= 0),
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

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY,
    id_loja      BIGINT NOT NULL,
    nome         VARCHAR(80) NOT NULL,

    CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
    CONSTRAINT uk_categoria_loja_categoria UNIQUE (id_loja, id_categoria),
    CONSTRAINT fk_categoria_loja
        FOREIGN KEY (id_loja)
        REFERENCES loja (id_loja)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE produto_categoria (
    id_produto   BIGINT NOT NULL,
    id_categoria BIGINT NOT NULL,
    id_loja      BIGINT NOT NULL,

    CONSTRAINT pk_produto_categoria PRIMARY KEY (id_produto, id_categoria),
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


-- =============================================================================
-- SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- =============================================================================

CREATE TYPE forma_pagamento AS ENUM (
    'pix',
    'cartao_credito',
    'cartao_debito',
    'dinheiro'
);

CREATE TYPE status_pedido AS ENUM (
    'solicitado',
    'aceito',
    'recusado',
    'pago',
    'em_preparacao',
    'pronto',
    'concluido'
);

CREATE TABLE IF NOT EXISTS pedido (
    id_pedido           BIGINT GENERATED ALWAYS AS IDENTITY,
    id_loja             BIGINT NOT NULL,
    id_cliente          BIGINT NOT NULL,
    id_endereco         BIGINT NOT NULL,
    complemento_entrega VARCHAR(80),
    referencia_entrega  VARCHAR(150),
    observacao_entrega  VARCHAR(255),
    status              status_pedido NOT NULL DEFAULT 'solicitado',
    data_pedido         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    forma_pagamento     forma_pagamento NOT NULL,
    subtotal            NUMERIC(12,2) NOT NULL,
    taxa_entrega        NUMERIC(12,2) NOT NULL,
    taxa_servico        NUMERIC(12,2) NOT NULL,
    valor_total         NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_pedido PRIMARY KEY (id_pedido),
    CONSTRAINT fk_pedido_loja FOREIGN KEY (id_loja) REFERENCES loja(id_loja),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_pessoa),
    CONSTRAINT fk_pedido_endereco FOREIGN KEY (id_endereco) REFERENCES endereco(id_endereco),
    CONSTRAINT uk_pedido_loja UNIQUE (id_loja, id_pedido),

    CONSTRAINT ck_pedido_subtotal CHECK (subtotal >= 0),
    CONSTRAINT ck_pedido_taxa_entrega CHECK (taxa_entrega >= 0),
    CONSTRAINT ck_pedido_taxa_servico CHECK (taxa_servico >= 0),
    CONSTRAINT ck_pedido_valor_total CHECK (valor_total = subtotal + taxa_entrega + taxa_servico)
);

CREATE TABLE IF NOT EXISTS item_pedido (
    id_pedido       BIGINT NOT NULL,
    id_produto      BIGINT NOT NULL,
    id_loja         BIGINT NOT NULL,
    quantidade      INTEGER NOT NULL,
    valor_unitario  NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_item_pedido PRIMARY KEY (id_pedido, id_produto),
    CONSTRAINT fk_item_pedido_loja FOREIGN KEY (id_loja, id_pedido)
        REFERENCES pedido(id_loja, id_pedido),
    CONSTRAINT fk_item_produto_loja FOREIGN KEY (id_loja, id_produto)
        REFERENCES produto(id_loja, id_produto),

    CONSTRAINT ck_item_pedido_quantidade CHECK (quantidade > 0),
    CONSTRAINT ck_item_pedido_valor_unitario CHECK (valor_unitario > 0)
);

CREATE TABLE IF NOT EXISTS avaliacao_loja (
    id_pedido       BIGINT NOT NULL,
    nota            SMALLINT NOT NULL,
    comentario      TEXT,
    data_avaliacao  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_avaliacao_loja PRIMARY KEY (id_pedido),
    CONSTRAINT fk_avaliacao_loja_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido),
    CONSTRAINT ck_avaliacao_loja_nota CHECK (nota BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS avaliacao_entregador (
    id_pedido       BIGINT NOT NULL,
    nota            SMALLINT NOT NULL,
    comentario      TEXT,
    data_avaliacao  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_avaliacao_entregador PRIMARY KEY (id_pedido),
    CONSTRAINT fk_avaliacao_entregador_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido),
    CONSTRAINT ck_avaliacao_entregador_nota CHECK (nota BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS divisao_pagamento (
    id_pedido           BIGINT NOT NULL,
    valor_total         NUMERIC(12,2) NOT NULL,
    taxa_plataforma     NUMERIC(12,2) NOT NULL,
    parcela_loja        NUMERIC(12,2) NOT NULL,
    comissao_entregador NUMERIC(12,2) NOT NULL,
    calculada_em        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_divisao_pagamento PRIMARY KEY (id_pedido),
    CONSTRAINT fk_divisao_pagamento_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido),

    CONSTRAINT ck_divisao_pagamento_parcela_loja CHECK (parcela_loja >= 0),
    CONSTRAINT ck_divisao_pagamento_comissao_entregador CHECK (comissao_entregador >= 0),
    CONSTRAINT ck_divisao_pagamento_taxa_plataforma CHECK (taxa_plataforma >= 0),
    CONSTRAINT ck_divisao_pagamento_soma CHECK (parcela_loja + comissao_entregador + taxa_plataforma = valor_total)
);
