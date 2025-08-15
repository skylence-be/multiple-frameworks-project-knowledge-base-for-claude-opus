-- Postgres: Extract DB structure (tables, columns, types, PK/FK) and distinct values for selected text columns
-- CONFIG: edit these arrays to fit your DB
\echo '=== CONFIGURATION ==='
\echo 'Schema filter and distinct columns include list'

-- Set target schema (leave as public if unsure)
\set schema_name 'public'

-- Columns to include for distinct sampling, format: 'schema.table.column'
-- Example: '{"public.orders.status","public.users.role"}'
\set distinct_columns '''{}'''  -- empty by default; put as Postgres array literal string
\set distinct_limit 1000         -- LIMIT for distinct sampling per column (0 = no limit)

\echo '=== SCHEMA OVERVIEW ==='

-- List tables
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = :'schema_name' AND table_type = 'BASE TABLE'
ORDER BY table_name;

\echo '---'
\echo 'COLUMNS (name, type, nullable, default)'

-- Columns with types and attributes
SELECT c.table_schema,
       c.table_name,
       c.column_name,
       c.data_type,
       c.is_nullable,
       c.column_default
FROM information_schema.columns c
JOIN information_schema.tables t
  ON c.table_schema = t.table_schema AND c.table_name = t.table_name
WHERE c.table_schema = :'schema_name' AND t.table_type = 'BASE TABLE'
ORDER BY c.table_name, c.ordinal_position;

\echo '---'
\echo 'PRIMARY KEYS'

-- Primary keys
SELECT kc.table_schema,
       kc.table_name,
       kc.constraint_name,
       kc.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kc
  ON kc.table_schema = tc.table_schema
 AND kc.table_name = tc.table_name
 AND kc.constraint_name = tc.constraint_name
WHERE tc.table_schema = :'schema_name' AND tc.constraint_type = 'PRIMARY KEY'
ORDER BY kc.table_name, kc.ordinal_position;

\echo '---'
\echo 'FOREIGN KEYS'

-- Foreign keys
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
WHERE tc.table_schema = :'schema_name' AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, kcu.ordinal_position;

\echo '---'
\echo 'ENUM TYPES (if any)'

-- Enum types (useful when mapping text -> enum)
SELECT n.nspname AS schema_name,
       t.typname AS enum_name,
       e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = :'schema_name'
ORDER BY t.typname, e.enumsortorder;

\echo '=== DISTINCT VALUES FOR SELECTED COLUMNS ==='

-- This block loops over provided columns and prints distinct values and counts
-- Input format: :'distinct_columns' must be a Postgres array literal string, e.g. '{"public.orders.status","public.users.role"}'

DO $$
DECLARE
  cols text[] := :'distinct_columns';
  lim  integer := :distinct_limit;
  fqcn text;
  sname text;
  tname text;
  cname text;
  sql text;
BEGIN
  IF cols IS NULL OR array_length(cols,1) IS NULL THEN
    RAISE NOTICE 'No columns configured for distinct sampling.';
    RETURN;
  END IF;

  FOREACH fqcn IN ARRAY cols LOOP
    -- Expecting fqcn like schema.table.column
    sname := split_part(fqcn, '.', 1);
    tname := split_part(fqcn, '.', 2);
    cname := split_part(fqcn, '.', 3);
    RAISE NOTICE '--- DISTINCTS: %.%.% ---', sname, tname, cname;
    sql := format('SELECT %I AS value, count(*) AS freq FROM %I.%I GROUP BY %I ORDER BY freq DESC', cname, sname, tname, cname);
    IF lim IS NOT NULL AND lim > 0 THEN
      sql := sql || format(' LIMIT %s', lim);
    END IF;
    EXECUTE sql;
  END LOOP;
END$$;
