# Error Handling in Pest

## Error Handling Strategies

### Defensive Testing
```php
test('handles all error scenarios', function () {
    // Test happy path
    $result = divide(10, 2);
    expect($result)->toBe(5);
    
    // Test error conditions
    expect(fn() => divide(10, 0))->toThrow(DivisionByZeroError::class);
    expect(fn() => divide('ten', 2))->toThrow(TypeError::class);
    expect(fn() => divide(null, 2))->toThrow(TypeError::class);
    expect(fn() => divide(10, null))->toThrow(TypeError::class);
});

test('validates input comprehensively', function ($input, $expectation) {
    if ($expectation instanceof Exception) {
        expect(fn() => processInput($input))->toThrow($expectation::class);
    } else {
        expect(processInput($input))->toBe($expectation);
    }
})->with([
    'valid input' => ['valid', 'processed'],
    'empty string' => ['', new InvalidArgumentException()],
    'null value' => [null, new TypeError()],
    'array input' => [[], new TypeError()],
    'too long' => [str_repeat('a', 1001), new LengthException()],
]);
```

### Try-Catch Patterns
```php
test('handles exceptions gracefully', function () {
    try {
        $result = riskyOperation();
        expect($result)->not->toBeNull();
    } catch (SpecificException $e) {
        // Expected exception
        expect($e->getCode())->toBe(422);
        expect($e->getMessage())->toContain('validation');
    } catch (Exception $e) {
        // Unexpected exception
        $this->fail('Unexpected exception: ' . $e->getMessage());
    } finally {
        // Cleanup
        cleanupResources();
    }
});
```

## Custom Error Classes

### Creating Test-Specific Exceptions
```php
// tests/Exceptions/TestException.php
class TestException extends Exception
{
    public function __construct(
        string $message = '',
        public readonly array $context = [],
        int $code = 0,
        ?Throwable $previous = null
    ) {
        parent::__construct($message, $code, $previous);
    }
    
    public function getContext(): array
    {
        return $this->context;
    }
}

// Usage in tests
test('custom exception handling', function () {
    $exception = new TestException('Test failed', ['user_id' => 1]);
    
    expect($exception)
        ->toBeInstanceOf(TestException::class)
        ->getMessage()->toBe('Test failed')
        ->getContext()->toBe(['user_id' => 1]);
});
```

### Domain-Specific Exceptions
```php
class ValidationException extends Exception
{
    public function __construct(
        private array $errors = [],
        string $message = 'Validation failed',
        int $code = 422
    ) {
        parent::__construct($message, $code);
    }
    
    public function getErrors(): array
    {
        return $this->errors;
    }
    
    public function hasError(string $field): bool
    {
        return isset($this->errors[$field]);
    }
}

test('validation exception handling', function () {
    try {
        validateUserInput([
            'email' => 'invalid',
            'age' => -5,
        ]);
    } catch (ValidationException $e) {
        expect($e->getCode())->toBe(422)
            ->and($e->hasError('email'))->toBeTrue()
            ->and($e->hasError('age'))->toBeTrue()
            ->and($e->getErrors())->toHaveKeys(['email', 'age']);
    }
});
```

## Async Error Handling

### Promise Error Handling
```php
test('handles async errors', function () {
    $promise = asyncOperation()
        ->then(function ($result) {
            expect($result)->not->toBeNull();
            return $result;
        })
        ->catch(function ($error) {
            expect($error)->toBeInstanceOf(AsyncException::class);
            throw $error; // Re-throw if needed
        })
        ->finally(function () {
            // Cleanup
            closeConnections();
        });
    
    // Wait for promise resolution
    try {
        $result = $promise->wait();
    } catch (AsyncException $e) {
        // Handle expected async error
        expect($e->getMessage())->toContain('timeout');
    }
});
```

### Queue Job Error Handling
```php
test('job handles failures correctly', function () {
    Queue::fake();
    
    // Job that will fail
    $job = new ProcessPaymentJob(Order::factory()->create());
    
    // Simulate failure
    try {
        $job->handle();
    } catch (PaymentException $e) {
        // Job should handle failure
        expect($job->failed($e))->toBeNull();
        
        // Check if job was released back to queue
        Queue::assertPushed(ProcessPaymentJob::class);
        
        // Check if notification was sent
        Notification::assertSentTo(
            $job->order->user,
            PaymentFailedNotification::class
        );
    }
});
```

## Error Boundaries

