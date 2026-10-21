-- =====================================================================
-- 8. CONSULTAS DE AUDITORIA E INTEGRIDADE (A01 a A20)
-- A01 a A14: painel de verificações — cada uma deve retornar 0 violações.
-- A15 a A20: trilhas de auditoria (quem fez o quê) para a gerência.
-- =====================================================================
USE palazio_del_chef;
SET NAMES utf8mb4;

-- ---------- Painel de integridade A01–A14 (violações esperadas = 0) ----------
-- Cada linha traz o código, o que verifica e a regra de negócio conferida.
SELECT codigo, verificacao, regra, violacoes, IF(violacoes = 0, 'OK', 'FALHOU') AS resultado FROM (
  -- A01 — Existe pedido fechado com pagamentos diferentes do total? | Verifica: RN10, RN11, RN15 (P6)
  SELECT 'A01' AS codigo, 'pedido fechado com pagamentos diferentes do total' AS verificacao, 'RN10, RN11, RN15' AS regra, COUNT(*) AS violacoes
    FROM vw_pedido_total WHERE tp_status = 'F' AND vl_pago <> vl_total
  UNION ALL
  -- A02 — Existe pedido fechado sem nenhum pagamento? | Verifica: RN10 (P6)
  SELECT 'A02', 'pedido fechado sem nenhum pagamento', 'RN10', COUNT(*)
    FROM vw_pedido_total WHERE tp_status = 'F' AND vl_pago = 0
  UNION ALL
  -- A03 — Existe pedido cancelado com pagamento ou com item não cancelado? | Verifica: RN09, RN10
  SELECT 'A03', 'pedido cancelado com pagamento ou item não cancelado', 'RN09, RN10', COUNT(*)
    FROM pedido p WHERE p.tp_status = 'C' AND (EXISTS (SELECT 1 FROM pagamento g WHERE g.id_pedido = p.id_pedido)
                          OR EXISTS (SELECT 1 FROM pedido_produto i WHERE i.id_pedido = p.id_pedido AND i.tp_status <> 'C'))
  UNION ALL
  -- A04 — Existe pedido fechado com item ainda não entregue? | Verifica: RN10
  SELECT 'A04', 'pedido fechado com item ainda não entregue', 'RN10', COUNT(DISTINCT p.id_pedido)
    FROM pedido p JOIN pedido_produto i ON i.id_pedido = p.id_pedido
   WHERE p.tp_status = 'F' AND i.tp_status IN ('P','E','R')
  UNION ALL
  -- A05 — Existe mesa ocupada sem pedido aberto, ou pedido aberto em mesa livre? | Verifica: RN02, RN05
  SELECT 'A05', 'mesa ocupada sem pedido aberto, ou pedido aberto em mesa livre', 'RN02, RN05', COUNT(*) FROM (
      SELECT m.id_mesa FROM mesa m WHERE m.tp_status = 'O' AND NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_mesa = m.id_mesa AND p.tp_status = 'A')
      UNION ALL
      SELECT m.id_mesa FROM mesa m WHERE m.tp_status = 'L' AND EXISTS (SELECT 1 FROM pedido p WHERE p.id_mesa = m.id_mesa AND p.tp_status = 'A')) x
  UNION ALL
  -- A06 — O estoque atual é igual à soma das movimentações? | Verifica: RN21 (P4, P5)
  SELECT 'A06', 'estoque atual diferente da soma das movimentações', 'RN21', COUNT(*) FROM (
      SELECT pr.id_produto FROM produto pr LEFT JOIN movimentacao_estoque m ON m.id_produto = pr.id_produto
       GROUP BY pr.id_produto, pr.qt_estoque_atual HAVING pr.qt_estoque_atual <> COALESCE(SUM(m.qt_movimento), 0)) x
  UNION ALL
  -- A07 — Existe produto com estoque negativo? | Verifica: RN08
  SELECT 'A07', 'estoque negativo', 'RN08', COUNT(*) FROM produto WHERE qt_estoque_atual < 0
  UNION ALL
  -- A08 — Algum item foi vendido por preço diferente do vigente na data? | Verifica: RN07
  SELECT 'A08', 'item vendido ao preço diferente do vigente na data', 'RN07', COUNT(*) FROM pedido_produto i
    JOIN produto pr ON pr.id_produto = i.id_produto
   WHERE i.vl_preco_unitario <> COALESCE((SELECT h.vl_preco_anterior FROM historico_produto h
                                           WHERE h.id_produto = i.id_produto AND h.dh_alteracao > i.dh_registro
                                           ORDER BY h.dh_alteracao LIMIT 1), pr.vl_preco)
  UNION ALL
  -- A09 — Algum produto teve o preço alterado sem registro no histórico? | Verifica: RN24 (P2)
  SELECT 'A09', 'produto alterado de preço sem registro no histórico', 'RN24', COUNT(*) FROM (
      SELECT pr.id_produto FROM produto pr
       WHERE pr.vl_preco <> COALESCE((SELECT h.vl_preco_novo FROM historico_produto h WHERE h.id_produto = pr.id_produto
                                       ORDER BY h.dh_alteracao DESC LIMIT 1), pr.vl_preco)) x
  UNION ALL
  -- A10 — A baixa/estorno de estoque bate com a quantidade efetiva de cada item? | Verifica: RN08, RN21 (P5)
  SELECT 'A10', 'venda/estorno de estoque diferente da quantidade efetiva dos itens', 'RN08, RN21', COUNT(*) FROM (
      SELECT i.id_pedido, i.id_produto FROM pedido_produto i JOIN produto pr USING (id_produto)
        LEFT JOIN movimentacao_estoque m ON m.id_pedido = i.id_pedido AND m.id_produto = i.id_produto
       WHERE pr.in_controla_estoque
       GROUP BY i.id_pedido, i.id_produto, i.qt_item, i.tp_status
      HAVING COALESCE(SUM(m.qt_movimento), 0) <> -(CASE WHEN i.tp_status = 'C' THEN 0 ELSE i.qt_item END)) x
  UNION ALL
  -- A11 — Toda compra recebida gerou a entrada de estoque correspondente? | Verifica: RN23 (P3, P4)
  SELECT 'A11', 'compra recebida sem movimentação de entrada correspondente', 'RN23', COUNT(*) FROM (
      SELECT cp.id_compra, cp.id_produto FROM compra c JOIN compra_produto cp USING (id_compra)
        LEFT JOIN movimentacao_estoque m ON m.id_compra = cp.id_compra AND m.id_produto = cp.id_produto AND m.tp_movimento = 'C'
       WHERE c.tp_status = 'R' GROUP BY cp.id_compra, cp.id_produto, cp.qt_comprada
      HAVING COALESCE(SUM(m.qt_movimento), 0) <> cp.qt_comprada) x
  UNION ALL
  -- A12 — Existe produto vendável sem setor de preparo? | Verifica: RN06
  SELECT 'A12', 'produto vendável sem setor de preparo', 'RN06', COUNT(*)
    FROM produto p JOIN setor s USING (id_setor) WHERE p.in_vendavel AND NOT s.in_preparo
  UNION ALL
  -- A13 — Existe pedido aberto por atendente sem perfil de atendimento? | Verifica: RN01, RN04 (P1)
  SELECT 'A13', 'pedido aberto por atendente sem perfil de atendimento', 'RN01, RN04', COUNT(*)
    FROM pedido p JOIN atendente a USING (id_atendente) WHERE a.tp_perfil NOT IN ('A','G','S')
  UNION ALL
  -- A14 — Existem dois pedidos sobrepostos na mesma mesa? | Verifica: RN05
  SELECT 'A14', 'sobreposição de pedidos na mesma mesa', 'RN05', COUNT(*)
    FROM pedido a JOIN pedido b ON a.id_mesa = b.id_mesa AND a.id_pedido < b.id_pedido
     AND a.dh_abertura < COALESCE(b.dh_fechamento, '9999-12-31 00:00:00') AND b.dh_abertura < COALESCE(a.dh_fechamento, '9999-12-31 00:00:00')
) t ORDER BY codigo;

