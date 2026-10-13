#!/usr/bin/env python3
"""Gera sql/04_insert_carga.sql — massa de dados FICTÍCIA do Palazio del Chef (semana 06/10 a 12/10/2026).

Os volumes seguem as estimativas reais informadas pelo estabelecimento (150-300 pedidos em dias úteis,
400-550 aos sábados, ~30 mesas e ~25 bistrôs); nomes, CNPJs, telefones e valores são inventados.
Semente fixa: a mesma saída é reproduzida a cada execução.  Uso:  python3 gen_data.py [caminho_saida.sql]
"""
import random, json, sys, math
from datetime import datetime, timedelta, date
from collections import defaultdict

random.seed(20261013)
NOW = datetime(2026, 10, 12, 21, 20)
DAYS = [date(2026, 10, 6) + timedelta(days=i) for i in range(7)]          # ter .. seg
PRICE_CHANGE = datetime(2026, 10, 9, 8, 10)
SUP1 = datetime(2026, 10, 9, 5, 30)     # recebimento de compras (sexta)
SUP2 = datetime(2026, 10, 12, 5, 30)    # recebimento de compras (segunda)
INV0 = datetime(2026, 10, 6, 5, 0)      # inventário inicial
ORDERS_PER_DAY = {0: 205, 1: 250, 2: 290, 3: 480, 4: 140, 5: 210, 6: 185}  # chave = weekday() (seg=0)
HOURS = {0: (6, 23), 1: (6, 23), 2: (6, 23), 3: (6, 24), 4: (6, 24), 5: (6, 24), 6: (11, 18)}  # seg..dom -> abertura/fechamento
# ajuste: Python weekday(): seg0 ter1 qua2 qui3 sex4 sab5 dom6.  Corrige a tabela acima para a semana real:
ORDERS_PER_DAY = {1: 185, 2: 205, 3: 250, 4: 290, 5: 580, 6: 140, 0: 210}
HOURS = {0: (6, 23), 1: (6, 23), 2: (6, 23), 3: (6, 24), 4: (6, 24), 5: (6, 24), 6: (11, 18)}
HW = {6:1,7:2,8:3,9:2,10:2,11:4,12:9,13:9,14:5,15:2,16:2,17:3,18:6,19:9,20:10,21:8,22:4,23:2}

def q(s):  return "NULL" if s is None else "'" + str(s).replace("'", "''") + "'"
def ts(d): return "NULL" if d is None else "'" + d.strftime("%Y-%m-%d %H:%M:%S") + "'"
def b(x):  return "TRUE" if x else "FALSE"
def n(x):  return "NULL" if x is None else str(x)

def ean13(prefix12):
    s = sum(int(c) * (3 if i % 2 else 1) for i, c in enumerate(prefix12))
    return prefix12 + str((10 - s % 10) % 10)

def cnpj(base12):
    def dv(nums, w): 
        r = sum(a * b_ for a, b_ in zip(nums, w)) % 11
        return 0 if r < 2 else 11 - r
    nums = [int(c) for c in base12]
    d1 = dv(nums, [5,4,3,2,9,8,7,6,5,4,3,2]); nums.append(d1)
    d2 = dv(nums, [6,5,4,3,2,9,8,7,6,5,4,3,2]); nums.append(d2)
    return "".join(map(str, nums))

# ------------------------------------------------------------------ cadastros
SETORES = [(1,'Salão',False),(2,'Cozinha',True),(3,'Bar',True),(4,'Gerência',False),(5,'Limpeza',False)]
CATS = ['Entradas','Pratos','Lanches','Pizzas','Sobremesas','Cervejas','Refrigerantes e águas','Vinhos','Drinks','Sucos e cafés','Insumos']
CAT_ID = {c: i + 1 for i, c in enumerate(CATS)}
# (nome, login, função, perfil, setor, admissão, ativo)
ATEND = [
 ('Marcos Antônio Teixeira','marcos.teixeira','SOCIO','S',4,'2019-03-04',True),
 ('Patrícia Nogueira Alves','patricia.alves','GERENTE','G',4,'2021-08-16',True),
 ('Fernanda Lopes Barreto','fernanda.barreto','CAIXA','A',1,'2022-02-07',True),
 ('Diego Martins Rocha','diego.rocha','GARCOM','A',1,'2023-05-02',True),
 ('Camila Freitas Duarte','camila.duarte','GARCOM','A',1,'2023-09-11',True),
 ('Lucas Pereira Matos','lucas.matos','GARCOM','A',1,'2024-01-15',True),
 ('Juliana Ramos Costa','juliana.costa','GARCOM','A',1,'2024-06-03',True),
 ('Rafael Gomes Vieira','rafael.vieira','GARCOM','A',1,'2025-02-10',True),
 ('Bruno Carvalho Lima','bruno.lima','GARCOM','A',1,'2025-04-22',False),   # desligado na semana (só atende ter/qua)
 ('Antônio Ferreira Prado','antonio.prado','COZINHA','P',2,'2020-10-05',True),
 ('Viviane Souza Melo','viviane.melo','COZINHA','P',2,'2022-07-18',True),
 ('Gustavo Henrique Lins','gustavo.lins','COZINHA','P',2,'2024-03-25',True),
 ('Renata Campos Pinto','renata.pinto','BAR','P',3,'2022-11-14',True),
 ('Thiago Moreira Santana','thiago.santana','BAR','P',3,'2025-01-20',True),
 ('Sueli Aparecida Dias','sueli.dias','LIMPEZA','A',5,'2021-04-12',True),
]
GARCOM_IDS = [4,5,6,7,8]; GARCOM_INATIVO = 9
COZ = {2:[10,11,12], 3:[13,14]}

