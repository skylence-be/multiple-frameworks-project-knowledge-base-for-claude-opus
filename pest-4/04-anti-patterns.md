# Pest Anti-Patterns

## Common Mistakes to Avoid

### 1. Testing Implementation Instead of Behavior

```php
// ❌ Bad: Testing internal implementation details
test('user service uses cache', function () {
    $service = new UserService();
    $reflection = new ReflectionClass($service);
    $property = $reflection->getProperty('cache');
    
    expect($property->getValue($service))->toBeInstanceOf(Cache::class);
});

// ✅ Good: Testing behavior
test('user service returns cached user on second call', function () {
    $service = new UserService();
    
    $user1 = $service->find(1);
    $user2 = $service->find(1); // Should hit cache
    
    expect($user1)->toBe($user2)
        ->and($service->getCacheHits())->toBe(1);
});
```

### 2. Overusing Mocks

```php
// ❌ Bad: Too many mocks make tests brittle
test('process order with everything mocked', function () {
    $userMock = Mockery::mock(User::class);
    $productMock = Mockery::mock(Product::class);
    $inventoryMock = Mockery::mock(Inventory::class);
    $emailMock = Mockery::mock(EmailService::class);
    $paymentMock = Mockery::mock(PaymentGateway::class);
    
    // Test becomes a mock configuration exercise
    $userMock->shouldReceive('getEmail')->once()->andReturn('test@example.com');
    $productMock->shouldReceive('getPrice')->once()->andReturn(99.99);
    // ... more mock setup
});

// ✅ Good: Use real objects when possible
test('process order with minimal mocking', function () {
    $user = User::factory()->create();
    $product = Product::factory()->create(['price' => 99.99]);
    
    // Only mock external dependencies
    Mail::fake();
    $paymentGateway = Mockery::mock(PaymentGateway::class);
    $paymentGateway->shouldReceive('charge')->once()->andReturn(true);
    
    $order = OrderService::process($user, $product, $paymentGateway);
    
    expect($order->total)->toBe(99.99);
    Mail::assertSent(OrderConfirmation::class);
});
```

### 3. Test Interdependencies

```php
// ❌ Bad: Tests depend on each other
test('create user', function () {
    $user = User::create(['email' => 'test@example.com']);
    $_GLOBALS['test_user_id'] = $user->id; // Sharing state
});

test('update user', function () {
    $user = User::find($_GLOBALS['test_user_id']); // Depends on previous test
    $user->update(['name' => 'Updated']);
    expect($user->name)->toBe('Updated');
});

// ✅ Good: Each test is independent
test('user can be created', function () {
    $user = User::create(['email' => 'test@example.com']);
    expect($user)->toBeInstanceOf(User::class);
});

test('user can be updated', function () {
    $user = User::factory()->create();
    $user->update(['name' => 'Updated']);
    expect($user->fresh()->name)->toBe('Updated');
});
```

### 4. Ignoring Test Failures

```php
// ❌ Bad: Skipping flaky tests indefinitely
test('flaky external API test')
    ->skip('Fails sometimes') // Never addressed
    ->group('integration');

// ✅ Good: Fix or properly handle flaky tests
test('external API with retry logic', function () {
    retry(3, function () {
        $response = Http::timeout(5)->get('https://api.example.com/data');
        expect($response->successful())->toBeTrue();
    }, 100);
})->group('integration');
```

## Code Smells in Tests

### 1. Large Test Setup

```php
// ❌ Bad: Huge setup indicates design issues
test('complex feature', function () {
    // 50 lines of setup...
    $company = Company::factory()->create();
    $department = Department::factory()->create(['company_id' => $company->id]);
    $manager = User::factory()->create(['role' => 'manager']);
    $employees = User::factory()->count(10)->create();
    // ... more setup
    
    $result = $service->process();
    expect($result)->toBeTrue();
});

// ✅ Good: Extract setup to helpers or factories
test('complex feature with clean setup', function () {
    $department = DepartmentFactory::withEmployees(10)->create();
    
    $result = $service->process($department);
    expect($result)->toBeTrue();
});
```

### 2. Multiple Assertions Without Context

```php
// ❌ Bad: Unclear what failed
test('user registration', function () {
    $response = $this->post('/register', [...]);
    
    expect($response->status())->toBe(201);
    expect($response->json('user.email'))->toBe('test@example.com');
    expect(User::count())->toBe(1);
    expect(auth()->check())->toBeTrue();
});

// ✅ Good: Group related assertions with context
test('user registration creates user and logs them in', function () {
    $response = $this->post('/register', [...]);
    
    expect($response->status())->toBe(201)
        ->and($response->json('user.email'))->toBe('test@example.com')
        ->and(User::count())->toBe(1)->because('user should be created')
        ->and(auth()->check())->toBeTrue()->because('user should be logged in');
});
```

### 3. Time-Dependent Tests

```php
// ❌ Bad: Test fails at certain times
test('scheduled task runs at midnight', function () {
    $task = new MidnightTask();
    
    if (now()->hour === 0) {
        expect($task->shouldRun())->toBeTrue();
    } else {
        expect($task->shouldRun())->toBeFalse();
    }
});

// ✅ Good: Control time in tests
test('scheduled task runs at midnight', function () {
    Carbon::setTestNow('2024-01-01 00:00:00');
    $task = new MidnightTask();
    expect($task->shouldRun())->toBeTrue();
    
    Carbon::setTestNow('2024-01-01 12:00:00');
    expect($task->shouldRun())->toBeFalse();
});
```

