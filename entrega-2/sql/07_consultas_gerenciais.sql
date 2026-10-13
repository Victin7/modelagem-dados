-- =====================================================================
-- 7. CONSULTAS GERENCIAIS (apoio à decisão / alimentam o BI da seção de arquitetura analítica)
-- Base: pedidos FECHADOS (tp_status = 'F') da semana 06/10 a 12/10/2026.
-- =====================================================================

-- G1. Faturamento por dia: pedidos, itens, ticket médio, taxa de serviço
SELECT p.dh_abertura::date AS dia, to_char(p.dh_abertura, 'TMDy') AS dia_semana, COUNT(*) AS pedidos,
       SUM(t.vl_subtotal) AS vendas, SUM(t.vl_taxa) AS taxa_servico, SUM(t.vl_total) AS faturamento,
       ROUND(AVG(t.vl_total), 2) AS ticket_medio
  FROM pedido p JOIN vw_pedido_total t USING (id_pedido)
 WHERE p.tp_status = 'F' GROUP BY 1, 2 ORDER BY 1;

-- G2. Top 10 produtos por receita (exclui itens cancelados), com participação no total
SELECT pr.nm_produto, c.nm_categoria, SUM(i.qt_item) AS qtd, SUM(i.qt_item * i.vl_preco_unitario) AS receita,
       ROUND(100.0 * SUM(i.qt_item * i.vl_preco_unitario) / SUM(SUM(i.qt_item * i.vl_preco_unitario)) OVER (), 1) AS pct_receita
  FROM pedido_produto i JOIN pedido p USING (id_pedido) JOIN produto pr USING (id_produto) JOIN categoria c USING (id_categoria)
 WHERE p.tp_status = 'F' AND i.tp_status <> 'C'
 GROUP BY pr.nm_produto, c.nm_categoria ORDER BY receita DESC LIMIT 10;

-- G3. Receita por categoria e setor (cozinha × bar)
SELECT s.nm_setor, c.nm_categoria, SUM(i.qt_item) AS qtd, SUM(i.qt_item * i.vl_preco_unitario) AS receita
  FROM pedido_produto i JOIN pedido p USING (id_pedido) JOIN produto pr USING (id_produto)
  JOIN categoria c USING (id_categoria) JOIN setor s ON s.id_setor = pr.id_setor
 WHERE p.tp_status = 'F' AND i.tp_status <> 'C'
 GROUP BY ROLLUP (s.nm_setor, c.nm_categoria) ORDER BY s.nm_setor NULLS LAST, receita DESC NULLS LAST;

-- G4. Desempenho por garçom: pedidos, faturamento, ticket médio e % de pedidos com taxa removida
SELECT a.nm_atendente, COUNT(*) AS pedidos, SUM(t.vl_total) AS faturamento, ROUND(AVG(t.vl_total), 2) AS ticket_medio,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT p.in_taxa_servico) / COUNT(*), 1) AS pct_sem_taxa
  FROM pedido p JOIN atendente a USING (id_atendente) JOIN vw_pedido_total t USING (id_pedido)
 WHERE p.tp_status = 'F' GROUP BY a.nm_atendente ORDER BY faturamento DESC;

-- G5. Tempo médio de preparo (minutos) por setor e categoria — meta de 2 s do app é de resposta; aqui é o tempo de cozinha/bar
SELECT s.nm_setor, c.nm_categoria, COUNT(*) AS itens,
       ROUND(AVG(EXTRACT(EPOCH FROM (i.dh_pronto - i.dh_registro)) / 60)::numeric, 1) AS min_medio,
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (i.dh_pronto - i.dh_registro)) / 60))::numeric, 1) AS min_p90
  FROM pedido_produto i JOIN produto pr USING (id_produto) JOIN categoria c USING (id_categoria)
  JOIN setor s ON s.id_setor = pr.id_setor
 WHERE i.dh_pronto IS NOT NULL GROUP BY s.nm_setor, c.nm_categoria ORDER BY s.nm_setor, min_medio DESC;

-- G6. Horários de pico: pedidos abertos por hora, para cada dia da semana
SELECT EXTRACT(HOUR FROM dh_abertura)::int AS hora,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM dh_abertura) BETWEEN 2 AND 4) AS ter_qua_qui,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM dh_abertura) = 5) AS sexta,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM dh_abertura) = 6) AS sabado,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM dh_abertura) = 0) AS domingo,
       COUNT(*) FILTER (WHERE EXTRACT(DOW FROM dh_abertura) = 1) AS segunda
  FROM pedido GROUP BY 1 ORDER BY 1;

