# Deployment Checklist for Pest Tests

## Pre-Deployment Requirements

### Code Quality Checks
```bash
# Run all tests
./vendor/bin/pest

# Run with coverage to ensure minimum threshold
./vendor/bin/pest --coverage --min=80

# Run architecture tests
./vendor/bin/pest tests/Architecture

# Check for profanity
./vendor/bin/pest --profanity

# Type coverage check
./vendor/bin/pest --type-coverage

# Run mutation testing
./vendor/bin/pest --mutate
```

### Test Suite Health
```php
// tests/PreDeployment/HealthCheckTest.php
test('all critical tests pass', function () {
    $result = shell_exec('./vendor/bin/pest --group=critical --stop-on-failure');
    
    expect($result)->toContain('PASS');
});

test('no skipped critical tests', function () {
    $tests = getTestsByGroup('critical');
    
    foreach ($tests as $test) {
        expect($test->isSkipped())->toBeFalse(
            "Critical test '{$test->getName()}' is skipped"
        );
    }
});

test('no todo tests in production code', function () {
    $todos = shell_exec("grep -r 'todo(' tests/");
    
    expect($todos)->toBeEmpty(
        'Remove or implement all todo tests before deployment'
    );
});
```

## Environment Configuration

### Environment Variables
```php
test('required environment variables are set', function () {
    $required = [
        'APP_KEY',
        'APP_ENV',
        'DB_CONNECTION',
        'DB_HOST',
        'DB_DATABASE',
        'CACHE_DRIVER',
        'QUEUE_CONNECTION',
        'SESSION_DRIVER',
    ];
    
    foreach ($required as $variable) {
        expect(env($variable))->not->toBeNull(
            "Environment variable {$variable} is not set"
        );
    }
});

test('production environment settings are correct', function () {
    // Temporarily set to production
    $originalEnv = app()->environment();
    app()->detectEnvironment(fn() => 'production');
    
    expect(config('app.debug'))->toBeFalse()
        ->and(config('app.env'))->toBe('production')
        ->and(config('cache.default'))->not->toBe('array')
        ->and(config('session.driver'))->not->toBe('array')
        ->and(config('queue.default'))->not->toBe('sync');
    
    // Restore original environment
    app()->detectEnvironment(fn() => $originalEnv);
});
```

### Configuration Validation
```php
test('configuration files are valid', function () {
    $configFiles = glob(config_path('*.php'));
    
    foreach ($configFiles as $file) {
        $config = include $file;
        
        expect($config)->toBeArray(
            "Config file {$file} does not return an array"
        );
    }
});

test('no development values in production config', function () {
    $configContent = file_get_contents(base_path('.env.production'));
    
    expect($configContent)
        ->not->toContain('localhost')
        ->not->toContain('127.0.0.1')
        ->not->toContain('test')
        ->not->toContain('debug=true')
        ->not->toContain('example.com');
});
```

## Build Process

### Build Verification
```bash
#!/bin/bash
# tests/Scripts/build-check.sh

echo "🔨 Starting build verification..."

# Clean previous builds
rm -rf node_modules vendor
npm ci
composer install --no-dev --optimize-autoloader

# Build assets
npm run production

# Verify build output
if [ ! -f "public/js/app.js" ]; then
    echo "❌ Build failed: app.js not found"
    exit 1
fi

if [ ! -f "public/css/app.css" ]; then
    echo "❌ Build failed: app.css not found"
    exit 1
fi

echo "✅ Build verification complete"
```

### Asset Compilation Tests
```php
test('production assets are minified', function () {
    $jsContent = file_get_contents(public_path('js/app.js'));
    $cssContent = file_get_contents(public_path('css/app.css'));
    
    // Check for minification indicators
    expect(strlen($jsContent))->toBeGreaterThan(1000)
        ->and($jsContent)->not->toContain('  ') // No double spaces
        ->and($cssContent)->not->toContain('  ')
        ->and($cssContent)->not->toContain('/*'); // No comments
});

test('asset manifest exists', function () {
    $manifestPath = public_path('mix-manifest.json');
    
    expect(file_exists($manifestPath))->toBeTrue();
    
    $manifest = json_decode(file_get_contents($manifestPath), true);
    
    expect($manifest)->toHaveKeys(['/js/app.js', '/css/app.css']);
});
```

## Deployment Strategies

