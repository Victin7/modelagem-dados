-- =====================================================================
-- 6. UPDATE e DELETE — fluxo completo de um pedido e testes das regras de negócio (MySQL 8.0)
-- Tudo roda dentro de uma transação que termina em ROLLBACK: os dados da carga ficam intactos.
-- O "usuário logado" é informado pela variável de sessão @id_atendente (o Garçom Web faz isso ao logar).
-- Ids usados: 2 = gerente Patrícia, 4 = garçom Diego, 10 = cozinha Antônio, 13 = bar Renata.
-- =====================================================================
USE palazio_del_chef;
SET NAMES utf8mb4;

SELECT '== PARTE 1 — ciclo de vida de um pedido (INSERT / UPDATE / DELETE) ==' AS etapa;
START TRANSACTION;

SET @id_atendente = 4;                                                  -- garçom Diego
SET @v_mesa = (SELECT id_mesa FROM mesa WHERE tp_status = 'L' AND in_ativa AND tp_local = 'M' ORDER BY nr_mesa LIMIT 1);
INSERT INTO pedido (id_mesa, id_atendente) VALUES (@v_mesa, 4);
SET @v_ped = LAST_INSERT_ID();
SELECT 'Pedido aberto na mesa livre; a mesa passou a ocupada:' AS etapa;
SELECT p.id_pedido, m.nr_mesa, m.tp_status AS status_mesa, p.tp_status AS status_pedido FROM pedido p JOIN mesa m USING (id_mesa) WHERE p.id_pedido = @v_ped;

SET @v_pizza = (SELECT id_produto FROM produto WHERE nm_produto = 'Pizza Calabresa');
SET @v_agua  = (SELECT id_produto FROM produto WHERE nm_produto = 'Água sem gás 500 ml');
SET @v_cafe  = (SELECT id_produto FROM produto WHERE nm_produto = 'Café expresso');
SET @v_estoque_antes = (SELECT qt_estoque_atual FROM produto WHERE id_produto = @v_agua);

CALL sp_lancar_item(@v_ped, @v_pizza, 1, NULL);
CALL sp_lancar_item(@v_ped, @v_agua, 2, NULL);
CALL sp_lancar_item(@v_ped, @v_cafe, 1, 'Sem açúcar');
CALL sp_lancar_item(@v_ped, @v_agua, 1, NULL);                           -- mesmo produto: soma a quantidade (sem Item_pedido)
SELECT 'Itens lançados (água somada: 2 + 1 = 3; preço copiado do cardápio, RN07):' AS etapa;
SELECT pr.nm_produto, i.qt_item, i.vl_preco_unitario, i.tp_status FROM pedido_produto i JOIN produto pr USING (id_produto) WHERE i.id_pedido = @v_ped ORDER BY 1;
SELECT 'Estoque da água baixou 3 unidades automaticamente (movimentação do tipo V):' AS etapa;
SELECT @v_estoque_antes AS antes, qt_estoque_atual AS depois FROM produto WHERE id_produto = @v_agua;

-- UPDATE: andamento do item (cozinha/bar) e entrega (garçom)
SET @id_atendente = 10;                                                  -- cozinheiro
UPDATE pedido_produto SET tp_status = 'E' WHERE id_pedido = @v_ped AND id_produto = @v_pizza;
UPDATE pedido_produto SET tp_status = 'R' WHERE id_pedido = @v_ped AND id_produto = @v_pizza;
SET @id_atendente = 13;                                                  -- bar
UPDATE pedido_produto SET tp_status = 'E' WHERE id_pedido = @v_ped AND id_produto IN (@v_agua, @v_cafe);
UPDATE pedido_produto SET tp_status = 'R' WHERE id_pedido = @v_ped AND id_produto IN (@v_agua, @v_cafe);
SET @id_atendente = 4;
UPDATE pedido_produto SET tp_status = 'N' WHERE id_pedido = @v_ped AND tp_status = 'R';

-- UPDATE: cancelamento de um item (estorna o estoque) e remoção da taxa a pedido do cliente
SET @v_coca = (SELECT id_produto FROM produto WHERE nm_produto = 'Coca-Cola lata');
SET @v_coca_antes = (SELECT qt_estoque_atual FROM produto WHERE id_produto = @v_coca);
CALL sp_lancar_item(@v_ped, @v_coca, 2, NULL);                           -- cliente pede 2 refrigerantes ...
UPDATE pedido_produto SET tp_status = 'C' WHERE id_pedido = @v_ped AND id_produto = @v_coca;   -- ... e desiste antes do preparo
SELECT 'Item cancelado: o estoque volta ao valor inicial (baixa V seguida de estorno E):' AS etapa;
SELECT @v_coca_antes AS antes, qt_estoque_atual AS depois FROM produto WHERE id_produto = @v_coca;
UPDATE pedido SET in_taxa_servico = FALSE WHERE id_pedido = @v_ped;
SELECT 'Conta sem taxa de serviço:' AS etapa;
SELECT vl_subtotal, vl_taxa, vl_total FROM vw_pedido_total WHERE id_pedido = @v_ped;
UPDATE pedido SET in_taxa_servico = TRUE WHERE id_pedido = @v_ped;

