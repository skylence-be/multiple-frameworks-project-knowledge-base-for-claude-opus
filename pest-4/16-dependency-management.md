# Dependency Management in Pest

## Package Selection Criteria

### Evaluating Testing Dependencies
```php
// tests/Dependencies/PackageEvaluationTest.php
test('package meets quality criteria', function ($package) {
    $composerData = json_decode(
        file_get_contents("vendor/{$package}/composer.json"),
        true
    );
    
    // Check maintenance status
    expect($composerData)->toHaveKey('authors')
        ->and($composerData)->toHaveKey('license');
    
    // Check for tests
    $hasTests = file_exists("vendor/{$package}/tests") ||
                file_exists("vendor/{$package}/test");
    expect($hasTests)->toBeTrue("{$package} should have tests");
    
    // Check for recent updates
    $packageInfo = json_decode(
        shell_exec("composer show {$package} --format=json"),
        true
    );
    
    $lastUpdate = new DateTime($packageInfo['time']);
    $sixMonthsAgo = new DateTime('-6 months');
    
    expect($lastUpdate)->toBeGreaterThan($sixMonthsAgo);
})->with([
    'pestphp/pest',
    'pestphp/pest-plugin-laravel',
    'mockery/mockery',
]);
```

### Testing Package Compatibility
```php
test('pest plugins are compatible', function () {
    $installedPlugins = json_decode(
        shell_exec('composer show --format=json | grep pest-plugin'),
        true
    );
    
    foreach ($installedPlugins as $plugin) {
        // Check Pest version compatibility
        $requires = $plugin['requires'] ?? [];
        if (isset($requires['pestphp/pest'])) {
            $requiredVersion = $requires['pestphp/pest'];
            $currentVersion = \Composer\InstalledVersions::getVersion('pestphp/pest');
            
            expect(version_compare($currentVersion, $requiredVersion, '>='))
                ->toBeTrue("{$plugin['name']} requires Pest {$requiredVersion}");
        }
    }
});
```

## Version Management

### Composer Configuration
```json
{
    "require-dev": {
        "pestphp/pest": "^4.0",
        "pestphp/pest-plugin-laravel": "^4.0",
        "pestphp/pest-plugin-browser": "^4.0",
        "pestphp/pest-plugin-arch": "^4.0",
        "pestphp/pest-plugin-mutate": "^4.0",
        "pestphp/pest-plugin-watch": "^4.0",
        "mockery/mockery": "^1.6",
        "fakerphp/faker": "^1.23"
    },
    "config": {
        "allow-plugins": {
            "pestphp/pest-plugin": true
        },
        "optimize-autoloader": true,
        "preferred-install": "dist",
        "sort-packages": true
    },
    "scripts": {
        "test": "pest",
        "test:unit": "pest --group=unit",
        "test:feature": "pest --group=feature",
        "test:coverage": "pest --coverage",
        "test:mutate": "pest --mutate",
        "test:arch": "pest tests/Architecture"
    }
}
```

### Version Constraints Best Practices
```php
test('dependencies use appropriate version constraints', function () {
    $composer = json_decode(file_get_contents('composer.json'), true);
    $devDependencies = $composer['require-dev'] ?? [];
    
    foreach ($devDependencies as $package => $version) {
        // Check for exact version locks (not recommended)
        expect($version)->not->toMatch('/^\d+\.\d+\.\d+$/');
        
        // Prefer caret or tilde operators
        expect($version)->toMatch('/^[\^~]/');
    }
});
```

### Lock File Management
```bash
#!/bin/bash
# scripts/check-composer-lock.sh

# Ensure lock file is up to date
composer validate --no-check-all --no-check-publish

# Check for outdated packages
composer outdated --direct

# Verify lock file matches composer.json
if ! composer install --dry-run 2>&1 | grep -q "Nothing to install"; then
    echo "composer.lock is out of sync with composer.json"
    exit 1
fi
```

## Security Auditing

