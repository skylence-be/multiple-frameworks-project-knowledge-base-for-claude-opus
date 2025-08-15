# Security Guidelines

## Security First Mindset

> "Security is not a feature, it's a requirement"

### Core Principles:
1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Grant minimum necessary permissions
3. **Zero Trust**: Verify everything, trust nothing
4. **Fail Securely**: Errors shouldn't expose sensitive info
5. **Keep it Simple**: Complex systems have more vulnerabilities

## OWASP Top 10 Protection

### 1. Injection (SQL, NoSQL, Command)

```javascript
// ❌ VULNERABLE
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ SECURE: Parameterized queries
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);

// ✅ SECURE: ORM with parameterization
const user = await User.findOne({ where: { id: userId } });

// Command injection prevention
// ❌ VULNERABLE
exec(`convert ${userInput} output.pdf`);

// ✅ SECURE
const { spawn } = require('child_process');
spawn('convert', [sanitizedInput, 'output.pdf']);
```

### 2. Broken Authentication

```javascript
// Password Requirements
const passwordPolicy = {
  minLength: 12,
  requireUppercase: true,
  requireLowercase: true,
  requireNumbers: true,
  requireSpecialChars: true,
  preventCommonPasswords: true,
  preventUserInfo: true
};

// Secure password hashing
const bcrypt = require('bcrypt');
const saltRounds = 12;
const hashedPassword = await bcrypt.hash(password, saltRounds);

// Session management
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true, // HTTPS only
    httpOnly: true, // No JS access
    maxAge: 1000 * 60 * 60, // 1 hour
    sameSite: 'strict'
  }
}));

// Multi-factor authentication
const speakeasy = require('speakeasy');
const token = speakeasy.totp({
  secret: user.totpSecret,
  encoding: 'base32'
});
```

### 3. Sensitive Data Exposure

```javascript
// Encryption at rest
const crypto = require('crypto');
const algorithm = 'aes-256-gcm';

function encrypt(text) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(algorithm, Buffer.from(key), iv);
  // ... encryption logic
}

// HTTPS enforcement
app.use((req, res, next) => {
  if (!req.secure && process.env.NODE_ENV === 'production') {
    return res.redirect('https://' + req.headers.host + req.url);
  }
  next();
});

// Secure headers
const helmet = require('helmet');
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

### 4. XML External Entities (XXE)

```javascript
// Disable XXE in XML parsers
const libxmljs = require('libxmljs');
const parserOptions = {
  noent: false, // Disable entity expansion
  dtdload: false, // Disable external DTD loading
  dtdvalid: false // Disable DTD validation
};
```

### 5. Broken Access Control

```javascript
// Role-based access control (RBAC)
function authorize(requiredRole) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    if (!hasRole(req.user, requiredRole)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    
    next();
  };
}

// Resource-based authorization
app.get('/api/documents/:id', authenticate, async (req, res) => {
  const document = await Document.findById(req.params.id);
  
  // Check ownership
  if (document.userId !== req.user.id) {
    return res.status(403).json({ error: 'Access denied' });
  }
  
  res.json(document);
});
```

### 6. Security Misconfiguration

```javascript
// Environment configuration
// .env file (never commit)
DATABASE_URL=postgresql://...
JWT_SECRET=complex-random-string
API_KEY=another-complex-string

// Secure defaults
app.disable('x-powered-by'); // Hide Express
app.set('trust proxy', 1); // Behind proxy

// Error handling without info leakage
app.use((err, req, res, next) => {
  logger.error(err); // Log full error
  
  // Send generic message to client
  res.status(500).json({
    error: 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { details: err.message })
  });
});
```

### 7. Cross-Site Scripting (XSS)

```javascript
// Input sanitization
const DOMPurify = require('isomorphic-dompurify');
const clean = DOMPurify.sanitize(userInput);

// Output encoding
const escapeHtml = (text) => {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return text.replace(/[&<>"']/g, m => map[m]);
};

// Content Security Policy
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    objectSrc: ["'none'"],
    upgradeInsecureRequests: []
  }
}));

// React: Use JSX (auto-escapes)
// ✅ Safe
<div>{userContent}</div>

// ❌ Dangerous
<div dangerouslySetInnerHTML={{ __html: userContent }} />
```

### 8. Insecure Deserialization

```javascript
// Validate JSON schema
const Ajv = require('ajv');
const ajv = new Ajv();

const schema = {
  type: 'object',
  properties: {
    name: { type: 'string', maxLength: 100 },
    age: { type: 'number', minimum: 0, maximum: 150 }
  },
  required: ['name', 'age'],
  additionalProperties: false
};

const validate = ajv.compile(schema);
if (!validate(userData)) {
  throw new ValidationError(validate.errors);
}
```

### 9. Using Components with Known Vulnerabilities

```bash
# Regular dependency audits
npm audit
npm audit fix

# Or with yarn
yarn audit
yarn audit fix

# Automated with CI/CD
- name: Security Audit
  run: npm audit --audit-level=high
```

### 10. Insufficient Logging & Monitoring

```javascript
// Comprehensive logging
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({ format: winston.format.simple() })
  ]
});

// Security event logging
function logSecurityEvent(event, user, details) {
  logger.warn('SECURITY_EVENT', {
    event,
    user: user?.id,
    ip: user?.ip,
    timestamp: new Date().toISOString(),
    details
  });
}

// Log authentication failures
logSecurityEvent('LOGIN_FAILED', req.user, { 
  attemptedUsername: username 
});
```

## Additional Security Measures

### Rate Limiting
```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests
  message: 'Too many requests from this IP'
});

const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // Strict limit for sensitive operations
  skipSuccessfulRequests: true
});

app.use('/api/', limiter);
app.use('/api/auth/login', strictLimiter);
```

### CORS Configuration
```javascript
const cors = require('cors');

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### File Upload Security
```javascript
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    // Generate unique filename
    cb(null, `${uuid()}-${Date.now()}${path.extname(file.originalname)}`);
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|pdf/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});
```

## Security Checklist

### Development
- [ ] Use parameterized queries
- [ ] Validate all inputs
- [ ] Sanitize all outputs
- [ ] Implement proper authentication
- [ ] Use HTTPS everywhere
- [ ] Keep dependencies updated
- [ ] Follow least privilege principle
- [ ] Implement rate limiting
- [ ] Add security headers
- [ ] Log security events

### Before Deployment
- [ ] Run security audit
- [ ] Penetration testing
- [ ] Review access controls
- [ ] Check for hardcoded secrets
- [ ] Verify error handling
- [ ] Test rate limiting
- [ ] Validate CORS settings
- [ ] Review logging

### Production
- [ ] Monitor for anomalies
- [ ] Regular security updates
- [ ] Incident response plan
- [ ] Regular backups
- [ ] Security training for team
