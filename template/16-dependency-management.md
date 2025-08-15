# Dependency Management Best Practices

## Package Management Philosophy

> "A project is only as stable as its weakest dependency"

### Core Principles:
1. **Minimize Dependencies**: Every dependency is a potential risk
2. **Audit Regularly**: Security vulnerabilities emerge constantly
3. **Lock Versions**: Reproducible builds are essential
4. **Update Strategically**: Balance stability with security
5. **Document Decisions**: Explain why each dependency exists

## Dependency Selection Criteria

### Before Adding a Dependency, Ask:
```
1. Do we really need this?
   - Can we build it ourselves reasonably?
   - Is it core to our business logic?

2. Is it actively maintained?
   - Last commit within 6 months
   - Open issues being addressed
   - Multiple contributors

3. Is it production-ready?
   - Version 1.0+ for critical dependencies
   - Good documentation
   - Test coverage

4. What's the cost?
   - Bundle size impact
   - Performance overhead
   - Learning curve
   - License compatibility

5. What are the alternatives?
   - Compare at least 3 options
   - Consider native solutions first
```

## NPM/Yarn Best Practices

### Package.json Configuration
```json
{
  "name": "my-app",
  "version": "1.0.0",
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  },
  "scripts": {
    "preinstall": "npx npm-force-resolutions",
    "postinstall": "npm audit --production",
    "audit": "npm audit fix --dry-run",
    "audit:fix": "npm audit fix",
    "outdated": "npm outdated",
    "update:check": "npx npm-check-updates",
    "update:minor": "npx npm-check-updates -u --target minor",
    "update:patch": "npx npm-check-updates -u --target patch",
    "licenses": "npx license-checker --production --summary",
    "size": "npx bundle-phobia-cli",
    "dedupe": "npm dedupe"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "eslint": "^8.42.0"
  },
  "resolutions": {
    "vulnerable-package": "^2.0.0"
  },
  "overrides": {
    "package-a": {
      "vulnerable-dep": "^1.0.0"
    }
  }
}
```

### Lock File Management
```bash
# Always commit lock files
git add package-lock.json  # npm
git add yarn.lock          # yarn
git add pnpm-lock.yaml     # pnpm

# Recreate lock file if corrupted
rm -rf node_modules package-lock.json
npm install

# Update lock file only
npm install --package-lock-only

# Install from lock file (CI)
npm ci  # Faster than npm install
```

## Version Management Strategies

### Semantic Versioning
```javascript
// Understanding version ranges
"dependencies": {
  "exact": "1.2.3",           // Exactly 1.2.3
  "patch": "~1.2.3",          // >=1.2.3 <1.3.0
  "minor": "^1.2.3",          // >=1.2.3 <2.0.0
  "major": "*",               // Any version (avoid!)
  "range": ">=1.2.3 <2.0.0",  // Custom range
  "latest": "latest"          // Always latest (avoid!)
}

// Recommended approach
"dependencies": {
  // Production: Use caret for non-breaking updates
  "express": "^4.18.2",
  "react": "^18.2.0",
  
  // Critical: Consider exact versions
  "payment-sdk": "2.1.0",
  
  // Beta/RC: Be specific
  "new-feature": "3.0.0-beta.2"
}
```

### Update Strategy
```javascript
// update-dependencies.js
const { execSync } = require('child_process');

const updateStrategies = {
  patch: {
    description: 'Safe, bug fixes only',
    command: 'npm update',
    frequency: 'weekly'
  },
  minor: {
    description: 'New features, backward compatible',
    command: 'npx npm-check-updates -u --target minor',
    frequency: 'monthly'
  },
  major: {
    description: 'Breaking changes, requires testing',
    command: 'npx npm-check-updates -u',
    frequency: 'quarterly',
    requiresReview: true
  }
};

function updateDependencies(strategy = 'patch') {
  const { command, requiresReview } = updateStrategies[strategy];
  
  // Check for vulnerabilities first
  execSync('npm audit', { stdio: 'inherit' });
  
  // Update based on strategy
  execSync(command, { stdio: 'inherit' });
  
  // Run tests
  execSync('npm test', { stdio: 'inherit' });
  
  if (requiresReview) {
    console.log('⚠️  Major updates detected. Manual review required.');
  }
}
```

## Security Management

### Automated Security Checks
```yaml
# .github/workflows/security.yml
name: Security Audit

on:
  schedule:
    - cron: '0 0 * * *'  # Daily
  push:
    paths:
      - 'package*.json'

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run npm audit
        run: |
          npm audit --production
          
      - name: Run Snyk scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
          
      - name: Check licenses
        run: |
          npx license-checker --production --onlyAllow 'MIT;Apache-2.0;BSD-3-Clause;BSD-2-Clause;ISC'
```

### Vulnerability Response Plan
```javascript
// audit-fix.js
const { execSync } = require('child_process');
const fs = require('fs');

function handleVulnerabilities() {
  try {
    // Get audit report
    const report = JSON.parse(
      execSync('npm audit --json', { encoding: 'utf8' })
    );
    
    const { vulnerabilities } = report;
    const critical = [];
    const high = [];
    
    Object.entries(vulnerabilities).forEach(([pkg, data]) => {
      if (data.severity === 'critical') critical.push(pkg);
      if (data.severity === 'high') high.push(pkg);
    });
    
    if (critical.length > 0) {
      console.error('🚨 CRITICAL vulnerabilities found:', critical);
      
      // Attempt automatic fix
      execSync('npm audit fix --force', { stdio: 'inherit' });
      
      // Verify fix
      const afterFix = JSON.parse(
        execSync('npm audit --json', { encoding: 'utf8' })
      );
      
      if (afterFix.metadata.vulnerabilities.critical > 0) {
        // Create override if fix failed
        createOverride(critical[0]);
      }
    }
    
    if (high.length > 0) {
      console.warn('⚠️  HIGH vulnerabilities found:', high);
      execSync('npm audit fix', { stdio: 'inherit' });
    }
    
  } catch (error) {
    console.error('Audit failed:', error.message);
  }
}

function createOverride(packageName) {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  
  pkg.overrides = pkg.overrides || {};
  // Add override for vulnerable package
  // This is a temporary fix - track for proper update
  
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
  console.log(`Added override for ${packageName}. This is temporary!`);
}
```

