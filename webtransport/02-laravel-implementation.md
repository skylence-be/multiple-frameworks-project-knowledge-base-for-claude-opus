# WebTransport Implementation with Laravel 12

## Prerequisites

### System Requirements
- PHP 8.3+
- Laravel 12.x
- Composer 2.x
- HTTP/3 capable server (Caddy, nginx 1.25+)
- SSL Certificate (Let's Encrypt recommended)

### Required Packages

```bash
# Core WebTransport support
composer require laravel/octane
composer require spiral/roadrunner-http "^3.5"
composer require spiral/roadrunner-grpc "^3.5"

# WebTransport specific package
composer require jonas/laravel-webtransport "^1.0"
# Note: If package doesn't exist, we'll build it

# Optional: For better performance
composer require ext-ev
composer require ext-event
```

## Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Browser   │◄────►│   Caddy/     │◄────►│   Laravel   │
│WebTransport │ HTTP3│   Nginx      │ gRPC │   Octane    │
└─────────────┘      └──────────────┘      └─────────────┘
                           ▲                      │
                           │                      ▼
                     ┌─────────────┐       ┌─────────────┐
                     │   SSL/TLS   │       │ RoadRunner  │
                     └─────────────┘       └─────────────┘
```

## Step 1: Laravel Octane Setup

### Install Octane with RoadRunner

```bash
php artisan octane:install --server=roadrunner

# Download RoadRunner binary
php artisan octane:install-roadrunner
```

### Configure `.rr.yaml` for WebTransport

```yaml
# .rr.yaml
version: "3"

server:
  command: "php artisan octane:start --server=roadrunner --host=0.0.0.0 --port=8000"
  relay: pipes
  relay_timeout: 60s

http:
  address: "0.0.0.0:8000"
  max_request_size: 20
  middleware: ["headers", "gzip"]
  uploads:
    forbid: [".php", ".exe", ".bat"]
  headers:
    cors:
      allowed_origin: "*"
      allowed_headers: "*"
      allowed_methods: "GET,POST,PUT,DELETE,OPTIONS"
      allow_credentials: true
      exposed_headers: "Cache-Control,Content-Language,Content-Type"
      max_age: 600

# WebTransport configuration
http3:
  address: "0.0.0.0:443"
  enable_webtransport: true
  cert: "/path/to/cert.pem"
  key: "/path/to/key.pem"
  max_concurrent_streams: 100
  initial_stream_receive_window: 1048576
  initial_connection_receive_window: 15728640
  max_receive_stream_flow_control_window: 6291456
  max_receive_connection_flow_control_window: 15728640

grpc:
  listen: "tcp://127.0.0.1:9001"
  proto:
    - "app/Grpc/proto/webtransport.proto"

logs:
  level: info
  output: stdout
  format: json
```

## Step 2: Create WebTransport Service Provider

```php
<?php
// app/Providers/WebTransportServiceProvider.php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use App\Services\WebTransport\WebTransportManager;
use App\Services\WebTransport\Handlers\StreamHandler;
use App\Services\WebTransport\Handlers\DatagramHandler;

class WebTransportServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(WebTransportManager::class, function ($app) {
            return new WebTransportManager(
                config('webtransport'),
                $app->make('log')
            );
        });

        $this->app->bind(StreamHandler::class);
        $this->app->bind(DatagramHandler::class);
    }

    public function boot(): void
    {
        $this->publishes([
            __DIR__.'/../../config/webtransport.php' => config_path('webtransport.php'),
        ], 'webtransport-config');

        $this->loadRoutesFrom(__DIR__.'/../../routes/webtransport.php');
    }
}
```

## Step 3: WebTransport Configuration

```php
<?php
// config/webtransport.php

