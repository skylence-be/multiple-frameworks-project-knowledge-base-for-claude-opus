# Filament v4 Security Guidelines (continued)

### Authorization
- [ ] Implement model policies for all resources
- [ ] Use field-level authorization
- [ ] Authorize all actions (create, edit, delete, bulk)
- [ ] Implement row-level security
- [ ] Use role-based access control (RBAC)
- [ ] Validate permissions on API endpoints

### Input Validation
- [ ] Validate all form inputs
- [ ] Sanitize HTML content
- [ ] Use parameter binding for queries
- [ ] Implement file type validation
- [ ] Set file size limits
- [ ] Validate image dimensions
- [ ] Check for malicious file content

### Data Protection
- [ ] Encrypt sensitive data at rest
- [ ] Use HTTPS everywhere
- [ ] Implement CSP headers
- [ ] Hash passwords with bcrypt/argon2
- [ ] Encrypt API tokens
- [ ] Mask sensitive data in UI
- [ ] Secure file storage

### Security Headers
- [ ] Content-Security-Policy
- [ ] X-Frame-Options
- [ ] X-Content-Type-Options
- [ ] X-XSS-Protection
- [ ] Strict-Transport-Security
- [ ] Referrer-Policy

### Monitoring
- [ ] Audit log all sensitive operations
- [ ] Monitor failed login attempts
- [ ] Track permission changes
- [ ] Log security events
- [ ] Set up intrusion detection
- [ ] Regular security scans

## OWASP Top 10 Protection

### 1. Injection Prevention
```php
// SECURE: Prevent SQL injection
$products = Product::whereRaw(
    'MATCH(name, description) AGAINST(? IN BOOLEAN MODE)',
    [$searchTerm]
)->get();

// SECURE: Prevent command injection
$output = escapeshellcmd($userInput);
exec("safe_command " . escapeshellarg($output));
```

### 2. Broken Authentication
```php
// SECURE: Strong password policy
Password::min(8)
    ->mixedCase()
    ->numbers()
    ->symbols()
    ->uncompromised();
```

### 3. Sensitive Data Exposure
```php
// SECURE: Never log sensitive data
Log::info('User action', [
    'user_id' => $user->id,
    'action' => 'password_reset',
    // Never log: password, credit_card, ssn, etc.
]);
```

### 4. XML External Entities (XXE)
```php
// SECURE: Disable external entities
libxml_disable_entity_loader(true);
$xml = simplexml_load_string($input, null, LIBXML_NOENT);
```

### 5. Broken Access Control
```php
// SECURE: Check permissions at every level
public function mount($record): void
{
    abort_unless(Gate::allows('view', $record), 403);
    parent::mount($record);
}
```

### 6. Security Misconfiguration
```php
// .env.production
APP_DEBUG=false
APP_ENV=production
DEBUGBAR_ENABLED=false
TELESCOPE_ENABLED=false
```

### 7. Cross-Site Scripting (XSS)
```php
// SECURE: Always escape output
{{ e($userInput) }}
{!! clean($trustedHtml) !!}
```

### 8. Insecure Deserialization
```php
// SECURE: Validate serialized data
$data = @unserialize($input);
if ($data === false && $input !== 'b:0;') {
    throw new \Exception('Invalid serialized data');
}
```

### 9. Using Components with Known Vulnerabilities
```bash
# SECURE: Regular dependency updates
composer audit
npm audit fix
```

### 10. Insufficient Logging & Monitoring
```php
// SECURE: Comprehensive logging
Log::channel('security')->warning('Suspicious activity', [
    'ip' => request()->ip(),
    'user_id' => auth()->id(),
    'url' => request()->fullUrl(),
    'method' => request()->method(),
]);
```
