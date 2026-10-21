#!/usr/bin/env python3
"""Gera docs/dicionario_dados_logico.html (arquivo único, modelo 02-03g) a partir do catálogo do MySQL
(tipos, obrigatoriedade, unicidade, padrão, CHECK, índices) + descrições do dicionário conceitual do README (seção 5.4).
Uso (com o banco criado por docs/script.sql):  python3 gerar_dicionario_logico.py"""
import re, html, collections
from catalogo_mysql import carregar, sql, gerada
colunas, pk, uq, fk, chk = carregar()
readme = open('../../README.md', encoding='utf-8').read()
sec = readme[readme.index('### 5.4 Dicionário de dados por entidade'):readme.index('### 5.5 ')]
ALIAS = {'RELACIONAMENTO CONTÉM': 'pedido_produto', 'RELACIONAMENTO POSSUI': 'compra_produto'}
desc = collections.defaultdict(dict)
for bloco in re.split(r'\n### ', sec)[1:]:
    titulo = bloco.split('\n', 1)[0]
    nome = re.match(r'([A-Za-zÀ-ú_ ]+?)(?: \*\(|$| \()', titulo).group(1).strip().upper()
    tab = ALIAS.get(nome, nome.lower())
    for linha in bloco.splitlines():
        m = re.match(r'\| ([A-Z_]+) \| [^|]+ \| [^|]+ \| (.*?) \| (.*?) \|\s*$', linha)
        if m: desc[tab][m.group(1).lower()] = (m.group(2).strip(), m.group(3).strip())
indices = collections.defaultdict(lambda: collections.OrderedDict())
for t, n, nu, c in sql("select table_name,index_name,non_unique,column_name from information_schema.statistics where table_schema='palazio_del_chef' order by table_name,index_name,seq_in_index"):
    indices[t].setdefault((n, nu), []).append(c)
def e(s): return html.escape(s or '')
def md(s): return re.sub(r'`([^`]+)`', r'<code>\1</code>', e(s)).replace('**', '')
def simples(clausula, col):
    cols = set(re.findall(r'\b([a-z]{2}_[a-z_]+)\b', clausula))
    return cols == {col}
tabelas = list(colunas)
out = ['<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
 '<title>Dicionário de Dados Lógico — Palazio del Chef (Entrega 2)</title>',
 '<style>:root{--bg:#fff;--fg:#1d1d1f;--mut:#666;--bd:#d9d9de;--hd:#f1f1f5;--ac:#7a1f2b}@media(prefers-color-scheme:dark){:root{--bg:#16161a;--fg:#ececf0;--mut:#a0a0aa;--bd:#33333b;--hd:#23232a;--ac:#e08a96}}',
 'body{font:15px/1.55 system-ui,sans-serif;background:var(--bg);color:var(--fg);max-width:1250px;margin:0 auto;padding:24px 16px}h1{color:var(--ac)}h2{margin-top:36px;border-bottom:2px solid var(--ac);padding-bottom:4px}',
 'table{border-collapse:collapse;width:100%;margin:10px 0;font-size:13.5px;display:block;overflow-x:auto}th,td{border:1px solid var(--bd);padding:5px 8px;text-align:left;vertical-align:top}th{background:var(--hd)}',
 'code{background:var(--hd);padding:1px 5px;border-radius:4px;font-size:12.5px}.n{color:var(--mut)}nav a{margin-right:10px}</style></head><body>',
 '<h1>Dicionário de Dados Lógico — Palazio del Chef</h1>',
 '<p class="n">Entrega 2 · Modelagem de Banco de Dados (UNICID) · modelo do arquivo 02-03g da disciplina · todos os exemplos e dados são fictícios.</p>',
 '<h2>1. Convenções</h2><ul>',
 '<li><b>SGBD:</b> MySQL 8.0, mecanismo InnoDB (transações, chaves estrangeiras e CHECK aplicados). <b>Codificação:</b> utf8mb4, collation utf8mb4_0900_ai_ci.</li>',
 '<li><b>Prefixos:</b> ID_ identificador, NM_ nome, DT_ data, DH_ data e hora, QT_ quantidade, VL_ valor monetário, NR_ número, TP_ tipo/situação (caractere), IN_ indicador booleano, DS_ descrição/texto livre.</li>',
 '<li><b>Restrições por coluna:</b> Obrigatório (NOT NULL), Único (UNIQUE), Padrão (DEFAULT) e Valores permitidos (CHECK de uma só coluna). CHECK que envolve várias colunas aparece abaixo de cada tabela. Descrições e regras de negócio (RNxx) vêm do dicionário conceitual do README (seção 5.4).</li>',
 '<li><b>Exemplos de valores:</b> fictícios. Senhas guardadas como hash SHA-256 com sal (RNF03).</li>',
 '<li><b>Versão:</b> v1.0 do dicionário lógico, 21/10/2026, gerada do catálogo do banco por <code>entrega-2/scripts/gerar_dicionario_logico.py</code>.</li></ul>',
 '<nav>' + ''.join(f'<a href="#{t}">{t}</a>' for t in tabelas) + '</nav>']
