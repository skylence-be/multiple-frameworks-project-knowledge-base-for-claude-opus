# Debugging Techniques in Pest

## Debugging Mindset

### Systematic Approach
1. **Reproduce the failure** - Ensure you can consistently reproduce the issue
2. **Isolate the problem** - Narrow down to the smallest failing test
3. **Gather information** - Use debugging tools to understand the state
4. **Form hypothesis** - Based on evidence, not assumptions
5. **Test hypothesis** - Verify with targeted debugging
6. **Fix and verify** - Implement fix and ensure all tests pass

### Common Debugging Scenarios
```php
// When a test unexpectedly fails
test('debugging example', function () {
    $user = User::factory()->create();
    
    // Add debugging output
    dump($user->toArray());
    ray($user)->label('User object');
    
    // Check assumptions
    expect($user->status)->toBe('active'); // Might fail if factory changed
});

// Temporary focused debugging
test('specific issue')->only()->dd(); // Run only this test with dump and die
```

## Debugging Tools

### Native PHP Functions
```php
test('using native debugging', function () {
    $data = processComplexData();
    
    // Basic output
    var_dump($data);        // Detailed type information
    print_r($data);         // Human-readable format
    
    // Execution flow
    debug_backtrace();      // See call stack
    debug_print_backtrace(); // Print call stack
    
    // Memory and performance
    memory_get_usage();     // Current memory usage
    memory_get_peak_usage(); // Peak memory usage
    
    // Stop execution
    die('Stopped here');    // Stop with message
    exit(1);               // Stop with exit code
});
```

### Pest's Built-in Debugging
```php
// Dump and die
test('dump and die', function () {
    $result = complexCalculation();
    
    dd($result); // Dump and die
    
    // Never reached
    expect($result)->toBe(42);
})->skip('Debugging');

// Dump without dying
test('dump values', function () {
    $step1 = firstStep();
    dump('After step 1:', $step1);
    
    $step2 = secondStep($step1);
    dump('After step 2:', $step2);
    
    expect($step2)->toBe('expected');
});

// Using ->dd() helper
test('chain debugging', function () {
    expect($value)
        ->dd()  // Dumps the expectation value
        ->toBe(5);
});
```

### Ray Debugging
```php
// Install: composer require spatie/laravel-ray --dev

test('debugging with ray', function () {
    $user = User::factory()->create();
    
    // Basic ray
    ray($user);
    ray('User created', $user);
    
    // Colored output
    ray($user)->green();
    ray('Error occurred')->red();
    
    // Labels and sections
    ray($user)->label('User object');
    ray()->showQueries(); // Show all queries
    
    // Conditional ray
    ray($user)->if($user->isAdmin());
    
    // Pause execution
    ray()->pause(); // Pause in Ray app
    
    // Clear Ray window
    ray()->clearAll();
    
    // Track execution time
    ray()->measure(function () {
        sleep(1);
        return 'done';
    });
});
```

### Xdebug Integration
```php
// Set breakpoint in IDE, then run:
// ./vendor/bin/pest --debug

test('step debugging', function () {
    $user = User::factory()->create();
    
    xdebug_break(); // Trigger breakpoint programmatically
    
    $result = $user->processSubscription();
    
    expect($result)->toBeTrue();
});

// Xdebug configuration for coverage
// php.ini or .user.ini
/*
xdebug.mode=debug,coverage
xdebug.start_with_request=yes
xdebug.client_host=localhost
xdebug.client_port=9003
*/
```

## Browser DevTools Usage

### Browser Test Debugging
```php
test('browser debugging', function () {
    $this->browse(function ($browser) {
        $browser->visit('/login')
            ->screenshot('before-login') // Take screenshot
            ->dump()                      // Dump page source
            ->pause(1000)                 // Pause for inspection
            ->type('email', 'user@example.com')
            ->press('Login')
            ->assertSee('Dashboard');
    });
});

// Interactive debugging
test('interactive browser test', function () {
    $this->browse(function ($browser) {
        $browser->visit('/complex-page')
            ->pause(); // Pause indefinitely for manual inspection
            
        // Use browser DevTools while paused
        // - Inspect elements
        // - Check network requests
        // - View console logs
        // - Test JavaScript manually
    });
})->skip('Interactive debugging');
```

