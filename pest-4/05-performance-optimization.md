# Performance Optimization in Pest

## Performance Metrics and Budgets

### Key Metrics to Track
```php
// Track test execution time
./vendor/bin/pest --profile

// Set time limits for tests
test('fast operation completes quickly')
    ->time(100); // Fails if takes more than 100ms

// Group tests by speed
test('quick unit test')->group('fast'); // < 100ms
test('integration test')->group('medium'); // < 1s
test('browser test')->group('slow'); // > 1s
```

### Performance Budgets
```php
// Set suite-wide performance goals
// In Pest.php
uses()
    ->beforeAll(function () {
        $this->startTime = microtime(true);
    })
    ->afterAll(function () {
        $duration = microtime(true) - $this->startTime;
        expect($duration)->toBeLessThan(60); // Suite should run under 60 seconds
    })
    ->in('Feature');
```

## Test Execution Optimization

### Parallel Testing
```php
// Enable parallel testing (uses all CPU cores by default)
./vendor/bin/pest --parallel

// Specify number of processes
./vendor/bin/pest --parallel --processes=4

// Configure in phpunit.xml
<phpunit>
    <extensions>
        <extension class="Pest\Parallel\ParallelExtension">
            <arguments>
                <string>--processes=8</string>
            </arguments>
        </extension>
    </extensions>
</phpunit>
```

### Test Sharding
```bash
# Split tests across multiple CI runners
# Runner 1
./vendor/bin/pest --shard=1/4

# Runner 2
./vendor/bin/pest --shard=2/4

# Runner 3
./vendor/bin/pest --shard=3/4

# Runner 4
./vendor/bin/pest --shard=4/4
```

### Selective Test Execution
```php
// Run only changed files (requires Git)
./vendor/bin/pest --dirty

// Run only specific groups
./vendor/bin/pest --group=critical
./vendor/bin/pest --exclude-group=slow

// Stop on first failure
./vendor/bin/pest --stop-on-failure

// Run failed tests from last run
./vendor/bin/pest --retry
```

## Database Optimization Strategies

### In-Memory Databases
```php
// Use SQLite in-memory for tests
// .env.testing
DB_CONNECTION=sqlite
DB_DATABASE=:memory:

// Configure in phpunit.xml
<env name="DB_CONNECTION" value="sqlite"/>
<env name="DB_DATABASE" value=":memory:"/>
```

### Database Transactions
```php
// Use transactions instead of migrations
uses(DatabaseTransactions::class)->in('Feature');

// Custom transaction handling
beforeEach(function () {
    DB::beginTransaction();
});

afterEach(function () {
    DB::rollBack();
});
```

### Minimal Database Seeding
```php
// ❌ Bad: Seeding unnecessary data
beforeEach(function () {
    $this->seed(); // Seeds entire database
});

// ✅ Good: Seed only what's needed
beforeEach(function () {
    $this->user = User::factory()->create();
    // Only create data needed for this test
});
```

### Factory Optimization
```php
// Use states to avoid callbacks
User::factory()->state([
    'email_verified_at' => now(),
    'role' => 'admin'
])->create();

// Reuse factories with make() when possible
$users = User::factory()->count(10)->make(); // Not persisted

// Use raw arrays when you don't need models
$data = User::factory()->raw(); // Returns array
```

## Caching Strategies

### Test Result Caching
```php
// Enable test result caching
./vendor/bin/pest --cache-result

// Use specific cache directory
./vendor/bin/pest --cache-directory=.pest-cache

// Clear cache when needed
./vendor/bin/pest --do-not-cache-result
```

### Coverage Caching
```php
// Cache coverage data
./vendor/bin/pest --coverage --cache-coverage

// Warm coverage cache
./vendor/bin/pest --warm-coverage-cache
```

### Configuration Caching
```php
// Cache configuration in CI
beforeAll(function () {
    Artisan::call('config:cache');
    Artisan::call('route:cache');
    Artisan::call('view:cache');
});

afterAll(function () {
    Artisan::call('config:clear');
    Artisan::call('route:clear');
    Artisan::call('view:clear');
});
```

## Mock and Stub Optimization

### Lazy Mocking
```php
// ❌ Bad: Creating mocks you might not use
beforeEach(function () {
    $this->emailService = Mockery::mock(EmailService::class);
    $this->smsService = Mockery::mock(SmsService::class);
    $this->pushService = Mockery::mock(PushService::class);
});

// ✅ Good: Create mocks when needed
function mockEmailService(): EmailService
{
    return once(fn () => Mockery::mock(EmailService::class));
}
```

### Partial Mocks
```php
// Only mock specific methods
$service = Mockery::mock(PaymentService::class)->makePartial();
$service->shouldReceive('charge')->andReturn(true);
// Other methods work normally
```

