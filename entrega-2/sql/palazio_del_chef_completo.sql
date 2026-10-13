-- Palazio del Chef — Entrega 2: script completo (executa 01 a 08 em sequência, a partir do zero).
-- Uso:  psql -U postgres -v ON_ERROR_STOP=1 -f palazio_del_chef_completo.sql
-- (execute dentro da pasta sql/, pois os \i usam caminhos relativos)
\set ON_ERROR_STOP on
\i 01_create_database.sql
\i 02_create_tables.sql
\i 03_triggers_views.sql
\i 04_insert_carga.sql
\i 05_select_join.sql
\i 06_update_delete.sql
\i 07_consultas_gerenciais.sql
\i 08_consultas_auditoria.sql