### Blue-Green Deployment Tests
```php
test('can switch between blue and green environments', function () {
    // Simulate blue environment
    $blueResponse = Http::get(env('BLUE_URL') . '/health');
    expect($blueResponse->ok())->toBeTrue();
    
    // Simulate green environment
    $greenResponse = Http::get(env('GREEN_URL') . '/health');
    expect($greenResponse->ok())->toBeTrue();
    
    // Verify load balancer can switch
    $activeEnv = Http::get(env('LB_URL') . '/active-env');
    expect($activeEnv->json('environment'))->toBeIn(['blue', 'green']);
});
```

### Rolling Deployment Validation
```php
test('application handles rolling updates', function () {
    // Check if old version endpoints still work
    $v1Response = Http::get('/api/v1/status');
    expect($v1Response->ok())->toBeTrue();
    
    // Check if new version endpoints work
    $v2Response = Http::get('/api/v2/status');
    expect($v2Response->ok())->toBeTrue();
    
    // Verify backward compatibility
    $oldClientResponse = Http::withHeaders(['API-Version' => '1.0'])
        ->get('/api/endpoint');
    expect($oldClientResponse->ok())->toBeTrue();
});
```

### Canary Deployment Tests
```php
test('canary deployment serves correct percentage', function () {
    $responses = collect();
    
    // Make 100 requests
    for ($i = 0; $i < 100; $i++) {
        $response = Http::get('/api/version');
        $responses->push($response->json('version'));
    }
    
    $canaryCount = $responses->filter(fn($v) => $v === 'canary')->count();
    
    // Expect ~10% canary traffic (with some tolerance)
    expect($canaryCount)->toBeBetween(5, 15);
});
```

## Post-Deployment Verification

### Health Checks
```php
test('application health endpoints respond correctly', function () {
    $endpoints = [
        '/health' => 200,
        '/api/health' => 200,
        '/ready' => 200,
    ];
    
    foreach ($endpoints as $endpoint => $expectedStatus) {
        $response = Http::get(env('APP_URL') . $endpoint);
        
        expect($response->status())->toBe($expectedStatus);
    }
});

test('database connections are working', function () {
    expect(DB::connection()->getPdo())->not->toBeNull();
    
    // Test read connection
    $result = DB::select('SELECT 1');
    expect($result)->not->toBeEmpty();
    
    // Test write connection (if separate)
    if (config('database.connections.mysql.read')) {
        $writeResult = DB::connection('mysql')->select('SELECT 1');
        expect($writeResult)->not->toBeEmpty();
    }
});

test('cache connections are working', function () {
    Cache::put('deployment_test', 'value', 60);
    
    expect(Cache::get('deployment_test'))->toBe('value');
    
    Cache::forget('deployment_test');
});

test('queue connections are working', function () {
    Queue::pushRaw('test', 'deployment-test');
    
    $job = Queue::pop('deployment-test');
    
    expect($job)->not->toBeNull()
        ->and($job->payload())->toBe('test');
});
```

### Smoke Tests
```php
// tests/Deployment/SmokeTest.php
test('critical user paths work', function () {
    // Homepage loads
    $response = $this->get('/');
    expect($response->status())->toBe(200);
    
    // Login works
    $user = User::factory()->create();
    $response = $this->post('/login', [
        'email' => $user->email,
        'password' => 'password',
    ]);
    expect($response->status())->toBe(302);
    
    // API endpoints respond
    $response = $this->getJson('/api/status');
    expect($response->status())->toBe(200);
});

test('critical business features work', function () {
    // Test payment processing
    $order = Order::factory()->create();
    $result = PaymentService::process($order);
    expect($result)->toBeTrue();
    
    // Test email sending
    Mail::fake();
    NotificationService::sendWelcomeEmail(User::factory()->create());
    Mail::assertSent(WelcomeEmail::class);
    
    // Test search functionality
    $results = SearchService::search('test');
    expect($results)->toBeArray();
});
```

