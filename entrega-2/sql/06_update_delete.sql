-- =====================================================================
-- 6. UPDATE e DELETE — fluxo completo de um pedido e testes das regras de negócio
-- Tudo roda dentro de uma transação que termina em ROLLBACK: os dados da carga ficam intactos.
-- O "usuário logado" é informado por SET LOCAL app.id_atendente (aqui, via set_config(..., true)).
-- Ids usados: 2 = gerente Patrícia, 4 = garçom Diego, 10 = cozinha Antônio, 13 = bar Renata.
-- =====================================================================
\set ON_ERROR_STOP on
\echo '== PARTE 1 — ciclo de vida de um pedido (INSERT / UPDATE / DELETE) =='
BEGIN;

SELECT set_config('app.id_atendente', '4', true);                       -- garçom Diego
SELECT id_mesa AS v_mesa FROM mesa WHERE tp_status = 'L' AND in_ativa AND tp_local = 'M' ORDER BY nr_mesa LIMIT 1 \gset
INSERT INTO pedido (id_mesa, id_atendente) VALUES (:v_mesa, 4) RETURNING id_pedido AS v_ped \gset
\echo 'Pedido aberto na mesa livre; a mesa passou a ocupada:'
SELECT p.id_pedido, m.nr_mesa, m.tp_status AS status_mesa, p.tp_status AS status_pedido FROM pedido p JOIN mesa m USING (id_mesa) WHERE p.id_pedido = :v_ped;

SELECT id_produto AS v_pizza FROM produto WHERE nm_produto = 'Pizza Calabresa' \gset
SELECT id_produto AS v_agua  FROM produto WHERE nm_produto = 'Água sem gás 500 ml' \gset
SELECT id_produto AS v_cafe  FROM produto WHERE nm_produto = 'Café expresso' \gset
SELECT qt_estoque_atual AS v_estoque_antes FROM produto WHERE id_produto = :v_agua \gset

SELECT lancar_item(:v_ped, :v_pizza, 1);
SELECT lancar_item(:v_ped, :v_agua, 2);
SELECT lancar_item(:v_ped, :v_cafe, 1, 'Sem açúcar');
SELECT lancar_item(:v_ped, :v_agua, 1);                                  -- mesmo produto: soma a quantidade (sem Item_pedido)
\echo 'Itens lançados (água somada: 2 + 1 = 3; preço copiado do cardápio, RN07):'
SELECT pr.nm_produto, i.qt_item, i.vl_preco_unitario, i.tp_status FROM pedido_produto i JOIN produto pr USING (id_produto) WHERE i.id_pedido = :v_ped ORDER BY 1;
\echo 'Estoque da água baixou 3 unidades automaticamente (movimentação do tipo V):'
SELECT :v_estoque_antes AS antes, qt_estoque_atual AS depois FROM produto WHERE id_produto = :v_agua;

-- UPDATE: andamento do item (cozinha/bar) e entrega (garçom)
SELECT set_config('app.id_atendente', '10', true);                       -- cozinheiro
UPDATE pedido_produto SET tp_status = 'E' WHERE id_pedido = :v_ped AND id_produto = :v_pizza;
UPDATE pedido_produto SET tp_status = 'R' WHERE id_pedido = :v_ped AND id_produto = :v_pizza;
SELECT set_config('app.id_atendente', '13', true);                       -- bar
UPDATE pedido_produto SET tp_status = 'E' WHERE id_pedido = :v_ped AND id_produto IN (:v_agua, :v_cafe);
UPDATE pedido_produto SET tp_status = 'R' WHERE id_pedido = :v_ped AND id_produto IN (:v_agua, :v_cafe);
SELECT set_config('app.id_atendente', '4', true);
UPDATE pedido_produto SET tp_status = 'N' WHERE id_pedido = :v_ped AND tp_status = 'R';

