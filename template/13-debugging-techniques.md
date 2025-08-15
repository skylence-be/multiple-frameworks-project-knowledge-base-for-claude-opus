# Debugging Techniques

## Debugging Mindset

> "The debugger is not a tool to find bugs, it's a tool to understand code." - Unknown

### Systematic Approach:
1. **Reproduce**: Can you consistently reproduce the issue?
2. **Isolate**: What is the smallest code that demonstrates the problem?
3. **Understand**: What should happen vs. what actually happens?
4. **Hypothesize**: Form theories about the cause
5. **Test**: Verify or disprove each hypothesis
6. **Fix**: Apply the minimal fix needed
7. **Verify**: Ensure the fix works and doesn't break anything else

## Browser DevTools Debugging

### Console Methods
```javascript
// Basic logging
console.log('Simple log');
console.info('Information');
console.warn('Warning message');
console.error('Error message');

// Formatted output
console.log('%c Styled text', 'color: blue; font-size: 20px;');
console.log('User: %s, Age: %d', 'John', 25);

// Object inspection
const user = { name: 'John', age: 30, address: { city: 'NYC' } };
console.dir(user);  // Interactive object explorer
console.table(user); // Tabular display

// Grouping
console.group('User Details');
console.log('Name:', user.name);
console.log('Age:', user.age);
console.groupEnd();

// Timing
console.time('DataFetch');
await fetchData();
console.timeEnd('DataFetch'); // DataFetch: 245.123ms

// Counting
function processItem(item) {
  console.count('Item processed');
  // Processing logic
}

// Stack trace
console.trace('Trace point');

// Assertions
console.assert(user.age > 0, 'Age must be positive');

// Clear console
console.clear();
```

### Breakpoints
```javascript
// Programmatic breakpoint
function calculateTotal(items) {
  let total = 0;
  
  for (const item of items) {
    debugger; // Execution stops here when DevTools is open
    total += item.price * item.quantity;
  }
  
  return total;
}

// Conditional breakpoints (set in DevTools)
// Right-click on line number → Add conditional breakpoint
// Condition: item.price > 100

// Logpoints (non-breaking console.log)
// Right-click on line number → Add logpoint
// Message: 'Item price:', item.price
```

### Performance Profiling
```javascript
// Performance marks
performance.mark('myTask-start');

// Do work
expensiveOperation();

performance.mark('myTask-end');
performance.measure('myTask', 'myTask-start', 'myTask-end');

// Get measurements
const measures = performance.getEntriesByType('measure');
console.log(measures);

// Memory profiling
console.memory; // Check memory usage

// CPU profiling
console.profile('MyProfile');
expensiveOperation();
console.profileEnd('MyProfile');
```

## Node.js Debugging

### Debug Module
```javascript
// Using debug module
const debug = require('debug');
const dbDebug = debug('app:database');
const httpDebug = debug('app:http');

dbDebug('Connecting to database...');
httpDebug('Server started on port %d', 3000);

// Enable with: DEBUG=app:* node index.js
// Or specific: DEBUG=app:database node index.js
```

### Inspector Mode
```bash
# Start with inspector
node --inspect index.js
node --inspect-brk index.js  # Break on first line

# With nodemon
nodemon --inspect index.js

# Connect Chrome DevTools
# Navigate to: chrome://inspect
```

### Process Debugging
```javascript
// Uncaught exception handler
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Log to file/service
  // Gracefully shutdown
  process.exit(1);
});

// Unhandled promise rejection
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// Memory usage
console.log(process.memoryUsage());
// {
//   rss: 4935680,
//   heapTotal: 1826816,
//   heapUsed: 650472,
//   external: 49879,
//   arrayBuffers: 9386
// }

// CPU usage
console.log(process.cpuUsage());
```

## React Debugging

