-- =====================================================================
-- Palazio del Chef — Entrega 2 (MySQL 8.0)
-- 1. CREATE DATABASE
-- Script completo em um arquivo: script.sql (reúne 01 a 08 na ordem).
--   mysql -u root -p --default-character-set=utf8mb4 < script.sql
-- No MySQL Workbench: abra script.sql e execute (raio). Os arquivos 01 a 08 podem
-- ser executados separadamente, na ordem, se preferir.
-- =====================================================================
SET NAMES utf8mb4;
DROP DATABASE IF EXISTS palazio_del_chef;
CREATE DATABASE palazio_del_chef CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE palazio_del_chef;