FORN = [  # nome, base cnpj (12 dígitos), telefone
 ('Distribuidora Vale do Sol Bebidas Ltda','123450010001','1132210101'),
 ('Adega Serra Bella Importadora Ltda','234560020001','1133220202'),
 ('Hortifruti Quintal Paulista Ltda','345670030001','1134230303'),
 ('Laticínios e Confeitaria Mantiqueira Ltda','456780040001','1135240404'),
 ('Casa de Carnes Boi Nobre Ltda','567890050001','1136250505'),
 ('Armazém Grão Dourado Comércio de Alimentos Ltda','678900060001','1137260606'),
]
F_BEB, F_ADEGA, F_HORTI, F_LATIC, F_CARNE, F_ARMAZ = 1,2,3,4,5,6

# produto: nome, categoria, setor, preço, peso, controla, alcoólico, vendável, fornecedor, pacote de compra, validade(dias), custo%
P = []
def add(nome, cat, setor, preco, peso, ctrl=False, alc=False, vend=True, forn=None, pack=1, val=None, custo=0.42):
    P.append(dict(nome=nome, cat=cat, setor=setor, preco=preco, peso=peso, ctrl=ctrl, alc=alc, vend=vend, forn=forn, pack=pack, val=val, custo=custo))
Z, B_ = 2, 3
for nm, pr, w in [('Bruschetta de tomate',28,5),('Polenta frita',32,4),('Bolinho de bacalhau (6 un)',46,3),('Carpaccio de carne',54,2),('Provoleta grelhada',48,3),('Batata frita',34,8)]:
    add(nm,'Entradas',Z,pr,w)
for nm, pr, w in [('Filé à parmegiana',69,6),('Risoto de cogumelos',72,3),('Fettuccine ao pesto',58,3),('Lasanha à bolonhesa',62,5),('Salmão grelhado',89,3),('Frango à milanesa',52,5),('Picanha na chapa',98,4),('Executivo do dia',38,9)]:
    add(nm,'Pratos',Z,pr,w)
for nm, pr, w in [('Hambúrguer Palazio',42,7),('X-Salada',34,5),('Misto quente',18,6),('Sanduíche de pernil',36,3),('Pão na chapa',9,5)]:
    add(nm,'Lanches',Z,pr,w)
for nm, pr, w in [('Pizza Margherita',58,5),('Pizza Calabresa',62,6),('Pizza Quatro Queijos',68,4),('Pizza Portuguesa',66,3)]:
    add(nm,'Pizzas',Z,pr,w)
add('Petit gâteau','Sobremesas',Z,32,4); add('Sorvete 2 bolas','Sobremesas',Z,20,3)
add('Pudim de leite','Sobremesas',Z,18,3,True,forn=F_LATIC,pack=12,val=(5,10),custo=0.35)
add('Cheesecake (fatia)','Sobremesas',Z,26,3,True,forn=F_LATIC,pack=8,val=(5,9),custo=0.40)
add('Torta de limão (fatia)','Sobremesas',Z,24,2,True,forn=F_LATIC,pack=8,val=(4,8),custo=0.40)
add('Chopp Pilsen 300 ml','Cervejas',B_,12,12)
for nm, pr, w, pk in [('Heineken long neck',14,8,24),('Original 600 ml',18,7,12),('Stella Artois 330 ml',13,6,24),('IPA artesanal 500 ml',28,2,12),('Brahma lata 350 ml',8,6,24)]:
    add(nm,'Cervejas',B_,pr,w,True,True,forn=F_BEB,pack=pk,val=(120,300),custo=0.50)
