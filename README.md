# Multiple Frameworks Knowledge Base for AI Assistants

## TL;DR
**A comprehensive template system that teaches AI assistants (Claude, ChatGPT, etc.) to act as senior developers for any web framework.** Fill the templates with framework-specific knowledge → AI becomes an expert in that framework.

---

## What This Repo Does

This repository provides a structured knowledge base template that transforms AI assistants into framework experts by giving them:
- **Senior developer mindset** and decision-making patterns
- **Best practices** and anti-patterns for each framework
- **Production-ready** code patterns and examples
- **Real-world** problem-solving approaches

## Quick Start

1. **Copy the template** for your framework:
   ```bash
   cp -r template laravel-12
   ```

2. **Fill in the framework-specific details** in each file

3. **Use with AI** by referencing the knowledge base:
   ```
   "You are a senior Laravel developer. Use the knowledge base in the laravel-12 folder to help me..."
   ```

## Why This Exists

Instead of getting generic AI responses, you get:
- ✅ Production-quality code following best practices
- ✅ Framework-specific solutions and patterns
- ✅ Security and performance considerations built-in
- ✅ Proper error handling and testing strategies
- ✅ Senior developer insights and trade-off analysis

## Structure

```
template/
├── 01-framework-overview.md      # Core concepts & philosophy
├── 02-senior-dev-persona.md      # How to think like a senior dev
├── 03-best-practices.md          # What TO do
├── 04-anti-patterns.md           # What NOT to do
├── 05-performance-optimization.md # Speed & efficiency
├── 06-security-guidelines.md     # Security best practices
├── 07-testing-strategies.md      # Testing approaches
├── 08-code-organization.md       # Architecture patterns
├── 09-naming-conventions.md      # Naming standards
├── 10-linting-rules.yaml         # Code quality rules
├── 11-code-style-guide.md        # Formatting standards
├── 12-common-patterns.md         # Design patterns
├── 13-debugging-techniques.md    # Problem-solving
├── 14-error-handling.md          # Error management
├── 15-deployment-checklist.md    # Production readiness
├── 16-dependency-management.md   # Package management
├── 17-version-migration.md       # Upgrading versions
├── 18-ecosystem-tools.md         # Essential tools
├── 19-community-resources.md     # Learning resources
└── 20-decision-matrix.md         # Framework selection
```

## Supported Frameworks

Create knowledge bases for:
- **Frontend**: React, Vue, Angular, Svelte, Next.js, Nuxt, Astro
- **Backend**: Laravel, Express, NestJS, Django, Rails, FastAPI
- **Full-Stack**: T3 Stack, MEAN, MERN, Laravel + Inertia
- **CSS**: Tailwind, Bootstrap, Material-UI, Chakra UI
- **Mobile**: React Native, Flutter, Ionic
- **And more...**

## How It Works

1. **Template files** contain prompts and structures for framework knowledge
2. **You fill them** with framework-specific information
3. **AI reads them** and gains deep framework expertise
4. **Result**: AI responds like a senior developer who's worked with that framework for years

## Example Use Case

**Without Knowledge Base:**
> "How do I handle authentication in Laravel?"
> *AI gives generic authentication advice*

**With Knowledge Base:**
> "How do I handle authentication in Laravel?"
> *AI provides Laravel-specific solution using Sanctum/Passport, includes middleware setup, follows Laravel conventions, suggests testing approach, mentions security considerations*

---

*Transform any AI into your senior developer teammate for any framework.*
