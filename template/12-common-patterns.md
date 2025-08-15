# Common Design Patterns & Solutions (Continued)

### Module Pattern (Continued)
```javascript
// Encapsulates private and public members
const CartModule = (function() {
  // Private variables
  let items = [];
  let total = 0;
  
  // Private functions
  function calculateTotal() {
    total = items.reduce((sum, item) => sum + item.price, 0);
  }
  
  // Public API
  return {
    addItem(item) {
      items.push(item);
      calculateTotal();
      return this;
    },
    
    removeItem(itemId) {
      items = items.filter(item => item.id !== itemId);
      calculateTotal();
      return this;
    },
    
    getTotal() {
      return total;
    },
    
    getItemCount() {
      return items.length;
    },
    
    clear() {
      items = [];
      total = 0;
      return this;
    }
  };
})();

// Usage
CartModule.addItem({ id: 1, price: 10 });
CartModule.addItem({ id: 2, price: 20 });
console.log(CartModule.getTotal()); // 30
```

## React Patterns

### Custom Hook Pattern
```javascript
// Reusable stateful logic
function useLocalStorage(key, initialValue) {
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(`Error loading ${key} from localStorage:`, error);
      return initialValue;
    }
  });
  
  const setValue = useCallback((value) => {
    try {
      const valueToStore = value instanceof Function 
        ? value(storedValue) 
        : value;
      
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {
      console.error(`Error saving ${key} to localStorage:`, error);
    }
  }, [key, storedValue]);
  
  return [storedValue, setValue];
}

// Usage
function Settings() {
  const [theme, setTheme] = useLocalStorage('theme', 'light');
  const [language, setLanguage] = useLocalStorage('language', 'en');
  
  return (
    <div>
      <ThemeSelector value={theme} onChange={setTheme} />
      <LanguageSelector value={language} onChange={setLanguage} />
    </div>
  );
}
```

### Compound Component Pattern
```javascript
// Components that work together
const Tabs = ({ children, defaultTab }) => {
  const [activeTab, setActiveTab] = useState(defaultTab || 0);
  
  return (
    <TabContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="tabs">{children}</div>
    </TabContext.Provider>
  );
};

Tabs.List = ({ children }) => (
  <div className="tabs-list">{children}</div>
);

Tabs.Tab = ({ index, children }) => {
  const { activeTab, setActiveTab } = useContext(TabContext);
  
  return (
    <button
      className={`tab ${activeTab === index ? 'active' : ''}`}
      onClick={() => setActiveTab(index)}
    >
      {children}
    </button>
  );
};

Tabs.Panels = ({ children }) => {
  const { activeTab } = useContext(TabContext);
  return children[activeTab] || null;
};

// Usage
<Tabs defaultTab={0}>
  <Tabs.List>
    <Tabs.Tab index={0}>Profile</Tabs.Tab>
    <Tabs.Tab index={1}>Settings</Tabs.Tab>
    <Tabs.Tab index={2}>Security</Tabs.Tab>
  </Tabs.List>
  
  <Tabs.Panels>
    <ProfilePanel />
    <SettingsPanel />
    <SecurityPanel />
  </Tabs.Panels>
</Tabs>
```

### Render Props Pattern
```javascript
// Share code between components using a prop
class DataFetcher extends Component {
  state = {
    data: null,
    loading: true,
    error: null
  };
  
  async componentDidMount() {
    try {
      const response = await fetch(this.props.url);
      const data = await response.json();
      this.setState({ data, loading: false });
    } catch (error) {
      this.setState({ error, loading: false });
    }
  }
  
  render() {
    return this.props.render(this.state);
  }
}

// Usage
<DataFetcher 
  url="/api/users"
  render={({ data, loading, error }) => {
    if (loading) return <Spinner />;
    if (error) return <ErrorMessage error={error} />;
    return <UserList users={data} />;
  }}
/>
```

### Higher-Order Component (HOC) Pattern
```javascript
// Component that takes a component and returns an enhanced component
function withAuth(Component) {
  return function AuthenticatedComponent(props) {
    const { user, loading } = useAuth();
    
    if (loading) {
      return <LoadingSpinner />;
    }
    
    if (!user) {
      return <Navigate to="/login" />;
    }
    
    return <Component {...props} user={user} />;
  };
}

// Usage
const ProtectedDashboard = withAuth(Dashboard);

// In your routes
<Route path="/dashboard" element={<ProtectedDashboard />} />
```

## State Management Patterns

### Redux Pattern
```javascript
// Actions
const ADD_TODO = 'ADD_TODO';
const TOGGLE_TODO = 'TOGGLE_TODO';

// Action creators
const addTodo = (text) => ({
  type: ADD_TODO,
  payload: { text, id: Date.now() }
});

const toggleTodo = (id) => ({
  type: TOGGLE_TODO,
  payload: { id }
});

// Reducer
const todosReducer = (state = [], action) => {
  switch (action.type) {
    case ADD_TODO:
      return [...state, {
        id: action.payload.id,
        text: action.payload.text,
        completed: false
      }];
      
    case TOGGLE_TODO:
      return state.map(todo =>
        todo.id === action.payload.id
          ? { ...todo, completed: !todo.completed }
          : todo
      );
      
    default:
      return state;
  }
};

// Store
const store = createStore(todosReducer);

// Usage
store.dispatch(addTodo('Learn patterns'));
console.log(store.getState());
```

