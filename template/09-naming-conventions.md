# Naming Conventions Guide

## General Principles

> "There are only two hard things in Computer Science: cache invalidation and naming things." - Phil Karlton

### Core Rules:
1. **Be Descriptive**: Names should reveal intent
2. **Be Consistent**: Same concept = same name pattern
3. **Be Searchable**: Avoid single letters (except loop counters)
4. **Be Pronounceable**: If you can't say it, reconsider
5. **Avoid Abbreviations**: Unless universally understood

## Variables

### JavaScript/TypeScript

```javascript
// ✅ GOOD: Descriptive, clear intent
const userAge = 25;
const isLoggedIn = true;
const hasAdminPrivileges = false;
const maxRetryAttempts = 3;
const apiEndpoint = 'https://api.example.com';

// ❌ BAD: Unclear, abbreviated
const a = 25;
const flag = true;
const admin = false;
const max = 3;
const ep = 'https://api.example.com';

// Boolean variables: Start with is/has/can/should
const isActive = true;
const hasPermission = false;
const canEdit = true;
const shouldUpdate = false;

// Arrays: Plural names
const users = [];
const activeProducts = [];
const pendingOrders = [];

// Constants: UPPER_SNAKE_CASE
const MAX_FILE_SIZE = 5242880; // 5MB
const API_TIMEOUT = 30000;
const DEFAULT_CURRENCY = 'USD';
```

### PHP

```php
// Variables: $camelCase
$userName = 'John';
$isActive = true;
$userList = [];

// Constants: UPPER_SNAKE_CASE
const MAX_UPLOAD_SIZE = 5242880;
define('API_VERSION', 'v2');

// Properties: camelCase
class User {
    private $firstName;
    protected $emailAddress;
    public $profilePicture;
}
```

## Functions & Methods

### Naming Patterns

```javascript
// Action functions: verb + noun
function createUser(data) {}
function deletePost(id) {}
function updateProfile(userId, data) {}
function sendEmail(recipient, subject, body) {}

// Boolean returning functions: is/has/can/should
function isValidEmail(email) {}
function hasPermission(user, action) {}
function canAccessResource(user, resource) {}
function shouldRetry(attempt, maxAttempts) {}

// Event handlers: handle + Event
function handleClick(event) {}
function handleSubmit(event) {}
function handleUserLogin(user) {}

// Lifecycle methods: on/before/after + Action
function onMount() {}
function beforeSave() {}
function afterUpdate() {}

// Getters/Setters
function getUserName() {}
function setUserName(name) {}

// Async functions: Often include verb indicating async nature
async function fetchUserData(id) {}
async function loadProducts() {}
async function syncDatabase() {}
```

## Classes & Interfaces

### TypeScript/JavaScript

```typescript
// Classes: PascalCase, singular nouns
class User {}
class ProductService {}
class DatabaseConnection {}
class AuthenticationMiddleware {}

// Interfaces: PascalCase, often prefixed with 'I' or suffixed with type
interface IUser {}
interface UserInterface {}
interface ApiResponse {}
interface DatabaseConfig {}

// Types: PascalCase
type UserId = string;
type ProductStatus = 'active' | 'inactive';
type ApiEndpoint = string;

// Enums: PascalCase for name, UPPER_SNAKE_CASE for values
enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
  GUEST = 'guest'
}

enum HttpStatus {
  OK = 200,
  NOT_FOUND = 404,
  SERVER_ERROR = 500
}
```

### PHP

```php
// Classes: PascalCase
class UserController {}
class ProductRepository {}
class EmailService {}

// Interfaces: Suffix with Interface
interface UserRepositoryInterface {}
interface CacheInterface {}

// Traits: Suffix with Trait
trait TimestampableTrait {}
trait SoftDeleteTrait {}

// Abstract classes: Prefix with Abstract
abstract class AbstractController {}
abstract class AbstractRepository {}
```

## Files & Directories

### Project Structure

```
// Components (React/Vue): PascalCase
UserProfile.tsx
ProductList.vue
ShoppingCart.jsx

// Utilities/Helpers: camelCase
formatDate.ts
validateEmail.js
parseJson.ts

// Config files: kebab-case or lowercase
webpack.config.js
database-config.js
app.config.ts

// Test files: match source + .test/.spec
UserService.ts → UserService.test.ts
utils.js → utils.spec.js

// Style files: match component or kebab-case
UserProfile.module.scss
Button.styles.ts
global-styles.css

// Directories: kebab-case (preferred) or camelCase
user-management/
shopping-cart/
auth-services/
```

## Database

### Tables & Columns

```sql
-- Tables: plural, snake_case
CREATE TABLE users (...);
CREATE TABLE product_categories (...);
CREATE TABLE order_items (...);

-- Columns: snake_case
CREATE TABLE users (
  id INT PRIMARY KEY,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  email_address VARCHAR(100),
  created_at TIMESTAMP,
  is_active BOOLEAN
);

-- Indexes: idx_tablename_columns
CREATE INDEX idx_users_email ON users(email_address);
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);

-- Foreign keys: fk_tablename_reference
ALTER TABLE orders 
ADD CONSTRAINT fk_orders_user 
FOREIGN KEY (user_id) REFERENCES users(id);
```

