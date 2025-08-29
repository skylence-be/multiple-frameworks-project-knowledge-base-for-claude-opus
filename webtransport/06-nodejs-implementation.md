# WebTransport Implementation with Node.js

## Why Node.js is the Best Choice

When you already have Node.js on your server, it's the optimal choice for WebTransport because:

1. **Mature Packages**: Multiple production-ready WebTransport implementations
2. **Shared TypeScript**: Share types/interfaces between Nuxt client and Node server
3. **Event-Driven**: Perfect match for WebTransport's streaming model
4. **No Protocol Bridge**: Direct implementation unlike PHP solutions
5. **Excellent Performance**: V8's async handling is ideal for real-time

## Quick Start

### Installation

```bash
# Create Node.js WebTransport server
mkdir webtransport-server
cd webtransport-server
npm init -y

# Install dependencies
npm install @fails-components/webtransport
npm install express cors helmet
npm install ioredis
npm install dotenv
npm install msgpack-lite

# Dev dependencies
npm install -D typescript @types/node
npm install -D tsx nodemon
npm install -D @types/express @types/cors
```

### Basic Server Implementation

```typescript
// server.ts
import { WebTransportServer } from '@fails-components/webtransport';
import { readFileSync } from 'fs';
import express from 'express';
import Redis from 'ioredis';
import msgpack from 'msgpack-lite';
import { createHash } from 'crypto';

// Initialize Redis for Laravel communication
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
});

const pubClient = redis.duplicate();
const subClient = redis.duplicate();

// Express app for HTTP endpoints
const app = express();
app.use(express.json());

// WebTransport server configuration
const wtServer = new WebTransportServer({
  port: 4433,
  host: '0.0.0.0',
  cert: readFileSync('./certs/cert.pem'),
  key: readFileSync('./certs/key.pem'),
  alpn: 'h3', // HTTP/3
});

// Session management
interface Session {
  id: string;
  userId?: number;
  transport: any;
  streams: Map<number, any>;
  channels: Set<string>;
  metadata: Record<string, any>;
  connectedAt: Date;
}

const sessions = new Map<string, Session>();

// Start WebTransport server
wtServer.start().then(() => {
  console.log('WebTransport server running on port 4433');
});

// Handle new WebTransport sessions
wtServer.on('session', async (transport: any) => {
  const sessionId = generateSessionId();
  
  const session: Session = {
    id: sessionId,
    transport,
    streams: new Map(),
    channels: new Set(),
    metadata: {},
    connectedAt: new Date(),
  };
  
  sessions.set(sessionId, session);
  
  console.log(`New WebTransport session: ${sessionId}`);
  
  // Notify Laravel about new connection
  await notifyLaravel('connection.opened', {
    sessionId,
    timestamp: session.connectedAt,
  });
  
  // Handle session close
  transport.closed.then(() => {
    handleSessionClose(sessionId);
  }).catch((error: any) => {
    console.error('Session closed with error:', error);
    handleSessionClose(sessionId);
  });
  
  // Accept bidirectional streams
  acceptBidirectionalStreams(session);
  
  // Accept unidirectional streams
  acceptUnidirectionalStreams(session);
  
  // Handle datagrams
  handleDatagrams(session);
});

// Handle bidirectional streams
async function acceptBidirectionalStreams(session: Session) {
  const reader = session.transport.incomingBidirectionalStreams.getReader();
  
  try {
    while (true) {
      const { value: stream, done } = await reader.read();
      if (done) break;
      
      handleBidirectionalStream(session, stream);
    }
  } catch (error) {
    console.error('Error accepting bidirectional streams:', error);
  }
}

// Handle individual bidirectional stream
async function handleBidirectionalStream(session: Session, stream: any) {
  const reader = stream.readable.getReader();
  const writer = stream.writable.getWriter();
  
  try {
    // First message should be authentication
    const { value: authData, done: authDone } = await reader.read();
    if (authDone) return;
    
    const authMessage = decodeMessage(authData);
    
    if (authMessage.type === 'auth') {
      const isValid = await validateAuth(authMessage.token);
      
      if (isValid) {
        session.userId = authMessage.userId;
        
        // Send success response
        await writer.write(encodeMessage({
          type: 'auth_success',
          sessionId: session.id,
        }));
        
        // Continue handling messages
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          
          const message = decodeMessage(value);
          await handleMessage(session, message, writer);
        }
      } else {
        await writer.write(encodeMessage({
          type: 'auth_failed',
          error: 'Invalid token',
        }));
        writer.close();
      }
    }
  } catch (error) {
    console.error('Stream error:', error);
  } finally {
    reader.releaseLock();
  }
}

// Handle incoming messages
async function handleMessage(
  session: Session, 
  message: any, 
  writer: WritableStreamDefaultWriter
) {
  console.log(`Message from ${session.id}:`, message);
  
  switch (message.type) {
    case 'subscribe':
      await handleSubscribe(session, message.channel);
      break;
      
    case 'unsubscribe':
      await handleUnsubscribe(session, message.channel);
      break;
      
    case 'message':
      await handleChannelMessage(session, message);
      break;
      
    case 'ping':
      await writer.write(encodeMessage({ type: 'pong', timestamp: Date.now() }));
      break;
      
    default:
      // Forward to Laravel for business logic
      const response = await forwardToLaravel(session, message);
      if (response) {
        await writer.write(encodeMessage(response));
      }
  }
}

// Handle datagrams (unreliable, low-latency)
async function handleDatagrams(session: Session) {
  const reader = session.transport.datagrams.readable.getReader();
  const writer = session.transport.datagrams.writable.getWriter();
  
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      
      const message = msgpack.decode(new Uint8Array(value));
      
      // Handle real-time updates (game state, cursor, typing)
      if (message.type === 'position' || message.type === 'cursor' || message.type === 'typing') {
        // Broadcast to other sessions in the same room
        broadcastDatagram(session, message);
      }
    }
  } catch (error) {
    console.error('Datagram error:', error);
  }
}

// Channel subscription
async function handleSubscribe(session: Session, channel: string) {
  session.channels.add(channel);
  
  // Store in Redis for persistence
  await redis.sadd(`channel:${channel}:sessions`, session.id);
  await redis.sadd(`session:${session.id}:channels`, channel);
  
  // Subscribe to Redis pub/sub for this channel
  await subClient.subscribe(`channel:${channel}`);
  
  console.log(`Session ${session.id} subscribed to ${channel}`);
}

// Channel unsubscription
async function handleUnsubscribe(session: Session, channel: string) {
  session.channels.delete(channel);
  
  await redis.srem(`channel:${channel}:sessions`, session.id);
  await redis.srem(`session:${session.id}:channels`, channel);
  
  console.log(`Session ${session.id} unsubscribed from ${channel}`);
}

// Handle channel messages
async function handleChannelMessage(session: Session, message: any) {
  const { channel, data } = message;
  
  // Forward to Laravel for processing
  const response = await forwardToLaravel(session, {
    type: 'channel_message',
    channel,
    data,
    sessionId: session.id,
    userId: session.userId,
  });
  
  // Broadcast to channel subscribers
  if (response && response.broadcast) {
    await broadcastToChannel(channel, response.data, session.id);
  }
}

// Broadcast to channel
async function broadcastToChannel(channel: string, data: any, excludeSessionId?: string) {
  const sessionIds = await redis.smembers(`channel:${channel}:sessions`);
  
  for (const sessionId of sessionIds) {
    if (sessionId === excludeSessionId) continue;
    
    const session = sessions.get(sessionId);
    if (session) {
      try {
        const stream = await session.transport.createBidirectionalStream();
        const writer = stream.writable.getWriter();
        
        await writer.write(encodeMessage({
          type: 'channel_broadcast',
          channel,
          data,
        }));
        
        writer.close();
      } catch (error) {
        console.error(`Failed to broadcast to session ${sessionId}:`, error);
      }
    }
  }
}

// Broadcast datagram
function broadcastDatagram(sender: Session, message: any) {
  const encoded = msgpack.encode(message);
  
  sessions.forEach((session) => {
    if (session.id === sender.id) return;
    
    // Check if in same room/channel
    if (message.room && session.channels.has(message.room)) {
      try {
        const writer = session.transport.datagrams.writable.getWriter();
        writer.write(encoded);
        writer.releaseLock();
      } catch (error) {
        console.error(`Failed to send datagram to ${session.id}:`, error);
      }
    }
  });
}

// Forward to Laravel backend
async function forwardToLaravel(session: Session, message: any): Promise<any> {
  try {
    const response = await fetch(`${process.env.LARAVEL_URL}/api/webtransport/handle`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-WebTransport-Session': session.id,
        'X-User-Id': session.userId?.toString() || '',
      },
      body: JSON.stringify(message),
    });
    
    if (response.ok) {
      return await response.json();
    }
  } catch (error) {
    console.error('Laravel forward error:', error);
  }
  
  return null;
}

// Notify Laravel about events
async function notifyLaravel(event: string, data: any) {
  try {
    await fetch(`${process.env.LARAVEL_URL}/api/webtransport/event`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ event, data }),
    });
  } catch (error) {
    console.error('Laravel notification error:', error);
  }
}

// Validate authentication token
async function validateAuth(token: string): Promise<boolean> {
  try {
    const response = await fetch(`${process.env.LARAVEL_URL}/api/auth/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
    });
    
    return response.ok;
  } catch (error) {
    console.error('Auth validation error:', error);
    return false;
  }
}

