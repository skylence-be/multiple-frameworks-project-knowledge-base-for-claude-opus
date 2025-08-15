# Deployment Checklist

## Pre-Deployment Requirements

### Code Quality Checks
- [ ] All tests passing (unit, integration, E2E)
- [ ] Code coverage meets minimum threshold (>80%)
- [ ] No linting errors or warnings
- [ ] No console.log statements in production code
- [ ] No commented-out code
- [ ] No TODO comments for critical features
- [ ] Code reviewed and approved
- [ ] Documentation updated

### Security Audit
- [ ] Dependencies updated (no known vulnerabilities)
- [ ] Security headers configured
- [ ] HTTPS enforced
- [ ] Environment variables secured
- [ ] API keys rotated if needed
- [ ] Input validation in place
- [ ] SQL injection prevention verified
- [ ] XSS protection enabled
- [ ] CSRF tokens implemented
- [ ] Rate limiting configured
- [ ] Authentication/authorization tested

### Performance Optimization
- [ ] Bundle size optimized (<500KB initial load)
- [ ] Images optimized and lazy loaded
- [ ] Code splitting implemented
- [ ] Caching strategy defined
- [ ] Database queries optimized
- [ ] CDN configured for static assets
- [ ] Gzip/Brotli compression enabled
- [ ] Service worker for offline capability
- [ ] Critical CSS inlined
- [ ] JavaScript deferred/async

### Database Preparation
- [ ] Database migrations tested
- [ ] Backup strategy in place
- [ ] Rollback plan prepared
- [ ] Indexes optimized
- [ ] Connection pooling configured
- [ ] Read replicas set up (if needed)
- [ ] Database monitoring enabled

### Infrastructure Setup
- [ ] Server requirements met
- [ ] Load balancer configured
- [ ] Auto-scaling policies defined
- [ ] Health checks implemented
- [ ] Monitoring tools configured
- [ ] Logging aggregation set up
- [ ] Alerting rules defined
- [ ] Backup systems verified

## Environment Configuration

### Environment Variables Checklist
```bash
# Production .env template
NODE_ENV=production
APP_URL=https://production.example.com
API_URL=https://api.example.com

# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname
DATABASE_POOL_SIZE=20
DATABASE_CONNECTION_TIMEOUT=5000

# Redis
REDIS_URL=redis://host:6379
REDIS_PASSWORD=secure_password

# Authentication
JWT_SECRET=complex_random_string_min_32_chars
JWT_EXPIRY=7d
SESSION_SECRET=another_complex_random_string

# External Services
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
AWS_REGION=us-east-1
S3_BUCKET=production-assets

# Email
SMTP_HOST=smtp.provider.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASSWORD=secure_password
FROM_EMAIL=noreply@example.com

# Monitoring
SENTRY_DSN=https://xxx@sentry.io/xxx
NEW_RELIC_LICENSE_KEY=xxx
DATADOG_API_KEY=xxx

# Feature Flags
ENABLE_NEW_FEATURE=false
MAINTENANCE_MODE=false

# Rate Limiting
RATE_LIMIT_WINDOW=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### Configuration Validation Script
```javascript
// validate-env.js
const required = [
  'NODE_ENV',
  'DATABASE_URL',
  'JWT_SECRET',
  'SESSION_SECRET'
];

const optional = [
  'REDIS_URL',
  'SENTRY_DSN',
  'AWS_ACCESS_KEY_ID'
];

function validateEnvironment() {
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  
  // Validate format
  if (process.env.NODE_ENV !== 'production') {
    console.warn('NODE_ENV is not set to production');
  }
  
  if (process.env.DATABASE_URL && !process.env.DATABASE_URL.startsWith('postgresql://')) {
    throw new Error('DATABASE_URL must be a valid PostgreSQL connection string');
  }
  
  // Check optional but recommended
  optional.forEach(key => {
    if (!process.env[key]) {
      console.warn(`Optional environment variable ${key} is not set`);
    }
  });
  
  console.log('✅ Environment validation passed');
}

validateEnvironment();
```

## Build Process

### Frontend Build Checklist
```bash
# Production build script
#!/bin/bash

echo "Starting production build..."

# Clean previous builds
rm -rf dist build

# Install dependencies
npm ci --production

# Run tests
npm run test:ci

# Build application
npm run build

# Analyze bundle size
npm run analyze

# Generate source maps (upload to error tracking)
npm run build:sourcemaps

# Verify build output
if [ ! -d "dist" ]; then
  echo "Build failed: dist directory not found"
  exit 1
fi

echo "✅ Build completed successfully"
```

### Docker Configuration
```dockerfile
# Multi-stage Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Switch to non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

## Deployment Strategies

### Blue-Green Deployment
```yaml
# kubernetes-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: myapp:v2.0.0
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Rolling Update
```bash
# Zero-downtime deployment script
#!/bin/bash

# Configuration
APP_NAME="myapp"
NEW_VERSION="v2.0.0"
HEALTH_CHECK_URL="https://api.example.com/health"

echo "Starting rolling update to $NEW_VERSION..."

# Step 1: Deploy to staging
echo "Deploying to staging..."
kubectl set image deployment/$APP_NAME-staging app=$APP_NAME:$NEW_VERSION

