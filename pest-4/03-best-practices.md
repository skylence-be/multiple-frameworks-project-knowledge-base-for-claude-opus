# Pest Best Practices

## Project Structure

### Recommended Directory Structure
```
tests/
├── Architecture/       # Architecture tests
├── Browser/           # Browser/E2E tests
├── Datasets/          # Shared datasets
├── Feature/           # Feature/Integration tests
├── Fixtures/          # Test fixtures and files
├── Helpers/           # Test helper functions
├── Unit/              # Unit tests
├── .pest/             # Pest cache and temp files
├── Pest.php           # Global configuration
└── TestCase.php       # Base test case class
```

### File Naming Conventions
```php
// Unit tests
tests/Unit/Services/OrderServiceTest.php
tests/Unit/Models/UserTest.php

// Feature tests
tests/Feature/Api/AuthenticationTest.php
tests/Feature/Console/SendEmailsCommandTest.php

// Browser tests
tests/Browser/CheckoutProcessTest.php

// Architecture tests
tests/Architecture/DomainBoundariesTest.php
```

## Test Organization

### Using Describe Blocks
```php
describe('OrderService', function () {
    describe('calculateTotal', function () {
        it('includes tax in calculation', function () {
            // Test implementation
        });
        
        it('applies discount when coupon is valid', function () {
            // Test implementation
        });
    });
    
    describe('processPayment', function () {
        it('charges the correct amount', function () {
            // Test implementation
        });
    });
});
```

### Grouping Related Tests
```php
// Group by feature
test('user registration')->group('auth', 'critical');
test('password reset')->group('auth');

// Group by speed
test('heavy calculation')->group('slow');
test('external API call')->group('integration', 'slow');

// Run specific groups
// ./vendor/bin/pest --group=critical
// ./vendor/bin/pest --exclude-group=slow
```

## Configuration Management

### Pest.php Configuration
```php
<?php

use App\Models\User;
use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
*/

uses(TestCase::class)
    ->beforeEach(function () {
        // Global setup for all tests
    })
    ->in('Feature');

uses(RefreshDatabase::class)
    ->in('Feature/Api');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

expect()->extend('toBeValidEmail', function () {
    return $this->toMatch('/^[^\s@]+@[^\s@]+\.[^\s@]+$/');
});

/*
|--------------------------------------------------------------------------
| Global Functions
|--------------------------------------------------------------------------
*/

function createUser(array $attributes = []): User
{
    return User::factory()->create($attributes);
}

function actingAsAdmin(): TestCase
{
    $admin = User::factory()->admin()->create();
    return test()->actingAs($admin);
}
```

### Environment Configuration
```php
// phpunit.xml
<php>
    <env name="APP_ENV" value="testing"/>
    <env name="BCRYPT_ROUNDS" value="4"/>
    <env name="CACHE_DRIVER" value="array"/>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>
    <env name="MAIL_MAILER" value="array"/>
    <env name="QUEUE_CONNECTION" value="sync"/>
    <env name="SESSION_DRIVER" value="array"/>
    <env name="TELESCOPE_ENABLED" value="false"/>
</php>
```

## Writing Effective Tests

### Clear Test Names
```php
// ✅ Good: Descriptive and specific
test('authenticated user can access their profile');
it('throws ValidationException when email is invalid');
it('sends notification after successful purchase');

// ❌ Bad: Vague or unclear
test('test user');
test('it works');
test('exception');
```

### Single Responsibility
```php
// ✅ Good: One test, one assertion concept
test('order total includes tax', function () {
    $order = Order::factory()->create(['subtotal' => 100]);
    
    expect($order->total())->toBe(108.00);
});

// ❌ Bad: Testing multiple unrelated things
test('order processing', function () {
    $order = Order::factory()->create();
    
    expect($order->total())->toBe(108.00);
    expect($order->user->email)->toContain('@');
    expect($order->status)->toBe('pending');
    // Too many unrelated assertions
});
```

### Using Datasets Effectively
```php
// Define reusable datasets
dataset('browsers', [
    'chrome' => ['Chrome', 'webkit'],
    'firefox' => ['Firefox', 'gecko'],
    'safari' => ['Safari', 'webkit'],
]);

dataset('invalid_inputs', function () {
    yield 'null' => [null];
    yield 'empty string' => [''];
    yield 'special chars' => ['@#$%'];
    yield 'too long' => [str_repeat('a', 256)];
});

// Use datasets in tests
test('browser detection works correctly', function ($name, $engine) {
    $browser = new BrowserDetector($name);
    
    expect($browser->engine())->toBe($engine);
})->with('browsers');
```

## Performance Optimization

### Parallel Testing
```php
// Run tests in parallel (8 processes)
// ./vendor/bin/pest --parallel --processes=8

// Mark tests that can't run in parallel
test('uses shared resource')
    ->group('serial')
    ->skip('parallel');
```