// Session cleanup
async function handleSessionClose(sessionId: string) {
  const session = sessions.get(sessionId);
  if (!session) return;
  
  console.log(`Session closed: ${sessionId}`);
  
  // Clean up Redis
  const channels = await redis.smembers(`session:${sessionId}:channels`);
  for (const channel of channels) {
    await redis.srem(`channel:${channel}:sessions`, sessionId);
  }
  await redis.del(`session:${sessionId}:channels`);
  
  // Notify Laravel
  await notifyLaravel('connection.closed', {
    sessionId,
    userId: session.userId,
  });
  
  sessions.delete(sessionId);
}

// Utility functions
function generateSessionId(): string {
  return createHash('sha256')
    .update(Date.now().toString() + Math.random().toString())
    .digest('hex')
    .substring(0, 32);
}

function encodeMessage(message: any): Uint8Array {
  return new TextEncoder().encode(JSON.stringify(message));
}

function decodeMessage(data: ArrayBuffer | Uint8Array): any {
  return JSON.parse(new TextDecoder().decode(data));
}

// HTTP endpoints for Laravel to call
app.post('/send-to-session', async (req, res) => {
  const { sessionId, message } = req.body;
  
  const session = sessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }
  
  try {
    const stream = await session.transport.createBidirectionalStream();
    const writer = stream.writable.getWriter();
    
    await writer.write(encodeMessage(message));
    writer.close();
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to send message' });
  }
});