### Console Output in Browser Tests
```php
test('capture browser console', function () {
    $this->browse(function ($browser) {
        $browser->visit('/page-with-js')
            ->assertConsoleLogHasNoErrors() // Custom assertion
            ->assertNoJavaScriptErrors();
        
        // Get console logs
        $logs = $browser->driver->manage()->getLog('browser');
        
        foreach ($logs as $log) {
            if ($log['level'] === 'SEVERE') {
                $this->fail('JavaScript error: ' . $log['message']);
            }
        }
    });
});
```

## Performance Profiling

### Timing Tests
```php
test('performance profiling', function () {
    $start = microtime(true);
    
    // Operation to profile
    $result = expensiveOperation();
    
    $duration = microtime(true) - $start;
    
    ray("Operation took: {$duration} seconds");
    
    expect($duration)->toBeLessThan(1.0); // Should complete in under 1 second
});

// Using Pest's built-in timing
test('timed test', function () {
    $result = expensiveOperation();
    
    expect($result)->not->toBeNull();
})->time(1000); // Fails if takes more than 1000ms
```

### Query Debugging
```php
test('debug database queries', function () {
    DB::enableQueryLog();
    
    // Perform operations
    $users = User::with('posts')->get();
    $orders = Order::whereDate('created_at', today())->get();
    
    $queries = DB::getQueryLog();
    
    // Analyze queries
    dump('Total queries:', count($queries));
    
    foreach ($queries as $query) {
        dump([
            'sql' => $query['query'],
            'bindings' => $query['bindings'],
            'time' => $query['time'] . 'ms',
        ]);
    }
    
    // Assert query count
    expect(count($queries))->toBeLessThan(10); // N+1 query detection
});

// Using Laravel Debugbar
test('with debugbar', function () {
    Debugbar::enable();
    
    $response = $this->get('/api/users');
    
    $queries = Debugbar::getCollector('queries')->collect();
    
    expect($queries['nb_statements'])->toBeLessThan(5);
});
```

## Memory Leak Detection

### Memory Usage Monitoring
```php
test('detect memory leaks', function () {
    $initialMemory = memory_get_usage();
    
    // Run operation multiple times
    for ($i = 0; $i < 1000; $i++) {
        $object = new LargeObject();
        // Should be garbage collected
        unset($object);
    }
    
    gc_collect_cycles(); // Force garbage collection
    
    $finalMemory = memory_get_usage();
    $leak = $finalMemory - $initialMemory;
    
    dump("Memory leak: " . number_format($leak / 1024 / 1024, 2) . " MB");
    
    expect($leak)->toBeLessThan(1024 * 1024); // Less than 1MB leak
});

// Profile memory in loops
test('memory profiling', function () {
    $memoryPoints = [];
    
    foreach (range(1, 100) as $i) {
        User::factory()->create();
        
        if ($i % 10 === 0) {
            $memoryPoints[$i] = memory_get_usage(true);
        }
    }
    
    // Analyze memory growth
    ray()->table('Memory Usage', $memoryPoints);
    
    $growth = end($memoryPoints) - reset($memoryPoints);
    expect($growth)->toBeLessThan(10 * 1024 * 1024); // Less than 10MB growth
});
```

## Debugging Helpers

### Custom Debug Functions
```php
// In tests/Helpers/debug.php

function debug_table(array $data, string $title = 'Debug Table'): void
{
    if (!app()->environment('testing')) {
        return;
    }
    
    ray()->table($title, $data);
    
    // Also output to console
    echo "\n=== {$title} ===\n";
    foreach ($data as $key => $value) {
        echo "{$key}: " . json_encode($value) . "\n";
    }
}

function debug_sql(Closure $callback): array
{
    DB::enableQueryLog();
    
    $callback();
    
    $queries = DB::getQueryLog();
    DB::disableQueryLog();
    
    ray()->showQueries($queries);
    
    return $queries;
}

function debug_exception(Throwable $e): void
{
    ray()->exception($e);
    
    dump([
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => $e->getTraceAsString(),
    ]);
}
```

