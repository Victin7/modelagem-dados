-- =====================================================================
-- Regras de negócio no banco: funções, procedures, triggers e views (MySQL 8.0)
-- Criadas DEPOIS da carga de dados (arquivo 03): a carga histórica tem datas passadas e já
-- chega consistente; daqui em diante, toda operação nova passa pelas regras.
-- Usuário responsável: a aplicação (Garçom Web) informa quem opera com
--     SET @id_atendente = <id>;      (variável de sessão)
-- Obs.: mensagens de erro (SIGNAL) têm no máximo 128 caracteres no MySQL, e o SIGNAL exige valor simples:
--       por isso as mensagens montadas com CONCAT passam pela variável de sessão @erro.
-- Obs.: os comandos DELIMITER são do cliente mysql/Workbench (não são SQL do servidor).
-- =====================================================================
USE palazio_del_chef;
SET NAMES utf8mb4;

DELIMITER $$

-- ---------- Procedures e funções auxiliares ----------
-- exige usuário identificado, ativo e de um dos perfis informados (ex.: 'GS' = gerência ou sócio)
DROP PROCEDURE IF EXISTS sp_exige_perfil$$
CREATE PROCEDURE sp_exige_perfil(IN p_perfis VARCHAR(10), IN p_acao VARCHAR(40),
                                 OUT o_id INT, OUT o_perfil CHAR(1), OUT o_setor SMALLINT)
BEGIN
    DECLARE v_ativo BOOLEAN;
    SET o_id = NULL;
    IF @id_atendente IS NOT NULL THEN
        SELECT id_atendente, tp_perfil, id_setor, in_ativo INTO o_id, o_perfil, o_setor, v_ativo
          FROM atendente WHERE id_atendente = @id_atendente;
    END IF;
    IF o_id IS NULL THEN
        SET @erro = CONCAT('Operação "', p_acao, '" exige usuário identificado (SET @id_atendente)');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NOT v_ativo OR LOCATE(o_perfil, p_perfis) = 0 THEN
        SET @erro = CONCAT('Perfil ', o_perfil, ' (atendente ', o_id, ') não autorizado para "', p_acao, '"');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

-- subtotal do pedido = itens não cancelados
DROP FUNCTION IF EXISTS fn_subtotal_pedido$$
CREATE FUNCTION fn_subtotal_pedido(p_id INT) RETURNS DECIMAL(10,2) READS SQL DATA
BEGIN
    DECLARE v DECIMAL(10,2);
    SELECT COALESCE(SUM(CASE WHEN tp_status <> 'C' THEN qt_item * vl_preco_unitario END), 0) INTO v
      FROM pedido_produto WHERE id_pedido = p_id;
    RETURN v;
END$$

-- valor total = subtotal + taxa de serviço de 10% (RN16), quando cobrada
DROP FUNCTION IF EXISTS fn_total_pedido$$
CREATE FUNCTION fn_total_pedido(p_id INT) RETURNS DECIMAL(10,2) READS SQL DATA
BEGIN
    DECLARE v_sub DECIMAL(10,2); DECLARE v_taxa BOOLEAN;
    SET v_sub = fn_subtotal_pedido(p_id);
    SELECT in_taxa_servico INTO v_taxa FROM pedido WHERE id_pedido = p_id;
    RETURN v_sub + IF(v_taxa, ROUND(v_sub * 0.10, 2), 0);
END$$

-- quantidade efetiva (item cancelado não conta) usada para baixa/estorno de estoque
DROP FUNCTION IF EXISTS fn_qtd_efetiva$$
CREATE FUNCTION fn_qtd_efetiva(p_qt INT, p_status CHAR(1)) RETURNS INT DETERMINISTIC
BEGIN
    RETURN IF(p_status = 'C', 0, COALESCE(p_qt, 0));
END$$

-- ---------- Atendente: admissão não pode ser futura ----------
DROP TRIGGER IF EXISTS trg_atendente_bi$$
CREATE TRIGGER trg_atendente_bi BEFORE INSERT ON atendente FOR EACH ROW
BEGIN
    IF NEW.dt_admissao > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de admissão não pode ser futura';
    END IF;
