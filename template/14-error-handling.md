# Error Handling Strategies

## Error Handling Philosophy

> "Errors are not exceptional, they are expected. Plan for them." - Pragmatic Programmer

### Core Principles:
1. **Fail Fast**: Detect errors as early as possible
2. **Fail Gracefully**: Never crash the application
3. **Fail Informatively**: Provide meaningful error messages
4. **Fail Safely**: Don't expose sensitive information
5. **Fail Recoverably**: Allow the system to continue when possible

## Error Types & Classification

### Error Hierarchy
```javascript
// Base error class
class AppError extends Error {
  constructor(message, statusCode = 500, isOperational = true) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.timestamp = new Date().toISOString();
    
    Error.captureStackTrace(this, this.constructor);
  }
}

// Specific error types
class ValidationError extends AppError {
  constructor(message, fields = []) {
    super(message, 400);
    this.fields = fields;
  }
}

class AuthenticationError extends AppError {
  constructor(message = 'Authentication failed') {
    super(message, 401);
  }
}

class AuthorizationError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super(message, 403);
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404);
  }
}

class ConflictError extends AppError {
  constructor(message) {
    super(message, 409);
  }
}

class RateLimitError extends AppError {
  constructor(message = 'Too many requests') {
    super(message, 429);
    this.retryAfter = 60; // seconds
  }
}

class ExternalServiceError extends AppError {
  constructor(service, originalError) {
    super(`External service error: ${service}`, 503);
    this.service = service;
    this.originalError = originalError;
  }
}
```

## Validation Error Handling

### Input Validation
```javascript
class Validator {
  constructor() {
    this.errors = [];
  }
  
  required(value, field) {
    if (!value || value.toString().trim() === '') {
      this.errors.push({
        field,
        message: `${field} is required`,
        rule: 'required'
      });
    }
    return this;
  }
  
  email(value, field) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (value && !emailRegex.test(value)) {
      this.errors.push({
        field,
        message: `${field} must be a valid email`,
        rule: 'email'
      });
    }
    return this;
  }
  
  minLength(value, min, field) {
    if (value && value.length < min) {
      this.errors.push({
        field,
        message: `${field} must be at least ${min} characters`,
        rule: 'minLength',
        params: { min }
      });
    }
    return this;
  }
  
  validate() {
    if (this.errors.length > 0) {
      throw new ValidationError('Validation failed', this.errors);
    }
    return true;
  }
}

// Usage
function validateUserInput(data) {
  const validator = new Validator();
  
  validator
    .required(data.email, 'email')
    .email(data.email, 'email')
    .required(data.password, 'password')
    .minLength(data.password, 8, 'password')
    .validate();
}
```

### Schema Validation (using Joi/Yup)
```javascript
// Using Yup
import * as yup from 'yup';

const userSchema = yup.object({
  email: yup
    .string()
    .email('Invalid email format')
    .required('Email is required'),
  password: yup
    .string()
    .min(8, 'Password must be at least 8 characters')
    .matches(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain uppercase, lowercase, and number'
    )
    .required('Password is required'),
  age: yup
    .number()
    .positive('Age must be positive')
    .integer('Age must be an integer')
    .min(18, 'Must be at least 18 years old')
});

async function validateUser(data) {
  try {
    const validData = await userSchema.validate(data, { abortEarly: false });
    return validData;
  } catch (error) {
    throw new ValidationError('Validation failed', error.errors);
  }
}
```

## Async Error Handling

### Promise Error Handling
```javascript
// Async wrapper for Express routes
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Usage
router.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await UserService.findById(req.params.id);
  if (!user) {
    throw new NotFoundError('User');
  }
  res.json(user);
}));

// Promise chain error handling
function fetchUserData(userId) {
  return fetchUser(userId)
    .then(user => {
      if (!user) throw new NotFoundError('User');
      return fetchUserPosts(user.id);
    })
    .then(posts => {
      return { user, posts };
    })
    .catch(error => {
      // Log error
      logger.error('Failed to fetch user data', error);
      
      // Re-throw or handle
      if (error instanceof NotFoundError) {
        return { user: null, posts: [] };
      }
      throw error;
    });
}
```