for nm, pr, w in [('Coca-Cola lata',7,9),('Guaraná Antarctica lata',7,6),('Coca-Cola Zero lata',7,5)]:
    add(nm,'Refrigerantes e águas',B_,pr,w,True,forn=F_BEB,pack=24,val=(150,240),custo=0.45)
add('Água sem gás 500 ml','Refrigerantes e águas',B_,5,8,True,forn=F_BEB,pack=12,val=(300,400),custo=0.40)
add('Água com gás 500 ml','Refrigerantes e águas',B_,6,4,True,forn=F_BEB,pack=12,val=(300,400),custo=0.40)
add('Vinho tinto Malbec (garrafa)','Vinhos',B_,98,2,True,True,forn=F_ADEGA,pack=6,custo=0.48)
add('Vinho branco Chardonnay (garrafa)','Vinhos',B_,92,1.5,True,True,forn=F_ADEGA,pack=6,custo=0.48)
add('Espumante brut (garrafa)','Vinhos',B_,120,1.5,True,True,forn=F_ADEGA,pack=6,custo=0.50)
add('Taça de vinho tinto','Vinhos',B_,28,3,False,True)
for nm, pr, w in [('Caipirinha',26,6),('Aperol Spritz',34,4),('Negroni',38,2),('Gin tônica',36,4),('Dose de whisky',30,2),('Dose de vodka',20,2)]:
    add(nm,'Drinks',B_,pr,w,False,True)
for nm, pr, w in [('Suco de laranja',14,5),('Suco de limão',12,4),('Café expresso',7,10),('Cappuccino',12,5),('Chá',8,1.5)]:
    add(nm,'Sucos e cafés',B_,pr,w)
INS = [  # nome, fornecedor, consumo diário base, custo unitário, pack, validade
 ('Farinha de trigo (kg)',F_ARMAZ,10,5.2,25,(120,200)),('Queijo muçarela (kg)',F_LATIC,9,38.0,10,(15,25)),
 ('Tomate (kg)',F_HORTI,12,7.5,10,(5,9)),('Carne bovina (kg)',F_CARNE,14,46.0,10,(4,8)),
 ('Filé de frango (kg)',F_CARNE,9,19.5,10,(4,8)),('Azeite de oliva (L)',F_ARMAZ,3,41.0,6,(300,500)),
 ('Arroz arbóreo (kg)',F_ARMAZ,4,16.0,10,(250,400)),('Café em grão (kg)',F_ARMAZ,3,52.0,5,(120,200))]
for nm, f, base, custo, pk, val in INS:
    add(nm,'Insumos',Z,0,0,True,False,False,forn=f,pack=pk,val=val,custo=0)
    P[-1]['ins'] = (base, custo)
for i, p in enumerate(P, 1):
    p['id'] = i; p['setor_id'] = p['setor']; p['cat_id'] = CAT_ID[p['cat']]
    p['barras'] = ean13(('78911' if p['vend'] else '78922') + '%07d' % (1000 + i * 17))
    p['novo'] = p['preco']
# reajuste de preço (sexta 09/10 08:10, feito pela gerente)
for nome, novo in [('Filé à parmegiana',72),('Picanha na chapa',104),('Hambúrguer Palazio',44),('Heineken long neck',15),
                   ('Original 600 ml',19),('Caipirinha',28),('Café expresso',8),('Executivo do dia',40)]:
    p = next(x for x in P if x['nome'] == nome); p['novo'] = novo
def price_at(p, dt): return p['preco'] if dt < PRICE_CHANGE else p['novo']
VEND = [p for p in P if p['vend']]
BY_CAT = defaultdict(list)
for p in VEND: BY_CAT[p['cat']].append(p)
PREP = {'Entradas':(8,15),'Pratos':(18,35),'Lanches':(10,20),'Pizzas':(20,35),'Sobremesas':(5,12),'Cervejas':(1,3),
        'Refrigerantes e águas':(1,3),'Vinhos':(2,5),'Drinks':(4,9),'Sucos e cafés':(2,7)}
MIX = {
 'manha':   {'Sucos e cafés':6,'Lanches':4,'Sobremesas':.3,'Refrigerantes e águas':1,'Entradas':.2},
 'almoco':  {'Pratos':6,'Lanches':2,'Entradas':2,'Refrigerantes e águas':4,'Sucos e cafés':3,'Sobremesas':1.5,'Cervejas':1.5,'Pizzas':.5,'Drinks':.3},
 'tarde':   {'Lanches':3,'Sucos e cafés':4,'Sobremesas':3,'Cervejas':2,'Drinks':1,'Entradas':2,'Pizzas':1,'Refrigerantes e águas':2,'Pratos':1},
 'noite':   {'Pizzas':3,'Pratos':3,'Entradas':3,'Lanches':2,'Cervejas':5,'Drinks':4,'Vinhos':1.5,'Refrigerantes e águas':3,'Sobremesas':1.5,'Sucos e cafés':.8},
}
def periodo(h): return 'manha' if h < 11 else 'almoco' if h < 15 else 'tarde' if h < 18 else 'noite'
OBS_ITEM = ['Sem cebola','Ponto mal passado','Sem gelo','Bem passado','Molho à parte','Sem pimenta']

