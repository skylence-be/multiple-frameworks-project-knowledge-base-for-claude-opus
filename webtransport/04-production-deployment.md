# WebTransport Production Deployment Guide

## Infrastructure Requirements

### Server Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16+ GB |
| Network | 1 Gbps | 10 Gbps |
| Storage | 50 GB SSD | 100+ GB NVMe |
| OS | Ubuntu 20.04 | Ubuntu 22.04 |

### Network Configuration

```bash
# Enable UDP port 443 for QUIC
sudo ufw allow 443/udp

# Increase UDP buffer sizes
echo "net.core.rmem_max = 2500000" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 2500000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Enable BBR congestion control
echo "net.core.default_qdisc = fq" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## SSL Certificate Setup

### Using Certbot (Let's Encrypt)

```bash
# Install Certbot
sudo apt update
sudo apt install certbot

# Generate certificate
sudo certbot certonly --standalone -d example.com -d www.example.com

# Auto-renewal
sudo certbot renew --dry-run
```

### Certificate Configuration

```bash
# Copy certificates to application directory
sudo cp /etc/letsencrypt/live/example.com/fullchain.pem /app/certs/
sudo cp /etc/letsencrypt/live/example.com/privkey.pem /app/certs/
sudo chown app:app /app/certs/*
sudo chmod 600 /app/certs/privkey.pem
```

## Web Server Configuration

### Caddy (Recommended)

```caddyfile
# /etc/caddy/Caddyfile
example.com {
    # Enable HTTP/3
    servers {
        protocol {
            experimental_http3
            allow_h2c
        }
    }

    # WebTransport endpoint
    handle /webtransport/* {
        reverse_proxy localhost:8000 {
            transport http {
                versions h3
            }
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-For {remote_host}
            header_up X-Forwarded-Proto {scheme}
        }
    }

    # Laravel application
    handle /api/* {
        reverse_proxy localhost:8000
    }

    # Nuxt application
    handle {
        reverse_proxy localhost:3000
    }

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "geolocation=(), microphone=(), camera=()"
    }

    # Enable compression
    encode gzip zstd

    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }
}
```

### Nginx Configuration

```nginx
# /etc/nginx/sites-available/webtransport
server {
    listen 443 quic reuseport;
    listen 443 ssl http2;
    
    server_name example.com;
    
    # SSL Configuration
    ssl_certificate /app/certs/fullchain.pem;
    ssl_certificate_key /app/certs/privkey.pem;
    ssl_protocols TLSv1.3;
    ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256';
    
    # HTTP/3 Configuration
    add_header Alt-Svc 'h3=":443"; ma=86400';
    
    # WebTransport endpoint
    location /webtransport/ {
        proxy_pass http://localhost:8000;
        proxy_http_version 3.0;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebTransport specific headers
        proxy_set_header Connection "";
        proxy_set_header Upgrade $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Laravel API
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # Nuxt application
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## Laravel Deployment

### Environment Configuration

```env
# .env.production
APP_ENV=production
APP_DEBUG=false
APP_URL=https://example.com

OCTANE_SERVER=roadrunner
OCTANE_WORKERS=auto
OCTANE_TASK_WORKERS=auto
OCTANE_MAX_REQUESTS=500

WEBTRANSPORT_ENABLED=true
WEBTRANSPORT_HOST=0.0.0.0
WEBTRANSPORT_PORT=8000
WEBTRANSPORT_CERT_PATH=/app/certs/fullchain.pem
WEBTRANSPORT_KEY_PATH=/app/certs/privkey.pem

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
```

### RoadRunner Production Configuration

```yaml
# .rr.yaml
version: "3"

server:
  command: "php artisan octane:start --server=roadrunner --host=0.0.0.0 --port=8000 --workers=auto"
  relay: pipes
  relay_timeout: 60s

http:
  address: "0.0.0.0:8000"
  max_request_size: 20
  middleware: ["headers", "gzip", "static"]
  pool:
    num_workers: ${OCTANE_WORKERS}
    max_jobs: ${OCTANE_MAX_REQUESTS}
    allocate_timeout: 60s
    destroy_timeout: 60s
  uploads:
    forbid: [".php", ".exe", ".bat"]
  static:
    dir: "public"
    forbid: [".php", ".htaccess"]

http3:
  address: "0.0.0.0:8000"
  enable_webtransport: true
  cert: "${WEBTRANSPORT_CERT_PATH}"
  key: "${WEBTRANSPORT_KEY_PATH}"
  max_concurrent_streams: 250
  initial_stream_receive_window: 1048576
  initial_connection_receive_window: 15728640

grpc:
  listen: "tcp://127.0.0.1:9001"
  proto:
    - "app/Grpc/proto/webtransport.proto"
  pool:
    num_workers: 4
    max_jobs: 100

logs:
  level: error
  output: "/var/log/roadrunner/error.log"
  format: json
  channels:
    http:
      level: error
      output: "/var/log/roadrunner/http.log"
    server:
      level: error
      output: "/var/log/roadrunner/server.log"

metrics:
  address: "127.0.0.1:2112"
  collect:
    app_metric:
      type: histogram
      help: "Application metrics"
```

### Supervisor Configuration

```ini
# /etc/supervisor/conf.d/laravel-webtransport.conf
[program:laravel-webtransport]
process_name=%(program_name)s_%(process_num)02d
command=/usr/bin/php /app/artisan octane:start --server=roadrunner --host=0.0.0.0 --port=8000
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=/var/log/supervisor/laravel-webtransport.log
environment=PATH="/usr/local/bin:/usr/bin:/bin"

[program:laravel-queue]
process_name=%(program_name)s_%(process_num)02d
command=/usr/bin/php /app/artisan queue:work redis --sleep=3 --tries=3 --timeout=90
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/var/log/supervisor/laravel-queue.log
```

## Nuxt Deployment

### PM2 Configuration

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'nuxt-webtransport',
    script: '.output/server/index.mjs',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      NUXT_PUBLIC_WEBTRANSPORT_URL: 'https://example.com/webtransport',
      NUXT_PUBLIC_API_URL: 'https://example.com/api',
      PORT: 3000,
    },
    error_file: '/var/log/pm2/nuxt-error.log',
    out_file: '/var/log/pm2/nuxt-out.log',
    log_file: '/var/log/pm2/nuxt-combined.log',
    time: true,
    max_memory_restart: '1G',
    min_uptime: '10s',
    max_restarts: 10,
  }]
}
```

### Docker Deployment

```dockerfile
# Dockerfile.nuxt
FROM node:20-alpine as builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:20-alpine

WORKDIR /app
COPY --from=builder /app/.output .output
COPY --from=builder /app/package*.json ./

EXPOSE 3000

ENV NODE_ENV=production
CMD ["node", ".output/server/index.mjs"]
```

```dockerfile
# Dockerfile.laravel
FROM php:8.3-cli

RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . .

RUN composer install --no-dev --optimize-autoloader
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache

CMD ["php", "artisan", "octane:start", "--server=roadrunner", "--host=0.0.0.0", "--port=8000"]
```

## Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - laravel
      - nuxt
    restart: unless-stopped

  laravel:
    build:
      context: ./laravel
      dockerfile: Dockerfile
    environment:
      - APP_ENV=production
      - OCTANE_SERVER=roadrunner
      - REDIS_HOST=redis
      - DB_HOST=mysql
    volumes:
      - ./laravel/storage:/app/storage
      - ./certs:/app/certs:ro
    depends_on:
      - redis
      - mysql
    restart: unless-stopped

  nuxt:
    build:
      context: ./nuxt
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
      - NUXT_PUBLIC_WEBTRANSPORT_URL=https://example.com/webtransport
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

  mysql:
    image: mysql:8
    environment:
      - MYSQL_ROOT_PASSWORD=secret
      - MYSQL_DATABASE=laravel
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
  redis_data:
  mysql_data:
```

## Monitoring and Logging

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'roadrunner'
    static_configs:
      - targets: ['localhost:2112']
    metrics_path: '/metrics'

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'caddy'
    static_configs:
      - targets: ['localhost:2019']
```

### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "WebTransport Metrics",
    "panels": [
      {
        "title": "Active Connections",
        "targets": [
          {
            "expr": "webtransport_active_connections",
            "legendFormat": "Connections"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Messages Per Second",
        "targets": [
          {
            "expr": "rate(webtransport_messages_total[1m])",
            "legendFormat": "{{type}}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Datagram Latency",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, webtransport_datagram_latency_bucket)",
            "legendFormat": "p95"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(webtransport_errors_total[5m])",
            "legendFormat": "{{error_type}}"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

### ELK Stack Setup

```yaml
# filebeat.yml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/roadrunner/*.log
    json.keys_under_root: true
    json.add_error_key: true
    fields:
      service: webtransport
      environment: production

output.elasticsearch:
  hosts: ["localhost:9200"]
  index: "webtransport-%{+yyyy.MM.dd}"

processors:
  - add_host_metadata:
      when.not.contains:
        tags: forwarded
```

## Load Balancing

### HAProxy Configuration

```
# /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend webtransport_frontend
    bind *:443 ssl crt /etc/ssl/certs/example.com.pem alpn h3,h2,http/1.1
    mode http
    
    # Enable HTTP/3
    http-response set-header alt-svc "h3=\":443\"; ma=86400"
    
    # Route to backend
    use_backend webtransport_backend if { path_beg /webtransport }
    default_backend web_backend

backend webtransport_backend
    balance roundrobin
    server wt1 10.0.0.1:8000 check
    server wt2 10.0.0.2:8000 check
    server wt3 10.0.0.3:8000 check

backend web_backend
    balance roundrobin
    server web1 10.0.0.1:3000 check
    server web2 10.0.0.2:3000 check
```

## Security Hardening

### Firewall Rules

```bash
#!/bin/bash
# firewall-setup.sh

# Reset firewall
sudo iptables -F
sudo iptables -X

# Default policies
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (restrict to specific IPs in production)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow QUIC/HTTP3
sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT

# Rate limiting for WebTransport
sudo iptables -A INPUT -p udp --dport 443 -m limit --limit 1000/sec --limit-burst 100 -j ACCEPT

# DDoS protection
sudo iptables -A INPUT -p udp --dport 443 -m connlimit --connlimit-above 100 -j DROP

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### Rate Limiting

```php
// app/Http/Middleware/WebTransportRateLimit.php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

class WebTransportRateLimit
{
    public function handle(Request $request, Closure $next)
    {
        $key = 'webtransport:' . $request->ip();
        
        // Allow 1000 messages per minute per IP
        $executed = RateLimiter::attempt(
            $key,
            1000,
            function() {},
            60
        );
        
        if (!$executed) {
            return response()->json([
                'error' => 'Too many requests'
            ], 429);
        }
        
        return $next($request);
    }
}
```

## Performance Tuning

### Linux Kernel Parameters

```bash
# /etc/sysctl.d/99-webtransport.conf

# Network buffers
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# UDP buffers
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# Connection tracking
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 60

# QUIC optimizations
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# File descriptors
fs.file-max = 2097152
fs.nr_open = 2097152
```

### PHP Configuration

```ini
; /etc/php/8.3/cli/conf.d/99-webtransport.ini
memory_limit = 512M
max_execution_time = 0
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.save_comments = 1
opcache.fast_shutdown = 1
```

## Backup and Recovery

### Automated Backup Script

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/webtransport"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
mysqldump -u root -p$MYSQL_PASSWORD laravel | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Backup Redis
redis-cli --rdb $BACKUP_DIR/redis_$DATE.rdb

# Backup application files
tar -czf $BACKUP_DIR/app_$DATE.tar.gz /app

# Backup certificates
tar -czf $BACKUP_DIR/certs_$DATE.tar.gz /app/certs

# Keep only last 7 days of backups
find $BACKUP_DIR -type f -mtime +7 -delete

# Upload to S3 (optional)
aws s3 sync $BACKUP_DIR s3://your-backup-bucket/webtransport/
```

## Health Checks

### Health Check Endpoint

```php
// app/Http/Controllers/HealthController.php
namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

class HealthController extends Controller
{
    public function check()
    {
        $health = [
            'status' => 'healthy',
            'timestamp' => now()->toIso8601String(),
            'checks' => []
        ];

        // Check database
        try {
            DB::connection()->getPdo();
            $health['checks']['database'] = 'ok';
        } catch (\Exception $e) {
            $health['checks']['database'] = 'failed';
            $health['status'] = 'unhealthy';
        }

        // Check Redis
        try {
            Redis::ping();
            $health['checks']['redis'] = 'ok';
        } catch (\Exception $e) {
            $health['checks']['redis'] = 'failed';
            $health['status'] = 'unhealthy';
        }

        // Check WebTransport
        try {
            $manager = app(\App\Services\WebTransport\WebTransportManager::class);
            $stats = $manager->getStats();
            $health['checks']['webtransport'] = 'ok';
            $health['metrics'] = $stats;
        } catch (\Exception $e) {
            $health['checks']['webtransport'] = 'failed';
            $health['status'] = 'unhealthy';
        }

        return response()->json($health, $health['status'] === 'healthy' ? 200 : 503);
    }
}
```

## Deployment Checklist

- [ ] SSL certificates installed and valid
- [ ] UDP port 443 open in firewall
- [ ] HTTP/3 enabled in web server
- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] Redis server running
- [ ] Supervisor/PM2 configured
- [ ] Monitoring setup (Prometheus/Grafana)
- [ ] Logging configured (ELK/CloudWatch)
- [ ] Backup strategy implemented
- [ ] Health checks configured
- [ ] Rate limiting enabled
- [ ] DDoS protection configured
- [ ] Load testing completed
- [ ] Rollback plan documented

## Next Steps

- [Performance Optimization Guide](./05-performance-optimization.md)
- [Advanced Features](./06-advanced-features.md)
- [Security Best Practices](./07-security.md)
- [Troubleshooting Guide](./08-troubleshooting.md)