### Spy vs Mock
```php
// Use spies for verification after the fact
$spy = Mockery::spy(Logger::class);
$service = new UserService($spy);

$service->createUser($data);

$spy->shouldHaveReceived('log')->once();
```

## Browser Test Optimization

### Headless Mode
```php
// Run browser tests in headless mode (faster)
// In Pest.php
use Pest\Browser\Browser;

Browser::$headless = true;
```

### Reuse Browser Sessions
```php
// Share browser session across tests in same class
uses()->group('browser')->beforeAll(function () {
    $this->browser = Browser::start();
});

uses()->group('browser')->afterAll(function () {
    $this->browser->quit();
});
```

### Optimize Selectors
```php
// ✅ Good: Use efficient selectors
$browser->click('[data-test="submit-button"]');
$browser->type('#email', 'test@example.com');

// ❌ Bad: Complex selectors
$browser->click('div.container > form > div:nth-child(3) > button');
```

## Code Coverage Optimization

### Selective Coverage
```php
// Only collect coverage for specific directories
<coverage processUncoveredFiles="false">
    <include>
        <directory suffix=".php">./app/Services</directory>
        <directory suffix=".php">./app/Models</directory>
    </include>
    <exclude>
        <directory suffix=".php">./app/Console</directory>
    </exclude>
</coverage>
```

### Coverage Drivers
```php
// Use PCOV for faster coverage (10x faster than Xdebug)
// Install: pecl install pcov
// Enable in php.ini: extension=pcov

// Configure in phpunit.xml
<coverage driver="pcov">
    <!-- coverage configuration -->
</coverage>
```

## Memory Optimization

### Garbage Collection
```php
// Force garbage collection after heavy tests
afterEach(function () {
    gc_collect_cycles();
});

// Unset large objects
test('process large dataset', function () {
    $data = LargeDataset::load();
    
    // Process data
    
    unset($data); // Free memory
    gc_collect_cycles();
});
```

### Memory Limits
```php
// Set appropriate memory limits in phpunit.xml
<ini name="memory_limit" value="512M"/>

// Monitor memory usage
test('memory efficient operation', function () {
    $before = memory_get_usage();
    
    // Operation
    
    $after = memory_get_usage();
    expect($after - $before)->toBeLessThan(10 * 1024 * 1024); // Less than 10MB
});
```

## Profiling and Benchmarking

### Built-in Profiling
```php
// Profile test execution
./vendor/bin/pest --profile

// Profile top 10 slowest tests
./vendor/bin/pest --profile=10
```

### Custom Benchmarking
```php
// Benchmark code sections
test('optimized algorithm', function () {
    $time = benchmark(function () {
        // Code to benchmark
        processLargeDataset();
    });
    
    expect($time)->toBeLessThan(0.5); // Less than 500ms
});

function benchmark(Closure $callback): float
{
    $start = microtime(true);
    $callback();
    return microtime(true) - $start;
}
```

## Optimization Checklist

### Before Optimization
- [ ] Profile to identify bottlenecks
- [ ] Set performance budgets
- [ ] Measure baseline performance
- [ ] Identify critical paths

### Database
- [ ] Use in-memory database when possible
- [ ] Use transactions instead of migrations
- [ ] Minimize factory callbacks
- [ ] Create only necessary data
- [ ] Use `make()` instead of `create()` when possible

### Execution
- [ ] Enable parallel testing
- [ ] Use test sharding in CI
- [ ] Group tests by speed
- [ ] Skip slow tests locally
- [ ] Cache test results

### Mocking
- [ ] Mock only external dependencies
- [ ] Use partial mocks when appropriate
- [ ] Prefer spies over mocks for verification
- [ ] Lazy-load mock objects

### Coverage
- [ ] Use PCOV instead of Xdebug
- [ ] Limit coverage to important code
- [ ] Cache coverage data
- [ ] Run coverage separately from regular tests

### Browser Tests
- [ ] Run in headless mode
- [ ] Reuse browser sessions
- [ ] Use efficient selectors
- [ ] Avoid unnecessary waits

### Memory
- [ ] Unset large objects after use
- [ ] Force garbage collection when needed
- [ ] Monitor memory usage in critical tests
- [ ] Set appropriate memory limits

## Performance Anti-Patterns to Avoid

1. **Full database refresh for each test** - Use transactions
2. **Creating unnecessary test data** - Only create what you need
3. **Running all tests always** - Use groups and filters
4. **Not using parallel testing** - Enable for faster execution
5. **Complex DOM selectors in browser tests** - Use data attributes
6. **Synchronous external API calls** - Use mocks or stubs
7. **Not caching anything** - Cache results, coverage, and config
8. **Using Xdebug for coverage** - Switch to PCOV
9. **Excessive mocking** - Use real objects when fast enough
10. **Ignoring slow tests** - Fix or separate them