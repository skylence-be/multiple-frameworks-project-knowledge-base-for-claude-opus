# Linting Rules Configuration

## ESLint Configuration (JavaScript/TypeScript)

```yaml
# Core linting rules for modern JavaScript/TypeScript projects
# Save as: .eslintrc.yaml

root: true

parser: '@typescript-eslint/parser'

parserOptions:
  ecmaVersion: 2023
  sourceType: module
  ecmaFeatures:
    jsx: true
  project: './tsconfig.json'

env:
  browser: true
  node: true
  es2023: true
  jest: true

extends:
  # Base configurations
  - 'eslint:recommended'
  - 'plugin:@typescript-eslint/recommended'
  - 'plugin:@typescript-eslint/recommended-requiring-type-checking'
  
  # Framework specific (uncomment as needed)
  # - 'plugin:react/recommended'
  # - 'plugin:react-hooks/recommended'
  # - 'plugin:vue/vue3-recommended'
  # - 'plugin:@angular-eslint/recommended'
  
  # Code quality
  - 'plugin:import/errors'
  - 'plugin:import/warnings'
  - 'plugin:import/typescript'
  - 'plugin:promise/recommended'
  - 'plugin:sonarjs/recommended'
  
  # Security
  - 'plugin:security/recommended'
  
  # Testing
  - 'plugin:jest/recommended'
  - 'plugin:testing-library/react' # For React
  
  # Accessibility (for React)
  # - 'plugin:jsx-a11y/recommended'
  
  # Prettier (must be last)
  - 'prettier'

plugins:
  - '@typescript-eslint'
  - 'import'
  - 'promise'
  - 'sonarjs'
  - 'security'
  - 'jest'
  - 'unicorn'
  - 'no-secrets'

rules:
  # TypeScript specific
  '@typescript-eslint/explicit-function-return-type':
    - error
    - allowExpressions: true
      allowTypedFunctionExpressions: true
  
  '@typescript-eslint/no-explicit-any':
    - error
    - ignoreRestArgs: true
  
  '@typescript-eslint/no-unused-vars':
    - error
    - argsIgnorePattern: '^_'
      varsIgnorePattern: '^_'
  
  '@typescript-eslint/naming-convention':
    - error
    - selector: interface
      format: [PascalCase]
      prefix: ['I']
    - selector: typeAlias
      format: [PascalCase]
    - selector: enum
      format: [PascalCase]
    - selector: variable
      format: [camelCase, UPPER_CASE]
    - selector: function
      format: [camelCase]
    - selector: class
      format: [PascalCase]

  # Import rules
  import/order:
    - error
    - groups:
        - builtin
        - external
        - internal
        - parent
        - sibling
        - index
      newlines-between: always
      alphabetize:
        order: asc

  import/no-duplicates: error
  import/no-cycle: error
  import/no-self-import: error

  # Code quality
  complexity:
    - error
    - max: 10

  max-depth:
    - error
    - max: 3

  max-lines:
    - error
    - max: 300
      skipBlankLines: true
      skipComments: true

  max-lines-per-function:
    - error
    - max: 50
      skipBlankLines: true
      skipComments: true

  max-params:
    - error
    - max: 3

  no-console:
    - warn
    - allow: [warn, error]

  no-debugger: error
  no-alert: error
  no-var: error
  prefer-const: error
  prefer-template: error
  prefer-arrow-callback: error
  no-param-reassign: error
  no-nested-ternary: error

  # Security
  security/detect-object-injection: warn
  security/detect-non-literal-regexp: warn
  security/detect-unsafe-regex: error
  no-secrets/no-secrets:
    - error
    - tolerance: 4.5

  # Promise handling
  promise/always-return: error
  promise/no-return-wrap: error
  promise/param-names: error
  promise/catch-or-return: error
  promise/no-nesting: warn

  # SonarJS rules for code quality
  sonarjs/cognitive-complexity:
    - error
    - 15
  sonarjs/no-duplicate-string:
    - error
    - 3
  sonarjs/no-identical-functions: error
  sonarjs/no-collapsible-if: error

  # Best practices
  eqeqeq:
    - error
    - always
  no-eval: error
  no-implied-eval: error
  no-new-func: error
  no-return-await: error
  require-await: error
  no-throw-literal: error

overrides:
  # Test files
  - files: ['**/*.test.ts', '**/*.test.tsx', '**/*.spec.ts']
    rules:
      '@typescript-eslint/no-explicit-any': off
      max-lines-per-function: off
      max-lines: off

  # Configuration files
  - files: ['*.config.js', '*.config.ts']
    rules:
      import/no-default-export: off

settings:
  import/resolver:
    typescript:
      alwaysTryTypes: true
    node:
      extensions: ['.js', '.jsx', '.ts', '.tsx']

ignorePatterns:
  - dist
  - build
  - node_modules
  - '*.min.js'
  - vendor
  - coverage
  - '*.generated.*'
```

## PHPStan Configuration (Laravel)

```neon
# phpstan.neon
parameters:
    level: 8
    paths:
        - app
        - config
        - database
        - routes
        - tests
    
    excludePaths:
        - app/Providers/TelescopeServiceProvider.php
        - database/migrations/*
    
    checkMissingIterableValueType: false
    checkGenericClassInNonGenericObjectType: false
    
    ignoreErrors:
        - '#Call to an undefined method .*#'
    
    reportUnmatchedIgnoredErrors: true
```

## Prettier Configuration

```javascript
// .prettierrc.js
module.exports = {
  printWidth: 100,
  tabWidth: 2,
  useTabs: false,
  semi: true,
  singleQuote: true,
  quoteProps: 'as-needed',
  jsxSingleQuote: false,
  trailingComma: 'es5',
  bracketSpacing: true,
  bracketSameLine: false,
  arrowParens: 'always',
  endOfLine: 'lf',
  htmlWhitespaceSensitivity: 'css',
  vueIndentScriptAndStyle: false,
  proseWrap: 'preserve',
  requirePragma: false,
  insertPragma: false,
  embeddedLanguageFormatting: 'auto',
};
```

## CommitLint Configuration

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation
        'style',    // Formatting
        'refactor', // Code restructuring
        'perf',     // Performance improvements
        'test',     // Adding tests
        'chore',    // Maintenance
        'revert',   // Revert changes
        'build',    // Build system
        'ci',       // CI configuration
      ],
    ],
    'subject-case': [2, 'never', ['start-case', 'pascal-case', 'upper-case']],
    'subject-full-stop': [2, 'never', '.'],
    'subject-max-length': [2, 'always', 72],
    'body-max-line-length': [2, 'always', 100],
  },
};
```
