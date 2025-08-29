# WebTransport Implementation with Nuxt 4

## Prerequisites

### System Requirements
- Node.js 20.x or higher
- npm 10.x or pnpm 8.x
- Nuxt 4.x
- SSL certificate for HTTPS

### Required Packages

```bash
# Core WebTransport support
npm install @nuxt/nitro
npm install h3
npm install crossws

# WebTransport client utilities
npm install webtransport-ponyfill
npm install msgpack-lite
npm install eventemitter3

# Development tools
npm install -D @types/node
npm install -D vitest
```

## Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Nuxt 4    │◄────►│  WebTransport│◄────►│  Laravel    │
│   Client    │      │   Protocol   │      │   Backend   │
└─────────────┘      └──────────────┘      └─────────────┘
       │                     │                      │
       ▼                     ▼                      ▼
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Stores    │      │    Streams   │      │   Octane    │
│   (Pinia)   │      │  & Datagrams │      │ RoadRunner  │
└─────────────┘      └──────────────┘      └─────────────┘
```

## Step 1: Nuxt Configuration

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  compatibilityDate: '2024-11-01',
  
  experimental: {
    payloadExtraction: false,
    renderJsonPayloads: true,
  },

  nitro: {
    experimental: {
      websocket: true,
      wasm: true,
    },
    rollupConfig: {
      external: ['webtransport'],
    },
  },

  runtimeConfig: {
    public: {
      webTransport: {
        url: process.env.NUXT_PUBLIC_WEBTRANSPORT_URL || 'https://localhost:443/webtransport',
        autoConnect: true,
        reconnect: true,
        reconnectDelay: 1000,
        maxReconnectAttempts: 5,
        heartbeatInterval: 30000,
      },
    },
  },

  modules: [
    '@pinia/nuxt',
    '@nuxtjs/tailwindcss',
  ],

  vite: {
    optimizeDeps: {
      include: ['msgpack-lite', 'eventemitter3'],
    },
    server: {
      https: {
        cert: './certificates/localhost.pem',
        key: './certificates/localhost-key.pem',
      },
    },
  },

  typescript: {
    strict: true,
    typeCheck: true,
  },
})
```

## Step 2: WebTransport Composable