### Automated Security Checks
```php
test('no known security vulnerabilities', function () {
    $audit = shell_exec('composer audit --format=json');
    $results = json_decode($audit, true);
    
    expect($results['advisories'])->toBeEmpty(
        'Security vulnerabilities found: ' . json_encode($results['advisories'])
    );
});

test('dependencies are from trusted sources', function () {
    $packages = json_decode(
        shell_exec('composer show --format=json'),
        true
    );
    
    $trustedVendors = [
        'pestphp',
        'laravel',
        'symfony',
        'illuminate',
        'mockery',
        'phpunit',
    ];
    
    foreach ($packages['installed'] as $package) {
        $vendor = explode('/', $package['name'])[0];
        
        if (!in_array($vendor, $trustedVendors)) {
            // Additional checks for unknown vendors
            expect($package['downloads'])->toBeGreaterThan(10000)
                ->and($package['favers'])->toBeGreaterThan(100);
        }
    }
});
```

### License Compliance
```php
test('all dependencies have compatible licenses', function () {
    $allowedLicenses = [
        'MIT',
        'BSD-3-Clause',
        'BSD-2-Clause',
        'Apache-2.0',
        'ISC',
    ];
    
    $packages = json_decode(
        shell_exec('composer licenses --format=json'),
        true
    );
    
    foreach ($packages['dependencies'] as $package => $info) {
        $licenses = (array) $info['license'];
        
        foreach ($licenses as $license) {
            expect($license)->toBeIn($allowedLicenses,
                "{$package} has incompatible license: {$license}"
            );
        }
    }
});
```

## Bundle Size Optimization

### Analyzing Test Dependencies
```php
test('development dependencies size is reasonable', function () {
    $vendorSize = 0;
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator('vendor')
    );
    
    foreach ($iterator as $file) {
        if ($file->isFile()) {
            $vendorSize += $file->getSize();
        }
    }
    
    $sizeMB = $vendorSize / 1024 / 1024;
    
    expect($sizeMB)->toBeLessThan(100); // Less than 100MB
});

test('no production code depends on test packages', function () {
    $productionFiles = glob('app/**/*.php');
    $testPackages = ['pest', 'mockery', 'faker'];
    
    foreach ($productionFiles as $file) {
        $content = file_get_contents($file);
        
        foreach ($testPackages as $package) {
            expect($content)->not->toContain("use {$package}\\")
                ->and($content)->not->toContain("use Pest\\");
        }
    }
});
```

### Autoload Optimization
```json
{
    "autoload-dev": {
        "psr-4": {
            "Tests\\": "tests/",
            "Tests\\Unit\\": "tests/Unit/",
            "Tests\\Feature\\": "tests/Feature/"
        },
        "files": [
            "tests/Helpers/functions.php"
        ]
    },
    "scripts": {
        "post-autoload-dump": [
            "@php artisan package:discover --ansi",
            "@php artisan vendor:publish --tag=pest-stubs"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=pest-config"
        ]
    }
}
```

## Update Strategies

### Controlled Updates
```php
// tests/Dependencies/UpdateTest.php
test('pest update does not break existing tests', function () {
    // Run tests before update
    $beforeUpdate = shell_exec('./vendor/bin/pest --compact');
    expect($beforeUpdate)->toContain('PASS');
    
    // Simulate update (in CI only)
    if (env('CI')) {
        shell_exec('composer update pestphp/pest --with-dependencies');
        
        // Run tests after update
        $afterUpdate = shell_exec('./vendor/bin/pest --compact');
        expect($afterUpdate)->toContain('PASS');
    }
})->skip(!env('CI'), 'Only run in CI');
```

### Gradual Migration Strategy
```bash
#!/bin/bash
# scripts/update-pest.sh

echo "🔄 Updating Pest Framework"

# Backup current state
cp composer.lock composer.lock.backup

# Update Pest core first
composer update pestphp/pest --with-dependencies

# Run tests
if ! ./vendor/bin/pest; then
    echo "❌ Tests failed after updating Pest core"
    mv composer.lock.backup composer.lock
    composer install
    exit 1
fi

# Update plugins one by one
plugins=("pest-plugin-laravel" "pest-plugin-arch" "pest-plugin-browser")

for plugin in "${plugins[@]}"; do
    echo "Updating $plugin..."
    composer update "pestphp/$plugin"
    
    if ! ./vendor/bin/pest; then
        echo "❌ Tests failed after updating $plugin"
        mv composer.lock.backup composer.lock
        composer install
        exit 1
    fi
done

echo "✅ All Pest packages updated successfully"
rm composer.lock.backup
```

