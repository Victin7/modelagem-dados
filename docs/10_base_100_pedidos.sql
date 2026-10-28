-- =====================================================================
-- Base enxuta para apresentação (MySQL 8.0): mantém só os 100 pedidos mais recentes.
-- Rodar DEPOIS do script.sql:   source 10_base_100_pedidos.sql
-- Mantém os pedidos 1550 a 1649 (inclui os 27 abertos) com seus itens, pagamentos e
-- baixas de estoque; remove o histórico anterior e recalcula o estoque a partir das
-- movimentações que sobraram (compras + vendas mantidas), para o banco continuar consistente.
-- Obs.: o banco bloqueia DELETE nessas tabelas (preservação do histórico). Esta é uma manutenção
--       excepcional para a apresentação: remove os 4 triggers de bloqueio, apaga e RECRIA os mesmos triggers.
-- =====================================================================
USE palazio_del_chef;
SET NAMES utf8mb4;
SET @corte = (SELECT MIN(id_pedido) FROM (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 100) t);

-- 1) libera a exclusão temporariamente
DROP TRIGGER IF EXISTS trg_nodel_pedido;
DROP TRIGGER IF EXISTS trg_nodel_pp;
DROP TRIGGER IF EXISTS trg_nodel_pagto;
DROP TRIGGER IF EXISTS trg_nodel_mov;

-- 2) apaga o histórico anterior (ordem: filhos antes do pedido)
DELETE FROM pagamento            WHERE id_pedido < @corte;
DELETE FROM movimentacao_estoque WHERE id_pedido < @corte;
DELETE FROM pedido_produto       WHERE id_pedido < @corte;
DELETE FROM pedido               WHERE id_pedido < @corte;

-- 3) restaura a proteção do histórico (mesmos triggers do arquivo 04)
CREATE TRIGGER trg_nodel_pedido BEFORE DELETE ON pedido FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em pedido: use cancelamento/inativação para preservar o histórico';
CREATE TRIGGER trg_nodel_pp BEFORE DELETE ON pedido_produto FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em pedido_produto: use cancelamento/inativação para preservar o histórico';
CREATE TRIGGER trg_nodel_pagto BEFORE DELETE ON pagamento FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em pagamento: use cancelamento/inativação para preservar o histórico';
CREATE TRIGGER trg_nodel_mov BEFORE DELETE ON movimentacao_estoque FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em movimentacao_estoque: use cancelamento/inativação para preservar o histórico';

-- 4) estoque = soma das movimentações restantes (única fonte de verdade, RN08)
UPDATE produto p SET qt_estoque_atual =
    (SELECT COALESCE(SUM(m.qt_movimento), 0) FROM movimentacao_estoque m WHERE m.id_produto = p.id_produto)
 WHERE p.in_controla_estoque;

SELECT COUNT(*) AS pedidos,
       SUM(tp_status = 'F') AS fechados, SUM(tp_status = 'A') AS abertos, SUM(tp_status = 'C') AS cancelados,
       (SELECT COUNT(*) FROM pedido_produto) AS itens,
       (SELECT COUNT(*) FROM pagamento) AS pagamentos
  FROM pedido;