END$$

-- ---------- SETOR de produto deve ser de preparo (RN06) ----------
DROP TRIGGER IF EXISTS trg_produto_bi$$
CREATE TRIGGER trg_produto_bi BEFORE INSERT ON produto FOR EACH ROW
BEGIN
    IF NOT (SELECT in_preparo FROM setor WHERE id_setor = NEW.id_setor) THEN
        SET @erro = CONCAT('RN06: produto "', NEW.nm_produto, '" deve pertencer a um setor de preparo');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

-- ---------- Alteração de preço: só gerência/sócio e gera histórico; setor continua sendo de preparo ----------
DROP TRIGGER IF EXISTS trg_produto_bu$$
CREATE TRIGGER trg_produto_bu BEFORE UPDATE ON produto FOR EACH ROW
BEGIN
    DECLARE v_id INT; DECLARE v_perfil CHAR(1); DECLARE v_setor SMALLINT;
    IF NEW.id_setor <> OLD.id_setor AND NOT (SELECT in_preparo FROM setor WHERE id_setor = NEW.id_setor) THEN
        SET @erro = CONCAT('RN06: produto "', NEW.nm_produto, '" deve pertencer a um setor de preparo');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.vl_preco <> OLD.vl_preco THEN
        CALL sp_exige_perfil('GS', 'alterar preço', v_id, v_perfil, v_setor);
        INSERT INTO historico_produto (id_produto, id_atendente, vl_preco_anterior, vl_preco_novo)
        VALUES (OLD.id_produto, v_id, OLD.vl_preco, NEW.vl_preco);
    END IF;
END$$

-- ---------- Reserva ----------
DROP TRIGGER IF EXISTS trg_reserva_bi$$
CREATE TRIGGER trg_reserva_bi BEFORE INSERT ON reserva FOR EACH ROW
BEGIN
    DECLARE v_nr SMALLINT; DECLARE v_lug SMALLINT; DECLARE v_ativa BOOLEAN;
    SELECT nr_mesa, qt_lugares, in_ativa INTO v_nr, v_lug, v_ativa FROM mesa WHERE id_mesa = NEW.id_mesa;
    IF NOT v_ativa THEN
        SET @erro = CONCAT('Mesa ', v_nr, ' inativa');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.qt_pessoas > v_lug THEN
        SET @erro = CONCAT('Mesa ', v_nr, ' comporta ', v_lug, ' lugares (reserva de ', NEW.qt_pessoas, ' pessoas)');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.dh_reserva <= NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reserva deve ser para data/hora futura';
    END IF;
    IF NEW.tp_status = 'A' AND EXISTS (SELECT 1 FROM reserva r WHERE r.id_mesa = NEW.id_mesa AND r.tp_status = 'A'
            AND r.dh_reserva BETWEEN NEW.dh_reserva - INTERVAL 2 HOUR AND NEW.dh_reserva + INTERVAL 2 HOUR) THEN
        SET @erro = CONCAT('Mesa ', v_nr, ' já reservada em horário próximo (janela de 2 h)');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