app.post('/broadcast-to-channel', async (req, res) => {
  const { channel, message } = req.body;
  
  await broadcastToChannel(channel, message);
  
  res.json({ success: true });
});

app.get('/sessions', (req, res) => {
  const sessionList = Array.from(sessions.values()).map(s => ({
    id: s.id,
    userId: s.userId,
    channels: Array.from(s.channels),
    connectedAt: s.connectedAt,
  }));
  
  res.json({ sessions: sessionList });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    sessions: sessions.size,
    uptime: process.uptime(),
  });
});

// Redis pub/sub for Laravel -> Node communication
subClient.on('message', async (channel: string, message: string) => {
  try {
    const data = JSON.parse(message);
    
    if (channel.startsWith('channel:')) {
      const channelName = channel.replace('channel:', '');
      await broadcastToChannel(channelName, data);
    } else if (channel.startsWith('session:')) {
      const sessionId = channel.replace('session:', '');
      const session = sessions.get(sessionId);
      
      if (session) {
        const stream = await session.transport.createBidirectionalStream();
        const writer = stream.writable.getWriter();
        await writer.write(encodeMessage(data));
        writer.close();
      }
    }
  } catch (error) {
    console.error('Redis message error:', error);
  }
});

// Start HTTP server
const HTTP_PORT = process.env.HTTP_PORT || 3001;
app.listen(HTTP_PORT, () => {
  console.log(`HTTP API running on port ${HTTP_PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down...');
  
  // Close all sessions
  for (const session of sessions.values()) {
    session.transport.close();
  }
  
  await redis.quit();
  await pubClient.quit();
  await subClient.quit();
  
  process.exit(0);
});
```

## Laravel Integration

### Laravel Service for Node.js Communication

```php
<?php
// app/Services/NodeWebTransportService.php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Log;

class NodeWebTransportService
{
    private string $nodeUrl;
    
    public function __construct()
    {
        $this->nodeUrl = config('services.webtransport.node_url', 'http://localhost:3001');
    }
    
    /**
     * Send message to specific session
     */
    public function sendToSession(string $sessionId, array $message): bool
    {
        try {
            $response = Http::post("{$this->nodeUrl}/send-to-session", [
                'sessionId' => $sessionId,
                'message' => $message,
            ]);
            
            return $response->successful();
        } catch (\Exception $e) {
            Log::error('Failed to send to session', [
                'sessionId' => $sessionId,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }
    
    /**
     * Broadcast to channel
     */
    public function broadcastToChannel(string $channel, array $message): bool
    {
        try {
            // Option 1: HTTP API
            $response = Http::post("{$this->nodeUrl}/broadcast-to-channel", [
                'channel' => $channel,
                'message' => $message,
            ]);
            
            // Option 2: Redis pub/sub (faster)
            Redis::publish("channel:{$channel}", json_encode($message));
            
            return true;
        } catch (\Exception $e) {
            Log::error('Failed to broadcast to channel', [
                'channel' => $channel,
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }
    
    /**
     * Get active sessions
     */
    public function getActiveSessions(): array
    {
        try {
            $response = Http::get("{$this->nodeUrl}/sessions");
            
            if ($response->successful()) {
                return $response->json('sessions', []);
            }
        } catch (\Exception $e) {
            Log::error('Failed to get sessions', ['error' => $e->getMessage()]);
        }
        
        return [];
    }
    
    /**
     * Send direct message via Redis
     */
    public function sendDirectMessage(string $sessionId, array $message): void
    {
        Redis::publish("session:{$sessionId}", json_encode($message));
    }
}
```

### Laravel Controller

```php
<?php
// app/Http/Controllers/WebTransportController.php

namespace App\Http\Controllers;

use App\Services\NodeWebTransportService;
use Illuminate\Http\Request;
use App\Models\User;
use App\Events\MessageSent;

class WebTransportController extends Controller
{
    public function __construct(
        private NodeWebTransportService $wtService
    ) {}
    
    /**
     * Handle incoming message from Node.js
     */
    public function handle(Request $request)
    {
        $sessionId = $request->header('X-WebTransport-Session');
        $userId = $request->header('X-User-Id');
        $message = $request->all();
        
        switch ($message['type']) {
            case 'channel_message':
                return $this->handleChannelMessage($userId, $message);
                
            case 'private_message':
                return $this->handlePrivateMessage($userId, $message);
                
            case 'room_action':
                return $this->handleRoomAction($userId, $message);
                
            default:
                return response()->json(['error' => 'Unknown message type'], 400);
        }
    }
    
    /**
     * Handle WebTransport events from Node.js
     */
    public function event(Request $request)
    {
        $event = $request->input('event');
        $data = $request->input('data');
        
        switch ($event) {
            case 'connection.opened':
                // Log connection
                activity()
                    ->withProperties($data)
                    ->log('WebTransport connection opened');
                break;
                
            case 'connection.closed':
                // Clean up user session
                if (isset($data['userId'])) {
                    cache()->forget("user:online:{$data['userId']}");
                }
                break;
        }
        
        return response()->json(['status' => 'ok']);
    }
    
    /**
     * Send message to user
     */
    public function sendMessage(Request $request)
    {
        $request->validate([
            'user_id' => 'required|exists:users,id',
            'message' => 'required|string',
        ]);
        
        // Get user's session
        $sessionId = cache()->get("user:session:{$request->user_id}");
        
        if (!$sessionId) {
            return response()->json(['error' => 'User not connected'], 404);
        }
        
        // Send via Node.js
        $this->wtService->sendToSession($sessionId, [
            'type' => 'message',
            'from' => auth()->id(),
            'content' => $request->message,
            'timestamp' => now()->toIso8601String(),
        ]);
        
        return response()->json(['status' => 'sent']);
    }
    
    private function handleChannelMessage($userId, $message)
    {
        // Process message (save to DB, etc.)
        $savedMessage = \App\Models\Message::create([
            'user_id' => $userId,
            'channel' => $message['channel'],
            'content' => $message['data']['content'],
        ]);
        
        // Broadcast to channel
        event(new MessageSent($savedMessage));
        
        return response()->json([
            'broadcast' => true,
            'data' => [
                'id' => $savedMessage->id,
                'user' => $savedMessage->user->only(['id', 'name', 'avatar']),
                'content' => $savedMessage->content,
                'created_at' => $savedMessage->created_at,
            ],
        ]);
    }
}
```

## Package.json Configuration

```json
{
  "name": "webtransport-server",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "tsx watch server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "start:pm2": "pm2 start ecosystem.config.js",
    "test": "vitest"
  },
  "dependencies": {
    "@fails-components/webtransport": "^0.3.0",
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "ioredis": "^5.3.2",
    "msgpack-lite": "^0.1.26",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "typescript": "^5.3.0",
    "tsx": "^4.6.0",
    "nodemon": "^3.0.2",
    "@types/node": "^20.10.0",
    "@types/express": "^4.17.21",
    "@types/cors": "^2.8.17",
    "vitest": "^1.1.0"
  }
}
```

## PM2 Configuration

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'webtransport-server',
    script: './dist/server.js',
    instances: 1, // WebTransport requires single instance per port
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 4433,
      HTTP_PORT: 3001,
      REDIS_HOST: 'localhost',
      REDIS_PORT: 6379,
      LARAVEL_URL: 'http://localhost:8000',
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
  }]
};
```

## Docker Configuration

```dockerfile
# Dockerfile
FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --production

