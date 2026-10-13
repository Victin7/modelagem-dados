-- =====================================================================
-- Regras de negócio no banco: funções, triggers e views
-- Usuário responsável: a aplicação (Garçom Web) informa quem opera com
--   SET LOCAL app.id_atendente = '<id>';    (dentro da transação)
-- =====================================================================

-- ---------- Funções auxiliares ----------
CREATE OR REPLACE FUNCTION fn_atendente_logado() RETURNS atendente
LANGUAGE plpgsql STABLE AS $$
DECLARE v_id TEXT := current_setting('app.id_atendente', true); v_at atendente;
BEGIN
    IF v_id IS NULL OR v_id = '' THEN RETURN NULL; END IF;
    SELECT * INTO v_at FROM atendente WHERE id_atendente = v_id::INT;
    RETURN v_at;
END $$;

-- exige usuário logado, ativo e de um dos perfis informados
CREATE OR REPLACE FUNCTION fn_exige_perfil(p_perfis TEXT, p_acao TEXT) RETURNS atendente
LANGUAGE plpgsql STABLE AS $$
DECLARE v_at atendente := fn_atendente_logado();
BEGIN
    IF v_at.id_atendente IS NULL THEN
        RAISE EXCEPTION 'Operação "%" exige usuário identificado (SET LOCAL app.id_atendente)', p_acao;
    END IF;
    IF NOT v_at.in_ativo OR position(v_at.tp_perfil IN p_perfis) = 0 THEN
        RAISE EXCEPTION 'Perfil % (atendente %) não autorizado para "%"', v_at.tp_perfil, v_at.id_atendente, p_acao;
    END IF;
    RETURN v_at;
END $$;

-- valor total do pedido = itens não cancelados + taxa de serviço de 10% (RN16)
CREATE OR REPLACE FUNCTION fn_subtotal_pedido(p_id INT) RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(qt_item * vl_preco_unitario) FILTER (WHERE tp_status <> 'C'), 0)
      FROM pedido_produto WHERE id_pedido = p_id $$;

CREATE OR REPLACE FUNCTION fn_total_pedido(p_id INT) RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
    SELECT s + CASE WHEN p.in_taxa_servico THEN ROUND(s * 0.10, 2) ELSE 0 END
      FROM pedido p, LATERAL (SELECT fn_subtotal_pedido(p.id_pedido) AS s) x
     WHERE p.id_pedido = p_id $$;

-- ---------- SETOR de produto deve ser de preparo (RN06) ----------
CREATE OR REPLACE FUNCTION trg_produto_setor() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT (SELECT in_preparo FROM setor WHERE id_setor = NEW.id_setor) THEN
        RAISE EXCEPTION 'RN06: produto "%" deve pertencer a um setor de preparo', NEW.nm_produto;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_produto_setor BEFORE INSERT OR UPDATE OF id_setor ON produto
    FOR EACH ROW EXECUTE FUNCTION trg_produto_setor();

-- ---------- Alteração de preço: só gerência/sócio e gera histórico (regra proposta: perfil e histórico) ----------
CREATE OR REPLACE FUNCTION trg_produto_preco() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_at atendente;
BEGIN
    IF NEW.vl_preco IS DISTINCT FROM OLD.vl_preco THEN
        v_at := fn_exige_perfil('GS', 'alterar preço');
        INSERT INTO historico_produto (id_produto, id_atendente, vl_preco_anterior, vl_preco_novo)
        VALUES (OLD.id_produto, v_at.id_atendente, OLD.vl_preco, NEW.vl_preco);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_produto_preco BEFORE UPDATE OF vl_preco ON produto
    FOR EACH ROW EXECUTE FUNCTION trg_produto_preco();