### Async/Await Error Handling
```javascript
// Try-catch with async/await
async function processOrder(orderId) {
  let order;
  let payment;
  
  try {
    order = await fetchOrder(orderId);
    payment = await processPayment(order);
    await updateInventory(order.items);
    await sendConfirmationEmail(order.user);
    
    return { success: true, orderId, paymentId: payment.id };
  } catch (error) {
    // Rollback operations if needed
    if (payment && !payment.completed) {
      await rollbackPayment(payment.id);
    }
    
    // Log with context
    logger.error('Order processing failed', {
      orderId,
      error: error.message,
      stack: error.stack
    });
    
    // Transform error for client
    if (error instanceof PaymentError) {
      throw new AppError('Payment processing failed', 402);
    }
    
    throw error;
  }
}

// Multiple error handling
async function fetchMultipleResources() {
  const results = await Promise.allSettled([
    fetchUser(),
    fetchPosts(),
    fetchComments()
  ]);
  
  const errors = results
    .filter(r => r.status === 'rejected')
    .map(r => r.reason);
  
  if (errors.length > 0) {
    logger.warn('Some resources failed to load', errors);
  }
  
  return {
    user: results[0].status === 'fulfilled' ? results[0].value : null,
    posts: results[1].status === 'fulfilled' ? results[1].value : [],
    comments: results[2].status === 'fulfilled' ? results[2].value : []
  };
}
```

## Express Error Handling

### Global Error Handler
```javascript
// Error handling middleware
class ErrorHandler {
  static handle(err, req, res, next) {
    let error = { ...err };
    error.message = err.message;
    
    // Log error
    logger.error('Error:', {
      error: err,
      request: {
        method: req.method,
        url: req.url,
        params: req.params,
        query: req.query,
        body: req.body,
        user: req.user?.id
      }
    });
    
    // Mongoose bad ObjectId
    if (err.name === 'CastError') {
      const message = 'Resource not found';
      error = new NotFoundError(message);
    }
    
    // Mongoose duplicate key
    if (err.code === 11000) {
      const field = Object.keys(err.keyValue)[0];
      const message = `Duplicate value for ${field}`;
      error = new ConflictError(message);
    }
    
    // Mongoose validation error
    if (err.name === 'ValidationError') {
      const fields = Object.values(err.errors).map(e => ({
        field: e.path,
        message: e.message
      }));
      error = new ValidationError('Validation failed', fields);
    }
    
    // JWT errors
    if (err.name === 'JsonWebTokenError') {
      error = new AuthenticationError('Invalid token');
    }
    
    if (err.name === 'TokenExpiredError') {
      error = new AuthenticationError('Token expired');
    }
    
    res.status(error.statusCode || 500).json({
      success: false,
      error: {
        message: error.message || 'Server Error',
        ...(process.env.NODE_ENV === 'development' && {
          stack: error.stack,
          details: error
        })
      }
    });
  }
  
  static notFound(req, res, next) {
    const error = new NotFoundError(`Route ${req.originalUrl}`);
    next(error);
  }
}

// Register middleware
app.use(ErrorHandler.notFound);
app.use(ErrorHandler.handle);
```

## React Error Handling

### Error Boundaries
```javascript
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      errorCount: 0
    };
  }
  
  static getDerivedStateFromError(error) {
    return { hasError: true };
  }
  
  componentDidCatch(error, errorInfo) {
    // Log to error reporting service
    console.error('ErrorBoundary caught:', error, errorInfo);
    
    // Send to monitoring service
    if (window.Sentry) {
      window.Sentry.captureException(error, {
        contexts: {
          react: {
            componentStack: errorInfo.componentStack
          }
        }
      });
    }
    
    this.setState(prevState => ({
      error,
      errorInfo,
      errorCount: prevState.errorCount + 1
    }));
  }
  
  handleReset = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null
    });
  };
  
  render() {
    if (this.state.hasError) {
      // Fallback UI
      if (this.props.fallback) {
        return this.props.fallback(
          this.state.error,
          this.state.errorInfo,
          this.handleReset
        );
      }
      
      return (
        <div className="error-fallback">
          <h2>Oops! Something went wrong</h2>
          <details style={{ whiteSpace: 'pre-wrap' }}>
            {this.state.error && this.state.error.toString()}
            <br />
            {this.state.errorInfo && this.state.errorInfo.componentStack}
          </details>
          <button onClick={this.handleReset}>Try again</button>
        </div>
      );
    }
    
    return this.props.children;
  }
}

// Usage
<ErrorBoundary
  fallback={(error, errorInfo, reset) => (
    <CustomErrorPage
      error={error}
      onRetry={reset}
    />
  )}
>
  <App />
</ErrorBoundary>
```

