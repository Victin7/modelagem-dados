-- =====================================================================
-- 8. CONSULTAS DE AUDITORIA E INTEGRIDADE
-- Parte A: painel de verificações — cada linha deve retornar 0 violações.
-- Parte B: trilhas de auditoria (quem fez o quê) para a gerência.
-- =====================================================================

-- ---------- A. Painel de integridade (violações esperadas = 0) ----------
SELECT verificacao, violacoes, CASE WHEN violacoes = 0 THEN 'OK' ELSE 'FALHOU' END AS resultado FROM (
  SELECT 'A1 pedido fechado com pagamentos diferentes do total' AS verificacao, COUNT(*) AS violacoes
    FROM vw_pedido_total WHERE tp_status = 'F' AND vl_pago <> vl_total
  UNION ALL
  SELECT 'A2 pedido fechado sem nenhum pagamento', COUNT(*)
    FROM vw_pedido_total WHERE tp_status = 'F' AND vl_pago = 0
  UNION ALL
  SELECT 'A3 pedido cancelado com pagamento ou item não cancelado', COUNT(*)
    FROM pedido p WHERE p.tp_status = 'C' AND (EXISTS (SELECT 1 FROM pagamento g WHERE g.id_pedido = p.id_pedido)
                          OR EXISTS (SELECT 1 FROM pedido_produto i WHERE i.id_pedido = p.id_pedido AND i.tp_status <> 'C'))
  UNION ALL
  SELECT 'A4 pedido fechado com item ainda não entregue', COUNT(DISTINCT p.id_pedido)
    FROM pedido p JOIN pedido_produto i ON i.id_pedido = p.id_pedido
   WHERE p.tp_status = 'F' AND i.tp_status IN ('P','E','R')
  UNION ALL
  SELECT 'A5 mesa ocupada sem pedido aberto, ou pedido aberto em mesa livre', COUNT(*) FROM (
      SELECT m.id_mesa FROM mesa m WHERE m.tp_status = 'O' AND NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_mesa = m.id_mesa AND p.tp_status = 'A')
      UNION ALL
      SELECT m.id_mesa FROM mesa m WHERE m.tp_status = 'L' AND EXISTS (SELECT 1 FROM pedido p WHERE p.id_mesa = m.id_mesa AND p.tp_status = 'A')) x
  UNION ALL
  SELECT 'A6 estoque atual diferente da soma das movimentações', COUNT(*) FROM (
      SELECT pr.id_produto FROM produto pr LEFT JOIN movimentacao_estoque m ON m.id_produto = pr.id_produto
       GROUP BY pr.id_produto, pr.qt_estoque_atual HAVING pr.qt_estoque_atual <> COALESCE(SUM(m.qt_movimento), 0)) x
  UNION ALL
  SELECT 'A7 estoque negativo', COUNT(*) FROM produto WHERE qt_estoque_atual < 0
  UNION ALL
  SELECT 'A8 item vendido ao preço diferente do vigente na data (RN07)', COUNT(*) FROM pedido_produto i
    JOIN produto pr ON pr.id_produto = i.id_produto
   WHERE i.vl_preco_unitario <> COALESCE((SELECT h.vl_preco_anterior FROM historico_produto h
                                           WHERE h.id_produto = i.id_produto AND h.dh_alteracao > i.dh_registro
                                           ORDER BY h.dh_alteracao LIMIT 1), pr.vl_preco)
  UNION ALL
  SELECT 'A9 produto alterado de preço sem registro no histórico', COUNT(*) FROM (
      SELECT pr.id_produto FROM produto pr
       WHERE pr.vl_preco <> COALESCE((SELECT h.vl_preco_novo FROM historico_produto h WHERE h.id_produto = pr.id_produto
                                       ORDER BY h.dh_alteracao DESC LIMIT 1), pr.vl_preco)) x
  UNION ALL
  SELECT 'A10 venda/estorno de estoque diferente da quantidade efetiva dos itens', COUNT(*) FROM (
      SELECT i.id_pedido, i.id_produto FROM pedido_produto i JOIN produto pr USING (id_produto)
        LEFT JOIN movimentacao_estoque m ON m.id_pedido = i.id_pedido AND m.id_produto = i.id_produto
       WHERE pr.in_controla_estoque
       GROUP BY i.id_pedido, i.id_produto, i.qt_item, i.tp_status
      HAVING COALESCE(SUM(m.qt_movimento), 0) <> -(CASE WHEN i.tp_status = 'C' THEN 0 ELSE i.qt_item END)) x
  UNION ALL
  SELECT 'A11 compra recebida sem movimentação de entrada correspondente', COUNT(*) FROM (
      SELECT cp.id_compra, cp.id_produto FROM compra c JOIN compra_produto cp USING (id_compra)
        LEFT JOIN movimentacao_estoque m ON m.id_compra = cp.id_compra AND m.id_produto = cp.id_produto AND m.tp_movimento = 'C'
       WHERE c.tp_status = 'R' GROUP BY cp.id_compra, cp.id_produto, cp.qt_comprada
      HAVING COALESCE(SUM(m.qt_movimento), 0) <> cp.qt_comprada) x
  UNION ALL
  SELECT 'A12 produto vendável sem setor de preparo (RN06)', COUNT(*)
    FROM produto p JOIN setor s USING (id_setor) WHERE p.in_vendavel AND NOT s.in_preparo
  UNION ALL
  SELECT 'A13 pedido aberto por atendente sem perfil de atendimento (RN01)', COUNT(*)
    FROM pedido p JOIN atendente a USING (id_atendente) WHERE a.tp_perfil NOT IN ('A','G','S')
  UNION ALL
  SELECT 'A14 sobreposição de pedidos na mesma mesa (RN05)', COUNT(*)
    FROM pedido a JOIN pedido b ON a.id_mesa = b.id_mesa AND a.id_pedido < b.id_pedido
     AND a.dh_abertura < COALESCE(b.dh_fechamento, 'infinity') AND b.dh_abertura < COALESCE(a.dh_fechamento, 'infinity')
) t ORDER BY 1;

