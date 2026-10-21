-- =====================================================================
-- 2. CREATE TABLE + 3. CONSTRAINTS (MySQL 8.0.16 ou superior: os CHECK são aplicados) (PK, FK, NOT NULL, UNIQUE, CHECK)
-- Convenção: prefixos do dicionário de dados (id_, nm_, dt_, dh_, qt_, vl_, nr_,
-- tp_, in_, ds_), em minúsculas. 14 tabelas: 12 entidades do DER + 2 tabelas
-- dos relacionamentos N:N com atributos (pedido_produto e compra_produto).
-- =====================================================================

-- ---------- SETOR ----------
CREATE TABLE setor (
    id_setor       SMALLINT AUTO_INCREMENT,
    nm_setor    VARCHAR(30) NOT NULL,
    in_preparo  BOOLEAN     NOT NULL,
    CONSTRAINT pk_setor      PRIMARY KEY (id_setor),
    CONSTRAINT uq_setor_nome UNIQUE (nm_setor)
);

-- ---------- CATEGORIA ----------
CREATE TABLE categoria (
    id_categoria   SMALLINT AUTO_INCREMENT,
    nm_categoria  VARCHAR(40) NOT NULL,
    in_ativa      BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_categoria      PRIMARY KEY (id_categoria),
    CONSTRAINT uq_categoria_nome UNIQUE (nm_categoria)
);

-- ---------- ATENDENTE ----------
CREATE TABLE atendente (
    id_atendente   INT AUTO_INCREMENT,
    id_setor       SMALLINT     NOT NULL,
    nm_atendente   VARCHAR(120) NOT NULL,
    nm_login       VARCHAR(30)  NOT NULL,
    ds_senha_hash  VARCHAR(255) NOT NULL,
    tp_funcao      VARCHAR(10)  NOT NULL,
    tp_perfil      CHAR(1)      NOT NULL,
    dt_admissao    DATE         NOT NULL,
    in_ativo       BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_atendente         PRIMARY KEY (id_atendente),
    CONSTRAINT uq_atendente_login   UNIQUE (nm_login),
    CONSTRAINT fk_atendente_setor   FOREIGN KEY (id_setor) REFERENCES setor (id_setor),
    CONSTRAINT ck_atendente_funcao  CHECK (tp_funcao IN ('GARCOM','CAIXA','COZINHA','BAR','GERENTE','SOCIO','LIMPEZA')),
    CONSTRAINT ck_atendente_perfil  CHECK (tp_perfil IN ('A','P','G','S')),   -- A=atendimento, P=preparo, G=gerência, S=sócio
    CONSTRAINT ck_atendente_func_perfil CHECK (                               -- a função define o perfil padrão
           (tp_funcao IN ('GARCOM','CAIXA','LIMPEZA') AND tp_perfil = 'A')
        OR (tp_funcao IN ('COZINHA','BAR')            AND tp_perfil = 'P')
        OR (tp_funcao = 'GERENTE'                     AND tp_perfil = 'G')
        OR (tp_funcao = 'SOCIO'                       AND tp_perfil = 'S')),
    CONSTRAINT ck_atendente_login   CHECK (nm_login REGEXP '^[a-z0-9._-]{3,30}$')
);

-- ---------- MESA ----------
CREATE TABLE mesa (
    id_mesa        SMALLINT AUTO_INCREMENT,
    nr_mesa     SMALLINT NOT NULL,
    tp_local    CHAR(1)  NOT NULL,
    qt_lugares  SMALLINT NOT NULL,
    tp_status   CHAR(1)  NOT NULL DEFAULT 'L',
    in_ativa    BOOLEAN  NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_mesa         PRIMARY KEY (id_mesa),
    CONSTRAINT uq_mesa_numero  UNIQUE (nr_mesa),
    CONSTRAINT ck_mesa_numero  CHECK (nr_mesa > 0),
    CONSTRAINT ck_mesa_local   CHECK (tp_local IN ('M','B')),                 -- M=mesa, B=bistrô
    CONSTRAINT ck_mesa_lugares CHECK (qt_lugares > 0),
    CONSTRAINT ck_mesa_status  CHECK (tp_status IN ('L','O'))                 -- L=livre, O=ocupada
);