-- G7. Ocupação: permanência média e giro das mesas × bistrôs
SELECT m.tp_local, COUNT(DISTINCT m.id_mesa) AS unidades, COUNT(*) AS pedidos,
       ROUND(AVG(EXTRACT(EPOCH FROM (p.dh_fechamento - p.dh_abertura)) / 60)::numeric, 0) AS permanencia_min,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT m.id_mesa), 1) AS giro_semana
  FROM pedido p JOIN mesa m USING (id_mesa) WHERE p.tp_status = 'F' GROUP BY m.tp_local;

-- G8. Margem bruta estimada dos produtos de revenda (custo da última compra recebida)
SELECT pr.nm_produto, pr.vl_preco, uc.vl_custo_unitario AS custo, ROUND(pr.vl_preco - uc.vl_custo_unitario, 2) AS margem,
       ROUND(100 * (pr.vl_preco - uc.vl_custo_unitario) / pr.vl_preco, 1) AS margem_pct
  FROM produto pr
  JOIN LATERAL (SELECT cp.vl_custo_unitario FROM compra_produto cp JOIN compra c USING (id_compra)
                 WHERE cp.id_produto = pr.id_produto AND c.tp_status = 'R' ORDER BY c.dh_recebimento DESC LIMIT 1) uc ON TRUE
 WHERE pr.in_vendavel ORDER BY margem_pct;

-- G9. Curva ABC de produtos por receita (A até 80 %, B até 95 %, C restante)
WITH r AS (
  SELECT pr.nm_produto, SUM(i.qt_item * i.vl_preco_unitario) AS receita
    FROM pedido_produto i JOIN pedido p USING (id_pedido) JOIN produto pr USING (id_produto)
   WHERE p.tp_status = 'F' AND i.tp_status <> 'C' GROUP BY pr.nm_produto),
 a AS (SELECT *, SUM(receita) OVER (ORDER BY receita DESC) / SUM(receita) OVER () AS acum FROM r)
SELECT CASE WHEN acum <= .80 THEN 'A' WHEN acum <= .95 THEN 'B' ELSE 'C' END AS classe,
       COUNT(*) AS produtos, SUM(receita) AS receita, ROUND(100 * MAX(acum), 1) AS acumulado_pct
  FROM a GROUP BY 1 ORDER BY 1;

-- G10. Impacto do reajuste de 09/10 08:10: média diária de unidades antes × depois (produtos reajustados)
SELECT pr.nm_produto, h.vl_preco_anterior, h.vl_preco_novo,
       ROUND(SUM(i.qt_item) FILTER (WHERE i.dh_registro <  h.dh_alteracao)::numeric / 3, 1) AS un_dia_antes,
       ROUND(SUM(i.qt_item) FILTER (WHERE i.dh_registro >= h.dh_alteracao)::numeric / 3.5, 1) AS un_dia_depois
  FROM historico_produto h JOIN produto pr USING (id_produto)
  JOIN pedido_produto i ON i.id_produto = h.id_produto AND i.tp_status <> 'C'
 GROUP BY pr.nm_produto, h.vl_preco_anterior, h.vl_preco_novo ORDER BY pr.nm_produto;

-- G11. Mix de formas de pagamento (D dinheiro, P Pix, C crédito, B débito)
SELECT tp_forma, COUNT(*) AS pagamentos, SUM(vl_pago) AS valor, ROUND(100 * SUM(vl_pago) / SUM(SUM(vl_pago)) OVER (), 1) AS pct
  FROM pagamento GROUP BY tp_forma ORDER BY valor DESC;

-- G12. Reposição: itens abaixo do mínimo com quantidade sugerida (cobrir a média de 7 dias de saída)
SELECT e.nm_produto, e.qt_estoque_atual, e.qt_estoque_minimo,
       CEIL(-SUM(m.qt_movimento) FILTER (WHERE m.tp_movimento IN ('V','E','A') AND m.ds_motivo NOT LIKE 'Inventário%') - e.qt_estoque_atual) AS sugestao_compra
  FROM vw_estoque_critico e JOIN movimentacao_estoque m USING (id_produto)
 GROUP BY e.nm_produto, e.qt_estoque_atual, e.qt_estoque_minimo ORDER BY e.nm_produto;
