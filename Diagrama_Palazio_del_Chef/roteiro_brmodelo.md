# Roteiro para montar o DER no BRModelo Web (modelo conceitual)

O BRModelo Web não importa arquivo (só por link de modelo compartilhado), então este roteiro permite refazer o DER em cerca de 30 a 40 minutos. A imagem de referência é `diagrama_palazio_del_chef.png`.

## Como montar

1. Em https://app.brmodeloweb.com, crie um **Modelo conceitual** chamado `Palazio del Chef`.

2. Arraste as **12 entidades** (retângulo) e dê o nome em maiúsculas, como na tabela 1.

3. Em cada entidade, adicione os **atributos** (círculo). O primeiro de cada lista é o **identificador**: marque como chave (círculo preenchido).

4. Arraste os **16 relacionamentos** (losango), ligue cada um às duas entidades e informe a **cardinalidade** (mín,máx) de cada lado, como na tabela 2.

5. Nos relacionamentos **contém** e **possui**, adicione os atributos próprios (círculos presos ao losango). **Não crie** as entidades Item_pedido nem Item_compra.

6. Não coloque chaves estrangeiras: no modelo conceitual, a ligação é feita pelo relacionamento.

7. Dica de organização: ATENDENTE à esquerda, PRODUTO à direita, e PEDIDO, MOVIMENTACAO_ESTOQUE, COMPRA, HISTORICO_PRODUTO e SETOR em coluna no meio; MESA, RESERVA e PAGAMENTO acima de PEDIDO; CATEGORIA acima de PRODUTO; FORNECEDOR perto de COMPRA.

## Tabela 1 — Entidades e atributos (o 1º é o identificador)

| Entidade | Atributos |
|---|---|
| MESA | **ID_MESA**, NR_MESA, TP_LOCAL, QT_LUGARES, TP_STATUS, IN_ATIVA |
| RESERVA | **ID_RESERVA**, NM_CLIENTE, NR_TELEFONE, DH_RESERVA, QT_PESSOAS, TP_STATUS |
| PEDIDO | **ID_PEDIDO**, DH_ABERTURA, DH_FECHAMENTO, IN_TAXA_SERVICO, TP_STATUS, DS_OBSERVACAO |
| ATENDENTE | **ID_ATENDENTE**, NM_ATENDENTE, NM_LOGIN, DS_SENHA_HASH, TP_FUNCAO, TP_PERFIL, DT_ADMISSAO, IN_ATIVO |
| SETOR | **ID_SETOR**, NM_SETOR, IN_PREPARO |
| PAGAMENTO | **ID_PAGAMENTO**, TP_FORMA, VL_PAGO, DH_PAGAMENTO |
| HISTORICO_PRODUTO | **ID_HISTORICO**, VL_PRECO_ANTERIOR, VL_PRECO_NOVO, DH_ALTERACAO |
| PRODUTO | **ID_PRODUTO**, NM_PRODUTO, NR_CODIGO_BARRAS, VL_PRECO, IN_VENDAVEL, IN_ALCOOLICO, QT_ESTOQUE_ATUAL, QT_ESTOQUE_MINIMO, IN_ATIVO |
| CATEGORIA | **ID_CATEGORIA**, NM_CATEGORIA, IN_ATIVA |
| MOVIMENTACAO_ESTOQUE | **ID_MOVIMENTACAO**, TP_MOVIMENTO, QT_MOVIMENTO, DH_MOVIMENTO, DS_MOTIVO |
| COMPRA | **ID_COMPRA**, DH_COMPRA, NR_NOTA_FISCAL, TP_STATUS, DH_RECEBIMENTO |
| FORNECEDOR | **ID_FORNECEDOR**, NM_FORNECEDOR, NR_CNPJ, NR_TELEFONE, IN_ATIVO |

## Tabela 2 — Relacionamentos e cardinalidades

| # | Entidade A | Cardinalidade em A | Relacionamento | Cardinalidade em B | Entidade B | Atributos do relacionamento |
|---|---|---|---|---|---|---|
| 1 | SETOR | (0,N) | agrupa | (1,1) | ATENDENTE | — |
| 2 | SETOR | (0,N) | prepara | (1,1) | PRODUTO | — |
| 3 | ATENDENTE | (1,N) | registra | (1,1) | PEDIDO | — |
| 4 | MESA | (0,N) | recebe | (1,1) | PEDIDO | — |
| 5 | PEDIDO | (1,N) | contém | (0,N) | PRODUTO | QT_ITEM, VL_PRECO_UNITARIO, TP_STATUS, DH_REGISTRO, DH_PRONTO, DS_OBSERVACAO |
| 6 | PEDIDO | (0,N) | é quitado por | (1,1) | PAGAMENTO | — |
| 7 | PRODUTO | (0,N) | tem | (1,1) | HISTORICO_PRODUTO | — |
| 8 | ATENDENTE | (0,N) | realiza | (1,1) | HISTORICO_PRODUTO | — |
| 9 | ATENDENTE | (0,N) | efetua | (1,1) | COMPRA | — |
| 10 | FORNECEDOR | (0,N) | fornece | (1,1) | COMPRA | — |
| 11 | COMPRA | (1,N) | possui | (0,N) | PRODUTO | QT_COMPRADA, VL_CUSTO_UNITARIO, DT_VALIDADE |
| 12 | PRODUTO | (0,N) | sofre | (1,1) | MOVIMENTACAO_ESTOQUE | — |
| 13 | MESA | (0,N) | reserva | (1,1) | RESERVA | — |
| 14 | CATEGORIA | (0,N) | classifica | (1,1) | PRODUTO | — |
| 15 | PEDIDO | (0,N) | gera | (0,1) | MOVIMENTACAO_ESTOQUE | — |
| 16 | COMPRA | (0,N) | gera | (0,1) | MOVIMENTACAO_ESTOQUE | — |

## Conferência final

- 12 entidades e 16 relacionamentos.
- Atendente (1,N) registra Pedido (1,1), como pediu o professor.
- Sem Item_pedido e sem Item_compra.
- Salve, exporte a imagem (ou PDF) e substitua a imagem do README por ela, se o grupo preferir o desenho do BRModelo.