-- ---------- B. Trilhas de auditoria ----------
-- B1. Alterações de preço (quem, quando, de quanto para quanto)
SELECT h.dh_alteracao, a.nm_atendente AS responsavel, p.nm_produto, h.vl_preco_anterior, h.vl_preco_novo,
       ROUND((h.vl_preco_novo - h.vl_preco_anterior) / h.vl_preco_anterior * 100, 1) AS variacao_pct
  FROM historico_produto h JOIN produto p USING (id_produto) JOIN atendente a USING (id_atendente)
 ORDER BY h.dh_alteracao, p.nm_produto;

-- B2. Ajustes manuais de estoque (exceto inventário inicial): consumo de insumos e correções
SELECT m.dh_movimento, p.nm_produto, m.qt_movimento, m.ds_motivo
  FROM movimentacao_estoque m JOIN produto p USING (id_produto)
 WHERE m.tp_movimento = 'A' AND m.ds_motivo NOT LIKE 'Inventário inicial%'
 ORDER BY m.dh_movimento, p.nm_produto
 LIMIT 40;

-- B3. Cancelamentos por atendente (pedidos cancelados e itens cancelados)
SELECT a.nm_atendente,
       COUNT(DISTINCT p.id_pedido) FILTER (WHERE p.tp_status = 'C')                    AS pedidos_cancelados,
       COUNT(DISTINCT p.id_pedido)                                                      AS pedidos_total,
       COUNT(*) FILTER (WHERE i.tp_status = 'C' AND p.tp_status <> 'C')                 AS itens_cancelados_em_pedidos_ativos,
       ROUND(100.0 * COUNT(DISTINCT p.id_pedido) FILTER (WHERE p.tp_status = 'C') / COUNT(DISTINCT p.id_pedido), 1) AS pct_cancelados
  FROM pedido p JOIN atendente a USING (id_atendente) JOIN pedido_produto i USING (id_pedido)
 GROUP BY a.nm_atendente ORDER BY pedidos_cancelados DESC, a.nm_atendente;

-- B4. Taxa de serviço removida (RN16): quantidade e valor deixado de arrecadar por garçom
SELECT a.nm_atendente, COUNT(*) AS pedidos_sem_taxa,
       ROUND(SUM(ROUND(t.vl_subtotal * 0.10, 2)), 2) AS taxa_nao_cobrada
  FROM pedido p JOIN atendente a USING (id_atendente) JOIN vw_pedido_total t USING (id_pedido)
 WHERE NOT p.in_taxa_servico AND p.tp_status = 'F'
 GROUP BY a.nm_atendente ORDER BY pedidos_sem_taxa DESC;

-- B5. Conferência do caixa por dia e forma de pagamento (a nota é emitida na maquininha)
SELECT dh_pagamento::date AS dia,
       SUM(vl_pago) FILTER (WHERE tp_forma = 'D') AS dinheiro,
       SUM(vl_pago) FILTER (WHERE tp_forma = 'P') AS pix,
       SUM(vl_pago) FILTER (WHERE tp_forma = 'C') AS credito,
       SUM(vl_pago) FILTER (WHERE tp_forma = 'B') AS debito,
       SUM(vl_pago)                               AS total_dia
  FROM pagamento GROUP BY 1 ORDER BY 1;

-- B6. Itens com validade vencida ou a vencer em 7 dias (referência: 12/10/2026), conferindo a planilha manual
SELECT p.nm_produto, f.nm_fornecedor, c.nr_nota_fiscal, cp.dt_validade, cp.dt_validade - DATE '2026-10-12' AS dias_para_vencer
  FROM compra_produto cp JOIN compra c USING (id_compra) JOIN produto p USING (id_produto) JOIN fornecedor f USING (id_fornecedor)
 WHERE c.tp_status = 'R' AND cp.dt_validade <= DATE '2026-10-12' + 7
 ORDER BY cp.dt_validade, p.nm_produto;

-- B7. Quem atendeu mesas além da jornada: pedidos abertos há mais de 3 horas (referência: 12/10/2026 21:20)
SELECT p.id_pedido, m.nr_mesa, a.nm_atendente, p.dh_abertura,
       ROUND(EXTRACT(EPOCH FROM (TIMESTAMP '2026-10-12 21:20' - p.dh_abertura)) / 3600, 1) AS horas_aberto
  FROM pedido p JOIN mesa m USING (id_mesa) JOIN atendente a USING (id_atendente)
 WHERE p.tp_status = 'A' AND p.dh_abertura < TIMESTAMP '2026-10-12 21:20' - INTERVAL '3 hours'
 ORDER BY p.dh_abertura;