-- ---------- Reserva ----------
CREATE OR REPLACE FUNCTION trg_reserva_ins() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_mesa mesa;
BEGIN
    SELECT * INTO v_mesa FROM mesa WHERE id_mesa = NEW.id_mesa;
    IF NOT v_mesa.in_ativa THEN RAISE EXCEPTION 'Mesa % inativa', v_mesa.nr_mesa; END IF;
    IF NEW.qt_pessoas > v_mesa.qt_lugares THEN
        RAISE EXCEPTION 'Mesa % comporta % lugares (reserva de % pessoas)', v_mesa.nr_mesa, v_mesa.qt_lugares, NEW.qt_pessoas;
    END IF;
    IF NEW.dh_reserva <= now() THEN RAISE EXCEPTION 'Reserva deve ser para data/hora futura'; END IF;
    IF NEW.tp_status = 'A' AND EXISTS (SELECT 1 FROM reserva r WHERE r.id_mesa = NEW.id_mesa AND r.tp_status = 'A'
            AND r.dh_reserva BETWEEN NEW.dh_reserva - INTERVAL '2 hours' AND NEW.dh_reserva + INTERVAL '2 hours') THEN
        RAISE EXCEPTION 'Mesa % já reservada em horário próximo (janela de 2 h)', v_mesa.nr_mesa;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_reserva_ins BEFORE INSERT ON reserva FOR EACH ROW EXECUTE FUNCTION trg_reserva_ins();

-- ---------- Abertura de pedido (RN01, RN02, RN04, RN05) ----------
CREATE OR REPLACE FUNCTION trg_pedido_ins() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_at atendente; v_mesa mesa;
BEGIN
    SELECT * INTO v_at FROM atendente WHERE id_atendente = NEW.id_atendente;
    IF NOT v_at.in_ativo OR v_at.tp_perfil NOT IN ('A','G','S') THEN
        RAISE EXCEPTION 'RN04: atendente % não pode abrir pedidos (inativo ou perfil %)', NEW.id_atendente, v_at.tp_perfil;
    END IF;
    SELECT * INTO v_mesa FROM mesa WHERE id_mesa = NEW.id_mesa FOR UPDATE;
    IF NOT v_mesa.in_ativa THEN RAISE EXCEPTION 'Mesa % inativa', v_mesa.nr_mesa; END IF;
    IF v_mesa.tp_status <> 'L' THEN RAISE EXCEPTION 'RN05: mesa % já está ocupada', v_mesa.nr_mesa; END IF;
    NEW.tp_status := 'A'; NEW.dh_fechamento := NULL;
    UPDATE mesa SET tp_status = 'O' WHERE id_mesa = NEW.id_mesa;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_pedido_ins BEFORE INSERT ON pedido FOR EACH ROW EXECUTE FUNCTION trg_pedido_ins();

