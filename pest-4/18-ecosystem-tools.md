# Ecosystem Tools for Pest

## Development Tools

### IDE Integration

#### PHPStorm/IntelliJ IDEA
```xml
<!-- .idea/pest.xml -->
<pest>
    <option name="pestPath" value="$PROJECT_DIR$/vendor/bin/pest" />
    <option name="configuration" value="$PROJECT_DIR$/phpunit.xml" />
    <option name="coverageEngine" value="PCOV" />
    <option name="runInParallel" value="true" />
</pest>
```

```php
// Live Templates for PHPStorm
// test - Pest test template
test('$NAME$', function () {
    $END$
});

// exp - Expectation template
expect($VAR$)->$END$;

// desc - Describe block template
describe('$NAME$', function () {
    $END$
});
```

#### Visual Studio Code
```json
// .vscode/settings.json
{
    "pestphp.enable": true,
    "pestphp.executable": "./vendor/bin/pest",
    "pestphp.args": ["--colors"],
    "pestphp.parallel": true,
    "editor.quickSuggestions": {
        "comments": false,
        "strings": false,
        "other": true
    },
    "php.suggest.basic": false
}

// .vscode/tasks.json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run Pest Tests",
            "type": "shell",
            "command": "./vendor/bin/pest",
            "group": {
                "kind": "test",
                "isDefault": true
            }
        },
        {
            "label": "Run Pest with Coverage",
            "type": "shell",
            "command": "./vendor/bin/pest --coverage"
        }
    ]
}
```

### Command Line Tools

#### Pest Watch Mode
```bash
# Install watch plugin
composer require pestphp/pest-plugin-watch --dev

# Run in watch mode
./vendor/bin/pest --watch

# Watch specific directories
./vendor/bin/pest --watch=app,tests

# Watch with notifications
./vendor/bin/pest --watch --notify
```

#### Custom Pest Commands
```php
// app/Console/Commands/PestCommand.php
class PestCommand extends Command
{
    protected $signature = 'test:pest
        {--unit : Run only unit tests}
        {--feature : Run only feature tests}
        {--coverage : Generate coverage report}
        {--parallel : Run in parallel}';
    
    public function handle(): int
    {
        $command = ['./vendor/bin/pest'];
        
        if ($this->option('unit')) {
            $command[] = 'tests/Unit';
        }
        
        if ($this->option('feature')) {
            $command[] = 'tests/Feature';
        }
        
        if ($this->option('coverage')) {
            $command[] = '--coverage';
        }
        
        if ($this->option('parallel')) {
            $command[] = '--parallel';
        }
        
        $process = Process::fromShellCommandline(implode(' ', $command));
        $process->setTty(true);
        
        return $process->run();
    }
}
```

## Build Tools

### Laravel Mix Integration
```javascript
// webpack.mix.js
const mix = require('laravel-mix');

mix.extend('pest', {
    register() {
        Mix.addTask('pest', () => {
            const { execSync } = require('child_process');
            execSync('./vendor/bin/pest', { stdio: 'inherit' });
        });
    }
});

// Run with: npm run pest
```

### Vite Integration
```javascript
// vite.config.js
import { defineConfig } from 'vite';

export default defineConfig({
    plugins: [
        {
            name: 'run-pest-tests',
            handleHotUpdate({ file }) {
                if (file.endsWith('.php')) {
                    const { exec } = require('child_process');
                    exec('./vendor/bin/pest --filter=' + file);
                }
            }
        }
    ]
});
```

### Docker Integration
```dockerfile
# Dockerfile.pest
FROM php:8.2-cli

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    && docker-php-ext-install zip

# Install PCOV for coverage
RUN pecl install pcov && docker-php-ext-enable pcov

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader

COPY . .
RUN composer dump-autoload

CMD ["./vendor/bin/pest"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  pest:
    build:
      context: .
      dockerfile: Dockerfile.pest
    volumes:
      - .:/app
    command: ./vendor/bin/pest --watch
```

## Testing Frameworks Integration

### Playwright Integration
```php
// Install
// composer require pestphp/pest-plugin-browser --dev

// Usage
test('browser automation with Playwright', function () {
    visit('https://example.com')
        ->screenshot('homepage')
        ->click('text=Login')
        ->type('#email', 'user@example.com')
        ->type('#password', 'password')
        ->press('Submit')
        ->waitForUrl('**/dashboard')
        ->assertSee('Welcome');
});
```

### Cypress Alternative
```javascript
// cypress/integration/pest-comparison.spec.js
describe('Pest equivalent in Cypress', () => {
    it('performs the same test', () => {
        cy.visit('/');
        cy.contains('Welcome');
        cy.get('[data-test=login]').click();
    });
});

// Pest equivalent
test('performs the same test', function () {
    visit('/')
        ->assertSee('Welcome')
        ->click('[data-test=login]');
});
```

### Codeception Comparison
```php
// Codeception style
$I->amOnPage('/');
$I->see('Welcome');
$I->click('Login');

// Pest equivalent
test('same test in Pest', function () {
    $this->get('/')
        ->assertSee('Welcome');
    
    $this->followingRedirects()
        ->click('Login');
});
```

## State Management Libraries

### Laravel Factories Extension
```php
// Custom factory states for testing
User::factory()->state(function () {
    return [
        'test_mode' => true,
        'created_at' => now()->subDays(rand(1, 365)),
    ];
})->create();

// Pest helper for common factory patterns
function createTestUser(array $attributes = []): User
{
    return User::factory()
        ->has(Profile::factory())
        ->has(Settings::factory())
        ->create($attributes);
}
```