### Hook Error Handling
```javascript
// Custom hook for error handling
function useErrorHandler() {
  const [error, setError] = useState(null);
  
  const resetError = () => setError(null);
  
  const handleError = useCallback((error) => {
    console.error('Error occurred:', error);
    setError(error);
    
    // Report to monitoring service
    if (window.Sentry) {
      window.Sentry.captureException(error);
    }
  }, []);
  
  // Throw error to nearest error boundary
  useEffect(() => {
    if (error) throw error;
  }, [error]);
  
  return { error, resetError, handleError };
}

// Async error handling hook
function useAsync(asyncFunction) {
  const [state, setState] = useState({
    loading: false,
    data: null,
    error: null
  });
  
  const execute = useCallback(async (...params) => {
    setState({ loading: true, data: null, error: null });
    
    try {
      const data = await asyncFunction(...params);
      setState({ loading: false, data, error: null });
      return data;
    } catch (error) {
      setState({ loading: false, data: null, error });
      throw error;
    }
  }, [asyncFunction]);
  
  return { ...state, execute };
}
```

## API Error Responses

### Consistent Error Format
```javascript
class APIError {
  static format(error) {
    return {
      success: false,
      error: {
        code: error.code || 'UNKNOWN_ERROR',
        message: error.message || 'An unexpected error occurred',
        statusCode: error.statusCode || 500,
        timestamp: new Date().toISOString(),
        ...(error.fields && { fields: error.fields }),
        ...(error.retryAfter && { retryAfter: error.retryAfter }),
        ...(process.env.NODE_ENV === 'development' && {
          stack: error.stack,
          details: error
        })
      }
    };
  }
  
  static success(data = null, message = 'Success') {
    return {
      success: true,
      message,
      data,
      timestamp: new Date().toISOString()
    };
  }
}

// Usage in route handler
router.post('/api/users', async (req, res, next) => {
  try {
    const user = await UserService.create(req.body);
    res.json(APIError.success(user, 'User created successfully'));
  } catch (error) {
    res.status(error.statusCode || 500).json(APIError.format(error));
  }
});
```

## Recovery Strategies

### Retry Logic
```javascript
class RetryableOperation {
  constructor(operation, options = {}) {
    this.operation = operation;
    this.maxAttempts = options.maxAttempts || 3;
    this.delay = options.delay || 1000;
    this.backoff = options.backoff || 2;
    this.onRetry = options.onRetry || (() => {});
  }
  
  async execute(...args) {
    let lastError;
    
    for (let attempt = 1; attempt <= this.maxAttempts; attempt++) {
      try {
        return await this.operation(...args);
      } catch (error) {
        lastError = error;
        
        // Don't retry on client errors
        if (error.statusCode >= 400 && error.statusCode < 500) {
          throw error;
        }
        
        if (attempt < this.maxAttempts) {
          const delay = this.delay * Math.pow(this.backoff, attempt - 1);
          
          this.onRetry(attempt, delay, error);
          
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }
    
    throw lastError;
  }
}

// Usage
const retryable = new RetryableOperation(
  fetchDataFromAPI,
  {
    maxAttempts: 3,
    delay: 1000,
    backoff: 2,
    onRetry: (attempt, delay) => {
      console.log(`Retry attempt ${attempt} after ${delay}ms`);
    }
  }
);

try {
  const data = await retryable.execute();
} catch (error) {
  console.error('All retry attempts failed', error);
}
```

## Error Monitoring

### Sentry Integration
```javascript
import * as Sentry from '@sentry/node';

// Initialize Sentry
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
  ],
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  beforeSend(event, hint) {
    // Filter sensitive data
    if (event.request) {
      delete event.request.cookies;
      delete event.request.headers?.authorization;
    }
    return event;
  }
});

// Capture errors with context
Sentry.withScope((scope) => {
  scope.setTag('section', 'payment');
  scope.setUser({ id: userId });
  scope.setContext('order', { orderId, amount });
  Sentry.captureException(error);
});
```

## Error Prevention Checklist

### Input Validation
- [ ] Validate all user inputs
- [ ] Sanitize data before processing
- [ ] Use schema validation
- [ ] Check data types
- [ ] Validate ranges and limits

### Error Handling
- [ ] Use try-catch for async operations
- [ ] Implement error boundaries (React)
- [ ] Add global error handlers
- [ ] Log errors with context
- [ ] Don't expose sensitive info

### Recovery
- [ ] Implement retry logic
- [ ] Add circuit breakers
- [ ] Provide fallback options
- [ ] Enable graceful degradation
- [ ] Clear error messages for users
