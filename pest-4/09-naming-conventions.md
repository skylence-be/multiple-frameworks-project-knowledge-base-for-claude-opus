# Naming Conventions in Pest

## Test File Naming Standards

### Unit Test Files
```php
// Pattern: [ClassName]Test.php
// Location: tests/Unit/[namespace]/

// Examples:
app/Services/OrderService.php → tests/Unit/Services/OrderServiceTest.php
app/Models/User.php → tests/Unit/Models/UserTest.php
app/Helpers/StringHelper.php → tests/Unit/Helpers/StringHelperTest.php
```

### Feature Test Files
```php
// Pattern: [Feature]Test.php
// Location: tests/Feature/[context]/

// Examples:
tests/Feature/Auth/LoginTest.php
tests/Feature/Auth/RegistrationTest.php
tests/Feature/Api/CreateOrderTest.php
tests/Feature/Admin/ManageUsersTest.php
```

### Browser Test Files
```php
// Pattern: [UserJourney]Test.php
// Location: tests/Browser/

// Examples:
tests/Browser/CheckoutProcessTest.php
tests/Browser/UserOnboardingTest.php
tests/Browser/AdminDashboardTest.php
```

### Architecture Test Files
```php
// Pattern: [Boundary]Test.php or [Rule]Test.php
// Location: tests/Architecture/

// Examples:
tests/Architecture/DomainBoundariesTest.php
tests/Architecture/NamingConventionsTest.php
tests/Architecture/DependencyRulesTest.php
```

## Test Function Naming

### Descriptive Test Names
```php
// Use clear, descriptive names that explain what is being tested
test('authenticated user can view their profile');
test('guest user is redirected to login when accessing protected route');
test('order total is calculated correctly with tax and discount');
test('email is sent when password reset is requested');
```

### Using 'it' for Behavior
```php
// Use 'it' for behavior-driven test descriptions
it('sends a welcome email after registration');
it('throws ValidationException when email is invalid');
it('retries failed payment up to 3 times');
it('caches the result for subsequent calls');
```

### Negative Test Cases
```php
// Clearly indicate negative/error cases
test('cannot create user with duplicate email');
test('throws exception when dividing by zero');
test('returns 404 when product does not exist');
test('validation fails with invalid credit card number');
```

### Edge Cases
```php
// Be specific about edge cases
test('handles empty array gracefully');
test('works with unicode characters in names');
test('processes maximum allowed file size');
test('correctly handles leap year calculations');
```

## Variable Naming in Tests

### Test Data Variables
```php
test('user registration', function () {
    // Use descriptive variable names
    $validEmail = 'test@example.com';
    $invalidEmail = 'not-an-email';
    $strongPassword = 'SecurePass123!';
    $weakPassword = '123';
    
    // Prefix with $ for test subjects
    $newUser = User::factory()->make();
    $existingUser = User::factory()->create();
    
    // Use clear names for mocks
    $mockedMailer = Mockery::mock(Mailer::class);
    $fakePaymentGateway = new FakePaymentGateway();
});
```

### Assertion Variables
```php
test('calculate order total', function () {
    // Name variables based on their purpose
    $basePrice = 100.00;
    $taxRate = 0.08;
    $discountAmount = 10.00;
    
    $expectedTotal = ($basePrice - $discountAmount) * (1 + $taxRate);
    $actualTotal = OrderCalculator::calculate($basePrice, $taxRate, $discountAmount);
    
    expect($actualTotal)->toBe($expectedTotal);
});
```

## Dataset Naming

### Descriptive Dataset Names
```php
// Use clear, descriptive dataset names
dataset('valid_credit_cards', [
    'visa' => ['4111111111111111'],
    'mastercard' => ['5555555555554444'],
    'amex' => ['378282246310005'],
]);

dataset('invalid_emails', [
    'no_at_symbol' => ['testexample.com'],
    'no_domain' => ['test@'],
    'spaces' => ['test @example.com'],
    'multiple_at' => ['test@@example.com'],
]);

dataset('user_roles_and_permissions', [
    'admin_full_access' => ['admin', ['read', 'write', 'delete']],
    'editor_limited' => ['editor', ['read', 'write']],
    'viewer_readonly' => ['viewer', ['read']],
]);
```

### Dynamic Dataset Names
```php
dataset('months', function () {
    foreach (range(1, 12) as $month) {
        $name = DateTime::createFromFormat('!m', $month)->format('F');
        yield strtolower($name) => [$month, $name];
    }
});

dataset('http_status_codes', function () {
    yield 'ok' => [200, 'OK'];
    yield 'created' => [201, 'Created'];
    yield 'bad_request' => [400, 'Bad Request'];
    yield 'unauthorized' => [401, 'Unauthorized'];
    yield 'not_found' => [404, 'Not Found'];
});
```

## Group Naming

### Feature Groups
```php
test('user can checkout')->group('checkout', 'e-commerce');
test('payment is processed')->group('payments', 'critical');
test('inventory is updated')->group('inventory', 'e-commerce');
```

### Environment Groups
```php
test('external API integration')->group('integration', 'external');
test('database transaction')->group('database');
test('redis cache')->group('cache', 'redis');
```

