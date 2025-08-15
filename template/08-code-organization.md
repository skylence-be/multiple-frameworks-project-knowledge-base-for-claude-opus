# Code Organization & Architecture Patterns

## Project Structure Philosophy

> "The architecture should scream the intent of the system" - Robert C. Martin

### Core Principles:
1. **Separation of Concerns**: Each module has a single, well-defined purpose
2. **High Cohesion**: Related code stays together
3. **Low Coupling**: Minimize dependencies between modules
4. **Scalability**: Structure should support growth
5. **Discoverability**: Easy to find what you're looking for

## Domain-Driven Design (DDD) Structure

```
src/
├── domain/                 # Core business logic
│   ├── user/
│   │   ├── User.entity.ts
│   │   ├── UserRepository.interface.ts
│   │   ├── UserService.ts
│   │   └── UserValidation.ts
│   ├── product/
│   │   ├── Product.entity.ts
│   │   ├── ProductRepository.interface.ts
│   │   └── ProductService.ts
│   └── shared/
│       ├── ValueObjects.ts
│       └── DomainEvents.ts
│
├── application/           # Application services
│   ├── user/
│   │   ├── CreateUser.usecase.ts
│   │   ├── UpdateUser.usecase.ts
│   │   └── GetUser.query.ts
│   └── product/
│       └── ...
│
├── infrastructure/        # External concerns
│   ├── database/
│   │   ├── repositories/
│   │   ├── migrations/
│   │   └── seeds/
│   ├── http/
│   │   ├── controllers/
│   │   ├── middleware/
│   │   └── validators/
│   ├── messaging/
│   └── external-services/
│
└── presentation/         # UI layer
    ├── web/
    ├── api/
    └── cli/
```

## Clean Architecture Layers

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│   (Controllers, Views, Presenters)      │
├─────────────────────────────────────────┤
│          Application Layer              │
│   (Use Cases, Application Services)     │
├─────────────────────────────────────────┤
│            Domain Layer                 │
│   (Entities, Value Objects, Domain      │
│    Services, Repository Interfaces)     │
├─────────────────────────────────────────┤
│        Infrastructure Layer             │
│   (Database, External APIs, File        │
│    System, Message Queues)              │
└─────────────────────────────────────────┘

Dependencies flow inward (top to bottom)
```

## Frontend Architecture Patterns

### Component-Based Structure (React/Vue/Angular)

```
src/
├── components/           # Reusable UI components
│   ├── common/
│   │   ├── Button/
│   │   │   ├── Button.tsx
│   │   │   ├── Button.test.tsx
│   │   │   ├── Button.stories.tsx
│   │   │   └── Button.module.css
│   │   └── Input/
│   ├── layout/
│   │   ├── Header/
│   │   ├── Footer/
│   │   └── Sidebar/
│   └── features/
│       ├── UserProfile/
│       └── ProductList/
│
├── pages/               # Route components
│   ├── Home/
│   ├── Dashboard/
│   └── Settings/
│
├── hooks/               # Custom React hooks
│   ├── useAuth.ts
│   ├── useApi.ts
│   └── useLocalStorage.ts
│
├── services/            # API and external services
│   ├── api/
│   │   ├── client.ts
│   │   ├── users.api.ts
│   │   └── products.api.ts
│   └── storage/
│
├── store/               # State management
│   ├── slices/         # Redux Toolkit
│   │   ├── userSlice.ts
│   │   └── cartSlice.ts
│   └── store.ts
│
├── utils/               # Helper functions
│   ├── formatters.ts
│   ├── validators.ts
│   └── constants.ts
│
├── types/               # TypeScript types
│   ├── user.types.ts
│   └── product.types.ts
│
└── styles/              # Global styles
    ├── variables.css
    ├── mixins.scss
    └── global.css
```

### Feature-Based Structure (Scalable)

```
src/
├── features/
│   ├── authentication/
│   │   ├── components/
│   │   │   ├── LoginForm.tsx
│   │   │   └── RegisterForm.tsx
│   │   ├── hooks/
│   │   │   └── useAuth.ts
│   │   ├── services/
│   │   │   └── auth.service.ts
│   │   ├── store/
│   │   │   └── auth.slice.ts
│   │   ├── types/
│   │   │   └── auth.types.ts
│   │   └── index.ts
│   │
│   ├── products/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── store/
│   │   └── types/
│   │
│   └── shared/
│       ├── components/
│       ├── hooks/
│       └── utils/
│
├── core/               # Core application setup
│   ├── router/
│   ├── store/
│   └── config/
│
└── assets/
```

## Backend Architecture Patterns

### Laravel Structure

```
app/
├── Console/            # CLI commands
├── Exceptions/         # Exception handlers
├── Http/
│   ├── Controllers/
│   ├── Middleware/
│   ├── Requests/      # Form requests
│   └── Resources/     # API resources
├── Models/            # Eloquent models
├── Providers/         # Service providers
├── Repositories/      # Repository pattern
├── Services/          # Business logic
├── Events/           
├── Listeners/
├── Jobs/             # Background jobs
├── Mail/             # Email classes
├── Notifications/
├── Policies/         # Authorization
└── Rules/            # Validation rules

