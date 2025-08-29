# Testing Strategies with Pest

## Testing Pyramid Approach

### Unit Tests (70% of tests)
```php
// Fast, isolated, numerous
test('calculator adds two numbers', function () {
    $calculator = new Calculator();
    
    expect($calculator->add(2, 3))->toBe(5);
});

test('user model calculates full name', function () {
    $user = User::make([
        'first_name' => 'John',
        'last_name' => 'Doe'
    ]);
    
    expect($user->full_name)->toBe('John Doe');
});
```

### Integration Tests (20% of tests)
```php
// Test component interactions
test('order service creates order with inventory check', function () {
    $product = Product::factory()->create(['stock' => 10]);
    $user = User::factory()->create();
    
    $orderService = new OrderService();
    $order = $orderService->create($user, $product, 2);
    
    expect($order)->toBeInstanceOf(Order::class)
        ->and($product->fresh()->stock)->toBe(8);
});

test('email service sends through queue', function () {
    Queue::fake();
    
    $emailService = new EmailService();
    $emailService->send('test@example.com', 'Welcome!');
    
    Queue::assertPushed(SendEmailJob::class);
});
```

### E2E Tests (10% of tests)
```php
// Critical user journeys
test('complete checkout process', function () {
    $user = User::factory()->create();
    $product = Product::factory()->create(['price' => 99.99]);
    
    $this->actingAs($user)
        ->visit('/products/' . $product->id)
        ->press('Add to Cart')
        ->visit('/cart')
        ->press('Checkout')
        ->type('card_number', '4111111111111111')
        ->press('Complete Purchase')
        ->assertSee('Order Confirmed')
        ->assertDatabaseHas('orders', [
            'user_id' => $user->id,
            'total' => 99.99
        ]);
});
```

## Unit Testing Best Practices

### Test Structure
```php
describe('StringHelper', function () {
    test('converts snake_case to camelCase', function () {
        expect(StringHelper::toCamelCase('hello_world'))
            ->toBe('helloWorld');
    });
    
    test('handles empty strings', function () {
        expect(StringHelper::toCamelCase(''))
            ->toBe('');
    });
    
    test('handles single words', function () {
        expect(StringHelper::toCamelCase('hello'))
            ->toBe('hello');
    });
});
```

### Testing Pure Functions
```php
test('tax calculator with different rates', function ($amount, $rate, $expected) {
    expect(TaxCalculator::calculate($amount, $rate))
        ->toBe($expected);
})->with([
    'standard rate' => [100, 0.20, 20.00],
    'reduced rate' => [100, 0.05, 5.00],
    'zero rate' => [100, 0, 0.00],
    'high amount' => [1000000, 0.20, 200000.00],
]);
```

### Testing Classes
```php
test('shopping cart operations', function () {
    $cart = new ShoppingCart();
    
    expect($cart->isEmpty())->toBeTrue();
    
    $cart->add('PROD-1', 2);
    $cart->add('PROD-2', 1);
    
    expect($cart->count())->toBe(3)
        ->and($cart->items())->toHaveCount(2);
    
    $cart->remove('PROD-1');
    
    expect($cart->items())->toHaveCount(1);
});
```

## Integration Testing Strategies

### Database Integration
```php
uses(RefreshDatabase::class);

test('repository finds users by criteria', function () {
    User::factory()->count(3)->create(['status' => 'active']);
    User::factory()->count(2)->create(['status' => 'inactive']);
    
    $repository = new UserRepository();
    $activeUsers = $repository->findByStatus('active');
    
    expect($activeUsers)->toHaveCount(3)
        ->each->status->toBe('active');
});
```

### API Integration
```php
test('weather service fetches current temperature', function () {
    Http::fake([
        'api.weather.com/*' => Http::response([
            'temperature' => 22.5,
            'unit' => 'celsius'
        ], 200)
    ]);
    
    $service = new WeatherService();
    $temperature = $service->getCurrentTemperature('London');
    
    expect($temperature)->toBe(22.5);
    
    Http::assertSent(function ($request) {
        return $request->url() === 'https://api.weather.com/current?city=London';
    });
});
```

### Queue Integration
```php
test('job processes payment and sends notification', function () {
    Queue::fake();
    Mail::fake();
    
    ProcessPaymentJob::dispatch($order = Order::factory()->create());
    
    Queue::assertPushed(ProcessPaymentJob::class);
    
    // Manually run the job
    (new ProcessPaymentJob($order))->handle();
    
    expect($order->fresh()->status)->toBe('paid');
    Mail::assertSent(PaymentConfirmation::class);
});
```

## E2E Testing Strategies

### Critical Path Testing
```php
test('user registration flow', function () {
    visit('/')
        ->click('Sign Up')
        ->type('name', 'John Doe')
        ->type('email', 'john@example.com')
        ->type('password', 'Password123!')
        ->type('password_confirmation', 'Password123!')
        ->check('terms')
        ->press('Register')
        ->assertSee('Welcome, John!')
        ->assertAuthenticated();
});
```

### Multi-Step Processes
```php
test('multi-step form submission', function () {
    $session = startSession();
    
    // Step 1: Personal Info
    $session->visit('/application/step-1')
        ->type('first_name', 'John')
        ->type('last_name', 'Doe')
        ->press('Next');
    
    // Step 2: Contact Info
    $session->assertSee('Step 2')
        ->type('email', 'john@example.com')
        ->type('phone', '555-0123')
        ->press('Next');
    
    // Step 3: Review
    $session->assertSee('Review Your Application')
        ->assertSee('John Doe')
        ->assertSee('john@example.com')
        ->press('Submit');
    
    $session->assertSee('Application Submitted Successfully');
    
    expect(Application::where('email', 'john@example.com')->exists())
        ->toBeTrue();
});
```