-- pagamento dividido e fechamento
SET @v_total = (SELECT vl_total FROM vw_pedido_total WHERE id_pedido = @v_ped);
INSERT INTO pagamento (id_pedido, tp_forma, vl_pago) VALUES (@v_ped, 'P', ROUND(@v_total / 2, 2)), (@v_ped, 'C', @v_total - ROUND(@v_total / 2, 2));
UPDATE pedido SET tp_status = 'F' WHERE id_pedido = @v_ped;
SELECT 'Pedido fechado; mesa liberada automaticamente:' AS etapa;
SELECT p.id_pedido, p.tp_status, p.dh_fechamento IS NOT NULL AS fechado, m.tp_status AS status_mesa FROM pedido p JOIN mesa m USING (id_mesa) WHERE p.id_pedido = @v_ped;

-- UPDATE de cadastro: reajuste de preço com histórico, desligamento de atendente, recebimento de compra
SET @id_atendente = 2;                                                  -- gerente
UPDATE produto SET vl_preco = 64.00 WHERE id_produto = @v_pizza;
SELECT 'Histórico de preço gerado automaticamente (responsável = gerente logado):' AS etapa;
SELECT h.vl_preco_anterior, h.vl_preco_novo, a.nm_atendente FROM historico_produto h JOIN atendente a USING (id_atendente)
 WHERE h.id_produto = @v_pizza ORDER BY h.id_historico DESC LIMIT 1;
UPDATE atendente SET in_ativo = FALSE WHERE nm_login = 'rafael.vieira';
SET @v_compra = (SELECT id_compra FROM compra WHERE tp_status = 'P' LIMIT 1);
UPDATE compra SET tp_status = 'R', nr_nota_fiscal = '049999' WHERE id_compra = @v_compra;
SELECT 'Compra pendente recebida: itens entraram no estoque (movimentações tipo C):' AS etapa;
SELECT p.nm_produto, m.qt_movimento, m.ds_motivo FROM movimentacao_estoque m JOIN produto p USING (id_produto) WHERE m.id_compra = @v_compra ORDER BY 1;

-- DELETE permitido: reserva cancelada e item de compra ainda pendente
SELECT 'DELETE de reservas canceladas (estas linhas serão removidas):' AS etapa;
SELECT id_reserva, nm_cliente FROM reserva WHERE tp_status = 'C';
DELETE FROM reserva WHERE tp_status = 'C';
INSERT INTO compra (id_fornecedor, id_atendente) SELECT id_fornecedor, 2 FROM fornecedor ORDER BY id_fornecedor LIMIT 1;
SET @v_c2 = LAST_INSERT_ID();
INSERT INTO compra_produto (id_compra, id_produto, qt_comprada, vl_custo_unitario)
  SELECT @v_c2, id_produto, 10, 5.00 FROM produto WHERE in_controla_estoque ORDER BY id_produto LIMIT 2;
SELECT 'DELETE de item de uma compra ainda pendente (permitido) e da compra vazia:' AS etapa;
DELETE FROM compra_produto WHERE id_compra = @v_c2 ORDER BY id_produto LIMIT 1;
DELETE FROM compra_produto WHERE id_compra = @v_c2;
DELETE FROM compra WHERE id_compra = @v_c2;
SELECT COUNT(*) AS itens_restantes_da_compra_teste FROM compra_produto WHERE id_compra = @v_c2;

ROLLBACK;
SELECT '(ROLLBACK: nada acima foi gravado)' AS etapa;

