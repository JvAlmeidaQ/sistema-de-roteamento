-- =================================================================================
-- DDL - SUBDOMÍNIO: COMÉRCIO E FINANÇAS
-- Arquivo: 01_esquema_comercio_financas.sql
-- Dependências externas: loja(id_loja), cliente(id_pessoa), endereco(id_endereco),
--                        produto(id_loja, id_produto)
-- =================================================================================

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
