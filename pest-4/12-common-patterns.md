# Common Patterns in Pest Testing

## Design Patterns

### Factory Pattern for Test Data
```php
// Test data factory
class TestDataFactory
{
    public static function validUser(array $overrides = []): array
    {
        return array_merge([
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'SecurePass123!',
            'role' => 'user',
        ], $overrides);
    }
    
    public static function validOrder(User $user = null): array
    {
        return [
            'user_id' => $user?->id ?? User::factory()->create()->id,
            'items' => self::orderItems(),
            'shipping_address' => self::validAddress(),
            'payment_method' => 'credit_card',
        ];
    }
    
    public static function orderItems(int $count = 3): array
    {
        return Product::factory()
            ->count($count)
            ->create()
            ->map(fn($product) => [
                'product_id' => $product->id,
                'quantity' => rand(1, 5),
                'price' => $product->price,
            ])
            ->toArray();
    }
}

// Usage in tests
test('creates order with valid data', function () {
    $orderData = TestDataFactory::validOrder();
    
    $response = $this->postJson('/api/orders', $orderData);
    
    expect($response->status())->toBe(201);
});
```

### Builder Pattern for Complex Test Objects
```php
class OrderBuilder
{
    private array $items = [];
    private ?User $user = null;
    private float $discount = 0;
    private string $status = 'pending';
    
    public function forUser(User $user): self
    {
        $this->user = $user;
        return $this;
    }
    
    public function withItems(array $items): self
    {
        $this->items = $items;
        return $this;
    }
    
    public function withDiscount(float $discount): self
    {
        $this->discount = $discount;
        return $this;
    }
    
    public function withStatus(string $status): self
    {
        $this->status = $status;
        return $this;
    }
    
    public function build(): Order
    {
        $order = Order::create([
            'user_id' => $this->user?->id ?? User::factory()->create()->id,
            'status' => $this->status,
            'discount' => $this->discount,
        ]);
        
        foreach ($this->items as $item) {
            $order->items()->create($item);
        }
        
        return $order;
    }
}

// Usage
test('order with discount', function () {
    $order = (new OrderBuilder())
        ->forUser(User::factory()->create())
        ->withItems([['product_id' => 1, 'quantity' => 2]])
        ->withDiscount(20)
        ->build();
    
    expect($order->calculateTotal())->toBe(80); // Assuming base price is 100
});
```

### Page Object Pattern for Browser Tests
```php
class LoginPage
{
    private $browser;
    
    public function __construct($browser)
    {
        $this->browser = $browser;
    }
    
    public function visit(): self
    {
        $this->browser->visit('/login');
        return $this;
    }
    
    public function fillEmail(string $email): self
    {
        $this->browser->type('email', $email);
        return $this;
    }
    
    public function fillPassword(string $password): self
    {
        $this->browser->type('password', $password);
        return $this;
    }
    
    public function submit(): self
    {
        $this->browser->press('Login');
        return $this;
    }
    
    public function login(string $email, string $password): self
    {
        return $this->visit()
            ->fillEmail($email)
            ->fillPassword($password)
            ->submit();
    }
    
    public function assertLoginSuccessful(): self
    {
        $this->browser->assertPathIs('/dashboard');
        return $this;
    }
    
    public function assertLoginFailed(): self
    {
        $this->browser->assertSee('Invalid credentials');
        return $this;
    }
}

// Usage
test('successful login', function () {
    $loginPage = new LoginPage($this->browser);
    
    $loginPage->login('user@example.com', 'password')
        ->assertLoginSuccessful();
});
```

### Repository Pattern for Test Data Access
```php
class TestUserRepository
{
    private static array $cache = [];
    
    public static function admin(): User
    {
        return self::$cache['admin'] ??= User::factory()->admin()->create();
    }
    
    public static function customer(): User
    {
        return self::$cache['customer'] ??= User::factory()->customer()->create();
    }
    
    public static function suspended(): User
    {
        return self::$cache['suspended'] ??= User::factory()->suspended()->create();
    }
    
    public static function withPurchaseHistory(): User
    {
        return User::factory()
            ->has(Order::factory()->count(5)->completed())
            ->create();
    }
    
    public static function clear(): void
    {
        self::$cache = [];
    }
}

// Usage
test('admin can access admin panel', function () {
    $admin = TestUserRepository::admin();
    
    $response = $this->actingAs($admin)->get('/admin');
    
    expect($response->status())->toBe(200);
});
```

