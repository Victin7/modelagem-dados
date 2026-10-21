USE palazio_del_chef;
-- =====================================================================
-- 5. SELECT com JOIN (MySQL 8.0) (consultas operacionais do dia a dia)
-- =====================================================================

-- 5.1 Comanda completa de um pedido (pedido × mesa × atendente × itens × produto)
SELECT p.id_pedido, m.nr_mesa, m.tp_local, a.nm_atendente AS garcom, pr.nm_produto, i.qt_item, i.vl_preco_unitario,
       i.qt_item * i.vl_preco_unitario AS vl_linha, i.tp_status
  FROM pedido p
  JOIN mesa m             ON m.id_mesa     = p.id_mesa
  JOIN atendente a        ON a.id_atendente = p.id_atendente
  JOIN pedido_produto i   ON i.id_pedido   = p.id_pedido
  JOIN produto pr         ON pr.id_produto = i.id_produto
 WHERE p.id_pedido = 1000
 ORDER BY pr.nm_produto;

-- 5.2 Conta do pedido: subtotal, taxa de serviço, total, pago (view sobre a regra RN16)
SELECT t.id_pedido, m.nr_mesa, t.vl_subtotal, t.vl_taxa, t.vl_total, t.vl_pago
  FROM vw_pedido_total t JOIN mesa m USING (id_mesa)
 WHERE t.id_pedido IN (1000, 1001, 1002);

-- 5.3 Mesas ocupadas agora, com garçom, tempo de permanência e consumo parcial (referência 12/10/2026 21:20)
SELECT m.nr_mesa, m.tp_local, a.nm_atendente AS garcom, p.dh_abertura,
       ROUND(TIMESTAMPDIFF(SECOND, p.dh_abertura, '2026-10-12 21:20:00') / 60) AS minutos_na_mesa,
       t.vl_subtotal
  FROM mesa m
  JOIN pedido p          ON p.id_mesa = m.id_mesa AND p.tp_status = 'A'
  JOIN atendente a       ON a.id_atendente = p.id_atendente
  JOIN vw_pedido_total t ON t.id_pedido = p.id_pedido
 WHERE m.tp_status = 'O'
 ORDER BY p.dh_abertura;

-- 5.4 Fila de preparo da cozinha e do bar (itens pendentes / em preparo)
SELECT nm_setor, nr_mesa, nm_produto, qt_item, tp_status, dh_registro
  FROM vw_fila_preparo ORDER BY nm_setor, dh_registro LIMIT 20;

-- 5.5 Cardápio com categoria, setor e preço vigente (somente produtos vendáveis e ativos)
SELECT c.nm_categoria, pr.nm_produto, s.nm_setor, pr.vl_preco, pr.in_alcoolico AS alcoolico
  FROM produto pr
  JOIN categoria c ON c.id_categoria = pr.id_categoria
  JOIN setor s     ON s.id_setor     = pr.id_setor
 WHERE pr.in_vendavel AND pr.in_ativo
 ORDER BY c.id_categoria, pr.nm_produto;

-- 5.6 Produtos com estoque crítico e último fornecedor (produto × compra_produto × compra × fornecedor)
SELECT e.nm_produto, e.qt_estoque_atual, e.qt_estoque_minimo, f.nm_fornecedor AS ultimo_fornecedor, c.dh_recebimento AS ultima_entrada
  FROM vw_estoque_critico e
  LEFT JOIN compra c ON c.id_compra = (SELECT cp.id_compra FROM compra_produto cp JOIN compra c2 ON c2.id_compra = cp.id_compra
                                        WHERE cp.id_produto = e.id_produto AND c2.tp_status = 'R'
                                        ORDER BY c2.dh_recebimento DESC LIMIT 1)
  LEFT JOIN fornecedor f ON f.id_fornecedor = c.id_fornecedor
 ORDER BY e.nm_produto;

-- 5.7 Compras com seus itens (fornecedor × compra × compra_produto × produto), valor total por nota
SELECT c.id_compra, c.nr_nota_fiscal, c.tp_status, f.nm_fornecedor, COUNT(*) AS itens,
       SUM(cp.qt_comprada * cp.vl_custo_unitario) AS vl_total_compra
  FROM compra c
  JOIN fornecedor f     ON f.id_fornecedor = c.id_fornecedor
  JOIN compra_produto cp ON cp.id_compra   = c.id_compra
 GROUP BY c.id_compra, c.nr_nota_fiscal, c.tp_status, f.nm_fornecedor
 ORDER BY c.dh_compra;

-- 5.8 Extrato de movimentação de um produto (venda, compra, estorno, ajuste) com saldo acumulado
SELECT m.dh_movimento, m.tp_movimento, m.qt_movimento,
       SUM(m.qt_movimento) OVER (ORDER BY m.dh_movimento, m.id_movimentacao) AS saldo,
       COALESCE(CONCAT('pedido ', m.id_pedido), CONCAT('compra ', m.id_compra), m.ds_motivo) AS origem
  FROM movimentacao_estoque m JOIN produto p USING (id_produto)
 WHERE p.nm_produto = 'Heineken long neck'
 ORDER BY m.dh_movimento, m.id_movimentacao
 LIMIT 15;

-- 5.9 Reservas ativas com a mesa e a capacidade (reserva × mesa)
SELECT r.dh_reserva, r.nm_cliente, r.qt_pessoas, m.nr_mesa, m.tp_local, m.qt_lugares
  FROM reserva r JOIN mesa m USING (id_mesa)
 WHERE r.tp_status = 'A' ORDER BY r.dh_reserva;

-- 5.10 Pedidos sem itens entregues há mais de 45 min (pedidos × itens), com LEFT JOIN para achar pedidos vazios
SELECT p.id_pedido, m.nr_mesa, p.dh_abertura, COUNT(i.id_produto) AS itens
  FROM pedido p JOIN mesa m USING (id_mesa)
  LEFT JOIN pedido_produto i ON i.id_pedido = p.id_pedido AND i.tp_status <> 'C'
 WHERE p.tp_status = 'A'
 GROUP BY p.id_pedido, m.nr_mesa, p.dh_abertura
HAVING COUNT(i.id_produto) = 0;