-- UPDATE: cancelamento de um item (estorna o estoque) e remoção da taxa a pedido do cliente
SELECT id_produto AS v_coca FROM produto WHERE nm_produto = 'Coca-Cola lata' \gset
SELECT qt_estoque_atual AS v_coca_antes FROM produto WHERE id_produto = :v_coca \gset
SELECT lancar_item(:v_ped, :v_coca, 2);                                   -- cliente pede 2 refrigerantes ...
UPDATE pedido_produto SET tp_status = 'C' WHERE id_pedido = :v_ped AND id_produto = :v_coca;   -- ... e desiste antes do preparo
\echo 'Item cancelado: o estoque volta ao valor inicial (baixa V seguida de estorno E):'
SELECT :v_coca_antes AS antes, qt_estoque_atual AS depois FROM produto WHERE id_produto = :v_coca;
UPDATE pedido SET in_taxa_servico = FALSE WHERE id_pedido = :v_ped;
\echo 'Conta sem taxa de serviço:'
SELECT vl_subtotal, vl_taxa, vl_total FROM vw_pedido_total WHERE id_pedido = :v_ped;
UPDATE pedido SET in_taxa_servico = TRUE WHERE id_pedido = :v_ped;

-- pagamento dividido e fechamento
SELECT vl_total AS v_total FROM vw_pedido_total WHERE id_pedido = :v_ped \gset
INSERT INTO pagamento (id_pedido, tp_forma, vl_pago) VALUES (:v_ped, 'P', ROUND(:v_total / 2, 2)), (:v_ped, 'C', :v_total - ROUND(:v_total / 2, 2));
UPDATE pedido SET tp_status = 'F' WHERE id_pedido = :v_ped;
\echo 'Pedido fechado; mesa liberada automaticamente:'
SELECT p.id_pedido, p.tp_status, p.dh_fechamento IS NOT NULL AS fechado, m.tp_status AS status_mesa FROM pedido p JOIN mesa m USING (id_mesa) WHERE p.id_pedido = :v_ped;

-- UPDATE de cadastro: reajuste de preço com histórico, desligamento de atendente, recebimento de compra
SELECT set_config('app.id_atendente', '2', true);                       -- gerente
UPDATE produto SET vl_preco = 64.00 WHERE id_produto = :v_pizza;
\echo 'Histórico de preço gerado automaticamente (responsável = gerente logado):'
SELECT h.vl_preco_anterior, h.vl_preco_novo, a.nm_atendente FROM historico_produto h JOIN atendente a USING (id_atendente)
 WHERE h.id_produto = :v_pizza ORDER BY h.id_historico DESC LIMIT 1;
UPDATE atendente SET in_ativo = FALSE WHERE nm_login = 'rafael.vieira';
SELECT id_compra AS v_compra FROM compra WHERE tp_status = 'P' LIMIT 1 \gset
UPDATE compra SET tp_status = 'R', nr_nota_fiscal = '049999' WHERE id_compra = :v_compra;
\echo 'Compra pendente recebida: itens entraram no estoque (movimentações tipo C):'
SELECT p.nm_produto, m.qt_movimento, m.ds_motivo FROM movimentacao_estoque m JOIN produto p USING (id_produto) WHERE m.id_compra = :v_compra ORDER BY 1;

-- DELETE permitido: reserva cancelada e item de compra ainda pendente
\echo 'DELETE de reservas canceladas:'
DELETE FROM reserva WHERE tp_status = 'C' RETURNING id_reserva, nm_cliente;
INSERT INTO compra (id_fornecedor, id_atendente) SELECT id_fornecedor, 2 FROM fornecedor ORDER BY id_fornecedor LIMIT 1 RETURNING id_compra AS v_c2 \gset
INSERT INTO compra_produto (id_compra, id_produto, qt_comprada, vl_custo_unitario)
  SELECT :v_c2, id_produto, 10, 5.00 FROM produto WHERE in_controla_estoque ORDER BY id_produto LIMIT 2;
\echo 'DELETE de item de uma compra ainda pendente (permitido) e da compra vazia:'
DELETE FROM compra_produto WHERE id_compra = :v_c2 AND id_produto = (SELECT MIN(id_produto) FROM compra_produto WHERE id_compra = :v_c2) RETURNING id_compra, id_produto;
DELETE FROM compra_produto WHERE id_compra = :v_c2 RETURNING id_compra, id_produto;
DELETE FROM compra WHERE id_compra = :v_c2 RETURNING id_compra;

ROLLBACK;
\echo '(ROLLBACK: nada acima foi gravado)'

