#!/bin/sh
# Junta os arquivos 01 a 08 em um único script.sql (na ordem exigida pela disciplina).
cd "$(dirname "$0")"
{
  echo "-- ====================================================================="
  echo "-- Palazio del Chef — Entrega 2 — SCRIPT SQL COMPLETO (MySQL 8.0)"
  echo "-- Gerado por docs/build_script.sh a partir dos arquivos 01 a 08 desta pasta."
  echo "-- Ordem: 1 CREATE DATABASE · 2 CREATE TABLE · 3 constraints · 4 INSERT (massa de dados)"
  echo "--        regras de negócio (triggers e views) · 5 SELECT com JOIN · 6 UPDATE e DELETE"
  echo "--        7 consultas gerenciais (G01-G15) · 8 consultas de auditoria (A01-A20)"
  echo "-- Execução a partir de banco vazio (recria o banco palazio_del_chef):"
  echo "--   mysql -u root -p --default-character-set=utf8mb4 < script.sql"
  echo "-- ====================================================================="
  for f in 01_create_database.sql 02_create_tables.sql 03_massa_de_dados.sql 04_regras_triggers_views.sql \
           05_select_join.sql 06_update_delete.sql 07_consultas_gerenciais.sql 08_consultas_auditoria.sql; do
    echo; echo "-- ################ $f ################"; cat "$f"
  done
} > script.sql
echo "script.sql: $(wc -l < script.sql) linhas"
