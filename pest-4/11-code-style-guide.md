# Pest Code Style Guide

## Formatting Standards

### Indentation and Spacing
```php
// Use 4 spaces for indentation (no tabs)
test('example test', function () {
    $user = User::factory()->create();
    
    expect($user)->toBeInstanceOf(User::class);
});

// Empty lines between test functions
test('first test', function () {
    // Test body
});

test('second test', function () {
    // Test body
});

// Group related assertions
test('user properties', function () {
    $user = User::factory()->create([
        'name' => 'John Doe',
        'email' => 'john@example.com',
    ]);
    
    expect($user->name)->toBe('John Doe')
        ->and($user->email)->toBe('john@example.com')
        ->and($user->created_at)->toBeInstanceOf(Carbon::class);
});
```

### Line Length
```php
// Keep lines under 120 characters
test('very long test name that describes what this test is checking should be split', 
    function () {
        // Test implementation
    }
);

// Break long method chains
expect($response)
    ->status()->toBe(200)
    ->json('data.user.name')->toBe('John')
    ->json('data.user.email')->toBe('john@example.com')
    ->json('data.user.roles')->toBeArray()
    ->json('data.user.roles.0')->toBe('admin');
```

### Brackets and Braces
```php
// Opening brace on same line for closures
test('example', function () {
    // Implementation
});

// Multi-line arrays with trailing comma
$data = [
    'name' => 'John',
    'email' => 'john@example.com',
    'role' => 'admin',
];

// Single-line arrays for simple data
$ids = [1, 2, 3, 4, 5];
```

## Code Structure Patterns

### Test Function Structure
```php
test('complete test structure example', function () {
    // Arrange
    $user = User::factory()->create();
    $product = Product::factory()->create(['price' => 100]);
    
    // Act
    $order = OrderService::create($user, $product);
    
    // Assert
    expect($order)->not->toBeNull()
        ->and($order->user_id)->toBe($user->id)
        ->and($order->total)->toBe(100);
})->group('orders', 'services');
```

### Describe Blocks
```php
describe('UserService', function () {
    beforeEach(function () {
        $this->service = new UserService();
    });
    
    describe('createUser', function () {
        it('creates a user with valid data', function () {
            $user = $this->service->createUser([
                'name' => 'John Doe',
                'email' => 'john@example.com',
            ]);
            
            expect($user)->toBeInstanceOf(User::class);
        });
        
        it('throws exception with invalid data', function () {
            expect(fn() => $this->service->createUser([]))
                ->toThrow(ValidationException::class);
        });
    });
});
```

### Higher Order Tests
```php
// Chain configuration methods
test('admin features')
    ->group('admin', 'auth')
    ->with('admin_users')
    ->skip('Under development')
    ->throwsIf(true, Exception::class);

// Use todo for planned tests
todo('implement payment refund functionality');
```

## Comment Guidelines

### Test Documentation
```php
/**
 * Test that verifies the complete checkout process including
 * inventory updates, payment processing, and email notifications.
 * 
 * @group e-commerce
 * @group critical
 */
test('complete checkout process with notifications', function () {
    // Implementation
});

// Inline comments for complex logic
test('complex calculation', function () {
    // Set up initial state with special conditions
    $order = Order::factory()->create(['status' => 'pending']);
    
    // Apply multiple discounts in specific order
    // Note: Order matters due to compound discount rules
    $order->applyDiscount('SUMMER20'); // 20% off
    $order->applyDiscount('LOYAL10');  // Additional 10% for loyalty
    
    expect($order->final_price)->toBe(72); // 100 * 0.8 * 0.9
});
```

### Section Comments
```php
test('user registration', function () {
    // === Arrange ===
    $userData = ['name' => 'John', 'email' => 'john@example.com'];
    
    // === Act ===
    $response = $this->post('/register', $userData);
    
    // === Assert ===
    expect($response->status())->toBe(201);
});
```

## Import Organization

### Order of Imports
```php
<?php

// 1. Declare statements
declare(strict_types=1);

// 2. Namespace
namespace Tests\Feature;

// 3. PHP built-in classes
use DateTime;
use Exception;

// 4. Framework classes
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;

// 5. Application classes
use App\Models\User;
use App\Services\UserService;

// 6. Test-specific imports
use Tests\TestCase;
use Tests\Traits\CreatesUsers;

// 7. Uses statements
uses(RefreshDatabase::class);
uses(CreatesUsers::class);
```

## Consistency Rules

### Expectation Syntax
```php
// ✅ Consistent use of expect API
expect($value)->toBe(5);
expect($array)->toHaveCount(3);
expect($string)->toContain('test');

// ❌ Avoid mixing assertion styles in same file
$this->assertEquals(5, $value);  // Don't mix with expect
$this->assertCount(3, $array);   // Use expect instead
```

### Dataset Usage
```php
// Define datasets consistently
dataset('users', [
    'admin' => [['role' => 'admin']],
    'editor' => [['role' => 'editor']],
    'viewer' => [['role' => 'viewer']],
]);

// Use datasets consistently
test('user permissions', function ($userData) {
    // Test implementation
})->with('users');
```

### Mock Style
```php
// Consistent mocking approach
beforeEach(function () {
    $this->mockPaymentGateway = Mockery::mock(PaymentGateway::class);
    $this->app->instance(PaymentGateway::class, $this->mockPaymentGateway);
});

test('payment processing', function () {
    $this->mockPaymentGateway
        ->shouldReceive('charge')
        ->once()
        ->with(100.00)
        ->andReturn(true);
    
    // Test implementation
});
```