### Context Pattern
```javascript
// Global state without prop drilling
const ThemeContext = createContext();
const AuthContext = createContext();

// Provider component
function AppProviders({ children }) {
  const [theme, setTheme] = useState('light');
  const [user, setUser] = useState(null);
  
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      <AuthContext.Provider value={{ user, setUser }}>
        {children}
      </AuthContext.Provider>
    </ThemeContext.Provider>
  );
}

// Custom hooks for consuming context
function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return context;
}

function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
```

## API Patterns

### Retry Pattern
```javascript
async function fetchWithRetry(url, options = {}, maxRetries = 3) {
  let lastError;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await fetch(url, options);
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      return response;
    } catch (error) {
      lastError = error;
      
      // Don't retry on client errors
      if (error.message.includes('4')) {
        throw error;
      }
      
      // Exponential backoff
      if (i < maxRetries - 1) {
        const delay = Math.pow(2, i) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw lastError;
}
```

### Circuit Breaker Pattern
```javascript
class CircuitBreaker {
  constructor(fn, options = {}) {
    this.fn = fn;
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 60000;
    this.state = 'CLOSED';
    this.failureCount = 0;
    this.nextAttempt = Date.now();
  }
  
  async call(...args) {
    if (this.state === 'OPEN') {
      if (Date.now() < this.nextAttempt) {
        throw new Error('Circuit breaker is OPEN');
      }
      this.state = 'HALF_OPEN';
    }
    
    try {
      const result = await this.fn(...args);
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }
  
  onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }
  
  onFailure() {
    this.failureCount++;
    
    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
      this.nextAttempt = Date.now() + this.resetTimeout;
    }
  }
}

// Usage
const apiCall = async (url) => {
  const response = await fetch(url);
  if (!response.ok) throw new Error('API failed');
  return response.json();
};

const breaker = new CircuitBreaker(apiCall);

try {
  const data = await breaker.call('/api/data');
} catch (error) {
  console.error('Service unavailable:', error);
}
```

### Debounce Pattern
```javascript
function debounce(func, delay) {
  let timeoutId;
  
  return function debounced(...args) {
    clearTimeout(timeoutId);
    
    timeoutId = setTimeout(() => {
      func.apply(this, args);
    }, delay);
  };
}

// Usage
const searchInput = document.getElementById('search');
const handleSearch = debounce((value) => {
  console.log('Searching for:', value);
  // Make API call
}, 300);

searchInput.addEventListener('input', (e) => {
  handleSearch(e.target.value);
});
```

### Throttle Pattern
```javascript
function throttle(func, limit) {
  let inThrottle;
  let lastResult;
  
  return function throttled(...args) {
    if (!inThrottle) {
      inThrottle = true;
      lastResult = func.apply(this, args);
      
      setTimeout(() => {
        inThrottle = false;
      }, limit);
    }
    
    return lastResult;
  };
}

// Usage
const handleScroll = throttle(() => {
  console.log('Scroll position:', window.scrollY);
}, 100);

window.addEventListener('scroll', handleScroll);
```

## Caching Patterns

### Memoization Pattern
```javascript
function memoize(fn) {
  const cache = new Map();
  
  return function memoized(...args) {
    const key = JSON.stringify(args);
    
    if (cache.has(key)) {
      return cache.get(key);
    }
    
    const result = fn.apply(this, args);
    cache.set(key, result);
    
    return result;
  };
}

// Usage
const expensiveCalculation = memoize((n) => {
  console.log('Computing...');
  return n * n;
});

console.log(expensiveCalculation(5)); // Computing... 25
console.log(expensiveCalculation(5)); // 25 (from cache)
```

### LRU Cache Pattern
```javascript
class LRUCache {
  constructor(capacity) {
    this.capacity = capacity;
    this.cache = new Map();
  }
  
  get(key) {
    if (!this.cache.has(key)) {
      return undefined;
    }
    
    // Move to end (most recently used)
    const value = this.cache.get(key);
    this.cache.delete(key);
    this.cache.set(key, value);
    
    return value;
  }
  
  set(key, value) {
    // Remove key if exists
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }
    
    // Check capacity
    if (this.cache.size >= this.capacity) {
      // Remove least recently used (first item)
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }
    
    // Add to end
    this.cache.set(key, value);
  }
}

// Usage
const cache = new LRUCache(3);
cache.set('a', 1);
cache.set('b', 2);
cache.set('c', 3);
cache.set('d', 4); // 'a' is evicted
console.log(cache.get('a')); // undefined
```