-- ---------- Fechamento / cancelamento de pedido (RN10, RN17) ----------
CREATE OR REPLACE FUNCTION trg_pedido_upd() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_total NUMERIC; v_pago NUMERIC;
BEGIN
    IF OLD.tp_status <> 'A' THEN
        RAISE EXCEPTION 'Pedido % já está % e não pode ser alterado', OLD.id_pedido, OLD.tp_status;
    END IF;
    IF NEW.id_mesa <> OLD.id_mesa OR NEW.id_atendente <> OLD.id_atendente OR NEW.dh_abertura <> OLD.dh_abertura THEN
        RAISE EXCEPTION 'Mesa, atendente e abertura do pedido não podem ser alterados';
    END IF;
    IF NEW.tp_status = 'F' THEN
        IF EXISTS (SELECT 1 FROM pedido_produto WHERE id_pedido = OLD.id_pedido AND tp_status IN ('P','E','R')) THEN
            RAISE EXCEPTION 'RN10: pedido % tem itens ainda não entregues', OLD.id_pedido;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pedido_produto WHERE id_pedido = OLD.id_pedido AND tp_status = 'N') THEN
            RAISE EXCEPTION 'RN10: pedido % não tem itens entregues; cancele-o', OLD.id_pedido;
        END IF;
        v_total := fn_total_pedido(OLD.id_pedido) ;
        -- a taxa informada na mesma instrução vale para o cálculo
        IF NEW.in_taxa_servico <> OLD.in_taxa_servico THEN
            v_total := fn_subtotal_pedido(OLD.id_pedido) + CASE WHEN NEW.in_taxa_servico THEN ROUND(fn_subtotal_pedido(OLD.id_pedido)*0.10,2) ELSE 0 END;
        END IF;
        SELECT COALESCE(SUM(vl_pago),0) INTO v_pago FROM pagamento WHERE id_pedido = OLD.id_pedido;
        IF v_pago <> v_total THEN
            RAISE EXCEPTION 'RN10: pagamentos (%) diferem do total do pedido (%)', v_pago, v_total;
        END IF;
        NEW.dh_fechamento := COALESCE(NEW.dh_fechamento, now());
        UPDATE mesa SET tp_status = 'L' WHERE id_mesa = OLD.id_mesa;
    ELSIF NEW.tp_status = 'C' THEN
        IF EXISTS (SELECT 1 FROM pagamento WHERE id_pedido = OLD.id_pedido) THEN
            RAISE EXCEPTION 'RN10: pedido % possui pagamento e não pode ser cancelado', OLD.id_pedido;
        END IF;
        IF EXISTS (SELECT 1 FROM pedido_produto WHERE id_pedido = OLD.id_pedido AND tp_status IN ('R','N')) THEN
            RAISE EXCEPTION 'RN17: pedido % possui itens prontos ou entregues e não pode ser cancelado', OLD.id_pedido;
        END IF;
        UPDATE pedido_produto SET tp_status = 'C' WHERE id_pedido = OLD.id_pedido AND tp_status <> 'C';
        NEW.dh_fechamento := COALESCE(NEW.dh_fechamento, now());
        UPDATE mesa SET tp_status = 'L' WHERE id_mesa = OLD.id_mesa;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_pedido_upd BEFORE UPDATE ON pedido FOR EACH ROW EXECUTE FUNCTION trg_pedido_upd();

-- ---------- Itens do pedido (relacionamento "contém") ----------
-- quantidade efetiva (considera cancelamento) usada para baixa/estorno de estoque
CREATE OR REPLACE FUNCTION fn_qtd_efetiva(p_qt INT, p_status CHAR) RETURNS INT
LANGUAGE sql IMMUTABLE AS $$ SELECT CASE WHEN p_status = 'C' THEN 0 ELSE COALESCE(p_qt,0) END $$;