## Test Organization

### Logical Grouping
```php
// Group related tests together
describe('Authentication', function () {
    test('user can login with valid credentials', function () {
        // Implementation
    });
    
    test('user cannot login with invalid credentials', function () {
        // Implementation
    });
    
    test('user can logout', function () {
        // Implementation
    });
});

// Or use consistent prefixes
test('auth: user can login', function () {});
test('auth: user can logout', function () {});
test('auth: password reset works', function () {});
```

### Test Order
```php
// Order tests from simple to complex
describe('OrderCalculator', function () {
    // 1. Basic functionality
    test('calculates subtotal', function () {});
    
    // 2. With one modifier
    test('applies single discount', function () {});
    
    // 3. Complex scenarios
    test('handles multiple discounts and tax', function () {});
    
    // 4. Edge cases
    test('handles empty order', function () {});
    test('handles negative quantities gracefully', function () {});
});
```

## Assertion Patterns

### Fluent Assertions
```php
// Chain related assertions
expect($user)
    ->toBeInstanceOf(User::class)
    ->name->toBe('John Doe')
    ->email->toContain('@')
    ->created_at->toBeInstanceOf(DateTime::class);

// Group assertions with 'and'
expect($response->status())->toBe(200)
    ->and($response->json('success'))->toBeTrue()
    ->and($response->json('data'))->toBeArray();
```

### Custom Expectations
```php
// Define in Pest.php
expect()->extend('toBeValidEmail', function () {
    return $this->toMatch('/^[^\s@]+@[^\s@]+\.[^\s@]+$/');
});

expect()->extend('toBeWithinRange', function ($min, $max) {
    return $this->toBeGreaterThanOrEqual($min)
        ->toBeLessThanOrEqual($max);
});

// Use in tests
test('email validation', function () {
    expect('user@example.com')->toBeValidEmail();
    expect(rand(5, 15))->toBeWithinRange(0, 20);
});
```

## Error Handling Style

### Exception Testing
```php
// Expect closure for exceptions
test('throws exception for invalid input', function () {
    expect(fn() => divide(10, 0))
        ->toThrow(DivisionByZeroException::class)
        ->toThrow('Cannot divide by zero');
});

// Test multiple exception properties
test('validates exception details', function () {
    try {
        processPayment(-100);
    } catch (InvalidAmountException $e) {
        expect($e->getMessage())->toContain('negative')
            ->and($e->getCode())->toBe(422)
            ->and($e->getAmount())->toBe(-100);
    }
});
```

## Database Testing Style

### Factory Usage
```php
// Consistent factory usage
test('user relationships', function () {
    $user = User::factory()
        ->has(Post::factory()->count(3))
        ->has(Comment::factory()->count(5))
        ->create();
    
    expect($user->posts)->toHaveCount(3)
        ->and($user->comments)->toHaveCount(5);
});

// Use states consistently
$admin = User::factory()->admin()->create();
$subscriber = User::factory()->subscriber()->withTrial()->create();
```

### Database Assertions
```php
test('creates user in database', function () {
    $response = $this->post('/users', [
        'name' => 'John Doe',
        'email' => 'john@example.com',
    ]);
    
    expect($response->status())->toBe(201);
    
    $this->assertDatabaseHas('users', [
        'email' => 'john@example.com',
    ]);
    
    $this->assertDatabaseCount('users', 1);
});
```

## HTTP Testing Style

### Request Formatting
```php
test('API endpoint', function () {
    $response = $this->postJson('/api/users', [
        'name' => 'John Doe',
        'email' => 'john@example.com',
        'role' => 'admin',
    ]);
    
    expect($response)
        ->status()->toBe(201)
        ->json('data.name')->toBe('John Doe')
        ->json('data.email')->toBe('john@example.com');
});

// Use descriptive variable names for responses
test('multiple requests', function () {
    $createResponse = $this->post('/users', [...]);
    $getResponse = $this->get('/users/1');
    $updateResponse = $this->put('/users/1', [...]);
    
    expect($createResponse->status())->toBe(201)
        ->and($getResponse->status())->toBe(200)
        ->and($updateResponse->status())->toBe(200);
});
```

## Style Guide Checklist

### ✅ Do's
- Use consistent indentation (4 spaces)
- Keep test names descriptive and readable
- Group related assertions
- Use empty lines to separate sections
- Follow PSR-12 standards
- Use trailing commas in multi-line arrays
- Comment complex test logic
- Organize imports logically

### ❌ Don'ts
- Don't use tabs for indentation
- Don't exceed 120 characters per line
- Don't mix assertion styles
- Don't use inconsistent naming
- Don't leave commented-out code
- Don't use magic numbers without context
- Don't skip proper formatting
- Don't ignore IDE warnings

## Editor Configuration

### .editorconfig
```ini
[*.php]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
max_line_length = 120

[{Pest,pest}.php]
indent_size = 4
```

### Prettier/PHP-CS-Fixer
```json
{
    "printWidth": 120,
    "tabWidth": 4,
    "useTabs": false,
    "singleQuote": true,
    "trailingComma": "all",
    "bracketSpacing": true,
    "arrowParens": "always"
}
```