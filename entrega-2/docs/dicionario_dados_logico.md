# Dicionário de dados lógico — Palazio del Chef (Entrega 2)

Gerado do catálogo do PostgreSQL por `scripts/gerar_dicionario_logico.py`. Descrição de cada atributo no negócio: dicionário conceitual do [README](../../README.md#5--dicionário-de-dados-conceitual-preliminar) (seção 5).

Legenda: PK chave primária · FK chave estrangeira (→ tabela.coluna) · UQ único · NN obrigatório.

## atendente

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_atendente` | INTEGER | PK |  |
| `id_setor` | SMALLINT | FK → setor.id_setor, NN |  |
| `nm_atendente` | VARCHAR(120) | NN |  |
| `nm_login` | VARCHAR(30) | UQ, NN |  |
| `ds_senha_hash` | VARCHAR(255) | NN |  |
| `tp_funcao` | VARCHAR(10) | NN |  |
| `tp_perfil` | CHAR(1) | NN |  |
| `dt_admissao` | DATE | NN |  |
| `in_ativo` | BOOLEAN | NN | true |

Regras `CHECK`:

- `((dt_admissao <= CURRENT_DATE))`
- `(((((tp_funcao)::text = ANY ((ARRAY['GARCOM'::character varying, 'CAIXA'::character varying, 'LIMPEZA'::character varying])::text[])) AND (tp_perfil = 'A'::bpchar)) OR (((tp_funcao)::text = ANY ((ARRAY['COZINHA'::character varying, 'BAR'::character varying])::text[])) AND (tp_perfil = 'P'::bpchar)) OR (((tp_funcao)::text = 'GERENTE'::text) AND (tp_perfil = 'G'::bpchar)) OR (((tp_funcao)::text = 'SOCIO'::text) AND (tp_perfil = 'S'::bpchar))))`
- `(((tp_funcao)::text = ANY ((ARRAY['GARCOM'::character varying, 'CAIXA'::character varying, 'COZINHA'::character varying, 'BAR'::character varying, 'GERENTE'::character varying, 'SOCIO'::character varying, 'LIMPEZA'::character varying])::text[])))`
- `(((nm_login)::text ~ '^[a-z0-9._-]{3,30}$'::text))`
- `((tp_perfil = ANY (ARRAY['A'::bpchar, 'P'::bpchar, 'G'::bpchar, 'S'::bpchar])))`

## categoria

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_categoria` | SMALLINT | PK |  |
| `nm_categoria` | VARCHAR(40) | UQ, NN |  |
| `in_ativa` | BOOLEAN | NN | true |

## compra

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_compra` | INTEGER | PK |  |
| `id_fornecedor` | INTEGER | FK → fornecedor.id_fornecedor, NN |  |
| `id_atendente` | INTEGER | FK → atendente.id_atendente, NN |  |
| `dh_compra` | TIMESTAMP | NN | now() |
| `tp_status` | CHAR(1) | NN | 'P'   |
| `nr_nota_fiscal` | VARCHAR(20) |  |  |
| `dh_recebimento` | TIMESTAMP |  |  |

Regras `CHECK`:

- `(((dh_recebimento IS NULL) OR (dh_recebimento >= dh_compra)))`
- `(((tp_status <> 'R'::bpchar) OR (nr_nota_fiscal IS NOT NULL)))`
- `(((tp_status = 'R'::bpchar) = (dh_recebimento IS NOT NULL)))`
- `((tp_status = ANY (ARRAY['P'::bpchar, 'R'::bpchar, 'C'::bpchar])))`

## compra_produto

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_compra` | INTEGER | PK, FK → compra.id_compra |  |
| `id_produto` | INTEGER | PK, FK → produto.id_produto |  |
| `qt_comprada` | INTEGER | NN |  |
| `vl_custo_unitario` | NUMERIC(8,2) | NN |  |
| `dt_validade` | DATE |  |  |

Regras `CHECK`:

- `((vl_custo_unitario > (0)::numeric))`
- `((qt_comprada > 0))`

## fornecedor

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_fornecedor` | INTEGER | PK |  |
| `nm_fornecedor` | VARCHAR(120) | NN |  |
| `nr_cnpj` | VARCHAR(14) | UQ, NN |  |
| `nr_telefone` | VARCHAR(15) |  |  |
| `in_ativo` | BOOLEAN | NN | true |

Regras `CHECK`:

- `(((nr_cnpj)::text ~ '^[0-9]{14}$'::text))`
- `(((nr_telefone IS NULL) OR ((nr_telefone)::text ~ '^[0-9]{10,15}$'::text)))`

## historico_produto

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_historico` | INTEGER | PK |  |
| `id_produto` | INTEGER | FK → produto.id_produto, NN |  |
| `id_atendente` | INTEGER | FK → atendente.id_atendente, NN |  |
| `vl_preco_anterior` | NUMERIC(8,2) | NN |  |
| `vl_preco_novo` | NUMERIC(8,2) | NN |  |
| `dh_alteracao` | TIMESTAMP | NN | now() |

Regras `CHECK`:

- `(((vl_preco_anterior >= (0)::numeric) AND (vl_preco_novo >= (0)::numeric) AND (vl_preco_anterior <> vl_preco_novo)))`

## mesa

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_mesa` | SMALLINT | PK |  |
| `nr_mesa` | SMALLINT | UQ, NN |  |
| `tp_local` | CHAR(1) | NN |  |
| `qt_lugares` | SMALLINT | NN |  |
| `tp_status` | CHAR(1) | NN | 'L'   |
| `in_ativa` | BOOLEAN | NN | true |

Regras `CHECK`:

- `((tp_local = ANY (ARRAY['M'::bpchar, 'B'::bpchar])))`
- `((qt_lugares > 0))`
- `((nr_mesa > 0))`
- `((tp_status = ANY (ARRAY['L'::bpchar, 'O'::bpchar])))`

## movimentacao_estoque

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_movimentacao` | INTEGER | PK |  |
| `id_produto` | INTEGER | FK → produto.id_produto, NN |  |
| `id_pedido` | INTEGER | FK → pedido.id_pedido |  |
| `id_compra` | INTEGER | FK → compra.id_compra |  |
| `tp_movimento` | CHAR(1) | NN |  |
| `qt_movimento` | INTEGER | NN |  |
| `dh_movimento` | TIMESTAMP | NN | now() |
| `ds_motivo` | VARCHAR(100) |  |  |

Regras `CHECK`:

- `(((tp_movimento <> 'A'::bpchar) OR (ds_motivo IS NOT NULL)))`
- `((((tp_movimento = ANY (ARRAY['V'::bpchar, 'E'::bpchar])) AND (id_pedido IS NOT NULL) AND (id_compra IS NULL)) OR ((tp_movimento = 'C'::bpchar) AND (id_compra IS NOT NULL) AND (id_pedido IS NULL)) OR ((tp_movimento = 'A'::bpchar) AND (id_pedido IS NULL) AND (id_compra IS NULL))))`
- `((qt_movimento <> 0))`
- `((((tp_movimento = 'V'::bpchar) AND (qt_movimento < 0)) OR ((tp_movimento = ANY (ARRAY['C'::bpchar, 'E'::bpchar])) AND (qt_movimento > 0)) OR (tp_movimento = 'A'::bpchar)))`
- `((tp_movimento = ANY (ARRAY['V'::bpchar, 'C'::bpchar, 'E'::bpchar, 'A'::bpchar])))`

## pagamento

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_pagamento` | INTEGER | PK |  |
| `id_pedido` | INTEGER | FK → pedido.id_pedido, NN |  |
| `tp_forma` | CHAR(1) | NN |  |
| `vl_pago` | NUMERIC(8,2) | NN |  |
| `dh_pagamento` | TIMESTAMP | NN | now() |

Regras `CHECK`:

- `((tp_forma = ANY (ARRAY['D'::bpchar, 'C'::bpchar, 'B'::bpchar, 'P'::bpchar])))`
- `((vl_pago > (0)::numeric))`

## pedido

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_pedido` | INTEGER | PK |  |
| `id_mesa` | SMALLINT | FK → mesa.id_mesa, NN |  |
| `id_atendente` | INTEGER | FK → atendente.id_atendente, NN |  |
| `dh_abertura` | TIMESTAMP | NN | now() |
| `dh_fechamento` | TIMESTAMP |  |  |
| `in_taxa_servico` | BOOLEAN | NN | true |
| `tp_status` | CHAR(1) | NN | 'A'   |
| `ds_observacao` | VARCHAR(200) |  |  |

Regras `CHECK`:

- `(((dh_fechamento IS NULL) OR (dh_fechamento >= dh_abertura)))`
- `(((tp_status = 'A'::bpchar) = (dh_fechamento IS NULL)))`
- `((tp_status = ANY (ARRAY['A'::bpchar, 'F'::bpchar, 'C'::bpchar])))`

## pedido_produto

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_pedido` | INTEGER | PK, FK → pedido.id_pedido |  |
| `id_produto` | INTEGER | PK, FK → produto.id_produto |  |
| `qt_item` | SMALLINT | NN |  |
| `vl_preco_unitario` | NUMERIC(8,2) | NN |  |
| `tp_status` | CHAR(1) | NN | 'P'   |
| `dh_registro` | TIMESTAMP | NN | now() |
| `dh_pronto` | TIMESTAMP |  |  |
| `ds_observacao` | VARCHAR(100) |  |  |

Regras `CHECK`:

- `(((dh_pronto IS NULL) OR (dh_pronto >= dh_registro)))`
- `((vl_preco_unitario > (0)::numeric))`
- `(((tp_status = ANY (ARRAY['R'::bpchar, 'N'::bpchar])) = (dh_pronto IS NOT NULL)))`
- `((qt_item > 0))`
- `((tp_status = ANY (ARRAY['P'::bpchar, 'E'::bpchar, 'R'::bpchar, 'N'::bpchar, 'C'::bpchar])))`

## produto

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_produto` | INTEGER | PK |  |
| `id_setor` | SMALLINT | FK → setor.id_setor, NN |  |
| `id_categoria` | SMALLINT | FK → categoria.id_categoria, NN |  |
| `nm_produto` | VARCHAR(80) | UQ, NN |  |
| `nr_codigo_barras` | VARCHAR(14) | UQ, NN |  |
| `vl_preco` | NUMERIC(8,2) | NN |  |
| `in_vendavel` | BOOLEAN | NN | true |
| `in_alcoolico` | BOOLEAN | NN | false |
| `in_controla_estoque` | BOOLEAN | NN | false |
| `qt_estoque_atual` | INTEGER | NN | 0 |
| `qt_estoque_minimo` | INTEGER | NN | 0 |
| `in_ativo` | BOOLEAN | NN | true |

Regras `CHECK`:

- `(((nr_codigo_barras)::text ~ '^[0-9]{8,14}$'::text))`
- `((qt_estoque_atual >= 0))`
- `((qt_estoque_minimo >= 0))`
- `((in_controla_estoque OR ((qt_estoque_atual = 0) AND (qt_estoque_minimo = 0))))`
- `((in_vendavel OR (in_controla_estoque AND (NOT in_alcoolico))))`
- `(((vl_preco >= (0)::numeric) AND ((NOT in_vendavel) OR (vl_preco > (0)::numeric))))`

## reserva

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_reserva` | INTEGER | PK |  |
| `id_mesa` | SMALLINT | FK → mesa.id_mesa, NN |  |
| `nm_cliente` | VARCHAR(80) | NN |  |
| `nr_telefone` | VARCHAR(15) |  |  |
| `dh_reserva` | TIMESTAMP | NN |  |
| `qt_pessoas` | SMALLINT | NN |  |
| `tp_status` | CHAR(1) | NN | 'A'   |

Regras `CHECK`:

- `(((nr_telefone IS NULL) OR ((nr_telefone)::text ~ '^[0-9]{10,15}$'::text)))`
- `((qt_pessoas > 0))`
- `((tp_status = ANY (ARRAY['A'::bpchar, 'T'::bpchar, 'C'::bpchar])))`

## setor

| Coluna | Tipo | Restrições | Padrão |
|---|---|---|---|
| `id_setor` | SMALLINT | PK |  |
| `nm_setor` | VARCHAR(30) | UQ, NN |  |
| `in_preparo` | BOOLEAN | NN |  |