-- ---------- RESERVA ----------
CREATE TABLE reserva (
    id_reserva     INT AUTO_INCREMENT,
    id_mesa      SMALLINT    NOT NULL,
    nm_cliente   VARCHAR(80) NOT NULL,
    nr_telefone  VARCHAR(15),
    dh_reserva   DATETIME   NOT NULL,
    qt_pessoas   SMALLINT    NOT NULL,
    tp_status    CHAR(1)     NOT NULL DEFAULT 'A',
    CONSTRAINT pk_reserva        PRIMARY KEY (id_reserva),
    CONSTRAINT fk_reserva_mesa   FOREIGN KEY (id_mesa) REFERENCES mesa (id_mesa),
    CONSTRAINT ck_reserva_pessoas CHECK (qt_pessoas > 0),
    CONSTRAINT ck_reserva_status CHECK (tp_status IN ('A','T','C')),          -- A=ativa, T=atendida, C=cancelada
    CONSTRAINT ck_reserva_fone   CHECK (nr_telefone IS NULL OR nr_telefone REGEXP '^[0-9]{10,15}$')
);

-- ---------- PRODUTO ----------
CREATE TABLE produto (
    id_produto     INT AUTO_INCREMENT,
    id_setor             SMALLINT     NOT NULL,
    id_categoria         SMALLINT     NOT NULL,
    nm_produto           VARCHAR(80)  NOT NULL,
    nr_codigo_barras     VARCHAR(14)  NOT NULL,
    vl_preco             DECIMAL(8,2) NOT NULL,
    in_vendavel          BOOLEAN      NOT NULL DEFAULT TRUE,
    in_alcoolico         BOOLEAN      NOT NULL DEFAULT FALSE,
    in_controla_estoque  BOOLEAN      NOT NULL DEFAULT FALSE,
    qt_estoque_atual     INT      NOT NULL DEFAULT 0,
    qt_estoque_minimo    INT      NOT NULL DEFAULT 0,
    in_ativo             BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_produto           PRIMARY KEY (id_produto),
    CONSTRAINT uq_produto_nome      UNIQUE (nm_produto),
    CONSTRAINT uq_produto_barras    UNIQUE (nr_codigo_barras),               -- RN03
    CONSTRAINT fk_produto_setor     FOREIGN KEY (id_setor)     REFERENCES setor (id_setor),
    CONSTRAINT fk_produto_categoria FOREIGN KEY (id_categoria) REFERENCES categoria (id_categoria),
    CONSTRAINT ck_produto_barras    CHECK (nr_codigo_barras REGEXP '^[0-9]{8,14}$'),
    CONSTRAINT ck_produto_preco     CHECK (vl_preco >= 0 AND (NOT in_vendavel OR vl_preco > 0)),
    CONSTRAINT ck_produto_est_atual  CHECK (qt_estoque_atual  >= 0),          -- RN08: estoque nunca negativo
    CONSTRAINT ck_produto_est_minimo CHECK (qt_estoque_minimo >= 0),
    CONSTRAINT ck_produto_estoque   CHECK (in_controla_estoque OR (qt_estoque_atual = 0 AND qt_estoque_minimo = 0)),
    CONSTRAINT ck_produto_insumo    CHECK (in_vendavel OR (in_controla_estoque AND NOT in_alcoolico))  -- RN30
);