### Component Error Boundaries
```php
test('component handles errors gracefully', function () {
    $component = new ErrorProneComponent();
    
    // Set up error boundary
    $errorBoundary = new ComponentErrorBoundary($component);
    
    try {
        $result = $errorBoundary->execute(function () use ($component) {
            return $component->riskyMethod();
        });
        
        expect($result)->not->toBeNull();
    } catch (ComponentException $e) {
        // Error boundary should catch and transform errors
        expect($e->getComponent())->toBe($component::class)
            ->and($e->getOriginalError())->toBeInstanceOf(Exception::class);
    }
});
```

### API Error Boundaries
```php
test('API endpoint handles all errors', function () {
    // Test various error scenarios
    $scenarios = [
        'validation' => [
            'payload' => ['invalid' => 'data'],
            'expectedStatus' => 422,
            'expectedMessage' => 'validation',
        ],
        'not found' => [
            'payload' => ['id' => 999999],
            'expectedStatus' => 404,
            'expectedMessage' => 'not found',
        ],
        'server error' => [
            'payload' => ['trigger_error' => true],
            'expectedStatus' => 500,
            'expectedMessage' => 'server error',
        ],
    ];
    
    foreach ($scenarios as $scenario => $config) {
        $response = $this->postJson('/api/endpoint', $config['payload']);
        
        expect($response->status())->toBe($config['expectedStatus'])
            ->and($response->json('message'))->toContain($config['expectedMessage'])
            ->and($response->json('error'))->not->toContain('Exception') // No stack traces
            ->and($response->json('error'))->not->toContain('.php'); // No file paths
    }
});
```

## Recovery Strategies

### Retry Mechanisms
```php
class RetryableOperation
{
    public static function execute(
        Closure $operation,
        int $maxAttempts = 3,
        int $delayMs = 100,
        array $retryOn = [NetworkException::class]
    ): mixed {
        $attempt = 0;
        $lastException = null;
        
        while ($attempt < $maxAttempts) {
            try {
                return $operation($attempt);
            } catch (Exception $e) {
                $lastException = $e;
                
                // Check if we should retry
                $shouldRetry = false;
                foreach ($retryOn as $exceptionClass) {
                    if ($e instanceof $exceptionClass) {
                        $shouldRetry = true;
                        break;
                    }
                }
                
                if (!$shouldRetry || ++$attempt >= $maxAttempts) {
                    throw $e;
                }
                
                usleep($delayMs * 1000 * $attempt); // Exponential backoff
            }
        }
        
        throw $lastException;
    }
}

test('retryable operation succeeds after failures', function () {
    $attempts = 0;
    
    $result = RetryableOperation::execute(
        function () use (&$attempts) {
            $attempts++;
            
            if ($attempts < 3) {
                throw new NetworkException('Connection failed');
            }
            
            return 'success';
        },
        maxAttempts: 5,
        delayMs: 10,
        retryOn: [NetworkException::class]
    );
    
    expect($result)->toBe('success')
        ->and($attempts)->toBe(3);
});
```

### Fallback Strategies
```php
test('uses fallback when primary fails', function () {
    $service = new ServiceWithFallback();
    
    // Primary service fails
    $primaryService = Mockery::mock(PrimaryService::class);
    $primaryService->shouldReceive('getData')
        ->once()
        ->andThrow(new ServiceException());
    
    // Fallback service works
    $fallbackService = Mockery::mock(FallbackService::class);
    $fallbackService->shouldReceive('getData')
        ->once()
        ->andReturn(['source' => 'fallback']);
    
    $service->setPrimary($primaryService);
    $service->setFallback($fallbackService);
    
    $result = $service->getData();
    
    expect($result)->toBe(['source' => 'fallback']);
});
```

### Circuit Breaker Pattern
```php
class CircuitBreaker
{
    private int $failures = 0;
    private ?float $lastFailureTime = null;
    private string $state = 'closed'; // closed, open, half-open
    
    public function __construct(
        private int $threshold = 5,
        private int $timeout = 60
    ) {}
    
    public function call(Closure $operation): mixed
    {
        if ($this->state === 'open') {
            if ($this->shouldAttemptReset()) {
                $this->state = 'half-open';
            } else {
                throw new CircuitOpenException('Circuit breaker is open');
            }
        }
        
        try {
            $result = $operation();
            $this->onSuccess();
            return $result;
        } catch (Exception $e) {
            $this->onFailure();
            throw $e;
        }
    }
    
    private function shouldAttemptReset(): bool
    {
        return $this->lastFailureTime 
            && (time() - $this->lastFailureTime) > $this->timeout;
    }
    
    private function onSuccess(): void
    {
        $this->failures = 0;
        $this->state = 'closed';
    }
    
    private function onFailure(): void
    {
        $this->failures++;
        $this->lastFailureTime = time();
        
        if ($this->failures >= $this->threshold) {
            $this->state = 'open';
        }
    }
}

test('circuit breaker prevents cascading failures', function () {
    $breaker = new CircuitBreaker(threshold: 3, timeout: 1);
    $callCount = 0;
    
    $operation = function () use (&$callCount) {
        $callCount++;
        throw new Exception('Service unavailable');
    };
    
    // First 3 calls fail and open the circuit
    for ($i = 0; $i < 3; $i++) {
        try {
            $breaker->call($operation);
        } catch (Exception $e) {
            // Expected
        }
    }
    
    // Circuit is now open
    expect(fn() => $breaker->call($operation))
        ->toThrow(CircuitOpenException::class);
    
    expect($callCount)->toBe(3); // Operation not called when circuit is open
    
    // Wait for timeout
    sleep(2);
    
    // Circuit should be half-open, allowing one attempt
    try {
        $breaker->call($operation);
    } catch (Exception $e) {
        // Expected failure, circuit opens again
    }
    
    expect($callCount)->toBe(4);
});
```