## API Endpoints

### RESTful Naming

```
# Resources: plural nouns, kebab-case
GET    /api/users           # Get all users
GET    /api/users/:id       # Get specific user
POST   /api/users           # Create user
PUT    /api/users/:id       # Update user
DELETE /api/users/:id       # Delete user

# Nested resources
GET    /api/users/:id/orders
GET    /api/products/:id/reviews

# Actions: verb as last segment
POST   /api/users/:id/activate
POST   /api/orders/:id/cancel
PUT    /api/products/:id/publish

# Query parameters: camelCase or snake_case (be consistent)
GET    /api/products?sortBy=price&filterBy=category
GET    /api/users?page_size=20&page_number=1
```

### GraphQL

```graphql
# Types: PascalCase
type User {
  id: ID!
  firstName: String!
  lastName: String!
  emailAddress: String!
}

# Queries: camelCase
type Query {
  getUser(id: ID!): User
  listUsers(limit: Int, offset: Int): [User!]!
  searchProducts(query: String!): [Product!]!
}

# Mutations: verb + Noun
type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!
}

# Input types: suffix with Input
input CreateUserInput {
  firstName: String!
  lastName: String!
  email: String!
}
```

## Git Branches & Commits

### Branch Naming

```bash
# Feature branches
feature/user-authentication
feature/add-shopping-cart
feature/JIRA-123-payment-integration

# Bug fixes
bugfix/fix-login-error
bugfix/JIRA-456-cart-calculation

# Hotfixes
hotfix/security-patch
hotfix/critical-payment-bug

# Release branches
release/1.2.0
release/2023-Q4

# Other
chore/update-dependencies
docs/api-documentation
refactor/user-service
```

### Commit Messages

```bash
# Format: <type>(<scope>): <subject>

feat(auth): add OAuth2 integration
fix(cart): resolve calculation error for discounts
docs(api): update user endpoint documentation
style(ui): format button components
refactor(user): simplify validation logic
perf(db): add index for user queries
test(auth): add unit tests for login
chore(deps): update npm packages
```

## CSS/SCSS

### Class Names (BEM Convention)

```scss
// Block__Element--Modifier
.user-card { }                      // Block
.user-card__header { }               // Element
.user-card__header--highlighted { }  // Modifier

.btn { }                            // Block
.btn--primary { }                   // Modifier
.btn--large { }                     // Modifier
.btn__icon { }                      // Element

// Utility classes: descriptive
.text-center { }
.margin-top-large { }
.display-flex { }
.hidden-mobile { }
```

### CSS Variables

```css
:root {
  /* Colors */
  --color-primary: #007bff;
  --color-secondary: #6c757d;
  --color-danger: #dc3545;
  
  /* Spacing */
  --spacing-small: 8px;
  --spacing-medium: 16px;
  --spacing-large: 24px;
  
  /* Typography */
  --font-size-base: 16px;
  --font-weight-normal: 400;
  --font-weight-bold: 700;
  
  /* Breakpoints */
  --breakpoint-mobile: 480px;
  --breakpoint-tablet: 768px;
  --breakpoint-desktop: 1024px;
}
```

## Environment Variables

```bash
# UPPER_SNAKE_CASE
DATABASE_URL=postgresql://localhost:5432/mydb
API_KEY=abc123xyz
JWT_SECRET=super-secret-key
NODE_ENV=production
MAX_UPLOAD_SIZE=5242880
REDIS_HOST=localhost
SMTP_PORT=587
ENABLE_DEBUG_MODE=false
```

## Common Naming Patterns

### Temporal Names
```javascript
const startDate, endDate;        // Not: date1, date2
const createdAt, updatedAt;      // Timestamps
const minValue, maxValue;        // Ranges
const oldValue, newValue;        // Comparisons
const beforeUpdate, afterUpdate; // State changes
```

### Collection Operations
```javascript
const filteredUsers = users.filter(...);
const sortedProducts = products.sort(...);
const mappedResults = results.map(...);
const groupedOrders = orders.reduce(...);
```

### Configuration Objects
```javascript
const userConfig = {};
const databaseOptions = {};
const serverSettings = {};
const apiParameters = {};
```

## Anti-Patterns to Avoid

```javascript
// ❌ AVOID these patterns:

// Single letters (except loop counters)
const d = new Date();  // Bad
const currentDate = new Date();  // Good

// Meaningless names
const data = {};  // Bad
const userData = {};  // Good

// Hungarian notation
const strName = 'John';  // Bad
const name = 'John';  // Good

// Abbreviations
const usrMgr = {};  // Bad
const userManager = {};  // Good

// Numbers in names (unless meaningful)
const value1, value2;  // Bad
const oldValue, newValue;  // Good

// Misleading names
const namesList = 'John';  // Bad (it's not a list)
const userName = 'John';  // Good
```
