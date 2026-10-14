#!/usr/bin/env python3
"""Gera docs/dicionario_dados_logico.md a partir do catálogo do banco palazio_del_chef."""
import subprocess, collections
def sql(q):
    o = subprocess.run(["su","postgres","-c",f'psql -d palazio_del_chef -At -F "|" -c "{q}"'],capture_output=True,text=True,check=True).stdout
    return [l.split("|") for l in o.strip().splitlines()]
cols = sql("select table_name,column_name,data_type,coalesce(character_maximum_length::text,''),coalesce(numeric_precision::text,''),coalesce(numeric_scale::text,''),is_nullable,coalesce(column_default,'') from information_schema.columns where table_schema='public' and table_name in (select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE') order by table_name,ordinal_position")
pk=collections.defaultdict(set); fk=collections.defaultdict(dict); uq=collections.defaultdict(set)
for t,c,ct in sql("select tc.table_name,kcu.column_name,tc.constraint_type from information_schema.table_constraints tc join information_schema.key_column_usage kcu using (constraint_name,table_schema,table_name) where tc.table_schema='public' and tc.constraint_type in ('PRIMARY KEY','UNIQUE')"):
    (pk if ct=='PRIMARY KEY' else uq)[t].add(c)
for t,c,rt,rc in sql("select tc.table_name,kcu.column_name,ccu.table_name,ccu.column_name from information_schema.table_constraints tc join information_schema.key_column_usage kcu using (constraint_name,table_schema) join information_schema.constraint_column_usage ccu using (constraint_name,table_schema) where tc.constraint_type='FOREIGN KEY' and tc.table_schema='public'"): fk[t][c]=f"{rt}.{rc}"
chk=collections.defaultdict(list)
for t,d in sql("select conrelid::regclass::text, pg_get_constraintdef(oid) from pg_constraint where contype='c' and connamespace='public'::regnamespace order by 1,conname"): chk[t].append(d.replace("CHECK ","",1))
def ty(dt,ln,pr,sc): return {'character varying':f'VARCHAR({ln})','character':f'CHAR({ln})','numeric':f'NUMERIC({pr},{sc})','smallint':'SMALLINT','integer':'INTEGER','boolean':'BOOLEAN','date':'DATE','timestamp without time zone':'TIMESTAMP'}.get(dt,dt.upper())
out=["# Dicionário de dados lógico — Palazio del Chef (Entrega 2)","","Gerado do catálogo do PostgreSQL por `scripts/gerar_dicionario_logico.py`. Descrição de cada atributo no negócio: dicionário conceitual do [README](../../README.md#5--dicionário-de-dados-conceitual-preliminar) (seção 5).","","Legenda: PK chave primária · FK chave estrangeira (→ tabela.coluna) · UQ único · NN obrigatório.",""]
tabs=collections.OrderedDict()
for r in cols: tabs.setdefault(r[0],[]).append(r)
for t,rs in tabs.items():
    out+= [f"## {t}","","| Coluna | Tipo | Restrições | Padrão |","|---|---|---|---|"]
    for _,c,dt,ln,pr,sc,nl,df in rs:
        rr=[]
        if c in pk[t]: rr.append("PK")
        if c in fk[t]: rr.append(f"FK → {fk[t][c]}")
        if c in uq[t] and c not in pk[t]: rr.append("UQ")
        if nl=='NO' and c not in pk[t]: rr.append("NN")
        df="identity" if 'identity' in df.lower() else df.replace("'::","'  ::").split("::")[0] if df else ""
        out.append(f"| `{c}` | {ty(dt,ln,pr,sc)} | {', '.join(rr)} | {df} |")
    if chk[t]:
        out+=["","Regras `CHECK`:",""]+[f"- `{d}`" for d in chk[t]]
    out.append("")
open('../docs/dicionario_dados_logico.md','w').write("\n".join(out))
print(len(tabs),"tabelas")