def wchoice(items, weights): return random.choices(items, weights=weights, k=1)[0]

# ------------------------------------------------------------------ pedidos
orders = []
for d in DAYS:
    wd = d.weekday(); ini, fim = HOURS[wd]
    hours = [h for h in range(ini, fim) if h in HW and (h < fim - 1 or fim - ini < 8 or True)]
    if wd == 6: weights = {11:4,12:9,13:9,14:7,15:5,16:3,17:1}
    else:       weights = {h: HW[h] * (1.5 if wd in (3,4,5) and h >= 22 else 1) for h in hours}
    hs = [h for h in weights if ini <= h < fim]
    for _ in range(ORDERS_PER_DAY[wd]):
        h = wchoice(hs, [weights[x] for x in hs])
        t = datetime(d.year, d.month, d.day, h, random.randint(0, 59), random.randint(0, 59))
        if wd != 6 and h == fim - 1 and t.minute > 25 and fim != 24: continue
        if t > NOW - timedelta(minutes=12): continue
        orders.append(dict(open=t, dia=d))
orders.sort(key=lambda o: o['open'])

mesa_busy = defaultdict(list)
MESAS = [(i, i, 'M', random.choice([4,4,4,6,2]) if i > 4 else 4) for i in range(1, 31)] + [(30 + i, 30 + i, 'B', 2) for i in range(1, 26)]
for oid, o in enumerate(orders, 1):
    t = o['open']; h = t.hour; per = periodo(h)
    party = wchoice([1,2,3,4,5,6], [.28 if per == 'manha' else .18, .4, .15, .15, .06, .06])
    nlin = max(1, min(9, round(random.gauss(1.2 + 0.9 * party, 1.0))))
    mix = MIX[per]; cats = list(mix); cw = [mix[c] for c in cats]
    chosen = {}
    tries = 0
    while len(chosen) < nlin and tries < 40:
        tries += 1
        c = wchoice(cats, cw); p = wchoice(BY_CAT[c], [x['peso'] for x in BY_CAT[c]])
        if p['id'] in chosen: continue
        if c in ('Cervejas','Refrigerantes e águas','Vinhos','Drinks'): qt = random.randint(1, max(1, min(party, 4)))
        elif c in ('Pratos','Pizzas'): qt = 1 if random.random() < .85 else 2
        else: qt = random.randint(1, max(1, min(party, 3))) if random.random() < .4 else 1
        chosen[p['id']] = (p, qt)
    lines = []; last_pronto = t
    for p, qt in chosen.values():
        seg2 = p['cat'] in ('Sobremesas',) or (p['nome'] in ('Café expresso','Cappuccino','Chá')) or (p['cat'] in ('Cervejas','Refrigerantes e águas','Drinks','Vinhos') and random.random() < .25)
        reg = t + timedelta(minutes=random.randint(1, 6), seconds=random.randint(0, 59))
        if seg2 and len(chosen) > 1: reg += timedelta(minutes=random.randint(22, 50))
        lo, hi = PREP[p['cat']]; fator = 1 + (0.4 * random.random() if h in (12,13,19,20,21) else 0)
        prep = timedelta(seconds=int(random.uniform(lo, hi) * 60 * fator))
        pronto = reg + prep
        last_pronto = max(last_pronto, pronto)
        lines.append(dict(p=p, qt=qt, reg=reg, pronto=pronto, pr0=pronto, status='N', obs=random.choice(OBS_ITEM) if random.random() < .05 and p['setor'] == Z else None))
    cancelado = random.random() < .01
    dining = timedelta(minutes=random.randint(12, 30) if per == 'manha' else random.randint(25, 75))
    close = last_pronto + timedelta(minutes=2) + dining
    ini, fim = HOURS[o['dia'].weekday()]
    lim = datetime(o['dia'].year, o['dia'].month, o['dia'].day) + timedelta(hours=fim, minutes=10)
    if close > lim: close = max(lim, last_pronto + timedelta(minutes=6))
    if cancelado:
        close = t + timedelta(minutes=random.randint(4, 15))
        for l in lines: l['status'] = 'C'; l['pronto'] = None; l['reg'] = min(l['reg'], close - timedelta(minutes=2))
    else:
        # cancela ~1,5 % das linhas, se sobrar ao menos uma
        for l in lines:
            if len(lines) > 1 and random.random() < .015 and sum(1 for x in lines if x['status'] != 'C') > 1:
                l['status'] = 'C'; l['pronto'] = None
    # mesa livre durante todo o período
    pref = 'B' if party <= 2 and random.random() < .45 else 'M'
    cand = [m for m in MESAS if m[2] == pref and m[3] >= min(party, 4) or (m[2] == 'M' and party > 4 and m[3] >= 6)]
    cand += [m for m in MESAS if m not in cand and (m[3] >= party or party > 6)]
    random.shuffle(cand)
    mesa = None
    for m in cand:
        if all(close <= a or t >= b_ for a, b_ in mesa_busy[m[0]]): mesa = m; break
    if mesa is None: o['drop'] = True; continue
    mesa_busy[mesa[0]].append((t, close))
    if o['dia'] in (DAYS[0], DAYS[1]) and random.random() < .5: gar = GARCOM_INATIVO
    elif o['dia'] in (DAYS[0], DAYS[1]): gar = random.choice(GARCOM_IDS + [GARCOM_INATIVO])
    else: gar = random.choice(GARCOM_IDS)
    o.update(id=oid, mesa=mesa[0], gar=gar, close=close, lines=lines, cancelado=cancelado, party=party,
             taxa=(random.random() > .04), obs=None)