CREATE OR REPLACE FUNCTION trg_pp_before() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_ped pedido; v_prod produto; v_delta INT; v_at atendente; v_old_eff INT := 0;
BEGIN
    SELECT * INTO v_ped FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_ped.tp_status <> 'A' THEN RAISE EXCEPTION 'Pedido % não está aberto', NEW.id_pedido; END IF;
    SELECT * INTO v_prod FROM produto WHERE id_produto = NEW.id_produto;

    IF TG_OP = 'INSERT' THEN
        IF NOT v_prod.in_ativo OR NOT v_prod.in_vendavel THEN
            RAISE EXCEPTION 'RN14: produto "%" não está disponível para venda', v_prod.nm_produto;
        END IF;
        NEW.tp_status := 'P'; NEW.dh_pronto := NULL;
        NEW.vl_preco_unitario := v_prod.vl_preco;                                   -- RN07
    ELSE
        IF NEW.id_pedido <> OLD.id_pedido OR NEW.id_produto <> OLD.id_produto THEN
            RAISE EXCEPTION 'Chave do item não pode ser alterada';
        END IF;
        v_old_eff := fn_qtd_efetiva(OLD.qt_item, OLD.tp_status);
        -- transições válidas
        IF OLD.tp_status = 'C' AND NEW.tp_status <> 'C' THEN                         -- reativação do item (via lancar_item)
            IF NEW.tp_status <> 'P' THEN RAISE EXCEPTION 'Item cancelado só pode voltar como Pendente'; END IF;
            IF NOT v_prod.in_ativo OR NOT v_prod.in_vendavel THEN
                RAISE EXCEPTION 'RN14: produto "%" não está disponível para venda', v_prod.nm_produto;
            END IF;
            NEW.vl_preco_unitario := v_prod.vl_preco; NEW.dh_registro := now(); NEW.dh_pronto := NULL;
        ELSIF OLD.tp_status = 'C' THEN
            IF NEW.qt_item <> OLD.qt_item OR NEW.tp_status <> 'C' THEN RAISE EXCEPTION 'Item cancelado não pode ser alterado'; END IF;
        ELSIF NEW.tp_status = 'P' AND OLD.tp_status <> 'P' THEN                      -- novo lançamento sobre linha existente
            IF NEW.qt_item <= OLD.qt_item THEN RAISE EXCEPTION 'Voltar item para Pendente exige aumento de quantidade'; END IF;
            NEW.dh_registro := now(); NEW.dh_pronto := NULL;
        ELSIF (OLD.tp_status, NEW.tp_status) NOT IN (('P','P'),('E','E'),('R','R'),('N','N'),('P','E'),('E','R'),('R','N'),
                                                    ('P','C'),('E','C')) THEN
            RAISE EXCEPTION 'RN09/RN17: transição de status inválida: % -> % (item pronto ou entregue não é cancelado)', OLD.tp_status, NEW.tp_status;
        END IF;
        IF NEW.qt_item < OLD.qt_item THEN RAISE EXCEPTION 'Quantidade só pode diminuir por cancelamento do item'; END IF;
        IF OLD.tp_status <> 'C' AND NEW.vl_preco_unitario <> OLD.vl_preco_unitario THEN
            RAISE EXCEPTION 'RN07: preço unitário do item não pode ser alterado';
        END IF;
        IF NEW.qt_item > OLD.qt_item AND NEW.tp_status NOT IN ('P') THEN
            RAISE EXCEPTION 'Aumento de quantidade reinicia o item como Pendente';
        END IF;
        -- quem pode mudar o andamento do item
        IF NEW.tp_status IS DISTINCT FROM OLD.tp_status THEN
            IF NEW.tp_status IN ('E','R') THEN
                v_at := fn_exige_perfil('PGS', 'preparar item');
                IF v_at.tp_perfil = 'P' AND v_at.id_setor <> v_prod.id_setor THEN
                    RAISE EXCEPTION 'Atendente % (setor %) não prepara itens do setor %', v_at.id_atendente, v_at.id_setor, v_prod.id_setor;
                END IF;
            ELSIF NEW.tp_status = 'N' THEN
                PERFORM fn_exige_perfil('AGS', 'entregar item');
            END IF;
        END IF;
    END IF;

    IF NEW.tp_status = 'R' AND NEW.dh_pronto IS NULL THEN NEW.dh_pronto := now(); END IF;
    IF NEW.tp_status IN ('P','E','C') THEN NEW.dh_pronto := NULL; END IF;

    -- RN08: estoque suficiente para o acréscimo
    v_delta := fn_qtd_efetiva(NEW.qt_item, NEW.tp_status) - v_old_eff;
    IF v_delta > 0 AND v_prod.in_controla_estoque AND v_prod.qt_estoque_atual < v_delta THEN
        RAISE EXCEPTION 'RN08: estoque insuficiente de "%" (disponível %, pedido %)', v_prod.nm_produto, v_prod.qt_estoque_atual, v_delta;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_pp_before BEFORE INSERT OR UPDATE ON pedido_produto FOR EACH ROW EXECUTE FUNCTION trg_pp_before();

CREATE OR REPLACE FUNCTION trg_pp_after() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_old INT := 0; v_new INT; v_delta INT;
BEGIN
    IF NOT (SELECT in_controla_estoque FROM produto WHERE id_produto = NEW.id_produto) THEN RETURN NULL; END IF;
    IF TG_OP = 'UPDATE' THEN v_old := fn_qtd_efetiva(OLD.qt_item, OLD.tp_status); END IF;
    v_new := fn_qtd_efetiva(NEW.qt_item, NEW.tp_status);
    v_delta := v_new - v_old;
    IF v_delta > 0 THEN
        INSERT INTO movimentacao_estoque (id_produto, id_pedido, tp_movimento, qt_movimento, ds_motivo)
        VALUES (NEW.id_produto, NEW.id_pedido, 'V', -v_delta, 'Baixa por venda');
    ELSIF v_delta < 0 THEN
        INSERT INTO movimentacao_estoque (id_produto, id_pedido, tp_movimento, qt_movimento, ds_motivo)
        VALUES (NEW.id_produto, NEW.id_pedido, 'E', -v_delta, 'Estorno por cancelamento');
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_pp_after AFTER INSERT OR UPDATE ON pedido_produto FOR EACH ROW EXECUTE FUNCTION trg_pp_after();