## Error Reporting

### Structured Error Logging
```php
class TestErrorReporter
{
    private array $errors = [];
    
    public function report(Throwable $e, array $context = []): void
    {
        $this->errors[] = [
            'exception' => get_class($e),
            'message' => $e->getMessage(),
            'code' => $e->getCode(),
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'context' => $context,
            'time' => now()->toIso8601String(),
            'trace' => $e->getTraceAsString(),
        ];
        
        // Log to file for test analysis
        Log::channel('testing')->error($e->getMessage(), $context);
    }
    
    public function getErrors(): array
    {
        return $this->errors;
    }
    
    public function hasErrors(): bool
    {
        return count($this->errors) > 0;
    }
    
    public function clear(): void
    {
        $this->errors = [];
    }
}

test('error reporter captures all errors', function () {
    $reporter = new TestErrorReporter();
    
    // Simulate various errors
    $reporter->report(new ValidationException('Invalid input'), ['user_id' => 1]);
    $reporter->report(new DatabaseException('Connection lost'), ['query' => 'SELECT *']);
    
    expect($reporter->hasErrors())->toBeTrue()
        ->and($reporter->getErrors())->toHaveCount(2)
        ->and($reporter->getErrors()[0]['exception'])->toBe(ValidationException::class);
});
```

## Testing Error Messages

### User-Friendly Error Messages
```php
test('provides helpful error messages', function () {
    $scenarios = [
        'missing_field' => [
            'input' => [],
            'expectedMessage' => 'The email field is required.',
        ],
        'invalid_format' => [
            'input' => ['email' => 'invalid'],
            'expectedMessage' => 'Please enter a valid email address.',
        ],
        'duplicate_entry' => [
            'input' => ['email' => 'existing@example.com'],
            'expectedMessage' => 'This email is already registered.',
        ],
    ];
    
    foreach ($scenarios as $scenario => $config) {
        try {
            processRegistration($config['input']);
            $this->fail("Expected exception for scenario: {$scenario}");
        } catch (UserException $e) {
            expect($e->getMessage())->toBe($config['expectedMessage']);
            
            // Ensure no technical details leak
            expect($e->getMessage())
                ->not->toContain('SQL')
                ->not->toContain('Exception')
                ->not->toContain('Stack trace');
        }
    }
});
```

## Error Handling Best Practices

### Comprehensive Error Testing
```php
describe('ErrorHandler', function () {
    test('catches all exception types', function () {
        $handler = new ErrorHandler();
        
        $exceptions = [
            new RuntimeException('Runtime error'),
            new LogicException('Logic error'),
            new InvalidArgumentException('Invalid argument'),
            new OutOfBoundsException('Out of bounds'),
            new TypeError('Type error'),
        ];
        
        foreach ($exceptions as $exception) {
            $result = $handler->handle($exception);
            
            expect($result)->toBeInstanceOf(ErrorResponse::class)
                ->and($result->isHandled())->toBeTrue();
        }
    });
    
    test('preserves error context', function () {
        $handler = new ErrorHandler();
        $context = ['user_id' => 123, 'action' => 'update'];
        
        $exception = new ContextualException('Error with context', $context);
        $result = $handler->handle($exception);
        
        expect($result->getContext())->toBe($context);
    });
    
    test('does not expose sensitive information', function () {
        $handler = new ErrorHandler();
        
        $exception = new DatabaseException('Connection using password=secret123 failed');
        $result = $handler->handle($exception);
        
        expect($result->getMessage())->not->toContain('secret123')
            ->and($result->getMessage())->not->toContain('password');
    });
});
```