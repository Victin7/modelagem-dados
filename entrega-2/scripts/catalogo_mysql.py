"""Lê o catálogo (information_schema) do banco palazio_del_chef no MySQL e devolve estruturas Python.
Usado por gerar_modelo_logico.py e gerar_dicionario_logico.py.  Requer: banco criado com docs/script.sql."""
import subprocess, collections, re

def sql(q):
    out = subprocess.run(["mysql", "-uroot", "-N", "-B", "--default-character-set=utf8mb4", "palazio_del_chef", "-e", q],
                         capture_output=True, text=True, check=True).stdout
    return [l.split("\t") for l in out.rstrip("\n").splitlines()]

def gerada(extra):
    return "VIRTUAL GENERATED" in extra.upper() or "STORED GENERATED" in extra.upper()

def tipo(column_type):
    t = column_type.upper()
    if t == "TINYINT(1)": return "BOOLEAN"
    return re.sub(r"\s+", " ", t)

def carregar():
    colunas = collections.OrderedDict()
    for t, c, ct, nl, df, ex in sql(
        "select table_name,column_name,column_type,is_nullable,ifnull(column_default,'<<NULO>>'),extra from information_schema.columns "
        "where table_schema='palazio_del_chef' and table_name in (select table_name from information_schema.tables "
        "where table_schema='palazio_del_chef' and table_type='BASE TABLE') order by table_name,ordinal_position"):
        colunas.setdefault(t, []).append(dict(nome=c, tipo=tipo(ct), nulo=(nl == "YES"), padrao=None if df == "<<NULO>>" else df, extra=ex))
    pk = collections.defaultdict(list); uq = collections.defaultdict(set)
    for t, c, ct, cn in sql("select tc.table_name,kcu.column_name,tc.constraint_type,tc.constraint_name from information_schema.table_constraints tc "
        "join information_schema.key_column_usage kcu using (constraint_name,table_schema,table_name) "
        "where tc.table_schema='palazio_del_chef' and tc.constraint_type in ('PRIMARY KEY','UNIQUE') order by kcu.ordinal_position"):
        if ct == "PRIMARY KEY": pk[t].append(c)
        else: uq[t].add(c)
    # índice único da coluna gerada (RN05) não é UNIQUE de negócio: ignorado no dicionário
    fk = collections.defaultdict(dict)
    for t, c, rt, rc in sql("select table_name,column_name,referenced_table_name,referenced_column_name from information_schema.key_column_usage "
                            "where table_schema='palazio_del_chef' and referenced_table_name is not null"):
        fk[t][c] = (rt, rc)
    chk = collections.defaultdict(list)
    for t, n, cl in sql("select tc.table_name,cc.constraint_name,cc.check_clause from information_schema.check_constraints cc "
                        "join information_schema.table_constraints tc using (constraint_schema,constraint_name) "
                        "where cc.constraint_schema='palazio_del_chef' and tc.constraint_type='CHECK' order by 1,2"):
        cl = cl.replace("\\\\", "\\")
        cl = cl.replace("_utf8mb4\\'", "'").replace("_utf8mb4'", "'").replace("\\'", "'").replace("`", "")
        cl = re.sub(r"^\((.*)\)$", r"\1", cl)
        chk[t].append((n, cl))
    return colunas, pk, uq, fk, chk
