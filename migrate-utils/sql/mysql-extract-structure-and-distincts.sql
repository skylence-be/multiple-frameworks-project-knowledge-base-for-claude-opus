-- MySQL/MariaDB: Extract DB structure (tables, columns, types, PK/FK) and distinct values for selected text columns
-- CONFIG: edit the variables below to fit your DB

-- NOTE: Set @db_name to the database you are connected to (or override it).
SET @db_name = DATABASE();

-- Comma-separated list of fully-qualified columns for distinct sampling: 'table.column' (schema is @db_name)
-- Example: 'orders.status,users.role'
SET @distinct_columns = '';
SET @distinct_limit = 1000; -- 0 = no limit

SELECT '=== SCHEMA OVERVIEW ===' AS header;

-- List tables
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = @db_name AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT '---' AS sep, 'COLUMNS (name, type, nullable, default)' AS header;

-- Columns with types and attributes
SELECT c.TABLE_SCHEMA,
       c.TABLE_NAME,
       c.COLUMN_NAME,
       c.COLUMN_TYPE,
       c.IS_NULLABLE,
       c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS c
         JOIN INFORMATION_SCHEMA.TABLES t
              ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
WHERE c.TABLE_SCHEMA = @db_name AND t.TABLE_TYPE = 'BASE TABLE'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

SELECT '---' AS sep, 'PRIMARY KEYS' AS header;

-- Primary keys
SELECT kcu.TABLE_SCHEMA,
       kcu.TABLE_NAME,
       kcu.CONSTRAINT_NAME,
       kcu.COLUMN_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
         JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
              ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
                  AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
                  AND kcu.TABLE_NAME = tc.TABLE_NAME
WHERE tc.TABLE_SCHEMA = @db_name AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY kcu.TABLE_NAME, kcu.ORDINAL_POSITION;

SELECT '---' AS sep, 'FOREIGN KEYS' AS header;

-- Foreign keys
SELECT kcu.TABLE_SCHEMA,
       kcu.TABLE_NAME,
       kcu.COLUMN_NAME,
       kcu.REFERENCED_TABLE_SCHEMA AS foreign_table_schema,
       kcu.REFERENCED_TABLE_NAME   AS foreign_table_name,
       kcu.REFERENCED_COLUMN_NAME  AS foreign_column_name,
       kcu.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
         JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
              ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
                  AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
                  AND tc.TABLE_NAME = kcu.TABLE_NAME
WHERE kcu.TABLE_SCHEMA = @db_name
  AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
  AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
ORDER BY kcu.TABLE_NAME, kcu.ORDINAL_POSITION;

SELECT '=== DISTINCT VALUES FOR SELECTED COLUMNS ===' AS header;

-- Iterate over comma-separated list of table.column entries and emit distinct values with counts
-- Warning: Building dynamic SQL; only include trusted identifiers.

DROP TEMPORARY TABLE IF EXISTS tmp_distinct_cols;
CREATE TEMPORARY TABLE tmp_distinct_cols (entry VARCHAR(512));

-- Split @distinct_columns by comma into rows (works on MySQL 8+); adjust if on older versions
SET @csv = TRIM(BOTH ' ' FROM @distinct_columns);
IF @csv <> '' THEN
SET @sql := CONCAT(
    'INSERT INTO tmp_distinct_cols(entry) ',
    "SELECT TRIM(x) FROM (SELECT REPLACE(REPLACE(@csv, ', ', ','), ' ,', ',') AS s) t1 ",
    'JOIN JSON_TABLE(CONCAT("[\"", REPLACE(t1.s, ",", "\",\""), "\"]"), ',
    '"$[*]" COLUMNS(x VARCHAR(512) PATH "$")) jt'
    );
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
END IF;
-- Cursor over entries
BEGIN DECLARE done INT DEFAULT FALSE;
DECLARE v_entry VARCHAR(512);
DECLARE cur CURSOR FOR
    SELECT
        entry
    FROM
        tmp_distinct_cols;
DECLARE CONTINUE HANDLER FOR NOT FOUND
SET
    done = TRUE;
OPEN cur;
read_loop: LOOP FETCH cur INTO v_entry;
IF done THEN LEAVE read_loop;
END IF;
-- Parse table and column
SET
    @tbl = SUBSTRING_INDEX(v_entry, '.', 1);
SET
    @col = SUBSTRING_INDEX(v_entry, '.', -1);
SET
    @q := CONCAT(
    'SELECT ',
    QUOTE(v_entry),
    ' AS column_ref, ',
    @col,
    ' AS value, COUNT(*) AS freq ',
    'FROM ',
    @db_name,
    '.',
    @tbl,
    ' GROUP BY ',
    @col,
    ' ORDER BY freq DESC'
    );
IF @distinct_limit IS NOT NULL
    AND @distinct_limit > 0 THEN
SET
    @q := CONCAT(@q, ' LIMIT ', @distinct_limit);
END IF;
SELECT
    CONCAT(
            '--- DISTINCTS: ',
            @db_name,
            '.',
            @tbl,
            '.',
            @col,
            ' ---'
    ) AS section;
PREPARE s
    FROM
    @q;
EXECUTE s;
DEALLOCATE PREPARE s;
END LOOP;
CLOSE cur;
END;