orders = [o for o in orders if not o.get('drop')]
for i, o in enumerate(orders, 1): o['id'] = i

# estado no instante NOW (pedidos ainda abertos)
for o in orders:
    o['aberto'] = o['close'] > NOW
    if not o['aberto']: continue
    was_canc = o['cancelado']; o['cancelado'] = False
    keep = []
    for l in o['lines']:
        if l['reg'] > NOW: continue
        if l['status'] == 'C' and not was_canc: keep.append(l); continue
        pr0 = l['pr0']
        l['pronto'] = pr0
        l['status'] = 'N' if pr0 + timedelta(minutes=2) <= NOW else 'R' if pr0 <= NOW else 'E' if l['reg'] + (pr0 - l['reg']) * 0.25 <= NOW else 'P'
        if l['status'] in ('P','E'): l['pronto'] = None
        keep.append(l)
    o['lines'] = keep; o['close'] = None
orders = [o for o in orders if o['lines']]
# totais
def tot(o):
    sub = sum(l['qt'] * price_at(l['p'], l['reg']) for l in o['lines'] if l['status'] != 'C')
    return round(sub, 2), (round(sub * .10 + 1e-9, 2) if o['taxa'] else 0)
for o in orders:
    o['sub'], o['vl_taxa'] = tot(o)

# pagamentos
pagamentos = []
for o in orders:
    if o['aberto'] or o['cancelado']: continue
    total = round(o['sub'] + o['vl_taxa'], 2)
    k = wchoice([1,2,3], [.82,.14,.04]); cents = int(round(total * 100))
    cuts = sorted(random.sample(range(1, cents), k - 1)) if k > 1 and cents > k else []
    parts = [b_ - a for a, b_ in zip([0] + cuts, cuts + [cents])]
    for part in parts:
        forma = wchoice(['P','C','B','D'], [.35,.30,.25,.10])
        pagamentos.append((o['id'], forma, part / 100, o['close'] - timedelta(seconds=random.randint(10, 150))))

# ------------------------------------------------------------------ estoque
ctrl = [p for p in P if p['ctrl']]
events = []   # (dt, id_produto, tipo, qtd, id_pedido, id_compra, motivo)
for o in orders:
    for l in o['lines']:
        if not l['p']['ctrl']: continue
        events.append((l['reg'], l['p']['id'], 'V', -l['qt'], o['id'], None, 'Baixa por venda'))
        if l['status'] == 'C':
            events.append((l['reg'] + timedelta(minutes=random.randint(2, 6)), l['p']['id'], 'E', l['qt'], o['id'], None, 'Estorno por cancelamento'))
pedidos_dia = defaultdict(int)
for o in orders: pedidos_dia[o['open'].date()] += 1
for d in DAYS[:-1]:
    ini, fim = HOURS[d.weekday()]
    at = datetime(d.year, d.month, d.day) + timedelta(hours=fim, minutes=20)
    for p in P:
        if 'ins' in p:
            qtd = max(1, round(p['ins'][0] * (pedidos_dia[d] / 200) * random.uniform(.85, 1.15)))
            events.append((at, p['id'], 'A', -qtd, None, None, 'Consumo diário de insumo (baixa manual)'))
