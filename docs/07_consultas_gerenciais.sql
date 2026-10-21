-- =====================================================================
-- 7. CONSULTAS GERENCIAIS (G01 a G15) — apoio à decisão; alimentam o BI da arquitetura analítica
-- Base: pedidos FECHADOS (tp_status = 'F') da semana 06/10 a 12/10/2026 (massa de dados fictícia).
-- Problemas declarados (README, seção 1.1):
--   P1 falta de controle de quem registra pedidos e ações (sem credenciais individuais)
--   P2 compras e cadastros (preço, estoque) dependem de poucas pessoas e não registram o responsável
--   P3 compras sem registro estruturado (fornecedor, nota fiscal e custo)
--   P4 estoque e validade em planilha manual, sem histórico de movimentação nem alerta de reposição
--   P5 pedido, estoque e compras fora do mesmo fluxo (baixa de estoque manual)
--   P6 conferência de pagamentos e fechamento do caixa feitos à mão
-- =====================================================================
USE palazio_del_chef;
SET NAMES utf8mb4;

-- G01 — Qual o faturamento por dia (pedidos, vendas, taxa de serviço, ticket médio)?
-- Atende: P6 (conferência do caixa) e KPI faturamento e ticket médio
SELECT DATE(p.dh_abertura) AS dia,
       ELT(DAYOFWEEK(p.dh_abertura), 'Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb') AS dia_semana,
       COUNT(*) AS pedidos, SUM(t.vl_subtotal) AS vendas, SUM(t.vl_taxa) AS taxa_servico, SUM(t.vl_total) AS faturamento,
       ROUND(AVG(t.vl_total), 2) AS ticket_medio
  FROM pedido p JOIN vw_pedido_total t USING (id_pedido)
 WHERE p.tp_status = 'F'
 GROUP BY DATE(p.dh_abertura), dia_semana ORDER BY dia;

-- G02 — Quais os 10 produtos que mais geram receita e quanto cada um pesa no total?
-- Atende: KPI produtos mais vendidos (receita e participação)
SELECT pr.nm_produto, c.nm_categoria, SUM(i.qt_item) AS qtd, SUM(i.qt_item * i.vl_preco_unitario) AS receita,
       ROUND(100.0 * SUM(i.qt_item * i.vl_preco_unitario) / SUM(SUM(i.qt_item * i.vl_preco_unitario)) OVER (), 1) AS pct_receita
  FROM pedido_produto i JOIN pedido p USING (id_pedido) JOIN produto pr USING (id_produto) JOIN categoria c USING (id_categoria)
 WHERE p.tp_status = 'F' AND i.tp_status <> 'C'
 GROUP BY pr.nm_produto, c.nm_categoria ORDER BY receita DESC LIMIT 10;

-- G03 — Quanto cada setor (cozinha × bar) e cada categoria vendem, com subtotais?
-- Atende: KPI receita por setor e categoria
SELECT IF(GROUPING(s.nm_setor), 'TOTAL GERAL', s.nm_setor) AS setor,
       IF(GROUPING(c.nm_categoria), IF(GROUPING(s.nm_setor), '(todas)', 'subtotal do setor'), c.nm_categoria) AS categoria,
       SUM(i.qt_item) AS qtd, SUM(i.qt_item * i.vl_preco_unitario) AS receita
  FROM pedido_produto i JOIN pedido p USING (id_pedido) JOIN produto pr USING (id_produto)
  JOIN categoria c USING (id_categoria) JOIN setor s ON s.id_setor = pr.id_setor
 WHERE p.tp_status = 'F' AND i.tp_status <> 'C'
 GROUP BY s.nm_setor, c.nm_categoria WITH ROLLUP;

