# Code Style Guide

## Formatting Fundamentals

### Indentation & Spacing

```javascript
// Use 2 spaces for JavaScript/TypeScript (or 4, be consistent)
function calculateTotal(items) {
  let total = 0;
  
  for (const item of items) {
    if (item.isActive) {
      total += item.price * item.quantity;
    }
  }
  
  return total;
}

// Spacing around operators
const sum = a + b;  // Good
const sum=a+b;      // Bad

// Spacing in objects
const user = { name: 'John', age: 30 };  // Good
const user={name:'John',age:30};         // Bad

// Spacing in arrays
const numbers = [1, 2, 3, 4, 5];  // Good
const numbers=[1,2,3,4,5];        // Bad
```

### Line Length & Breaking

```javascript
// Max line length: 80-120 characters (pick one, stay consistent)

// Breaking long method chains
const result = collection
  .filter(item => item.isActive)
  .map(item => item.value)
  .reduce((sum, value) => sum + value, 0);

// Breaking long parameter lists
function createUser(
  firstName,
  lastName,
  email,
  phoneNumber,
  address,
  preferences
) {
  // Implementation
}

// Breaking long conditionals
if (
  user.isActive &&
  user.hasPermission &&
  user.emailVerified &&
  !user.isSuspended
) {
  // Allow action
}

// Breaking long strings
const message = 'This is a very long string that exceeds the maximum ' +
  'line length and needs to be broken into multiple lines for ' +
  'better readability and maintenance.';
```

## Code Structure

### Function Organization

```javascript
// 1. Constants first
const MAX_RETRIES = 3;
const TIMEOUT = 5000;

// 2. Main function
export async function processData(input) {
  validateInput(input);
  
  const transformed = transformData(input);
  const result = await saveData(transformed);
  
  return result;
}

// 3. Helper functions
function validateInput(input) {
  if (!input) {
    throw new Error('Input is required');
  }
}

function transformData(data) {
  return {
    ...data,
    processedAt: new Date()
  };
}

// 4. Private utilities last
async function saveData(data) {
  return await database.save(data);
}
```

### Class Organization

```javascript
class UserService {
  // 1. Static properties
  static VERSION = '1.0.0';
  
  // 2. Static methods
  static getInstance() {
    return new UserService();
  }
  
  // 3. Constructor
  constructor(database, logger) {
    this.database = database;
    this.logger = logger;
  }
  
  // 4. Public methods
  async createUser(userData) {
    this.validateUserData(userData);
    return await this.saveUser(userData);
  }
  
  async getUser(id) {
    return await this.database.findById(id);
  }
  
  // 5. Private methods
  validateUserData(data) {
    // Validation logic
  }
  
  async saveUser(data) {
    // Save logic
  }
}
```

## Comments & Documentation

### JSDoc Standards

```javascript
/**
 * Calculates the total price including tax and discounts.
 * 
 * @param {number} basePrice - The base price of the item
 * @param {number} taxRate - Tax rate as a decimal (e.g., 0.08 for 8%)
 * @param {number} [discount=0] - Optional discount amount
 * @returns {number} The final calculated price
 * @throws {Error} Throws an error if basePrice is negative
 * 
 * @example
 * const price = calculatePrice(100, 0.08, 10);
 * console.log(price); // 97.2
 */
function calculatePrice(basePrice, taxRate, discount = 0) {
  if (basePrice < 0) {
    throw new Error('Base price cannot be negative');
  }
  
  const discountedPrice = basePrice - discount;
  const finalPrice = discountedPrice * (1 + taxRate);
  
  return finalPrice;
}
```

### Inline Comments

```javascript
// Good: Explains WHY, not WHAT
function processPayment(amount) {
  // Stripe requires amounts in cents, not dollars
  const amountInCents = amount * 100;
  
  // Retry logic due to intermittent network issues
  for (let i = 0; i < MAX_RETRIES; i++) {
    try {
      return stripe.charge(amountInCents);
    } catch (error) {
      // Log but don't throw on retryable errors
      if (i === MAX_RETRIES - 1) throw error;
      logger.warn(`Payment retry ${i + 1}/${MAX_RETRIES}`);
    }
  }
}

// Bad: States the obvious
function add(a, b) {
  // Add a and b
  return a + b;  // Return the sum
}
```

## Imports & Dependencies

### Import Organization

```javascript
// 1. Node built-ins
import fs from 'fs';
import path from 'path';

// 2. External packages
import express from 'express';
import lodash from 'lodash';
import React, { useState, useEffect } from 'react';

// 3. Internal absolute imports
import { UserService } from '@/services/UserService';
import { API_ENDPOINTS } from '@/constants';

// 4. Internal relative imports
import { formatDate } from '../utils/date';
import UserCard from './UserCard';

// 5. Style imports
import styles from './Component.module.css';
import './global.css';

// 6. Type imports (TypeScript)
import type { User, UserRole } from '@/types';
```

## Conditional Logic

### Guard Clauses