```typescript
// composables/useWebTransport.ts
import { WebTransport } from 'webtransport-ponyfill'
import EventEmitter from 'eventemitter3'
import msgpack from 'msgpack-lite'

export interface WebTransportOptions {
  url: string
  token?: string
  autoConnect?: boolean
  reconnect?: boolean
  reconnectDelay?: number
  maxReconnectAttempts?: number
  heartbeatInterval?: number
}

export interface WebTransportMessage {
  type: string
  channel?: string
  data: any
  timestamp?: number
}

class WebTransportClient extends EventEmitter {
  private transport: WebTransport | null = null
  private options: WebTransportOptions
  private reconnectAttempts = 0
  private reconnectTimer: NodeJS.Timeout | null = null
  private heartbeatTimer: NodeJS.Timeout | null = null
  private sessionId: string | null = null
  private streams: Map<number, WritableStreamDefaultWriter> = new Map()
  private streamCounter = 0
  private isConnecting = false
  private messageQueue: WebTransportMessage[] = []

  constructor(options: WebTransportOptions) {
    super()
    this.options = {
      autoConnect: true,
      reconnect: true,
      reconnectDelay: 1000,
      maxReconnectAttempts: 5,
      heartbeatInterval: 30000,
      ...options,
    }

    if (this.options.autoConnect) {
      this.connect()
    }
  }

  async connect(): Promise<void> {
    if (this.isConnecting || this.isConnected()) {
      return
    }

    this.isConnecting = true
    this.emit('connecting')

    try {
      // Add authentication token to URL if provided
      const url = new URL(this.options.url)
      if (this.options.token) {
        url.searchParams.set('token', this.options.token)
      }

      // Create WebTransport connection
      this.transport = new WebTransport(url.toString())
      
      // Wait for connection to be ready
      await this.transport.ready
      
      this.isConnecting = false
      this.reconnectAttempts = 0
      
      // Get session ID from server
      await this.authenticate()
      
      // Setup handlers
      this.setupTransportHandlers()
      this.startHeartbeat()
      
      // Process queued messages
      this.processMessageQueue()
      
      this.emit('connected', { sessionId: this.sessionId })
      
      console.log('[WebTransport] Connected:', this.sessionId)
    } catch (error) {
      this.isConnecting = false
      console.error('[WebTransport] Connection failed:', error)
      this.emit('error', error)
      this.handleReconnect()
    }
  }

  private async authenticate(): Promise<void> {
    if (!this.transport) return

    const stream = await this.transport.createBidirectionalStream()
    const writer = stream.writable.getWriter()
    const reader = stream.readable.getReader()

    // Send authentication request
    await this.writeToStream(writer, {
      type: 'auth',
      token: this.options.token,
    })

    // Read authentication response
    const { value } = await reader.read()
    if (value) {
      const response = this.decodeMessage(value)
      if (response.type === 'auth_success') {
        this.sessionId = response.sessionId
      } else {
        throw new Error('Authentication failed')
      }
    }

    writer.close()
    reader.releaseLock()
  }

  private setupTransportHandlers(): void {
    if (!this.transport) return

    // Handle connection close
    this.transport.closed
      .then(() => {
        console.log('[WebTransport] Connection closed')
        this.handleDisconnect()
      })
      .catch((error) => {
        console.error('[WebTransport] Connection closed with error:', error)
        this.handleDisconnect()
      })

    // Accept incoming bidirectional streams
    this.acceptBidirectionalStreams()
    
    // Accept incoming unidirectional streams
    this.acceptUnidirectionalStreams()
    
    // Handle incoming datagrams
    this.handleDatagrams()
  }

  private async acceptBidirectionalStreams(): Promise<void> {
    if (!this.transport) return

    const reader = this.transport.incomingBidirectionalStreams.getReader()
    
    try {
      while (true) {
        const { value: stream, done } = await reader.read()
        if (done) break
        
        this.handleIncomingStream(stream)
      }
    } catch (error) {
      console.error('[WebTransport] Error accepting bidirectional streams:', error)
    }
  }

  private async acceptUnidirectionalStreams(): Promise<void> {
    if (!this.transport) return

    const reader = this.transport.incomingUnidirectionalStreams.getReader()
    
    try {
      while (true) {
        const { value: stream, done } = await reader.read()
        if (done) break
        
        this.handleIncomingUnidirectionalStream(stream)
      }
    } catch (error) {
      console.error('[WebTransport] Error accepting unidirectional streams:', error)
    }
  }

  private async handleIncomingStream(stream: any): Promise<void> {
    const reader = stream.readable.getReader()
    
    try {
      while (true) {
        const { value, done } = await reader.read()
        if (done) break
        
        const message = this.decodeMessage(value)
        this.handleMessage(message)
      }
    } catch (error) {
      console.error('[WebTransport] Error reading stream:', error)
    } finally {
      reader.releaseLock()
    }
  }

  private async handleIncomingUnidirectionalStream(stream: any): Promise<void> {
    const reader = stream.getReader()
    
    try {
      while (true) {
        const { value, done } = await reader.read()
        if (done) break
        
        const message = this.decodeMessage(value)
        this.handleMessage(message)
      }
    } catch (error) {
      console.error('[WebTransport] Error reading unidirectional stream:', error)
    } finally {
      reader.releaseLock()
    }
  }

  private async handleDatagrams(): Promise<void> {
    if (!this.transport) return

    const reader = this.transport.datagrams.readable.getReader()
    
    try {
      while (true) {
        const { value, done } = await reader.read()
        if (done) break
        
        const message = msgpack.decode(new Uint8Array(value))
        this.emit('datagram', message)
        
        // Handle specific datagram types
        if (message.type === 'typing' || message.type === 'cursor') {
          this.emit(message.type, message.data)
        }
      }
    } catch (error) {
      console.error('[WebTransport] Error reading datagrams:', error)
    } finally {
      reader.releaseLock()
    }
  }

  private handleMessage(message: WebTransportMessage): void {
    // Handle different message types
    switch (message.type) {
      case 'pong':
        // Heartbeat response
        break
        
      case 'message':
        this.emit('message', message)
        if (message.channel) {
          this.emit(`channel:${message.channel}`, message.data)
        }
        break
        
      case 'error':
        this.emit('error', message.data)
        break
        
      case 'notification':
        this.emit('notification', message.data)
        break
        
      default:
        this.emit(message.type, message.data)
    }
  }

  async send(message: WebTransportMessage): Promise<void> {
    if (!this.isConnected()) {
      // Queue message if not connected
      this.messageQueue.push(message)
      
      // Try to reconnect
      if (this.options.reconnect && !this.isConnecting) {
        this.connect()
      }
      return
    }

    try {
      const stream = await this.transport!.createBidirectionalStream()
      const writer = stream.writable.getWriter()
      
      await this.writeToStream(writer, message)
      
      writer.close()
    } catch (error) {
      console.error('[WebTransport] Error sending message:', error)
      this.emit('error', error)
    }
  }

  async sendDatagram(data: any): Promise<void> {
    if (!this.isConnected()) {
      console.warn('[WebTransport] Cannot send datagram: not connected')
      return
    }

    try {
      const writer = this.transport!.datagrams.writable.getWriter()
      const encoded = msgpack.encode(data)
      
      await writer.write(encoded)
      writer.releaseLock()
    } catch (error) {
      console.error('[WebTransport] Error sending datagram:', error)
    }
  }

  async subscribe(channel: string): Promise<void> {
    await this.send({
      type: 'subscribe',
      channel,
      data: {},
    })
  }

  async unsubscribe(channel: string): Promise<void> {
    await this.send({
      type: 'unsubscribe',
      channel,
      data: {},
    })
  }

  private async writeToStream(writer: WritableStreamDefaultWriter, message: any): Promise<void> {
    const encoded = this.encodeMessage(message)
    await writer.write(encoded)
  }

  private encodeMessage(message: any): Uint8Array {
    const json = JSON.stringify(message)
    const encoder = new TextEncoder()
    return encoder.encode(json)
  }

  private decodeMessage(data: ArrayBuffer | Uint8Array): any {
    const decoder = new TextDecoder()
    const json = decoder.decode(data)
    return JSON.parse(json)
  }

  private startHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer)
    }

    this.heartbeatTimer = setInterval(() => {
      if (this.isConnected()) {
        this.send({ type: 'ping', data: {} })
      }
    }, this.options.heartbeatInterval!)
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = null
    }
  }

  private handleDisconnect(): void {
    this.transport = null
    this.sessionId = null
    this.streams.clear()
    this.stopHeartbeat()
    
    this.emit('disconnected')
    
    this.handleReconnect()
  }

  private handleReconnect(): void {
    if (!this.options.reconnect) return
    
    if (this.reconnectAttempts >= this.options.maxReconnectAttempts!) {
      this.emit('reconnect_failed')
      return
    }

    this.reconnectAttempts++
    const delay = this.options.reconnectDelay! * Math.pow(2, this.reconnectAttempts - 1)
    
    console.log(`[WebTransport] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`)
    
    this.reconnectTimer = setTimeout(() => {
      this.connect()
    }, delay)
  }

  private processMessageQueue(): void {
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift()!
      this.send(message)
    }
  }

  isConnected(): boolean {
    return this.transport !== null && this.sessionId !== null
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }

    this.options.reconnect = false
    
    if (this.transport) {
      this.transport.close()
      this.transport = null
    }
    
    this.stopHeartbeat()
    this.sessionId = null
    this.streams.clear()
    this.messageQueue = []
    
    this.emit('disconnected')
  }

  getSessionId(): string | null {
    return this.sessionId
  }
}

// Singleton instance
let client: WebTransportClient | null = null

export const useWebTransport = () => {
  const config = useRuntimeConfig()
  const { $auth } = useNuxtApp()

  // Initialize client if not exists
  if (!client) {
    client = new WebTransportClient({
      url: config.public.webTransport.url,
      token: $auth.getToken(),
      ...config.public.webTransport,
    })
  }

  const isConnected = ref(client.isConnected())
  const sessionId = ref(client.getSessionId())
  const connectionState = ref<'disconnected' | 'connecting' | 'connected'>('disconnected')

  // Update reactive state on events
  client.on('connected', (data) => {
    isConnected.value = true
    sessionId.value = data.sessionId
    connectionState.value = 'connected'
  })

  client.on('connecting', () => {
    connectionState.value = 'connecting'
  })

  client.on('disconnected', () => {
    isConnected.value = false
    sessionId.value = null
    connectionState.value = 'disconnected'
  })

  return {
    client,
    isConnected: readonly(isConnected),
    sessionId: readonly(sessionId),
    connectionState: readonly(connectionState),
    connect: () => client!.connect(),
    disconnect: () => client!.disconnect(),
    send: (message: WebTransportMessage) => client!.send(message),
    sendDatagram: (data: any) => client!.sendDatagram(data),
    subscribe: (channel: string) => client!.subscribe(channel),
    unsubscribe: (channel: string) => client!.unsubscribe(channel),
    on: (event: string, handler: Function) => client!.on(event, handler),
    off: (event: string, handler: Function) => client!.off(event, handler),
  }
}
```