resources/
├── views/
├── lang/
└── js/

database/
├── factories/
├── migrations/
└── seeders/
```

### Node.js/Express Structure

```
src/
├── api/              # API layer
│   ├── controllers/
│   ├── routes/
│   ├── middleware/
│   └── validators/
│
├── services/         # Business logic
│   ├── UserService.js
│   └── EmailService.js
│
├── models/          # Data models
│   ├── User.model.js
│   └── Product.model.js
│
├── repositories/    # Data access layer
│   ├── UserRepository.js
│   └── BaseRepository.js
│
├── utils/           # Utilities
│   ├── logger.js
│   ├── database.js
│   └── cache.js
│
├── config/          # Configuration
│   ├── database.config.js
│   ├── app.config.js
│   └── auth.config.js
│
├── jobs/            # Background jobs
│   └── EmailJob.js
│
└── app.js           # Application entry
```

## Microservices Architecture

```
services/
├── api-gateway/
│   ├── src/
│   ├── Dockerfile
│   └── package.json
│
├── user-service/
│   ├── src/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── repositories/
│   │   └── models/
│   ├── tests/
│   ├── Dockerfile
│   └── package.json
│
├── product-service/
│   └── ...
│
├── notification-service/
│   └── ...
│
├── shared/          # Shared libraries
│   ├── contracts/   # API contracts
│   ├── utils/
│   └── types/
│
└── docker-compose.yml
```

## Design Patterns Implementation

### Repository Pattern

```typescript
// Base Repository
abstract class BaseRepository<T> {
  abstract findById(id: string): Promise<T>;
  abstract findAll(): Promise<T[]>;
  abstract create(entity: T): Promise<T>;
  abstract update(id: string, entity: T): Promise<T>;
  abstract delete(id: string): Promise<void>;
}

// Implementation
class UserRepository extends BaseRepository<User> {
  async findById(id: string): Promise<User> {
    // Database query implementation
  }
}
```

### Service Layer Pattern

```typescript
class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private logger: Logger
  ) {}

  async createUser(userData: CreateUserDto): Promise<User> {
    // Business logic
    const user = await this.userRepository.create(userData);
    await this.emailService.sendWelcomeEmail(user);
    this.logger.info('User created', { userId: user.id });
    return user;
  }
}
```

### Factory Pattern

```typescript
interface PaymentProcessor {
  process(amount: number): Promise<void>;
}

class PaymentProcessorFactory {
  static create(type: string): PaymentProcessor {
    switch (type) {
      case 'stripe':
        return new StripeProcessor();
      case 'paypal':
        return new PayPalProcessor();
      default:
        throw new Error('Unknown payment type');
    }
  }
}
```

## Module Organization Best Practices

### 1. Public API Pattern
```typescript
// user/index.ts - Module's public API
export { UserService } from './UserService';
export { UserRepository } from './UserRepository';
export type { User, CreateUserDto } from './types';
// Don't export internal helpers
```

### 2. Barrel Exports
```typescript
// components/index.ts
export { Button } from './Button';
export { Input } from './Input';
export { Card } from './Card';
```

### 3. Dependency Injection
```typescript
// Use DI container or manual injection
const userRepository = new UserRepository(database);
const emailService = new EmailService(mailgun);
const userService = new UserService(userRepository, emailService);
```

## File Naming Conventions

### TypeScript/JavaScript
- Components: `PascalCase.tsx` (UserProfile.tsx)
- Utilities: `camelCase.ts` (formatDate.ts)
- Constants: `UPPER_SNAKE_CASE.ts` (API_ENDPOINTS.ts)
- Types: `PascalCase.types.ts` (User.types.ts)
- Tests: `*.test.ts` or `*.spec.ts`
- Stories: `*.stories.tsx`

### CSS/SCSS
- Components: `PascalCase.module.scss`
- Utilities: `_mixins.scss`, `_variables.scss`
- Pages: `kebab-case.scss`

## Monorepo Structure

```
monorepo/
├── apps/
│   ├── web/         # Main web application
│   ├── admin/       # Admin dashboard
│   └── mobile/      # React Native app
│
├── packages/
│   ├── ui/          # Shared UI components
│   ├── utils/       # Shared utilities
│   ├── types/       # Shared TypeScript types
│   └── config/      # Shared configurations
│
├── services/        # Backend services
│   ├── api/
│   └── worker/
│
├── package.json     # Root package.json
├── lerna.json       # Lerna configuration
└── tsconfig.json    # Root TypeScript config
```

## Architecture Decision Guidelines

### When to Split Components:
- Single responsibility violated
- Component > 200 lines
- Multiple reasons to change
- Reusability needed

### When to Create a Service:
- Business logic complexity
- Multiple consumers
- External dependency abstraction
- Cross-cutting concerns

### When to Use Patterns:
- Repository: Database abstraction needed
- Factory: Multiple implementations
- Observer: Event-driven updates
- Strategy: Interchangeable algorithms
