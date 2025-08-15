# HOWTO: Extract DB Structure and Distinct Values

This folder contains portable SQL scripts for PostgreSQL and MySQL/MariaDB that:
- Export the database structure: tables, columns, data types, nullability, default values, primary/foreign keys.
- Collect distinct values and counts for specific columns that are often used by UI selects but are stored as text instead of normalized IDs (e.g., status, category).

Files:
- postgres-extract-structure-and-distincts.sql
- mysql-extract-structure-and-distincts.sql

## Usage

1) Choose the script for your database engine.
2) Open the script and edit the CONFIG section near the top:
   - Set a schema (PostgreSQL) or database (MySQL) filter.
   - Populate the include list of columns to collect DISTINCT values for.
3) Run the script using your SQL client (psql / mysql) and redirect output to a file.

Examples:
- PostgreSQL: `psql -d mydb -f postgres-extract-structure-and-distincts.sql -o db_report_postgres.txt`
- MySQL: `mysql -D mydb < mysql-extract-structure-and-distincts.sql > db_report_mysql.txt`

## Notes

- Performance: DISTINCT on large text columns can be expensive. The scripts provide optional LIMITs; consider sampling or time window filters for very large datasets.
- Security: Review the include list carefully; avoid columns with sensitive data (PII/PHI).
- Output format: Plain text with sections separated by headers so you can paste into docs or feed back to AI tools.
- Extensibility: You can adapt the DISTINCT section to also emit top-N frequencies or export as CSV.