## Step 3: Pinia Store for WebTransport

```typescript
// stores/webtransport.ts
import { defineStore } from 'pinia'

interface Message {
  id: string
  channel: string
  user: {
    id: number
    name: string
    avatar?: string
  }
  content: string
  type: 'text' | 'image' | 'file'
  timestamp: string
  read?: boolean
}

interface TypingUser {
  userId: number
  userName: string
  roomId: number
}

export const useWebTransportStore = defineStore('webtransport', () => {
  const { client, isConnected, sessionId } = useWebTransport()
  
  // State
  const messages = ref<Map<string, Message[]>>(new Map())
  const typingUsers = ref<Map<number, TypingUser[]>>(new Map())
  const onlineUsers = ref<Set<number>>(new Set())
  const notifications = ref<any[]>([])
  
  // Computed
  const getChannelMessages = computed(() => (channel: string) => {
    return messages.value.get(channel) || []
  })
  
  const getTypingUsers = computed(() => (roomId: number) => {
    return typingUsers.value.get(roomId) || []
  })
  
  // Actions
  const initializeWebTransport = () => {
    // Handle incoming messages
    client.on('channel:chat', (data: any) => {
      handleChatMessage(data)
    })
    
    // Handle typing indicators via datagram
    client.on('typing', (data: any) => {
      handleTypingIndicator(data)
    })
    
    // Handle notifications
    client.on('channel:notifications', (data: any) => {
      handleNotification(data)
    })
    
    // Handle user status updates
    client.on('user_status', (data: any) => {
      handleUserStatus(data)
    })
    
    // Subscribe to default channels
    client.on('connected', async () => {
      await client.subscribe('chat')
      await client.subscribe('notifications')
    })
  }
  
  const sendMessage = async (channel: string, content: string, type: 'text' | 'image' | 'file' = 'text') => {
    await client.send({
      type: 'message',
      channel: 'chat',
      data: {
        action: 'send_message',
        channel,
        content,
        type,
      },
    })
  }
  
  const sendTypingIndicator = (roomId: number, isTyping: boolean) => {
    // Use datagram for low-latency typing indicators
    client.sendDatagram({
      type: 'typing',
      roomId,
      isTyping,
    })
  }
  
  const markAsRead = async (channel: string, messageIds: string[]) => {
    await client.send({
      type: 'message',
      channel: 'chat',
      data: {
        action: 'mark_read',
        channel,
        messageIds,
      },
    })
  }
  
  const joinRoom = async (roomId: number) => {
    await client.send({
      type: 'message',
      channel: 'chat',
      data: {
        action: 'join_room',
        roomId,
      },
    })
  }
  
  const leaveRoom = async (roomId: number) => {
    await client.send({
      type: 'message',
      channel: 'chat',
      data: {
        action: 'leave_room',
        roomId,
      },
    })
  }
  
  // Handlers
  const handleChatMessage = (data: any) => {
    if (data.action === 'new_message') {
      const channel = data.channel || 'general'
      const channelMessages = messages.value.get(channel) || []
      
      channelMessages.push({
        id: data.message.id,
        channel,
        user: data.message.user,
        content: data.message.content,
        type: data.message.type,
        timestamp: data.message.created_at,
        read: false,
      })
      
      messages.value.set(channel, channelMessages)
    }
  }
  
  const handleTypingIndicator = (data: any) => {
    const roomId = data.roomId
    const userId = data.user_id
    
    if (data.is_typing) {
      const roomTypingUsers = typingUsers.value.get(roomId) || []
      
      if (!roomTypingUsers.find(u => u.userId === userId)) {
        roomTypingUsers.push({
          userId,
          userName: data.user_name,
          roomId,
        })
        typingUsers.value.set(roomId, roomTypingUsers)
      }
      
      // Auto-remove after 3 seconds
      setTimeout(() => {
        removeTypingUser(roomId, userId)
      }, 3000)
    } else {
      removeTypingUser(roomId, userId)
    }
  }
  
  const removeTypingUser = (roomId: number, userId: number) => {
    const roomTypingUsers = typingUsers.value.get(roomId) || []
    const filtered = roomTypingUsers.filter(u => u.userId !== userId)
    typingUsers.value.set(roomId, filtered)
  }
  
  const handleNotification = (data: any) => {
    notifications.value.push({
      id: Date.now(),
      ...data,
      timestamp: new Date().toISOString(),
    })
  }
  
  const handleUserStatus = (data: any) => {
    if (data.status === 'online') {
      onlineUsers.value.add(data.userId)
    } else {
      onlineUsers.value.delete(data.userId)
    }
  }
  
  // Cleanup
  const cleanup = () => {
    client.off('channel:chat', handleChatMessage)
    client.off('typing', handleTypingIndicator)
    client.off('channel:notifications', handleNotification)
    client.off('user_status', handleUserStatus)
  }
  
  return {
    // State
    messages: readonly(messages),
    typingUsers: readonly(typingUsers),
    onlineUsers: readonly(onlineUsers),
    notifications: readonly(notifications),
    isConnected,
    sessionId,
    
    // Computed
    getChannelMessages,
    getTypingUsers,
    
    // Actions
    initializeWebTransport,
    sendMessage,
    sendTypingIndicator,
    markAsRead,
    joinRoom,
    leaveRoom,
    cleanup,
  }
})
```

