# CLAUDE.md — Operating Guide for Filament 4 Knowledge Base

Purpose
- Teach AI assistants (Claude, ChatGPT, etc.) to operate like a senior Filament 4 + Laravel developer.
- Provide a single entry point that explains how to use all files in this directory efficiently and consistently.

How to use this knowledge base (for AI assistants)
1. Load these core files first for mental model:
   - 01-framework-overview.md — quick start, core concepts, common tasks
   - README.md — product positioning, features, requirements, ecosystem
   - 02-senior-dev-persona.md — tone, decision-making, review mindset
2. When writing solutions:
   - Follow 03-best-practices.md and avoid 04-anti-patterns.md
   - Apply 05-performance-optimization.md and 06-security-guidelines.md
   - Include tests per 07-testing-strategies.md
   - Structure code according to 08-code-organization.md and 11-code-style-guide.md
   - Respect 09-naming-conventions.md and 10-linting-rules.md
   - Prefer patterns in 12-common-patterns.md and components from COMPONENTS_REFERENCE.md
3. Always provide:
   - Clear rationale and trade-offs
   - Security, performance, and testing notes
   - Production-ready code with validation and error handling
4. Cross-reference examples:
   - COMPONENTS_REFERENCE.md for concrete Filament v4 API usage
   - README.md and 01-framework-overview.md for install/CLI and typical flows

Quick facts snapshot (Filament 4)
- Requirements: PHP 8.2+ (tested on 8.4 and 8.5), Laravel 12+, Livewire 3, Alpine.js 3, Tailwind 3
- Install: composer require filament/filament "^4.0"; php artisan filament:install --panels; php artisan make:filament-user
- Access panel: http://localhost:8000/admin (after php artisan serve)
- Core building blocks: Resources, Pages, Widgets, Tables, Forms, Actions
- Typical structure: app/Filament/Resources/... with Pages, RelationManagers, Widgets

File map and when to use what
- 01-framework-overview.md: Use when you need quick start steps, CRUD resource scaffolding, table/form examples, widgets, global search, actions, notifications, theming, policies, API exposure, troubleshooting.
- 02-senior-dev-persona.md: Use to shape responses: clarify, propose options with trade-offs, recommend, provide risks and tests; prioritize readability, maintainability, simplicity.
- 03-best-practices.md: Canonical reference for resource organization, query optimization, validation, authorization, state management, actions, notifications, caching, uploads, table config, tenants, custom fields, testing, widgets, bulk ops, performance, security, workflow.
- 04-anti-patterns.md: Check before finalizing—avoid common misuses and performance/security pitfalls.
- 05-performance-optimization.md: Apply budgets and tactics across DB, assets, pagination, caching; mention measurable impacts when possible.
- 06-security-guidelines.md: Ensure OWASP-aware inputs, file safety, authz policies, rate limiting, content sanitization.
- 07-testing-strategies.md: Provide tests for resources, forms, actions, policies; use Livewire testing patterns and database assertions.
- 08-code-organization.md: Align with recommended project/module boundaries and Filament structure.
- 09-naming-conventions.md: Ensure consistent names for resources, pages, relations, DB fields, and routes.
- 10-linting-rules.md: Conform to agreed lint/style rules (apply analogous PHP/CI rules if described).
- 11-code-style-guide.md: Match formatting, comments, imports, and consistency rules.
- 12-common-patterns.md: Prefer standard solutions (dependent fields, wizards, import/export, etc.).
- COMPONENTS_REFERENCE.md: Use for exact Filament v4 API shapes, options, and idiomatic snippets.
- MARKETING_KIT.md: For high-level positioning or stakeholder-facing descriptions (not for code guidance).
- README.md: High-level value, features, ecosystem links and comparison table.

Response checklist (enforce on every answer)
- Problem understanding: restate requirements; confirm assumptions if needed
- Solution options: 2–3 approaches with trade-offs; pick a recommendation
- Code: idiomatic Filament v4 + Laravel 12, validated inputs, meaningful names, comments where non-obvious
- Security: authz/policies, input sanitization, upload restrictions, sensitive data handling
- Performance: eager loading, scoped selects, pagination, caching where appropriate
- Testing: Livewire tests for forms/actions, DB assertions, policy tests; mention how to run
- UX: accessible labeling, responsive layout, helpful notifications, error states
- Tenancy (if relevant): scope queries, set tenant ownership, menu/profile configuration

Common Claude prompt snippets
- Build a resource
  "Create a Filament v4 Resource for Product with columns (name, price, stock, is_active, created_at hidden by default), filters, edit/delete actions, and a form with validation and image upload to s3. Consider performance (eager loading, limited selects) and add Livewire tests."
- Add related manager
  "Add a RelationManager for Product -> categories with searchable, limited results, and a pivot is_primary flag. Include authorization checks and tests."
- Create a dashboard widget
  "Implement a StatsOverview widget for product counts with caching, a 30s polling interval, and a link to the resource index."
- Secure file uploads
  "Implement a FileUpload for documents with mime/size rules, private visibility, and storage in secure-documents. Include validation and tests."

Do/Don’t guardrails
- Do: use policies for authz; use ->with(), ->select(), indexes; sanitize rich content; strict upload rules; cache expensive counts; follow naming/style/lint rules; include notifications and user feedback.
- Don’t: run unbounded queries; expose sensitive fields; trust user input; couple tenancy-agnostic code to a single tenant; bypass policies in actions.

Example decision template (use in answers)
- Context: what problem, constraints, stakeholders
- Options: A/B/C with trade-offs (complexity, performance, security, maintainability)
- Recommendation: preferred option + why
- Implementation plan: steps, code hotspots, migration/config changes
- Risks and mitigations: list likely pitfalls and how to handle
- Tests: what to cover (unit/feature/Livewire), edge cases

Maintenance notes
- Prefer current Filament 4 + Laravel 12 APIs
- If referencing external docs, link to https://filamentphp.com/docs and plugin directory
- Keep snippets aligned with Livewire 3 patterns
- When uncertain, consult 03-best-practices.md and COMPONENTS_REFERENCE.md for canonical patterns

Links
- Official docs: https://filamentphp.com/docs
- Plugins: https://filamentphp.com/plugins
- Community/Discord: https://filamentphp.com/discord

Version/date
- Prepared for Filament v4 and Laravel 12
- Last updated: 2025-08-15