### Priority Groups
```php
test('user login')->group('smoke', 'critical');
test('data export')->group('feature', 'low-priority');
test('admin reports')->group('admin', 'reports');
```

## Class and Trait Naming

### Test Base Classes
```php
// Base test classes use descriptive names
abstract class IntegrationTestCase extends TestCase
{
    // Shared integration test setup
}

abstract class ApiTestCase extends TestCase
{
    // API-specific test helpers
}

abstract class BrowserTestCase extends TestCase
{
    // Browser testing setup
}
```

### Test Traits
```php
// Traits describe their functionality
trait InteractsWithStripe
{
    protected function createStripeCustomer() { }
    protected function mockStripeCharge() { }
}

trait SeedsDatabase
{
    protected function seedUsers(int $count = 10) { }
    protected function seedProducts(int $count = 50) { }
}

trait AssertsJsonStructure
{
    protected function assertJsonStructureMatches(array $structure) { }
}
```

## Helper Function Naming

### Action Helpers
```php
// Use verb prefixes for actions
function createAuthenticatedUser(): User
{
    return User::factory()->create();
}

function mockPaymentGateway(): PaymentGateway
{
    return Mockery::mock(PaymentGateway::class);
}

function generateTestData(int $count): Collection
{
    return collect(range(1, $count));
}
```

### Assertion Helpers
```php
// Prefix with 'assert' for custom assertions
function assertEmailWasSent(string $email): void
{
    Mail::assertSent(function ($mail) use ($email) {
        return $mail->hasTo($email);
    });
}

function assertDatabaseHasUser(array $attributes): void
{
    test()->assertDatabaseHas('users', $attributes);
}

function assertResponseIsJson($response): void
{
    expect($response->headers->get('Content-Type'))
        ->toContain('application/json');
}
```

## Configuration File Naming

### Pest Configuration Files
```php
// Main configuration
tests/Pest.php

// Module-specific configuration
tests/Modules/Billing/PestBilling.php
tests/Modules/Inventory/PestInventory.php

// Environment-specific
tests/Pest.local.php
tests/Pest.ci.php
```

## Mock and Stub Naming

### Mock Objects
```php
test('service interaction', function () {
    // Prefix mocks with 'mock' or 'mocked'
    $mockRepository = Mockery::mock(UserRepository::class);
    $mockedCache = Mockery::mock(CacheInterface::class);
    
    // Or suffix with 'Mock'
    $userRepositoryMock = Mockery::mock(UserRepository::class);
    $cacheServiceMock = Mockery::mock(CacheService::class);
});
```

### Stub Objects
```php
test('with stubs', function () {
    // Prefix stubs with 'stub' or 'stubbed'
    $stubGateway = new StubPaymentGateway();
    $stubbedResponse = ['status' => 'success'];
    
    // Or suffix with 'Stub'
    $paymentGatewayStub = new PaymentGatewayStub();
    $apiResponseStub = new ApiResponseStub();
});
```

### Fake Objects
```php
test('with fakes', function () {
    // Prefix fakes with 'fake'
    $fakeMailer = new FakeMailer();
    $fakeFileSystem = Storage::fake('local');
    
    // Laravel facades
    Mail::fake();
    Queue::fake();
    Event::fake();
});
```

## Database Naming in Tests

### Factory States
```php
// Use descriptive state names
User::factory()->active()->create();
User::factory()->suspended()->create();
User::factory()->withPosts(5)->create();

Product::factory()->published()->create();
Product::factory()->outOfStock()->create();
Product::factory()->onSale()->create();
```

### Seeder Names in Tests
```php
// Descriptive seeder method names
$this->seedActiveUsers(10);
$this->seedProductsWithCategories();
$this->seedOrdersForLastMonth();
```

## Directory Structure Naming

```
tests/
├── Architecture/           # Architecture and structure tests
├── Browser/               # End-to-end browser tests
├── Console/               # Artisan command tests
├── Datasets/              # Shared test datasets
├── External/              # External service integration tests
├── Feature/               # Feature/integration tests
│   ├── Api/              # API endpoint tests
│   ├── Auth/             # Authentication tests
│   └── Admin/            # Admin panel tests
├── Fixtures/              # Test fixture files
├── Helpers/               # Test helper functions
├── Mocks/                 # Mock implementations
├── Stubs/                 # Stub classes
├── Traits/                # Reusable test traits
└── Unit/                  # Unit tests
    ├── Models/           # Model tests
    ├── Services/         # Service tests
    └── Utilities/        # Utility class tests
```

## Naming Convention Checklist

### Do's ✅
- Use descriptive, readable test names
- Follow consistent naming patterns
- Use snake_case for test functions
- Use PascalCase for class names
- Use camelCase for variables
- Prefix helpers with their action
- Group related tests with describe blocks
- Use meaningful dataset keys

### Don'ts ❌
- Don't use abbreviations (usr → user)
- Don't use generic names (test1, testA)
- Don't use numbers without context
- Don't mix naming conventions
- Don't use special characters
- Don't make names too long (>80 chars)
- Don't use misleading names
- Don't duplicate test names