## Step 4: Chat Component Example

```vue
<!-- components/WebTransportChat.vue -->
<template>
  <div class="chat-container h-screen flex flex-col">
    <!-- Connection Status -->
    <div class="connection-status p-4 bg-gray-100 dark:bg-gray-800">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div 
            :class="[
              'w-3 h-3 rounded-full',
              connectionState === 'connected' ? 'bg-green-500' : 
              connectionState === 'connecting' ? 'bg-yellow-500 animate-pulse' : 
              'bg-red-500'
            ]"
          />
          <span class="text-sm">
            {{ connectionState === 'connected' ? 'Connected' : 
               connectionState === 'connecting' ? 'Connecting...' : 
               'Disconnected' }}
          </span>
        </div>
        <button 
          v-if="connectionState === 'disconnected'"
          @click="reconnect"
          class="px-3 py-1 text-sm bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          Reconnect
        </button>
      </div>
    </div>

    <!-- Messages -->
    <div 
      ref="messagesContainer"
      class="flex-1 overflow-y-auto p-4 space-y-4"
    >
      <TransitionGroup name="message">
        <div
          v-for="message in messages"
          :key="message.id"
          :class="[
            'message flex gap-3',
            message.user.id === currentUserId ? 'flex-row-reverse' : ''
          ]"
        >
          <img
            :src="message.user.avatar || '/default-avatar.png'"
            :alt="message.user.name"
            class="w-10 h-10 rounded-full"
          >
          
          <div 
            :class="[
              'max-w-md px-4 py-2 rounded-lg',
              message.user.id === currentUserId 
                ? 'bg-blue-500 text-white' 
                : 'bg-gray-200 dark:bg-gray-700'
            ]"
          >
            <div class="text-sm font-semibold mb-1">
              {{ message.user.name }}
            </div>
            <div class="break-words">
              {{ message.content }}
            </div>
            <div class="text-xs opacity-70 mt-1">
              {{ formatTime(message.timestamp) }}
            </div>
          </div>
        </div>
      </TransitionGroup>
      
      <!-- Typing Indicators -->
      <div 
        v-if="typingUsers.length > 0"
        class="typing-indicator flex items-center gap-2 text-sm text-gray-500"
      >
        <div class="flex gap-1">
          <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0ms" />
          <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 150ms" />
          <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 300ms" />
        </div>
        <span>
          {{ typingUsersText }}
        </span>
      </div>
    </div>

    <!-- Input Area -->
    <div class="input-area p-4 border-t border-gray-200 dark:border-gray-700">
      <form @submit.prevent="sendMessage" class="flex gap-2">
        <input
          v-model="messageInput"
          @input="handleTyping"
          type="text"
          placeholder="Type a message..."
          class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg 
                 bg-white dark:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
        <button
          type="submit"
          :disabled="!messageInput.trim() || !isConnected"
          class="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 
                 disabled:opacity-50 disabled:cursor-not-allowed transition"
        >
          Send
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useWebTransportStore } from '~/stores/webtransport'

const props = defineProps<{
  channel: string
  roomId: number
  currentUserId: number
}>()

const store = useWebTransportStore()
const { connectionState, isConnected } = useWebTransport()

// Local state
const messageInput = ref('')
const messagesContainer = ref<HTMLElement>()
const isTyping = ref(false)
const typingTimeout = ref<NodeJS.Timeout>()

// Computed
const messages = computed(() => store.getChannelMessages(props.channel))
const typingUsers = computed(() => store.getTypingUsers(props.roomId))
const typingUsersText = computed(() => {
  const users = typingUsers.value
  if (users.length === 0) return ''
  if (users.length === 1) return `${users[0].userName} is typing...`
  if (users.length === 2) return `${users[0].userName} and ${users[1].userName} are typing...`
  return `${users[0].userName} and ${users.length - 1} others are typing...`
})

// Methods
const sendMessage = async () => {
  if (!messageInput.value.trim() || !isConnected.value) return
  
  await store.sendMessage(props.channel, messageInput.value)
  messageInput.value = ''
  
  // Stop typing indicator
  if (isTyping.value) {
    isTyping.value = false
    store.sendTypingIndicator(props.roomId, false)
  }
  
  // Scroll to bottom
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
}

const handleTyping = () => {
  if (!isTyping.value && messageInput.value.trim()) {
    isTyping.value = true
    store.sendTypingIndicator(props.roomId, true)
  }
  
  // Clear previous timeout
  if (typingTimeout.value) {
    clearTimeout(typingTimeout.value)
  }
  
  // Set new timeout to stop typing indicator
  typingTimeout.value = setTimeout(() => {
    if (isTyping.value) {
      isTyping.value = false
      store.sendTypingIndicator(props.roomId, false)
    }
  }, 2000)
}

const reconnect = () => {
  const { connect } = useWebTransport()
  connect()
}

const formatTime = (timestamp: string) => {
  const date = new Date(timestamp)
  return date.toLocaleTimeString('en-US', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

// Lifecycle
onMounted(() => {
  store.initializeWebTransport()
  store.joinRoom(props.roomId)
})

onUnmounted(() => {
  store.leaveRoom(props.roomId)
  if (typingTimeout.value) {
    clearTimeout(typingTimeout.value)
  }
})

// Watch for new messages to scroll
watch(messages, () => {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
})
</script>

<style scoped>
.message-enter-active,
.message-leave-active {
  transition: all 0.3s ease;
}

.message-enter-from {
  opacity: 0;
  transform: translateX(-30px);
}

.message-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
</style>
```