-- ---------- Trilhas de auditoria A15–A20 ----------

-- A15 — Quem alterou preços, quando e de quanto para quanto?
-- Verifica: RN24 (só a gerência altera preço, com responsável e data) — apoia P2
SELECT h.dh_alteracao, a.nm_atendente AS responsavel, a.tp_perfil, p.nm_produto, h.vl_preco_anterior, h.vl_preco_novo,
       ROUND((h.vl_preco_novo - h.vl_preco_anterior) / h.vl_preco_anterior * 100, 1) AS variacao_pct
  FROM historico_produto h JOIN produto p USING (id_produto) JOIN atendente a USING (id_atendente)
 ORDER BY h.dh_alteracao, p.nm_produto;

-- A16 — Quais ajustes manuais de estoque ocorreram (consumo de insumos e correções, exceto inventário inicial)?
-- Verifica: RN17, RN21 (todo ajuste tem motivo e vira movimentação) — apoia P4
SELECT m.dh_movimento, p.nm_produto, m.qt_movimento, m.ds_motivo
  FROM movimentacao_estoque m JOIN produto p USING (id_produto)
 WHERE m.tp_movimento = 'A' AND m.ds_motivo NOT LIKE 'Inventário inicial%'
 ORDER BY m.dh_movimento, p.nm_produto
 LIMIT 40;