-- ---------- Abertura de pedido (RN01, RN02, RN04, RN05) ----------
DROP TRIGGER IF EXISTS trg_pedido_bi$$
CREATE TRIGGER trg_pedido_bi BEFORE INSERT ON pedido FOR EACH ROW
BEGIN
    DECLARE v_ativo BOOLEAN; DECLARE v_perfil CHAR(1);
    DECLARE v_nr SMALLINT; DECLARE v_mesa_ativa BOOLEAN; DECLARE v_mesa_status CHAR(1);
    SELECT in_ativo, tp_perfil INTO v_ativo, v_perfil FROM atendente WHERE id_atendente = NEW.id_atendente;
    IF NOT v_ativo OR v_perfil NOT IN ('A','G','S') THEN
        SET @erro = CONCAT('RN04: atendente ', NEW.id_atendente, ' não pode abrir pedidos (inativo ou perfil ', v_perfil, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    SELECT nr_mesa, in_ativa, tp_status INTO v_nr, v_mesa_ativa, v_mesa_status FROM mesa WHERE id_mesa = NEW.id_mesa FOR UPDATE;
    IF NOT v_mesa_ativa THEN
        SET @erro = CONCAT('Mesa ', v_nr, ' inativa');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF v_mesa_status <> 'L' THEN
        SET @erro = CONCAT('RN05: mesa ', v_nr, ' já está ocupada');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    SET NEW.tp_status = 'A';
    SET NEW.dh_fechamento = NULL;
    UPDATE mesa SET tp_status = 'O' WHERE id_mesa = NEW.id_mesa;
END$$

-- ---------- Fechamento / cancelamento de pedido (RN10, RN17) ----------
DROP TRIGGER IF EXISTS trg_pedido_bu$$
CREATE TRIGGER trg_pedido_bu BEFORE UPDATE ON pedido FOR EACH ROW
BEGIN
    DECLARE v_sub DECIMAL(10,2); DECLARE v_total DECIMAL(10,2); DECLARE v_pago DECIMAL(10,2);
    IF OLD.tp_status <> 'A' THEN
        SET @erro = CONCAT('Pedido ', OLD.id_pedido, ' já está ', OLD.tp_status, ' e não pode ser alterado');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.id_mesa <> OLD.id_mesa OR NEW.id_atendente <> OLD.id_atendente OR NEW.dh_abertura <> OLD.dh_abertura THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mesa, atendente e abertura do pedido não podem ser alterados';
    END IF;
    IF NEW.tp_status = 'F' THEN
        IF EXISTS (SELECT 1 FROM pedido_produto WHERE id_pedido = OLD.id_pedido AND tp_status IN ('P','E','R')) THEN
            SET @erro = CONCAT('RN10: pedido ', OLD.id_pedido, ' tem itens ainda não entregues');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pedido_produto WHERE id_pedido = OLD.id_pedido AND tp_status = 'N') THEN
            SET @erro = CONCAT('RN10: pedido ', OLD.id_pedido, ' não tem itens entregues; cancele-o');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        SET v_sub = fn_subtotal_pedido(OLD.id_pedido);
        SET v_total = v_sub + IF(NEW.in_taxa_servico, ROUND(v_sub * 0.10, 2), 0);   -- a taxa informada na mesma instrução vale
        SELECT COALESCE(SUM(vl_pago), 0) INTO v_pago FROM pagamento WHERE id_pedido = OLD.id_pedido;
        IF v_pago <> v_total THEN
            SET @erro = CONCAT('RN10: pagamentos (', v_pago, ') diferem do total do pedido (', v_total, ')');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        SET NEW.dh_fechamento = COALESCE(NEW.dh_fechamento, NOW());
        UPDATE mesa SET tp_status = 'L' WHERE id_mesa = OLD.id_mesa;
    ELSEIF NEW.tp_status = 'C' THEN
        IF EXISTS (SELECT 1 FROM pagamento WHERE id_pedido = OLD.id_pedido) THEN
            SET @erro = CONCAT('RN10: pedido ', OLD.id_pedido, ' possui pagamento e não pode ser cancelado');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        IF EXISTS (SELECT 1 FROM pedido_produto WHERE id_pedido = OLD.id_pedido AND tp_status IN ('R','N')) THEN
            SET @erro = CONCAT('RN17: pedido ', OLD.id_pedido, ' tem itens prontos ou entregues e não pode ser cancelado');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        UPDATE pedido_produto SET tp_status = 'C' WHERE id_pedido = OLD.id_pedido AND tp_status <> 'C';
        SET NEW.dh_fechamento = COALESCE(NEW.dh_fechamento, NOW());
        UPDATE mesa SET tp_status = 'L' WHERE id_mesa = OLD.id_mesa;
    END IF;
END$$