### React DevTools
```javascript
// Component profiling
import { Profiler } from 'react';

function onRenderCallback(id, phase, actualDuration) {
  console.log(`${id} (${phase}) took ${actualDuration}ms`);
}

<Profiler id="UserList" onRender={onRenderCallback}>
  <UserList users={users} />
</Profiler>

// Why did this render?
import { useWhyDidYouUpdate } from 'use-why-did-you-update';

function UserProfile(props) {
  // Logs what props changed
  useWhyDidYouUpdate('UserProfile', props);
  
  return <div>{props.name}</div>;
}

// Debug context changes
const MyContext = React.createContext();
MyContext.displayName = 'MyContext'; // Shows in DevTools
```

### Error Boundaries
```javascript
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  
  componentDidCatch(error, errorInfo) {
    console.error('Error caught:', error);
    console.error('Error info:', errorInfo);
    
    // Log to error reporting service
    logErrorToService(error, errorInfo);
  }
  
  render() {
    if (this.state.hasError) {
      return (
        <div>
          <h1>Something went wrong.</h1>
          {process.env.NODE_ENV === 'development' && (
            <details>
              <summary>Error details</summary>
              <pre>{this.state.error?.toString()}</pre>
            </details>
          )}
        </div>
      );
    }
    
    return this.props.children;
  }
}
```

## Network Debugging

### Request Interceptors
```javascript
// Axios interceptors
axios.interceptors.request.use(
  (config) => {
    console.log('Request:', config.method.toUpperCase(), config.url);
    console.log('Headers:', config.headers);
    console.log('Data:', config.data);
    return config;
  },
  (error) => {
    console.error('Request error:', error);
    return Promise.reject(error);
  }
);

axios.interceptors.response.use(
  (response) => {
    console.log('Response:', response.status, response.statusText);
    console.log('Data:', response.data);
    return response;
  },
  (error) => {
    console.error('Response error:', error.response?.status);
    console.error('Error data:', error.response?.data);
    return Promise.reject(error);
  }
);

// Fetch wrapper for debugging
const debugFetch = async (url, options = {}) => {
  console.log('Fetching:', url);
  console.log('Options:', options);
  
  const startTime = performance.now();
  
  try {
    const response = await fetch(url, options);
    const duration = performance.now() - startTime;
    
    console.log(`Response: ${response.status} in ${duration}ms`);
    
    if (!response.ok) {
      console.error('Response not OK:', await response.text());
    }
    
    return response;
  } catch (error) {
    console.error('Fetch error:', error);
    throw error;
  }
};
```

## Memory Leak Detection

### Common Patterns
```javascript
// Memory leak detection helper
class MemoryLeakDetector {
  constructor() {
    this.snapshots = [];
  }
  
  takeSnapshot(label) {
    if (performance.memory) {
      this.snapshots.push({
        label,
        timestamp: Date.now(),
        memory: { ...performance.memory }
      });
    }
  }
  
  compareSnapshots(label1, label2) {
    const snap1 = this.snapshots.find(s => s.label === label1);
    const snap2 = this.snapshots.find(s => s.label === label2);
    
    if (!snap1 || !snap2) {
      console.error('Snapshots not found');
      return;
    }
    
    const diff = {
      usedJSHeapSize: snap2.memory.usedJSHeapSize - snap1.memory.usedJSHeapSize,
      totalJSHeapSize: snap2.memory.totalJSHeapSize - snap1.memory.totalJSHeapSize
    };
    
    console.table({
      'Heap Size Change': `${(diff.usedJSHeapSize / 1024 / 1024).toFixed(2)} MB`,
      'Total Heap Change': `${(diff.totalJSHeapSize / 1024 / 1024).toFixed(2)} MB`
    });
  }
}

// Common leak sources to check
// 1. Event listeners not removed
element.addEventListener('click', handler);
// Fix: element.removeEventListener('click', handler);

// 2. Timers not cleared
const timer = setInterval(() => {}, 1000);
// Fix: clearInterval(timer);

// 3. Closures holding references
function createLeak() {
  const largeData = new Array(1000000).fill('data');
  return function() {
    console.log(largeData.length); // Holds reference
  };
}

// 4. DOM references
let detachedNode = document.getElementById('node');
document.body.removeChild(detachedNode);
// Fix: detachedNode = null;
```

