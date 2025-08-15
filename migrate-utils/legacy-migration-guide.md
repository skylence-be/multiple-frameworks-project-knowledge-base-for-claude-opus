# Legacy Project Migration Guide (Claude-Assisted)

This guide outlines a pragmatic workflow to migrate a legacy project using an AI assistant (e.g., Claude) to read and analyze the codebase, produce a migration plan, and help validate the outcome. It is designed to be tool-agnostic and hands-on.

## 1) Prepare the Inputs

- Source Code Snapshot
  - Create a read-only snapshot of the legacy repository (zip or tar). Exclude large binaries and generated assets.
  - Include environment files and deployment descriptors where possible (sanitized of secrets).
- System Context
  - Document high-level architecture, inbound/outbound integrations, and critical business flows.
  - Note tech stack versions (frameworks, runtimes, DBs) and hosting environment.
- Data Shape
  - Run the SQL scripts in `migrate-utils/sql/` to extract schema and distinct values for suspect columns. Save the outputs.
- Constraints
  - Timeline, downtime tolerance, compliance constraints (PII/PHI/GDPR), and non-functional requirements (SLOs).

## 2) Ask Claude to Build an Inventory and Risk Map

Example prompts you can paste along with files or summaries:

- "Read this codebase snapshot and produce: (a) module inventory, (b) dependency graph, (c) framework and version usage, (d) areas with tight coupling, (e) obsolete libraries, (f) global states and side effects."
- "Identify anti-patterns that will block upgrading to <target framework/version> (e.g., deprecated APIs, reflection hacks, monkey patches). Provide file paths and code excerpts."
- "Given this DB schema report (attached), identify entities that should be normalized, columns that store text instead of IDs, and tables that should be split or merged."
- "List external integrations (e.g., email, payments, queues) with libraries/SDKs used and propose migration targets with compatibility notes."

Deliverables to ask for:
- A concise system map with hotspots.
- A prioritized risk list with effort estimates.
- A migration options matrix (in-place upgrade, strangler pattern, module-by-module rewrite) with pros/cons.

## 3) Shape the Migration Strategy

- Choose Strategy
  - In-place upgrade when API compat is high and risks are localized.
  - Strangler pattern for large monoliths or risky modules; extract seams and route traffic gradually.
  - Hybrid: upgrade core, strangle edges.
- Define Interfaces
  - Establish boundary contracts (DTOs/events) to decouple legacy and new components.
- Data Plan
  - Map textual columns to normalized lookup tables or enums. Use the distinct values export to build mappings.
  - Plan backfills and dual-writes (if necessary) with feature flags.
- Testing Approach
  - Golden master tests to lock in legacy behaviors.
  - Contract tests around boundaries and integrations.

## 4) Create an Executable Plan

- Work Breakdown Structure (WBS)
  - For each module: analysis, upgrade/rewrite, integration, tests, rollout.
- Architecture Decision Records (ADRs)
  - Capture significant decisions; use `adr/000-template.md` in this repo as a starting point.
- Cutover Plan
  - Rollout strategy (canary, blue/green), rollback procedures, data migration runbooks.

## 5) Implement with Tight Feedback Loops

- Use feature flags and toggles to ship incrementally.
- Maintain a migration ledger: what changed, when, why, by whom.
- Keep the AI assistant in the loop:
  - Share diffs and ask for targeted code reviews.
  - Ask for refactoring suggestions with clear acceptance criteria.

## 6) Validate and Harden

- Run performance/regression tests; compare SLIs/SLOs against baselines.
- Security review: authz/authn, secrets handling, dependency scanning.
- Observability: logs, metrics, traces—ensure parity or improvement vs legacy.

## 7) Data Normalization Using Distinct Values Export

- Identify Columns
  - UI select fields stored as text instead of IDs (e.g., status, category, role, type).
- Export Distincts
  - Use the SQL script to produce a list of distinct values and their counts per column.
- Build Mappings
  - Create lookup tables with stable IDs.
  - Map legacy text -> new ID; prepare backfill scripts.
- Dual-Read/Dual-Write (optional)
  - During transition, maintain both columns and verify parity.

## 8) Checklist

- [ ] Codebase inventory and dependency audit complete
- [ ] Risk register prioritized and accepted
- [ ] DB schema documented; suspect columns identified
- [ ] Strategy selected (in-place / strangler / hybrid)
- [ ] ADRs recorded for key decisions
- [ ] Test strategy in place (golden master, contracts)
- [ ] Cutover plan with rollback ready
- [ ] Data normalization mappings and backfills prepared
- [ ] Observability and security checks passed

## 9) Artifacts to Archive

- AI analysis summaries and conversations
- Schema exports, distinct values reports, and mapping tables
- ADRs and runbooks

## Appendix: Tips for Better AI Analysis

- Provide structure: folder trees, key files, and context upfront.
- Ask for concrete artifacts: lists, tables, and file-path-indexed reports.
- Iterate: narrow focus to problematic modules and re-run deeper analysis.
- Keep sensitive data out or anonymized.
