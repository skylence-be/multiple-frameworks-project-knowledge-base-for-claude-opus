# Pest Framework Overview

## Framework Name
Pest PHP Testing Framework v4.x

## Core Philosophy
Pest is designed to bring back the joy of testing in PHP through simplicity, elegance, and developer experience. It emphasizes:
- **Minimal and expressive syntax** - Write less code with more clarity
- **Human-first design** - Tests should read like natural language
- **Beautiful output** - Clear, informative test results with excellent error reporting
- **Progressive enhancement** - Built on PHPUnit but adds modern testing features
- **Zero configuration** - Works out of the box with sensible defaults

## Mental Model
When working with Pest, developers should think in terms of:
- **Functional testing style** - Tests are functions, not classes
- **Behavior-driven development** - Tests describe what the code should do
- **Expectation-based assertions** - Chain expectations for fluent testing
- **Modular test organization** - Group related tests with describe blocks
- **Test isolation** - Each test runs in isolation with clean state

## Architecture Overview

### Core Components
- **Test Runner**: Built on top of PHPUnit 12, inheriting its robustness
- **Expectation API**: Fluent assertion library inspired by Jest
- **Plugin System**: Extensible architecture for adding functionality
- **Configuration Layer**: Pest.php file for suite-wide configuration
- **Browser Testing**: Integrated Playwright support for end-to-end testing
- **Architecture Testing**: Built-in support for testing code structure

### Request Lifecycle
1. **Initialization**: Pest loads configuration from Pest.php
2. **Discovery**: Test files are discovered based on naming conventions
3. **Setup**: BeforeAll and BeforeEach hooks are executed
4. **Execution**: Tests run in isolation with fresh application state
5. **Assertions**: Expectations are evaluated
6. **Teardown**: AfterEach and AfterAll hooks clean up
7. **Reporting**: Results are formatted and displayed

### Data Flow
```
Test Files → Pest Runner → PHPUnit Core → Test Execution → Results → Output Formatter
     ↑                                            ↓
     └──────────── Hooks & Configuration ←────────┘
```

### Key Abstractions
- **test()/it()**: Define individual test cases
- **expect()**: Create chainable expectations
- **describe()**: Group related tests
- **dataset()**: Provide test data for parameterized testing
- **uses()**: Apply traits and base classes to tests
- **covers()/mutates()**: Specify code coverage targets

## Key Concepts

### 1. Functional Testing Style
Tests are written as functions rather than methods in classes, reducing boilerplate and improving readability.

### 2. Expectation API
A fluent interface for assertions that reads like natural language:
```php
expect($value)->toBe(5)->toBeInt()->toBeGreaterThan(0);
```

### 3. Higher-Order Tests
Chain test configuration using fluent methods:
```php
test('example')->skip()->group('slow')->depends('setup');
```

### 4. Datasets
Parameterized testing with named datasets:
```php
test('math operations', function ($a, $b, $result) {
    expect($a + $b)->toBe($result);
})->with('addition');
```

### 5. Architecture Testing
Test your application's structure and dependencies:
```php
arch('models')->expect('App\Models')->toBeClasses()->toExtend(Model::class);
```

### 6. Browser Testing (v4+)
Native browser testing with Playwright integration:
```php
test('user can login', function () {
    visit('/login')
        ->type('email', 'user@example.com')
        ->press('Login')
        ->assertSee('Dashboard');
});
```

## Framework Strengths
- **Developer Experience**: Minimal syntax with maximum expressiveness
- **Fast Execution**: Parallel testing support out of the box
- **Great Error Messages**: Clear, actionable failure messages with code snippets
- **PHPUnit Compatibility**: Run existing PHPUnit tests without modification
- **Rich Plugin Ecosystem**: Extensive plugins for various testing needs
- **Modern Features**: Coverage reports, profiling, watch mode, mutations
- **Laravel Integration**: First-class support for Laravel applications
- **Type Coverage**: Built-in type coverage analysis

## Framework Limitations
- **PHP Version Requirement**: Requires PHP 8.2 or higher
- **Learning Curve**: Different mental model from traditional PHPUnit
- **IDE Support**: Some IDEs have limited support for Pest's syntax
- **Debugging**: Stack traces can be more complex due to functional style
- **Enterprise Features**: Less mature than PHPUnit for enterprise needs
- **Documentation Gaps**: Some advanced features have limited documentation

## Comparison with Alternatives

| Feature | Pest | PHPUnit | Codeception | Behat |
|---------|------|---------|-------------|--------|
| **Syntax** | Functional/Fluent | Object-Oriented | Mixed | Gherkin |
| **Learning Curve** | Low | Medium | High | Medium |
| **Setup Required** | Minimal | Moderate | Extensive | Moderate |
| **Performance** | Fast (parallel) | Fast | Moderate | Slow |
| **Browser Testing** | Native (v4+) | Via plugins | Native | Via plugins |
| **Architecture Testing** | Native | No | No | No |
| **Laravel Support** | Excellent | Good | Good | Limited |
| **Community Size** | Growing | Large | Medium | Medium |
| **Enterprise Ready** | Good | Excellent | Good | Good |
| **Error Messages** | Excellent | Good | Good | Fair |

## Version History & Breaking Changes

### v4.0 (2024)
- Browser testing with Playwright
- Test sharding for CI/CD
- Profanity checking
- PHPUnit 12 compatibility
- Breaking: Removed support for PHP 8.1

### v3.0 (2024)
- Type coverage analysis
- Mutation testing
- Task management
- Breaking: New configuration format

### v2.0 (2023)
- Architecture testing
- Parallel testing
- Stress testing
- Breaking: PHPUnit 10 requirement

### v1.0 (2021)
- Initial stable release
- Expectation API
- Plugin system
- Laravel integration

## Core Dependencies
- **PHPUnit 12.x**: Core testing engine
- **PHP 8.2+**: Runtime requirement
- **Composer**: Package management
- **Optional**:
  - Laravel Framework (for Laravel testing)
  - Playwright (for browser testing)
  - Xdebug/PCOV (for coverage reports)

## Development vs Production Differences
- **Development**: Full error traces, verbose output, watch mode available
- **Production/CI**: Compact output, parallel execution, coverage reports
- **Configuration**: Environment-specific settings via phpunit.xml
- **Performance**: Development focuses on DX, CI on speed
- **Debugging**: Development has better debugging tools integration