\echo
\echo '== PARTE 2 — operações que o banco deve BLOQUEAR (cada linha mostra a regra aplicada) =='
BEGIN;
DO $$
DECLARE v_ocup INT; v_livre INT; v_ped INT; v_pizza INT; v_ins INT; v_ctrl INT; v_pg INT;
BEGIN
  SELECT id_mesa INTO v_ocup  FROM mesa WHERE tp_status = 'O' LIMIT 1;
  SELECT id_mesa INTO v_livre FROM mesa WHERE tp_status = 'L' AND in_ativa LIMIT 1;
  SELECT id_pedido INTO v_ped FROM pedido WHERE tp_status = 'A' LIMIT 1;
  SELECT id_produto INTO v_pizza FROM produto WHERE nm_produto = 'Pizza Calabresa';
  SELECT id_produto INTO v_ins   FROM produto WHERE NOT in_vendavel LIMIT 1;
  SELECT id_produto INTO v_ctrl  FROM produto WHERE nm_produto = 'Heineken long neck';
  SELECT id_pagamento INTO v_pg  FROM pagamento LIMIT 1;

  BEGIN INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_ocup, 4); RAISE NOTICE 'FALHA: abriu pedido em mesa ocupada';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  1. %', SQLERRM; END;

  BEGIN INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_livre, 10); RAISE NOTICE 'FALHA: cozinheiro abriu pedido';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  2. %', SQLERRM; END;

  BEGIN INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_livre, 9); RAISE NOTICE 'FALHA: atendente inativo abriu pedido';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  3. %', SQLERRM; END;

  BEGIN PERFORM lancar_item(v_ped, v_ins, 1); RAISE NOTICE 'FALHA: vendeu insumo';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  4. %', SQLERRM; END;

  BEGIN PERFORM lancar_item(v_ped, v_ctrl, 30000); RAISE NOTICE 'FALHA: vendeu acima do estoque';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  5. %', SQLERRM; END;

  PERFORM set_config('app.id_atendente', '4', true);
  BEGIN UPDATE produto SET vl_preco = 1 WHERE id_produto = v_pizza; RAISE NOTICE 'FALHA: garçom alterou preço';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  6. %', SQLERRM; END;

  BEGIN INSERT INTO movimentacao_estoque (id_produto, tp_movimento, qt_movimento, ds_motivo) VALUES (v_ctrl, 'A', -1, 'teste');
        RAISE NOTICE 'FALHA: garçom ajustou estoque';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  7. %', SQLERRM; END;

  BEGIN UPDATE pedido SET tp_status = 'F' WHERE id_pedido = v_ped; RAISE NOTICE 'FALHA: fechou pedido com itens pendentes/sem pagamento';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  8. %', SQLERRM; END;

  BEGIN INSERT INTO pagamento (id_pedido, tp_forma, vl_pago) VALUES (v_ped, 'P', 999999); RAISE NOTICE 'FALHA: pagamento acima do total';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK  9. %', SQLERRM; END;

  BEGIN UPDATE pagamento SET vl_pago = 1 WHERE id_pagamento = v_pg; RAISE NOTICE 'FALHA: alterou pagamento';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK 10. %', SQLERRM; END;

  BEGIN DELETE FROM pedido WHERE id_pedido = v_ped; RAISE NOTICE 'FALHA: excluiu pedido';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK 11. %', SQLERRM; END;

  BEGIN DELETE FROM movimentacao_estoque WHERE id_movimentacao = 1; RAISE NOTICE 'FALHA: excluiu movimentação';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK 12. %', SQLERRM; END;

  BEGIN INSERT INTO produto (id_setor, id_categoria, nm_produto, nr_codigo_barras, vl_preco, in_vendavel)
        SELECT id_setor, id_categoria, 'Produto duplicado', nr_codigo_barras, 10, TRUE FROM produto WHERE id_produto = v_pizza;
        RAISE NOTICE 'FALHA: código de barras duplicado';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK 13. %', SQLERRM; END;

  BEGIN INSERT INTO produto (id_setor, id_categoria, nm_produto, nr_codigo_barras, vl_preco, in_vendavel)
        VALUES (1, 1, 'Produto no salão', '7890000000017', 10, TRUE); RAISE NOTICE 'FALHA: produto em setor sem preparo';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK 14. %', SQLERRM; END;

  BEGIN INSERT INTO reserva (id_mesa, nm_cliente, dh_reserva, qt_pessoas) SELECT id_mesa, 'Teste', now() + INTERVAL '1 day', 20 FROM mesa LIMIT 1;
        RAISE NOTICE 'FALHA: reserva acima da capacidade';
  EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'OK 15. %', SQLERRM; END;
END $$;
ROLLBACK;
