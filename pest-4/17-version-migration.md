# Version Migration Guide for Pest

## Migration Planning

### Pre-Migration Assessment
```php
// tests/Migration/PreMigrationTest.php
test('current pest version is documented', function () {
    $version = \Composer\InstalledVersions::getVersion('pestphp/pest');
    
    expect($version)->not->toBeNull();
    
    // Log current version
    file_put_contents(
        base_path('pest-migration.log'),
        "Current version: {$version}\n",
        FILE_APPEND
    );
});

test('all tests pass before migration', function () {
    $result = shell_exec('./vendor/bin/pest --stop-on-failure');
    
    expect($result)->toContain('PASS')
        ->and($result)->not->toContain('FAIL');
});

test('test coverage baseline is recorded', function () {
    $coverage = shell_exec('./vendor/bin/pest --coverage --min=0');
    
    preg_match('/Total Coverage\s+(\d+\.\d+)%/', $coverage, $matches);
    $percentage = $matches[1] ?? 0;
    
    file_put_contents(
        base_path('pest-migration.log'),
        "Baseline coverage: {$percentage}%\n",
        FILE_APPEND
    );
    
    expect($percentage)->toBeGreaterThan(0);
});
```

## Breaking Changes Handling

### Pest v3 to v4 Migration
```php
// Deprecated features detection
test('detects v3 deprecated features', function () {
    $testFiles = glob('tests/**/*.php');
    $deprecations = [];
    
    foreach ($testFiles as $file) {
        $content = file_get_contents($file);
        
        // Check for deprecated methods
        if (str_contains($content, '->group()')) {
            $deprecations[] = "{$file}: ->group() is deprecated, use ->tags()";
        }
        
        if (str_contains($content, 'uses(TestCase::class)->in()')) {
            $deprecations[] = "{$file}: Consider using new syntax";
        }
    }
    
    if (!empty($deprecations)) {
        dump('Deprecations found:', $deprecations);
    }
    
    expect($deprecations)->toBeEmpty();
});

// Migration script for common patterns
function migratePestV3ToV4(string $filePath): void
{
    $content = file_get_contents($filePath);
    
    // Update deprecated methods
    $replacements = [
        '->group(' => '->tags(',
        'expectException(' => 'expect()->toThrow(',
        'getMockBuilder(' => 'Mockery::mock(',
    ];
    
    foreach ($replacements as $old => $new) {
        $content = str_replace($old, $new, $content);
    }
    
    // Update browser testing syntax
    $content = preg_replace(
        '/\$this->browse\(/',
        'visit(',
        $content
    );
    
    file_put_contents($filePath, $content);
}
```

### PHPUnit Version Compatibility
```php
test('PHPUnit version is compatible with Pest', function () {
    $pestVersion = \Composer\InstalledVersions::getVersion('pestphp/pest');
    $phpunitVersion = \Composer\InstalledVersions::getVersion('phpunit/phpunit');
    
    // Pest 4 requires PHPUnit 12
    if (str_starts_with($pestVersion, '4.')) {
        expect($phpunitVersion)->toMatch('/^12\./');
    }
    
    // Pest 3 requires PHPUnit 11
    if (str_starts_with($pestVersion, '3.')) {
        expect($phpunitVersion)->toMatch('/^11\./');
    }
});
```

## Incremental Migration

### Step-by-Step Migration
```bash
#!/bin/bash
# scripts/incremental-migration.sh

echo "🔄 Starting incremental Pest migration"

# Step 1: Update Pest core only
echo "Step 1: Updating Pest core..."
composer require pestphp/pest:^4.0 --dev --update-with-dependencies

# Run basic tests
if ! ./vendor/bin/pest tests/Unit; then
    echo "❌ Unit tests failed after core update"
    exit 1
fi

# Step 2: Update plugins one by one
plugins=("laravel" "arch" "browser" "mutate")

for plugin in "${plugins[@]}"; do
    echo "Updating pest-plugin-$plugin..."
    composer require "pestphp/pest-plugin-$plugin:^4.0" --dev
    
    # Test after each plugin update
    if ! ./vendor/bin/pest; then
        echo "⚠️ Tests failed after updating $plugin"
        echo "Fix issues before continuing"
        exit 1
    fi
done

echo "✅ Migration complete!"
```

### Parallel Version Testing
```php
// Test compatibility with multiple versions
test('code works with both Pest versions', function () {
    $pestVersion = \Composer\InstalledVersions::getVersion('pestphp/pest');
    $majorVersion = explode('.', $pestVersion)[0];
    
    // Version-specific logic
    if ($majorVersion === '3') {
        // Pest 3 specific test
        expect(true)->toBeTrue();
    } elseif ($majorVersion === '4') {
        // Pest 4 specific test
        expect(true)->toBeTrue();
    }
});

// Compatibility layer for smooth migration
if (!function_exists('visit')) {
    function visit($url) {
        return test()->visit($url);
    }
}
```

## Testing During Migration

### Migration Test Suite
```php
// tests/Migration/MigrationTest.php
describe('Migration Tests', function () {
    test('all unit tests pass', function () {
        $result = shell_exec('./vendor/bin/pest tests/Unit --stop-on-failure');
        expect($result)->toContain('PASS');
    });
    
    test('all feature tests pass', function () {
        $result = shell_exec('./vendor/bin/pest tests/Feature --stop-on-failure');
        expect($result)->toContain('PASS');
    });
    
    test('coverage remains consistent', function () {
        $coverage = shell_exec('./vendor/bin/pest --coverage --min=0');
        preg_match('/Total Coverage\s+(\d+\.\d+)%/', $coverage, $matches);
        
        $currentCoverage = (float) ($matches[1] ?? 0);
        $baselineCoverage = 80.0; // Your baseline
        
        expect($currentCoverage)->toBeGreaterThanOrEqual($baselineCoverage - 5);
    });
});
```