## Step 5: Game Component with Datagrams

```vue
<!-- components/WebTransportGame.vue -->
<template>
  <div class="game-container relative w-full h-screen bg-gray-900 overflow-hidden">
    <!-- Game Canvas -->
    <canvas
      ref="gameCanvas"
      @mousemove="handleMouseMove"
      @click="handleClick"
      class="absolute inset-0 w-full h-full"
    />
    
    <!-- HUD -->
    <div class="absolute top-4 left-4 text-white">
      <div class="bg-black/50 p-4 rounded-lg">
        <div>Players Online: {{ players.size }}</div>
        <div>Score: {{ score }}</div>
        <div>Latency: {{ latency }}ms</div>
      </div>
    </div>
    
    <!-- Performance Stats -->
    <div class="absolute top-4 right-4 text-white">
      <div class="bg-black/50 p-4 rounded-lg text-xs">
        <div>FPS: {{ fps }}</div>
        <div>Updates/s: {{ updatesPerSecond }}</div>
        <div>Datagrams/s: {{ datagramsPerSecond }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
interface Player {
  id: number
  x: number
  y: number
  vx: number
  vy: number
  color: string
  score: number
  lastUpdate: number
}

interface GameState {
  players: Map<number, Player>
  projectiles: any[]
  powerups: any[]
  timestamp: number
}

const { sendDatagram, on, off } = useWebTransport()

// Canvas and rendering
const gameCanvas = ref<HTMLCanvasElement>()
let ctx: CanvasRenderingContext2D | null = null
let animationFrameId: number

// Game state
const players = ref<Map<number, Player>>(new Map())
const localPlayer = ref<Player>({
  id: Date.now(),
  x: 0,
  y: 0,
  vx: 0,
  vy: 0,
  color: '#00ff00',
  score: 0,
  lastUpdate: Date.now(),
})
const score = ref(0)

// Performance metrics
const fps = ref(60)
const latency = ref(0)
const updatesPerSecond = ref(0)
const datagramsPerSecond = ref(0)
let lastFrameTime = performance.now()
let frameCount = 0
let updateCount = 0
let datagramCount = 0

// Input handling
const keys = reactive({
  w: false,
  a: false,
  s: false,
  d: false,
})

// Initialize game
const initGame = () => {
  if (!gameCanvas.value) return
  
  ctx = gameCanvas.value.getContext('2d')
  if (!ctx) return
  
  // Set canvas size
  gameCanvas.value.width = window.innerWidth
  gameCanvas.value.height = window.innerHeight
  
  // Initialize local player position
  localPlayer.value.x = Math.random() * gameCanvas.value.width
  localPlayer.value.y = Math.random() * gameCanvas.value.height
  
  // Start game loop
  gameLoop()
  
  // Start sending position updates
  startPositionUpdates()
  
  // Start performance monitoring
  startPerformanceMonitoring()
}

// Game loop
const gameLoop = () => {
  const currentTime = performance.now()
  const deltaTime = (currentTime - lastFrameTime) / 1000
  lastFrameTime = currentTime
  
  // Update game state
  updateGame(deltaTime)
  
  // Render game
  renderGame()
  
  // Calculate FPS
  frameCount++
  
  animationFrameId = requestAnimationFrame(gameLoop)
}

// Update game state
const updateGame = (deltaTime: number) => {
  // Update local player based on input
  const speed = 300 // pixels per second
  
  if (keys.w) localPlayer.value.vy = -speed
  else if (keys.s) localPlayer.value.vy = speed
  else localPlayer.value.vy *= 0.9
  
  if (keys.a) localPlayer.value.vx = -speed
  else if (keys.d) localPlayer.value.vx = speed
  else localPlayer.value.vx *= 0.9
  
  // Apply velocity
  localPlayer.value.x += localPlayer.value.vx * deltaTime
  localPlayer.value.y += localPlayer.value.vy * deltaTime
  
  // Keep player in bounds
  localPlayer.value.x = Math.max(0, Math.min(gameCanvas.value!.width, localPlayer.value.x))
  localPlayer.value.y = Math.max(0, Math.min(gameCanvas.value!.height, localPlayer.value.y))
  
  // Interpolate other players
  const now = Date.now()
  players.value.forEach((player) => {
    const timeSinceUpdate = (now - player.lastUpdate) / 1000
    player.x += player.vx * timeSinceUpdate
    player.y += player.vy * timeSinceUpdate
  })
  
  updateCount++
}

// Render game
const renderGame = () => {
  if (!ctx || !gameCanvas.value) return
  
  // Clear canvas
  ctx.fillStyle = '#111827'
  ctx.fillRect(0, 0, gameCanvas.value.width, gameCanvas.value.height)
  
  // Draw grid
  ctx.strokeStyle = '#1f2937'
  ctx.lineWidth = 1
  for (let x = 0; x < gameCanvas.value.width; x += 50) {
    ctx.beginPath()
    ctx.moveTo(x, 0)
    ctx.lineTo(x, gameCanvas.value.height)
    ctx.stroke()
  }
  for (let y = 0; y < gameCanvas.value.height; y += 50) {
    ctx.beginPath()
    ctx.moveTo(0, y)
    ctx.lineTo(gameCanvas.value.width, y)
    ctx.stroke()
  }
  
  // Draw other players
  players.value.forEach((player) => {
    drawPlayer(player)
  })
  
  // Draw local player
  drawPlayer(localPlayer.value)
}

// Draw player
const drawPlayer = (player: Player) => {
  if (!ctx) return
  
  ctx.save()
  ctx.translate(player.x, player.y)
  
  // Draw player circle
  ctx.fillStyle = player.color
  ctx.beginPath()
  ctx.arc(0, 0, 20, 0, Math.PI * 2)
  ctx.fill()
  
  // Draw player ID
  ctx.fillStyle = 'white'
  ctx.font = '12px Arial'
  ctx.textAlign = 'center'
  ctx.fillText(`P${player.id % 1000}`, 0, -25)
  
  ctx.restore()
}

// Send position updates via datagram
const startPositionUpdates = () => {
  setInterval(() => {
    // Send local player position via unreliable datagram
    sendDatagram({
      type: 'game_update',
      playerId: localPlayer.value.id,
      x: Math.round(localPlayer.value.x),
      y: Math.round(localPlayer.value.y),
      vx: Math.round(localPlayer.value.vx),
      vy: Math.round(localPlayer.value.vy),
      timestamp: Date.now(),
    })
    
    datagramCount++
  }, 50) // 20 updates per second
}

// Handle incoming game updates
const handleGameUpdate = (data: any) => {
  if (data.playerId === localPlayer.value.id) return
  
  // Update or add player
  const player = players.value.get(data.playerId) || {
    id: data.playerId,
    x: data.x,
    y: data.y,
    vx: data.vx,
    vy: data.vy,
    color: `hsl(${data.playerId % 360}, 70%, 50%)`,
    score: 0,
    lastUpdate: data.timestamp,
  }
  
  player.x = data.x
  player.y = data.y
  player.vx = data.vx
  player.vy = data.vy
  player.lastUpdate = data.timestamp
  
  players.value.set(data.playerId, player)
  
  // Calculate latency
  const roundTripTime = Date.now() - data.timestamp
  latency.value = Math.round(roundTripTime / 2)
}

// Handle mouse move
const handleMouseMove = (event: MouseEvent) => {
  // Could be used for aiming or cursor position sharing
  const rect = gameCanvas.value!.getBoundingClientRect()
  const mouseX = event.clientX - rect.left
  const mouseY = event.clientY - rect.top
  
  // Send cursor position via datagram for other players to see
  sendDatagram({
    type: 'cursor_position',
    playerId: localPlayer.value.id,
    x: mouseX,
    y: mouseY,
  })
}

// Handle click
const handleClick = (event: MouseEvent) => {
  // Could be used for shooting or interaction
  const rect = gameCanvas.value!.getBoundingClientRect()
  const clickX = event.clientX - rect.left
  const clickY = event.clientY - rect.top
  
  // Send click event
  sendDatagram({
    type: 'player_action',
    action: 'shoot',
    playerId: localPlayer.value.id,
    x: clickX,
    y: clickY,
  })
}

// Performance monitoring
const startPerformanceMonitoring = () => {
  setInterval(() => {
    fps.value = frameCount
    updatesPerSecond.value = updateCount
    datagramsPerSecond.value = datagramCount
    
    frameCount = 0
    updateCount = 0
    datagramCount = 0
  }, 1000)
}

// Keyboard input
const handleKeyDown = (event: KeyboardEvent) => {
  const key = event.key.toLowerCase()
  if (key in keys) {
    keys[key as keyof typeof keys] = true
  }
}

const handleKeyUp = (event: KeyboardEvent) => {
  const key = event.key.toLowerCase()
  if (key in keys) {
    keys[key as keyof typeof keys] = false
  }
}

// Lifecycle
onMounted(() => {
  initGame()
  
  // Register event listeners
  window.addEventListener('keydown', handleKeyDown)
  window.addEventListener('keyup', handleKeyUp)
  window.addEventListener('resize', () => {
    if (gameCanvas.value) {
      gameCanvas.value.width = window.innerWidth
      gameCanvas.value.height = window.innerHeight
    }
  })
  
  // Listen for game updates
  on('datagram', (data: any) => {
    if (data.type === 'game_update') {
      handleGameUpdate(data)
    }
  })
})

onUnmounted(() => {
  // Cleanup
  window.removeEventListener('keydown', handleKeyDown)
  window.removeEventListener('keyup', handleKeyUp)
  
  off('datagram', handleGameUpdate)
  
  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId)
  }
})
</script>
```

