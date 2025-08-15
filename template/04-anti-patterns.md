# Anti-Patterns & Common Mistakes

## Critical Anti-Patterns to Avoid

### 1. ❌ God Objects/Components
**What it looks like:**
```javascript
// BAD: One class/component doing everything
class AppController {
  handleUserAuth() { }
  sendEmails() { }
  processPayments() { }
  generateReports() { }
  manageDatabase() { }
  // ... 500 more methods
}
```

**Why it's bad:**
- Impossible to test
- Hard to maintain
- Violates Single Responsibility
- Creates tight coupling

**Do this instead:**
```javascript
// GOOD: Separated concerns
class AuthService { }
class EmailService { }
class PaymentService { }
class ReportService { }
```

### 2. ❌ Callback Hell / Promise Hell
**What it looks like:**
```javascript
// BAD: Nested callbacks/promises
getData(function(a) {
  getMoreData(a, function(b) {
    getMoreData(b, function(c) {
      getMoreData(c, function(d) {
        // Welcome to hell
      });
    });
  });
});
```

**Do this instead:**
```javascript
// GOOD: Use async/await
async function processData() {
  const a = await getData();
  const b = await getMoreData(a);
  const c = await getMoreData(b);
  const d = await getMoreData(c);
  return d;
}
```

### 3. ❌ Magic Numbers/Strings
**What it looks like:**
```javascript
// BAD: What does 86400000 mean?
if (Date.now() - lastUpdate > 86400000) {
  updateCache();
}

// BAD: Magic strings everywhere
if (user.role === 'admin') { }
```

**Do this instead:**
```javascript
// GOOD: Named constants
const ONE_DAY_IN_MS = 24 * 60 * 60 * 1000;
const USER_ROLES = {
  ADMIN: 'admin',
  USER: 'user'
};

if (Date.now() - lastUpdate > ONE_DAY_IN_MS) {
  updateCache();
}
```

### 4. ❌ Ignoring Error Handling
**What it looks like:**
```javascript
// BAD: Swallowing errors
try {
  doSomethingRisky();
} catch (e) {
  // Silent failure
}

// BAD: Not handling promises
someAsyncOperation(); // Fire and forget
```

**Do this instead:**
```javascript
// GOOD: Proper error handling
try {
  await doSomethingRisky();
} catch (error) {
  logger.error('Operation failed', { error });
  // Handle appropriately
  throw new OperationError(error);
}
```

### 5. ❌ Premature Optimization
**What it looks like:**
```javascript
// BAD: Optimizing before measuring
// Using complex caching for data that changes rarely
// Micro-optimizing loops that run once
// Building abstractions for single use cases
```

**Do this instead:**
- Measure first, optimize second
- Follow the 80/20 rule
- Optimize hot paths only
- Keep it simple until proven otherwise

### 6. ❌ Copy-Paste Programming
**What it looks like:**
```javascript
// BAD: Same code repeated everywhere
function processUser1(user) {
  // 20 lines of validation
  // 30 lines of processing
}

function processUser2(user) {
  // Same 20 lines of validation
  // Same 30 lines of processing with tiny change
}
```

**Do this instead:**
```javascript
// GOOD: DRY principle
function validateUser(user) { }
function processUser(user, options) { }
```

### 7. ❌ Tight Coupling
**What it looks like:**
```javascript
// BAD: Direct dependencies
class OrderService {
  constructor() {
    this.db = new PostgresDB(); // Hard-coded dependency
    this.email = new SendGrid(); // Can't test without SendGrid
  }
}
```

**Do this instead:**
```javascript
// GOOD: Dependency injection
class OrderService {
  constructor(database, emailService) {
    this.db = database;
    this.email = emailService;
  }
}
```

### 8. ❌ Not Using Framework Features
**What it looks like:**
- Implementing custom validation instead of framework validators
- Writing custom routing instead of using the router
- Creating custom authentication instead of framework auth
- Building custom ORM when framework provides one

**Why it's bad:**
- Reinventing the wheel
- Missing security updates
- More code to maintain
- Missing optimizations

### 9. ❌ Mutating State Directly
**What it looks like:**
```javascript
// BAD: Direct mutation
state.users.push(newUser);
props.data.value = newValue;
```

**Do this instead:**
```javascript
// GOOD: Immutable updates
setState(prev => ({
  users: [...prev.users, newUser]
}));
```

### 10. ❌ SQL Injection Vulnerabilities
**What it looks like:**
```javascript
// BAD: String concatenation
const query = `SELECT * FROM users WHERE id = ${userId}`;
```

**Do this instead:**
```javascript
// GOOD: Parameterized queries
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```

### 11. ❌ Inconsistent Naming
**What it looks like:**
```javascript
// BAD: Mixed conventions
let user_name;
let firstName;
let LastName;
function get_user() { }
function fetchUserData() { }
```

**Do this instead:**
- Pick a convention and stick to it
- Use framework conventions
- Be consistent across the codebase

### 12. ❌ Over-Engineering
**What it looks like:**
- Creating complex abstractions for simple problems
- Building generic solutions for specific use cases
- Adding layers of indirection unnecessarily
- Implementing design patterns where they don't fit

**Do this instead:**
- YAGNI (You Aren't Gonna Need It)
- Start simple, refactor when needed
- Add complexity only when justified

### 13. ❌ Under-Engineering
**What it looks like:**
- No error handling
- No input validation
- No tests
- No documentation
- No logging

**Do this instead:**
- Cover the basics first
- Add minimum viable error handling
- Validate inputs at boundaries
- Write at least critical path tests

### 14. ❌ Memory Leaks
**What it looks like:**
```javascript
// BAD: Not cleaning up
componentDidMount() {
  window.addEventListener('resize', this.handleResize);
  this.timer = setInterval(this.tick, 1000);
}
// Never removing listeners or clearing intervals
```

**Do this instead:**
```javascript
// GOOD: Proper cleanup
componentWillUnmount() {
  window.removeEventListener('resize', this.handleResize);
  clearInterval(this.timer);
}
```

### 15. ❌ Blocking the Event Loop
**What it looks like:**
```javascript
// BAD: Synchronous heavy operations
function processLargeArray(arr) {
  for (let i = 0; i < 1000000; i++) {
    // Heavy synchronous operation
  }
}
```

**Do this instead:**
- Use workers for CPU-intensive tasks
- Break large operations into chunks
- Use async operations
- Implement pagination

## Framework-Specific Anti-Patterns

### [Add framework-specific anti-patterns here]

## Red Flags in Code Reviews

Watch out for:
- `any` type everywhere (TypeScript)
- Empty catch blocks
- Commented-out code
- TODO comments older than 3 months
- Functions longer than 50 lines
- Files longer than 300 lines
- Deeply nested code (>3 levels)
- Duplicate code
- Mixed concerns in single module
- Missing error boundaries
- No tests for critical paths
