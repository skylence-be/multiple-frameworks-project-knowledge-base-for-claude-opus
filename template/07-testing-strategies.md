# Testing Strategies & Best Practices

## Testing Philosophy

> "Code without tests is broken by design" - Jacob Kaplan-Moss

### Testing Principles:
1. **Test Behavior, Not Implementation**: Focus on what, not how
2. **Fast Feedback**: Tests should run quickly
3. **Isolated**: Tests shouldn't depend on each other
4. **Deterministic**: Same input = same output
5. **Clear**: Test names should describe what they test

## Testing Pyramid

```
         /\        E2E Tests (10%)
        /  \       - Critical user journeys
       /    \      - Smoke tests
      /      \
     /--------\    Integration Tests (20%)
    /          \   - API tests
   /            \  - Component integration
  /              \
 /________________\ Unit Tests (70%)
                    - Business logic
                    - Utilities
                    - Individual components
```

## Unit Testing

### Best Practices:
```javascript
// Good test structure: AAA Pattern
describe('UserService', () => {
  describe('createUser', () => {
    it('should create a user with valid data', async () => {
      // Arrange
      const userData = {
        name: 'John Doe',
        email: 'john@example.com'
      };
      const mockDb = { insert: jest.fn().mockResolvedValue({ id: 1, ...userData }) };
      const service = new UserService(mockDb);

      // Act
      const result = await service.createUser(userData);

      // Assert
      expect(result).toEqual({ id: 1, ...userData });
      expect(mockDb.insert).toHaveBeenCalledWith('users', userData);
    });

    it('should throw error for invalid email', async () => {
      // Test one thing at a time
      const userData = { name: 'John', email: 'invalid' };
      const service = new UserService();

      await expect(service.createUser(userData))
        .rejects
        .toThrow('Invalid email format');
    });
  });
});
```

### What to Unit Test:
- Pure functions
- Business logic
- Utility functions
- Data transformations
- Validation logic
- Error handling

### Mocking Best Practices:
```javascript
// Mock external dependencies
jest.mock('../services/email-service');

// Mock timers
jest.useFakeTimers();

// Mock API calls
const mockFetch = jest.fn();
global.fetch = mockFetch;

// Spy on methods
const spy = jest.spyOn(object, 'method');

// Clean up after tests
afterEach(() => {
  jest.clearAllMocks();
  jest.restoreAllMocks();
});
```

## Integration Testing

### API Testing:
```javascript
// Using supertest for Express apps
const request = require('supertest');
const app = require('../app');

describe('POST /api/users', () => {
  it('should create a user', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({
        name: 'John Doe',
        email: 'john@example.com'
      })
      .expect(201)
      .expect('Content-Type', /json/);

    expect(response.body).toHaveProperty('id');
    expect(response.body.name).toBe('John Doe');
  });

  it('should return 400 for invalid data', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ name: 'John' }) // Missing email
      .expect(400);

    expect(response.body).toHaveProperty('error');
  });
});
```

### Database Testing:
```javascript
// Test with real database (test database)
beforeAll(async () => {
  await db.migrate.latest();
});

beforeEach(async () => {
  await db.seed.run();
});

afterEach(async () => {
  await db('users').truncate();
});

afterAll(async () => {
  await db.destroy();
});

describe('UserRepository', () => {
  it('should find user by email', async () => {
    // Uses real database connection
    const user = await UserRepository.findByEmail('test@example.com');
    expect(user).toBeDefined();
    expect(user.email).toBe('test@example.com');
  });
});
```

## End-to-End Testing

### Using Playwright/Cypress:
```javascript
// Playwright example
const { test, expect } = require('@playwright/test');

test('user can complete purchase flow', async ({ page }) => {
  // Navigate
  await page.goto('https://example.com');
  
  // Login
  await page.fill('[data-testid="email"]', 'user@example.com');
  await page.fill('[data-testid="password"]', 'password');
  await page.click('[data-testid="login-button"]');
  
  // Add to cart
  await page.click('[data-testid="product-1"]');
  await page.click('[data-testid="add-to-cart"]');
  
  // Checkout
  await page.click('[data-testid="checkout"]');
  await page.fill('[data-testid="card-number"]', '4242424242424242');
  await page.click('[data-testid="pay-button"]');
  
  // Verify success
  await expect(page.locator('[data-testid="success-message"]'))
    .toContainText('Order confirmed');
});
```