## Framework-Specific Patterns

### Laravel Testing Patterns

#### Service Container Mocking
```php
test('service uses injected dependencies', function () {
    // Mock the dependency
    $mockMailer = Mockery::mock(MailerInterface::class);
    $mockMailer->shouldReceive('send')->once()->andReturn(true);
    
    // Bind mock to container
    $this->app->instance(MailerInterface::class, $mockMailer);
    
    // Test the service
    $service = app(NotificationService::class);
    $result = $service->notify('user@example.com', 'Test message');
    
    expect($result)->toBeTrue();
});
```

#### Event Testing Pattern
```php
test('order placement triggers events', function () {
    Event::fake([
        OrderPlaced::class,
        InventoryUpdated::class,
        CustomerNotified::class,
    ]);
    
    // Place order
    $order = OrderService::place(
        User::factory()->create(),
        Product::factory()->create()
    );
    
    // Assert events dispatched
    Event::assertDispatched(OrderPlaced::class, function ($event) use ($order) {
        return $event->order->id === $order->id;
    });
    
    Event::assertDispatched(InventoryUpdated::class);
    Event::assertDispatched(CustomerNotified::class);
    
    // Assert event count
    Event::assertDispatchedTimes(OrderPlaced::class, 1);
});
```

#### Job Testing Pattern
```php
test('processes job with retry logic', function () {
    Queue::fake();
    
    // Dispatch job
    ProcessPayment::dispatch($order = Order::factory()->create());
    
    // Assert job pushed
    Queue::assertPushed(ProcessPayment::class, function ($job) use ($order) {
        return $job->order->id === $order->id && 
               $job->tries === 3 && 
               $job->timeout === 120;
    });
    
    // Simulate job execution
    $job = new ProcessPayment($order);
    $job->handle();
    
    // Assert job completed successfully
    expect($order->fresh()->status)->toBe('paid');
});
```

### State Management Patterns

#### Test State Manager
```php
class TestState
{
    private static array $state = [];
    
    public static function set(string $key, mixed $value): void
    {
        self::$state[$key] = $value;
    }
    
    public static function get(string $key, mixed $default = null): mixed
    {
        return self::$state[$key] ?? $default;
    }
    
    public static function remember(string $key, Closure $callback): mixed
    {
        if (!isset(self::$state[$key])) {
            self::$state[$key] = $callback();
        }
        
        return self::$state[$key];
    }
    
    public static function reset(): void
    {
        self::$state = [];
    }
}

// Usage
beforeEach(function () {
    TestState::reset();
});

test('uses shared state', function () {
    $user = TestState::remember('user', fn() => User::factory()->create());
    
    // Use $user across multiple assertions
    expect($user)->toBeInstanceOf(User::class);
});
```

### API Testing Patterns

#### API Response Assertion Helper
```php
class ApiResponse
{
    public function __construct(
        private TestResponse $response
    ) {}
    
    public function assertSuccess(int $expectedStatus = 200): self
    {
        expect($this->response->status())->toBe($expectedStatus);
        return $this;
    }
    
    public function assertJsonStructure(array $structure): self
    {
        $this->response->assertJsonStructure($structure);
        return $this;
    }
    
    public function assertPaginated(): self
    {
        return $this->assertJsonStructure([
            'data' => [],
            'links' => ['first', 'last', 'prev', 'next'],
            'meta' => ['current_page', 'last_page', 'per_page', 'total'],
        ]);
    }
    
    public function getData(): array
    {
        return $this->response->json('data');
    }
}

// Usage
test('api returns paginated users', function () {
    User::factory()->count(25)->create();
    
    $response = new ApiResponse($this->get('/api/users'));
    
    $response->assertSuccess()
        ->assertPaginated();
    
    expect($response->getData())->toHaveCount(15); // Default pagination
});
```