def seg(dt): return 1 if dt < SUP1 else 2 if dt < SUP2 else 3
demand = defaultdict(lambda: [0, 0, 0])
for dt, pid, tp, qt, *_ in events: demand[pid][seg(dt) - 1] += -qt
plan = {}   # pid -> (inicial, Q1, Q2, final)
for p in ctrl:
    d1, d2, d3 = demand[p['id']]
    pk = p['pack']; ceilpk = lambda x: int(math.ceil(max(0, x) / pk) * pk)
    forcar = p['nome'] in ('Torta de limão (fatia)','Espumante brut (garrafa)','Café em grão (kg)','Heineken long neck')
    u = [random.uniform(.08, .25), random.uniform(.08, .30), 0.0 if forcar else random.uniform(.10, .35)]
    ini0 = ceilpk(d1 * (1 + u[0]) + 2)
    l1 = ini0 - d1; q1 = ceilpk(d2 * (1 + u[1]) - l1)
    l2 = l1 + q1 - d2; q2 = ceilpk(d3 * (1 + u[2]) - l2) if not forcar else ceilpk(d3 - l2)
    fin = l2 + q2 - d3
    assert min(l1, l2, fin) >= 0, (p['nome'], l1, l2, fin)
    plan[p['id']] = (ini0, q1, q2, fin)
    p['final'] = fin
    sem = d1 + d2 + d3
    p['min'] = int(max(2, round(sem * 0.14)))
# movimentos de inventário inicial e de compras
fn_nota = iter(range(48210, 49000))
compras = []; compra_itens = []
def mk_compra(dt_receb, status, itens_por_forn, gerente):
    for f, itens in itens_por_forn.items():
        cid = len(compras) + 1
        dtc = (dt_receb - timedelta(days=1)).replace(hour=16, minute=random.randint(0, 40)) if dt_receb else None
        compras.append(dict(id=cid, forn=f, ger=gerente, dh=dtc, status=status,
                            nota=('%06d' % next(fn_nota)) if status == 'R' else None, receb=dt_receb if status == 'R' else None))
        for pid, qtd in itens:
            p = P[pid - 1]
            custo = p['ins'][1] if 'ins' in p else round(p['preco'] * p['custo'], 2)
            custo = round(custo * random.uniform(.97, 1.03), 2)
            val = None
            if p['val']:
                base = (dt_receb or datetime(2026, 10, 12)).date()
                val = base + timedelta(days=random.randint(*p['val']))
            compra_itens.append((cid, pid, qtd, custo, val))
            if status == 'R': events.append((dt_receb, pid, 'C', qtd, None, cid, 'Entrada por compra NF ' + compras[-1]['nota']))
for lbl, idx, dt in (('inicial', 0, None), ('sex', 1, SUP1), ('seg', 2, SUP2)):
    if idx == 0:
        for p in ctrl: events.append((INV0, p['id'], 'A', plan[p['id']][0], None, None, 'Inventário inicial da semana'))
        continue
    por_forn = defaultdict(list)
    for p in ctrl:
        if plan[p['id']][idx] > 0: por_forn[p['forn']].append((p['id'], plan[p['id']][idx]))
    mk_compra(dt, 'R', por_forn, 2 if idx == 1 else 1)
# compra pendente (pedida na segunda) e compra cancelada (quarta)
bebidas = [p for p in ctrl if p['forn'] == F_BEB]
compras.append(dict(id=len(compras) + 1, forn=F_BEB, ger=2, dh=datetime(2026, 10, 12, 10, 5), status='P', nota=None, receb=None))
for p in random.sample(bebidas, 4): compra_itens.append((compras[-1]['id'], p['id'], p['pack'] * 4, round(p['preco'] * p['custo'], 2), None))
compras.append(dict(id=len(compras) + 1, forn=F_HORTI, ger=1, dh=datetime(2026, 10, 7, 7, 0), status='C', nota=None, receb=None))
for p in [x for x in ctrl if x['forn'] == F_HORTI]: compra_itens.append((compras[-1]['id'], p['id'], 20, P[p['id'] - 1]['ins'][1], None))
compras.sort(key=lambda c: c['dh']); remap = {}
for i, c in enumerate(compras, 1): remap[c['id']] = i; c['id'] = i
compra_itens = [(remap[a], *r) for a, *r in compra_itens]
events = [(e[0], e[1], e[2], e[3], e[4], remap.get(e[5]) if e[5] else None, e[6]) for e in events]
events.sort(key=lambda e: (e[0], e[1]))
bal = defaultdict(int)
for dt, pid, tp, qt, *_ in events:
    bal[pid] += qt; assert bal[pid] >= 0, (P[pid - 1]['nome'], dt, bal[pid])