```javascript
// Good: Early returns reduce nesting
function processUser(user) {
  if (!user) {
    return null;
  }
  
  if (!user.isActive) {
    return { error: 'User is not active' };
  }
  
  if (!user.emailVerified) {
    return { error: 'Email not verified' };
  }
  
  // Main logic with minimal nesting
  return {
    id: user.id,
    name: user.name,
    permissions: getUserPermissions(user)
  };
}

// Bad: Nested conditions
function processUser(user) {
  if (user) {
    if (user.isActive) {
      if (user.emailVerified) {
        // Main logic deeply nested
        return {
          id: user.id,
          name: user.name,
          permissions: getUserPermissions(user)
        };
      } else {
        return { error: 'Email not verified' };
      }
    } else {
      return { error: 'User is not active' };
    }
  } else {
    return null;
  }
}
```

### Switch Statements

```javascript
// Good: Clear, with default case
function getStatusColor(status) {
  switch (status) {
    case 'success':
      return 'green';
    case 'warning':
      return 'yellow';
    case 'error':
      return 'red';
    case 'info':
      return 'blue';
    default:
      return 'gray';
  }
}

// Better: Object lookup for simple mappings
const STATUS_COLORS = {
  success: 'green',
  warning: 'yellow',
  error: 'red',
  info: 'blue'
};

function getStatusColor(status) {
  return STATUS_COLORS[status] || 'gray';
}
```

## Error Handling Style

```javascript
// Consistent error handling pattern
class CustomError extends Error {
  constructor(message, code, statusCode) {
    super(message);
    this.name = 'CustomError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

async function fetchUserData(userId) {
  try {
    const response = await api.get(`/users/${userId}`);
    
    if (!response.ok) {
      throw new CustomError(
        'Failed to fetch user',
        'USER_FETCH_ERROR',
        response.status
      );
    }
    
    return response.data;
  } catch (error) {
    // Log with context
    logger.error('User fetch failed', {
      userId,
      error: error.message,
      stack: error.stack
    });
    
    // Re-throw or handle appropriately
    throw error;
  }
}
```

## Async Code Style

```javascript
// Prefer async/await over promises
// Good: Clean, readable async/await
async function processOrder(orderId) {
  try {
    const order = await fetchOrder(orderId);
    const items = await fetchOrderItems(order.id);
    const user = await fetchUser(order.userId);
    
    const result = await processPayment({
      order,
      items,
      user
    });
    
    return result;
  } catch (error) {
    logger.error('Order processing failed', { orderId, error });
    throw error;
  }
}

// Avoid: Promise chains (unless necessary)
function processOrder(orderId) {
  return fetchOrder(orderId)
    .then(order => {
      return Promise.all([
        order,
        fetchOrderItems(order.id),
        fetchUser(order.userId)
      ]);
    })
    .then(([order, items, user]) => {
      return processPayment({ order, items, user });
    })
    .catch(error => {
      logger.error('Order processing failed', { orderId, error });
      throw error;
    });
}
```

## React/Component Style

```jsx
// Functional component with hooks
function UserProfile({ userId, onUpdate }) {
  // 1. Hooks first
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // 2. Effects
  useEffect(() => {
    fetchUser(userId)
      .then(setUser)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [userId]);
  
  // 3. Event handlers
  const handleUpdate = useCallback(async (data) => {
    try {
      const updated = await updateUser(userId, data);
      setUser(updated);
      onUpdate?.(updated);
    } catch (err) {
      setError(err);
    }
  }, [userId, onUpdate]);
  
  // 4. Early returns for edge cases
  if (loading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!user) return <EmptyState />;
  
  // 5. Main render
  return (
    <div className={styles.profile}>
      <h1>{user.name}</h1>
      <UserDetails user={user} />
      <EditButton onClick={handleUpdate} />
    </div>
  );
}

// PropTypes or TypeScript interfaces
UserProfile.propTypes = {
  userId: PropTypes.string.isRequired,
  onUpdate: PropTypes.func
};
```

## CSS/SCSS Style

```scss
// Component styles with BEM
.user-card {
  // Layout
  display: flex;
  flex-direction: column;
  gap: 1rem;
  
  // Box model
  padding: 1.5rem;
  margin-bottom: 1rem;
  
  // Visual
  background-color: var(--color-white);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  
  // Typography
  font-family: var(--font-primary);
  
  // Transitions
  transition: box-shadow 0.3s ease;
  
  // States
  &:hover {
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
  }
  
  // Elements
  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  
  &__title {
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--color-text-primary);
  }
  
  // Modifiers
  &--featured {
    border-color: var(--color-primary);
    background-color: var(--color-primary-light);
  }
  
  // Responsive
  @media (max-width: 768px) {
    padding: 1rem;
  }
}
```

## File Structure Style

```javascript
// 1. Imports
import dependencies

// 2. Constants
const CONSTANTS = {};

// 3. Types/Interfaces (TypeScript)
interface UserData {}

// 4. Main export (component/function/class)
export function MainComponent() {}

// 5. Sub-components (if in same file)
function SubComponent() {}

// 6. Helper functions
function helperFunction() {}

// 7. Styled components (if using CSS-in-JS)
const StyledDiv = styled.div``;

// 8. PropTypes/Default props
MainComponent.propTypes = {};
MainComponent.defaultProps = {};

// 9. Default export (if needed)
export default MainComponent;
```

## Consistency Rules

1. **Pick a style and stick to it**
   - Semicolons: always or never
   - Quotes: single or double
   - Trailing commas: yes or no
   
2. **Use tools to enforce**
   - Prettier for formatting
   - ESLint for code quality
   - Husky for pre-commit hooks
   
3. **Document exceptions**
   - When breaking style guide
   - Why the exception exists
   - When it can be removed