-- Lançamento de item: "upsert" que substitui a antiga entidade Item_pedido.
-- Se o produto já está no pedido, soma a quantidade; se estava cancelado, reativa com o preço vigente.
CREATE OR REPLACE FUNCTION lancar_item(p_pedido INT, p_produto INT, p_qtd INT, p_obs TEXT DEFAULT NULL) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE v_pp pedido_produto;
BEGIN
    IF p_qtd IS NULL OR p_qtd <= 0 THEN RAISE EXCEPTION 'Quantidade deve ser positiva'; END IF;
    SELECT * INTO v_pp FROM pedido_produto WHERE id_pedido = p_pedido AND id_produto = p_produto FOR UPDATE;
    IF NOT FOUND THEN
        INSERT INTO pedido_produto (id_pedido, id_produto, qt_item, vl_preco_unitario, ds_observacao)
        VALUES (p_pedido, p_produto, p_qtd, 1, p_obs);        -- preço real é copiado pelo trigger (RN07)
    ELSIF v_pp.tp_status = 'C' THEN
        UPDATE pedido_produto SET qt_item = p_qtd, tp_status = 'P', ds_observacao = COALESCE(p_obs, ds_observacao)
         WHERE id_pedido = p_pedido AND id_produto = p_produto;
    ELSE
        UPDATE pedido_produto SET qt_item = qt_item + p_qtd, tp_status = 'P', ds_observacao = COALESCE(p_obs, ds_observacao)
         WHERE id_pedido = p_pedido AND id_produto = p_produto;
    END IF;
END $$;

-- ---------- Pagamento (RN15) ----------
CREATE OR REPLACE FUNCTION trg_pagamento_ins() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status CHAR; v_total NUMERIC; v_pago NUMERIC;
BEGIN
    SELECT tp_status INTO v_status FROM pedido WHERE id_pedido = NEW.id_pedido;
    IF v_status <> 'A' THEN RAISE EXCEPTION 'Pedido % não está aberto para pagamento', NEW.id_pedido; END IF;
    v_total := fn_total_pedido(NEW.id_pedido);
    SELECT COALESCE(SUM(vl_pago),0) INTO v_pago FROM pagamento WHERE id_pedido = NEW.id_pedido;
    IF v_pago + NEW.vl_pago > v_total THEN
        RAISE EXCEPTION 'RN15: pagamento (% + %) excede o total do pedido (%)', v_pago, NEW.vl_pago, v_total;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_pagamento_ins BEFORE INSERT ON pagamento FOR EACH ROW EXECUTE FUNCTION trg_pagamento_ins();

-- ---------- Movimentação de estoque: única porta de alteração de qt_estoque_atual ----------
CREATE OR REPLACE FUNCTION trg_mov_before() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_prod produto;
BEGIN
    SELECT * INTO v_prod FROM produto WHERE id_produto = NEW.id_produto;
    IF NOT v_prod.in_controla_estoque THEN
        RAISE EXCEPTION 'Produto "%" não tem controle de estoque', v_prod.nm_produto;
    END IF;
    IF NEW.tp_movimento = 'A' THEN PERFORM fn_exige_perfil('GS', 'ajuste manual de estoque'); END IF;
    IF v_prod.qt_estoque_atual + NEW.qt_movimento < 0 THEN
        RAISE EXCEPTION 'RN08: movimentação deixaria "%" com estoque negativo (% % %)', v_prod.nm_produto, v_prod.qt_estoque_atual, '+', NEW.qt_movimento;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_mov_before BEFORE INSERT ON movimentacao_estoque FOR EACH ROW EXECUTE FUNCTION trg_mov_before();