### Database Optimization
```php
// Use database transactions for speed
uses(DatabaseTransactions::class)->in('Feature');

// Use in-memory SQLite for tests
// DB_CONNECTION=sqlite
// DB_DATABASE=:memory:

// Minimize database interactions
beforeEach(function () {
    // Seed only necessary data
    $this->user = User::factory()->create();
});
```

### Test Speed Strategies
```php
// Skip slow tests during development
test('integration with payment gateway')
    ->skipLocally()
    ->group('integration');

// Use test doubles for external services
test('sends email notification', function () {
    Mail::fake();
    
    $order = Order::factory()->create();
    $order->sendConfirmation();
    
    Mail::assertSent(OrderConfirmation::class);
});
```

## Security Considerations

### Testing Authentication
```php
test('unauthenticated users cannot access admin panel', function () {
    $response = $this->get('/admin');
    
    expect($response->status())->toBe(401);
});

test('users cannot access other users data', function () {
    $user1 = User::factory()->create();
    $user2 = User::factory()->create();
    
    actingAs($user1)
        ->get("/api/users/{$user2->id}/private")
        ->assertForbidden();
});
```

### Testing Input Validation
```php
test('rejects SQL injection attempts', function ($input) {
    $response = $this->post('/api/search', [
        'query' => $input
    ]);
    
    expect($response->status())->toBe(400);
    expect($response->json('error'))->toContain('Invalid input');
})->with([
    'sql injection' => ["'; DROP TABLE users; --"],
    'union select' => ['UNION SELECT * FROM passwords'],
    'xss attempt' => ['<script>alert("XSS")</script>'],
]);
```

## Architecture Testing

### Enforcing Boundaries
```php
arch('controllers stay lean')
    ->expect('App\Http\Controllers')
    ->not->toUse(['App\Models', 'Illuminate\Support\Facades\DB'])
    ->because('controllers should delegate to services');

arch('models are final')
    ->expect('App\Models')
    ->toBeFinal()
    ->because('we prefer composition over inheritance');

arch('no debug statements')
    ->expect(['dd', 'dump', 'var_dump', 'ray'])
    ->not->toBeUsed()
    ->because('debug statements should not be committed');
```

### Dependency Rules
```php
arch('domain has no framework dependencies')
    ->expect('Domain')
    ->not->toUse('Illuminate')
    ->because('domain should be framework agnostic');

arch('infrastructure depends on domain interfaces')
    ->expect('Infrastructure')
    ->toOnlyBeUsedIn('App')
    ->because('infrastructure is an implementation detail');
```

## Coverage Strategies

### Setting Coverage Goals
```php
// Run with coverage
// ./vendor/bin/pest --coverage --min=80

// Coverage by namespace
// ./vendor/bin/pest --coverage --coverage-html=coverage

// Focus coverage on critical paths
covers(PaymentService::class);
covers(OrderCalculator::class);
```

### Mutation Testing
```php
// Install mutation testing
// composer require pestphp/pest-plugin-mutate --dev

// Run mutation tests
// ./vendor/bin/pest --mutate

// Specify mutation targets
mutates(CriticalService::class);
```

## Continuous Integration

### GitHub Actions Configuration
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.2'
        extensions: dom, curl, libxml, mbstring, zip
        coverage: xdebug
    
    - name: Install Dependencies
      run: composer install --no-progress
    
    - name: Run Tests
      run: ./vendor/bin/pest --parallel --coverage --min=80
    
    - name: Run Architecture Tests
      run: ./vendor/bin/pest tests/Architecture --stop-on-failure
```

### Test Sharding for CI
```bash
# Split tests across multiple CI runners
./vendor/bin/pest --shard=1/4 --parallel
./vendor/bin/pest --shard=2/4 --parallel
./vendor/bin/pest --shard=3/4 --parallel
./vendor/bin/pest --shard=4/4 --parallel
```

## Common Patterns

### Factory Pattern for Test Data
```php
// Create a test data factory
class TestDataFactory
{
    public static function validOrder(): array
    {
        return [
            'items' => [
                ['sku' => 'PROD-1', 'quantity' => 2],
                ['sku' => 'PROD-2', 'quantity' => 1],
            ],
            'shipping_address' => self::validAddress(),
            'payment_method' => 'card',
        ];
    }
    
    public static function validAddress(): array
    {
        return [
            'line1' => '123 Main St',
            'city' => 'Springfield',
            'state' => 'IL',
            'zip' => '62701',
        ];
    }
}
```

### Page Object Pattern for Browser Tests
```php
class LoginPage
{
    public function visit()
    {
        return visit('/login');
    }
    
    public function login(string $email, string $password)
    {
        return $this->visit()
            ->type('email', $email)
            ->type('password', $password)
            ->press('Login');
    }
}

test('user can login', function () {
    $page = new LoginPage();
    
    $page->login('user@example.com', 'password')
        ->assertSee('Dashboard');
});
```