## Performance Pitfalls

### 1. Unnecessary Database Operations

```php
// ❌ Bad: Creating data you don't need
test('user has name', function () {
    $user = User::factory()
        ->has(Post::factory()->count(100)) // Unnecessary
        ->has(Comment::factory()->count(500)) // Unnecessary
        ->create(['name' => 'John']);
    
    expect($user->name)->toBe('John');
});

// ✅ Good: Create only what you need
test('user has name', function () {
    $user = User::factory()->create(['name' => 'John']);
    
    expect($user->name)->toBe('John');
});
```

### 2. Not Using Database Transactions

```php
// ❌ Bad: Slow database cleanup
uses(RefreshDatabase::class); // Migrations run for each test

// ✅ Good: Use transactions when possible
uses(DatabaseTransactions::class); // Rollback after each test
```

### 3. Testing Framework Code

```php
// ❌ Bad: Testing Laravel/framework functionality
test('eloquent save method works', function () {
    $user = new User(['email' => 'test@example.com']);
    $user->save();
    
    expect($user->exists)->toBeTrue();
});

// ✅ Good: Trust the framework, test your code
test('user service creates user with profile', function () {
    $service = new UserService();
    $user = $service->createWithProfile([
        'email' => 'test@example.com',
        'profile' => ['bio' => 'Developer']
    ]);
    
    expect($user->profile)->not->toBeNull()
        ->and($user->profile->bio)->toBe('Developer');
});
```

## Security Vulnerabilities in Tests

### 1. Hardcoded Credentials

```php
// ❌ Bad: Real credentials in tests
test('api authentication', function () {
    $response = Http::withToken('sk_live_abc123...') // Real API key!
        ->post('https://api.service.com/charge');
});

// ✅ Good: Use test credentials from environment
test('api authentication', function () {
    $response = Http::withToken(env('TEST_API_KEY'))
        ->post(env('TEST_API_URL') . '/charge');
});
```

### 2. Exposing Sensitive Data

```php
// ❌ Bad: Logging sensitive information
test('user login', function () {
    $password = 'secret123';
    Log::info("Testing with password: {$password}"); // Don't log passwords!
    
    $response = $this->post('/login', [
        'email' => 'test@example.com',
        'password' => $password
    ]);
});

// ✅ Good: Never log sensitive data
test('user login', function () {
    $response = $this->post('/login', [
        'email' => 'test@example.com',
        'password' => 'password'
    ]);
    
    expect($response)->toBeSuccessful();
});
```

## What NOT to Do

### 1. Don't Use Production Data

```php
// ❌ Never use real user data
test('process real orders', function () {
    $orders = DB::connection('production')->table('orders')->get();
    // NEVER DO THIS!
});
```

### 2. Don't Skip Error Scenarios

```php
// ❌ Bad: Only testing happy path
test('payment process', function () {
    $payment = new Payment(100);
    $result = $payment->process();
    expect($result)->toBeTrue();
});

// ✅ Good: Test error scenarios too
test('payment fails with invalid amount', function () {
    expect(fn() => new Payment(-100))
        ->toThrow(InvalidAmountException::class);
});
```

### 3. Don't Use Random Data Without Seeds

```php
// ❌ Bad: Non-deterministic tests
test('random calculation', function () {
    $value = rand(1, 100);
    $result = calculateSomething($value);
    expect($result)->toBeGreaterThan(0); // Might fail randomly
});

// ✅ Good: Use seeded random or datasets
test('calculation with various inputs', function ($value, $expected) {
    $result = calculateSomething($value);
    expect($result)->toBe($expected);
})->with([
    [1, 10],
    [50, 500],
    [100, 1000],
]);
```

### 4. Don't Mix Unit and Integration Tests

```php
// ❌ Bad: Unit test making HTTP requests
test('calculator adds numbers', function () {
    $response = $this->post('/api/calculate', [ // This is integration!
        'a' => 2,
        'b' => 3
    ]);
    expect($response->json('result'))->toBe(5);
});

// ✅ Good: Keep unit tests focused
test('calculator adds numbers', function () {
    $calculator = new Calculator();
    expect($calculator->add(2, 3))->toBe(5);
});
```

### 5. Don't Ignore Architecture Rules

```php
// ❌ Bad: Violating architectural boundaries
// In App/Domain/User.php
use Illuminate\Support\Facades\DB; // Framework dependency in domain!

// ✅ Good: Enforce with architecture tests
arch('domain is framework agnostic')
    ->expect('App\Domain')
    ->not->toUse('Illuminate');
```

## Red Flags to Watch For

1. **Tests that occasionally fail** - Indicates timing issues or external dependencies
2. **Tests requiring specific order** - Shows coupling between tests
3. **Commented-out assertions** - Either fix or remove them
4. **Tests with no assertions** - Not actually testing anything
5. **Copy-pasted test code** - Should use datasets or helpers
6. **Tests slower than 1 second** - Likely doing too much
7. **Mocking value objects** - Just use real objects
8. **Testing private methods directly** - Test through public interface
9. **Using sleep() in tests** - Use proper waiting mechanisms
10. **Global state modifications** - Will cause problems in parallel testing