for p in ctrl: assert bal[p['id']] == p['final'], (p['nome'], bal[p['id']], p['final'])
for p in P: p['estoque'] = bal.get(p['id'], 0); p['min'] = p.get('min', 0) if p['ctrl'] else 0

# reservas
RES = [  # mesa, cliente, tel, quando, pessoas, status
 (3,'Helena Prado','11987650001',datetime(2026,10,6,12,30),4,'T'),(8,'Carlos Eduardo Brito','11987650002',datetime(2026,10,7,20,0),5,'T'),
 (12,'Marina Souza','11987650003',datetime(2026,10,8,20,30),4,'T'),(5,'Roberto Tavares','11987650004',datetime(2026,10,9,21,0),4,'T'),
 (14,'Aline Nakamura','11987650005',datetime(2026,10,9,20,0),6,'T'),(2,'Sérgio Barbosa','11987650006',datetime(2026,10,10,13,0),4,'T'),
 (9,'Cláudia Ribeiro','11987650007',datetime(2026,10,10,20,30),6,'T'),(7,'Paulo Henrique Maia','11987650008',datetime(2026,10,10,19,30),4,'C'),
 (16,'Beatriz Cardoso','11987650009',datetime(2026,10,11,12,30),6,'T'),(4,'Fábio Lacerda','11987650010',datetime(2026,10,12,19,0),4,'T'),
 (10,'Letícia Andrade','11987650011',datetime(2026,10,13,20,0),4,'A'),(6,'Daniel Furtado','11987650012',datetime(2026,10,16,21,0),6,'A'),
 (11,'Simone Teles','11987650013',datetime(2026,10,17,20,30),6,'A'),(13,'Orlando Pimentel','11987650014',datetime(2026,10,17,13,0),4,'A'),
]

# ------------------------------------------------------------------ saída
out = []
w = out.append
def block(tabela, cols, rows, size=400):
    for i in range(0, len(rows), size):
        w("INSERT INTO %s (%s) VALUES" % (tabela, ", ".join(cols)))
        w(",\n".join("  (" + ", ".join(r) + ")" for r in rows[i:i + size]) + ";")
w("-- =====================================================================")
w("-- 4. INSERT — massa de dados FICTÍCIA (gerada por scripts/gen_data.py, semente 20261013)")
w("-- Semana simulada: ter 06/10/2026 a seg 12/10/2026; 'agora' = seg 12/10/2026 21:20.")
w("-- Nomes, CNPJs, telefones e valores são inventados; os volumes seguem as estimativas")
w("-- reais do estabelecimento. Triggers de regra de negócio ficam desabilitados só durante")
w("-- a carga histórica (inserir datas passadas), e são reabilitados no final.")
w("-- =====================================================================")
TAB = ['reserva','pedido','pedido_produto','pagamento','compra','compra_produto','movimentacao_estoque','historico_produto','produto']
for t in TAB: w("ALTER TABLE %s DISABLE TRIGGER USER;" % t)
w("")
block('setor', ['id_setor','nm_setor','in_preparo'], [(str(i), q(nm), b(pr)) for i, nm, pr in SETORES])
block('categoria', ['id_categoria','nm_categoria'], [(str(i), q(c)) for c, i in CAT_ID.items()])
block('atendente', ['id_atendente','id_setor','nm_atendente','nm_login','ds_senha_hash','tp_funcao','tp_perfil','dt_admissao','in_ativo'],
      [(str(i), str(a[4]), q(a[0]), q(a[1]), "crypt('Senha@2026', gen_salt('bf', 6))", q(a[2]), q(a[3]), q(a[5]), b(a[6])) for i, a in enumerate(ATEND, 1)])
mesas = []
for i, nr, loc, lug in MESAS:
    aberta = any(o['aberto'] and o['mesa'] == i for o in orders)
    mesas.append((str(i), str(nr), q(loc), str(lug), q('O' if aberta else 'L')))
block('mesa', ['id_mesa','nr_mesa','tp_local','qt_lugares','tp_status'], mesas)
block('fornecedor', ['id_fornecedor','nm_fornecedor','nr_cnpj','nr_telefone'],
      [(str(i), q(f[0]), q(cnpj(f[1])), q(f[2])) for i, f in enumerate(FORN, 1)])
block('produto', ['id_produto','id_setor','id_categoria','nm_produto','nr_codigo_barras','vl_preco','in_vendavel','in_alcoolico','in_controla_estoque','qt_estoque_atual','qt_estoque_minimo'],
      [(str(p['id']), str(p['setor_id']), str(p['cat_id']), q(p['nome']), q(p['barras']), '%.2f' % p['novo'], b(p['vend']), b(p['alc']), b(p['ctrl']), str(p['estoque']), str(p['min'])) for p in P])
