-- =====================================================================
-- Gerador de pedidos de teste (MySQL 8.0) - NÃO faz parte da entrega obrigatória.
-- Cria e executa a procedure sp_gerar_pedidos(n): para cada pedido, passa por TODAS as
-- regras de negócio (triggers): abre numa mesa livre (RN02/RN05), lança 1 a 4 itens
-- (RN07/RN08/RN14), prepara (P->E->R), entrega (N), paga o total exato (RN15) e fecha (RN10).
-- Pedidos que violarem alguma regra (ex.: estoque insuficiente) são desfeitos e contados.
-- Uso:  CALL sp_gerar_pedidos(100);
-- =====================================================================
USE palazio_del_chef;
SET NAMES utf8mb4;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_gerar_pedidos$$
CREATE PROCEDURE sp_gerar_pedidos(IN p_qtd INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_ok INT DEFAULT 0;
    DECLARE v_falha INT DEFAULT 0;
    DECLARE v_mesa SMALLINT; DECLARE v_garcom INT; DECLARE v_chefia INT;
    DECLARE v_pedido INT; DECLARE v_itens INT; DECLARE j INT; DECLARE v_total DECIMAL(10,2);
    DECLARE v_msg VARCHAR(128);
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_falha = v_falha + 1;
        SET @ultimo_erro = v_msg;
    END;

    SELECT id_atendente INTO v_chefia FROM atendente WHERE in_ativo AND tp_perfil IN ('G','S') ORDER BY id_atendente LIMIT 1;

    WHILE i < p_qtd DO
        SET i = i + 1;
        SET v_pedido = NULL;
        SET v_mesa = (SELECT id_mesa FROM mesa WHERE in_ativa AND tp_status = 'L' ORDER BY RAND() LIMIT 1);
        SET v_garcom = (SELECT id_atendente FROM atendente WHERE in_ativo AND tp_perfil = 'A' ORDER BY RAND() LIMIT 1);
        IF v_mesa IS NULL OR v_garcom IS NULL THEN
            SET v_falha = v_falha + 1;
        ELSE
            START TRANSACTION;
            SET @id_atendente = v_garcom;
            INSERT INTO pedido (id_mesa, id_atendente) VALUES (v_mesa, v_garcom);
            SET v_pedido = LAST_INSERT_ID();

            -- 1 a 4 produtos distintos, 1 a 3 unidades cada
            SET v_itens = 1 + FLOOR(RAND() * 4);
            SET j = 0;
            WHILE j < v_itens DO
                SET j = j + 1;
                CALL sp_lancar_item(v_pedido,
                    (SELECT id_produto FROM produto WHERE in_ativo AND in_vendavel
                        AND (NOT in_controla_estoque OR qt_estoque_atual >= 5)
                      ORDER BY RAND() LIMIT 1),
                    1 + FLOOR(RAND() * 3), NULL);
            END WHILE;

            -- preparo (cozinha/bar = chefia), entrega (garçom)
            SET @id_atendente = v_chefia;
            UPDATE pedido_produto SET tp_status = 'E' WHERE id_pedido = v_pedido AND tp_status = 'P';
            UPDATE pedido_produto SET tp_status = 'R' WHERE id_pedido = v_pedido AND tp_status = 'E';
            SET @id_atendente = v_garcom;
            UPDATE pedido_produto SET tp_status = 'N' WHERE id_pedido = v_pedido AND tp_status = 'R';

            -- pagamento do total (itens + 10% de serviço) em uma forma aleatória e fechamento
            SET v_total = fn_total_pedido(v_pedido);
            INSERT INTO pagamento (id_pedido, tp_forma, vl_pago)
            VALUES (v_pedido, ELT(1 + FLOOR(RAND() * 4), 'D','C','B','P'), v_total);
            UPDATE pedido SET tp_status = 'F' WHERE id_pedido = v_pedido;
            COMMIT;
            SET v_ok = v_ok + 1;
        END IF;
    END WHILE;

    SELECT p_qtd AS solicitados, v_ok AS gerados_ok, v_falha AS desfeitos_por_regra, @ultimo_erro AS ultimo_erro;
END$$

DELIMITER ;

CALL sp_gerar_pedidos(100);

SELECT COUNT(*) AS total_pedidos,
       SUM(tp_status = 'F') AS fechados,
       SUM(tp_status = 'A') AS abertos
  FROM pedido;