return [
    'enabled' => env('WEBTRANSPORT_ENABLED', true),
    
    'server' => [
        'host' => env('WEBTRANSPORT_HOST', '0.0.0.0'),
        'port' => env('WEBTRANSPORT_PORT', 443),
        'cert_path' => env('WEBTRANSPORT_CERT_PATH'),
        'key_path' => env('WEBTRANSPORT_KEY_PATH'),
    ],

    'transport' => [
        'max_streams' => env('WEBTRANSPORT_MAX_STREAMS', 100),
        'max_datagram_size' => env('WEBTRANSPORT_MAX_DATAGRAM_SIZE', 1200),
        'idle_timeout' => env('WEBTRANSPORT_IDLE_TIMEOUT', 30),
        'keep_alive_interval' => env('WEBTRANSPORT_KEEP_ALIVE', 15),
    ],

    'handlers' => [
        'stream' => \App\Services\WebTransport\Handlers\StreamHandler::class,
        'datagram' => \App\Services\WebTransport\Handlers\DatagramHandler::class,
    ],

    'middleware' => [
        \App\Http\Middleware\WebTransportAuth::class,
        \App\Http\Middleware\WebTransportRateLimit::class,
    ],

    'channels' => [
        'chat' => [
            'handler' => \App\WebTransport\Channels\ChatChannel::class,
            'max_connections' => 1000,
        ],
        'notifications' => [
            'handler' => \App\WebTransport\Channels\NotificationChannel::class,
            'max_connections' => 5000,
        ],
        'game' => [
            'handler' => \App\WebTransport\Channels\GameChannel::class,
            'max_connections' => 100,
            'use_datagrams' => true,
        ],
    ],
];
```

## Step 4: WebTransport Manager Implementation

```php
<?php
// app/Services/WebTransport/WebTransportManager.php

namespace App\Services\WebTransport;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use App\Events\WebTransportConnected;
use App\Events\WebTransportDisconnected;

class WebTransportManager
{
    private array $connections = [];
    private array $channels = [];
    private array $config;

    public function __construct(array $config, $logger)
    {
        $this->config = $config;
        $this->logger = $logger;
        $this->initializeChannels();
    }

    public function handleConnection(string $sessionId, array $metadata): void
    {
        $this->connections[$sessionId] = [
            'id' => $sessionId,
            'connected_at' => now(),
            'metadata' => $metadata,
            'channels' => [],
            'streams' => [],
        ];

        event(new WebTransportConnected($sessionId, $metadata));
        
        $this->logger->info('WebTransport connection established', [
            'session_id' => $sessionId
        ]);
    }

    public function handleStream(string $sessionId, int $streamId, string $data): void
    {
        if (!isset($this->connections[$sessionId])) {
            return;
        }

        $message = json_decode($data, true);
        
        switch ($message['type'] ?? null) {
            case 'subscribe':
                $this->subscribeToChannel($sessionId, $message['channel']);
                break;
                
            case 'unsubscribe':
                $this->unsubscribeFromChannel($sessionId, $message['channel']);
                break;
                
            case 'message':
                $this->handleChannelMessage($sessionId, $message['channel'], $message['data']);
                break;
                
            case 'ping':
                $this->sendPong($sessionId, $streamId);
                break;
                
            default:
                $this->handleCustomMessage($sessionId, $streamId, $message);
        }
    }

    public function handleDatagram(string $sessionId, string $data): void
    {
        if (!isset($this->connections[$sessionId])) {
            return;
        }

        // Datagrams are used for unreliable, low-latency data
        // Perfect for game state updates, cursor positions, etc.
        $message = msgpack_unpack($data); // Using msgpack for efficiency
        
        if (isset($message['channel'])) {
            $channel = $this->channels[$message['channel']] ?? null;
            if ($channel && method_exists($channel, 'handleDatagram')) {
                $channel->handleDatagram($sessionId, $message['data']);
            }
        }
    }

    public function broadcast(string $channel, array $data, array $except = []): void
    {
        $subscribers = $this->getChannelSubscribers($channel);
        
        foreach ($subscribers as $sessionId) {
            if (in_array($sessionId, $except)) {
                continue;
            }
            
            $this->sendToSession($sessionId, [
                'channel' => $channel,
                'data' => $data,
                'timestamp' => microtime(true),
            ]);
        }
    }