### E2E Best Practices:
- Use data-testid attributes for selectors
- Test critical paths only
- Run against staging environment
- Use page object pattern for maintainability
- Reset test data between runs

## Component Testing (Frontend)

### React Testing Library:
```javascript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import UserForm from './UserForm';

describe('UserForm', () => {
  it('should submit form with valid data', async () => {
    const onSubmit = jest.fn();
    render(<UserForm onSubmit={onSubmit} />);
    
    // Fill form
    fireEvent.change(screen.getByLabelText(/name/i), {
      target: { value: 'John Doe' }
    });
    fireEvent.change(screen.getByLabelText(/email/i), {
      target: { value: 'john@example.com' }
    });
    
    // Submit
    fireEvent.click(screen.getByRole('button', { name: /submit/i }));
    
    // Verify
    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        name: 'John Doe',
        email: 'john@example.com'
      });
    });
  });

  it('should show validation errors', async () => {
    render(<UserForm />);
    
    // Submit empty form
    fireEvent.click(screen.getByRole('button', { name: /submit/i }));
    
    // Check for errors
    expect(await screen.findByText(/name is required/i)).toBeInTheDocument();
    expect(await screen.findByText(/email is required/i)).toBeInTheDocument();
  });
});
```

## Test Coverage

### Coverage Goals:
```javascript
// jest.config.js
module.exports = {
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  collectCoverageFrom: [
    'src/**/*.{js,jsx}',
    '!src/index.js',
    '!src/**/*.test.js'
  ]
};
```

### What to Measure:
- Line coverage: % of lines executed
- Branch coverage: % of if/else branches tested
- Function coverage: % of functions called
- Statement coverage: % of statements executed

## Testing Utilities

### Test Data Factories:
```javascript
// factories/user.factory.js
const faker = require('faker');

function createUser(overrides = {}) {
  return {
    id: faker.datatype.uuid(),
    name: faker.name.findName(),
    email: faker.internet.email(),
    createdAt: faker.date.past(),
    ...overrides
  };
}

// Usage in tests
const user = createUser({ email: 'specific@email.com' });
```

### Custom Matchers:
```javascript
// custom-matchers.js
expect.extend({
  toBeValidEmail(received) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const pass = emailRegex.test(received);
    
    return {
      pass,
      message: () => pass
        ? `Expected ${received} not to be a valid email`
        : `Expected ${received} to be a valid email`
    };
  }
});

// Usage
expect('user@example.com').toBeValidEmail();
```

## Test Organization

### File Structure:
```
src/
├── components/
│   ├── UserCard.jsx
│   └── UserCard.test.jsx
├── services/
│   ├── UserService.js
│   └── UserService.test.js
├── utils/
│   ├── validators.js
│   └── validators.test.js
└── __tests__/
    ├── integration/
    │   └── api.test.js
    └── e2e/
        └── user-flow.test.js
```

## Testing Checklist

### For Every Feature:
- [ ] Unit tests for business logic
- [ ] Integration tests for API endpoints
- [ ] Component tests for UI components
- [ ] E2E test for critical path
- [ ] Error scenarios tested
- [ ] Edge cases covered
- [ ] Performance tests for heavy operations
- [ ] Security tests for sensitive operations

### Code Review Questions:
- Are the tests testing behavior, not implementation?
- Can the tests run in isolation?
- Are the test names descriptive?
- Is the test coverage adequate?
- Are edge cases tested?
- Are error scenarios handled?
- Are the tests maintainable?

## Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
      - run: npm ci
      - run: npm run lint
      - run: npm run test:unit
      - run: npm run test:integration
      - run: npm run test:e2e
      - run: npm run test:coverage
      - uses: codecov/codecov-action@v2
```

## Testing Anti-Patterns to Avoid

1. **Testing Implementation Details**: Don't test private methods
2. **Excessive Mocking**: Too many mocks = brittle tests
3. **Shared State**: Tests affecting each other
4. **Slow Tests**: Long-running tests slow down development
5. **Flaky Tests**: Non-deterministic tests
6. **No Assertions**: Tests that can't fail
7. **Testing Framework Code**: Don't test the framework itself
8. **Ignored Tests**: Commented out or skipped tests
