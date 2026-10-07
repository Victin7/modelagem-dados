"""Gera o DER conceitual do Palazio del Chef (notação Chen, como no BRModelo).
Uso: python3 gerar_der.py  ->  diagrama_palazio_del_chef.png
Sem chaves estrangeiras. Sem entidade ITEM_PEDIDO/ITEM_COMPRA: PEDIDO×PRODUTO e COMPRA×PRODUTO são
relacionamentos N:N com atributos próprios (círculos presos ao losango)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, Circle

COR, TXT, DEST = "#7a1f2b", "#1d1d1f", "#f3e8ea"
# nome: (x, y, lado dos atributos, [atributos]; o primeiro é o identificador)
E = {
 "MESA":(40,16,"up",["ID_MESA","NR_MESA","TP_LOCAL","QT_LUGARES","TP_STATUS","IN_ATIVA"]),
 "RESERVA":(15,16,"down",["ID_RESERVA","NM_CLIENTE","NR_TELEFONE","DH_RESERVA","QT_PESSOAS","TP_STATUS"]),
 "PEDIDO":(62,30,"up",["ID_PEDIDO","DH_ABERTURA","DH_FECHAMENTO","IN_TAXA_SERVICO","TP_STATUS","DS_OBSERVACAO"]),
 "ATENDENTE":(25,64,"left",["ID_ATENDENTE","NM_ATENDENTE","NM_LOGIN","DS_SENHA_HASH","TP_FUNCAO","TP_PERFIL","DT_ADMISSAO","IN_ATIVO"]),
 "SETOR":(62,102,"down",["ID_SETOR","NM_SETOR","IN_PREPARO"]),
 "PAGAMENTO":(33,30,"up",["ID_PAGAMENTO","TP_FORMA","VL_PAGO","DH_PAGAMENTO"]),
 "HISTORICO_PRODUTO":(62,84,"left",["ID_HISTORICO","VL_PRECO_ANTERIOR","VL_PRECO_NOVO","DH_ALTERACAO"]),
 "PRODUTO":(105,64,"right",["ID_PRODUTO","NM_PRODUTO","NR_CODIGO_BARRAS","VL_PRECO","IN_VENDAVEL","IN_ALCOOLICO","QT_ESTOQUE_ATUAL","QT_ESTOQUE_MINIMO","IN_ATIVO"]),
 "CATEGORIA":(105,42,"right",["ID_CATEGORIA","NM_CATEGORIA","IN_ATIVA"]),
 "MOVIMENTACAO_ESTOQUE":(62,44,"left",["ID_MOVIMENTACAO","TP_MOVIMENTO","QT_MOVIMENTO","DH_MOVIMENTO","DS_MOTIVO"]),
 "COMPRA":(62,58,"down",["ID_COMPRA","DH_COMPRA","NR_NOTA_FISCAL","TP_STATUS","DH_RECEBIMENTO"]),
 "FORNECEDOR":(49,67,"left",["ID_FORNECEDOR","NM_FORNECEDOR","NR_CNPJ","NR_TELEFONE","IN_ATIVO"]),
}
# (A, rótulo, B, card. em A, card. em B, lado dos atributos do relacionamento, atributos do relacionamento)
R = [
 ("SETOR","agrupa","ATENDENTE","(0,N)","(1,1)","left",[]),
 ("SETOR","prepara","PRODUTO","(0,N)","(1,1)","right",[]),
 ("ATENDENTE","registra","PEDIDO","(1,N)","(1,1)","up",[]),
 ("MESA","recebe","PEDIDO","(0,N)","(1,1)","up",[]),
 ("PEDIDO","contém","PRODUTO","(1,N)","(0,N)","up",["QT_ITEM","VL_PRECO_UNITARIO","TP_STATUS","DH_REGISTRO","DH_PRONTO","DS_OBSERVACAO"]),
 ("PEDIDO","é quitado por","PAGAMENTO","(0,N)","(1,1)","up",[]),
 ("PRODUTO","tem","HISTORICO_PRODUTO","(0,N)","(1,1)","down",[]),
 ("ATENDENTE","realiza","HISTORICO_PRODUTO","(0,N)","(1,1)","down",[]),
 ("ATENDENTE","efetua","COMPRA","(0,N)","(1,1)","up",[]),
 ("FORNECEDOR","fornece","COMPRA","(0,N)","(1,1)","up",[]),
 ("COMPRA","possui","PRODUTO","(1,N)","(0,N)","down",["QT_COMPRADA","VL_CUSTO_UNITARIO","DT_VALIDADE"]),
 ("PRODUTO","sofre","MOVIMENTACAO_ESTOQUE","(0,N)","(1,1)","right",[]),
 ("MESA","reserva","RESERVA","(0,N)","(1,1)","up",[]),
 ("CATEGORIA","classifica","PRODUTO","(0,N)","(1,1)","right",[]),
 ("PEDIDO","gera","MOVIMENTACAO_ESTOQUE","(0,N)","(0,1)","left",[]),
 ("COMPRA","gera","MOVIMENTACAO_ESTOQUE","(0,N)","(0,1)","left",[]),
]
fig, ax = plt.subplots(figsize=(38, 31), dpi=100)
ax.set_xlim(-2, 135); ax.set_ylim(112, 0); ax.axis('off'); ax.set_aspect('equal'); ax.set_aspect("equal")
BW = lambda n: 1.0 + 0.5*len(n)
BH = 1.0
def edge_point(cx, cy, w, h, tx, ty):
    dx, dy = tx-cx, ty-cy
    if dx == 0 and dy == 0: return cx, cy
    s = min((w/2)/abs(dx) if dx else 9e9, (h/2)/abs(dy) if dy else 9e9)
    return cx+dx*s, cy+dy*s
def fan(x, y, w, h, side, attrs, fs=10.5):
    k = len(attrs); gap = 0.72
    for i, at in enumerate(attrs):
        off = (i-(k-1)/2)*gap; pk = i == 0 and fs > 10.4 and h == BH
        if side in ("up", "down"):
            sg = -1 if side == "up" else 1
            cx_, cy_ = x+off, y+sg*(h/2+1.4)
            tx, ty = edge_point(x, y, w, h, cx_, cy_)
            ax.plot([cx_, tx], [cy_, ty], color=TXT, lw=0.9, zorder=1)
            ax.text(cx_, cy_+sg*0.25, at, rotation=90, ha="center", va="bottom" if side == "up" else "top",
                    fontsize=fs, fontweight="bold" if pk else "normal", color=TXT, zorder=4)
        else:
            sg = -1 if side == "left" else 1
            cx_, cy_ = x+sg*(w/2+1.8), y+off
            tx, ty = edge_point(x, y, w, h, cx_, cy_)
            ax.plot([cx_, tx], [cy_, ty], color=TXT, lw=0.9, zorder=1)
            ax.text(cx_+sg*0.25, cy_, at, ha="right" if side == "left" else "left", va="center",
                    fontsize=fs, fontweight="bold" if pk else "normal", color=TXT, zorder=4)
        ax.add_patch(Circle((cx_, cy_), 0.14, fc=TXT if pk else "white", ec=TXT, lw=1.3, zorder=4))
for (a, lab, b, ca, cb, rs, ra) in R:
    xa, ya = E[a][:2]; xb, yb = E[b][:2]
    mx, my = (xa+xb)/2, (ya+yb)/2
    for n, c in ((a, ca), (b, cb)):
        x, y = E[n][:2]
        ax.plot([x, mx], [y, my], color=TXT, lw=1.6, zorder=1)
        ex, ey = edge_point(x, y, BW(n), BH, mx, my)
        dx, dy = mx-x, my-y; L = (dx*dx+dy*dy)**.5; ux, uy = dx/L, dy/L
        ax.text(ex+ux*0.55-uy*0.3, ey+uy*0.55+ux*0.3, c, color=COR, fontsize=11, fontweight="bold", ha="center", va="center", zorder=5,
                bbox=dict(fc="white", ec="none", pad=0.6))
    dw, dh = 0.5+0.1*len(lab), 0.55
    ax.add_patch(Polygon([(mx-dw,my),(mx,my-dh),(mx+dw,my),(mx,my+dh)], fc="white", ec=TXT, lw=1.6, zorder=3))
    ax.text(mx, my, lab, fontsize=9.5, ha="center", va="center", zorder=4, color=TXT)
    if ra: fan(mx, my, 2*dw, 2*dh, rs, ra, fs=10)
for n, (x, y, side, attrs) in E.items():
    w = BW(n)
    ax.add_patch(Rectangle((x-w/2, y-BH/2), w, BH, fc=DEST, ec=COR, lw=2.2, zorder=3))
    ax.text(x, y, n, fontsize=11.5, fontweight="bold", color=COR, ha="center", va="center", zorder=4)
    fan(x, y, w, BH, side, attrs)
ax.text(-1, 2, "DER Conceitual — Palazio del Chef", fontsize=24, fontweight="bold", color=TXT, va="center")
ax.text(-1, 3.4, "Notação do BRModelo (Chen): retângulo = entidade · losango = relacionamento · círculo = atributo · cardinalidade (mín,máx). Sem chaves estrangeiras.", fontsize=12, color=TXT, va="center")
ax.text(-1, 4.5, "PEDIDO × PRODUTO e COMPRA × PRODUTO são relacionamentos N:N com atributos próprios (sem entidade Item_pedido).", fontsize=12, color=COR, va="center")
ax.add_patch(Circle((-0.8, 5.8), 0.14, fc=TXT, ec=TXT)); ax.text(-0.4, 5.8, "identificador", fontsize=11, va="center")
ax.add_patch(Circle((-0.8, 6.7), 0.14, fc="white", ec=TXT, lw=1.3)); ax.text(-0.4, 6.7, "atributo", fontsize=11, va="center")
fig.savefig("diagrama_palazio_del_chef.png", bbox_inches="tight", facecolor="white")