SELECT '== PARTE 2 — operações que o banco deve BLOQUEAR (cada linha mostra a regra aplicada) ==' AS etapa;

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_testes_bloqueio$$
CREATE PROCEDURE sp_testes_bloqueio()
BEGIN
  DECLARE v_ocup INT; DECLARE v_livre INT; DECLARE v_ped INT; DECLARE v_pizza INT; DECLARE v_ins INT;
  DECLARE v_ctrl INT; DECLARE v_pg INT; DECLARE v_msg TEXT DEFAULT '';
  DROP TEMPORARY TABLE IF EXISTS t_testes;
  CREATE TEMPORARY TABLE t_testes (n INT, resultado VARCHAR(6), mensagem TEXT);

  SET v_ocup  = (SELECT id_mesa FROM mesa WHERE tp_status = 'O' LIMIT 1);
  SET v_livre = (SELECT id_mesa FROM mesa WHERE tp_status = 'L' AND in_ativa LIMIT 1);
  SET v_ped   = (SELECT id_pedido FROM pedido WHERE tp_status = 'A' LIMIT 1);
  SET v_pizza = (SELECT id_produto FROM produto WHERE nm_produto = 'Pizza Calabresa');
  SET v_ins   = (SELECT id_produto FROM produto WHERE NOT in_vendavel LIMIT 1);
  SET v_ctrl  = (SELECT id_produto FROM produto WHERE nm_produto = 'Heineken long neck');
  SET v_pg    = (SELECT id_pagamento FROM pagamento LIMIT 1);

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (1, 'OK', v_msg); END;
    INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_ocup, 4); INSERT INTO t_testes VALUES (1, 'FALHA', 'abriu pedido em mesa ocupada'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (2, 'OK', v_msg); END;
    INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_livre, 10); INSERT INTO t_testes VALUES (2, 'FALHA', 'cozinheiro abriu pedido'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (3, 'OK', v_msg); END;
    INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_livre, 9); INSERT INTO t_testes VALUES (3, 'FALHA', 'atendente inativo abriu pedido'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (4, 'OK', v_msg); END;
    CALL sp_lancar_item(v_ped, v_ins, 1, NULL); INSERT INTO t_testes VALUES (4, 'FALHA', 'vendeu insumo'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (5, 'OK', v_msg); END;
    CALL sp_lancar_item(v_ped, v_ctrl, 30000, NULL); INSERT INTO t_testes VALUES (5, 'FALHA', 'vendeu acima do estoque'); END;

  SET @id_atendente = 4;
  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (6, 'OK', v_msg); END;
    UPDATE produto SET vl_preco = 1 WHERE id_produto = v_pizza; INSERT INTO t_testes VALUES (6, 'FALHA', 'garçom alterou preço'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (7, 'OK', v_msg); END;
    INSERT INTO movimentacao_estoque (id_produto, tp_movimento, qt_movimento, ds_motivo) VALUES (v_ctrl, 'A', -1, 'teste');
    INSERT INTO t_testes VALUES (7, 'FALHA', 'garçom ajustou estoque'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (8, 'OK', v_msg); END;
    UPDATE pedido SET tp_status = 'F' WHERE id_pedido = v_ped; INSERT INTO t_testes VALUES (8, 'FALHA', 'fechou pedido com itens pendentes/sem pagamento'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (9, 'OK', v_msg); END;
    INSERT INTO pagamento (id_pedido, tp_forma, vl_pago) VALUES (v_ped, 'P', 999999); INSERT INTO t_testes VALUES (9, 'FALHA', 'pagamento acima do total'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (10, 'OK', v_msg); END;
    UPDATE pagamento SET vl_pago = 1 WHERE id_pagamento = v_pg; INSERT INTO t_testes VALUES (10, 'FALHA', 'alterou pagamento'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (11, 'OK', v_msg); END;
    DELETE FROM pedido WHERE id_pedido = v_ped; INSERT INTO t_testes VALUES (11, 'FALHA', 'excluiu pedido'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (12, 'OK', v_msg); END;
    DELETE FROM movimentacao_estoque WHERE id_movimentacao = 1; INSERT INTO t_testes VALUES (12, 'FALHA', 'excluiu movimentação'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (13, 'OK', v_msg); END;
    INSERT INTO produto (id_setor, id_categoria, nm_produto, nr_codigo_barras, vl_preco, in_vendavel)
      SELECT id_setor, id_categoria, 'Produto duplicado', nr_codigo_barras, 10, TRUE FROM produto WHERE id_produto = v_pizza;
    INSERT INTO t_testes VALUES (13, 'FALHA', 'código de barras duplicado'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (14, 'OK', v_msg); END;
    INSERT INTO produto (id_setor, id_categoria, nm_produto, nr_codigo_barras, vl_preco, in_vendavel)
      VALUES (1, 1, 'Produto no salão', '7890000000017', 10, TRUE); INSERT INTO t_testes VALUES (14, 'FALHA', 'produto em setor sem preparo'); END;

  BEGIN DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT; INSERT INTO t_testes VALUES (15, 'OK', v_msg); END;
    INSERT INTO reserva (id_mesa, nm_cliente, dh_reserva, qt_pessoas) SELECT id_mesa, 'Teste', NOW() + INTERVAL 1 DAY, 20 FROM mesa LIMIT 1;
    INSERT INTO t_testes VALUES (15, 'FALHA', 'reserva acima da capacidade'); END;

  SELECT n, resultado, mensagem FROM t_testes ORDER BY n;
END$$
DELIMITER ;

START TRANSACTION;
CALL sp_testes_bloqueio();
ROLLBACK;
DROP PROCEDURE sp_testes_bloqueio;