## Step 6: Testing

```typescript
// tests/webtransport.test.ts
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { WebTransportClient } from '~/composables/useWebTransport'

describe('WebTransport Client', () => {
  let client: WebTransportClient
  
  beforeEach(() => {
    // Mock WebTransport API
    global.WebTransport = vi.fn().mockImplementation(() => ({
      ready: Promise.resolve(),
      closed: new Promise(() => {}),
      close: vi.fn(),
      createBidirectionalStream: vi.fn(),
      createUnidirectionalStream: vi.fn(),
      incomingBidirectionalStreams: {
        getReader: vi.fn(() => ({
          read: vi.fn(),
        })),
      },
      incomingUnidirectionalStreams: {
        getReader: vi.fn(() => ({
          read: vi.fn(),
        })),
      },
      datagrams: {
        readable: {
          getReader: vi.fn(() => ({
            read: vi.fn(),
          })),
        },
        writable: {
          getWriter: vi.fn(() => ({
            write: vi.fn(),
            releaseLock: vi.fn(),
          })),
        },
      },
    }))
    
    client = new WebTransportClient({
      url: 'https://localhost:443/webtransport',
      autoConnect: false,
    })
  })
  
  it('should connect to server', async () => {
    const connectSpy = vi.spyOn(client, 'connect')
    await client.connect()
    
    expect(connectSpy).toHaveBeenCalled()
    expect(client.isConnected()).toBe(true)
  })
  
  it('should send messages', async () => {
    await client.connect()
    
    const message = {
      type: 'test',
      data: { content: 'Hello' },
    }
    
    await expect(client.send(message)).resolves.not.toThrow()
  })
  
  it('should handle reconnection', async () => {
    client.options.reconnect = true
    client.options.maxReconnectAttempts = 3
    
    // Simulate connection failure
    global.WebTransport = vi.fn().mockImplementation(() => {
      throw new Error('Connection failed')
    })
    
    await client.connect()
    
    // Should attempt to reconnect
    expect(client.reconnectAttempts).toBeGreaterThan(0)
  })
  
  it('should queue messages when disconnected', async () => {
    const message = {
      type: 'test',
      data: { content: 'Queued message' },
    }
    
    await client.send(message)
    
    expect(client.messageQueue).toHaveLength(1)
    expect(client.messageQueue[0]).toEqual(message)
  })
})
```

## Deployment Notes

### Environment Variables

```bash
# .env
NUXT_PUBLIC_WEBTRANSPORT_URL=https://api.example.com/webtransport
NUXT_PUBLIC_API_URL=https://api.example.com
```

### Docker Configuration

```dockerfile
# Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]
```

### Performance Optimization

1. **Bundle Size**: Use dynamic imports for WebTransport components
2. **Connection Pooling**: Reuse WebTransport connections across components
3. **Message Batching**: Batch multiple small messages into single stream
4. **Compression**: Use msgpack for smaller payloads
5. **Throttling**: Implement rate limiting for high-frequency updates

## Next Steps

- [Production Deployment Guide](./04-production-deployment.md)
- [Performance Optimization](./05-performance-optimization.md)
- [Security Best Practices](./07-security.md)