-- ---------- Itens do pedido (relacionamento "contém") ----------
DROP TRIGGER IF EXISTS trg_pp_bi$$
CREATE TRIGGER trg_pp_bi BEFORE INSERT ON pedido_produto FOR EACH ROW
BEGIN
    DECLARE v_status CHAR(1); DECLARE v_nome VARCHAR(80); DECLARE v_preco DECIMAL(8,2);
    DECLARE v_ativo BOOLEAN; DECLARE v_vend BOOLEAN; DECLARE v_ctrl BOOLEAN; DECLARE v_estq INT;
    SELECT tp_status INTO v_status FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_status IS NULL OR v_status <> 'A' THEN
        SET @erro = CONCAT('Pedido ', NEW.id_pedido, ' não está aberto');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    SELECT nm_produto, vl_preco, in_ativo, in_vendavel, in_controla_estoque, qt_estoque_atual
      INTO v_nome, v_preco, v_ativo, v_vend, v_ctrl, v_estq FROM produto WHERE id_produto = NEW.id_produto;
    IF NOT v_ativo OR NOT v_vend THEN
        SET @erro = CONCAT('RN14: produto "', v_nome, '" não está disponível para venda');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    SET NEW.tp_status = 'P';
    SET NEW.dh_pronto = NULL;
    SET NEW.vl_preco_unitario = v_preco;                                       -- RN07: copia o preço vigente
    IF v_ctrl AND v_estq < NEW.qt_item THEN                                    -- RN08
        SET @erro = CONCAT('RN08: estoque insuficiente de "', v_nome, '" (disponível ', v_estq, ', pedido ', NEW.qt_item, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_pp_bu$$
CREATE TRIGGER trg_pp_bu BEFORE UPDATE ON pedido_produto FOR EACH ROW
BEGIN
    DECLARE v_status CHAR(1); DECLARE v_nome VARCHAR(80); DECLARE v_preco DECIMAL(8,2);
    DECLARE v_ativo BOOLEAN; DECLARE v_vend BOOLEAN; DECLARE v_ctrl BOOLEAN; DECLARE v_estq INT; DECLARE v_psetor SMALLINT;
    DECLARE v_delta INT; DECLARE v_old_eff INT;
    DECLARE v_id INT; DECLARE v_perfil CHAR(1); DECLARE v_setor SMALLINT;
    SELECT tp_status INTO v_status FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_status IS NULL OR v_status <> 'A' THEN
        SET @erro = CONCAT('Pedido ', NEW.id_pedido, ' não está aberto');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    SELECT nm_produto, vl_preco, in_ativo, in_vendavel, in_controla_estoque, qt_estoque_atual, id_setor
      INTO v_nome, v_preco, v_ativo, v_vend, v_ctrl, v_estq, v_psetor FROM produto WHERE id_produto = NEW.id_produto;

    IF NEW.id_pedido <> OLD.id_pedido OR NEW.id_produto <> OLD.id_produto THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chave do item não pode ser alterada';
    END IF;
    SET v_old_eff = fn_qtd_efetiva(OLD.qt_item, OLD.tp_status);

    IF OLD.tp_status = 'C' AND NEW.tp_status <> 'C' THEN                         -- reativação do item (via sp_lancar_item)
        IF NEW.tp_status <> 'P' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Item cancelado só pode voltar como Pendente';
        END IF;
        IF NOT v_ativo OR NOT v_vend THEN
            SET @erro = CONCAT('RN14: produto "', v_nome, '" não está disponível para venda');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        SET NEW.vl_preco_unitario = v_preco;
        SET NEW.dh_registro = NOW();
        SET NEW.dh_pronto = NULL;
    ELSEIF OLD.tp_status = 'C' THEN
        IF NEW.qt_item <> OLD.qt_item OR NEW.tp_status <> 'C' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Item cancelado não pode ser alterado';
        END IF;
    ELSEIF NEW.tp_status = 'P' AND OLD.tp_status <> 'P' THEN                      -- novo lançamento sobre linha existente
        IF NEW.qt_item <= OLD.qt_item THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Voltar item para Pendente exige aumento de quantidade';
        END IF;
        SET NEW.dh_registro = NOW();
        SET NEW.dh_pronto = NULL;
    ELSEIF CONCAT(OLD.tp_status, NEW.tp_status) NOT IN ('PP','EE','RR','NN','PE','ER','RN','PC','EC') THEN
        SET @erro = CONCAT('RN09/RN17: transição inválida ', OLD.tp_status, '->', NEW.tp_status, ' (item pronto ou entregue não é cancelado)');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.qt_item < OLD.qt_item THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade só pode diminuir por cancelamento do item';
    END IF;
    IF OLD.tp_status <> 'C' AND NEW.vl_preco_unitario <> OLD.vl_preco_unitario THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN07: preço unitário do item não pode ser alterado';
    END IF;
    IF NEW.qt_item > OLD.qt_item AND NEW.tp_status <> 'P' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aumento de quantidade reinicia o item como Pendente';
    END IF;
    -- quem pode mudar o andamento do item
    IF NEW.tp_status <> OLD.tp_status THEN
        IF NEW.tp_status IN ('E','R') THEN
            CALL sp_exige_perfil('PGS', 'preparar item', v_id, v_perfil, v_setor);
            IF v_perfil = 'P' AND v_setor <> v_psetor THEN
                SET @erro = CONCAT('Atendente ', v_id, ' (setor ', v_setor, ') não prepara itens do setor ', v_psetor);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
            END IF;
        ELSEIF NEW.tp_status = 'N' THEN
            CALL sp_exige_perfil('AGS', 'entregar item', v_id, v_perfil, v_setor);
        END IF;
    END IF;

    IF NEW.tp_status = 'R' AND NEW.dh_pronto IS NULL THEN SET NEW.dh_pronto = NOW(); END IF;
    IF NEW.tp_status IN ('P','E','C') THEN SET NEW.dh_pronto = NULL; END IF;

    -- RN08: estoque suficiente para o acréscimo
    SET v_delta = fn_qtd_efetiva(NEW.qt_item, NEW.tp_status) - v_old_eff;
    IF v_delta > 0 AND v_ctrl AND v_estq < v_delta THEN
        SET @erro = CONCAT('RN08: estoque insuficiente de "', v_nome, '" (disponível ', v_estq, ', pedido ', v_delta, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

-- baixa/estorno de estoque conforme a variação da quantidade efetiva do item
DROP PROCEDURE IF EXISTS sp_pp_movimenta$$
CREATE PROCEDURE sp_pp_movimenta(IN p_produto INT, IN p_pedido INT, IN p_old INT, IN p_new INT)
BEGIN
    DECLARE v_delta INT DEFAULT p_new - p_old;
    IF (SELECT in_controla_estoque FROM produto WHERE id_produto = p_produto) THEN
        IF v_delta > 0 THEN
            INSERT INTO movimentacao_estoque (id_produto, id_pedido, tp_movimento, qt_movimento, ds_motivo)
            VALUES (p_produto, p_pedido, 'V', -v_delta, 'Baixa por venda');
        ELSEIF v_delta < 0 THEN
            INSERT INTO movimentacao_estoque (id_produto, id_pedido, tp_movimento, qt_movimento, ds_motivo)
            VALUES (p_produto, p_pedido, 'E', -v_delta, 'Estorno por cancelamento');
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_pp_ai$$
CREATE TRIGGER trg_pp_ai AFTER INSERT ON pedido_produto FOR EACH ROW
BEGIN
    CALL sp_pp_movimenta(NEW.id_produto, NEW.id_pedido, 0, fn_qtd_efetiva(NEW.qt_item, NEW.tp_status));
END$$

DROP TRIGGER IF EXISTS trg_pp_au$$
CREATE TRIGGER trg_pp_au AFTER UPDATE ON pedido_produto FOR EACH ROW
BEGIN
    CALL sp_pp_movimenta(NEW.id_produto, NEW.id_pedido, fn_qtd_efetiva(OLD.qt_item, OLD.tp_status), fn_qtd_efetiva(NEW.qt_item, NEW.tp_status));
END$$

-- Lançamento de item: "upsert" que substitui a antiga entidade Item_pedido.
-- Se o produto já está no pedido, soma a quantidade; se estava cancelado, reativa com o preço vigente.
DROP PROCEDURE IF EXISTS sp_lancar_item$$
CREATE PROCEDURE sp_lancar_item(IN p_pedido INT, IN p_produto INT, IN p_qtd INT, IN p_obs VARCHAR(100))
BEGIN
    DECLARE v_existe INT; DECLARE v_status CHAR(1);
    IF p_qtd IS NULL OR p_qtd <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade deve ser positiva';
    END IF;
    SELECT COUNT(*), MAX(tp_status) INTO v_existe, v_status
      FROM pedido_produto WHERE id_pedido = p_pedido AND id_produto = p_produto FOR UPDATE;
    IF v_existe = 0 THEN
        INSERT INTO pedido_produto (id_pedido, id_produto, qt_item, vl_preco_unitario, ds_observacao)
        VALUES (p_pedido, p_produto, p_qtd, 1, p_obs);              -- o preço real é copiado pelo trigger (RN07)
    ELSEIF v_status = 'C' THEN
        UPDATE pedido_produto SET qt_item = p_qtd, tp_status = 'P', ds_observacao = COALESCE(p_obs, ds_observacao)
         WHERE id_pedido = p_pedido AND id_produto = p_produto;
    ELSE
        UPDATE pedido_produto SET qt_item = qt_item + p_qtd, tp_status = 'P', ds_observacao = COALESCE(p_obs, ds_observacao)
         WHERE id_pedido = p_pedido AND id_produto = p_produto;
    END IF;
END$$

-- ---------- Pagamento (RN15) ----------
DROP TRIGGER IF EXISTS trg_pagamento_bi$$
CREATE TRIGGER trg_pagamento_bi BEFORE INSERT ON pagamento FOR EACH ROW
BEGIN
    DECLARE v_status CHAR(1); DECLARE v_total DECIMAL(10,2); DECLARE v_pago DECIMAL(10,2);
    SELECT tp_status INTO v_status FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_status IS NULL OR v_status <> 'A' THEN
        SET @erro = CONCAT('Pedido ', NEW.id_pedido, ' não está aberto para pagamento');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    SET v_total = fn_total_pedido(NEW.id_pedido);
    SELECT COALESCE(SUM(vl_pago), 0) INTO v_pago FROM pagamento WHERE id_pedido = NEW.id_pedido;
    IF v_pago + NEW.vl_pago > v_total THEN
        SET @erro = CONCAT('RN15: pagamento (', v_pago, ' + ', NEW.vl_pago, ') excede o total do pedido (', v_total, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

-- ---------- Movimentação de estoque: única porta de alteração de qt_estoque_atual ----------
DROP TRIGGER IF EXISTS trg_mov_bi$$
CREATE TRIGGER trg_mov_bi BEFORE INSERT ON movimentacao_estoque FOR EACH ROW
BEGIN
    DECLARE v_nome VARCHAR(80); DECLARE v_ctrl BOOLEAN; DECLARE v_estq INT;
    DECLARE v_id INT; DECLARE v_perfil CHAR(1); DECLARE v_setor SMALLINT;
    SELECT nm_produto, in_controla_estoque, qt_estoque_atual INTO v_nome, v_ctrl, v_estq FROM produto WHERE id_produto = NEW.id_produto;
    IF NOT v_ctrl THEN
        SET @erro = CONCAT('Produto "', v_nome, '" não tem controle de estoque');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.tp_movimento = 'A' THEN
        CALL sp_exige_perfil('GS', 'ajuste manual de estoque', v_id, v_perfil, v_setor);
    END IF;
    IF v_estq + NEW.qt_movimento < 0 THEN
        SET @erro = CONCAT('RN08: movimentação deixaria "', v_nome, '" com estoque negativo (', v_estq, ' ', NEW.qt_movimento, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_mov_ai$$
CREATE TRIGGER trg_mov_ai AFTER INSERT ON movimentacao_estoque FOR EACH ROW
BEGIN
    UPDATE produto SET qt_estoque_atual = qt_estoque_atual + NEW.qt_movimento WHERE id_produto = NEW.id_produto;
END$$

-- ---------- Compras (regra proposta: só gerência/sócio) ----------
DROP TRIGGER IF EXISTS trg_compra_bi$$
CREATE TRIGGER trg_compra_bi BEFORE INSERT ON compra FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM atendente WHERE id_atendente = NEW.id_atendente AND in_ativo AND tp_perfil IN ('G','S')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Compras só podem ser registradas por gerência/sócio ativos';
    END IF;
    IF NOT (SELECT in_ativo FROM fornecedor WHERE id_fornecedor = NEW.id_fornecedor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fornecedor inativo';
    END IF;
    SET NEW.tp_status = 'P';
    SET NEW.dh_recebimento = NULL;
END$$

DROP TRIGGER IF EXISTS trg_compra_bu$$
CREATE TRIGGER trg_compra_bu BEFORE UPDATE ON compra FOR EACH ROW
BEGIN
    IF OLD.tp_status <> 'P' THEN
        SET @erro = CONCAT('Compra ', OLD.id_compra, ' já está ', OLD.tp_status, ' e não pode ser alterada');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF NEW.tp_status = 'R' THEN
        IF NOT EXISTS (SELECT 1 FROM compra_produto WHERE id_compra = OLD.id_compra) THEN
            SET @erro = CONCAT('Compra ', OLD.id_compra, ' sem itens não pode ser recebida');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
        END IF;
        SET NEW.dh_recebimento = COALESCE(NEW.dh_recebimento, NOW());
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_compra_au$$
CREATE TRIGGER trg_compra_au AFTER UPDATE ON compra FOR EACH ROW
BEGIN
    IF OLD.tp_status = 'P' AND NEW.tp_status = 'R' THEN            -- recebimento: gera a entrada de estoque
        INSERT INTO movimentacao_estoque (id_produto, id_compra, tp_movimento, qt_movimento, dh_movimento, ds_motivo)
        SELECT id_produto, id_compra, 'C', qt_comprada, NEW.dh_recebimento, CONCAT('Entrada por compra NF ', NEW.nr_nota_fiscal)
          FROM compra_produto WHERE id_compra = NEW.id_compra;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_cp_guard$$
CREATE PROCEDURE sp_cp_guard(IN p_compra INT, IN p_produto INT, IN p_valida_produto BOOLEAN)
BEGIN
    IF (SELECT tp_status FROM compra WHERE id_compra = p_compra) <> 'P' THEN
        SET @erro = CONCAT('Itens só podem ser alterados em compras pendentes (compra ', p_compra, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
    IF p_valida_produto AND NOT (SELECT in_controla_estoque FROM produto WHERE id_produto = p_produto) THEN
        SET @erro = CONCAT('Produto ', p_produto, ' não tem controle de estoque; não entra em compras');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_cp_bi$$
CREATE TRIGGER trg_cp_bi BEFORE INSERT ON compra_produto FOR EACH ROW CALL sp_cp_guard(NEW.id_compra, NEW.id_produto, TRUE)$$
DROP TRIGGER IF EXISTS trg_cp_bu$$
CREATE TRIGGER trg_cp_bu BEFORE UPDATE ON compra_produto FOR EACH ROW CALL sp_cp_guard(NEW.id_compra, NEW.id_produto, TRUE)$$
DROP TRIGGER IF EXISTS trg_cp_bd$$
CREATE TRIGGER trg_cp_bd BEFORE DELETE ON compra_produto FOR EACH ROW CALL sp_cp_guard(OLD.id_compra, OLD.id_produto, FALSE)$$

-- ---------- Proteção contra exclusão e alteração de registros históricos ----------
DROP TRIGGER IF EXISTS trg_nodel_pedido$$
CREATE TRIGGER trg_nodel_pedido BEFORE DELETE ON pedido FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em pedido: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_pp$$
CREATE TRIGGER trg_nodel_pp BEFORE DELETE ON pedido_produto FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em pedido_produto: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_pagto$$
CREATE TRIGGER trg_nodel_pagto BEFORE DELETE ON pagamento FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em pagamento: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_mov$$
CREATE TRIGGER trg_nodel_mov BEFORE DELETE ON movimentacao_estoque FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em movimentacao_estoque: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_hist$$
CREATE TRIGGER trg_nodel_hist BEFORE DELETE ON historico_produto FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em historico_produto: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_produto$$
CREATE TRIGGER trg_nodel_produto BEFORE DELETE ON produto FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em produto: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_atend$$
CREATE TRIGGER trg_nodel_atend BEFORE DELETE ON atendente FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em atendente: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_mesa$$
CREATE TRIGGER trg_nodel_mesa BEFORE DELETE ON mesa FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em mesa: use cancelamento/inativação para preservar o histórico'$$
DROP TRIGGER IF EXISTS trg_nodel_fornec$$
CREATE TRIGGER trg_nodel_fornec BEFORE DELETE ON fornecedor FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Exclusão bloqueada em fornecedor: use cancelamento/inativação para preservar o histórico'$$

-- compra só pode ser excluída enquanto está pendente (sem efeito em estoque)
DROP TRIGGER IF EXISTS trg_nodel_compra$$
CREATE TRIGGER trg_nodel_compra BEFORE DELETE ON compra FOR EACH ROW
BEGIN
    IF OLD.tp_status <> 'P' THEN
        SET @erro = CONCAT('Compra ', OLD.id_compra, ' está ', OLD.tp_status, ' e não pode ser excluída (use cancelamento)');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @erro;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_ro_pagto$$
CREATE TRIGGER trg_ro_pagto BEFORE UPDATE ON pagamento FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registro de pagamento é imutável (somente inserção)'$$
DROP TRIGGER IF EXISTS trg_ro_mov$$
CREATE TRIGGER trg_ro_mov BEFORE UPDATE ON movimentacao_estoque FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registro de movimentacao_estoque é imutável (somente inserção)'$$
DROP TRIGGER IF EXISTS trg_ro_hist$$
CREATE TRIGGER trg_ro_hist BEFORE UPDATE ON historico_produto FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Registro de historico_produto é imutável (somente inserção)'$$

DELIMITER ;

-- ---------- VIEWS (valores derivados não ficam gravados: 3FN) ----------
CREATE OR REPLACE VIEW vw_pedido_total AS
SELECT p.id_pedido, p.id_mesa, p.id_atendente, p.dh_abertura, p.dh_fechamento, p.tp_status, p.in_taxa_servico,
       COALESCE(s.vl_subtotal, 0) AS vl_subtotal,
       IF(p.in_taxa_servico, ROUND(COALESCE(s.vl_subtotal, 0) * 0.10, 2), 0) AS vl_taxa,
       COALESCE(s.vl_subtotal, 0) + IF(p.in_taxa_servico, ROUND(COALESCE(s.vl_subtotal, 0) * 0.10, 2), 0) AS vl_total,
       COALESCE(pg.vl_pago, 0) AS vl_pago
  FROM pedido p
  LEFT JOIN (SELECT id_pedido, SUM(CASE WHEN tp_status <> 'C' THEN qt_item * vl_preco_unitario END) AS vl_subtotal
               FROM pedido_produto GROUP BY id_pedido) s ON s.id_pedido = p.id_pedido
  LEFT JOIN (SELECT id_pedido, SUM(vl_pago) AS vl_pago FROM pagamento GROUP BY id_pedido) pg ON pg.id_pedido = p.id_pedido;

CREATE OR REPLACE VIEW vw_fila_preparo AS
SELECT st.nm_setor, pp.dh_registro, ROUND(TIMESTAMPDIFF(SECOND, pp.dh_registro, NOW()) / 60) AS min_espera,
       pp.id_pedido, m.nr_mesa, pr.nm_produto, pp.qt_item, pp.tp_status, pp.ds_observacao
  FROM pedido_produto pp
  JOIN pedido  p  ON p.id_pedido   = pp.id_pedido AND p.tp_status = 'A'
  JOIN produto pr ON pr.id_produto = pp.id_produto
  JOIN setor   st ON st.id_setor   = pr.id_setor
  JOIN mesa    m  ON m.id_mesa     = p.id_mesa
 WHERE pp.tp_status IN ('P','E');

CREATE OR REPLACE VIEW vw_estoque_critico AS
SELECT pr.id_produto, pr.nm_produto, c.nm_categoria, pr.qt_estoque_atual, pr.qt_estoque_minimo,
       pr.qt_estoque_minimo - pr.qt_estoque_atual AS qt_repor_ate_minimo
  FROM produto pr JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE pr.in_controla_estoque AND pr.in_ativo AND pr.qt_estoque_atual <= pr.qt_estoque_minimo;