CREATE OR REPLACE FUNCTION trg_mov_after() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE produto SET qt_estoque_atual = qt_estoque_atual + NEW.qt_movimento WHERE id_produto = NEW.id_produto;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_mov_after AFTER INSERT ON movimentacao_estoque FOR EACH ROW EXECUTE FUNCTION trg_mov_after();

-- ---------- Compras (regra proposta: só gerência/sócio) ----------
CREATE OR REPLACE FUNCTION trg_compra_ins() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    PERFORM 1 FROM atendente WHERE id_atendente = NEW.id_atendente AND in_ativo AND tp_perfil IN ('G','S');
    IF NOT FOUND THEN RAISE EXCEPTION 'Compras só podem ser registradas por gerência/sócio ativos'; END IF;
    IF NOT (SELECT in_ativo FROM fornecedor WHERE id_fornecedor = NEW.id_fornecedor) THEN
        RAISE EXCEPTION 'Fornecedor inativo';
    END IF;
    NEW.tp_status := 'P'; NEW.dh_recebimento := NULL;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_compra_ins BEFORE INSERT ON compra FOR EACH ROW EXECUTE FUNCTION trg_compra_ins();

CREATE OR REPLACE FUNCTION trg_compra_upd() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.tp_status <> 'P' THEN RAISE EXCEPTION 'Compra % já está % e não pode ser alterada', OLD.id_compra, OLD.tp_status; END IF;
    IF NEW.tp_status = 'R' THEN
        IF NOT EXISTS (SELECT 1 FROM compra_produto WHERE id_compra = OLD.id_compra) THEN
            RAISE EXCEPTION 'Compra % sem itens não pode ser recebida', OLD.id_compra;
        END IF;
        NEW.dh_recebimento := COALESCE(NEW.dh_recebimento, now());
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER trg_compra_upd BEFORE UPDATE ON compra FOR EACH ROW EXECUTE FUNCTION trg_compra_upd();

CREATE OR REPLACE FUNCTION trg_compra_receb() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO movimentacao_estoque (id_produto, id_compra, tp_movimento, qt_movimento, dh_movimento, ds_motivo)
    SELECT id_produto, id_compra, 'C', qt_comprada, NEW.dh_recebimento, 'Entrada por compra NF ' || NEW.nr_nota_fiscal
      FROM compra_produto WHERE id_compra = NEW.id_compra;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_compra_receb AFTER UPDATE OF tp_status ON compra
    FOR EACH ROW WHEN (OLD.tp_status = 'P' AND NEW.tp_status = 'R') EXECUTE FUNCTION trg_compra_receb();

CREATE OR REPLACE FUNCTION trg_cp_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_id INT := COALESCE(NEW.id_compra, OLD.id_compra);
BEGIN
    IF (SELECT tp_status FROM compra WHERE id_compra = v_id) <> 'P' THEN
        RAISE EXCEPTION 'Itens só podem ser alterados em compras pendentes (compra %)', v_id;
    END IF;
    IF TG_OP <> 'DELETE' AND NOT (SELECT in_controla_estoque FROM produto WHERE id_produto = NEW.id_produto) THEN
        RAISE EXCEPTION 'Produto % não tem controle de estoque; não entra em compras', NEW.id_produto;
    END IF;
    RETURN COALESCE(NEW, OLD);
END $$;
CREATE TRIGGER trg_cp_guard BEFORE INSERT OR UPDATE OR DELETE ON compra_produto FOR EACH ROW EXECUTE FUNCTION trg_cp_guard();

-- ---------- Proteção contra exclusão e alteração de registros históricos ----------
CREATE OR REPLACE FUNCTION trg_bloqueia_exclusao() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Exclusão bloqueada em %: use cancelamento/inativação para preservar o histórico', TG_TABLE_NAME;
END $$;
CREATE TRIGGER trg_nodel_pedido   BEFORE DELETE ON pedido               FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_pp       BEFORE DELETE ON pedido_produto       FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_pagto    BEFORE DELETE ON pagamento            FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_mov      BEFORE DELETE ON movimentacao_estoque FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_hist     BEFORE DELETE ON historico_produto    FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_produto  BEFORE DELETE ON produto              FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_atend    BEFORE DELETE ON atendente            FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_mesa     BEFORE DELETE ON mesa                 FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();
CREATE TRIGGER trg_nodel_fornec   BEFORE DELETE ON fornecedor           FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_exclusao();