### Performance Baselines
```php
test('response times are within acceptable limits', function () {
    $endpoints = [
        '/' => 200,           // Homepage: 200ms
        '/api/users' => 100,  // API list: 100ms
        '/search' => 500,     // Search: 500ms
    ];
    
    foreach ($endpoints as $endpoint => $maxTime) {
        $start = microtime(true);
        $response = Http::get(env('APP_URL') . $endpoint);
        $duration = (microtime(true) - $start) * 1000;
        
        expect($response->ok())->toBeTrue()
            ->and($duration)->toBeLessThan($maxTime);
    }
});

test('database queries are optimized', function () {
    DB::enableQueryLog();
    
    // Load a typical page
    $this->get('/dashboard');
    
    $queries = DB::getQueryLog();
    
    // Check query count
    expect(count($queries))->toBeLessThan(20);
    
    // Check for slow queries
    foreach ($queries as $query) {
        expect($query['time'])->toBeLessThan(100); // Under 100ms
    }
});
```

## Rollback Procedures

### Rollback Tests
```php
test('can rollback database migrations', function () {
    // Record current migration
    $currentMigration = DB::table('migrations')->latest()->first();
    
    // Run rollback
    Artisan::call('migrate:rollback');
    
    // Verify rollback succeeded
    $afterRollback = DB::table('migrations')->latest()->first();
    
    expect($afterRollback->id)->toBeLessThan($currentMigration->id);
    
    // Re-run migrations
    Artisan::call('migrate');
});

test('can restore from backup', function () {
    // Create backup
    $backupFile = storage_path('backup-test.sql');
    exec("mysqldump " . env('DB_DATABASE') . " > {$backupFile}");
    
    expect(file_exists($backupFile))->toBeTrue();
    
    // Verify restore command exists
    $restoreCommand = "mysql " . env('DB_DATABASE') . " < {$backupFile}";
    
    // Clean up
    unlink($backupFile);
});
```

### Feature Flag Tests
```php
test('feature flags can disable features', function () {
    // Enable feature
    config(['features.new_checkout' => true]);
    $response = $this->get('/checkout/new');
    expect($response->status())->toBe(200);
    
    // Disable feature
    config(['features.new_checkout' => false]);
    $response = $this->get('/checkout/new');
    expect($response->status())->toBe(404);
});

test('critical features cannot be disabled', function () {
    $criticalFeatures = ['authentication', 'payment', 'api'];
    
    foreach ($criticalFeatures as $feature) {
        expect(config("features.{$feature}"))->toBeTrue()
            ->and(config("features.can_disable.{$feature}"))->toBeFalse();
    }
});
```

## Deployment Checklist Script

```bash
#!/bin/bash
# deploy-checklist.sh

echo "🚀 Deployment Checklist"
echo "======================="

# Function to check step
check_step() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 - FAILED"
        exit 1
    fi
}

# Pre-deployment checks
echo -e "\n📋 Pre-deployment Checks:"

./vendor/bin/pest --stop-on-failure
check_step "All tests pass"

./vendor/bin/pest --coverage --min=80 --quiet
check_step "Code coverage >= 80%"

./vendor/bin/pest tests/Architecture --quiet
check_step "Architecture tests pass"

# Build checks
echo -e "\n🔨 Build Checks:"

npm run production
check_step "Assets compiled"

composer install --no-dev --optimize-autoloader
check_step "Dependencies optimized"

php artisan config:cache
check_step "Configuration cached"

php artisan route:cache
check_step "Routes cached"

# Database checks
echo -e "\n🗄️ Database Checks:"

php artisan migrate --dry-run
check_step "Migrations ready"

# Final verification
echo -e "\n✨ Final Verification:"

./vendor/bin/pest tests/Deployment/SmokeTest.php
check_step "Smoke tests pass"

echo -e "\n✅ All deployment checks passed!"
echo "Ready for deployment 🚀"
```

## CI/CD Integration

### GitHub Actions Deployment
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Run Pest Tests
        run: |
          ./vendor/bin/pest --parallel
          ./vendor/bin/pest --coverage --min=80
      
      - name: Run Deployment Checks
        run: ./deploy-checklist.sh
      
      - name: Deploy
        if: success()
        run: |
          # Deployment commands
          echo "Deploying..."
```

## Post-Deployment Monitoring

### Monitoring Tests
```php
test('monitoring endpoints are accessible', function () {
    $endpoints = [
        '/metrics',
        '/health',
        '/status',
    ];
    
    foreach ($endpoints as $endpoint) {
        $response = Http::get(env('APP_URL') . $endpoint);
        expect($response->ok())->toBeTrue();
    }
});

test('error rates are within threshold', function () {
    // Check error logs
    $errors = Log::channel('production')->getErrors(now()->subHour());
    
    expect(count($errors))->toBeLessThan(10); // Less than 10 errors per hour
});
```