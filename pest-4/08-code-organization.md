# Code Organization in Pest

## Project Structure Patterns

### Standard Laravel + Pest Structure
```
project/
├── app/
│   ├── Domain/           # Domain logic
│   ├── Http/
│   │   ├── Controllers/
│   │   └── Middleware/
│   ├── Models/
│   └── Services/
├── tests/
│   ├── Architecture/      # Architecture tests
│   ├── Browser/          # E2E browser tests
│   ├── Datasets/         # Shared test data
│   ├── Feature/          # Integration tests
│   │   ├── Api/
│   │   ├── Auth/
│   │   └── Console/
│   ├── Fixtures/         # Test files/data
│   ├── Helpers/          # Test utilities
│   ├── Traits/           # Test traits
│   ├── Unit/             # Unit tests
│   │   ├── Domain/
│   │   ├── Models/
│   │   └── Services/
│   ├── Pest.php          # Global config
│   └── TestCase.php      # Base test class
```

### Clean Architecture Test Structure
```
tests/
├── Domain/               # Pure business logic tests
│   ├── Entities/
│   ├── UseCases/
│   └── ValueObjects/
├── Application/          # Application services tests
│   ├── Commands/
│   ├── Queries/
│   └── Services/
├── Infrastructure/       # External services tests
│   ├── Database/
│   ├── Http/
│   └── Queue/
└── Presentation/         # UI/API tests
    ├── Api/
    ├── Console/
    └── Web/
```

## Domain-Driven Design Testing

### Bounded Context Organization
```php
// tests/Contexts/Catalog/Unit/ProductTest.php
namespace Tests\Contexts\Catalog\Unit;

test('product can be created with valid data', function () {
    $product = new Product(
        ProductId::generate(),
        new ProductName('Laravel Book'),
        Money::USD(2999)
    );
    
    expect($product->getId())->toBeInstanceOf(ProductId::class)
        ->and($product->getPrice()->getAmount())->toBe(2999);
});

// tests/Contexts/Ordering/Feature/PlaceOrderTest.php
namespace Tests\Contexts\Ordering\Feature;

test('order can be placed with items from catalog', function () {
    $customerId = CustomerId::generate();
    $items = [
        new OrderItem(ProductId::fromString('...'), 2)
    ];
    
    $order = OrderingService::placeOrder($customerId, $items);
    
    expect($order->getStatus())->toBe(OrderStatus::PENDING);
});
```

### Aggregate Testing
```php
describe('Order Aggregate', function () {
    test('order starts in pending state', function () {
        $order = Order::create(CustomerId::generate());
        
        expect($order->getStatus())->toBe(OrderStatus::PENDING);
        expect($order->getUncommittedEvents())->toHaveCount(1);
        expect($order->getUncommittedEvents()[0])
            ->toBeInstanceOf(OrderCreated::class);
    });
    
    test('order can be confirmed when pending', function () {
        $order = Order::create(CustomerId::generate());
        
        $order->confirm();
        
        expect($order->getStatus())->toBe(OrderStatus::CONFIRMED);
        expect($order->getUncommittedEvents())->toContain(
            fn($event) => $event instanceof OrderConfirmed
        );
    });
    
    test('order cannot be confirmed twice', function () {
        $order = Order::create(CustomerId::generate());
        $order->confirm();
        
        expect(fn() => $order->confirm())
            ->toThrow(InvalidOrderStateTransition::class);
    });
});
```

## Microservices Testing Patterns

### Service Isolation Tests
```php
// tests/Services/PaymentService/Unit/PaymentProcessorTest.php
test('payment processor handles successful payment', function () {
    $gateway = Mockery::mock(PaymentGateway::class);
    $gateway->shouldReceive('charge')
        ->once()
        ->andReturn(new PaymentResult(true, 'TXN-123'));
    
    $processor = new PaymentProcessor($gateway);
    $result = $processor->process(Money::USD(9999));
    
    expect($result->isSuccessful())->toBeTrue()
        ->and($result->getTransactionId())->toBe('TXN-123');
});

// tests/Services/PaymentService/Contract/PaymentApiTest.php
test('payment API contract', function () {
    $response = $this->postJson('/api/payments', [
        'amount' => 9999,
        'currency' => 'USD',
        'source' => 'tok_visa'
    ]);
    
    expect($response->status())->toBe(201)
        ->and($response->json())->toMatchArray([
            'id' => expect()->toBeString(),
            'amount' => 9999,
            'currency' => 'USD',
            'status' => 'succeeded'
        ]);
});
```

