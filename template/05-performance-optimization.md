# Performance Optimization Guide

## Performance Mindset

> "Premature optimization is the root of all evil" - Donald Knuth
> 
> BUT: "Performance is a feature" - Modern Web Development

### The Right Approach:
1. **Measure First**: Use profiling tools to identify bottlenecks
2. **Optimize What Matters**: Focus on the critical path
3. **Set Performance Budgets**: Define acceptable thresholds
4. **Monitor Continuously**: Track performance in production

## Core Web Vitals & Metrics

### Key Metrics to Track:
- **LCP (Largest Contentful Paint)**: < 2.5s
- **FID (First Input Delay)**: < 100ms
- **CLS (Cumulative Layout Shift)**: < 0.1
- **TTFB (Time to First Byte)**: < 200ms
- **FCP (First Contentful Paint)**: < 1.8s

## Frontend Performance

### 1. Bundle Size Optimization
```javascript
// Techniques:
- Code splitting
- Tree shaking
- Dynamic imports
- Lazy loading
- Minification
- Compression (gzip/brotli)

// Example: Dynamic imports
const HeavyComponent = lazy(() => import('./HeavyComponent'));
```

### 2. Asset Optimization
- **Images**: Use WebP/AVIF, lazy load, responsive images
- **Fonts**: Subset fonts, use font-display: swap
- **CSS**: Critical CSS inline, defer non-critical
- **JavaScript**: Defer/async scripts appropriately

### 3. Rendering Performance
```javascript
// GOOD: Virtualization for large lists
import { VirtualList } from 'virtual-list-library';

// GOOD: Debouncing expensive operations
const debouncedSearch = debounce(searchFunction, 300);

// GOOD: Using CSS transforms instead of layout properties
transform: translateX(100px); // Good
left: 100px; // Triggers reflow
```

### 4. React/Vue/Angular Specific
```javascript
// React: Memoization
const MemoizedComponent = memo(ExpensiveComponent);
const memoizedValue = useMemo(() => computeExpensive(a, b), [a, b]);

// Vue: Computed properties
computed: {
  expensiveComputation() {
    return this.items.reduce(/* ... */);
  }
}

// Angular: OnPush change detection
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush
})
```

## Backend Performance

### 1. Database Optimization

#### Query Optimization:
```sql
-- BAD: N+1 problem
SELECT * FROM users;
-- Then for each user:
SELECT * FROM posts WHERE user_id = ?;

-- GOOD: Eager loading
SELECT users.*, posts.*
FROM users
LEFT JOIN posts ON users.id = posts.user_id;
```

#### Indexing Strategy:
```sql
-- Index frequently queried columns
CREATE INDEX idx_users_email ON users(email);

-- Composite indexes for multiple columns
CREATE INDEX idx_posts_user_created ON posts(user_id, created_at);

-- Partial indexes for filtered queries
CREATE INDEX idx_active_users ON users(status) WHERE status = 'active';
```

### 2. Caching Strategies

```javascript
// Cache Levels:
// 1. Browser Cache (HTTP headers)
res.setHeader('Cache-Control', 'public, max-age=31536000');

// 2. CDN Cache
// Configure at CDN level

// 3. Application Cache (Redis/Memcached)
const cached = await redis.get(key);
if (cached) return cached;

const result = await expensiveOperation();
await redis.set(key, result, 'EX', 3600);

// 4. Database Query Cache
// Configure at database level
```

### 3. API Optimization

```javascript
// Pagination
app.get('/api/users', async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;
  
  const users = await db.users.findAll({
    limit,
    offset,
    attributes: ['id', 'name', 'email'] // Select only needed fields
  });
});

// GraphQL: Avoid over-fetching
query {
  user(id: 1) {
    name
    email
    # Don't request fields you don't need
  }
}
```

### 4. Async Processing

```javascript
// Move heavy operations to background jobs
app.post('/api/report', async (req, res) => {
  // Don't do this synchronously
  // const report = await generateHeavyReport();
  
  // Do this instead
  const jobId = await queue.add('generate-report', req.body);
  res.json({ jobId, status: 'processing' });
});
```

## Memory Management

### Preventing Memory Leaks:
```javascript
// Clear timers
const timer = setTimeout(...);
clearTimeout(timer);

// Remove event listeners
element.addEventListener('click', handler);
element.removeEventListener('click', handler);

// Clear references
let cache = new Map();
// When done:
cache.clear();
cache = null;

// Weak references for caches
const cache = new WeakMap();
```

## Network Optimization

### 1. HTTP/2 and HTTP/3
- Enable server push
- Multiplex requests
- Header compression

### 2. Compression
```javascript
// Express example
const compression = require('compression');
app.use(compression());
```

### 3. Connection Pooling
```javascript
// Database connection pool
const pool = new Pool({
  max: 20,
  min: 5,
  idle: 10000
});
```

## Monitoring & Profiling Tools

### Frontend Tools:
- Chrome DevTools Performance tab
- Lighthouse
- WebPageTest
- Bundle analyzers

### Backend Tools:
- APM tools (New Relic, DataDog)
- Database query analyzers
- Load testing tools (k6, JMeter)
- Profilers (Node.js --inspect, pprof)

## Performance Checklist

### Before Deployment:
- [ ] Run Lighthouse audit
- [ ] Check bundle sizes
- [ ] Verify lazy loading works
- [ ] Test with slow network
- [ ] Profile database queries
- [ ] Load test critical endpoints
- [ ] Set up monitoring alerts

### Common Performance Wins:
1. **Quick Wins** (< 1 hour):
   - Enable compression
   - Add caching headers
   - Optimize images
   - Minify assets

2. **Medium Effort** (1 day):
   - Implement lazy loading
   - Add database indexes
   - Set up CDN
   - Implement pagination

3. **Large Effort** (1 week+):
   - Code splitting
   - Server-side rendering
   - Database restructuring
   - Microservices migration

## Performance Budget Example

```javascript
// performance.budget.js
module.exports = {
  bundles: [
    {
      name: 'main',
      maxSize: '200kb'
    },
    {
      name: 'vendor',
      maxSize: '350kb'
    }
  ],
  metrics: {
    lighthouse: {
      performance: 90,
      accessibility: 100,
      'best-practices': 95,
      seo: 95
    }
  }
};
```