## Logging Best Practices

### Structured Logging
```javascript
class Logger {
  constructor(context) {
    this.context = context;
  }
  
  log(level, message, data = {}) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      context: this.context,
      message,
      ...data
    };
    
    if (process.env.NODE_ENV === 'production') {
      // Send to logging service
      this.sendToService(logEntry);
    } else {
      // Console output for development
      console[level.toLowerCase()](message, data);
    }
  }
  
  info(message, data) {
    this.log('INFO', message, data);
  }
  
  warn(message, data) {
    this.log('WARN', message, data);
  }
  
  error(message, error, data) {
    this.log('ERROR', message, {
      ...data,
      error: {
        message: error.message,
        stack: error.stack,
        name: error.name
      }
    });
  }
  
  debug(message, data) {
    if (process.env.DEBUG) {
      this.log('DEBUG', message, data);
    }
  }
}

// Usage
const logger = new Logger('UserService');
logger.info('User created', { userId: 123 });
logger.error('Failed to create user', error, { userData });
```

## Testing for Debugging

### Debug-Friendly Tests
```javascript
// Descriptive test names
describe('UserService', () => {
  describe('when creating a user with valid data', () => {
    it('should return user object with generated ID', async () => {
      // Test implementation
    });
    
    it('should send welcome email', async () => {
      // Test implementation
    });
  });
  
  describe('when creating a user with duplicate email', () => {
    it('should throw DuplicateEmailError', async () => {
      // Test implementation
    });
  });
});

// Debug helper in tests
function debugTest(description, fn) {
  return it(description, async () => {
    console.log(`\n=== Starting: ${description} ===`);
    try {
      await fn();
      console.log(`=== Passed: ${description} ===\n`);
    } catch (error) {
      console.error(`=== Failed: ${description} ===`);
      console.error(error);
      throw error;
    }
  });
}
```

## Production Debugging

### Source Maps
```javascript
// webpack.config.js
module.exports = {
  devtool: process.env.NODE_ENV === 'production' 
    ? 'source-map'  // Separate file
    : 'eval-source-map', // Inline for dev
};

// Upload source maps to error tracking service
// Don't expose source maps publicly
```

### Feature Flags for Debugging
```javascript
class FeatureFlags {
  static isEnabled(flag) {
    const flags = {
      DEBUG_MODE: process.env.DEBUG === 'true',
      VERBOSE_LOGGING: process.env.VERBOSE === 'true',
      PERFORMANCE_TRACKING: process.env.PERF === 'true'
    };
    
    return flags[flag] || false;
  }
}

// Usage
if (FeatureFlags.isEnabled('DEBUG_MODE')) {
  console.log('Detailed debug info:', data);
}

if (FeatureFlags.isEnabled('PERFORMANCE_TRACKING')) {
  performance.mark('operation-start');
}
```

## Debugging Checklist

### Before Starting:
- [ ] Can you reproduce the issue consistently?
- [ ] Do you have error messages or stack traces?
- [ ] What changed recently in the code?
- [ ] Is this environment-specific?

### During Debugging:
- [ ] Start with the error message
- [ ] Check the network tab for failed requests
- [ ] Look at console for errors/warnings
- [ ] Use breakpoints to step through code
- [ ] Check component props/state (React DevTools)
- [ ] Verify data flow
- [ ] Test with different inputs
- [ ] Check for race conditions

### Common Issues to Check:
- [ ] Undefined/null references
- [ ] Async/await issues
- [ ] Scope problems
- [ ] Type mismatches
- [ ] Off-by-one errors
- [ ] Case sensitivity
- [ ] Cache issues
- [ ] CORS problems
- [ ] Environment variables
