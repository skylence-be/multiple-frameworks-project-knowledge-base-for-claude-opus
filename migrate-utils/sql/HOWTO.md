# HOWTO: Extract DB Structure (copy-paste friendly) and Optional Distinct Values

This folder contains two kinds of SQL scripts for PostgreSQL and MySQL/MariaDB:
- Copy-paste friendly scripts that export the database structure (tables, columns, data types, nullability, default values, primary/foreign keys) and can be run directly in GUI tools (pgAdmin, DBeaver, DataGrip, HeidiSQL, MySQL Workbench) without any command-line meta-commands.
- Advanced scripts that additionally collect distinct values for selected columns (useful for normalizing text fields). These require some light configuration.

Files:
- postgres-extract-structure.sql (copy-paste friendly; no distincts)
- mysql-extract-structure.sql (copy-paste friendly; no distincts)
- postgres-extract-structure-and-distincts.sql (advanced)
- mysql-extract-structure-and-distincts.sql (advanced)

## Usage (copy-paste friendly)

1) Open the appropriate copy-paste script in your SQL editor.
2) For PostgreSQL: If your schema is not `public`, replace the `'public'` literal with your schema name.
3) Run the whole script or section-by-section to get result sets.

## Usage (advanced scripts with distincts)

1) Choose the advanced script for your database engine.
2) Open the script and edit the CONFIG section near the top:
   - PostgreSQL: set schema_name and the array of fully-qualified columns to sample distinct values for (optional).
   - MySQL: set the comma-separated list of table.column entries to sample (optional).
3) Run the script using your SQL client or CLI.

Examples (CLI):
- PostgreSQL: `psql -d mydb -f postgres-extract-structure-and-distincts.sql -o db_report_postgres.txt`
- MySQL: `mysql -D mydb < mysql-extract-structure-and-distincts.sql > db_report_mysql.txt`

## Notes

- Performance: DISTINCT on large text columns can be expensive. Prefer the copy-paste scripts if you only need the structure.
- Security: Avoid running distinct sampling on columns with sensitive data (PII/PHI).
- Output format: Each section yields a result set suitable for copying into docs or exporting to CSV in your GUI tool.
- Extensibility: You can add more sections (e.g., indexes, checks) as needed.