-- ---------- HISTORICO_PRODUTO ----------
CREATE TABLE historico_produto (
    id_historico   INT AUTO_INCREMENT,
    id_produto         INT      NOT NULL,
    id_atendente       INT      NOT NULL,
    vl_preco_anterior  DECIMAL(8,2) NOT NULL,
    vl_preco_novo      DECIMAL(8,2) NOT NULL,
    dh_alteracao       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historico_produto PRIMARY KEY (id_historico),
    CONSTRAINT fk_hist_produto      FOREIGN KEY (id_produto)   REFERENCES produto (id_produto),
    CONSTRAINT fk_hist_atendente    FOREIGN KEY (id_atendente) REFERENCES atendente (id_atendente),
    CONSTRAINT ck_hist_precos       CHECK (vl_preco_anterior >= 0 AND vl_preco_novo >= 0 AND vl_preco_anterior <> vl_preco_novo)
);

-- ---------- PEDIDO ----------
CREATE TABLE pedido (
    id_pedido      INT AUTO_INCREMENT,
    id_mesa          SMALLINT  NOT NULL,                                      -- RN02
    id_atendente     INT   NOT NULL,                                      -- RN01
    dh_abertura      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dh_fechamento    DATETIME,
    in_taxa_servico  BOOLEAN   NOT NULL DEFAULT TRUE,                         -- RN16: 10%, removível a pedido do cliente
    tp_status        CHAR(1)   NOT NULL DEFAULT 'A',
    ds_observacao    VARCHAR(200),
    id_mesa_aberta   SMALLINT  GENERATED ALWAYS AS (CASE WHEN tp_status = 'A' THEN id_mesa END) VIRTUAL,   -- apoio à RN05
    CONSTRAINT pk_pedido            PRIMARY KEY (id_pedido),
    CONSTRAINT fk_pedido_mesa       FOREIGN KEY (id_mesa)      REFERENCES mesa (id_mesa),
    CONSTRAINT fk_pedido_atendente  FOREIGN KEY (id_atendente) REFERENCES atendente (id_atendente),
    CONSTRAINT ck_pedido_status     CHECK (tp_status IN ('A','F','C')),       -- A=aberto, F=fechado, C=cancelado
    CONSTRAINT ck_pedido_fechamento CHECK ((tp_status = 'A') = (dh_fechamento IS NULL)),
    CONSTRAINT ck_pedido_datas      CHECK (dh_fechamento IS NULL OR dh_fechamento >= dh_abertura)
);

-- ---------- PEDIDO_PRODUTO (relacionamento "contém", N:N com atributos) ----------
-- Sem a entidade Item_pedido (orientação do professor): a chave é composta (pedido, produto).
-- Limitação: o mesmo produto não repete no pedido; novos lançamentos somam a quantidade (função lancar_item).
CREATE TABLE pedido_produto (
    id_pedido          INT      NOT NULL,
    id_produto         INT      NOT NULL,
    qt_item            SMALLINT     NOT NULL,
    vl_preco_unitario  DECIMAL(8,2) NOT NULL,                                 -- RN07: preço no momento do pedido
    tp_status          CHAR(1)      NOT NULL DEFAULT 'P',
    dh_registro        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    dh_pronto          DATETIME,
    ds_observacao      VARCHAR(100),
    CONSTRAINT pk_pedido_produto    PRIMARY KEY (id_pedido, id_produto),
    CONSTRAINT fk_pp_pedido         FOREIGN KEY (id_pedido)  REFERENCES pedido (id_pedido),
    CONSTRAINT fk_pp_produto        FOREIGN KEY (id_produto) REFERENCES produto (id_produto),
    CONSTRAINT ck_pp_qtd            CHECK (qt_item > 0),
    CONSTRAINT ck_pp_preco          CHECK (vl_preco_unitario > 0),
    CONSTRAINT ck_pp_status         CHECK (tp_status IN ('P','E','R','N','C')), -- P=pendente, E=em preparo, R=pronto, N=entregue, C=cancelado
    CONSTRAINT ck_pp_pronto         CHECK ((tp_status IN ('R','N')) = (dh_pronto IS NOT NULL)),
    CONSTRAINT ck_pp_datas          CHECK (dh_pronto IS NULL OR dh_pronto >= dh_registro)
);