### Regression Testing
```php
test('no regression in test execution time', function () {
    $start = microtime(true);
    shell_exec('./vendor/bin/pest tests/Unit');
    $duration = microtime(true) - $start;
    
    // Compare with baseline (adjust based on your tests)
    expect($duration)->toBeLessThan(60); // 60 seconds max
});

test('no regression in memory usage', function () {
    $memoryBefore = memory_get_usage();
    
    shell_exec('./vendor/bin/pest tests/Unit');
    
    $memoryAfter = memory_get_peak_usage();
    $memoryUsed = ($memoryAfter - $memoryBefore) / 1024 / 1024;
    
    expect($memoryUsed)->toBeLessThan(500); // 500MB max
});
```

## Rollback Procedures

### Rollback Plan
```bash
#!/bin/bash
# scripts/rollback-pest.sh

echo "⏪ Rolling back Pest migration"

# Check for backup
if [ ! -f "composer.lock.backup" ]; then
    echo "❌ No backup found. Cannot rollback."
    exit 1
fi

# Restore previous versions
mv composer.lock.backup composer.lock
composer install

# Verify rollback
if ./vendor/bin/pest --version | grep -q "3."; then
    echo "✅ Successfully rolled back to Pest 3"
else
    echo "❌ Rollback failed"
    exit 1
fi

# Run tests to verify
./vendor/bin/pest
```

### Version Pinning
```json
{
    "require-dev": {
        "pestphp/pest": "3.5.1",
        "pestphp/pest-plugin-laravel": "3.0.0"
    },
    "config": {
        "platform": {
            "php": "8.2"
        }
    }
}
```

## Feature Flag Migration

### Gradual Feature Adoption
```php
// config/pest.php
return [
    'features' => [
        'browser_testing' => env('PEST_BROWSER_TESTING', false),
        'architecture_testing' => env('PEST_ARCH_TESTING', true),
        'mutation_testing' => env('PEST_MUTATION_TESTING', false),
        'parallel_testing' => env('PEST_PARALLEL', false),
    ],
];

// In tests
test('uses new browser testing')
    ->skip(!config('pest.features.browser_testing'))
    ->visit('/')
    ->assertSee('Welcome');
```

## Migration Checklist

### Pre-Migration
- [ ] Document current Pest version
- [ ] Record test coverage baseline
- [ ] Backup composer.json and composer.lock
- [ ] Review breaking changes documentation
- [ ] Identify deprecated features in use
- [ ] Create migration branch

### During Migration
- [ ] Update Pest core first
- [ ] Run unit tests after core update
- [ ] Update plugins incrementally
- [ ] Fix deprecation warnings
- [ ] Update CI configuration
- [ ] Update documentation

### Post-Migration
- [ ] All tests passing
- [ ] Coverage maintained or improved
- [ ] Performance acceptable
- [ ] CI/CD pipeline working
- [ ] Team notified of changes
- [ ] Migration guide documented

## Version-Specific Features

### Pest v4 New Features
```php
// Browser testing
test('browser testing in v4', function () {
    visit('/login')
        ->type('email', 'user@example.com')
        ->press('Login')
        ->assertSee('Dashboard');
});

// Test sharding
// ./vendor/bin/pest --shard=1/4

// Profanity checking
// ./vendor/bin/pest --profanity

// Type coverage
// ./vendor/bin/pest --type-coverage
```

### Maintaining Backward Compatibility
```php
// Compatibility wrapper for teams migrating gradually
trait PestCompatibility
{
    public function pestVersion(): int
    {
        $version = \Composer\InstalledVersions::getVersion('pestphp/pest');
        return (int) explode('.', $version)[0];
    }
    
    public function runCompatibleTest(Closure $v3, Closure $v4): void
    {
        if ($this->pestVersion() === 3) {
            $v3();
        } else {
            $v4();
        }
    }
}

// Usage
test('compatible test', function () {
    $this->runCompatibleTest(
        v3: fn() => expect(true)->toBeTrue(),
        v4: fn() => expect(true)->toBeTrue()
    );
})->uses(PestCompatibility::class);
```

## Troubleshooting Migration Issues

### Common Issues and Solutions
```php
// Issue: Class not found after migration
test('autoload is refreshed', function () {
    shell_exec('composer dump-autoload');
    expect(class_exists(\Pest\TestSuite::class))->toBeTrue();
});

// Issue: Plugins not recognized
test('plugins are properly installed', function () {
    $plugins = shell_exec('./vendor/bin/pest --plugins');
    expect($plugins)->toContain('Laravel Plugin');
});

// Issue: Configuration not loading
test('pest configuration is valid', function () {
    $config = include base_path('tests/Pest.php');
    expect($config)->not->toThrow(Exception::class);
});
```

## Documentation Updates

### Updating Team Documentation
```markdown
# Pest Migration Guide - v3 to v4

## What Changed
- Browser testing now built-in
- New test sharding feature
- Updated PHPUnit to v12
- Improved parallel testing

## Action Required
1. Update composer.json dependencies
2. Run migration script: `./scripts/migrate-pest.sh`
3. Update CI configuration
4. Review and update custom helpers

## New Features Available
- Browser testing without additional setup
- Test sharding for faster CI
- Profanity checking
- Type coverage analysis
```