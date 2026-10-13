-- =====================================================================
-- Palazio del Chef — Entrega 2 (PostgreSQL 16)
-- 1. CREATE DATABASE
-- Execute este arquivo conectado ao banco padrão "postgres" e, depois,
-- rode os demais (02 a 08) já conectado ao banco palazio_del_chef:
--   psql -U postgres -f 01_create_database.sql
--   psql -U postgres -d palazio_del_chef -f 02_create_tables.sql   (e assim por diante)
-- Ou rode tudo de uma vez: psql -U postgres -f palazio_del_chef_completo.sql
-- =====================================================================
DROP DATABASE IF EXISTS palazio_del_chef;
CREATE DATABASE palazio_del_chef
    ENCODING 'UTF8'
    TEMPLATE template0;
COMMENT ON DATABASE palazio_del_chef IS 'Palazio del Chef — modelo lógico da Entrega 2 (projeto acadêmico, dados fictícios)';
\connect palazio_del_chef