# Wait for rollout
kubectl rollout status deployment/$APP_NAME-staging

# Step 2: Run smoke tests
echo "Running smoke tests..."
npm run test:smoke:staging

# Step 3: Deploy to production (canary)
echo "Starting canary deployment..."
kubectl set image deployment/$APP_NAME-canary app=$APP_NAME:$NEW_VERSION

# Monitor metrics
sleep 300  # 5 minutes

# Step 4: Full production deployment
echo "Rolling out to all production instances..."
kubectl set image deployment/$APP_NAME app=$APP_NAME:$NEW_VERSION

# Monitor rollout
kubectl rollout status deployment/$APP_NAME

echo "✅ Deployment completed"
```

## Post-Deployment Verification

### Health Checks
```javascript
// healthcheck.js
const checks = {
  database: async () => {
    const result = await db.query('SELECT 1');
    return result.rows.length > 0;
  },
  
  redis: async () => {
    const result = await redis.ping();
    return result === 'PONG';
  },
  
  filesystem: async () => {
    const testFile = '/tmp/healthcheck.txt';
    await fs.writeFile(testFile, 'test');
    const content = await fs.readFile(testFile, 'utf8');
    await fs.unlink(testFile);
    return content === 'test';
  },
  
  externalAPI: async () => {
    const response = await fetch('https://api.external.com/health');
    return response.ok;
  }
};

app.get('/health', async (req, res) => {
  const results = {};
  let allHealthy = true;
  
  for (const [name, check] of Object.entries(checks)) {
    try {
      results[name] = await check();
      if (!results[name]) allHealthy = false;
    } catch (error) {
      results[name] = false;
      allHealthy = false;
    }
  }
  
  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'healthy' : 'unhealthy',
    checks: results,
    timestamp: new Date().toISOString()
  });
});
```

### Smoke Tests
```javascript
// smoke-tests.js
const smokeTests = [
  {
    name: 'Homepage loads',
    test: async () => {
      const response = await fetch(process.env.APP_URL);
      assert(response.ok, 'Homepage should return 200');
    }
  },
  {
    name: 'API health check',
    test: async () => {
      const response = await fetch(`${process.env.API_URL}/health`);
      const data = await response.json();
      assert(data.status === 'healthy', 'API should be healthy');
    }
  },
  {
    name: 'Authentication works',
    test: async () => {
      const response = await fetch(`${process.env.API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: process.env.TEST_USER_EMAIL,
          password: process.env.TEST_USER_PASSWORD
        })
      });
      assert(response.ok, 'Login should succeed');
    }
  },
  {
    name: 'Database connection',
    test: async () => {
      const response = await fetch(`${process.env.API_URL}/health/db`);
      assert(response.ok, 'Database should be accessible');
    }
  }
];

async function runSmokeTests() {
  console.log('Running smoke tests...');
  const results = [];
  
  for (const { name, test } of smokeTests) {
    try {
      await test();
      results.push({ name, status: 'PASSED' });
      console.log(`✅ ${name}`);
    } catch (error) {
      results.push({ name, status: 'FAILED', error: error.message });
      console.log(`❌ ${name}: ${error.message}`);
    }
  }
  
  const failed = results.filter(r => r.status === 'FAILED');
  if (failed.length > 0) {
    console.error(`\n${failed.length} tests failed`);
    process.exit(1);
  }
  
  console.log(`\n✅ All ${results.length} smoke tests passed`);
}

runSmokeTests();
```

## Monitoring Setup

### Application Metrics
```javascript
// metrics.js
const prometheus = require('prom-client');

// Create metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || 'unknown';
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(prometheus.register.metrics());
});
```

## Rollback Plan

### Rollback Procedures
```bash
#!/bin/bash

# Rollback script
PREVIOUS_VERSION="v1.9.0"

echo "⚠️  Starting rollback to $PREVIOUS_VERSION"

# Step 1: Revert deployment
kubectl set image deployment/myapp app=myapp:$PREVIOUS_VERSION

# Step 2: Wait for rollout
kubectl rollout status deployment/myapp

# Step 3: Revert database migrations (if needed)
npm run migrate:down

# Step 4: Clear caches
redis-cli FLUSHALL

# Step 5: Verify rollback
npm run test:smoke

echo "✅ Rollback completed"
```

## Final Deployment Checklist

### Before Deployment
- [ ] All stakeholders notified
- [ ] Maintenance window scheduled
- [ ] Backup completed
- [ ] Rollback plan tested
- [ ] Load testing completed
- [ ] Security scan passed
- [ ] Documentation updated
- [ ] Support team briefed

### During Deployment
- [ ] Monitoring dashboards open
- [ ] Error tracking active
- [ ] Logs being tailed
- [ ] Health checks passing
- [ ] Smoke tests running
- [ ] Performance metrics normal
- [ ] No error spike detected

### After Deployment
- [ ] All tests passing
- [ ] Performance metrics acceptable
- [ ] Error rates normal
- [ ] User feedback positive
- [ ] Documentation published
- [ ] Post-mortem scheduled (if issues)
- [ ] Team celebration! 🎉