# Copy source
COPY . .

# Build TypeScript
RUN npm run build

# SSL certificates
COPY ./certs /app/certs

EXPOSE 4433 3001

CMD ["node", "dist/server.js"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  webtransport:
    build: .
    ports:
      - "4433:4433/udp"  # WebTransport (QUIC/UDP)
      - "3001:3001"      # HTTP API
    environment:
      - NODE_ENV=production
      - REDIS_HOST=redis
      - LARAVEL_URL=http://laravel:8000
    volumes:
      - ./certs:/app/certs:ro
      - ./logs:/app/logs
    depends_on:
      - redis
      - laravel
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  laravel:
    build: ./laravel
    ports:
      - "8000:8000"
    environment:
      - APP_ENV=production
      - REDIS_HOST=redis
    depends_on:
      - redis

volumes:
  redis_data:
```

## Client Usage (Nuxt)

```typescript
// composables/useNodeWebTransport.ts
export const useNodeWebTransport = () => {
  const config = useRuntimeConfig();
  
  const connect = async () => {
    const transport = new WebTransport('https://your-server.com:4433');
    await transport.ready;
    
    // Authenticate
    const stream = await transport.createBidirectionalStream();
    const writer = stream.writable.getWriter();
    const reader = stream.readable.getReader();
    
    await writer.write(encodeMessage({
      type: 'auth',
      token: await $auth.getToken(),
      userId: $auth.user.id,
    }));
    
    const { value } = await reader.read();
    const response = decodeMessage(value);
    
    if (response.type === 'auth_success') {
      console.log('Connected with session:', response.sessionId);
      return transport;
    }
    
    throw new Error('Authentication failed');
  };
  
  return { connect };
};
```

## Performance Optimization

### 1. Connection Pooling
- Keep connections alive with heartbeat
- Reuse streams when possible
- Implement connection limits per user

### 2. Message Batching
```typescript
// Batch multiple small messages
const messageBatch: any[] = [];
const batchInterval = setInterval(() => {
  if (messageBatch.length > 0) {
    sendBatch(messageBatch.splice(0));
  }
}, 100); // Send every 100ms
```

### 3. Compression
```typescript
import { compress, decompress } from 'lz-string';

// For large messages
if (message.length > 1000) {
  message = compress(message);
}
```

### 4. Rate Limiting
```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 1000, // 1000 requests
});