-- compra só pode ser excluída enquanto está pendente (sem efeito em estoque)
CREATE OR REPLACE FUNCTION trg_compra_del() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.tp_status <> 'P' THEN
        RAISE EXCEPTION 'Compra % está % e não pode ser excluída (use cancelamento)', OLD.id_compra, OLD.tp_status;
    END IF;
    RETURN OLD;
END $$;
CREATE TRIGGER trg_nodel_compra BEFORE DELETE ON compra FOR EACH ROW EXECUTE FUNCTION trg_compra_del();

CREATE OR REPLACE FUNCTION trg_somente_insercao() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Registro de % é imutável (somente inserção)', TG_TABLE_NAME;
END $$;
CREATE TRIGGER trg_ro_pagto BEFORE UPDATE ON pagamento            FOR EACH ROW EXECUTE FUNCTION trg_somente_insercao();
CREATE TRIGGER trg_ro_mov   BEFORE UPDATE ON movimentacao_estoque FOR EACH ROW EXECUTE FUNCTION trg_somente_insercao();
CREATE TRIGGER trg_ro_hist  BEFORE UPDATE ON historico_produto    FOR EACH ROW EXECUTE FUNCTION trg_somente_insercao();

-- ---------- VIEWS (valores derivados não ficam gravados: 3FN) ----------
CREATE OR REPLACE VIEW vw_pedido_total AS
SELECT p.id_pedido, p.id_mesa, p.id_atendente, p.dh_abertura, p.dh_fechamento, p.tp_status, p.in_taxa_servico,
       s.vl_subtotal,
       CASE WHEN p.in_taxa_servico THEN ROUND(s.vl_subtotal * 0.10, 2) ELSE 0 END AS vl_taxa,
       s.vl_subtotal + CASE WHEN p.in_taxa_servico THEN ROUND(s.vl_subtotal * 0.10, 2) ELSE 0 END AS vl_total,
       COALESCE(pg.vl_pago, 0) AS vl_pago
  FROM pedido p
  CROSS JOIN LATERAL (SELECT COALESCE(SUM(pp.qt_item * pp.vl_preco_unitario) FILTER (WHERE pp.tp_status <> 'C'), 0) AS vl_subtotal
                        FROM pedido_produto pp WHERE pp.id_pedido = p.id_pedido) s
  LEFT JOIN LATERAL (SELECT SUM(vl_pago) AS vl_pago FROM pagamento WHERE id_pedido = p.id_pedido) pg ON TRUE;

CREATE OR REPLACE VIEW vw_fila_preparo AS
SELECT st.nm_setor, pp.dh_registro, ROUND(EXTRACT(EPOCH FROM (now() - pp.dh_registro)) / 60) AS min_espera,
       pp.id_pedido, m.nr_mesa, pr.nm_produto, pp.qt_item, pp.tp_status, pp.ds_observacao
  FROM pedido_produto pp
  JOIN pedido  p  ON p.id_pedido   = pp.id_pedido AND p.tp_status = 'A'
  JOIN produto pr ON pr.id_produto = pp.id_produto
  JOIN setor   st ON st.id_setor   = pr.id_setor
  JOIN mesa    m  ON m.id_mesa     = p.id_mesa
 WHERE pp.tp_status IN ('P','E')
 ORDER BY pp.dh_registro;

CREATE OR REPLACE VIEW vw_estoque_critico AS
SELECT pr.id_produto, pr.nm_produto, c.nm_categoria, pr.qt_estoque_atual, pr.qt_estoque_minimo,
       pr.qt_estoque_minimo - pr.qt_estoque_atual AS qt_repor_ate_minimo
  FROM produto pr JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE pr.in_controla_estoque AND pr.in_ativo AND pr.qt_estoque_atual <= pr.qt_estoque_minimo
 ORDER BY pr.qt_estoque_atual - pr.qt_estoque_minimo;