### State Inspection
```php
test('inspect application state', function () {
    // Inspect service container
    $bindings = app()->getBindings();
    ray($bindings)->label('Container bindings');
    
    // Inspect configuration
    $config = config()->all();
    ray($config)->label('All configuration');
    
    // Inspect loaded service providers
    $providers = app()->getLoadedProviders();
    ray($providers)->label('Loaded providers');
    
    // Inspect middleware
    $middleware = app(Kernel::class)->getMiddleware();
    ray($middleware)->label('Global middleware');
});
```

## Test Isolation Debugging

### Finding Test Pollution
```php
// Run tests in random order to find dependencies
// ./vendor/bin/pest --order-by=random

test('potentially polluted test', function () {
    // Add state checking
    expect(Cache::get('some_key'))->toBeNull()
        ->and(Session::all())->toBeEmpty()
        ->and(Queue::size())->toBe(0);
    
    // Your test logic
    doSomething();
    
    // Verify state isn't polluted
    expect(Cache::get('some_key'))->toBeNull();
});

// Clean up after tests
afterEach(function () {
    Cache::flush();
    Session::flush();
    Queue::clear();
    Mockery::close();
});
```

### Debugging Flaky Tests
```php
test('potentially flaky test', function () {
    // Add retry logic for debugging
    $attempts = 0;
    $maxAttempts = 3;
    
    while ($attempts < $maxAttempts) {
        try {
            $result = unreliableOperation();
            expect($result)->toBeTrue();
            break;
        } catch (Exception $e) {
            $attempts++;
            ray("Attempt {$attempts} failed: " . $e->getMessage());
            
            if ($attempts === $maxAttempts) {
                throw $e;
            }
            
            sleep(1); // Wait before retry
        }
    }
});
```

## Advanced Debugging Techniques

### Snapshot Debugging
```php
test('debug with snapshots', function () {
    $state = [
        'user' => User::factory()->create()->toArray(),
        'config' => config('app'),
        'time' => now()->toDateTimeString(),
    ];
    
    // Save snapshot for comparison
    file_put_contents(
        base_path('tests/snapshots/debug-state.json'),
        json_encode($state, JSON_PRETTY_PRINT)
    );
    
    // Later, compare with saved snapshot
    $savedState = json_decode(
        file_get_contents(base_path('tests/snapshots/debug-state.json')),
        true
    );
    
    $diff = array_diff_assoc($state, $savedState);
    ray($diff)->label('State differences');
});
```

### Event Stream Debugging
```php
test('debug event flow', function () {
    $events = [];
    
    Event::listen('*', function ($event, $data) use (&$events) {
        $events[] = [
            'event' => $event,
            'data' => $data,
            'time' => microtime(true),
        ];
    });
    
    // Perform operations
    $user = User::factory()->create();
    $user->delete();
    
    // Analyze event flow
    ray()->table('Events', array_map(function ($event) {
        return [
            'event' => class_basename($event['event']),
            'time' => $event['time'],
        ];
    }, $events));
});
```

## Debugging Checklist

### Before Debugging
- [ ] Can you reproduce the issue consistently?
- [ ] Have you isolated the test that's failing?
- [ ] Is the test environment properly configured?
- [ ] Are all dependencies up to date?

### During Debugging
- [ ] Use appropriate debugging tools (dump, ray, xdebug)
- [ ] Check your assumptions with assertions
- [ ] Verify database state before and after
- [ ] Monitor memory and performance
- [ ] Check for race conditions

### After Debugging
- [ ] Remove all debugging code
- [ ] Add regression test for the bug
- [ ] Document the fix
- [ ] Verify all tests still pass
- [ ] Consider adding monitoring for similar issues