app.use('/send-to-session', limiter);
```

## Monitoring

```typescript
// Add Prometheus metrics
import { register, Counter, Gauge, Histogram } from 'prom-client';

const metrics = {
  connections: new Gauge({
    name: 'webtransport_active_connections',
    help: 'Active WebTransport connections',
  }),
  
  messages: new Counter({
    name: 'webtransport_messages_total',
    help: 'Total messages processed',
    labelNames: ['type'],
  }),
  
  latency: new Histogram({
    name: 'webtransport_message_latency',
    help: 'Message processing latency',
    buckets: [0.001, 0.01, 0.1, 0.5, 1, 5],
  }),
};

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Production Checklist

- [ ] SSL certificates configured and valid
- [ ] UDP port 4433 open in firewall
- [ ] Redis connection configured
- [ ] Laravel backend URL set
- [ ] PM2 or Docker configured
- [ ] Monitoring setup (Prometheus/Grafana)
- [ ] Log rotation configured
- [ ] Health checks implemented
- [ ] Rate limiting enabled
- [ ] Error handling comprehensive
- [ ] Graceful shutdown implemented
- [ ] Auto-restart on failure

## Advantages Over PHP Solutions

| Feature | Node.js | PHP (Swoole) | PHP (RoadRunner) |
|---------|---------|--------------|------------------|
| WebTransport Support | ✅ Native | ❌ No | ⚠️ Experimental |
| Performance | Excellent | N/A | Good |
| Complexity | Low | N/A | High |
| Maintenance | Easy | N/A | Complex |
| Community Support | Strong | None | Limited |
| Production Ready | ✅ Yes | ❌ No | ❌ No |

## Conclusion

With Node.js already on your server, this is the optimal solution for WebTransport. It provides:

1. **Production-ready implementation** with mature packages
2. **Direct integration** without protocol bridges
3. **Excellent performance** with V8's async handling
4. **Easy maintenance** with familiar Node.js ecosystem
5. **Seamless Laravel integration** via HTTP/Redis

This architecture gives you the best of both worlds: Node.js for real-time WebTransport and Laravel for business logic and data persistence.