### Database Seeders for Tests
```php
// tests/Seeders/TestSeeder.php
class TestSeeder extends Seeder
{
    public function run(): void
    {
        User::factory()->count(10)->create();
        Product::factory()->count(50)->create();
        Order::factory()->count(100)->create();
    }
}

// Usage in Pest
beforeEach(function () {
    $this->seed(TestSeeder::class);
});
```

## Essential Packages

### Core Testing Packages
```json
{
    "require-dev": {
        "pestphp/pest": "^4.0",
        "pestphp/pest-plugin-laravel": "^4.0",
        "pestphp/pest-plugin-arch": "^4.0",
        "pestphp/pest-plugin-browser": "^4.0",
        "pestphp/pest-plugin-mutate": "^4.0",
        "pestphp/pest-plugin-watch": "^4.0",
        "mockery/mockery": "^1.6",
        "fakerphp/faker": "^1.23",
        "spatie/laravel-ray": "^1.33"
    }
}
```

### Utility Packages
```php
// Snapshot Testing
composer require spatie/pest-plugin-snapshots --dev

test('matches snapshot', function () {
    $data = generateComplexData();
    
    expect($data)->toMatchSnapshot();
});

// Test Profiling
composer require pestphp/pest-plugin-profile --dev

test('performance critical operation')
    ->profile()
    ->expect(fn() => expensiveOperation())
    ->toExecuteInLessThan(100); // milliseconds
```

### Assertion Libraries
```php
// Custom assertions package
composer require pestphp/pest-plugin-expectations --dev

// Additional expectations
expect($value)->toBeEmail();
expect($array)->toHaveKeys(['name', 'email']);
expect($string)->toBeJson();
expect($date)->toBeInFuture();
```

## CI/CD Tools

### GitHub Actions
```yaml
# .github/workflows/pest.yml
name: Pest Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        php: [8.2, 8.3]
        pest: [3.*, 4.*]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php }}
          extensions: dom, curl, libxml, mbstring, zip, pcov
          coverage: pcov
      
      - name: Install Pest ${{ matrix.pest }}
        run: |
          composer require "pestphp/pest:${{ matrix.pest }}" --dev
          composer update --prefer-dist --no-progress
      
      - name: Run Pest Tests
        run: ./vendor/bin/pest --parallel --coverage
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```

### GitLab CI
```yaml
# .gitlab-ci.yml
stages:
  - test
  - coverage

pest:test:
  stage: test
  image: php:8.2-cli
  script:
    - composer install
    - ./vendor/bin/pest --parallel
  artifacts:
    reports:
      junit: tests/reports/junit.xml

pest:coverage:
  stage: coverage
  image: php:8.2-cli
  script:
    - pecl install pcov
    - docker-php-ext-enable pcov
    - composer install
    - ./vendor/bin/pest --coverage --min=80
  coverage: '/Total Coverage:\s+(\d+\.\d+)%/'
```

### Jenkins Pipeline
```groovy
// Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Install') {
            steps {
                sh 'composer install'
            }
        }
        
        stage('Test') {
            steps {
                sh './vendor/bin/pest --parallel'
            }
        }
        
        stage('Coverage') {
            steps {
                sh './vendor/bin/pest --coverage --coverage-html=coverage'
                publishHTML([
                    reportDir: 'coverage',
                    reportFiles: 'index.html',
                    reportName: 'Pest Coverage Report'
                ])
            }
        }
    }
    
    post {
        always {
            junit 'tests/reports/*.xml'
        }
    }
}
```

## Debugging Tools

### Ray Integration
```php
// Install
composer require spatie/laravel-ray --dev

// Usage in Pest tests
test('debugging with Ray', function () {
    $user = User::factory()->create();
    
    ray($user)->label('Created user');
    ray()->showQueries();
    
    $user->posts()->create([...]);
    
    ray()->stopShowingQueries();
    ray()->measure(function () {
        // Code to measure
    });
    
    expect($user->posts)->toHaveCount(1);
});
```

### Tinkerwell Integration
```php
// Run Pest tests in Tinkerwell
$result = shell_exec('cd ' . base_path() . ' && ./vendor/bin/pest');
echo $result;

// Test specific files
$result = shell_exec('cd ' . base_path() . ' && ./vendor/bin/pest tests/Unit/UserTest.php');
```

## Documentation Tools

### PHPDocumentor Integration
```php
/**
 * @test
 * @covers \App\Services\UserService
 * @group unit
 */
test('documented test example', function () {
    // Test implementation
});
```

### API Documentation Testing
```php
// Test API documentation accuracy
test('API documentation matches implementation', function () {
    $docs = json_decode(file_get_contents('docs/api.json'), true);
    
    foreach ($docs['endpoints'] as $endpoint) {
        $response = $this->json(
            $endpoint['method'],
            $endpoint['path'],
            $endpoint['example_request'] ?? []
        );
        
        expect($response->status())->toBe($endpoint['expected_status']);
        
        if (isset($endpoint['response_structure'])) {
            $response->assertJsonStructure($endpoint['response_structure']);
        }
    }
});
```

## Monitoring and Reporting

### Test Reporter Integration
```php
// Custom test reporter
class CustomReporter implements Reporter
{
    public function report(TestResult $result): void
    {
        $data = [
            'total' => $result->total(),
            'passed' => $result->passed(),
            'failed' => $result->failed(),
            'skipped' => $result->skipped(),
            'duration' => $result->duration(),
        ];
        
        // Send to monitoring service
        Http::post('https://monitoring.example.com/tests', $data);
    }
}
```

### Allure Reports
```bash
# Install Allure adapter
composer require --dev pestphp/pest-plugin-allure

# Generate Allure report
./vendor/bin/pest --allure

# View report
allure serve tests/allure-results
```