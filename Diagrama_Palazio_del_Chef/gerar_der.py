"""Gera o DER conceitual do Palazio del Chef (notação Chen, como no BRModelo).
Uso: python3 gerar_der.py  ->  diagrama_palazio_del_chef.png
Sem chaves estrangeiras: no modelo conceitual, a ligação é feita pelo relacionamento."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, Circle

COR, TXT, DEST = "#7a1f2b", "#1d1d1f", "#f3e8ea"
E = {  # nome: (x, y, lado dos atributos, [atributos]; o primeiro é o identificador)
 "MESA":(0,0,"left",["ID_MESA","NR_MESA","TP_LOCAL","QT_LUGARES","TP_STATUS","IN_ATIVA"]),
 "RESERVA":(0,-2,"left",["ID_RESERVA","NM_CLIENTE","NR_TELEFONE","DH_RESERVA","QT_PESSOAS","TP_STATUS"]),
 "CATEGORIA":(7.5,3.4,"left",["ID_CATEGORIA","NM_CATEGORIA","IN_ATIVA"]),
 "PEDIDO":(2,0,"up",["ID_PEDIDO","DH_ABERTURA","DH_FECHAMENTO","IN_TAXA_SERVICO","TP_STATUS","DS_OBSERVACAO"]),
 "ATENDENTE":(4,0,"up",["ID_ATENDENTE","NM_ATENDENTE","NM_LOGIN","DS_SENHA_HASH","TP_PERFIL","DT_ADMISSAO","IN_ATIVO"]),
 "SETOR":(7.5,0,"right",["ID_SETOR","NM_SETOR","IN_PREPARO"]),
 "PAGAMENTO":(0,2,"left",["ID_PAGAMENTO","TP_FORMA","VL_PAGO","DH_PAGAMENTO"]),
 "HISTORICO_PRODUTO":(4.7,2,"left",["ID_HISTORICO","VL_PRECO_ANTERIOR","VL_PRECO_NOVO","DH_ALTERACAO"]),
 "PRODUTO":(7.5,2,"ur",["ID_PRODUTO","NM_PRODUTO","NR_CODIGO_BARRAS","VL_PRECO","IN_VENDAVEL","IN_ALCOOLICO","QT_ESTOQUE_ATUAL","QT_ESTOQUE_MINIMO","IN_ATIVO"]),
 "ITEM_COMPRA":(12.1,2,"right",["ID_ITEM_COMPRA","QT_COMPRADA","VL_CUSTO_UNITARIO","DT_VALIDADE"]),
 "ITEM_PEDIDO":(2,5,"left",["ID_ITEM","QT_ITEM","VL_PRECO_UNITARIO","TP_STATUS","DH_REGISTRO","DH_PRONTO","DS_OBSERVACAO"]),
 "MOVIMENTACAO_ESTOQUE":(9.9,5,"down",["ID_MOVIMENTACAO","TP_MOVIMENTO","QT_MOVIMENTO","DH_MOVIMENTO","DS_MOTIVO"]),
 "COMPRA":(12.1,-1.5,"up",["ID_COMPRA","DH_COMPRA","NR_NOTA_FISCAL","TP_STATUS","DH_RECEBIMENTO"]),
 "FORNECEDOR":(14.8,-1.5,"right",["ID_FORNECEDOR","NM_FORNECEDOR","NR_CNPJ","NR_TELEFONE","IN_ATIVO"]),
}
R = [  # (A, rótulo, B, card. em A, card. em B, deslocamento do losango 0..1)
 ("SETOR","agrupa","ATENDENTE","(0,N)","(1,1)"),
 ("SETOR","prepara","PRODUTO","(0,N)","(1,1)"),
 ("ATENDENTE","registra","PEDIDO","(0,N)","(1,1)"),
 ("MESA","recebe","PEDIDO","(0,N)","(1,1)"),
 ("PEDIDO","contém","ITEM_PEDIDO","(1,N)","(1,1)"),
 ("PRODUTO","é pedido em","ITEM_PEDIDO","(0,N)","(1,1)"),
 ("PEDIDO","é quitado por","PAGAMENTO","(0,N)","(1,1)"),
 ("PRODUTO","tem","HISTORICO_PRODUTO","(0,N)","(1,1)"),
 ("ATENDENTE","realiza","HISTORICO_PRODUTO","(0,N)","(1,1)"),
 ("ATENDENTE","efetua","COMPRA","(0,N)","(1,1)"),
 ("FORNECEDOR","fornece","COMPRA","(0,N)","(1,1)"),
 ("COMPRA","possui","ITEM_COMPRA","(1,N)","(1,1)"),
 ("PRODUTO","é comprado em","ITEM_COMPRA","(0,N)","(1,1)"),
 ("PRODUTO","sofre","MOVIMENTACAO_ESTOQUE","(0,N)","(1,1)"),
 ("MESA","recebe reserva","RESERVA","(0,N)","(1,1)"),
 ("CATEGORIA","classifica","PRODUTO","(0,N)","(1,1)"),
 ("ITEM_PEDIDO","gera","MOVIMENTACAO_ESTOQUE","(0,N)","(0,1)"),
 ("ITEM_COMPRA","gera","MOVIMENTACAO_ESTOQUE","(0,1)","(0,1)"),
]
fig, ax = plt.subplots(figsize=(37, 17), dpi=100)
ax.set_xlim(-14, 72); ax.set_ylim(25, -17); ax.axis("off"); ax.set_aspect("equal")
BW = lambda n: 0.8 + 0.36*len(n)
BH = 0.8
def edge_point(cx, cy, w, h, tx, ty):
    dx, dy = tx-cx, ty-cy
    if dx == 0 and dy == 0: return cx, cy
    s = min((w/2)/abs(dx) if dx else 9e9, (h/2)/abs(dy) if dy else 9e9)
    return cx+dx*s, cy+dy*s
SX, SY = 4.0, 3.3
for _n in E:
    _x,_y,_s,_a = E[_n]; E[_n]=(_x*SX,_y*SY,_s,_a)
mid = {}
for a, lab, b, ca, cb in R:
    xa, ya = E[a][:2]; xb, yb = E[b][:2]
    mid[(a, lab, b)] = ((xa+xb)/2, (ya+yb)/2)
for (a, lab, b, ca, cb) in R:
    mx, my = mid[(a, lab, b)]
    for n, c in ((a, ca), (b, cb)):
        x, y = E[n][:2]
        ax.plot([x, mx], [y, my], color=TXT, lw=1.6, zorder=1)
        w = BW(n)
        ex, ey = edge_point(x, y, w, BH, mx, my)
        dx, dy = mx-x, my-y; L = (dx*dx+dy*dy)**.5
        ux, uy = dx/L, dy/L
        ax.text(ex+ux*0.55-uy*0.3, ey+uy*0.55+ux*0.3, c, color=COR, fontsize=11, fontweight="bold", ha="center", va="center", zorder=5,
                bbox=dict(fc="white", ec="none", pad=0.6))
    dw, dh = 0.5+0.1*len(lab), 0.55
    ax.add_patch(Polygon([(mx-dw,my),(mx,my-dh),(mx+dw,my),(mx,my+dh)], fc="white", ec=TXT, lw=1.6, zorder=3))
    ax.text(mx, my, lab, fontsize=9.5, ha="center", va="center", zorder=4, color=TXT)
for n, (x, y, side, attrs) in E.items():
    w = BW(n)
    ax.add_patch(Rectangle((x-w/2, y-BH/2), w, BH, fc=DEST, ec=COR, lw=2.2, zorder=3))
    ax.text(x, y, n, fontsize=11.5, fontweight="bold", color=COR, ha="center", va="center", zorder=4)
    k = len(attrs); gap = 0.62
    for i, at in enumerate(attrs):
        off = (i-(k-1)/2)*gap
        pk = i == 0
        if side == "ur":
            cx_, cy_ = x+w/2+2.4, y-0.9-(k-1-i)*0.43
            tx, ty = edge_point(x, y, w, BH, cx_, cy_)
            ax.plot([cx_, tx], [cy_, ty], color=TXT, lw=0.9, zorder=1)
            ax.text(cx_+0.25, cy_, at, ha="left", va="center", fontsize=10, fontweight="bold" if pk else "normal", color=TXT, zorder=4)
            ax.add_patch(Circle((cx_, cy_), 0.14, fc=TXT if pk else "white", ec=TXT, lw=1.3, zorder=4))
        elif side in ("up", "down"):
            sg = -1 if side == "up" else 1
            cx_, cy_ = x+off, y+sg*1.8
            tx, ty = edge_point(x, y, w, BH, cx_, cy_)
            ax.plot([cx_, tx], [cy_, ty], color=TXT, lw=0.9, zorder=1)
            ax.text(cx_, cy_+sg*0.25, at, rotation=90, ha="center", va="bottom" if side == "up" else "top",
                    fontsize=10.5, fontweight="bold" if pk else "normal", color=TXT, zorder=4)
            ax.add_patch(Circle((cx_, cy_), 0.14, fc=TXT if pk else "white", ec=TXT, lw=1.3, zorder=4))
        else:
            sg = -1 if side == "left" else 1
            cx_, cy_ = x+sg*(w/2+1.8), y+off
            tx, ty = edge_point(x, y, w, BH, cx_, cy_)
            ax.plot([cx_, tx], [cy_, ty], color=TXT, lw=0.9, zorder=1)
            ax.text(cx_+sg*0.25, cy_, at, ha="right" if side == "left" else "left", va="center",
                    fontsize=10.5, fontweight="bold" if pk else "normal", color=TXT, zorder=4)
            ax.add_patch(Circle((cx_, cy_), 0.14, fc=TXT if pk else "white", ec=TXT, lw=1.3, zorder=4))
ax.text(-13.5, -14.2, "DER Conceitual — Palazio del Chef", fontsize=24, fontweight="bold", color=TXT, va="center")
ax.text(-13.5, -13.0, "Notação do BRModelo (Chen): retângulo = entidade · losango = relacionamento · círculo = atributo · cardinalidade (mín,máx). Sem chaves estrangeiras.", fontsize=12, color=TXT, va="center")
ax.add_patch(Circle((-13.3, -11.8), 0.14, fc=TXT, ec=TXT)); ax.text(-12.9, -11.8, "identificador", fontsize=11, va="center")
ax.add_patch(Circle((-13.3, -10.9), 0.14, fc="white", ec=TXT, lw=1.3)); ax.text(-12.9, -10.9, "atributo", fontsize=11, va="center")
fig.savefig("diagrama_palazio_del_chef.png", bbox_inches="tight", facecolor="white")
