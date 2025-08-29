# Security Guidelines for Pest Testing (continued)

## CSRF Protection Testing

```php
test('requires CSRF token for state-changing operations', function () {
    $response = $this->post('/api/users', [
        'name' => 'Test User',
        'email' => 'test@example.com'
    ]);
    
    expect($response->status())->toBe(419); // CSRF token mismatch
});

test('accepts valid CSRF token', function () {
    $response = $this->withSession(['_token' => 'test-token'])
        ->post('/api/users', [
            '_token' => 'test-token',
            'name' => 'Test User',
            'email' => 'test@example.com'
        ]);
    
    expect($response->status())->toBe(201);
});
```

## Rate Limiting Testing

```php
test('enforces rate limiting on API endpoints', function () {
    $user = User::factory()->create();
    
    // Make requests up to the limit
    for ($i = 0; $i < 60; $i++) {
        $response = $this->actingAs($user)->get('/api/data');
        expect($response->status())->toBe(200);
    }
    
    // Next request should be rate limited
    $response = $this->actingAs($user)->get('/api/data');
    
    expect($response->status())->toBe(429)
        ->and($response->headers->get('X-RateLimit-Remaining'))->toBe('0')
        ->and($response->headers->get('Retry-After'))->toBeGreaterThan(0);
});
```

## Cryptography Testing

```php
test('uses secure password hashing', function () {
    $password = 'SecurePassword123!';
    $hash = Hash::make($password);
    
    expect($hash)->not->toBe($password)
        ->and(Hash::check($password, $hash))->toBeTrue()
        ->and(Hash::needsRehash($hash))->toBeFalse();
});

test('generates cryptographically secure tokens', function () {
    $token1 = Str::random(40);
    $token2 = Str::random(40);
    
    expect($token1)->toHaveLength(40)
        ->and($token1)->not->toBe($token2)
        ->and($token1)->toMatch('/^[a-zA-Z0-9]+$/');
});
```

## API Security Testing

```php
test('validates API key authentication', function () {
    // No API key
    $response = $this->get('/api/v1/protected');
    expect($response->status())->toBe(401);
    
    // Invalid API key
    $response = $this->withHeaders([
        'X-API-Key' => 'invalid-key'
    ])->get('/api/v1/protected');
    expect($response->status())->toBe(401);
    
    // Valid API key
    $apiKey = ApiKey::factory()->create();
    $response = $this->withHeaders([
        'X-API-Key' => $apiKey->key
    ])->get('/api/v1/protected');
    expect($response->status())->toBe(200);
});

test('implements API versioning security', function () {
    // Deprecated version should warn
    $response = $this->get('/api/v1/users');
    expect($response->headers->get('X-API-Deprecated'))->toBe('true');
    
    // Unsupported version should fail
    $response = $this->get('/api/v0/users');
    expect($response->status())->toBe(404);
});
```

## Database Security Testing

```php
test('uses parameterized queries', function () {
    $maliciousInput = "'; DROP TABLE users; --";
    
    // This should safely handle the malicious input
    $users = DB::select('SELECT * FROM users WHERE name = ?', [$maliciousInput]);
    
    expect($users)->toBeArray()
        ->and(DB::table('users')->exists())->toBeTrue();
});

test('encrypts sensitive database fields', function () {
    $user = User::factory()->create([
        'credit_card' => encrypt('4111111111111111')
    ]);
    
    $rawData = DB::table('users')
        ->where('id', $user->id)
        ->value('credit_card');
    
    expect($rawData)->not->toContain('4111')
        ->and(decrypt($rawData))->toBe('4111111111111111');
});
```

## Security Testing Helpers

```php
// In Pest.php

/**
 * Create a user with specific permissions for testing
 */
function createUserWithPermissions(array $permissions): User
{
    $user = User::factory()->create();
    foreach ($permissions as $permission) {
        $user->givePermissionTo($permission);
    }
    return $user;
}

/**
 * Assert that a response contains security headers
 */
function assertHasSecurityHeaders($response): void
{
    expect($response->headers->get('X-Frame-Options'))->not->toBeNull()
        ->and($response->headers->get('X-Content-Type-Options'))->not->toBeNull()
        ->and($response->headers->get('X-XSS-Protection'))->not->toBeNull();
}

/**
 * Generate malicious payloads for testing
 */
function maliciousPayloads(): array
{
    return [
        'sql_injection' => "' OR '1'='1",
        'xss_script' => '<script>alert("XSS")</script>',
        'xxe_attack' => '<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>',
        'path_traversal' => '../../../etc/passwd',
        'command_injection' => '; cat /etc/passwd',
        'ldap_injection' => '*)(uid=*))(|(uid=*',
    ];
}
```

## Security Audit Checklist

### Authentication
- [ ] Password complexity requirements enforced
- [ ] Account lockout after failed attempts
- [ ] Session timeout implemented
- [ ] Secure password reset process
- [ ] Multi-factor authentication available
- [ ] OAuth/SAML properly configured

### Authorization
- [ ] Role-based access control tested
- [ ] Resource-level permissions verified
- [ ] API endpoints properly protected
- [ ] Admin functions restricted
- [ ] IDOR vulnerabilities checked

### Input Validation
- [ ] All inputs validated and sanitized
- [ ] File uploads restricted and scanned
- [ ] SQL injection prevention tested
- [ ] XSS prevention verified
- [ ] Command injection blocked

### Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] Secure transmission (HTTPS/TLS)
- [ ] PII properly handled
- [ ] Logs sanitized
- [ ] Backups encrypted

### Security Headers
- [ ] CSP header configured
- [ ] X-Frame-Options set
- [ ] X-Content-Type-Options present
- [ ] HSTS enabled
- [ ] CORS properly configured

### API Security
- [ ] Rate limiting implemented
- [ ] API authentication required
- [ ] API versioning handled
- [ ] Input validation on all endpoints
- [ ] Error messages sanitized

## Compliance Testing

### GDPR Compliance
```php
test('allows users to export their data', function () {
    $user = User::factory()->create();
    
    $response = $this->actingAs($user)->get('/api/gdpr/export');
    
    expect($response->status())->toBe(200)
        ->and($response->json())->toHaveKeys(['personal_data', 'activity_logs']);
});

test('allows users to delete their account', function () {
    $user = User::factory()->create();
    
    $response = $this->actingAs($user)->delete('/api/account');
    
    expect($response->status())->toBe(200)
        ->and(User::find($user->id))->toBeNull();
});
```

### PCI DSS Compliance
```php
test('does not store CVV codes', function () {
    $response = $this->post('/api/payment', [
        'card_number' => '4111111111111111',
        'cvv' => '123'
    ]);
    
    expect($response->status())->toBe(200);
    
    // Check database doesn't contain CVV
    $payment = Payment::latest()->first();
    expect($payment->getAttributes())->not->toHaveKey('cvv');
});
```

## Security Best Practices for Tests

1. **Never commit real credentials** - Use env variables or test credentials
2. **Test both positive and negative security cases** - Valid and invalid inputs
3. **Use security-focused datasets** - Include common attack vectors
4. **Isolate security tests** - Group them for easy identification
5. **Run security tests in CI/CD** - Automate security validation
6. **Keep security tests updated** - Add new attack vectors as discovered
7. **Document security assumptions** - Make security requirements clear
8. **Use security testing tools** - Integrate SAST/DAST tools
9. **Test rate limiting carefully** - Don't trigger actual blocks
10. **Monitor test coverage of security features** - Ensure comprehensive testing