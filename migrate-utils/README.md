# Migrate Utils

A small, self-contained set of guides and SQL scripts to help migrate legacy projects that have been read and analyzed by an AI assistant (e.g., Claude). The goal is to:

- Structure the migration plan produced from the AI analysis into actionable steps.
- Extract the current database schema (tables, columns, types, constraints) for documentation and mapping.
- Optionally identify columns that store textual values where normalized foreign keys (IDs) are expected and collect distinct values for mapping.

Contents:
- legacy-migration-guide.md — A practical, prompt-driven workflow to have Claude (or another AI) analyze a legacy codebase and convert findings into a concrete migration plan.
- sql/ —
  - Copy-paste friendly SQL for PostgreSQL and MySQL/MariaDB to extract schema details with no CLI meta-commands.
  - Optional advanced scripts that also sample distinct values for specified columns.

Who is this for:
- Engineers migrating legacy monoliths, older frameworks, or mixed-style databases.
- Teams standardizing disparate projects into a modern stack.

How to use:
1) Read legacy-migration-guide.md to set up the analysis and migration plan.
2) Use the copy-paste SQL scripts under sql/ in your DB GUI to document schema. If needed, run the advanced scripts to collect distinct values for mapping to normalized dictionaries/enums.
3) Feed the outputs back into your AI analysis or migration strategy documents.