### Inter-Service Communication Tests
```php
test('inventory service updates when order is placed', function () {
    // Mock inventory service
    Http::fake([
        'inventory-service.local/*' => Http::response([
            'status' => 'updated',
            'items' => []
        ], 200)
    ]);
    
    // Place order
    $order = OrderService::place([
        'product_id' => 'PROD-123',
        'quantity' => 2
    ]);
    
    // Verify inventory service was called
    Http::assertSent(function ($request) {
        return $request->url() === 'http://inventory-service.local/api/reserve' &&
               $request['product_id'] === 'PROD-123' &&
               $request['quantity'] === 2;
    });
});
```

## Module Organization

### Feature Modules
```php
// tests/Modules/Billing/
├── Unit/
│   ├── InvoiceTest.php
│   ├── SubscriptionTest.php
│   └── PaymentMethodTest.php
├── Feature/
│   ├── CreateInvoiceTest.php
│   ├── ProcessPaymentTest.php
│   └── ManageSubscriptionTest.php
└── module-pest.php  // Module-specific configuration

// tests/Modules/Billing/module-pest.php
uses(BillingTestCase::class)
    ->beforeEach(function () {
        $this->billing = new BillingService();
    })
    ->in(__DIR__);
```

### Shared Module Testing
```php
// tests/Modules/Shared/Helpers.php
function createActiveSubscription(): Subscription
{
    return Subscription::factory()->active()->create();
}

function mockPaymentGateway(bool $successful = true): PaymentGateway
{
    $mock = Mockery::mock(PaymentGateway::class);
    $mock->shouldReceive('charge')->andReturn($successful);
    return $mock;
}

// Usage in tests
test('charges active subscription', function () {
    $subscription = createActiveSubscription();
    $gateway = mockPaymentGateway();
    
    $result = BillingService::charge($subscription, $gateway);
    
    expect($result)->toBeTrue();
});
```

## Test Organization by Layers

### Repository Layer Tests
```php
// tests/Unit/Repositories/UserRepositoryTest.php
describe('UserRepository', function () {
    beforeEach(function () {
        $this->repository = new UserRepository();
    });
    
    test('finds user by email', function () {
        $user = User::factory()->create(['email' => 'test@example.com']);
        
        $found = $this->repository->findByEmail('test@example.com');
        
        expect($found->id)->toBe($user->id);
    });
    
    test('returns null when user not found', function () {
        $found = $this->repository->findByEmail('nonexistent@example.com');
        
        expect($found)->toBeNull();
    });
    
    test('finds active users', function () {
        User::factory()->count(3)->active()->create();
        User::factory()->count(2)->inactive()->create();
        
        $activeUsers = $this->repository->findActive();
        
        expect($activeUsers)->toHaveCount(3);
    });
});
```

### Service Layer Tests
```php
// tests/Unit/Services/OrderServiceTest.php
describe('OrderService', function () {
    test('calculates order total with tax', function () {
        $items = [
            new OrderItem('PROD-1', 2, 50.00),
            new OrderItem('PROD-2', 1, 30.00)
        ];
        
        $service = new OrderService(new TaxCalculator(0.08));
        $total = $service->calculateTotal($items);
        
        expect($total)->toBe(140.40); // (100 + 30) * 1.08
    });
    
    test('applies discount codes', function () {
        $order = Order::factory()->create(['total' => 100]);
        $discount = DiscountCode::factory()->create(['value' => 20]);
        
        $service = new OrderService();
        $service->applyDiscount($order, $discount);
        
        expect($order->fresh()->total)->toBe(80);
    });
});
```

### Controller Layer Tests
```php
// tests/Feature/Controllers/ProductControllerTest.php
describe('ProductController', function () {
    test('index returns paginated products', function () {
        Product::factory()->count(25)->create();
        
        $response = $this->get('/api/products');
        
        expect($response->status())->toBe(200)
            ->and($response->json('data'))->toHaveCount(15)
            ->and($response->json('meta.total'))->toBe(25);
    });
    
    test('store validates and creates product', function () {
        $response = $this->postJson('/api/products', [
            'name' => 'New Product',
            'price' => 99.99,
            'sku' => 'PROD-NEW'
        ]);
        
        expect($response->status())->toBe(201)
            ->and(Product::where('sku', 'PROD-NEW')->exists())->toBeTrue();
    });
});
```