for i, t in enumerate(tabelas, 2):
    cs = colunas[t]
    partes = []
    for c in cs:
        n = c['nome'].upper()
        partes.append(('@' + n) if c['nome'] in pk[t] and len(pk[t]) == 1 else n if not c['nulo'] else '(' + n + ')')
    if len(pk[t]) > 1: partes = [f'@{{{" + ".join(x.upper() for x in pk[t])}}}'] + [p for p, c in zip(partes, cs) if c['nome'] not in pk[t]]
    out.append(f'<h2 id="{t}">{i}. {t.upper()}</h2><p><code>{e(t.upper())} = {e(" + ".join(partes))}</code></p>')
    out.append('<table><thead><tr><th>Atributo</th><th>Tipo físico</th><th>Obrigatório</th><th>Único</th><th>Padrão</th><th>Valores permitidos (CHECK)</th><th>Chave</th><th>Descrição</th><th>Regra de negócio</th></tr></thead><tbody>')
    usados = set()
    for c in cs:
        n = c['nome']; eh_gerada = gerada(c['extra'])
        chave = []
        if n in pk[t]: chave.append('PK')
        if n in fk[t]: chave.append(f'FK → {fk[t][n][0]}.{fk[t][n][1]}')
        padrao = ''
        if 'auto_increment' in c['extra']: padrao = 'AUTO_INCREMENT'
        elif c['padrao'] is not None: padrao = c['padrao']
        valores = []
        for nome_ck, cl in chk[t]:
            if simples(cl, n): valores.append(cl); usados.add(nome_ck)
        d, r = desc[t].get(n, ('', ''))
        if eh_gerada: d, r = 'Coluna gerada: vale id_mesa enquanto o pedido está aberto e NULL nos demais.', 'Com o índice único ux_pedido_mesa_aberto, garante um único pedido aberto por mesa (RN05).'; chave.append('gerada')
        obrig = 'Sim' if not c['nulo'] and not eh_gerada else 'Não'
        unico = 'Sim' if n in uq[t] else ('Sim (PK)' if n in pk[t] and len(pk[t]) == 1 else ('Composto' if n in pk[t] else ''))
        out.append(f'<tr><td><code>{e(n)}</code></td><td>{e(c["tipo"])}</td><td>{obrig}</td><td>{unico}</td><td>{e(padrao)}</td>'
                   f'<td>{"<br>".join("<code>" + e(v) + "</code>" for v in valores)}</td><td>{e(", ".join(chave))}</td><td>{md(d)}</td><td>{md(r)}</td></tr>')
    out.append('</tbody></table>')
    multi = [(n, cl) for n, cl in chk[t] if n not in usados]
    if multi:
        out.append('<p><b>Restrições CHECK de mais de uma coluna:</b></p><ul>' + ''.join(f'<li><code>{e(n)}</code>: <code>{e(cl)}</code></li>' for n, cl in multi) + '</ul>')
    idx = [f'{"único " if nu == "0" else ""}<code>{e(n)}</code> ({e(", ".join(cols))})' for (n, nu), cols in indices[t].items()]
    out.append('<p><b>Índices:</b> ' + '; '.join(idx) + '.</p>')
out.append('</body></html>')
open('../../docs/dicionario_dados_logico.html', 'w', encoding='utf-8').write('\n'.join(out))
print(len(tabelas), 'tabelas;', sum(len(v) for v in desc.values()), 'descrições aproveitadas do README')