## Test Coverage Goals

### Setting Coverage Targets
```php
// phpunit.xml configuration
<coverage>
    <include>
        <directory suffix=".php">./app</directory>
    </include>
    <exclude>
        <directory>./app/Console</directory>
        <directory>./app/Exceptions</directory>
    </exclude>
    <report>
        <html outputDirectory="coverage" lowUpperBound="50" highLowerBound="90"/>
    </report>
</coverage>
```

### Coverage Commands
```bash
# Run with coverage report
./vendor/bin/pest --coverage

# Set minimum coverage threshold
./vendor/bin/pest --coverage --min=80

# Generate HTML coverage report
./vendor/bin/pest --coverage-html=coverage

# Type coverage
./vendor/bin/pest --type-coverage
```

### Strategic Coverage
```php
// Focus on business logic
covers(OrderCalculator::class);
covers(PricingService::class);
covers(InventoryManager::class);

// Skip UI/framework code
arch('controllers are not tested directly')
    ->expect('App\Http\Controllers')
    ->not->toBeCovered();
```

## Test Data Management

### Factories and Seeders
```php
// Define factory states
User::factory()
    ->state(['role' => 'admin'])
    ->withPosts(5)
    ->create();

// Use sequences for varied data
User::factory()
    ->count(3)
    ->sequence(
        ['role' => 'admin'],
        ['role' => 'editor'],
        ['role' => 'viewer']
    )
    ->create();
```

### Test Fixtures
```php
// Load fixture files
test('imports CSV data', function () {
    $csv = fixture('data/users.csv');
    
    $importer = new CsvImporter();
    $result = $importer->import($csv);
    
    expect($result->successful)->toBeTrue()
        ->and($result->imported)->toBe(100);
});
```

### Shared Test Data
```php
// In Pest.php
dataset('valid_emails', [
    'simple' => ['test@example.com'],
    'subdomain' => ['user@mail.example.com'],
    'plus' => ['user+tag@example.com'],
]);

dataset('product_categories', function () {
    yield 'electronics' => ['Electronics', 0.20];
    yield 'books' => ['Books', 0.05];
    yield 'food' => ['Food', 0.10];
});
```

## Testing Strategies by Feature Type

### CRUD Operations
```php
describe('Product CRUD', function () {
    test('creates product', function () {
        $response = $this->post('/api/products', [
            'name' => 'Widget',
            'price' => 29.99
        ]);
        
        expect($response->status())->toBe(201)
            ->and(Product::where('name', 'Widget')->exists())->toBeTrue();
    });
    
    test('reads product', function () {
        $product = Product::factory()->create();
        
        $response = $this->get("/api/products/{$product->id}");
        
        expect($response->json('data.id'))->toBe($product->id);
    });
    
    test('updates product', function () {
        $product = Product::factory()->create();
        
        $response = $this->put("/api/products/{$product->id}", [
            'name' => 'Updated Widget'
        ]);
        
        expect($product->fresh()->name)->toBe('Updated Widget');
    });
    
    test('deletes product', function () {
        $product = Product::factory()->create();
        
        $response = $this->delete("/api/products/{$product->id}");
        
        expect($response->status())->toBe(204)
            ->and(Product::find($product->id))->toBeNull();
    });
});
```

### Event-Driven Features
```php
test('order placement triggers events', function () {
    Event::fake();
    
    $order = OrderService::place($cart);
    
    Event::assertDispatched(OrderPlaced::class);
    Event::assertDispatched(InventoryUpdated::class);
    Event::assertDispatched(function (PaymentProcessed $event) use ($order) {
        return $event->order->id === $order->id;
    });
});
```

### Async Operations
```php
test('async report generation', function () {
    Queue::fake();
    
    $response = $this->post('/api/reports/generate', [
        'type' => 'sales',
        'period' => 'monthly'
    ]);
    
    expect($response->status())->toBe(202)
        ->and($response->json('message'))->toContain('queued');
    
    Queue::assertPushed(GenerateReport::class, function ($job) {
        return $job->type === 'sales' && $job->period === 'monthly';
    });
});
```

## Test Organization Patterns

### Arrange-Act-Assert
```php
test('applies discount to order', function () {
    // Arrange
    $order = Order::factory()->create(['total' => 100]);
    $coupon = Coupon::factory()->create(['discount' => 20]);
    
    // Act
    $order->applyCoupon($coupon);
    
    // Assert
    expect($order->total)->toBe(80)
        ->and($order->coupon_id)->toBe($coupon->id);
});
```

### Given-When-Then (BDD Style)
```php
test('user receives welcome email after registration', function () {
    // Given
    Mail::fake();
    
    // When
    $response = $this->post('/register', [
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'password' => 'password'
    ]);
    
    // Then
    Mail::assertSent(WelcomeEmail::class, function ($mail) {
        return $mail->hasTo('john@example.com');
    });
});
```

## Continuous Testing

### Watch Mode
```bash
# Auto-run tests on file changes
./vendor/bin/pest --watch

# Watch specific directory
./vendor/bin/pest --watch=app/Services
```

### Pre-commit Hooks
```bash
#!/bin/sh
# .git/hooks/pre-commit

# Run tests before commit
./vendor/bin/pest --stop-on-failure

if [ $? -ne 0 ]; then
    echo "Tests failed! Commit aborted."
    exit 1
fi
```

### CI/CD Integration
```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        php: [8.2, 8.3]
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: |
          ./vendor/bin/pest --parallel --coverage --min=80
```