block('historico_produto', ['id_produto','id_atendente','vl_preco_anterior','vl_preco_novo','dh_alteracao'],
      [(str(p['id']), '2', '%.2f' % p['preco'], '%.2f' % p['novo'], ts(PRICE_CHANGE)) for k, p in enumerate([x for x in P if x['novo'] != x['preco']])])
block('reserva', ['id_mesa','nm_cliente','nr_telefone','dh_reserva','qt_pessoas','tp_status'],
      [(str(m), q(c), q(t_), ts(d_), str(pp), q(s)) for m, c, t_, d_, pp, s in RES])
block('compra', ['id_compra','id_fornecedor','id_atendente','dh_compra','tp_status','nr_nota_fiscal','dh_recebimento'],
      [(str(c['id']), str(c['forn']), str(c['ger']), ts(c['dh']), q(c['status']), q(c['nota']), ts(c['receb'])) for c in compras])
block('compra_produto', ['id_compra','id_produto','qt_comprada','vl_custo_unitario','dt_validade'],
      [(str(a), str(b_), str(c_), '%.2f' % d_, q(e_.isoformat()) if e_ else 'NULL') for a, b_, c_, d_, e_ in sorted(compra_itens)])
block('pedido', ['id_pedido','id_mesa','id_atendente','dh_abertura','dh_fechamento','in_taxa_servico','tp_status','ds_observacao'],
      [(str(o['id']), str(o['mesa']), str(o['gar']), ts(o['open']), ts(o['close']), b(o['taxa']),
        q('A' if o['aberto'] else 'C' if o['cancelado'] else 'F'), q('Cliente pediu para retirar a taxa de serviço' if not o['taxa'] else None)) for o in orders], 500)
pp = []
for o in orders:
    for l in o['lines']:
        pp.append((str(o['id']), str(l['p']['id']), str(l['qt']), '%.2f' % price_at(l['p'], l['reg']), q(l['status']), ts(l['reg']), ts(l['pronto']), q(l['obs'])))
block('pedido_produto', ['id_pedido','id_produto','qt_item','vl_preco_unitario','tp_status','dh_registro','dh_pronto','ds_observacao'], pp, 500)
pagamentos.sort(key=lambda x: x[3])
block('pagamento', ['id_pedido','tp_forma','vl_pago','dh_pagamento'], [(str(a), q(f), '%.2f' % v, ts(d_)) for a, f, v, d_ in pagamentos], 500)
block('movimentacao_estoque', ['id_produto','id_pedido','id_compra','tp_movimento','qt_movimento','dh_movimento','ds_motivo'],
      [(str(pid), n(ped), n(cp), q(tp), str(qt), ts(dt), q(mo)) for dt, pid, tp, qt, ped, cp, mo in events], 500)
w("")
for t in TAB: w("ALTER TABLE %s ENABLE TRIGGER USER;" % t)
w("")
w("-- Ajusta as sequências das chaves geradas (identity) para continuar após os valores carregados")
for t, c in [('setor','id_setor'),('categoria','id_categoria'),('atendente','id_atendente'),('mesa','id_mesa'),('reserva','id_reserva'),
             ('produto','id_produto'),('historico_produto','id_historico'),('pedido','id_pedido'),('pagamento','id_pagamento'),
             ('fornecedor','id_fornecedor'),('compra','id_compra'),('movimentacao_estoque','id_movimentacao')]:
    w("SELECT setval(pg_get_serial_sequence('%s', '%s'), (SELECT COALESCE(MAX(%s), 1) FROM %s));" % (t, c, c, t))
w("ANALYZE;")
dest = sys.argv[1] if len(sys.argv) > 1 else "../sql/04_insert_carga.sql"
open(dest, "w", encoding="utf-8").write("\n".join(out) + "\n")

stats = dict(pedidos=len(orders), abertos=sum(o['aberto'] for o in orders), cancelados=sum(o['cancelado'] for o in orders),
             itens=len(pp), pagamentos=len(pagamentos), movimentacoes=len(events), compras=len(compras), produtos=len(P),
             por_dia={str(d): pedidos_dia[d] for d in DAYS},
             faturamento=round(sum(o['sub'] + o['vl_taxa'] for o in orders if not o['aberto'] and not o['cancelado']), 2))
json.dump(stats, open(dest.replace('04_insert_carga.sql', '../scripts/stats.json') if False else "stats.json", "w"), indent=1, ensure_ascii=False)
print(json.dumps(stats, indent=1, ensure_ascii=False))