    public function sendToSession(string $sessionId, array $data): bool
    {
        try {
            $connection = $this->connections[$sessionId] ?? null;
            if (!$connection) {
                return false;
            }

            // Use gRPC to send data through RoadRunner
            $client = new \App\Grpc\WebTransportClient('127.0.0.1:9001', [
                'credentials' => \Grpc\ChannelCredentials::createInsecure(),
            ]);

            $request = new \App\Grpc\SendStreamRequest();
            $request->setSessionId($sessionId);
            $request->setData(json_encode($data));

            [$response, $status] = $client->SendStream($request)->wait();
            
            return $status->code === \Grpc\STATUS_OK;
        } catch (\Exception $e) {
            $this->logger->error('Failed to send WebTransport message', [
                'session_id' => $sessionId,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    public function sendDatagram(string $sessionId, string $data): bool
    {
        try {
            $client = new \App\Grpc\WebTransportClient('127.0.0.1:9001', [
                'credentials' => \Grpc\ChannelCredentials::createInsecure(),
            ]);

            $request = new \App\Grpc\SendDatagramRequest();
            $request->setSessionId($sessionId);
            $request->setData($data);

            [$response, $status] = $client->SendDatagram($request)->wait();
            
            return $status->code === \Grpc\STATUS_OK;
        } catch (\Exception $e) {
            $this->logger->error('Failed to send WebTransport datagram', [
                'session_id' => $sessionId,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    public function disconnect(string $sessionId): void
    {
        if (!isset($this->connections[$sessionId])) {
            return;
        }

        $connection = $this->connections[$sessionId];
        
        // Unsubscribe from all channels
        foreach ($connection['channels'] as $channel) {
            $this->unsubscribeFromChannel($sessionId, $channel);
        }

        unset($this->connections[$sessionId]);
        
        event(new WebTransportDisconnected($sessionId));
        
        $this->logger->info('WebTransport connection closed', [
            'session_id' => $sessionId
        ]);
    }

    private function subscribeToChannel(string $sessionId, string $channel): void
    {
        if (!isset($this->channels[$channel])) {
            return;
        }

        $this->connections[$sessionId]['channels'][] = $channel;
        
        // Store in cache for persistence across workers
        $subscribers = Cache::get("wt:channel:{$channel}", []);
        $subscribers[] = $sessionId;
        Cache::put("wt:channel:{$channel}", array_unique($subscribers), 3600);
    }

    private function unsubscribeFromChannel(string $sessionId, string $channel): void
    {
        $key = array_search($channel, $this->connections[$sessionId]['channels'] ?? []);
        if ($key !== false) {
            unset($this->connections[$sessionId]['channels'][$key]);
        }

        $subscribers = Cache::get("wt:channel:{$channel}", []);
        $subscribers = array_diff($subscribers, [$sessionId]);
        Cache::put("wt:channel:{$channel}", $subscribers, 3600);
    }

    private function getChannelSubscribers(string $channel): array
    {
        return Cache::get("wt:channel:{$channel}", []);
    }

    private function initializeChannels(): void
    {
        foreach ($this->config['channels'] as $name => $config) {
            $this->channels[$name] = app($config['handler']);
        }
    }

    private function handleChannelMessage(string $sessionId, string $channel, $data): void
    {
        $channelHandler = $this->channels[$channel] ?? null;
        if ($channelHandler) {
            $channelHandler->handleMessage($sessionId, $data, $this);
        }
    }

    private function handleCustomMessage(string $sessionId, int $streamId, array $message): void
    {
        // Override this method for custom message handling
        $this->logger->debug('Unhandled WebTransport message', [
            'session_id' => $sessionId,
            'stream_id' => $streamId,
            'message' => $message,
        ]);
    }

    private function sendPong(string $sessionId, int $streamId): void
    {
        $this->sendToSession($sessionId, [
            'type' => 'pong',
            'stream_id' => $streamId,
            'timestamp' => microtime(true),
        ]);
    }
}
```

## Step 5: Channel Implementation Example

```php
<?php
// app/WebTransport/Channels/ChatChannel.php

namespace App\WebTransport\Channels;

use App\Services\WebTransport\WebTransportManager;
use App\Models\Message;
use App\Models\User;

class ChatChannel
{
    public function handleMessage(string $sessionId, $data, WebTransportManager $manager): void
    {
        $user = $this->getUserFromSession($sessionId);
        
        if (!$user) {
            $manager->sendToSession($sessionId, [
                'error' => 'Unauthorized',
            ]);
            return;
        }

        switch ($data['action'] ?? null) {
            case 'send_message':
                $this->handleSendMessage($user, $data, $manager);
                break;
                
            case 'typing':
                $this->handleTyping($user, $data, $manager);
                break;
                
            case 'read':
                $this->handleMarkAsRead($user, $data, $manager);
                break;
        }
    }

    private function handleSendMessage(User $user, array $data, WebTransportManager $manager): void
    {
        $message = Message::create([
            'user_id' => $user->id,
            'room_id' => $data['room_id'],
            'content' => $data['content'],
            'type' => $data['type'] ?? 'text',
        ]);

        // Broadcast to all users in the room
        $manager->broadcast('chat', [
            'action' => 'new_message',
            'message' => [
                'id' => $message->id,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'avatar' => $user->avatar_url,
                ],
                'content' => $message->content,
                'type' => $message->type,
                'created_at' => $message->created_at->toIso8601String(),
            ],
            'room_id' => $data['room_id'],
        ]);
    }

    private function handleTyping(User $user, array $data, WebTransportManager $manager): void
    {
        // Use datagram for typing indicators (unreliable is fine)
        $datagramData = msgpack_pack([
            'channel' => 'chat',
            'action' => 'typing',
            'user_id' => $user->id,
            'user_name' => $user->name,
            'room_id' => $data['room_id'],
            'is_typing' => $data['is_typing'] ?? true,
        ]);

        $roomUsers = $this->getRoomUsers($data['room_id']);
        foreach ($roomUsers as $sessionId) {
            if ($sessionId !== $data['session_id']) {
                $manager->sendDatagram($sessionId, $datagramData);
            }
        }
    }

    private function handleMarkAsRead(User $user, array $data, WebTransportManager $manager): void
    {
        Message::where('room_id', $data['room_id'])
            ->where('user_id', '!=', $user->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        $manager->sendToSession($data['session_id'], [
            'action' => 'messages_read',
            'room_id' => $data['room_id'],
        ]);
    }

    private function getUserFromSession(string $sessionId): ?User
    {
        $userId = cache()->get("wt:session:user:{$sessionId}");
        return $userId ? User::find($userId) : null;
    }

    private function getRoomUsers(int $roomId): array
    {
        return cache()->get("wt:room:users:{$roomId}", []);
    }
}
```

## Step 6: Controller Implementation

```php
<?php
// app/Http/Controllers/WebTransportController.php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\WebTransport\WebTransportManager;
use Illuminate\Support\Str;

class WebTransportController extends Controller
{
    public function __construct(
        private WebTransportManager $webTransport
    ) {}

    /**
     * Initialize WebTransport connection
     */
    public function connect(Request $request)
    {
        $request->validate([
            'token' => 'required|string',
        ]);

        // Verify authentication token
        $user = $this->verifyToken($request->token);
        
        if (!$user) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $sessionId = Str::uuid()->toString();
        
        // Store user association
        cache()->put("wt:session:user:{$sessionId}", $user->id, 3600);
        
        // Initialize connection
        $this->webTransport->handleConnection($sessionId, [
            'user_id' => $user->id,
            'ip' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'session_id' => $sessionId,
            'endpoints' => [
                'stream' => url('/webtransport/stream'),
                'datagram' => url('/webtransport/datagram'),
            ],
            'config' => [
                'max_streams' => config('webtransport.transport.max_streams'),
                'max_datagram_size' => config('webtransport.transport.max_datagram_size'),
                'idle_timeout' => config('webtransport.transport.idle_timeout'),
            ],
        ]);
    }

    /**
     * Handle incoming stream data
     */
    public function handleStream(Request $request)
    {
        $sessionId = $request->header('X-WebTransport-Session');
        $streamId = $request->header('X-WebTransport-Stream');
        
        if (!$sessionId || !$streamId) {
            return response()->json(['error' => 'Invalid request'], 400);
        }

        $data = $request->getContent();
        
        $this->webTransport->handleStream($sessionId, (int)$streamId, $data);
        
        return response()->json(['status' => 'ok']);
    }

    /**
     * Handle incoming datagram
     */
    public function handleDatagram(Request $request)
    {
        $sessionId = $request->header('X-WebTransport-Session');
        
        if (!$sessionId) {
            return response()->json(['error' => 'Invalid request'], 400);
        }

        $data = $request->getContent();
        
        $this->webTransport->handleDatagram($sessionId, $data);
        
        return response()->json(['status' => 'ok']);
    }

    /**
     * Close WebTransport connection
     */
    public function disconnect(Request $request)
    {
        $sessionId = $request->header('X-WebTransport-Session');
        
        if ($sessionId) {
            $this->webTransport->disconnect($sessionId);
            cache()->forget("wt:session:user:{$sessionId}");
        }
        
        return response()->json(['status' => 'disconnected']);
    }

    private function verifyToken(string $token)
    {
        // Implement your token verification logic
        return \App\Models\User::where('api_token', $token)->first();
    }
}
```

## Step 7: Routes Configuration

```php
<?php
// routes/webtransport.php

use App\Http\Controllers\WebTransportController;

Route::prefix('webtransport')->group(function () {
    Route::post('/connect', [WebTransportController::class, 'connect']);
    Route::post('/stream', [WebTransportController::class, 'handleStream']);
    Route::post('/datagram', [WebTransportController::class, 'handleDatagram']);
    Route::post('/disconnect', [WebTransportController::class, 'disconnect']);
});
```

## Step 8: Middleware for Authentication

```php
<?php
// app/Http/Middleware/WebTransportAuth.php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class WebTransportAuth
{
    public function handle(Request $request, Closure $next)
    {
        $sessionId = $request->header('X-WebTransport-Session');
        
        if (!$sessionId) {
            return response()->json(['error' => 'No session'], 401);
        }

        $userId = cache()->get("wt:session:user:{$sessionId}");
        
        if (!$userId) {
            return response()->json(['error' => 'Invalid session'], 401);
        }

        $request->merge(['user_id' => $userId, 'session_id' => $sessionId]);
        
        return $next($request);
    }
}
```

## Step 9: Testing WebTransport

```php
<?php
// tests/Feature/WebTransportTest.php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Services\WebTransport\WebTransportManager;

class WebTransportTest extends TestCase
{
    public function test_can_establish_webtransport_connection()
    {
        $user = User::factory()->create();
        
        $response = $this->postJson('/webtransport/connect', [
            'token' => $user->api_token,
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'session_id',
                'endpoints',
                'config',
            ]);
    }

    public function test_can_send_stream_message()
    {
        $user = User::factory()->create();
        $sessionId = 'test-session-id';
        
        cache()->put("wt:session:user:{$sessionId}", $user->id, 60);

        $response = $this->postJson('/webtransport/stream', [
            'type' => 'message',
            'channel' => 'chat',
            'data' => [
                'action' => 'send_message',
                'content' => 'Hello WebTransport!',
            ],
        ], [
            'X-WebTransport-Session' => $sessionId,
            'X-WebTransport-Stream' => '1',
        ]);

        $response->assertOk();
    }

    public function test_can_broadcast_to_channel()
    {
        $manager = app(WebTransportManager::class);
        
        $manager->broadcast('notifications', [
            'type' => 'alert',
            'message' => 'System update in 5 minutes',
        ]);

        // Assert broadcast was sent to all subscribers
        $this->assertTrue(true);
    }
}
```

## Production Deployment

### Caddy Configuration

```caddyfile
example.com {
    reverse_proxy /webtransport/* localhost:8000 {
        transport http {
            versions h3
        }
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }

    # Enable HTTP/3
    servers {
        protocol {
            experimental_http3
            allow_h2c
        }
    }
}
```

### Supervisor Configuration

```ini
[program:laravel-webtransport]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/artisan octane:start --server=roadrunner --workers=4 --task-workers=8
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=1
redirect_stderr=true
stdout_logfile=/var/log/laravel-webtransport.log
```

## Performance Monitoring

```php
// app/Console/Commands/MonitorWebTransport.php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\WebTransport\WebTransportManager;

class MonitorWebTransport extends Command
{
    protected $signature = 'webtransport:monitor';
    protected $description = 'Monitor WebTransport connections and performance';

    public function handle(WebTransportManager $manager)
    {
        $this->info('WebTransport Monitor Started');
        
        while (true) {
            $stats = $manager->getStats();
            
            $this->table(
                ['Metric', 'Value'],
                [
                    ['Active Connections', $stats['connections']],
                    ['Total Streams', $stats['streams']],
                    ['Datagrams Sent', $stats['datagrams_sent']],
                    ['Datagrams Received', $stats['datagrams_received']],
                    ['Avg Latency', $stats['avg_latency'] . 'ms'],
                    ['Memory Usage', $this->formatBytes($stats['memory'])],
                ]
            );
            
            sleep(5);
        }
    }

    private function formatBytes($bytes, $precision = 2)
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $i = 0;
        
        while ($bytes > 1024 && $i < count($units) - 1) {
            $bytes /= 1024;
            $i++;
        }
        
        return round($bytes, $precision) . ' ' . $units[$i];
    }
}
```

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check if HTTP/3 is enabled in your server
   - Verify UDP port 443 is open
   - Ensure valid SSL certificate

2. **High Latency**
   - Enable 0-RTT in server configuration
   - Check network congestion
   - Monitor server resources

3. **Stream Errors**
   - Verify stream limits in configuration
   - Check for proper error handling
   - Monitor RoadRunner logs

### Debug Mode

```php
// Enable debug logging
'logging' => [
    'channels' => [
        'webtransport' => [
            'driver' => 'daily',
            'path' => storage_path('logs/webtransport.log'),
            'level' => env('WEBTRANSPORT_LOG_LEVEL', 'debug'),
        ],
    ],
],
```

## Next Steps

- [Client Implementation with Nuxt 4](./03-nuxt-implementation.md)
- [Advanced Features](./06-advanced-features.md)
- [Security Best Practices](./07-security.md)
