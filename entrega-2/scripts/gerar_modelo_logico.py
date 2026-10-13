#!/usr/bin/env python3
"""Gera o diagrama do modelo lógico (../docs/modelo_logico.png/.svg) lendo o catálogo do banco palazio_del_chef.
Requer o banco criado (sql/palazio_del_chef_completo.sql) e Graphviz. Uso: python3 gerar_modelo_logico.py"""
import subprocess, collections, os
def sql(q):
    out = subprocess.run(["su","postgres","-c",f'psql -d palazio_del_chef -At -F "|" -c "{q}"'],capture_output=True,text=True,check=True).stdout
    return [l.split("|") for l in out.strip().splitlines()]
cols = sql("select table_name,column_name,data_type,coalesce(character_maximum_length::text,''),coalesce(numeric_precision::text,''),coalesce(numeric_scale::text,''),is_nullable from information_schema.columns where table_schema='public' and table_name in (select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE') order by table_name,ordinal_position")
pks = collections.defaultdict(set); fks = collections.defaultdict(dict); uqs = collections.defaultdict(set)
for t,c,ct in sql("select tc.table_name,kcu.column_name,tc.constraint_type from information_schema.table_constraints tc join information_schema.key_column_usage kcu using (constraint_name,table_schema,table_name) where tc.table_schema='public' and tc.constraint_type in ('PRIMARY KEY','UNIQUE')"):
    (pks if ct=='PRIMARY KEY' else uqs)[t].add(c)
edges = []
for t,c,rt in sql("select tc.table_name,kcu.column_name,ccu.table_name from information_schema.table_constraints tc join information_schema.key_column_usage kcu using (constraint_name,table_schema) join information_schema.constraint_column_usage ccu using (constraint_name,table_schema) where tc.constraint_type='FOREIGN KEY' and tc.table_schema='public'"):
    fks[t][c]=rt; edges.append((t,c,rt))
def tipo(dt,ln,pr,sc):
    return {'character varying':f'VARCHAR({ln})','character':f'CHAR({ln})','numeric':f'NUMERIC({pr},{sc})','smallint':'SMALLINT','integer':'INTEGER','boolean':'BOOLEAN','date':'DATE','timestamp without time zone':'TIMESTAMP'}.get(dt,dt.upper())
tabs = collections.OrderedDict()
for t,c,dt,ln,pr,sc,nl in cols: tabs.setdefault(t,[]).append((c,tipo(dt,ln,pr,sc),nl))
COR = {'pedido_produto':'#fde9c9','compra_produto':'#fde9c9'}
dot = ['digraph L {','rankdir=LR; splines=true; nodesep=0.5; ranksep=1.3; pad=0.3; fontname="Helvetica";',
       'node [shape=plain fontname="Helvetica" fontsize=11]; edge [color="#555555" arrowsize=0.8 fontname="Helvetica" fontsize=9];']
for t,cs in tabs.items():
    bg = COR.get(t,'#e7f0fb')
    rows = [f'<tr><td colspan="3" bgcolor="#1f3a5f"><font color="white"><b>{t}</b></font></td></tr>']
    for c,ty,nl in cs:
        tag = 'PK' if c in pks[t] else ''
        if c in fks[t]: tag = (tag+',FK').strip(',')
        elif c in uqs[t] and c not in pks[t]: tag = 'UQ'
        nn = '' if nl=='YES' else ' NN'
        b1,b2 = ('<b>','</b>') if c in pks[t] else ('','')
        rows.append(f'<tr><td align="left" port="{c}" bgcolor="{bg}">{b1}{c}{b2}</td><td align="left" bgcolor="{bg}"><font color="#444444">{ty}{nn if c not in pks[t] else ""}</font></td><td bgcolor="{bg}">{('<font color="#b00020">'+tag+'</font>') if tag else '&nbsp;'}</td></tr>')
    dot.append(f'{t} [label=<<table border="1" cellborder="0" cellspacing="0" cellpadding="3">{"".join(rows)}</table>>];')
for t,c,rt in edges:
    dot.append(f'{t}:{c} -> {rt} [arrowhead=crowodot arrowtail=tee dir=both];' if False else f'{rt} -> {t}:{c} [arrowhead=crow arrowtail=tee dir=both];')
dot.append('}')
os.makedirs('../docs',exist_ok=True)
open('../docs/modelo_logico.dot','w').write("\n".join(dot))
for fmt in ('png','svg'): subprocess.run(['dot',f'-T{fmt}','-Gdpi=130','../docs/modelo_logico.dot','-o',f'../docs/modelo_logico.{fmt}'],check=True)
print(len(tabs),'tabelas,',len(edges),'chaves estrangeiras')