### Caching Patterns

#### Cache Testing Helper
```php
trait TestsCache
{
    protected function assertCached(string $key, mixed $expected = null): void
    {
        expect(Cache::has($key))->toBeTrue();
        
        if ($expected !== null) {
            expect(Cache::get($key))->toBe($expected);
        }
    }
    
    protected function assertNotCached(string $key): void
    {
        expect(Cache::has($key))->toBeFalse();
    }
    
    protected function withCache(string $key, mixed $value): void
    {
        Cache::put($key, $value, now()->addHour());
    }
}

test('caches expensive operation', function () {
    Cache::flush();
    
    // First call - not cached
    $result = ExpensiveService::calculate();
    $this->assertCached('expensive_calculation', $result);
    
    // Second call - from cache
    Cache::shouldReceive('remember')->never();
    $cachedResult = ExpensiveService::calculate();
    
    expect($cachedResult)->toBe($result);
})->uses(TestsCache::class);
```

### Database Patterns

#### Database State Snapshots
```php
class DatabaseSnapshot
{
    private array $snapshot = [];
    
    public function capture(string $table): void
    {
        $this->snapshot[$table] = DB::table($table)->get()->toArray();
    }
    
    public function assertUnchanged(string $table): void
    {
        $current = DB::table($table)->get()->toArray();
        
        expect($current)->toBe($this->snapshot[$table]);
    }
    
    public function assertChanged(string $table): void
    {
        $current = DB::table($table)->get()->toArray();
        
        expect($current)->not->toBe($this->snapshot[$table]);
    }
}

test('operation does not affect unrelated tables', function () {
    $snapshot = new DatabaseSnapshot();
    $snapshot->capture('products');
    
    // Perform operation that should only affect orders
    OrderService::process(Order::factory()->create());
    
    $snapshot->assertUnchanged('products');
});
```

## Testing Async Operations

### Promise/Async Pattern
```php
test('handles async operations', function () {
    $promise = new AsyncOperation();
    
    $promise->then(function ($result) {
        TestState::set('result', $result);
    })->catch(function ($error) {
        TestState::set('error', $error);
    });
    
    // Wait for completion
    $promise->wait();
    
    expect(TestState::get('result'))->not->toBeNull()
        ->and(TestState::get('error'))->toBeNull();
});
```

### Retry Pattern
```php
function retry(int $times, Closure $callback, int $sleep = 0): mixed
{
    $attempts = 0;
    
    beginning:
    try {
        $attempts++;
        return $callback($attempts);
    } catch (Exception $e) {
        if ($attempts < $times) {
            if ($sleep) {
                usleep($sleep * 1000);
            }
            
            goto beginning;
        }
        
        throw $e;
    }
}

test('retries failed operation', function () {
    $result = retry(3, function ($attempt) {
        if ($attempt < 3) {
            throw new Exception('Failed');
        }
        
        return 'success';
    }, 100);
    
    expect($result)->toBe('success');
});
```

## Custom Matcher Patterns

### Domain-Specific Matchers
```php
// In Pest.php
expect()->extend('toBeValidUuid', function () {
    $pattern = '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i';
    
    return $this->toMatch($pattern);
});

expect()->extend('toBeValidMoney', function () {
    return $this->toBeFloat()
        ->toBeGreaterThanOrEqual(0)
        ->toBeLessThan(1000000);
});

expect()->extend('toBeActiveUser', function () {
    return $this->toBeInstanceOf(User::class)
        ->status->toBe('active')
        ->email_verified_at->not->toBeNull();
});

// Usage
test('generates valid identifiers', function () {
    $uuid = Str::uuid()->toString();
    $price = Product::factory()->create()->price;
    $user = User::factory()->active()->create();
    
    expect($uuid)->toBeValidUuid()
        ->and($price)->toBeValidMoney()
        ->and($user)->toBeActiveUser();
});
```