-- PostgreSQL: Copy-paste friendly schema overview (no psql meta-commands, no DISTINCT sampling)
-- How to use:
-- 1) Open this file in your SQL editor (pgAdmin, DBeaver, DataGrip, etc.).
-- 2) Option A: Run the whole file. Option B: Run each section separately.
-- 3) By default, it targets schema 'public'. Change the literal 'public' below if needed.

/* === TABLES (BASE TABLES) === */
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

/* === COLUMNS (name, type, nullable, default) === */
SELECT c.table_schema,
       c.table_name,
       c.column_name,
       c.data_type,
       c.is_nullable,
       c.column_default
FROM information_schema.columns c
JOIN information_schema.tables t
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name
WHERE c.table_schema = 'public' AND t.table_type = 'BASE TABLE'
ORDER BY c.table_name, c.ordinal_position;

/* === PRIMARY KEYS === */
SELECT kc.table_schema,
       kc.table_name,
       kc.constraint_name,
       kc.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kc
  ON kc.table_schema = tc.table_schema
 AND kc.table_name = tc.table_name
 AND kc.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public' AND tc.constraint_type = 'PRIMARY KEY'
ORDER BY kc.table_name, kc.ordinal_position;

/* === FOREIGN KEYS === */
SELECT tc.table_schema,
       tc.table_name,
       kcu.column_name,
       ccu.table_schema AS foreign_table_schema,
       ccu.table_name   AS foreign_table_name,
       ccu.column_name  AS foreign_column_name,
       tc.constraint_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
WHERE tc.table_schema = 'public' AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, kcu.ordinal_position;

/* === ENUM TYPES (if any) === */
SELECT n.nspname AS schema_name,
       t.typname AS enum_name,
       e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
ORDER BY t.typname, e.enumsortorder;
