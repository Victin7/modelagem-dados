# 🍽️ Palazio del Chef — Relatório Técnico Final

### Modelagem de Banco de Dados · Entrega 2 (modelo lógico, SQL em MySQL e arquitetura analítica)

> Este README é o relatório da Entrega 2. A Entrega 1 (modelo conceitual, processos, requisitos, regras, dicionário conceitual e DER) está preservada no **[Anexo A](#anexo-a--entrega-1-modelo-conceitual)** no fim do arquivo.
> Marcadores: **`[PREENCHER]`** = dado que só o grupo tem · **`[VALIDAR]`** = ponto a confirmar com o grupo, o estabelecimento ou o professor.

## Integrantes

| Integrante | RGM | Usuário no GitHub |
|---|---|---|
| Raphael Luiz Lima de Araujo | 46995773 | [Raphael186](https://github.com/Raphael186) |
| Ricardo Santos Marcelino | 47023708 | [Ricardo-Sm1](https://github.com/Ricardo-Sm1) |
| Thiago Rodrigues Ribeiro | 47188049 | [thiago-rodrigues-S6](https://github.com/thiago-rodrigues-S6) |
| Victor Sousa dos Anjos | 47333235 | [Victin7](https://github.com/Victin7) (repositório `Victin7/modelagem-dados`) |

**Curso / Disciplina:** Análise e Desenvolvimento de Sistemas — Modelagem de Banco de Dados (UNICID) · Prof. Cid Andrade.
**SGBD:** MySQL 8.0 (InnoDB, `utf8mb4`) · **Banco:** `palazio_del_chef`.

## Sumário

1. [Modelo conceitual (revisão)](#1-modelo-conceitual)
   1.1 [Caracterização, problemas e evidências](#11-caracterização-da-organização-problemas-e-evidências) · 1.2 [Conversão](#12-conversão-do-conceitual-para-o-lógico) · 1.3 [PKs e FKs](#13-chaves-primárias-e-estrangeiras) · 1.4 [Normalização](#14-normalização) · 1.5 [Justificativas](#15-justificativas-técnicas) · 1.6 [BI e IA](#16-arquitetura-analítica-bi-e-ia)
2. [Modelo lógico](#2-modelo-lógico)
3. [Script SQL](#3-script-sql)
4. [Massa de dados](#4-massa-de-dados)
5. [Repositório](#5-repositório)
6. [Uso de IA](#6-uso-de-inteligência-artificial-nesta-entrega)
7. [Pitch](#7-pitch-de-8-minutos)
8. [Limitações e pontos a validar](#8-limitações-e-pontos-a-validar)

---

## 1. Modelo conceitual

### 1.1 Caracterização da organização, problemas e evidências

**Organização real:** Palazio del Chef (Bar e Restaurante Palazio Del Chef Tatuape LTDA., CNPJ 58.759.116/0001-99), Rua Apucarana, 480, Tatuapé, São Paulo. Restaurante e bar de atendimento presencial, **cerca de 30 mesas e 25 bistrôs**, **150 a 300 pedidos por dia útil e 400 a 550 aos sábados** (estimativa informada), funcionários CLT em escala 6x1, pedidos lançados no aplicativo Garçom Web. A caracterização completa, o horário e o cardápio estão no [Anexo A, seção 1](#1--caracterização-da-organização).

**Problemas identificados** (cada um é resolvido pelo modelo e tem consulta que o demonstra; a tabela de rastreabilidade está na seção 1.6):

| # | Problema (relatado ou observado na visita) | Como o modelo resolve |
|---|---|---|
| P1 | Equipe sem credenciais individuais: não se sabe quem registrou cada pedido ou ação | `atendente` com login único e perfil; `pedido.id_atendente` obrigatório; o banco confere o perfil de quem opera |
| P2 | Compras e cadastros (preço, estoque) dependem de poucas pessoas e não ficam registrados por responsável | Só gerência/sócio muda preço (com `historico_produto`), registra compra e faz ajuste de estoque |
| P3 | Compras sem registro estruturado (fornecedor, nota, custo) | `fornecedor`, `compra`, `compra_produto` com nota fiscal e custo unitário |
| P4 | Validade e estoque em planilha mensal, sem histórico nem alerta de reposição | `movimentacao_estoque` (saldo = soma das movimentações), `dt_validade`, `qt_estoque_minimo` |
| P5 | Pedido, estoque e compras fora do mesmo fluxo | Venda baixa estoque e compra recebida dá entrada, por trigger, na mesma transação |
| P6 | Pagamento e fechamento do caixa conferidos à mão | `pagamento` por forma, pagamento dividido que fecha o total do pedido ao centavo, painel de auditoria |

**Escopo.** O modelo cobre todos os dados da organização: atendimento (mesa, reserva, pedido, item), setores de preparo, cardápio com histórico de preço, pagamento, compras, fornecedores e estoque. Ficou fora o que não é dado do restaurante: folha de pagamento, escala de funcionários, nota fiscal de venda (emitida na maquininha) e dados pessoais de clientes.

**Justificativa da escolha.** O porte é adequado: tem processos de atendimento, produção em dois setores, compras, estoque e pagamento, o suficiente para exercitar o modelo sem exigir módulos fora do escopo. `[PREENCHER]` como o grupo tem acesso ao local (vínculo com o proprietário, se houver).

**Evidências.**

| Evidência | Registro |
|---|---|
| Endereço e CNPJ | Rua Apucarana, 480, Tatuapé, São Paulo · 58.759.116/0001-99 |
| Google Maps | [maps.app.goo.gl/TnAsUSbBUWyaUT7E9](https://maps.app.goo.gl/TnAsUSbBUWyaUT7E9) · horário em [`evidencias/horario_google_maps.jpg`](evidencias/horario_google_maps.jpg) |
| Rede social | [@palaziodelchef](https://www.instagram.com/palaziodelchef/) |
| Responsável | Ivo Diogo Alcantara Parente, proprietário e sócio-administrador · telefone (11) 2359-7134 |
| Fotos | [`imagem_palazio.jpeg`](imagem_palazio.jpeg) (fachada) · [`visita_palazio.jpeg`](visita_palazio.jpeg) (equipe com o gerente) |
| Cardápio | [`evidencias/cardapio_palazio_diurno.pdf`](evidencias/cardapio_palazio_diurno.pdf) |

**Relatório da entrevista.** Visita em **04/09/2026**, no estabelecimento, com **um gerente** (entrevistado) e os quatro integrantes. Foram levantados: atendimento e reserva, registro e encaminhamento do pedido, cancelamento, taxa de serviço, pagamento, compras e recebimento, validade e estoque, fechamento do caixa e regime dos funcionários. O texto organizado, com **observações separadas das respostas**, está em [`levantamento/levantamento.md`](levantamento/levantamento.md); o roteiro, em [`evidencias/roteiro_entrevista.md`](evidencias/roteiro_entrevista.md).

**Processos, requisitos e regras.** Estão detalhados, com os campos de dados de cada um, no [Anexo A, seções 2 a 4](#2--processos-de-negócio) (13 processos, requisitos funcionais e não funcionais, 31 regras de negócio). Ficaram de fora, por falta de informação do local, mas são prováveis: controle de escala e ponto, programa de fidelidade, entrega (o gerente disse que não há) e emissão de nota fiscal de venda (feita na maquininha). `[VALIDAR]`

**Revisão do modelo conceitual (Caso A).** `[PREENCHER]` Abaixo, a tabela exigida; a coluna 1 deve ser preenchida com os apontamentos do professor na correção da Entrega 1. As três mudanças feitas ao implementar estão registradas:

| Apontamento da correção da Entrega 1 | O que mudou | Por quê |
|---|---|---|
| `[PREENCHER]` | — | — |
| (orientação em aula) Funcionário → Atendente, Valor → Preço, remover Item_pedido, Atendente 1,N, incluir Histórico_Produto | Já aplicado no DER e no dicionário | Orientação do professor |
| (nosso, ao implementar) novo atributo `IN_CONTROLA_ESTOQUE` em PRODUTO `[VALIDAR]` | Produto de revenda tem estoque por unidade; prato e drink preparados na hora não | Sem ele o estoque de um prato ficaria zero e a regra "estoque nunca negativo" bloquearia vendas |
| (nosso) chaves compostas em CONTÉM e POSSUI | Atributos do relacionamento viram colunas da tabela associativa com PK `(id_pedido, id_produto)` | Mantém a orientação de não ter Item_pedido |
| (nosso) `TP_FUNCAO` e `TP_LOCAL` como domínios | Viraram `CHECK` | Função (garçom, caixa, cozinha, bar, gerente, sócio, limpeza) e local (mesa `M` ou bistrô `B`) |

**DER.** Notação de Chen no [Anexo A, seção 7](#7--diagrama-entidade-relacionamento-der) (12 entidades, 16 relacionamentos) e DER anterior do grupo em BRModelo, em [`Diagrama_Palazio_del_Chef/`](Diagrama_Palazio_del_Chef/). Software: BRModelo (DER anterior) e Graphviz (diagrama gerado). `[VALIDAR]` se o professor exige o DER final em notação BRModelo.

### 1.2 Conversão do conceitual para o lógico

| Construção do DER | Tabela/coluna resultante |
|---|---|
| Entidade | Uma tabela; o identificador vira PK |
| Relacionamento 1:N | FK no lado N |
| Relacionamento N:N com atributos (CONTÉM, POSSUI) | Tabela associativa com PK composta e duas FKs |
| Atributo opcional | Coluna que aceita `NULL` (`dh_fechamento`, `dh_pronto`, `nr_telefone`, `dt_validade`...) |
| Domínio fechado (`TP_*`, `IN_*`) | `CHAR`/`TINYINT(1)` com `CHECK` |
| Atributo derivado (total do pedido, taxa de 10%, saldo) | **Não é coluna**: view `vw_pedido_total` e função `fn_total_pedido` |

Resultado: **14 tabelas** (12 entidades + `pedido_produto` + `compra_produto`) e **18 chaves estrangeiras**.

| Tabela | Origem | Linhas na massa |
|---|---|---|
| setor | SETOR | 5 |
| categoria | CATEGORIA | 11 |
| atendente | ATENDENTE | 15 |
| mesa | MESA | 55 (30 mesas + 25 bistrôs) |
| reserva | RESERVA | 14 |
| produto | PRODUTO | 62 (54 do cardápio + 8 insumos) |
| historico_produto | HISTORICO_PRODUTO | 8 |
| pedido | PEDIDO | 1.649 |
| pedido_produto | CONTÉM | 5.936 |
| pagamento | PAGAMENTO | 1.933 |
| fornecedor | FORNECEDOR | 6 |
| compra | COMPRA | 11 |
| compra_produto | POSSUI | 36 |
| movimentacao_estoque | MOVIMENTACAO_ESTOQUE | 1.720 |

### 1.3 Chaves primárias e estrangeiras

**PKs.** Substitutas (`INT`/`SMALLINT AUTO_INCREMENT`) nas entidades. Compostas só em `pedido_produto (id_pedido, id_produto)` e `compra_produto (id_compra, id_produto)`. Identificadores naturais (`nm_login`, `nr_cnpj`, `nr_codigo_barras`, `nr_mesa`, `nm_produto`) ficam `UNIQUE`.

| Tabela filha | Coluna(s) FK | Tabela pai | Cardinalidade |
|---|---|---|---|
| atendente | id_setor | setor | N:1 |
| produto | id_setor, id_categoria | setor, categoria | N:1 |
| historico_produto | id_produto, id_atendente | produto, atendente | N:1 |
| reserva | id_mesa | mesa | N:1 |
| pedido | id_mesa, id_atendente | mesa, atendente | N:1 |
| pedido_produto | id_pedido, id_produto | pedido, produto | N:1 (PK composta) |
| pagamento | id_pedido | pedido | N:1 |
| compra | id_fornecedor, id_atendente | fornecedor, atendente | N:1 |
| compra_produto | id_compra, id_produto | compra, produto | N:1 (PK composta) |
| movimentacao_estoque | id_produto; id_pedido ou id_compra (um dos dois, conforme o tipo) | produto, pedido, compra | N:1 |

Sem `ON DELETE CASCADE`: o histórico não some em cascata; exclusões são barradas por trigger (RN13).

### 1.4 Normalização

**1FN.** Colunas atômicas, sem listas nem grupos repetidos; itens do pedido e da compra estão em tabelas próprias; toda tabela tem PK.

**2FN.** Nas tabelas de PK composta, todo atributo depende da chave inteira: em `pedido_produto`, `qt_item`, `vl_preco_unitario`, `tp_status`, `dh_registro`, `dh_pronto` e `ds_observacao` dependem de (pedido, produto); em `compra_produto`, `qt_comprada`, `vl_custo_unitario` e `dt_validade` dependem de (compra, produto). Nome e preço de tabela do produto ficam em `produto`. As demais têm PK simples.

**3FN.** Nenhum atributo não-chave depende de outro não-chave: nome de setor/categoria fica nas suas tabelas, dados do garçom não se repetem em `pedido`, e **total, taxa de serviço e saldo não são armazenados** (view `vw_pedido_total`).

**Redundâncias deliberadas e proteção:**

| Redundância | Por quê | Proteção |
|---|---|---|
| `produto.qt_estoque_atual` | Consulta rápida no salão | Só o trigger `trg_mov_ai` altera o saldo; auditoria **A06** confere saldo = soma das movimentações |
| `pedido_produto.vl_preco_unitario` | O preço da venda não muda quando o cardápio muda (RN07) | Trigger copia o preço e impede alteração; auditoria **A08** compara com o histórico |
| `mesa.tp_status` | Mapa de mesas em tempo real | Triggers de pedido; auditoria **A05** confere com os pedidos abertos |

### 1.5 Justificativas técnicas

| Decisão | Justificativa |
|---|---|
| PK substituta nas entidades | Nome, CNPJ e código de barras mudam ou são digitados errado; um número interno estável evita atualizar FKs |
| PK composta em `pedido_produto` e `compra_produto` | Um item é identificado por (pedido, produto); impede o mesmo produto duas vezes e dispensa Item_pedido (orientação do professor) |
| `pedido.id_atendente` e `id_mesa` obrigatórias | Todo pedido tem responsável (RN01) e mesa (RN02): resolve P1 |
| FKs sem `CASCADE` | Histórico financeiro e de estoque não pode sumir (RN13) |
| `UNIQUE` em login, CNPJ, código de barras, número da mesa e nomes de setor/categoria/produto | Evita duplicidade que quebraria login individual (RN12), identificação do fornecedor, leitura do código (RN03) e mapa de mesas |
| `NOT NULL` nos atributos de negócio | Sem preço, quantidade, data e status o pedido, a compra e o estoque deixam de ser calculáveis; opcionais só `dh_fechamento`, `dh_pronto`, `dh_recebimento`, `nr_telefone`, `dt_validade`, `ds_observacao` e a origem da movimentação |
| `CHECK` de domínio (`tp_status`, `tp_forma`, `tp_perfil`, `tp_funcao`, `tp_local`, `tp_movimento`) | Só valores previstos no dicionário |
| `CHECK` de consistência (fechamento ≥ abertura; `dh_pronto` só se pronto/entregue; nota fiscal na compra recebida; sinal e origem da movimentação) | Estado e datas contam a mesma história |
| `CHECK` numéricos (`qt_item > 0`, `vl_pago > 0`, estoque ≥ 0, CNPJ 14 dígitos, telefone 10 a 15) | Bloqueiam valores impossíveis na origem (RN08); são 41 `CHECK`s |
| Coluna gerada `id_mesa_aberta` + `UNIQUE ux_pedido_mesa_aberto` | RN05 (um pedido aberto por mesa). O MySQL não tem índice parcial; a coluna só tem valor quando o pedido está aberto, e `UNIQUE` aceita vários `NULL` |

**Regras de negócio no banco** (script `04_regras_triggers_views.sql`, **32 triggers**, 6 funções/procedimentos, 3 views). Valem mesmo que o Garçom Web ou outra ferramenta acesse o banco:

| Regra (Anexo A, seção 4) | Implementação |
|---|---|
| RN01 pedido com atendente; RN02 com mesa | FKs `NOT NULL` |
| RN03 código de barras único | `UNIQUE` + `CHECK` |
| RN04 só atendente ativo abre pedido | `trg_pedido_bi` |
| RN05 um pedido aberto por mesa | `trg_pedido_bi` + `ux_pedido_mesa_aberto` |
| RN06 item vai ao setor de preparo do produto | `trg_produto_bi/bu` |
| RN07 preço congelado no item | `trg_pp_bi/bu` |
| RN08 estoque suficiente, nunca negativo | `trg_pp_bi`, `trg_mov_bi` e `CHECK` |
| RN09/RN17 cancelar item só antes de ficar pronto | matriz de transições em `trg_pp_bu` |
| RN10 fechar só pago e sem itens pendentes | `trg_pedido_bu` |
| RN11 total calculado | `vw_pedido_total`, `fn_total_pedido` |
| RN13 cadastros não são excluídos | `trg_nodel_*` |
| RN14 produto indisponível não é pedido | `trg_pp_bi` |
| RN15 pagamento dividido, sem exceder a conta | `trg_pagamento_bi` |
| RN16 taxa de 10% removível | `in_taxa_servico` + `vw_pedido_total` |
| RN21 saldo = soma das movimentações | `trg_mov_ai` (única porta do saldo) |
| RN24 só gerência/sócio muda preço, com histórico | `trg_produto_bu` |
| RN22/RN23 compra só de fornecedor ativo, pela gerência/sócio, com nota ao receber | `trg_compra_bi/bu/au`, `trg_cp_*` |
| RN30 insumo com estoque e fora do cardápio | `CHECK ck_produto_insumo` |
| Histórico imutável (pagamento, movimentação, histórico de preço) | `trg_ro_*` |

**Quem fez a operação.** O app informa o usuário com `SET @id_atendente = <id>` na sessão; o procedimento `sp_exige_perfil` confere o perfil (A atendimento, P preparo, G gerência, S sócio). Item só vai a "em preparo/pronto" por quem é do setor do produto (ou gerência); só gerência/sócio faz ajuste manual de estoque ou muda preço.

**Particularidades do MySQL.** `CURRENT_DATE` não é aceito em `CHECK`; a data de admissão futura é barrada por trigger. Triggers são por linha e separados para `INSERT` e `UPDATE` (por isso 32 e não 27). Mensagens de erro usam `SIGNAL SQLSTATE '45000'`. Como não é possível desabilitar triggers por tabela, eles são criados **depois** da carga histórica.

**Índices.** Além de PKs e `UNIQUE`: fila de preparo (`ix_pp_fila`), caixa por data (`ix_pagamento_data`), extrato de estoque (`ix_mov_produto_data`) e as FKs mais consultadas (16 índices).

**Por que MySQL.** É o SGBD definido pela disciplina. Atende `CHECK` (8.0.16+), colunas geradas, funções de janela (`PERCENT_RANK`, `ROLLUP`) e triggers.

### 1.6 Arquitetura analítica (BI e IA)

O banco transacional atende o salão; a análise lê dele sem escrever:

```
Garçom Web ──► MySQL (OLTP, 14 tabelas)
                    │  réplica de leitura / carga noturna
                    ▼
          Camada analítica (views e tabelas agregadas)
                    │
        ┌───────────┴────────────┐
        ▼                        ▼
  Painéis de BI (gerência)   Modelos de IA (previsão)
```

Fatos: `pedido_produto`, `pagamento`, `movimentacao_estoque`. Dimensões: tempo, produto/categoria/setor, atendente, mesa.

**Rastreabilidade: problema ou indicador → tabelas → consulta** (arquivos `docs/07_consultas_gerenciais.sql` e `docs/08_consultas_auditoria.sql`):

| Problema / indicador (KPI) | Tabelas | Consulta |
|---|---|---|
| P1 quem registrou cada pedido; desempenho por atendente | pedido, atendente | G04, G15, A17, A18 |
| P2 alteração de preço e compras com responsável | produto, historico_produto, compra, atendente | G10, A15, A20 |
| P3 compras com fornecedor, nota e custo; margem | compra, compra_produto, fornecedor, produto | G08, G13, A20 |
| P4 estoque crítico, validade, reposição | produto, movimentacao_estoque, compra_produto | G12, G14, A16 |
| P5 item do lançamento ao preparo; baixa automática | pedido_produto, movimentacao_estoque | G05, A10 |
| P6 conferência do caixa por forma de pagamento | pagamento, pedido, pedido_produto | G01, G11, A19, A01–A02 |
| KPI faturamento e ticket médio | pedido, pedido_produto, pagamento | G01 |
| KPI produtos mais vendidos, curva ABC | pedido_produto, produto | G02, G09 |
| KPI receita por setor e categoria | pedido_produto, produto, setor, categoria | G03 |
| KPI pedidos por hora (escala de equipe) | pedido | G06 |
| KPI giro e permanência das mesas | pedido, mesa | G07 |
| Integridade geral do banco (14 verificações) | todas | A01 a A14 |

**Potencial para BI:** ligar uma ferramenta de BI às views e consultas acima já entrega painéis de faturamento diário, mapa de calor de horários, ranking de produtos e alerta de estoque.

**Usos de IA que o modelo sustenta** (propostas, não implementadas): (1) previsão de demanda por produto e hora, sobre `pedido_produto`; (2) reposição sugerida, em que G12 é a versão em SQL e um modelo pode substituí-la usando sazonalidade e validade; (3) elasticidade de preço, partindo de G10; (4) detecção de anomalias em cancelamentos e taxa removida (A17, A18).

Cuidados: dados pessoais (nome e telefone de reserva, login) ficam fora da camada analítica. Nenhum dado real foi usado.

---

## 2. Modelo lógico

![Modelo lógico](docs/modelo_logico.png)

Diagrama gerado pelo **Graphviz** a partir do catálogo do MySQL real (`entrega-2/scripts/gerar_modelo_logico.py`), com PK/FK, tipos e cardinalidade mínima e máxima (mín,máx) em cada ponta. Versão vetorial: [`docs/modelo_logico.svg`](docs/modelo_logico.svg). `[VALIDAR]` se o professor exige a notação do BRModelo; o fonte `.dot` está em `docs/`.

**Dicionário de dados lógico** (tipos, restrições, `CHECK`, índices e a regra de negócio de cada atributo): [`docs/dicionario_dados_logico.html`](docs/dicionario_dados_logico.html), em um único arquivo HTML.

## 3. Script SQL

O script único é [`docs/script.sql`](docs/script.sql) (gerado pela concatenação dos arquivos numerados, que também estão em `docs/`):

| Arquivo | Conteúdo |
|---|---|
| `01_create_database.sql` | `CREATE DATABASE` |
| `02_create_tables.sql` | `CREATE TABLE` com PK, FK, `UNIQUE`, `NOT NULL`, `CHECK` e índices |
| `03_massa_de_dados.sql` | `INSERT` da massa fictícia (≈ 0,8 MB) |
| `04_regras_triggers_views.sql` | Funções, procedimentos, 32 triggers e 3 views |
| `05_select_join.sql` | 10 `SELECT` com `JOIN` (comanda, conta, mesas ocupadas, fila, estoque crítico...) |
| `06_update_delete.sql` | Ciclo completo de um pedido com `UPDATE` e `DELETE` (termina em `ROLLBACK`) e 15 testes de operação bloqueada |
| `07_consultas_gerenciais.sql` | G01 a G15, cada uma com a pergunta e o problema que atende |
| `08_consultas_auditoria.sql` | A01 a A14 (painel de integridade) e A15 a A20 (trilhas) |

```bash
mysql -u root -p --default-character-set=utf8mb4 < docs/script.sql
```

Reexecutar é seguro: o script recria o banco. Requer MySQL 8.0.16 ou superior. Testado em MySQL 8.0.46 a partir de banco vazio, sem erros (exit 0). Resultado: 14 tabelas, 3 views, 32 triggers, 41 `CHECK`s.

**Testes e evidências.**
- **Painel A01 a A14:** todas com **0 violações** (pagamento = total, nenhum pedido fechado com item pendente, saldo = soma das movimentações, sem estoque negativo, preço do item = preço vigente, mesa coerente, perfil de quem abre pedido, etc.). `[PREENCHER]` print da execução na máquina do grupo.
- **Bloqueios:** 15 operações inválidas rejeitadas com a mensagem da regra (mesa ocupada, perfil sem permissão, estoque insuficiente, pagamento acima do total, exclusão de pedido, alteração de pagamento, código de barras duplicado...), todas "OK".
- **Fluxo (06, parte 1):** abre pedido, lança itens, preparo, entrega, cancelamento com estorno, remoção da taxa, pagamento dividido, fechamento com liberação da mesa, reajuste com histórico, recebimento de compra e `DELETE`s permitidos; termina com `ROLLBACK` e a carga continua com 1.649 pedidos.

## 4. Massa de dados

Gerada por [`entrega-2/scripts/gen_data.py`](entrega-2/scripts/gen_data.py) (Python, semente `20261013`; mesma saída a cada execução). **Nomes, CNPJs, telefones, notas fiscais e valores são inventados**; senhas são guardadas como SHA-256 com sal.

**Volume versus números reais.** O restaurante tem 150 a 300 pedidos por dia útil e 400 a 550 aos sábados. A massa simula **uma semana** (ter 06/10 a seg 12/10/2026, "agora" = seg 21h20) com **1.649 pedidos** (1.611 fechados, 27 abertos, 11 cancelados), que equivale a uma semana real, e não ao histórico de meses. Escolhemos uma semana para as consultas gerenciais terem variação (dias úteis, sábado, domingo, reajuste de preço em 09/10) sem inflar o arquivo.

| Item | Real (informado) | Na massa |
|---|---|---|
| Pedidos em dias úteis | 150 a 300 | seg 153, ter 180, qua 195, qui 245, sex 273 |
| Pedidos no sábado | 400 a 550 | 430 |
| Domingo | menor movimento | 135 |
| Mesas / bistrôs | cerca de 30 / 25 | 30 / 25 |
| Horário | seg–qua 6h–23h; qui–sáb 6h–0h; dom 11h–18h | pedidos só dentro do horário |
| Taxa de serviço | 10%, removível | 4% dos pedidos sem taxa |
| Pagamento | Pix, crédito, débito, dinheiro | 34% / 31% / 25% / 10% |

**Coerência.** O gerador simula a semana em ordem cronológica; estoque, compras e baixas são calculados juntos para nenhum saldo ficar negativo, e cada pagamento fecha o total do pedido ao centavo. O painel A01–A14 prova isso.

**Uso de LLM.** O Claude escreveu o programa gerador; os dados são sintéticos e reproduzíveis. Foi o grupo quem informou os volumes reais; cardápio, setores, horários e regras vieram do levantamento. É inventado: preços de alguns itens, nomes de pessoas e fornecedores (o local não informou fornecedores), quantidades e custos.

## 5. Repositório

```text
modelagem-dados/
├── README.md                          ← este relatório
├── imagem_palazio.jpeg · visita_palazio.jpeg
├── levantamento/levantamento.md
├── evidencias/                        ← roteiro, cardápio, horário, prompts
├── docs/                              ← script.sql, 01..08, modelo lógico (.png/.svg/.dot), dicionário lógico (.html)
├── dicionario_dados_palazio/          ← dicionário conceitual (Entrega 1, HTML)
├── Diagrama_Palazio_del_Chef/         ← DER (Entrega 1)
├── Fluxograma_Palazio_del_Chef/       ← fluxos de vendas e compras
└── entrega-2/scripts/                 ← gerador da massa, do diagrama e do dicionário
```

**Commits.** O histórico deve mostrar contribuições equilibradas de cada integrante, feitas pela **própria conta do GitHub**, com o nome igual ao da tabela de integrantes. `[PREENCHER]`/`[VALIDAR]` conferir antes da entrega. O professor corrige apenas a branch `main`.

**Responsabilidades:** Thiago (diagrama e entrevista), Ricardo (análise da atividade e entrevista), Victor (estrutura do projeto, README, banco MySQL), Raphael (fluxograma e etapa por etapa).

## 6. Uso de inteligência artificial nesta entrega

O registro completo (prompts do ChatGPT desde 19/08 e usos do Claude) está no [Anexo A, seção 9](#9--uso-de-inteligência-artificial).

| Ferramenta | Para quê | Como foi verificado |
|---|---|---|
| Claude (Anthropic) | Modelo lógico, scripts SQL em MySQL (tabelas, triggers, views, consultas), gerador da massa, diagrama e dicionário lógico, este relatório | Execução em MySQL 8.0.46 a partir de banco vazio; painel de 14 verificações com 0 violações; 15 operações inválidas bloqueadas; comparação com o dicionário e as regras da Entrega 1 |
| ChatGPT (OpenAI) | Organização do README e orientações para aplicar as alterações do professor no DER (Entrega 1) | Conferência com o parecer do professor e com a visita |

**Erros da IA encontrados nos testes:** `SIGNAL` com `CONCAT` direto (erro de sintaxe no MySQL), `CHECK` com `CURRENT_DATE` (não aceito), índice parcial inexistente no MySQL (trocado por coluna gerada), exclusão de compra pendente bloqueada por engano, teste de estoque que estourava o tipo, reajuste de teste sem efeito e numeração das regras diferente do README. Todos corrigidos.

`[PREENCHER]` Reflexão crítica do grupo, com suas palavras: o que a IA acertou, o que errou e como vocês validaram.

## 7. Pitch de 8 minutos

Roteiro sugerido, na ordem pedida: **(1) problema** (P1 a P6, com a foto da visita); **(2) solução** (14 tabelas, regras no banco); **(3) modelo lógico** (diagrama); **(4) demonstração em SQL** (rodar `script.sql`, mostrar o painel A01–A14 e um bloqueio de `06_update_delete.sql`); **(5) consultas** (G01, G04, G12); **(6) BI e IA** (tabela de rastreabilidade); **(7) benefícios** (quem fez o quê, estoque e caixa conferidos). O deck está no artefato de slides do grupo. `[VALIDAR]` o tempo ensaiando.

## 8. Limitações e pontos a validar

1. **Item_pedido removido** (orientação do professor): o mesmo produto não repete no pedido e o status é por produto. Pedir de novo soma à linha existente (`sp_lancar_item`); pedir mais de um produto já entregue reinicia o status da linha. `[VALIDAR]` com o professor.
2. **`movimentacao_estoque` não guarda quem fez** (o dicionário da Entrega 1 não tem `id_atendente`); o banco só valida o perfil na hora. `[VALIDAR]`
3. **`IN_CONTROLA_ESTOQUE`** é atributo novo. `[VALIDAR]`
4. **Baixa de insumos** é manual no estabelecimento; a massa simula lançamentos de ajuste diários.
5. **Conferência de documento para bebida alcoólica** (RN18) é feita pessoalmente e não é registrada.
6. **Fornecedores:** o local não os informou; os seis da carga são fictícios.
7. A nota fiscal é emitida pela maquininha; `nr_nota_fiscal` existe só em compras.

---

# Anexo A — Entrega 1 (modelo conceitual)

*Conteúdo da Entrega 1 preservado integralmente. Os processos usam o prefixo `PR` (PR1 a PR13) para não se confundir com os problemas P1 a P6 acima.*

### 1. 📖 Caracterização da Organização

- **Nome e natureza:** **Palazio del Chef** — estabelecimento do segmento de alimentação, com características de **restaurante e bar**, com fins lucrativos.
- **Contexto e porte:** restaurante e bar no Tatuapé (São Paulo), com um único cardápio (o mesmo no almoço e à noite, com pratos e bar) e atendimento presencial, sem delivery. O salão tem cerca de **30 mesas e 25 bistrôs** (estimativa do grupo) e o movimento é de **150 a 300 pedidos** por dia em dias de semana e de **400 a 550 pedidos** aos sábados (estimativa do grupo). A operação é dividida entre **salão** (garçons), **cozinha**, **bar**, **gerência** e **limpeza**, com funcionários CLT em escala 6x1. O grupo classifica o porte como **baixo a médio**.

| Dado de porte | Valor |
|---------------|-------|
| Número de mesas | Cerca de 30 mesas e 25 bistrôs (estimativa) |
| Setores com funcionários | Salão (garçons), cozinha, bar, gerência e limpeza `[PREENCHER: quantidade em cada setor]` |
| Horário de funcionamento | Segunda a quarta: 06:00 às 23:00 · Quinta a sábado: 06:00 às 00:00 · Domingo: 11:00 às 18:00 (conforme o Google Maps; print em [`evidencias/`](./evidencias/horario_google_maps.jpg)) |
| Pedidos (estimativa por dia) | 150 a 300 em dias de semana; 400 a 550 aos sábados |
| Itens no cardápio | Mais de 260 preços, em cerca de 45 grupos (lanches, pratos, porções, sobremesas, sucos, caipirinhas, drinks, cervejas, chopp, doses etc.). Ver [`evidencias/`](./evidencias/) |
| Como os pedidos são registrados hoje | Comanda, marcada por mesa. Os garçons também lançam o pedido no aplicativo **Garçom Web** |
| Regime de trabalho | CLT, escala 6x1 |

- **Problemas e necessidades identificados:**
  - **Falta de controle dos atendentes (original):** a equipe não é registrada por credenciais. Isso dificulta saber quem registrou cada pedido e controlar as atividades feitas no sistema.
  - **Funcionários sem credenciais administrativas (informado na visita):** quem não é da gerência ou da direção não tem acesso individual de gestão. Compras e cadastros dependem de poucas pessoas e não ficam registrados por responsável.
  - **Compras sem registro estruturado (informado na visita):** as compras de produtos e insumos são feitas pelo proprietário. O recebimento é conferido pelo gerente. Não há registro de fornecedor nem de custo por compra.
  - **Validade e estoque em planilha (informado na visita):** uma vez por mês os garçons conferem a validade e retiram os itens a até 10 dias de vencer, anotando tudo em planilha. Não há alerta automático de reposição nem histórico de movimentação.
  - **Sistema atual:** o pedido é lançado no aplicativo **Garçom Web**, que o envia ao bar ou à cozinha, com aviso ao chefe de cozinha. O estoque e as compras ficam fora desse fluxo. `[VALIDAR: o que o Garçom Web já controla e o que o novo modelo deve cobrir]`
  - **Conferência dos pagamentos e do caixa (informado pelo grupo):** a maquininha gera a nota fiscal; tudo é separado e conferido antes de encerrar o expediente. O pagamento em dinheiro também é lançado no aplicativo do local.
- **Justificativa da escolha:** O estabelecimento foi escolhido pela sua estrutura operacional e pelos processos envolvidos no funcionamento (atendimento, produção em setores distintos, compras, estoque e pagamento), o que permite aplicar os conceitos de modelagem de banco de dados. O porte é adequado: tem processos e entidades suficientes, sem ser complexo demais para esta etapa. `[PREENCHER: como o grupo tem acesso ao local — ex.: vínculo com o proprietário]`
- **Evidências da organização:**

<p align="center">
  <img src="./imagem_palazio.jpeg" alt="Fachada do Palazio del Chef, no Tatuapé" width="400">
</p>

| Evidência | Registro |
|-----------|----------|
| Razão social | Bar e Restaurante Palazio Del Chef Tatuape LTDA. |
| Endereço completo | Rua Apucarana, 480 — Tatuapé, São Paulo - SP (CEP 03311-000) |
| CNPJ | 58.759.116/0001-99 |
| Link no Google Maps | [maps.app.goo.gl/TnAsUSbBUWyaUT7E9](https://maps.app.goo.gl/TnAsUSbBUWyaUT7E9) |
| Rede social | Instagram: [@palaziodelchef](https://www.instagram.com/palaziodelchef/) |
| Contato | Telefone (11) 2359-7134 · E-mail palaziodelchef@gmail.com |
| Responsável pela organização | Ivo Diogo Alcantara Parente, proprietário e sócio-administrador (informado na visita) |
| Datas das visitas | 04/09/2026 |
| Entrevista e observação | Resumo abaixo, com as informações da visita de 04/09/2026. Roteiro usado: [`evidencias/roteiro_entrevista.md`](./evidencias/roteiro_entrevista.md) |
| Cardápio | Cardápio do estabelecimento (o mesmo no almoço e à noite), em [`evidencias/`](./evidencias/cardapio_palazio_diurno.pdf) |
| Fotos da pesquisa de campo | Fachada com a placa "Café e Restaurante — Palazio del Chef — Tatuapé" (foto acima). Registro da equipe com o gerente durante a visita (Figura 2, abaixo). A foto do salão não foi publicada, para não expor clientes. |
| Nome no Google Maps | "Palazio Del Chefe" (a placa da fachada diz "Palazio del Chef") |

Durante a visita, foi realizada uma entrevista com um gerente do estabelecimento, para compreender o atendimento aos clientes, o registro dos pedidos, o encaminhamento à cozinha ou ao bar e o gerenciamento do estoque. Como evidência, apresenta-se a fotografia registrada pela equipe durante o encontro com o gerente.

<p align="center">
  <img src="./visita_palazio.jpeg" alt="Equipe do projeto com o gerente do Palazio del Chef durante a visita" width="800">
</p>

*Figura 2 — Registro fotográfico da equipe com o gerente durante a visita ao estabelecimento.*

**Resumo da visita de 04/09/2026** (informações repassadas pelo grupo, a partir do que foi visto e perguntado no local):

- O cliente chega e escolhe o lugar entre cerca de 30 mesas e 25 bistrôs, ou reserva por telefone. A atendente que fica no caixa registra a reserva no sistema e a marca pelo número da mesa. Quem não reservou entra e vê se há lugar.
- O pedido é marcado por mesa, na comanda. O **garçom** lança o pedido no aplicativo **Garçom Web**, que o encaminha ao **bar** ou à **cozinha** e notifica o chefe de cozinha para o preparo.
- Cada produto recebido é cadastrado com um **código de barras próprio**. Os pratos também existem no sistema, e tudo que sai aparece para eles. Se o produto não tem estoque, o sistema bloqueia a venda.
- O garçom também encaminha o preparo, cobra o cliente e gera a conta no aplicativo. O pagamento é em dinheiro, cartão ou Pix. É cobrada **taxa de serviço de 10%**.
- Um item pode ser cancelado no sistema do aplicativo, antes de ficar pronto, e o cancelamento também bloqueia o item na cozinha.
- Para bebida alcoólica, pedem **documento com foto**, por causa da proibição para menores de 18 anos.
- As **compras** de produtos e insumos são feitas pelo proprietário. Quem **recebe** a mercadoria é o gerente. Os fornecedores não foram informados.
- Os garçons conferem a **validade** uma vez por mês, retiram os itens a até 10 dias do vencimento e anotam tudo em planilha.
- Controlam o estoque de ingredientes, de pratos prontos e também de bebidas.
- A **nota fiscal** só vem pela maquininha de cartão, sem cupom no sistema.
- Os registros são guardados por semestre (meses 1 a 6 e meses 7 a 12). O fechamento do caixa é feito pelo gerente.
- Os funcionários são CLT, em escala **6x1**. Os funcionários não têm credenciais administrativas e, segundo o gerente, não possuem credenciais individuais de acesso ao aplicativo de pedidos.
- Segundo o gerente, o restaurante atende presencialmente e **não realiza entregas por delivery**. A reserva de mesa continua sendo feita por telefone.

**Nota de escopo:** os problemas listados na seção 1 vêm do que foi relatado e observado na visita. O grupo não afirma que o estabelecimento tenha falhas comprovadas no atendimento, erros em pedidos ou inconsistências de estoque. A proposta organiza as informações e estabelece uma estrutura adequada para armazená-las e relacioná-las. Dificuldades adicionais dependem de levantamento complementar sobre pagamento, estoque, compras e acompanhamento dos pedidos.

#### 🎯 Objetivo do Projeto (original)

Analisar os processos do estabelecimento e desenvolver uma modelagem de banco de dados capaz de organizar as principais informações relacionadas ao **atendimento, pedidos, produtos, mesas, setores e atendentes**. Nesta versão, o escopo também cobre **pagamento, compras, fornecedores e controle de estoque** `(proposta)`.

---

### 2. 🗺️ Processos de Negócio

Os processos foram organizados em três grupos: **Vendas** (ciclo do atendimento), **Compras** (reposição de mercadoria) e **Apoio** (estoque, pessoas e caixa). A coluna *Origem* indica se o processo veio do README original ou é uma proposta a validar em campo.

#### 2.1 Processos de Vendas

| # | Processo | Descrição | Entrada → Saída | Responsável | Entidades | Origem |
|---|----------|-----------|-----------------|-------------|-----------|--------|
| PR1 | 🛎️ Atendimento e abertura de mesa | O cliente chega e é acomodado em uma mesa ou bistrô (com ou sem reserva). O garçom abre o pedido da mesa, que passa a ocupada. | Cliente → pedido aberto na mesa | Garçom | MESA, PEDIDO, ATENDENTE | original / confirmado na visita |
| PR2 | 📝 Registro do pedido | O garçom marca o pedido por mesa na comanda e o lança no aplicativo Garçom Web (produto, quantidade, observação). O preço do cardápio é copiado para o item e o estoque é baixado. Sem estoque, o item é bloqueado. | Pedido do cliente → itens pendentes | Garçom | PEDIDO, PRODUTO (relacionamento contém) | original / confirmado na visita |
| PR3 | 🏃 Encaminhamento para cozinha e bar | Depois do lançamento, o pedido é encaminhado ao bar ou à cozinha, com notificação ao chefe de cozinha para o preparo. | Item pendente → fila do setor | Garçom / sistema | PEDIDO, PRODUTO (contém), SETOR | original / confirmado na visita |
| PR4 | 🍳 Preparo | O setor prepara o item e o marca como em preparo e depois como pronto. O atendente entrega e marca como entregue. | Item na fila → item entregue | Cozinha / Bar / Atendente | PEDIDO, PRODUTO (contém) | original |
| PR5 | 💳 Fechamento da conta e pagamento | O garçom gera a conta no aplicativo e cobra o cliente. A conta soma os itens e a **taxa de serviço de 10%**. O pagamento é em dinheiro, cartão ou Pix, podendo ser dividido. Com a conta quitada, o pedido é fechado e a mesa é liberada. A nota fiscal vem pela maquininha de cartão. | Pedido entregue → pedido fechado, mesa livre | Garçom | PEDIDO, PAGAMENTO, MESA | original / confirmado na visita |
| PR6 | 📅 Reservas | O cliente reserva mesa por telefone. No dia, a reserva vira o atendimento da mesa. Quem não reservou entra e vê se há lugar. A atendente que fica no caixa registra a reserva no sistema do estabelecimento e a marca pelo número da mesa. | Pedido de reserva → mesa reservada | Atendente do caixa |  RESERVA, MESA | confirmado na visita |
| PR7 | 📋 Cadastro de cardápio e preços | Cada produto recebido é cadastrado com código de barras próprio, e os pratos também existem no sistema. O cardápio tem categorias (lanches, pratos, porções, bebidas etc.). Cada reajuste de preço fica no histórico, com responsável e data. `[VALIDAR: quem cadastra e reajusta]` | Decisão de preço → cardápio atualizado | Gerência `[VALIDAR]` | PRODUTO, CATEGORIA, HISTORICO_PRODUTO, SETOR | confirmado na visita / proposta |

#### 2.2 Processos de Compras

| # | Processo | Descrição | Entrada → Saída | Responsável | Entidades | Origem |
|---|----------|-----------|-----------------|-------------|-----------|--------|
| PR8 | 🛒 Compra de insumos e bebidas | O proprietário compra produtos e insumos. Neste modelo, a compra passa a ser registrada com fornecedor, itens, quantidades e custo, a partir do alerta de estoque mínimo. | Alerta de estoque → compra registrada | Proprietário | COMPRA, PRODUTO (relacionamento possui) | confirmado na visita (quem compra) / proposta (registro) |
| PR9 | 🏭 Cadastro de fornecedores | O estabelecimento **não quis informar** os fornecedores. O modelo propõe cadastrá-los (nome, CNPJ, telefone), sem dados reais do Palazio. Só se compra de fornecedor cadastrado e ativo. | Dados do fornecedor → fornecedor ativo | Proprietário / gerência | FORNECEDOR | proposta (fornecedores reais não informados) |
| PR10 | 📦 Recebimento de mercadorias | O gerente recebe a mercadoria. Cada produto recebido é cadastrado com código de barras próprio. Neste modelo, o recebimento registra nota fiscal, quantidade e validade e gera a entrada no estoque. | Mercadoria + nota → entrada de estoque | Gerente | COMPRA, PRODUTO (possui), MOVIMENTACAO_ESTOQUE | confirmado na visita (quem recebe) / proposta (registro) |

#### 2.3 Processos de Apoio

| # | Processo | Descrição | Entrada → Saída | Responsável | Entidades | Origem |
|---|----------|-----------|-----------------|-------------|-----------|--------|
| PR11 | 📊 Controle de estoque e validade | Hoje, controlam o estoque de ingredientes, pratos prontos e bebidas, e os garçons conferem a validade uma vez por mês, retiram os itens a até 10 dias do vencimento e anotam em planilha. Neste modelo, toda venda, compra, estorno e ajuste (perda, vencimento) gera uma movimentação, e o saldo é a soma delas. Abaixo do mínimo, há alerta de reposição. | Evento de estoque → saldo atualizado e alerta | Garçons (validade) / gerência `[VALIDAR]` | PRODUTO, MOVIMENTACAO_ESTOQUE | confirmado na visita (validade) / proposta (movimentação) |
| PR12 | 🧑‍🍳 Cadastro de atendentes e escalas | Os funcionários são CLT, em escala 6x1 (seis dias de trabalho e um de folga), e hoje não têm credenciais individuais de gestão. Neste modelo, cada funcionário recebe cadastro com credencial, setor e perfil de acesso. Funcionário desligado é inativado, não excluído. A escala de folgas é rotina de RH e não está modelada nesta versão. | Contratação → atendente ativo com acesso | Gerência `[VALIDAR]` | ATENDENTE, SETOR | original / confirmado na visita (6x1) |
| PR13 | 💰 Caixa e fechamento diário | Antes de encerrar o expediente, o gerente confere os pagamentos, que ficam separados por forma (a maquininha gera a nota fiscal e o dinheiro também é lançado no aplicativo do local). No modelo, é uma consulta sobre os pagamentos do dia, sem entidade própria. | Pagamentos do dia → conferência do caixa | Gerente | PAGAMENTO, PEDIDO | confirmado (quem fecha e como confere) / proposta (consulta) |

#### 2.4 Como os processos se integram

- **Vendas → Estoque:** o lançamento de cada item (PR2) baixa o estoque (PR11). O cancelamento de um item pendente estorna a baixa.
- **Estoque → Compras:** o saldo no mínimo ou abaixo (PR11) dispara a compra (PR8) a um fornecedor cadastrado (PR9).
- **Compras → Estoque:** o recebimento (PR10) gera a entrada de estoque (PR11) e registra a validade dos perecíveis.
- **Cardápio → Vendas:** só produto ativo e com estoque entra em um pedido. O preço vigente (PR7) é copiado para o item (PR2).
- **Reservas → Vendas:** a reserva (PR6) garante a mesa; no dia, o atendimento abre o pedido (PR1) na mesma mesa.
- **Pessoas → todos:** nenhum processo ocorre sem atendente autenticado (PR12). Por isso cada pedido, compra e reajuste tem um responsável.
- **Vendas → Caixa:** os pagamentos (PR5) alimentam o fechamento diário (PR13).

#### 2.5 Fluxogramas

Clique na imagem para abrir em tamanho original (PNG; também há versão SVG na mesma pasta).

[![Fluxo 1 — Atendimento, pedido e pagamento](./Fluxograma_Palazio_del_Chef/fluxo_vendas.png)](./Fluxograma_Palazio_del_Chef/fluxo_vendas.png)

[![Fluxo 2 — Compras, recebimento e estoque](./Fluxograma_Palazio_del_Chef/fluxo_compras.png)](./Fluxograma_Palazio_del_Chef/fluxo_compras.png)

Fontes das imagens: [`fluxo_vendas.dot`](./Fluxograma_Palazio_del_Chef/fluxo_vendas.dot) e [`fluxo_compras.dot`](./Fluxograma_Palazio_del_Chef/fluxo_compras.dot) (Graphviz). Abaixo, os mesmos fluxos em Mermaid, que o GitHub renderiza.

**Fluxo 1 — Atendimento, pedido e pagamento (PR1 a PR5):**

```mermaid
flowchart TD
    A([Cliente chega]) --> B[Cliente é acomodado em uma mesa]
    B --> C[Atendente faz login com credencial]
    C --> D[Atendente abre pedido<br/>vinculado à mesa]
    D --> E[Atendente registra os itens]
    E --> F{Setor do produto}
    F -- Cozinha --> G[Cozinha recebe e prepara]
    F -- Bar --> H[Bar recebe e prepara]
    G --> I[Item pronto]
    H --> I
    I --> J[Atendente entrega na mesa]
    J --> K{Cliente pede<br/>mais algo?}
    K -- Sim --> E
    K -- Não --> L[Cliente solicita a conta]
    L --> M[Registro do pagamento<br/>em uma ou mais formas]
    M --> N[Pedido fechado<br/>Mesa livre]
    E -. baixa .-> O[(Estoque do produto)]
```

**Fluxo 2 — Compras, recebimento e estoque (PR8 a PR11):**

```mermaid
flowchart TD
    A[Venda baixa o estoque] --> B{Saldo no mínimo<br/>ou abaixo?}
    B -- Não --> A
    B -- Sim --> C[Alerta de reposição]
    C --> D[Gerência escolhe fornecedor<br/>cadastrado e ativo]
    D --> E[Registra a compra<br/>com itens e custo]
    E --> F[Mercadoria chega]
    F --> G{Nota, quantidade<br/>e validade conferem?}
    G -- Não --> H[Recusa ou ajusta a compra]
    G -- Sim --> I[Registra o recebimento]
    I --> J[Entrada no estoque<br/>movimentação do tipo compra]
    J --> A
```

---

### 3. ⚙️ Requisitos do Sistema

#### 3.1 Requisitos Funcionais

| Código | Requisito | Processo | Origem |
|--------|-----------|----------|--------|
| RF01 | O sistema deve permitir que o atendente registre um pedido de forma eficiente. | PR2 | original |
| RF02 | O sistema deve cadastrar atendentes com credenciais individuais (login e senha), setor e perfil de acesso. | PR12 | proposta (resolve o problema identificado) |
| RF03 | O sistema deve exigir autenticação do atendente antes de registrar ou alterar um pedido. | PR2 | proposta |
| RF04 | O sistema deve vincular cada pedido a uma mesa e ao atendente que o registrou. | PR1 | proposta (formaliza as regras originais) |
| RF05 | O sistema deve permitir adicionar itens a um pedido aberto, com quantidade e observação. | PR2 | proposta |
| RF06 | O sistema deve encaminhar cada item ao setor responsável pelo preparo (cozinha ou bar). | PR3 | proposta |
| RF07 | O sistema deve permitir que cozinha e bar atualizem o status dos itens (em preparo, pronto) e o atendente, o de entregue. | PR4 | proposta |
| RF08 | O sistema deve cadastrar produtos com código de barras, preço, setor de preparo e estoque mínimo. | PR7 | proposta |
| RF09 | O sistema deve atualizar o estoque a cada venda e alertar quando o saldo atingir o mínimo. | PR11 | proposta |
| RF10 | O sistema deve registrar o histórico de alterações de preço dos produtos, com responsável e data. | PR7 | proposta |
| RF11 | O sistema deve calcular o total do pedido e registrar um ou mais pagamentos, por forma de pagamento. | PR5 | proposta |
| RF12 | O sistema deve fechar o pedido somente após o pagamento integral e liberar a mesa. | PR5 | proposta |
| RF13 | O sistema deve emitir relatórios de vendas por período, por atendente, por setor e por produto. | PR5 | proposta |
| RF14 | O sistema deve permitir cancelar um item pendente ou um pedido, com estorno do estoque. | PR2 | proposta |
| RF15 | O sistema deve cadastrar, alterar e inativar fornecedores. | PR9 | proposta |
| RF16 | O sistema deve registrar compras a fornecedores, com os itens, as quantidades e o custo unitário. | PR8 | proposta |
| RF17 | O sistema deve registrar o recebimento da compra, com nota fiscal e validade, e dar entrada no estoque. | PR10 | proposta |
| RF18 | O sistema deve registrar ajustes de estoque (perda, quebra, vencimento) com motivo e responsável. | PR11 | proposta |
| RF19 | O sistema deve listar os produtos no estoque mínimo ou abaixo, para reposição. | PR11 | proposta |
| RF20 | O sistema deve apresentar o fechamento diário do caixa, com o total por forma de pagamento. | PR13 | proposta `[VALIDAR]` |
| RF21 | O sistema deve permitir inativar atendentes, produtos e mesas, sem apagar o histórico. | PR7, PR12 | proposta |
| RF22 | O sistema deve registrar reservas de mesa, com data, hora, quantidade de pessoas e o contato do cliente. | PR6 | confirmado na visita (existem reservas por telefone) |
| RF23 | O sistema deve agrupar os produtos em categorias do cardápio e marcar quais são bebidas alcoólicas. | PR7 | proposta (a partir do cardápio) |
| RF24 | O sistema deve calcular a taxa de serviço de 10% sobre os itens, quando cobrada, e incluí-la na conta. | PR5 | confirmado na visita |
| RF25 | O sistema deve bloquear o item cancelado também no setor de preparo. | PR3 | confirmado na visita |

#### 3.2 Requisitos Não Funcionais

| Código | Categoria | Requisito | Origem |
|--------|-----------|-----------|--------|
| RNF01 | Segurança | O sistema deve garantir que somente funcionários autorizados visualizem informações restritas do bar ou da cozinha. | original |
| RNF02 | Segurança | O sistema deve possuir controle de acesso por perfil (atendimento, preparo, gerência), garantindo confidencialidade conforme a permissão de cada usuário. | original |
| RNF03 | Segurança | As senhas devem ser armazenadas de forma criptografada (hash), nunca em texto puro. | proposta |
| RNF04 | Rastreabilidade | Toda ação relevante (pedido, item, pagamento, compra, ajuste de estoque, alteração de preço) deve registrar o atendente e a data e hora. | proposta |
| RNF05 | Integridade | Pedidos, itens, pagamentos e compras não podem ser excluídos fisicamente. A correção é feita por cancelamento ou inativação. | proposta |
| RNF06 | Usabilidade | O registro de pedidos deve ser rápido e utilizável em dispositivo móvel no salão. | proposta |
| RNF07 | Disponibilidade | O sistema deve estar disponível em todo o horário de funcionamento. | proposta |
| RNF08 | Desempenho | O lançamento de um item e a consulta da fila do setor devem responder em até 2 segundos em condições normais de uso. `[VALIDAR o limite]` | proposta |
| RNF09 | Consistência | O saldo de estoque e o total do pedido devem ser sempre coerentes com as movimentações e os itens (sem divergências). | proposta |
| RNF10 | Privacidade (LGPD) | O sistema deve guardar apenas os dados pessoais necessários e restringir o acesso a eles. Os logs de acesso devem ser mantidos. | proposta |
| RNF11 | Recuperação | Deve haver cópia de segurança diária do banco, com restauração testada. | proposta |
| RNF12 | Manutenibilidade | O modelo deve permitir novos setores, formas de pagamento e produtos sem alterar a estrutura das tabelas. | proposta |
| RNF13 | Integridade | Valores monetários devem ser armazenados em tipo numérico decimal apropriado, sem perda de precisão em preços e pagamentos. | proposta |

---

### 4. 📜 Regras de Negócio

#### 4.1 Regras operacionais

| Código | Processo | Regra | Origem |
|--------|----------|-------|--------|
| RN01 | Pedido | **Rastreabilidade de pedidos:** todo pedido deve estar obrigatoriamente associado a um atendente responsável pelo seu registro. | original |
| RN02 | Pedido | **Localização do cliente:** todo pedido deve estar vinculado a uma mesa. Não pode existir pedido sem número de mesa. | original |
| RN03 | Produto | **Identificação de produtos:** todo produto cadastrado deve possuir um código de barras, único no sistema. Cada produto recebido é cadastrado com código próprio, e os pratos também existem no sistema. | original / confirmado na visita |
| RN04 | Pedido | Somente atendente **ativo e autenticado** pode registrar pedidos. | proposta |
| RN05 | Pedido | Uma mesa só pode ter **um pedido aberto por vez**. | proposta |
| RN06 | Pedido | Cada item é encaminhado ao **setor de preparo do produto** (cozinha ou bar). | proposta |
| RN07 | Pedido | O **preço unitário é gravado no item** no momento do pedido. Reajustes não alteram pedidos anteriores. | proposta |
| RN08 | Pedido | Um item só pode ser adicionado se houver **estoque suficiente** do produto. Sem estoque, o sistema bloqueia o lançamento. | confirmado na visita |
| RN09 | Pedido | Um item pode ser **cancelado no sistema antes de ficar pronto**. O cancelamento bloqueia o item também no setor de preparo. | confirmado na visita |
| RN10 | Pedido | O pedido só pode ser **fechado** se estiver integralmente pago e sem itens pendentes ou em preparo. | proposta |
| RN11 | Pedido | O **total do pedido é calculado** (não é digitado): soma de quantidade × preço unitário dos itens não cancelados. | proposta |
| RN12 | Atendente | **Login único** por atendente. Cada atendente pertence a **um setor** e tem **um perfil** de acesso. | proposta |
| RN13 | Cadastros | Atendentes, produtos, mesas e fornecedores **não são excluídos**, apenas inativados, preservando o histórico. | proposta |
| RN14 | Pedido | **Produto indisponível não pode ser pedido:** produto inativo, ou sem estoque suficiente, é bloqueado no lançamento do item. | proposta |
| RN15 | Pagamento | **Formas de pagamento:** dinheiro, cartão (crédito e débito) e Pix, além das demais indicadas no cardápio. A conta pode ser **dividida** em vários pagamentos, e a soma deve igualar o total do pedido. `[VALIDAR: quais outras formas o cardápio indica]` | confirmado na visita |
| RN16 | Pagamento | **Taxa de serviço de 10%** sobre o valor dos itens, cobrada pelo estabelecimento e incluída na conta. O cliente pode pedir para **retirar** a taxa, se quiser. | confirmado na visita |
| RN17 | Pedido | **Perda após o preparo:** item pronto ou entregue não é cancelado. A perda é registrada pela gerência como ajuste de estoque, com motivo. `[VALIDAR]` | proposta |
| RN18 | Restrição legal | **Bebida alcoólica** só pode ser vendida a maiores de 18 anos. O garçom pede **documento com foto**. É política de atendimento, sem dados de cliente no sistema. | confirmado na visita |
| RN19 | Estoque | **Validade:** os garçons conferem a validade uma vez por mês e retiram os itens a até 10 dias do vencimento, anotando em planilha. No modelo, o item perecível registra a validade no recebimento, e o produto retirado sai do estoque por ajuste, com motivo. | confirmado na visita / proposta (registro) |
| RN20 | Estoque | **Estoque mínimo:** produto com saldo igual ou abaixo do mínimo entra na lista de reposição. | proposta |
| RN21 | Estoque | **Toda alteração do saldo** (venda, compra, estorno ou ajuste) gera uma movimentação. O saldo é a soma das movimentações. | proposta |
| RN22 | Compras | **Compra só de fornecedor cadastrado e ativo.** As compras são feitas pelo proprietário. Os fornecedores reais não foram informados pelo estabelecimento. | proposta / confirmado na visita (quem compra) |
| RN23 | Compras | O **recebimento** de uma compra gera a entrada de estoque de cada item. Quem recebe é o gerente. Compra recebida não pode ser alterada. | proposta / confirmado na visita (quem recebe) |
| RN24 | Cadastro | O **preço do produto só é alterado pela gerência**. Cada alteração grava o preço anterior, o novo, o responsável e a data. | proposta |
| RN25 | Caixa | O **fechamento diário** é feito pelo gerente e compara o total por forma de pagamento com o valor conferido em caixa. | confirmado (conferência antes de encerrar o expediente; dinheiro também lançado no aplicativo) / proposta (conferência por forma) |
| RN26 | Pedido | **Meia porção** custa **70%** do valor da porção inteira (regra do cardápio). | confirmado (cardápio) |
| RN27 | Produto | **Variações** de tamanho ou acompanhamento (1 ou 2 pessoas, com ou sem fritas) são produtos distintos, cada um com preço e código próprios. | proposta (a partir do cardápio) |
| RN28 | Reserva | Uma **reserva** é feita para uma mesa ativa, em uma data e hora, e guarda apenas o nome e o telefone do cliente. | proposta `[VALIDAR]` |
| RN29 | Produto | Todo produto pertence a **uma categoria** do cardápio (lanches, pratos, porções, bebidas etc.). Bebidas alcoólicas são marcadas, para a regra RN18. | proposta (a partir do cardápio) |
| RN30 | Estoque | **Insumos** (ingredientes) e produtos prontos têm estoque controlado, como as bebidas. O insumo não aparece no cardápio e não é pedido pelo cliente. Hoje a baixa dos insumos é **feita manualmente**; no modelo, é registrada como ajuste de consumo, com motivo. | confirmado (controlam ingredientes; baixa manual) / proposta (registro como ajuste) |
| RN31 | Pedido / Pagamento | **Validação de quantidades e valores:** a quantidade de um produto no pedido deve ser maior que zero. Preço do produto, preço unitário e valor pago não podem ser negativos. A data de pagamento só é preenchida quando o pagamento é realizado. | proposta (aplicada por CHECKs no SQL) |

#### 4.2 Restrições organizacionais

| Restrição | Por que importa para o modelo |
|-----------|-------------------------------|
| **Controle de acesso por setor e perfil (original):** informações do bar e da cozinha são restritas aos funcionários autorizados. | Por isso o atendente tem setor e perfil, e o acesso é por papel (seção 5.6). |
| **LGPD (Lei 13.709/2018):** dados pessoais de funcionários e de clientes que reservam mesa devem ser mínimos e com acesso restrito. | O modelo não guarda CPF, endereço nem telefone de funcionário. A senha é guardada em hash. A reserva guarda só nome e telefone do cliente. Os dados de fornecedores são de pessoa jurídica. |
| **Venda de bebida alcoólica:** proibida para menores de 18 anos (Estatuto da Criança e do Adolescente). O cardápio traz o aviso, e o garçom pede documento com foto. | É política de atendimento. O sistema não cadastra clientes, então não há atributo de idade. O produto tem um indicador de bebida alcoólica. |
| **Vigilância sanitária:** controle de validade e armazenamento de alimentos e bebidas. Hoje é feito uma vez por mês, em planilha (RN19). | Por isso o item de compra registra a data de validade e o estoque aceita ajuste por vencimento. |
| **Obrigação fiscal:** a venda exige nota fiscal. No Palazio, a nota vem pela maquininha de cartão, sem cupom no sistema. | A emissão está **fora do escopo** do banco. O modelo guarda o necessário para emitir (itens, valores, forma de pagamento, data e hora). |
| **Escopo desta versão:** delivery (o estabelecimento não realiza entregas), cadastro de clientes, folha de pagamento, escala de folgas 6x1 e ficha técnica (insumos por prato). | Ficam como evolução. A estrutura atual comporta essas extensões sem reestruturação (seção 8). |

---

### 5. 🗄️ Dicionário de Dados Conceitual (Preliminar)

> Segue o modelo do arquivo 02-03g da disciplina. A versão completa em HTML está em [`dicionario_dados_palazio/index.html`](./dicionario_dados_palazio/index.html).
> **Privacidade:** todos os exemplos de valores são **fictícios**.
> `[VALIDAR]` Os atributos são uma proposta. **Confira com o dicionário e o DER que o grupo já fez** e ajuste o que divergir.

#### 5.1 Modelo conceitual e cardinalidades

Este modelo representa um restaurante e bar em que o cliente, com ou sem **reserva**, é atendido em uma **mesa** (ou bistrô). Um **atendente** (o garçom) registra o **pedido**, que **contém** produtos (com quantidade, preço e status de preparo). Cada **produto** que pertence a uma **categoria** do cardápio e é preparado no **setor** (cozinha ou bar), e a conta é quitada por um ou mais **pagamentos**. O estoque dos produtos é reposto por **compras** a **fornecedores** e controlado por **movimentações**.

| Entidade | Relaciona-se com | Cardinalidade |
|----------|------------------|---------------|
| SETOR | ATENDENTE | 1:N — um setor tem vários funcionários; cada funcionário atua em um setor |
| SETOR | PRODUTO | 1:N — um setor (cozinha ou bar) prepara vários produtos; cada produto tem um setor de preparo |
| ATENDENTE | PEDIDO | 1:N — um atendente registra um ou vários pedidos (1,N); cada pedido tem exatamente um atendente (1,1), conforme orientação do professor |
| MESA | RESERVA | 1:N — uma mesa pode ser reservada várias vezes; cada reserva é de uma mesa |
| CATEGORIA | PRODUTO | 1:N — uma categoria do cardápio agrupa vários produtos; cada produto tem uma categoria |
| MESA | PEDIDO | 1:N — uma mesa recebe vários pedidos ao longo do tempo; cada pedido está em uma única mesa |
| PEDIDO × PRODUTO | **contém** (N:N, com atributos) | N:N — um pedido contém um ou mais produtos (1,N); um produto pode estar em vários pedidos (0,N). A quantidade, o preço unitário, o status de preparo, o horário e a observação são **atributos do relacionamento** (não há entidade Item_pedido, conforme orientação do professor) |
| PEDIDO | PAGAMENTO | 1:N — um pedido tem zero (aberto) ou vários pagamentos; cada pagamento quita um pedido |
| PRODUTO | HISTORICO_PRODUTO | 1:N — um produto tem várias alterações de preço registradas |
| ATENDENTE | HISTORICO_PRODUTO | 1:N — um atendente (gerência) registra várias alterações de preço |
| FORNECEDOR | COMPRA | 1:N — um fornecedor atende várias compras; cada compra é de um fornecedor |
| ATENDENTE | COMPRA | 1:N — um atendente (gerência) efetua várias compras; cada compra tem um responsável |
| COMPRA × PRODUTO | **possui** (N:N, com atributos) | N:N — uma compra possui um ou mais produtos (1,N); um produto pode estar em várias compras (0,N). Quantidade, custo unitário e validade são atributos do relacionamento |
| PRODUTO | MOVIMENTACAO_ESTOQUE | 1:N — um produto tem várias movimentações; cada movimentação é de um produto |
| PEDIDO | MOVIMENTACAO_ESTOQUE | 1:N opcional — um pedido gera baixas (e, se cancelado, estornos) (0,N); uma movimentação pode ou não ter origem em um pedido (0,1) |
| COMPRA | MOVIMENTACAO_ESTOQUE | 1:N opcional — uma compra recebida gera entradas (0,N); uma movimentação pode ou não ter origem em uma compra (0,1) |

**Definições.** **Setor** é a área de trabalho (salão, cozinha, bar, gerência, limpeza). **Categoria** é o grupo do cardápio (lanches, pratos, porções, sobremesas, bebidas etc.). **Reserva** é a mesa guardada por telefone, para uma data e hora. **Atendente** é o funcionário com credencial individual. **Mesa** é o local do cliente. **Produto** é o item vendido e estocado. **Pedido** é o atendimento de uma mesa. **Contém** é o relacionamento entre pedido e produto, com quantidade, preço unitário e status. **Pagamento** é a quitação, total ou parcial, do pedido. **Fornecedor** é a empresa que vende mercadoria. **Compra** é o pedido de mercadoria a um fornecedor. **Possui** é o relacionamento entre compra e produto, com quantidade, custo e validade. **Movimentação de estoque** é cada entrada, saída, estorno ou ajuste do saldo de um produto. **Histórico do produto** é o registro de cada alteração de preço.

#### 5.2 Fluxo de dados

O cliente reserva por telefone (RESERVA, ligada a uma MESA) ou entra e vê se há lugar → o atendente (autenticado em ATENDENTE) abre um PEDIDO em uma MESA → o PEDIDO contém PRODUTOS (relacionamento com quantidade, preço e status), e cada produto carrega a CATEGORIA do cardápio e o SETOR de preparo → cada produto lançado no pedido gera uma baixa em MOVIMENTACAO_ESTOQUE e atualiza o saldo do PRODUTO → cozinha e bar atualizam o status do item → o cliente paga e cada forma usada vira um registro em PAGAMENTO → com a soma dos pagamentos igual ao total, o PEDIDO é fechado e a MESA liberada. Quando o saldo do PRODUTO chega ao mínimo, a gerência registra uma COMPRA a um FORNECEDOR, com os produtos comprados → no recebimento, cada produto gera uma entrada em MOVIMENTACAO_ESTOQUE. Os reajustes de preço feitos pela gerência geram registros em HISTORICO_PRODUTO. Toda leitura ou escrita relevante é registrada no log do SGBD (seção 5.5), o que sustenta a auditoria e a conformidade com a LGPD (seção 5.6).

#### 5.3 Convenções do dicionário

- **SGBD de referência:** MySQL 8.0.
- **Codificação de caracteres:** UTF-8, para guardar acentuação do português sem perda em nomes e observações.
- **Prefixos:** `NM_` nome · `DT_` data · `DH_` data e hora · `ID_` identificador (não sofre operação matemática) · `QT_` quantidade · `VL_` valor monetário · `NR_` número · `TP_` tipo (categorização) · `IN_` indicador booleano · `DS_` descrição ou texto livre.
- **Notação formal:** `=` é composto de · `+` e (elementos obrigatórios) · `( )` opcional · `[ | ]` escolha obrigatória entre alternativas · `@` identificador (chave primária).
- **Chave estrangeira (FK):** aparece nos dicionários como atributo da entidade do lado N, com a indicação (FK). O **DER** não a desenha: no modelo conceitual a ligação é o relacionamento.
- **Versão deste dicionário:** v2.0, 07/10/2026. Qualquer alteração de estrutura gera nova revisão registrada aqui.

#### 5.4 Dicionário de dados por entidade

#### SETOR
`SETOR = @ID_SETOR + NM_SETOR + IN_PREPARO`

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_SETOR | integer | Sim (PK) | Identificador do setor. | — |
| NM_SETOR | varchar(30) | Sim | Nome do setor. Ex.: Salão, Cozinha, Bar, Gerência, Limpeza. | Único. |
| IN_PREPARO | boolean | Sim | Indica se o setor prepara produtos. | Verdadeiro para Cozinha e Bar; falso para Salão, Gerência e Limpeza. Só esses setores podem ser setor de preparo de um produto (RN06). |

Índices: PK ID_SETOR; índice único em NM_SETOR.

#### ATENDENTE
`ATENDENTE = @ID_ATENDENTE + ID_SETOR + NM_ATENDENTE + NM_LOGIN + DS_SENHA_HASH + TP_FUNCAO + TP_PERFIL + DT_ADMISSAO + IN_ATIVO`

*Leitura:* `TP_FUNCAO` exige escolher a função do funcionário: Garçom, Caixa, Cozinha, Bar, Gerente, Sócio ou Limpeza. `TP_PERFIL` exige escolher um perfil entre Atendimento (A), Preparo (P), Gerência (G) e Sócio (S). Todos os campos são obrigatórios. A equipe de limpeza só é cadastrada se precisar de acesso `[VALIDAR]`.

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_ATENDENTE | integer | Sim (PK) | Identifica individualmente cada atendente que registra pedidos. | Base da rastreabilidade (RN01). |
| ID_SETOR | integer | Sim (FK) | Setor em que o funcionário atua. | Define quais informações ele visualiza (RNF01). |
| NM_ATENDENTE | varchar(120) | Sim | Nome completo. Ex.: "Mariana Costa" (fictício). | — |
| NM_LOGIN | varchar(30) | Sim | Credencial de acesso. Ex.: "mariana.costa". | Único (RN12). |
| DS_SENHA_HASH | varchar(255) | Sim | Senha armazenada em hash. | Nunca em texto puro (RNF03). |
| TP_FUNCAO | varchar(10) (GARCOM, CAIXA, COZINHA, BAR, GERENTE, SOCIO, LIMPEZA) | Sim | Função do funcionário no estabelecimento, conforme orientação do professor de especificar a função de cada atendente. `[VALIDAR: se a lista de funções está completa]` | Define o trabalho, o setor e o perfil de acesso padrão. |
| TP_PERFIL | char(1) (A, P, G, S) | Sim | Perfil de acesso: Atendimento (garçom), Preparo (cozinha ou bar), Gerência ou Sócio (proprietário). | Define as permissões (RNF02). |
| DT_ADMISSAO | date | Sim | Data de admissão. | Não pode ser futura. |
| IN_ATIVO | boolean | Sim | Se o funcionário está ativo. | Inativo não registra pedidos e mantém o histórico (RN04, RN13). |

Índices: PK ID_ATENDENTE; índice único em NM_LOGIN (autenticação); índice em ID_SETOR.

#### MESA
`MESA = @ID_MESA + NR_MESA + TP_LOCAL + QT_LUGARES + TP_STATUS + IN_ATIVA`

*Leitura:* `TP_LOCAL` é Mesa (M) ou Bistrô (B). `TP_STATUS` é Livre (L) ou Ocupada (O).

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_MESA | integer | Sim (PK) | Identificador interno da mesa. | — |
| NR_MESA | smallint | Sim | Número da mesa, usado pelo atendente. Ex.: 12. | Único (RN02). |
| TP_LOCAL | char(1) (M, B) | Sim | Tipo de lugar: mesa ou bistrô. O salão tem cerca de 30 mesas e 25 bistrôs. | Domínio fechado. |
| QT_LUGARES | smallint | Sim | Quantidade de lugares. | Maior que zero. |
| TP_STATUS | char(1) (L, O) | Sim | Situação: Livre ou Ocupada. | Ocupada ao abrir o pedido, livre ao fechar (RN05, RN10). |
| IN_ATIVA | boolean | Sim | Se a mesa está em uso. | Mesa inativa não recebe pedidos (RN13). |

Índices: PK ID_MESA; índice único em NR_MESA.

#### PRODUTO
`PRODUTO = @ID_PRODUTO + ID_SETOR + ID_CATEGORIA + NM_PRODUTO + NR_CODIGO_BARRAS + VL_PRECO + IN_VENDAVEL + IN_ALCOOLICO + IN_CONTROLA_ESTOQUE + QT_ESTOQUE_ATUAL + QT_ESTOQUE_MINIMO + IN_ATIVO`

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_PRODUTO | integer | Sim (PK) | Identificador do produto. | — |
| ID_SETOR | integer | Sim (FK) | Setor responsável pelo preparo (Cozinha ou Bar). | Setor com IN_PREPARO verdadeiro (RN06). |
| ID_CATEGORIA | integer | Sim (FK) | Categoria do cardápio do produto. | Todo produto tem uma categoria (RN29). |
| NM_PRODUTO | varchar(80) | Sim | Nome no cardápio, com a variação de tamanho quando houver. Ex.: "Risoto de cogumelos", "Bife de contrafilé (2 pessoas)". | Variações são produtos distintos (RN27). |
| NR_CODIGO_BARRAS | varchar(14) | Sim | Código de barras. | Único (RN03). `[VALIDAR]` |
| VL_PRECO | decimal(8,2) | Sim | Preço de venda atual. | Maior que zero. Reajuste não altera pedidos antigos (RN07). Só a gerência altera (RN24). |
| IN_VENDAVEL | boolean | Sim | Verdadeiro para item do cardápio. Falso para insumo (ingrediente), que só tem estoque. | Só item vendável entra em pedido (RN14, RN30). |
| IN_ALCOOLICO | boolean | Sim | Indica bebida alcoólica. | Venda só para maiores de 18 anos, com conferência de documento (RN18). |
| IN_CONTROLA_ESTOQUE | boolean | Sim | Indica se o produto tem estoque controlado (bebidas, sobremesas prontas, insumos). Pratos, drinks e cafés preparados na hora não têm baixa por unidade. O controle do que chega ao local é feito especificamente pelos **garçons**. | Só produto com controle gera movimentação e entra em compra; quando falso, estoque atual e mínimo valem 0. `[VALIDAR]` atributo proposto na Entrega 2. |
| QT_ESTOQUE_ATUAL | integer | Sim | Quantidade disponível. | Não pode ser negativa (RN08). É a soma das movimentações (RN21). `[VALIDAR]` |
| QT_ESTOQUE_MINIMO | integer | Sim | Quantidade que dispara o alerta de reposição. | Alerta de reposição (RN20). |
| IN_ATIVO | boolean | Sim | Se o produto está no cardápio. | Inativo não pode ser pedido (RN13, RN14). |

Índices: PK ID_PRODUTO; índice único em NR_CODIGO_BARRAS; índice em ID_SETOR; índice em ID_CATEGORIA; índice em NM_PRODUTO (busca no lançamento do pedido).

#### HISTORICO_PRODUTO *(proposta de definição — o README original só citava o nome)*
`HISTORICO_PRODUTO = @ID_HISTORICO + ID_PRODUTO + ID_ATENDENTE + VL_PRECO_ANTERIOR + VL_PRECO_NOVO + DH_ALTERACAO`

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_HISTORICO | integer | Sim (PK) | Identificador do registro. | — |
| ID_PRODUTO | integer | Sim (FK) | Produto alterado. | — |
| ID_ATENDENTE | integer | Sim (FK) | Quem fez a alteração. | Perfil de Gerência (RN24). |
| VL_PRECO_ANTERIOR | decimal(8,2) | Sim | Preço antes da alteração. | — |
| VL_PRECO_NOVO | decimal(8,2) | Sim | Preço depois da alteração. | Maior que zero. |
| DH_ALTERACAO | timestamp | Sim | Data e hora da alteração. | Automática. |

Índices: PK ID_HISTORICO; índice em (ID_PRODUTO, DH_ALTERACAO).

#### PEDIDO
`PEDIDO = @ID_PEDIDO + ID_MESA + ID_ATENDENTE + DH_ABERTURA + (DH_FECHAMENTO) + IN_TAXA_SERVICO + TP_STATUS + (DS_OBSERVACAO)`

*Leitura:* `DH_FECHAMENTO` e `DS_OBSERVACAO` são opcionais. `TP_STATUS` é Aberto (A), Fechado (F) ou Cancelado (C).

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_PEDIDO | integer | Sim (PK) | Identificador do pedido. | — |
| ID_MESA | integer | Sim (FK) | Mesa do pedido. | Obrigatório: não existe pedido sem mesa (RN02). Uma mesa tem no máximo um pedido aberto (RN05). |
| ID_ATENDENTE | integer | Sim (FK) | Atendente que registrou o pedido. | Obrigatório e ativo (RN01, RN04). |
| DH_ABERTURA | timestamp | Sim | Data e hora de abertura. | Automática. |
| DH_FECHAMENTO | timestamp | Não | Data e hora de fechamento. | Obrigatória quando o status for Fechado (RN10). |
| IN_TAXA_SERVICO | boolean | Sim | Se a taxa de serviço de 10% foi cobrada neste pedido. | Padrão: verdadeiro. Falso quando o cliente pede para retirar a taxa (RN16). |
| TP_STATUS | char(1) (A, F, C) | Sim | Aberto, Fechado ou Cancelado. | Fecha só se estiver pago (RN10). |
| DS_OBSERVACAO | varchar(200) | Não | Observação geral. | — |

O **total do pedido não é atributo**: é derivado (RN11), assim como o valor da taxa de serviço (10% dos itens, RN16).

Índices: PK ID_PEDIDO; índice em ID_MESA; índice em ID_ATENDENTE; índice em DH_ABERTURA (relatórios por período); índice único parcial em ID_MESA para pedidos abertos (RN05).

#### Relacionamento CONTÉM *(PEDIDO × PRODUTO, N:N com atributos)*
`CONTÉM = ID_PEDIDO + ID_PRODUTO + QT_ITEM + VL_PRECO_UNITARIO + TP_STATUS + DH_REGISTRO + (DH_PRONTO) + (DS_OBSERVACAO)`

*Leitura:* `TP_STATUS` é Pendente (P), Em preparo (E), Pronto (R), Entregue (N) ou Cancelado (C).

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_PEDIDO | integer | Sim (ref.) | Pedido ao qual pertence (lado do relacionamento, não é chave estrangeira no DER). | Só em pedido aberto. |
| ID_PRODUTO | integer | Sim (ref.) | Produto pedido (lado do relacionamento). | Produto ativo e com estoque (RN08, RN13, RN14). |
| QT_ITEM | smallint | Sim | Quantidade pedida. | Maior que zero. |
| VL_PRECO_UNITARIO | decimal(8,2) | Sim | Preço unitário no momento do pedido. | Cópia do preço vigente (RN07). |
| TP_STATUS | char(1) (P, E, R, N, C) | Sim | Pendente, Em preparo, Pronto, Entregue ou Cancelado. | Cancela só se pendente (RN09, RN17). O setor do produto determina quem atualiza (RN06). |
| DH_REGISTRO | timestamp | Sim | Quando o item foi lançado. | Automática. |
| DH_PRONTO | timestamp | Não | Quando o item ficou pronto. | Preenchida quando o status passa a Pronto. Permite medir o tempo de preparo. |
| DS_OBSERVACAO | varchar(100) | Não | Observação do cliente. Ex.: "sem gelo". | — |

Índices e chave: definidos na modelagem lógica (Entrega 2). **Ponto a validar com o professor:** sem a entidade Item_pedido, o par (pedido, produto) não repete; se o mesmo produto for pedido duas vezes no mesmo pedido, a quantidade é somada e o status de preparo passa a ser por produto, não por lançamento.
#### CATEGORIA *(proposta, a partir do cardápio)*
`CATEGORIA = @ID_CATEGORIA + NM_CATEGORIA + IN_ATIVA`

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_CATEGORIA | integer | Sim (PK) | Identificador da categoria. | — |
| NM_CATEGORIA | varchar(40) | Sim | Nome do grupo do cardápio. Ex.: Lanches, Porções, Caipirinhas, Cervejas. | Único. |
| IN_ATIVA | boolean | Sim | Se a categoria está no cardápio. | Não se exclui (RN13). |

Índices: PK ID_CATEGORIA; índice único em NM_CATEGORIA.

#### RESERVA *(confirmada na visita; atributos propostos)*
`RESERVA = @ID_RESERVA + ID_MESA + NM_CLIENTE + (NR_TELEFONE) + DH_RESERVA + QT_PESSOAS + TP_STATUS`

*Leitura:* `TP_STATUS` é Ativa (A), Atendida (T) ou Cancelada (C). `NR_TELEFONE` é opcional.

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_RESERVA | integer | Sim (PK) | Identificador da reserva. | — |
| ID_MESA | integer | Sim (FK) | Mesa reservada. | Mesa ativa (RN28). |
| NM_CLIENTE | varchar(80) | Sim | Nome de quem reservou. Ex.: "Carlos Mendes" (fictício). | Dado pessoal mínimo (LGPD). |
| NR_TELEFONE | varchar(15) | Não | Telefone para confirmar. | Dado pessoal; acesso restrito (seção 5.6). |
| DH_RESERVA | timestamp | Sim | Data e hora para as quais a mesa foi reservada. | Futuro no momento do cadastro. |
| QT_PESSOAS | smallint | Sim | Quantidade de pessoas. | Maior que zero e não maior que os lugares da mesa. |
| TP_STATUS | char(1) (A, T, C) | Sim | Ativa, Atendida ou Cancelada. | Reserva não se exclui (RN13). |

Índices: PK ID_RESERVA; índice em (ID_MESA, DH_RESERVA).

#### PAGAMENTO *(proposta — o processo "Pagamento" não tinha entidade)*
`PAGAMENTO = @ID_PAGAMENTO + ID_PEDIDO + TP_FORMA + VL_PAGO + DH_PAGAMENTO`

*Leitura:* `TP_FORMA` é Dinheiro (D), Crédito (C), Débito (B) ou Pix (P).

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_PAGAMENTO | integer | Sim (PK) | Identificador do pagamento. | — |
| ID_PEDIDO | integer | Sim (FK) | Pedido quitado. | Um pedido pode ter vários pagamentos (RN15). |
| TP_FORMA | char(1) (D, C, B, P) | Sim | Dinheiro, crédito, débito ou Pix. | Domínio fechado (RN15). |
| VL_PAGO | decimal(8,2) | Sim | Valor pago nesta forma. | Maior que zero. A soma deve igualar o total (RN10, RN11). |
| DH_PAGAMENTO | timestamp | Sim | Data e hora do pagamento. | Automática. |

Índices: PK ID_PAGAMENTO; índice em ID_PEDIDO; índice em DH_PAGAMENTO (fechamento diário do caixa, RN25).

#### FORNECEDOR *(proposta)*
`FORNECEDOR = @ID_FORNECEDOR + NM_FORNECEDOR + NR_CNPJ + (NR_TELEFONE) + IN_ATIVO`

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_FORNECEDOR | integer | Sim (PK) | Identificador do fornecedor. | — |
| NM_FORNECEDOR | varchar(120) | Sim | Razão social ou nome fantasia. Ex.: "Distribuidora Aurora" (fictício). | — |
| NR_CNPJ | varchar(14) | Sim | CNPJ, só dígitos. Ex.: "00000000000191" (fictício). | Único. É pessoa jurídica, fora do escopo da LGPD. |
| NR_TELEFONE | varchar(15) | Não | Telefone comercial de contato. | — |
| IN_ATIVO | boolean | Sim | Se o fornecedor está ativo. | Só se compra de fornecedor ativo (RN22). Não se exclui (RN13). |

Índices: PK ID_FORNECEDOR; índice único em NR_CNPJ.

#### COMPRA *(proposta)*
`COMPRA = @ID_COMPRA + ID_FORNECEDOR + ID_ATENDENTE + DH_COMPRA + TP_STATUS + (NR_NOTA_FISCAL) + (DH_RECEBIMENTO)`

*Leitura:* `TP_STATUS` é Pedida (P), Recebida (R) ou Cancelada (C). `NR_NOTA_FISCAL` e `DH_RECEBIMENTO` são preenchidos no recebimento.

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_COMPRA | integer | Sim (PK) | Identificador da compra. | — |
| ID_FORNECEDOR | integer | Sim (FK) | Fornecedor da compra. | Cadastrado e ativo (RN22). |
| ID_ATENDENTE | integer | Sim (FK) | Quem registrou a compra. | Perfil de Gerência (RNF04). |
| DH_COMPRA | timestamp | Sim | Data e hora do registro. | Automática. |
| TP_STATUS | char(1) (P, R, C) | Sim | Pedida, Recebida ou Cancelada. | Compra recebida não é alterada (RN23). |
| NR_NOTA_FISCAL | varchar(20) | Não | Número da nota fiscal do fornecedor. | Obrigatório quando recebida. |
| DH_RECEBIMENTO | timestamp | Não | Data e hora do recebimento. | Preenchida quando a compra passa a Recebida. |

Índices: PK ID_COMPRA; índice em ID_FORNECEDOR; índice em DH_COMPRA.

#### Relacionamento POSSUI *(COMPRA × PRODUTO, N:N com atributos — proposta)*
`POSSUI = ID_COMPRA + ID_PRODUTO + QT_COMPRADA + VL_CUSTO_UNITARIO + (DT_VALIDADE)`

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_COMPRA | integer | Sim (ref.) | Compra a que pertence (lado do relacionamento). | — |
| ID_PRODUTO | integer | Sim (ref.) | Produto comprado (lado do relacionamento). | — |
| QT_COMPRADA | integer | Sim | Quantidade comprada. | Maior que zero. |
| VL_CUSTO_UNITARIO | decimal(8,2) | Sim | Custo de cada unidade nesta compra. | Maior que zero. |
| DT_VALIDADE | date | Não | Validade do lote recebido. | Obrigatória para perecíveis (RN19). |

Índices e chave: definidos na modelagem lógica (Entrega 2).
#### MOVIMENTACAO_ESTOQUE *(proposta)*
`MOVIMENTACAO_ESTOQUE = @ID_MOVIMENTACAO + ID_PRODUTO + (ID_PEDIDO) + (ID_COMPRA) + TP_MOVIMENTO + QT_MOVIMENTO + DH_MOVIMENTO + (DS_MOTIVO)`

*Leitura:* `TP_MOVIMENTO` é Venda (V), Compra (C), Estorno (E) ou Ajuste (A). `ID_PEDIDO` e `ID_COMPRA` são opcionais: preenchidos quando a movimentação vem de uma venda ou de uma compra.

| Atributo | Tipo | Obrig. | Descrição | Regra de negócio associada |
|----------|------|--------|-----------|----------------------------|
| ID_MOVIMENTACAO | integer | Sim (PK) | Identificador da movimentação. | — |
| ID_PRODUTO | integer | Sim (FK) | Produto movimentado. | — |
| ID_PEDIDO | integer | Não (FK) | Pedido de origem (venda ou estorno). | — |
| ID_COMPRA | integer | Não (FK) | Compra de origem (entrada). | — |
| TP_MOVIMENTO | char(1) (V, C, E, A) | Sim | Venda, Compra, Estorno ou Ajuste. | Domínio fechado. |
| QT_MOVIMENTO | integer | Sim | Quantidade com sinal: negativa para saída, positiva para entrada. | Diferente de zero. A soma por produto é o saldo (RN21). |
| DH_MOVIMENTO | timestamp | Sim | Data e hora. | Automática. |
| DS_MOTIVO | varchar(100) | Não | Motivo, obrigatório no ajuste. Ex.: "garrafa quebrada". | Ajuste exige motivo (RN17, RN19). |

Índices: PK ID_MOVIMENTACAO; índice em (ID_PRODUTO, DH_MOVIMENTO).

#### 5.5 Log de acesso (metadado operacional)

Todas as tabelas ficam sob o mesmo mecanismo de auditoria do SGBD. No MySQL, o log geral (`general_log`) ou o plugin de auditoria registram todo `INSERT`, `UPDATE` e `DELETE` no arquivo de log do servidor, com usuário e horário. A extensão `pgaudit` pode ser usada para registrar também as leituras (`SELECT`) das tabelas sensíveis. A retenção e a rotação do log seguem política própria, independente da retenção dos dados de negócio. `[VALIDAR com o grupo qual mecanismo será adotado na Entrega 2]`

#### 5.6 Acesso por operação e conformidade com a LGPD (metadado administrativo)

Papéis: **Atendimento**, **Preparo** (cozinha e bar), **Gerência** e **Auditoria**.

| Tabela | LER | INSERIR | ATUALIZAR | APAGAR |
|--------|-----|---------|-----------|--------|
| ATENDENTE | Gerência, Auditoria | Gerência | Gerência | Nenhum papel — só inativação |
| SETOR, MESA, CATEGORIA | Todos | Gerência | Gerência (mesa: também Atendimento, no status) | Nenhum papel — só inativação |
| RESERVA | Atendimento, Gerência, Auditoria | Atendimento, Gerência | Atendimento, Gerência (status) | Nenhum papel — só cancelamento |
| PRODUTO | Todos | Gerência | Gerência | Nenhum papel — só inativação |
| HISTORICO_PRODUTO | Gerência, Auditoria | Automático (gatilho) | Nenhum papel | Nenhum papel |
| PEDIDO | Atendimento, Gerência, Auditoria | Atendimento | Atendimento, Gerência | Nenhum papel — só cancelamento |
| CONTÉM (pedido × produto) | Atendimento, Preparo (do próprio setor), Gerência, Auditoria | Atendimento | Atendimento; Preparo (status do próprio setor) | Nenhum papel — só cancelamento |
| PAGAMENTO | Atendimento, Gerência, Auditoria | Atendimento | Nenhum papel — estorna-se e lança-se de novo | Nenhum papel |
| FORNECEDOR, COMPRA, POSSUI (compra × produto) | Gerência, Auditoria | Gerência | Gerência (compra recebida não se altera) | Nenhum papel — só inativação ou cancelamento |
| MOVIMENTACAO_ESTOQUE | Gerência, Auditoria | Automático (venda, compra, estorno); Gerência (ajuste) | Nenhum papel | Nenhum papel |

**LGPD.** Os dados pessoais do modelo são os do funcionário (ATENDENTE: nome, login e data de admissão) e os do cliente que reserva mesa (RESERVA: nome e telefone). Não são guardados CPF nem endereço, por minimização de dados (art. 6º, III). A reserva é apagada ou anonimizada depois de atendida ou cancelada, no prazo definido pelo estabelecimento. A senha é guardada em hash. O acesso é restrito aos papéis da tabela, e toda consulta fica no log (seção 5.5), o que sustenta a responsabilização (art. 6º, X). O modelo não tem dados sensíveis (art. 5º, II) e não cadastra clientes, exceto o nome e o telefone da reserva. FORNECEDOR guarda dados de pessoa jurídica, fora do escopo da lei. Os registros do estabelecimento são guardados por semestre (meses 1 a 6 e 7 a 12). `[VALIDAR com o contador o prazo fiscal de guarda]`. Funcionário desligado é inativado e, ao fim do prazo de retenção, o nome pode ser anonimizado, nunca apagado fisicamente, para preservar a integridade do histórico.

---

### 6. 🧠 Modelagem Conceitual (Entidades, Atributos, Relacionamentos)

- **Entidades reconhecidas:**

| Entidade | Justificativa | Origem |
|----------|---------------|--------|
| ATENDENTE | Funcionário com credencial individual, que resolve o problema identificado de controle e rastreabilidade. | original |
| MESA | Identifica o local do cliente e é o vínculo obrigatório do pedido. | original |
| PEDIDO | Registro central do atendimento. | original |
| PRODUTO | Itens vendidos, com código de barras e saldo de estoque. | original |
| SETOR | Define salão, cozinha e bar, tanto para a lotação do funcionário quanto para o encaminhamento do preparo. | original |
| HISTORICO_PRODUTO | Histórico de alterações de preço dos produtos. | original (nome) / proposta (definição) |
| PAGAMENTO | Registra a quitação do pedido, inclusive dividida em várias formas. Mapeia o processo PR5. | proposta |
| RESERVA | Registra a reserva de mesa por telefone, processo PR6 confirmado na visita. | proposta (processo confirmado) |
| CATEGORIA | Organiza o cardápio em grupos (lanches, pratos, porções, bebidas...), em vez de repetir o nome do grupo em cada produto. | proposta (a partir do cardápio) |
| MOVIMENTACAO_ESTOQUE | Dá entidade ao controle de estoque (PR11): cada entrada, venda, estorno ou ajuste fica registrado, e o saldo do produto pode ser auditado. | proposta |
| FORNECEDOR | Empresa de quem se compra. Mapeia o processo PR9. | proposta |
| COMPRA | Registro da reposição de mercadoria (PR8 e PR10). | proposta |

- **Atributos e classificações:** detalhados no dicionário (seção 5.4). Identificadores `ID_*`. Opcionais entre parênteses. Domínios fechados em `TP_*`. **Derivados (não armazenados):** total do pedido, taxa de serviço (10% dos itens) e fechamento do caixa. **Redundância deliberada:** `QT_ESTOQUE_ATUAL` em PRODUTO (saldo calculável pelas movimentações, guardado para consulta rápida e protegido pela regra RN21) e `VL_PRECO_UNITARIO` no relacionamento contém (RN07).

- **Relacionamentos pertinentes:** os 16 relacionamentos e suas cardinalidades estão na tabela da seção 5.1 e no DER (seção 7). Os N:N são **contém** (PEDIDO × PRODUTO) e **possui** (COMPRA × PRODUTO), ambos com atributos próprios e sem entidade associativa, conforme a orientação do professor de remover Item_pedido.

- **Restrições e políticas aplicadas ao modelo:** pedido sempre com mesa e atendente (RN01, RN02); uma mesa com um pedido aberto (RN05); acesso por setor e perfil (RNF01, RNF02); preço copiado no item (RN07); inativação em vez de exclusão (RN13); toda alteração de estoque vira movimentação (RN21); compra só de fornecedor ativo (RN22).

---

### 7. 🔗 Diagrama Entidade-Relacionamento (DER)

O DER abaixo foi desenhado na notação de Chen (retângulo, losango e círculo), a partir do dicionário. Ele **amplia o DER anterior do grupo** (veja a comparação mais abaixo) com as entidades marcadas como proposta. O DER **não mostra chaves estrangeiras**: a ligação entre entidades é feita pelo relacionamento, com a cardinalidade (mín,máx) nos dois lados.

<p align="center">
  <img src="./Diagrama_Palazio_del_Chef/diagrama_palazio_del_chef.png" alt="Diagrama Entidade-Relacionamento do Palazio del Chef" width="900">
</p>

> [Ver Diagrama](./Diagrama_Palazio_del_Chef/) · [abrir a imagem em tamanho original](./Diagrama_Palazio_del_Chef/diagrama_palazio_del_chef.png)

#### 7.1 DER anterior do grupo (BRModelo, 22/09/2026)

[![DER anterior do grupo no BRModelo](./Diagrama_Palazio_del_Chef/der_grupo_brmodelo_22-09-2026.jpg)](./Diagrama_Palazio_del_Chef/der_grupo_brmodelo_22-09-2026.jpg)

Este foi o DER feito pelo grupo no BRModelo Web, antes das orientações do professor. A versão atual parte dele e muda o seguinte:

| DER anterior do grupo | DER atual | Motivo |
|-----------------------|-----------|--------|
| Atendente (0,n) registra Pedido (1,1) | Atendente **(1,N)** registra Pedido (1,1) | Orientação do professor |
| Entidade Item_pedido (Pedido possui Item_pedido; Produto referente) | **Removida**: "contém" é N:N entre Pedido e Produto, com quantidade, preço unitário, status, horários e observação | Orientação do professor |
| Atendente só com nome e id | Atendente com **função** (`TP_FUNCAO`), login, perfil, setor e situação | Orientação do professor (especificar a função) e problema de credenciais |
| `preço_atual` e `preço_unitario` | `VL_PRECO` e `VL_PRECO_UNITARIO` (preço) | Orientação do professor (valor → preço) |
| Sem histórico de preço | Entidade **Histórico_Produto** | Orientação do professor |
| `forma_pagamento` e `Nmr_mesa` como atributos do Pedido | Entidades **Pagamento** (várias formas por pedido) e **Mesa** ligada ao Pedido | Pagamento dividido e mesa com dados próprios (proposta) |
| Produto com `Nmr_setor` | Relacionamento Setor prepara Produto | Evita repetir o setor no produto |
| Sem reserva, categoria, compra, fornecedor e estoque | **Reserva, Categoria, Compra, Fornecedor, Movimentação de estoque** | Processos relatados na visita (proposta de modelagem) |

Versão de apoio em Mermaid:

```mermaid
erDiagram
    SETOR ||--o{ ATENDENTE : "agrupa"
    SETOR ||--o{ PRODUTO : "prepara"
    ATENDENTE ||--|{ PEDIDO : "registra"
    MESA ||--o{ PEDIDO : "recebe"
    PEDIDO }|--o{ PRODUTO : "contém (QT_ITEM, VL_PRECO_UNITARIO, TP_STATUS, DH_REGISTRO, DH_PRONTO, DS_OBSERVACAO)"
    PEDIDO ||--o{ PAGAMENTO : "é quitado por"
    PRODUTO ||--o{ HISTORICO_PRODUTO : "tem"
    ATENDENTE ||--o{ HISTORICO_PRODUTO : "realiza"
    FORNECEDOR ||--o{ COMPRA : "fornece"
    ATENDENTE ||--o{ COMPRA : "efetua"
    COMPRA }|--o{ PRODUTO : "possui (QT_COMPRADA, VL_CUSTO_UNITARIO, DT_VALIDADE)"
    PRODUTO ||--o{ MOVIMENTACAO_ESTOQUE : "sofre"
    PEDIDO |o--o{ MOVIMENTACAO_ESTOQUE : "gera"
    COMPRA |o--o{ MOVIMENTACAO_ESTOQUE : "gera"
    MESA ||--o{ RESERVA : "recebe reserva"
    CATEGORIA ||--o{ PRODUTO : "classifica"

    SETOR {
        int ID_SETOR PK
        string NM_SETOR
        boolean IN_PREPARO
    }
    ATENDENTE {
        int ID_ATENDENTE PK
        string NM_ATENDENTE
        string NM_LOGIN
        string DS_SENHA_HASH
        string TP_FUNCAO
        char TP_PERFIL
        date DT_ADMISSAO
        boolean IN_ATIVO
    }
    MESA {
        int ID_MESA PK
        int NR_MESA
        char TP_LOCAL
        int QT_LUGARES
        char TP_STATUS
        boolean IN_ATIVA
    }
    PRODUTO {
        int ID_PRODUTO PK
        string NM_PRODUTO
        string NR_CODIGO_BARRAS
        decimal VL_PRECO
        boolean IN_VENDAVEL
        boolean IN_ALCOOLICO
        boolean IN_CONTROLA_ESTOQUE
        int QT_ESTOQUE_ATUAL
        int QT_ESTOQUE_MINIMO
        boolean IN_ATIVO
    }
    HISTORICO_PRODUTO {
        int ID_HISTORICO PK
        decimal VL_PRECO_ANTERIOR
        decimal VL_PRECO_NOVO
        timestamp DH_ALTERACAO
    }
    PEDIDO {
        int ID_PEDIDO PK
        timestamp DH_ABERTURA
        timestamp DH_FECHAMENTO
        boolean IN_TAXA_SERVICO
        char TP_STATUS
        string DS_OBSERVACAO
    }
    CATEGORIA {
        int ID_CATEGORIA PK
        string NM_CATEGORIA
        boolean IN_ATIVA
    }
    RESERVA {
        int ID_RESERVA PK
        string NM_CLIENTE
        string NR_TELEFONE
        timestamp DH_RESERVA
        int QT_PESSOAS
        char TP_STATUS
    }
    PAGAMENTO {
        int ID_PAGAMENTO PK
        char TP_FORMA
        decimal VL_PAGO
        timestamp DH_PAGAMENTO
    }
    FORNECEDOR {
        int ID_FORNECEDOR PK
        string NM_FORNECEDOR
        string NR_CNPJ
        string NR_TELEFONE
        boolean IN_ATIVO
    }
    COMPRA {
        int ID_COMPRA PK
        timestamp DH_COMPRA
        string NR_NOTA_FISCAL
        char TP_STATUS
        timestamp DH_RECEBIMENTO
    }
    MOVIMENTACAO_ESTOQUE {
        int ID_MOVIMENTACAO PK
        char TP_MOVIMENTO
        int QT_MOVIMENTO
        timestamp DH_MOVIMENTO
        string DS_MOTIVO
    }
```

**Legenda:** `||` exatamente um · `|o` zero ou um · `o{` zero ou muitos · `|{` um ou muitos.

---

### 8. 🧾 Justificativa Técnica

- **Entidade ATENDENTE com credencial e função:** a função de cada funcionário (garçom, caixa, cozinha, bar, gerente, sócio, limpeza) é um atributo explícito, conforme orientou o professor. O perfil de acesso é separado da função, pois várias funções podem ter o mesmo acesso. A cardinalidade (1,N) do atendente no relacionamento "registra" também segue a orientação do professor. A solução resolve diretamente o problema identificado. Como a equipe não era registrada, não havia como saber quem registrou cada pedido. Com `ID_ATENDENTE` e login individual, cada pedido passa a ter um responsável (RN01), o que dá rastreabilidade e responsabilização. O modelo guarda **senha em hash** e apenas os dados pessoais necessários, por minimização de dados (LGPD). A alternativa, um campo de texto com o nome do garçom no pedido, permitiria grafias diferentes e não daria controle de acesso.
- **SETOR como entidade:** serve a dois fins do mesmo conceito: lotação do funcionário (quem vê o quê, RNF01) e destino do preparo do produto (cozinha ou bar). Como atributo de texto, o nome do setor se repetiria e permitiria grafias diferentes ("Bar", "bar", "BAR"). Como entidade, centraliza o dado e permite novos setores sem alterar a estrutura.
- **MESA como entidade e vínculo obrigatório:** reflete a regra original de que todo pedido pertence a uma mesa (RN02) e permite o controle de ocupação (RN05). A cardinalidade (0,N) para a mesa e (1,1) para o pedido diz que uma mesa pode ficar sem pedido, mas todo pedido tem exatamente uma mesa.
- **Sem a entidade Item_pedido (orientação do professor):** o N:N entre pedido e produto é o relacionamento **contém**, que guarda quantidade, preço unitário, status de preparo, horários e observação. **Limitação a validar com o professor:** sem chave própria, o mesmo produto não aparece duas vezes no mesmo pedido (a quantidade é somada) e o status de preparo é por produto, não por lançamento. Na modelagem lógica (Entrega 2) o relacionamento vira uma tabela; se for necessário, decidir lá entre chave composta (pedido, produto) ou chave própria.
- **Preço copiado no item e total derivado:** sem copiar o preço, reajustar o cardápio alteraria vendas passadas (RN07). Guardar o total no pedido criaria risco de inconsistência com os itens (RN11).
- **PRODUTO com código de barras único:** atende à regra original e facilita o registro e o controle de estoque (RN03). A pendência de validar se vale para pratos feitos na casa está registrada na regra.
- **PAGAMENTO como entidade, e não como atributo do pedido:** o DER anterior tinha só a forma de pagamento como atributo de PEDIDO. Isso impede registrar a conta dividida (por exemplo, metade em Pix e metade no cartão) e o fechamento por forma de pagamento. Como entidade (1:N com o pedido), cada pagamento tem forma, valor e horário próprios.
- **Estoque com entidade própria (MOVIMENTACAO_ESTOQUE):** só um campo de saldo em PRODUTO não diz de onde veio a quantidade nem permite achar uma divergência. Cada entrada, venda, estorno e ajuste vira um registro, e o saldo é a soma das movimentações (RN21). O saldo fica também em PRODUTO como redundância deliberada, para consulta rápida e alerta de reposição. A regra RN21 mantém os dois coerentes. A opção de modelar também **insumos** (ingredientes de cada prato, com ficha técnica) foi deixada como evolução, pois exige uma tabela de composição por prato `[VALIDAR: a cozinha controla estoque de ingredientes ou só de produtos prontos e bebidas?]`.
- **FORNECEDOR e COMPRA:** o processo de reposição (PR8 a PR10) é a origem das entradas de estoque. COMPRA guarda fornecedor, data, nota e responsável; o relacionamento **possui** (COMPRA × PRODUTO) guarda quantidade, custo e validade de cada lote, o que atende à vigilância sanitária (RN19) e permite calcular o custo e a margem dos produtos.
- **Fechamento de caixa sem entidade própria:** o fechamento diário (PR13) é um total dos pagamentos do dia por forma. Guardá-lo em tabela duplicaria dado já existente em PAGAMENTO. Fica como consulta.
- **RESERVA como entidade:** a visita confirmou que o cliente reserva mesa por telefone. A reserva tem data, hora, quantidade de pessoas e contato, e muda de situação (ativa, atendida, cancelada). Guardá-la como atributo da mesa não permitiria várias reservas da mesma mesa em dias diferentes. O cadastro do cliente é mínimo (nome e telefone) por causa da LGPD. A reserva não é ligada ao pedido, porque nem todo pedido tem reserva.
- **CATEGORIA como entidade:** o cardápio tem mais de 260 preços em cerca de 45 grupos. Repetir o nome do grupo em cada produto permitiria grafias diferentes e dificultaria relatórios por categoria. Como entidade, o grupo é cadastrado uma vez. As variações de tamanho (1 ou 2 pessoas, com ou sem fritas) são produtos distintos, cada um com preço e código próprio, porque são vendidos e estocados separadamente.
- **Taxa de serviço e bebida alcoólica no modelo:** a taxa de 10% é derivada dos itens e só precisa de um indicador no pedido (`IN_TAXA_SERVICO`), pois o valor se calcula. O indicador `IN_ALCOOLICO` no produto sustenta a regra de conferência de documento e permite relatórios de venda de bebida alcoólica.
- **Escala 6x1 fora do modelo:** a escala de folgas dos funcionários CLT é rotina de RH e não influencia pedidos, estoque ou compras. Modelá-la ampliaria o escopo sem ganho para os processos mapeados. Fica como evolução.
- **HISTORICO_PRODUTO:** dá rastreabilidade às mudanças de preço e responsabiliza a gerência (RN24).
- **Sem chaves estrangeiras no DER:** no modelo conceitual, a ligação entre entidades é o relacionamento. As chaves estrangeiras surgem na conversão para o modelo lógico (Entrega 2).
- **Escalabilidade e integração:** o modelo comporta, sem reestruturação, cadastro de clientes e fidelidade, múltiplas unidades, delivery (o estabelecimento hoje não faz entregas), ficha técnica de pratos, escala de folgas e nota fiscal. A estrutura de pedido, item e pagamento sustenta indicadores de BI (ticket médio, produtos mais vendidos, desempenho por atendente e por setor, tempo de preparo), e as movimentações sustentam análises de giro e perdas de estoque.

---

### 9. 🤖 Uso de Inteligência Artificial

> **As informações do estabelecimento vêm da visita do grupo. O que a IA propôs está marcado como `(proposta)` e deve ser revisado pelo grupo.** A disciplina exige o registro **de cada uso relevante**, com o que foi verificado e o que foi corrigido.

| Item | Registro |
|------|----------|
| **Ferramenta e etapa** | **(1) ChatGPT (OpenAI):** ferramenta de apoio na organização da documentação, na estruturação do README, na revisão do texto, na melhoria da clareza e na padronização, usando as informações e as orientações do professor que o grupo já tinha. **(2) Claude (Anthropic):** reorganização do README no formato do esqueleto da Entrega 1, proposta de requisitos, regras, atributos, relacionamentos, justificativas e do DER, incorporação dos dados da visita e ajustes conforme o parecer do professor. |
| **Motivação** | Organizar e padronizar a documentação segundo o esqueleto da disciplina, informar o uso de IA como o professor pediu e corrigir os pontos apontados no parecer do professor. (rascunho; o grupo confirma) |
| **Prompt(s) utilizados** | **ChatGPT:** 24 prompts do grupo, a partir do pedido "me explica sobre o trabalho do semestre" (19/08/2026) até o prompt final da Entrega 1 (16/09/2026), listados um a um na tabela **"Prompts no ChatGPT"** abaixo. O texto integral do prompt de revisão da Entrega 1 está em [`evidencias/prompt_chatgpt.md`](./evidencias/prompt_chatgpt.md) (conversa: [chatgpt.com/share/6ac6b6d5-d03c-83e9-8cb3-1928b9067b78](https://chatgpt.com/share/6ac6b6d5-d03c-83e9-8cb3-1928b9067b78)). **Claude:** todos os usos estão na tabela **"Usos do Claude"**, que inclui a Entrega 2. |
| **Resposta recebida** | **ChatGPT:** explicação do trabalho semestral, sugestões de tipo de organização e de SGBD (PostgreSQL), README em Markdown para o GitHub (várias versões), 15 comentários de melhoria, orientações para aplicar as alterações do professor no DER, seção de uso de IA e prompts-resumo da Entrega 1 (resumo de cada resposta na tabela abaixo). **Claude:** README reorganizado em 9 seções, mantendo o conteúdo original e marcando o que foi proposto; 13 processos, requisitos, regras de negócio, dicionário no modelo da disciplina, DER sem chaves estrangeiras, fluxogramas, e na Entrega 2 o modelo lógico, os scripts SQL, a massa de dados e o relatório técnico. |
| **Fontes consultadas e verificadas** | Visita ao estabelecimento em 04/09/2026 (respostas às perguntas do roteiro), cardápio, horário no Google Maps, foto da fachada, parecer e orientações do professor, esqueleto da Entrega 1 e exemplo de dicionário (02-03g) da disciplina, e o DER anterior do grupo no BRModelo. **O grupo conferiu a estrutura do DER indicada pelo professor, analisando juntos os links importantes disponibilizados no Blackboard.** A IA não teve acesso ao estabelecimento. |
| **Trechos rejeitados ou corrigidos** | O grupo usou a IA para **remover tudo o que havia colocado de errado** no modelo, conforme as orientações do professor: Funcionário → Atendente com função, Valor → Preço, Item_pedido removido (virou o relacionamento "contém"), Atendente (1,N) e inclusão de Histórico_Produto. Mantidos apenas dados reais da visita; o que a IA propôs sem confirmação ficou marcado como proposta. Fornecedores reais não foram informados pelo estabelecimento, então o modelo só prevê o cadastro. |
| **Justificativa da escolha final** | A escolha final foi baseada na **facilidade** de entender e manter o modelo e em ele ser **completo**: com 12 entidades, cobre os processos relatados na visita (atendimento, reserva, pedido por mesa, pagamento, compras, estoque) e resolve o problema de rastreabilidade com a entidade Atendente. O N:N entre pedido e produto segue a orientação do professor. |
| **Reflexão crítica** | **Rascunho para o grupo revisar e assumir:** a IA acelerou a organização e a padronização do README, mas propôs atributos, regras e entidades sem ver o estabelecimento nem o DER do grupo, e por isso tudo precisou ser comparado com a visita e com as orientações do professor. A remoção do Item_pedido mostrou o limite do modelo: o mesmo produto não repete no pedido e o status de preparo fica por produto, ponto a confirmar com o professor. Regras como código de barras para pratos, taxa de serviço e validade vieram da visita; as de compra e de fornecedor são propostas. `[PREENCHER: o grupo deve reescrever com suas palavras]` |

#### Prompts no ChatGPT (OpenAI)

Registro dos prompts do grupo (conversa exportada em PDF, 124 páginas, a partir do pedido de explicação do trabalho do semestre). Os textos estão resumidos; o grupo guarda a conversa completa. Datas conforme a exportação; onde não há data, o prompt está entre as datas vizinhas.

| # | Data | Prompt do grupo | O que o ChatGPT devolveu | Como foi usado |
|---|------|-----------------|--------------------------|----------------|
| 1 | 19/08 | "me explica sobre o trabalho do semestre" | Explicou as etapas do trabalho semestral (organização real, levantamento, DER, modelo lógico, SQL, BI/IA) e estimou dificuldade 8/10. | Entendimento das entregas. |
| 2 | 19/08 | "me indica empresas/ong que eu poderia criar esses bancos" | Lista de tipos de organização (pet shop, academia etc.) e dicas de escolha. | Ajudou a decidir o segmento; a empresa real foi escolhida pelo grupo. |
| 3 | 19/08 | "se for restaurante, indica nomes" | Perfis de restaurante de bairro/médio porte e exemplos de nomes. | Apoio na escolha; o grupo usou o Palazio del Chef. |
| 4 | 19/08 | "o professor queria que fosse algo de porte médio" | Critérios de um restaurante de porte médio (salão, estoque, fornecedores, pagamentos). | Critérios conferidos na visita. |
| 5 | 19/08 | "precisa ser uma empresa, que não tenha banco de dados" | Perfil de empresa que controla tudo em planilhas, cadernos e WhatsApp. | Reforçou o problema da rastreabilidade. |
| 6 | 19/08 | "me ajuda indica um banco de dados gratuito e bom para usar" | Recomendou PostgreSQL. | SGBD adotado. |
| 7 | 19/08 a 15/09 | "Simula pra mim, como se fosse aqui no condominio..." | Mini-projeto de treino (torres, unidades, moradores) para praticar entidades, PK e FK. | Só estudo; não entra no projeto. |
| 8 | 19/08 a 15/09 | Envio do ZIP da aula | Mapa dos materiais (modelos, BRModelo, entregas 1 e 2). | Referência de estudo. |
| 9 | 19/08 a 15/09 | "o que tenho que fazer na entrega 1?" | Lista da Entrega 1; avisou que não conseguiu ler o esqueleto oficial e não inventou exigências. | Roteiro inicial, conferido depois no esqueleto. |
| 10 | 15/09 | Documentação do grupo anexada: "estrutura um readme para eu colocar no github" | Primeiro README do GitHub; recomendou deixar como "estrutura inicial". | Base do README. |
| 11 | 15/09 | Texto da documentação colado, pedindo para organizar os pontos | README reorganizado, com dicionário por entidade. | Organização do texto do grupo. |
| 12 | 15/09 | "organiza para mim esses pontos" | Versão mais limpa; sugeriu não renomear campos antes do DER. | Texto revisado. |
| 13 | 15/09 | "faça tudo de uma vez para eu copiar e colar" | README completo em um bloco. | Colado no GitHub. |
| 14 | 15/09 | Nome dos integrantes | Seção "Integrantes" e renumeração das seções. | Incluído. |
| 15 | 15/09 | "me manda 15 comentários de melhorias para meu amigo nesse readme" | 15 comentários (integrantes, problema específico, cardinalidades, normalização, status). | Enviados ao colega. |
| 16 | 15/09 | README atualizado colado | Revisão; alertou para não marcar como concluídas as etapas ainda não feitas. | Status ajustado. |
| 17 | 16/09 | Diagrama do grupo + alterações do professor (Funcionário → Atendente, Valor → Preço, Item_pedido removido, Atendente 1,N, Histórico_Produto) | Tabela do que mudar no DER e na estrutura Pedido–Produto. | Base para refazer o DER. |
| 18 | 16/09 | README atualizado colado | Revisão alinhada às alterações do professor. | Texto revisado. |
| 19 | 16/09 | "faça uma versão para eu só copiar e colar" | README completo. | Colado no GitHub. |
| 20 | 16/09 | "quero que especifica em alguma área que foi usado o chatgpt para desenvolver o readme, o professor pediu que informasse isso" | Seção "Uso de Inteligência Artificial". | Origem desta seção 9. |
| 21 | 16/09 | "faça uma versão copia e cola com essas alterações" | README final com a seção de IA e instrução da pasta `docs`. | Colado no GitHub. |
| 22 | 16/09 | "me explica resumidamente o que eu alterei no readme, para eu mandar no whats pro meu grupo ver" | Resumo das alterações em tópicos. | Enviado ao grupo. |
| 23 | 16/09 | "me faça um prompt de tudo que eu pedi da entrega 1" | Prompt completo para outra IA. | Registrado em `evidencias/prompt_chatgpt.md`. |
| 24 | 16/09 | "resume" | Versão curta do prompt. | Registrado no mesmo arquivo. |

Pontos de atenção sobre o ChatGPT: as respostas não vieram da visita ao estabelecimento, então tudo foi conferido com a visita e com o parecer do professor; a indicação de empresas e nomes foi só inspiração; o README gerado nas etapas 10 a 13 ainda usava o modelo antigo (com Item_pedido), corrigido nas etapas 17 a 21 e depois pelo Claude.

#### Usos do Claude (Anthropic)

| # | Uso | O que o grupo pediu / forneceu | O que o Claude entregou |
|---|-----|-------------------------------|-------------------------|
| 1 | Material da disciplina | Envio do material da aula (esqueleto da Entrega 1 e modelo de dicionário 02-03g). | Leitura do esqueleto e do modelo, usados como referência de formato. |
| 2 | Simulação de entrega | Pedido de uma simulação de Entrega 1 com uma lanchonete fictícia, apenas como exemplo do formato. | Exemplo de estrutura (não usado como conteúdo do Palazio). |
| 3 | Reorganização do README | README do grupo anexado, com o pedido "organize e faça um nosso". | README reorganizado nas seções do esqueleto. |
| 4 | Revisão da Entrega 1 | Perguntas sobre o que faltou e uma estimativa de nota (0 a 2,5). | Lista de pendências e estimativa, usadas só como orientação. |
| 5 | Organização do repositório | Pedido para arrumar o GitHub (`modelagem-dados`) pasta por pasta. | Estrutura de pastas, `LEIA-ME`, roteiro de entrevista e commits. |
| 6 | Correção pelo parecer | Parecer do professor anexado (critérios 1 a 12). | Conferência do que já existia e inclusão do que faltava. |
| 7 | Dados da visita | Endereço, contato, data, porte, respostas às 24 perguntas, cardápio, fotos, horário, reserva, Instagram, taxa de serviço, link do Maps e RGMs. | Incorporação no README (caracterização, 13 processos, requisitos e regras). |
| 8 | Requisitos, regras e dicionário | Pedido de requisitos, regras e dicionário no modelo 02-03g. | RF, RNF, RN e dicionário com 12 entidades, cardinalidades, fluxo, log e LGPD. |
| 9 | DER | Pedido de um DER; depois, as orientações do professor (Atendente, função, Preço, Histórico_Produto, Atendente (1,N), remover Item_pedido). | DER em imagem na notação de Chen, gerado por script (`Diagrama_Palazio_del_Chef/gerar_der.py`). |
| 10 | Justificativa técnica | Pedido de justificar as escolhas. | Texto da seção 8, com a limitação apontada pela remoção do Item_pedido. |
| 11 | Entrega 2 (primeiro rascunho) | Pedido de modelo lógico e SQL. | Rascunho no modelo antigo (14 entidades), substituído depois. |
| 12 | Conferência do caixa, fornecedores e insumos | Respostas do estabelecimento: a nota é gerada na maquininha, o caixa é conferido antes de encerrar o expediente e o dinheiro também é lançado no aplicativo; fornecedores não informados; baixa de insumos manual. | Atualização do README, das regras e do dicionário com essas respostas. |
| 13 | DER anterior do grupo | Imagem do DER feito no BRModelo (22/09). | Tabela comparando o DER do grupo com o novo (Funcionário → Atendente, Item_pedido, Histórico_Produto etc.). |
| 14 | Fluxogramas | Pedido de fluxogramas clicáveis a partir do README. | Fluxogramas de vendas e de compras em Graphviz (`Fluxograma_Palazio_del_Chef/`). |
| 15 | Seção de uso de IA | Pedido para acrescentar o que foi feito com o Claude e rascunhos curtos de cada campo. | Tabela "Usos do Claude" e rascunhos marcados para o grupo assumir. |
| 16 | Prompt da Entrega 1 | Pedido de um prompt completo (engenharia de prompt) para executar a entrega inteira. | Prompt completo e versão resumida. |
| 17 | Entrega 2: modelo lógico e SQL | Esqueleto da Entrega 2 e o pedido "faça o seguimento para a entrega 2". | Modelo lógico de 14 tabelas, scripts 01 a 08 (criação, restrições, triggers, views, carga, JOIN, UPDATE, DELETE, gerenciais e auditoria), escritos primeiro em PostgreSQL e depois convertidos para MySQL 8.0 (SGBD da disciplina), testados a partir de banco vazio. |
| 18 | Entrega 2: massa de dados | Volumes reais informados pelo estabelecimento (pedidos por dia, mesas, horários). | Programa gerador (`entrega-2/scripts/gen_data.py`, semente fixa) com cerca de 1.650 pedidos fictícios coerentes; nomes, CNPJs e valores são inventados. |
| 19 | Entrega 2: relatório técnico | Itens do esqueleto (revisão do conceitual, conversão, PKs/FKs, normalização, justificativas, BI/IA). | este README (parte da Entrega 2) e o diagrama do modelo lógico gerado do banco. |
| 20 | Ajuste do DER | Necessidade surgida na implementação (pratos sem baixa por porção). | Atributo `IN_CONTROLA_ESTOQUE` proposto, no dicionário, no DER e no HTML (a validar com o professor). |

**Como o Claude foi usado na Entrega 2:** o Claude escreveu os scripts SQL, o gerador de dados e o relatório; **todos os dados da carga são sintéticos**. A verificação foi feita executando tudo em MySQL 8.0 (painel de integridade com 14 verificações em 0 violações e 15 operações inválidas bloqueadas). Falhas encontradas nos próprios scripts durante os testes: exclusão de compra pendente bloqueada por engano, teste de estoque que estourava o tipo `smallint`, reajuste de preço de teste sem efeito e numeração das regras diferente do README; todas corrigidas.

**Verificação pelo grupo:** o grupo conferiu a estrutura do DER indicada pelo professor, analisando juntos os links importantes do Blackboard, e usou a IA para remover o que havia colocado de errado. Além disso, cada resultado do Claude foi comparado com as orientações do professor, com os dados da visita e com o DER anterior do grupo; o que não foi observado no estabelecimento ficou como proposta ou `[VALIDAR]`.

---


---

### Contribuição da equipe

Trabalho em conjunto pelos quatro integrantes (visita, levantamento, DER, dicionário, modelo lógico, SQL e documentação); responsabilidades principais na seção 5.

### Contexto acadêmico

Atividade da disciplina de Modelagem de Banco de Dados (ADS, UNICID), baseada em um estabelecimento real. A Entrega 1 traz o modelo conceitual; a Entrega 2, o modelo lógico, a normalização e a implementação em MySQL com dados de teste e consultas.