## Dependency Isolation

### Mocking External Dependencies
```php
test('isolates external package behavior', function () {
    // Mock external package
    $mock = Mockery::mock('overload:ExternalPackage\Client');
    $mock->shouldReceive('connect')->once()->andReturn(true);
    $mock->shouldReceive('getData')->once()->andReturn(['data' => 'test']);
    
    // Test your code that uses the package
    $service = new ServiceUsingExternalPackage();
    $result = $service->process();
    
    expect($result)->toBe(['data' => 'test']);
});
```

### Container Swapping
```php
test('swaps implementations for testing', function () {
    // Swap implementation in container
    $this->app->bind(PaymentGatewayInterface::class, function () {
        return new FakePaymentGateway();
    });
    
    // Test with fake implementation
    $payment = app(PaymentService::class);
    $result = $payment->charge(100);
    
    expect($result)->toBeTrue();
});
```

## Plugin Management

### Installing Pest Plugins
```bash
# Core plugins
composer require --dev pestphp/pest-plugin-laravel
composer require --dev pestphp/pest-plugin-arch
composer require --dev pestphp/pest-plugin-browser
composer require --dev pestphp/pest-plugin-mutate
composer require --dev pestphp/pest-plugin-watch

# Community plugins
composer require --dev pestphp/pest-plugin-snapshot
composer require --dev pestphp/pest-plugin-parallel
```

### Plugin Configuration
```php
// pest.php
use Pest\Plugin;

// Configure plugins
Plugin::uses(LaravelPlugin::class);
Plugin::uses(ArchPlugin::class);
Plugin::uses(BrowserPlugin::class);

// Plugin-specific configuration
ArchPlugin::configure()
    ->preset('strict')
    ->ignore('tests');

BrowserPlugin::configure()
    ->headless(env('CI', false))
    ->timeout(30);
```

## Troubleshooting Dependencies

### Conflict Resolution
```php
test('no dependency conflicts', function () {
    $output = shell_exec('composer diagnose 2>&1');
    
    expect($output)->not->toContain('conflict')
        ->and($output)->not->toContain('problem')
        ->and($output)->toContain('OK');
});
```

### Debugging Autoload Issues
```php
test('autoload files are generated correctly', function () {
    // Regenerate autoload
    shell_exec('composer dump-autoload');
    
    // Check critical files exist
    $autoloadFiles = [
        'vendor/autoload.php',
        'vendor/composer/autoload_psr4.php',
        'vendor/composer/autoload_classmap.php',
    ];
    
    foreach ($autoloadFiles as $file) {
        expect(file_exists($file))->toBeTrue();
    }
    
    // Verify Pest helpers are loaded
    expect(function_exists('test'))->toBeTrue()
        ->and(function_exists('expect'))->toBeTrue()
        ->and(function_exists('it'))->toBeTrue();
});
```

## Dependency Documentation

### Maintaining Package List
```php
// tests/Documentation/DependencyListTest.php
test('README contains all test dependencies', function () {
    $composer = json_decode(file_get_contents('composer.json'), true);
    $readme = file_get_contents('README.md');
    
    foreach ($composer['require-dev'] as $package => $version) {
        expect($readme)->toContain($package,
            "README should document {$package}"
        );
    }
});
```

### Version History Tracking
```bash
#!/bin/bash
# scripts/track-dependency-updates.sh

# Generate dependency update log
echo "# Dependency Update History" > DEPENDENCIES.md
echo "" >> DEPENDENCIES.md
echo "## $(date '+%Y-%m-%d')" >> DEPENDENCIES.md
echo "" >> DEPENDENCIES.md

composer show --format=json | jq -r '.installed[] | "- \(.name): \(.version)"' >> DEPENDENCIES.md

git add DEPENDENCIES.md
git commit -m "chore: update dependency tracking"
```