-- G04 — Como cada garçom se sai: pedidos, faturamento, ticket médio e % de pedidos sem taxa de serviço?
-- Atende: P1 (saber quem registrou cada pedido) e KPI desempenho por atendente
SELECT a.nm_atendente, COUNT(*) AS pedidos, SUM(t.vl_total) AS faturamento, ROUND(AVG(t.vl_total), 2) AS ticket_medio,
       ROUND(100.0 * SUM(CASE WHEN NOT p.in_taxa_servico THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_sem_taxa
  FROM pedido p JOIN atendente a USING (id_atendente) JOIN vw_pedido_total t USING (id_pedido)
 WHERE p.tp_status = 'F' GROUP BY a.nm_atendente ORDER BY faturamento DESC;

-- G05 — Quanto tempo (minutos) a cozinha e o bar levam para preparar, por categoria (média e P90 aproximado)?
-- Atende: KPI tempo médio de preparo; apoia P5 (acompanhar o item do lançamento ao preparo)
WITH x AS (
  SELECT s.nm_setor, c.nm_categoria, TIMESTAMPDIFF(SECOND, i.dh_registro, i.dh_pronto) / 60 AS minutos,
         PERCENT_RANK() OVER (PARTITION BY s.nm_setor, c.nm_categoria ORDER BY TIMESTAMPDIFF(SECOND, i.dh_registro, i.dh_pronto)) AS pr
    FROM pedido_produto i JOIN produto pr USING (id_produto) JOIN categoria c USING (id_categoria)
    JOIN setor s ON s.id_setor = pr.id_setor
   WHERE i.dh_pronto IS NOT NULL)
SELECT nm_setor, nm_categoria, COUNT(*) AS itens, ROUND(AVG(minutos), 1) AS min_medio,
       ROUND(MIN(CASE WHEN pr >= 0.9 THEN minutos END), 1) AS min_p90
  FROM x GROUP BY nm_setor, nm_categoria ORDER BY nm_setor, min_medio DESC;

-- G06 — Quais os horários de pico (pedidos abertos por hora e dia da semana)?
-- Atende: KPI pedidos por hora (escala de equipe e compras)
SELECT HOUR(dh_abertura) AS hora,
       SUM(DAYOFWEEK(dh_abertura) IN (3, 4, 5)) AS ter_qua_qui,
       SUM(DAYOFWEEK(dh_abertura) = 6) AS sexta,
       SUM(DAYOFWEEK(dh_abertura) = 7) AS sabado,
       SUM(DAYOFWEEK(dh_abertura) = 1) AS domingo,
       SUM(DAYOFWEEK(dh_abertura) = 2) AS segunda
  FROM pedido GROUP BY HOUR(dh_abertura) ORDER BY hora;

-- G07 — Quanto tempo as mesas e os bistrôs ficam ocupados e quantos pedidos giram na semana?
-- Atende: KPI permanência média e giro de mesas
SELECT m.tp_local, COUNT(DISTINCT m.id_mesa) AS unidades, COUNT(*) AS pedidos,
       ROUND(AVG(TIMESTAMPDIFF(SECOND, p.dh_abertura, p.dh_fechamento) / 60), 0) AS permanencia_min,
       ROUND(COUNT(*) / COUNT(DISTINCT m.id_mesa), 1) AS giro_semana
  FROM pedido p JOIN mesa m USING (id_mesa) WHERE p.tp_status = 'F' GROUP BY m.tp_local;

-- G08 — Qual a margem bruta estimada de cada produto de revenda (custo da última compra recebida)?
-- Atende: P3 (custo por compra registrado) e KPI margem bruta
SELECT x.nm_produto, x.vl_preco, x.custo, ROUND(x.vl_preco - x.custo, 2) AS margem,
       ROUND(100 * (x.vl_preco - x.custo) / x.vl_preco, 1) AS margem_pct
  FROM (SELECT pr.nm_produto, pr.vl_preco,
               (SELECT cp.vl_custo_unitario FROM compra_produto cp JOIN compra c USING (id_compra)
                 WHERE cp.id_produto = pr.id_produto AND c.tp_status = 'R'
                 ORDER BY c.dh_recebimento DESC LIMIT 1) AS custo
          FROM produto pr WHERE pr.in_vendavel) x
 WHERE x.custo IS NOT NULL ORDER BY margem_pct;

-- G09 — Quais produtos formam a curva ABC de receita (A até 80 %, B até 95 %, C o restante)?
-- Atende: KPI concentração de receita (curva ABC)
WITH r AS (
  SELECT pr.nm_produto, SUM(i.qt_item * i.vl_preco_unitario) AS receita
    FROM pedido_produto i JOIN pedido p USING (id_pedido) JOIN produto pr USING (id_produto)
   WHERE p.tp_status = 'F' AND i.tp_status <> 'C' GROUP BY pr.nm_produto),
 a AS (SELECT r.*, SUM(receita) OVER (ORDER BY receita DESC) / SUM(receita) OVER () AS acum FROM r)
SELECT CASE WHEN acum <= .80 THEN 'A' WHEN acum <= .95 THEN 'B' ELSE 'C' END AS classe,
       COUNT(*) AS produtos, SUM(receita) AS receita, ROUND(100 * MAX(acum), 1) AS acumulado_pct
  FROM a GROUP BY classe ORDER BY classe;

-- G10 — O reajuste de 09/10 mudou a venda diária dos produtos reajustados (antes × depois) e quem o fez?
-- Atende: P2 (alteração de preço com responsável e histórico) e KPI impacto de reajuste
SELECT pr.nm_produto, h.vl_preco_anterior, h.vl_preco_novo, a.nm_atendente AS responsavel,
       ROUND(SUM(CASE WHEN i.dh_registro <  h.dh_alteracao THEN i.qt_item END) / 3, 1)   AS un_dia_antes,
       ROUND(SUM(CASE WHEN i.dh_registro >= h.dh_alteracao THEN i.qt_item END) / 3.5, 1) AS un_dia_depois
  FROM historico_produto h JOIN produto pr USING (id_produto) JOIN atendente a USING (id_atendente)
  JOIN pedido_produto i ON i.id_produto = h.id_produto AND i.tp_status <> 'C'
 GROUP BY pr.nm_produto, h.vl_preco_anterior, h.vl_preco_novo, a.nm_atendente ORDER BY pr.nm_produto;

-- G11 — Como os pagamentos se dividem por forma (dinheiro, Pix, crédito, débito)?
-- Atende: P6 (conferência do caixa por forma de pagamento) e KPI mix de pagamentos
SELECT tp_forma, COUNT(*) AS pagamentos, SUM(vl_pago) AS valor, ROUND(100 * SUM(vl_pago) / SUM(SUM(vl_pago)) OVER (), 1) AS pct
  FROM pagamento GROUP BY tp_forma ORDER BY valor DESC;

-- G12 — Quais itens estão abaixo do estoque mínimo e quanto repor (cobrir a média de 7 dias de saída)?
-- Atende: P4 (alerta de reposição) e KPI itens abaixo do mínimo
SELECT e.nm_produto, e.qt_estoque_atual, e.qt_estoque_minimo,
       CEIL(-SUM(CASE WHEN m.tp_movimento IN ('V','E','A') AND m.ds_motivo NOT LIKE 'Inventário%' THEN m.qt_movimento END) - e.qt_estoque_atual) AS sugestao_compra
  FROM vw_estoque_critico e JOIN movimentacao_estoque m USING (id_produto)
 GROUP BY e.nm_produto, e.qt_estoque_atual, e.qt_estoque_minimo ORDER BY e.nm_produto;

-- G13 — Quanto foi comprado de cada fornecedor (notas, itens, valor e custo médio por item)?
-- Atende: P3 (compras com fornecedor, nota fiscal e custo) e KPI gasto por fornecedor
SELECT f.nm_fornecedor, COUNT(DISTINCT c.id_compra) AS compras, COUNT(*) AS itens,
       SUM(cp.qt_comprada * cp.vl_custo_unitario) AS valor_comprado,
       ROUND(SUM(cp.qt_comprada * cp.vl_custo_unitario) / SUM(cp.qt_comprada), 2) AS custo_medio_unidade
  FROM compra c JOIN fornecedor f USING (id_fornecedor) JOIN compra_produto cp USING (id_compra)
 WHERE c.tp_status = 'R' GROUP BY f.nm_fornecedor ORDER BY valor_comprado DESC;

-- G14 — Quais itens estão vencidos ou vencem em até 7 dias (substitui a conferência mensal em planilha)?
-- Atende: P4 (validade controlada no sistema) e KPI itens a vencer. Referência: 12/10/2026
SELECT p.nm_produto, f.nm_fornecedor, c.nr_nota_fiscal, cp.dt_validade, DATEDIFF(cp.dt_validade, '2026-10-12') AS dias_para_vencer
  FROM compra_produto cp JOIN compra c USING (id_compra) JOIN produto p USING (id_produto) JOIN fornecedor f USING (id_fornecedor)
 WHERE c.tp_status = 'R' AND cp.dt_validade <= DATE_ADD('2026-10-12', INTERVAL 7 DAY)
 ORDER BY cp.dt_validade, p.nm_produto;

-- G15 — Pedidos abertos há mais de 3 horas (referência 12/10/2026 21:20): quem atende e em que mesa?
-- Atende: P1 (responsável por cada pedido) e KPI pedidos abertos por tempo
SELECT p.id_pedido, m.nr_mesa, a.nm_atendente, p.dh_abertura,
       ROUND(TIMESTAMPDIFF(SECOND, p.dh_abertura, '2026-10-12 21:20:00') / 3600, 1) AS horas_aberto
  FROM pedido p JOIN mesa m USING (id_mesa) JOIN atendente a USING (id_atendente)
 WHERE p.tp_status = 'A' AND p.dh_abertura < '2026-10-12 21:20:00' - INTERVAL 3 HOUR
 ORDER BY p.dh_abertura;