-- ---------- PAGAMENTO ----------
CREATE TABLE pagamento (
    id_pagamento   INT AUTO_INCREMENT,
    id_pedido     INT      NOT NULL,
    tp_forma      CHAR(1)      NOT NULL,
    vl_pago       DECIMAL(8,2) NOT NULL,
    dh_pagamento  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_pagamento        PRIMARY KEY (id_pagamento),
    CONSTRAINT fk_pagamento_pedido FOREIGN KEY (id_pedido) REFERENCES pedido (id_pedido),
    CONSTRAINT ck_pagamento_forma  CHECK (tp_forma IN ('D','C','B','P')),     -- D=dinheiro, C=crédito, B=débito, P=Pix
    CONSTRAINT ck_pagamento_valor  CHECK (vl_pago > 0)
);

-- ---------- FORNECEDOR ----------
CREATE TABLE fornecedor (
    id_fornecedor  INT AUTO_INCREMENT,
    nm_fornecedor  VARCHAR(120) NOT NULL,
    nr_cnpj        VARCHAR(14)  NOT NULL,
    nr_telefone    VARCHAR(15),
    in_ativo       BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_fornecedor       PRIMARY KEY (id_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj  UNIQUE (nr_cnpj),
    CONSTRAINT ck_fornecedor_cnpj  CHECK (nr_cnpj REGEXP '^[0-9]{14}$'),
    CONSTRAINT ck_fornecedor_fone  CHECK (nr_telefone IS NULL OR nr_telefone REGEXP '^[0-9]{10,15}$')
);

-- ---------- COMPRA ----------
CREATE TABLE compra (
    id_compra      INT AUTO_INCREMENT,
    id_fornecedor   INT     NOT NULL,
    id_atendente    INT     NOT NULL,
    dh_compra       DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tp_status       CHAR(1)     NOT NULL DEFAULT 'P',
    nr_nota_fiscal  VARCHAR(20),
    dh_recebimento  DATETIME,
    CONSTRAINT pk_compra            PRIMARY KEY (id_compra),
    CONSTRAINT fk_compra_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES fornecedor (id_fornecedor),
    CONSTRAINT fk_compra_atendente  FOREIGN KEY (id_atendente)  REFERENCES atendente (id_atendente),
    CONSTRAINT ck_compra_status     CHECK (tp_status IN ('P','R','C')),       -- P=pedida, R=recebida, C=cancelada
    CONSTRAINT ck_compra_recebida   CHECK ((tp_status = 'R') = (dh_recebimento IS NOT NULL)),
    CONSTRAINT ck_compra_nota       CHECK (tp_status <> 'R' OR nr_nota_fiscal IS NOT NULL),
    CONSTRAINT ck_compra_datas      CHECK (dh_recebimento IS NULL OR dh_recebimento >= dh_compra)
);

-- ---------- COMPRA_PRODUTO (relacionamento "possui", N:N com atributos) ----------
CREATE TABLE compra_produto (
    id_compra          INT      NOT NULL,
    id_produto         INT      NOT NULL,
    qt_comprada        INT      NOT NULL,
    vl_custo_unitario  DECIMAL(8,2) NOT NULL,
    dt_validade        DATE,
    CONSTRAINT pk_compra_produto PRIMARY KEY (id_compra, id_produto),
    CONSTRAINT fk_cp_compra      FOREIGN KEY (id_compra)  REFERENCES compra (id_compra),
    CONSTRAINT fk_cp_produto     FOREIGN KEY (id_produto) REFERENCES produto (id_produto),
    CONSTRAINT ck_cp_qtd         CHECK (qt_comprada > 0),
    CONSTRAINT ck_cp_custo       CHECK (vl_custo_unitario > 0)
);

-- ---------- MOVIMENTACAO_ESTOQUE ----------
CREATE TABLE movimentacao_estoque (
    id_movimentacao INT AUTO_INCREMENT,
    id_produto       INT      NOT NULL,
    id_pedido        INT,
    id_compra        INT,
    tp_movimento     CHAR(1)      NOT NULL,
    qt_movimento     INT      NOT NULL,
    dh_movimento     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ds_motivo        VARCHAR(100),
    CONSTRAINT pk_movimentacao   PRIMARY KEY (id_movimentacao),
    CONSTRAINT fk_mov_produto    FOREIGN KEY (id_produto) REFERENCES produto (id_produto),
    CONSTRAINT fk_mov_pedido     FOREIGN KEY (id_pedido)  REFERENCES pedido (id_pedido),
    CONSTRAINT fk_mov_compra     FOREIGN KEY (id_compra)  REFERENCES compra (id_compra),
    CONSTRAINT ck_mov_tipo       CHECK (tp_movimento IN ('V','C','E','A')),   -- V=venda, C=compra, E=estorno, A=ajuste
    CONSTRAINT ck_mov_quantidade CHECK (qt_movimento <> 0),
    CONSTRAINT ck_mov_sinal      CHECK ((tp_movimento = 'V' AND qt_movimento < 0)
                                     OR (tp_movimento IN ('C','E') AND qt_movimento > 0)
                                     OR  tp_movimento = 'A'),
    CONSTRAINT ck_mov_origem     CHECK ((tp_movimento IN ('V','E') AND id_pedido IS NOT NULL AND id_compra IS NULL)
                                     OR (tp_movimento = 'C'        AND id_compra IS NOT NULL AND id_pedido IS NULL)
                                     OR (tp_movimento = 'A'        AND id_pedido IS NULL     AND id_compra IS NULL)),
    CONSTRAINT ck_mov_motivo     CHECK (tp_movimento <> 'A' OR ds_motivo IS NOT NULL)   -- ajuste exige motivo
);

-- ---------- ÍNDICES ----------
-- RN05: no máximo um pedido aberto por mesa. O MySQL não tem índice parcial; a coluna gerada
-- id_mesa_aberta vale id_mesa só enquanto o pedido está aberto (NULL nos demais, e NULL não se repete no UNIQUE).
CREATE UNIQUE INDEX ux_pedido_mesa_aberto ON pedido (id_mesa_aberta);
CREATE INDEX ix_pedido_abertura     ON pedido (dh_abertura);
CREATE INDEX ix_pedido_atendente    ON pedido (id_atendente);
CREATE INDEX ix_pp_produto          ON pedido_produto (id_produto);
CREATE INDEX ix_pp_fila             ON pedido_produto (tp_status, dh_registro);   -- fila de preparo
CREATE INDEX ix_pagamento_pedido    ON pagamento (id_pedido);
CREATE INDEX ix_pagamento_data      ON pagamento (dh_pagamento);                                    -- fechamento do caixa
CREATE INDEX ix_mov_produto_data    ON movimentacao_estoque (id_produto, dh_movimento);
CREATE INDEX ix_mov_pedido          ON movimentacao_estoque (id_pedido);
CREATE INDEX ix_mov_compra          ON movimentacao_estoque (id_compra);
CREATE INDEX ix_hist_produto_data   ON historico_produto (id_produto, dh_alteracao);
CREATE INDEX ix_produto_setor       ON produto (id_setor);
CREATE INDEX ix_produto_categoria   ON produto (id_categoria);
CREATE INDEX ix_atendente_setor     ON atendente (id_setor);
CREATE INDEX ix_reserva_mesa_data   ON reserva (id_mesa, dh_reserva);
CREATE INDEX ix_compra_fornecedor   ON compra (id_fornecedor);
CREATE INDEX ix_compra_data         ON compra (dh_compra);