## Monorepo Dependency Management

### Workspace Configuration
```json
// package.json (root)
{
  "name": "monorepo-root",
  "private": true,
  "workspaces": [
    "packages/*",
    "apps/*"
  ],
  "scripts": {
    "install:all": "npm install --workspaces",
    "build:all": "npm run build --workspaces",
    "test:all": "npm test --workspaces",
    "audit:all": "npm audit --workspaces"
  }
}

// Lerna configuration
{
  "version": "independent",
  "npmClient": "npm",
  "command": {
    "publish": {
      "conventionalCommits": true,
      "message": "chore(release): publish"
    },
    "version": {
      "allowBranch": ["main", "release/*"]
    }
  }
}
```

### Shared Dependencies
```javascript
// packages/shared-deps/index.js
module.exports = {
  // Shared production deps
  production: {
    "lodash": "^4.17.21",
    "date-fns": "^2.29.3",
    "axios": "^1.3.0"
  },
  
  // Shared dev deps
  development: {
    "typescript": "^5.0.0",
    "eslint": "^8.42.0",
    "prettier": "^2.8.8",
    "jest": "^29.5.0"
  },
  
  // Ensure consistency
  resolutions: {
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
};

// Tool to sync dependencies
function syncDependencies() {
  const shared = require('./packages/shared-deps');
  const workspaces = ['packages/app1', 'packages/app2'];
  
  workspaces.forEach(workspace => {
    const pkgPath = `${workspace}/package.json`;
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    
    // Merge shared deps
    pkg.dependencies = { ...pkg.dependencies, ...shared.production };
    pkg.devDependencies = { ...pkg.devDependencies, ...shared.development };
    
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));
  });
}
```

## Bundle Size Management

### Size Analysis Tools
```javascript
// webpack.config.js
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin;
const CompressionPlugin = require('compression-webpack-plugin');

module.exports = {
  plugins: [
    new BundleAnalyzerPlugin({
      analyzerMode: process.env.ANALYZE ? 'server' : 'disabled'
    }),
    new CompressionPlugin({
      test: /\.(js|css|html|svg)$/,
      threshold: 8192,
      minRatio: 0.8
    })
  ],
  optimization: {
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          priority: 10
        },
        common: {
          minChunks: 2,
          priority: 5,
          reuseExistingChunk: true
        }
      }
    }
  }
};

// Size monitoring script
const maxSizes = {
  'main.js': 200 * 1024,      // 200KB
  'vendor.js': 500 * 1024,    // 500KB
  'total': 1024 * 1024        // 1MB
};

function checkBundleSize() {
  const stats = require('./dist/stats.json');
  const assets = stats.assets;
  let totalSize = 0;
  
  assets.forEach(asset => {
    totalSize += asset.size;
    
    if (maxSizes[asset.name] && asset.size > maxSizes[asset.name]) {
      console.error(`❌ ${asset.name} exceeds limit: ${asset.size} > ${maxSizes[asset.name]}`);
      process.exit(1);
    }
  });
  
  if (totalSize > maxSizes.total) {
    console.error(`❌ Total size exceeds limit: ${totalSize} > ${maxSizes.total}`);
    process.exit(1);
  }
  
  console.log('✅ Bundle size check passed');
}
```

## Alternative Package Managers

### PNPM Configuration
```yaml
# .pnpmfile.cjs
module.exports = {
  hooks: {
    readPackage(pkg, context) {
      // Override problematic packages
      if (pkg.name === 'react-redux') {
        pkg.peerDependencies = {
          ...pkg.peerDependencies,
          react: '^18.0.0'
        };
      }
      return pkg;
    }
  }
};

# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
  - '!**/test/**'
```

### Yarn Configuration
```yaml
# .yarnrc.yml
nodeLinker: node-modules
npmRegistryServer: "https://registry.npmjs.org"

packageExtensions:
  "react-redux@*":
    peerDependencies:
      react: "*"

plugins:
  - path: .yarn/plugins/@yarnpkg/plugin-workspace-tools.cjs
    spec: "@yarnpkg/plugin-workspace-tools"
```

## Dependency Documentation

### Dependency Decision Record
```markdown
# Dependency: [Package Name]

## Decision Date
YYYY-MM-DD

## Status
Active | Deprecated | Replaced

## Reason for Addition
Describe why this dependency was needed

## Alternatives Considered
- Alternative 1: Why rejected
- Alternative 2: Why rejected

## Trade-offs
- Pros: Benefits of this choice
- Cons: Drawbacks accepted

## Migration Plan (if replacing)
Steps to migrate away from this dependency

## Review Date
When to re-evaluate this decision
```

## Maintenance Checklist

### Weekly
- [ ] Run security audit
- [ ] Check for patch updates
- [ ] Review dependabot alerts

### Monthly
- [ ] Update minor versions
- [ ] Review bundle size
- [ ] Check for deprecated packages
- [ ] Update development dependencies

### Quarterly
- [ ] Evaluate major updates
- [ ] Review all dependencies for necessity
- [ ] Check license compliance
- [ ] Performance audit

### Yearly
- [ ] Full dependency audit
- [ ] Consider alternative packages
- [ ] Update Node.js version
- [ ] Archive unused packages