## Test Grouping Strategies

### By Business Feature
```php
// Group by feature
uses()->group('checkout')->in('Feature/Checkout');
uses()->group('inventory')->in('Feature/Inventory');
uses()->group('reporting')->in('Feature/Reporting');

// Run specific feature tests
./vendor/bin/pest --group=checkout
```

### By Test Type
```php
// In individual test files
test('unit test example')->group('unit');
test('integration test example')->group('integration');
test('e2e test example')->group('e2e');

// In Pest.php
uses()->group('unit')->in('Unit');
uses()->group('feature')->in('Feature');
uses()->group('browser')->in('Browser');
```

### By Priority
```php
test('critical user flow')->group('critical', 'smoke');
test('important feature')->group('important');
test('nice to have')->group('optional');

// Run critical tests in CI
./vendor/bin/pest --group=critical
```

## Naming Conventions

### Test File Naming
```
# Unit tests - match class name
app/Services/PaymentService.php
tests/Unit/Services/PaymentServiceTest.php

# Feature tests - describe feature
tests/Feature/Auth/LoginTest.php
tests/Feature/Api/CreateOrderTest.php

# Browser tests - describe user journey
tests/Browser/CheckoutProcessTest.php
tests/Browser/UserOnboardingTest.php
```

### Test Method Naming
```php
// Descriptive test names
test('user can login with valid credentials');
test('guest cannot access admin dashboard');
test('order total includes tax and shipping');

// Using "it" for behavior
it('sends email when order is placed');
it('throws exception for invalid input');
it('retries failed payments up to 3 times');

// Describe blocks for grouping
describe('ShoppingCart', function () {
    it('starts empty');
    it('can add items');
    it('calculates total');
    it('applies discounts');
});
```

## Test Data Organization

### Factories Organization
```php
// database/factories/Domain/
├── User/
│   ├── UserFactory.php
│   └── UserProfileFactory.php
├── Product/
│   ├── ProductFactory.php
│   └── ProductVariantFactory.php
└── Order/
    ├── OrderFactory.php
    └── OrderItemFactory.php
```

### Datasets Organization
```php
// tests/Datasets/users.php
dataset('user_roles', [
    'admin' => ['admin'],
    'editor' => ['editor'],
    'viewer' => ['viewer'],
]);

// tests/Datasets/products.php
dataset('product_types', [
    'physical' => ['physical', true, false],
    'digital' => ['digital', false, true],
    'service' => ['service', false, false],
]);

// Usage
test('handles different user roles', function ($role) {
    // Test implementation
})->with('user_roles');
```

### Fixtures Organization
```
tests/Fixtures/
├── csv/
│   ├── valid-import.csv
│   └── invalid-import.csv
├── json/
│   ├── api-response.json
│   └── config.json
├── images/
│   ├── valid-upload.jpg
│   └── oversized.jpg
└── xml/
    ├── valid-feed.xml
    └── malformed.xml
```

## Helper Organization

### Test Traits
```php
// tests/Traits/CreatesApplication.php
trait CreatesApplication
{
    protected function createApplication()
    {
        $app = require __DIR__.'/../../bootstrap/app.php';
        $app->make(Kernel::class)->bootstrap();
        return $app;
    }
}

// tests/Traits/InteractsWithPayments.php
trait InteractsWithPayments
{
    protected function createPayment(array $attributes = []): Payment
    {
        return Payment::factory()->create($attributes);
    }
    
    protected function mockPaymentGateway(): MockInterface
    {
        return Mockery::mock(PaymentGateway::class);
    }
}
```

### Global Helpers
```php
// tests/Helpers/AuthHelpers.php
function loginAs(User $user): TestCase
{
    return test()->actingAs($user);
}

function loginAsAdmin(): TestCase
{
    return loginAs(User::factory()->admin()->create());
}

// tests/Helpers/AssertionHelpers.php
function assertDatabaseHasWithJson(string $table, array $data): void
{
    test()->assertDatabaseHas($table, [
        'data' => json_encode($data)
    ]);
}
```