-- A17 — Quantos pedidos e itens cada atendente cancelou?
-- Verifica: RN09 (cancelamento de item/pedido fica registrado, não é apagado) — apoia P1
SELECT a.nm_atendente,
       COUNT(DISTINCT CASE WHEN p.tp_status = 'C' THEN p.id_pedido END)               AS pedidos_cancelados,
       COUNT(DISTINCT p.id_pedido)                                                    AS pedidos_total,
       SUM(i.tp_status = 'C' AND p.tp_status <> 'C')                                  AS itens_cancelados_em_pedidos_ativos,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN p.tp_status = 'C' THEN p.id_pedido END) / COUNT(DISTINCT p.id_pedido), 1) AS pct_cancelados
  FROM pedido p JOIN atendente a USING (id_atendente) JOIN pedido_produto i USING (id_pedido)
 GROUP BY a.nm_atendente ORDER BY pedidos_cancelados DESC, a.nm_atendente;

-- A18 — Quanto de taxa de serviço deixou de ser cobrada, por garçom?
-- Verifica: RN16 (taxa de 10%, removível a pedido do cliente) — apoia P1
SELECT a.nm_atendente, COUNT(*) AS pedidos_sem_taxa, ROUND(SUM(ROUND(t.vl_subtotal * 0.10, 2)), 2) AS taxa_nao_cobrada
  FROM pedido p JOIN atendente a USING (id_atendente) JOIN vw_pedido_total t USING (id_pedido)
 WHERE NOT p.in_taxa_servico AND p.tp_status = 'F'
 GROUP BY a.nm_atendente ORDER BY pedidos_sem_taxa DESC;

-- A19 — Qual o fechamento do caixa por dia e forma de pagamento (a nota é emitida na maquininha)?
-- Verifica: RN15, RN25 (fechamento diário compara o total por forma de pagamento) — apoia P6
SELECT DATE(dh_pagamento) AS dia,
       SUM(CASE WHEN tp_forma = 'D' THEN vl_pago END) AS dinheiro,
       SUM(CASE WHEN tp_forma = 'P' THEN vl_pago END) AS pix,
       SUM(CASE WHEN tp_forma = 'C' THEN vl_pago END) AS credito,
       SUM(CASE WHEN tp_forma = 'B' THEN vl_pago END) AS debito,
       SUM(vl_pago)                                   AS total_dia
  FROM pagamento GROUP BY DATE(dh_pagamento) ORDER BY dia;

-- A20 — Quais compras foram feitas, por quem e com qual nota fiscal?
-- Verifica: RN22, RN23 (compra só de fornecedor ativo, feita pela gerência/proprietário, com nota no recebimento) — apoia P2 e P3
SELECT c.id_compra, c.dh_compra, a.nm_atendente AS responsavel, f.nm_fornecedor, c.tp_status, c.nr_nota_fiscal, c.dh_recebimento
  FROM compra c JOIN atendente a USING (id_atendente) JOIN fornecedor f USING (id_fornecedor)
 ORDER BY c.dh_compra;
