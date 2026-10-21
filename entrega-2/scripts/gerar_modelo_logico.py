#!/usr/bin/env python3
"""Gera o diagrama do modelo lógico (../docs/modelo_logico.png/.svg/.dot) lendo o catálogo do MySQL.
Notação inspirada no modelo lógico do brModelo: tabela com nome no topo, coluna à esquerda e tipo à direita,
marcas PK / FK / PK,FK ao lado do tipo e cardinalidade (mín,máx) em cada ponta da ligação.
Uso (com o banco criado por docs/script.sql):  python3 gerar_modelo_logico.py"""
import subprocess, os
from catalogo_mysql import carregar, gerada
colunas, pk, uq, fk, chk = carregar()
COR = {'pedido_produto': '#fde9c9', 'compra_produto': '#fde9c9'}
dot = ['digraph L {', 'rankdir=LR; splines=true; nodesep=0.5; ranksep=1.8; pad=0.3; fontname="Helvetica";',
       'node [shape=plain fontname="Helvetica" fontsize=11]; edge [color="#444444" arrowhead=none fontname="Helvetica" fontsize=10 fontcolor="#1f3a5f" labeldistance=2.0];']
for t, cs in colunas.items():
    bg = COR.get(t, '#e7f0fb')
    rows = [f'<tr><td colspan="3" bgcolor="#1f3a5f"><font color="white"><b>{t}</b></font></td></tr>']
    for c in cs:
        if gerada(c['extra']): continue          # coluna gerada de apoio (RN05): só no dicionário
        n = c['nome']; marcas = []
        if n in pk[t]: marcas.append('PK')
        if n in fk[t]: marcas.append('FK')
        tag = ','.join(marcas)
        b1, b2 = ('<b>', '</b>') if n in pk[t] else ('', '')
        rows.append(f'<tr><td align="left" port="{n}" bgcolor="{bg}">{b1}{n}{b2}</td><td align="left" bgcolor="{bg}"><font color="#444444">{c["tipo"]}</font></td>'
                    f'<td bgcolor="{bg}">{("<font color=\"#b00020\">" + tag + "</font>") if tag else "&nbsp;"}</td></tr>')
    dot.append(f'{t} [label=<<table border="1" cellborder="0" cellspacing="0" cellpadding="3">{"".join(rows)}</table>>];')
arestas = 0
for t, d in fk.items():
    for c, (rt, rc) in d.items():
        nulo = next(x for x in colunas[t] if x['nome'] == c)['nulo']
        lado_filho = '(0,1)' if nulo else '(1,1)'
        dot.append(f'{rt} -> {t}:{c} [taillabel="(0,n)" headlabel="{lado_filho}"];')
        arestas += 1
dot.append('}')
os.makedirs('../../docs', exist_ok=True)
open('../../docs/modelo_logico.dot', 'w').write("\n".join(dot))
for fmt in ('png', 'svg'):
    subprocess.run(['dot', f'-T{fmt}', '-Gdpi=130', '../../docs/modelo_logico.dot', '-o', f'../../docs/modelo_logico.{fmt}'], check=True)
print(len(colunas), 'tabelas,', arestas, 'chaves estrangeiras')
