# 🚀 KIẾN TRÚC HỆ THỐNG CHAT APPLICATION

## Microservices Architecture - Production Ready & Cost-Effective

---

## 📋 MỤC LỤC

- [1. Tổng Quan Kiến Trúc](#1-tổng-quan-kiến-trúc)
- [2. Chi Tiết Các Tầng](#2-chi-tiết-các-tầng)
  - [2.1 Client Layer](#21-client-layer)
  - [2.2 API Gateway](#22-api-gateway)
  - [2.3 BFF Layer](#23-bff-layer)
  - [2.4 Core Microservices](#24-core-microservices)
  - [2.5 Event Bus](#25-event-bus)
  - [2.6 Data Layer](#26-data-layer)
- [3. Kiến Trúc Deploy](#3-kiến-trúc-deploy)
- [4. Hạ Tầng Cơ Bản](#4-hạ-tầng-cơ-bản)
- [5. Deploy Từng Component](#5-deploy-từng-component)
- [6. Ước Tính Chi Phí](#6-ước-tính-chi-phí)
- [7. Scaling Strategy](#7-scaling-strategy)

---

## 1. 🏗️ TỔNG QUAN KIẾN TRÚC

### 1.1 Sơ Đồ Kiến Trúc Tổng Thể

```
┌────────────────────────────── CLIENT ──────────────────────────────┐
│                                                                    │
│   🌐 React Web                     📱 React Native                 │
│   - Chat UI                        - Chat UI                       │
│   - Group Management               - Group Management              │
│   - Media Handling                 - Push Notification             │
│                                                                    │
│   REST (HTTPS)              WebSocket (WSS)                        │
└───────────────┬──────────────────────────┬─────────────────────────┘
                │                          │
                ▼                          ▼
┌──────────────────────────── API GATEWAY ───────────────────────────┐
│ Kong / Envoy / Nginx                                               │
│ ✓ JWT Authentication & Verification                                │
│ ✓ Rate Limiting & Throttling                                       │
│ ✓ Request Routing (REST & WebSocket)                               │
│ ✓ Load Balancing                                                   │
└───────────────┬──────────────────────────┬─────────────────────────┘
                │                          │
         REST (JSON)                 WebSocket Upgrade
                │                          │
                ▼                          ▼
┌──────────────────────────── BFF LAYER ─────────────────────────────┐
│ NestJS (Node.js + TypeScript)                                      │
│ ✓ API cho React Web / React Native                                 │
│ ✓ Aggregate data từ multiple services                              │
│ ✓ Transform data phù hợp UI                                        │
│ ✗ KHÔNG xử lý business logic                                       │
│ ✗ KHÔNG kết nối trực tiếp database                                 │
└───────────────┬──────────────────────────┬─────────────────────────┘
                │                          │
                ▼                          ▼
┌──────────────────────── CORE MICROSERVICES ────────────────────────┐
│                                                                    │
│  🔐 Auth Service        👤 User Service        👥 Friend Service   │
│     (NestJS)              (NestJS)               (NestJS)          │
│     - Login/Register      - Profile CRUD         - Friend Request  │
│     - JWT Token           - User Search          - Friend List     │
│     - Refresh Token       - Status Update        - Block User      │
│                                                                    │
│  👨‍👩‍👧 Group Service     🟢 Presence Service     💬 Chat Core     │
│     (NestJS)               (Java)                (Java)            │
│     - Create Group        - Online/Offline       - Send Message    │
│     - Member Mgmt         - Typing Indicator     - Edit Message    │
│     - Group Settings      - Last Seen            - Delete Message  │
│                                                                    │
│  ⚡ Realtime Gateway      🖼 Media Processor     🔔 Notification   │
│     (Java)                 (Java)               (Java/NestJS)      │
│     - WebSocket Hub       - Image Resize         - Push FCM        │
│     - Connection Pool     - Video Compress       - Email           │
│     - Message Broadcast   - Thumbnail Gen        - SMS              │
│                                                                    │
└───────────────┬──────────────────────────┬─────────────────────────┘
                │                          │
        Sync (REST/gRPC)             Async Event
                │                          │
                ▼                          ▼
┌──────────────────────────── EVENT BUS ─────────────────────────────┐
│ Apache Kafka                                           │
│                                                                    │
│ Topics:                                                            │
│ ✓ message.created          - New message events                    │
│ ✓ message.read             - Read receipt tracking                 │
│ ✓ message.delivered        - Delivery confirmation                 │
│ ✓ notification.send        - Push notification queue               │
│ ✓ user.presence.changed    - Online status updates                 │
│ ✓ media.uploaded           - Media processing queue                │
│                                                                    │
└───────────────┬──────────────────────────┬─────────────────────────┘
                │                          │
                ▼                          ▼
┌──────────────────────────── DATA LAYER ────────────────────────────┐
│                                                                    │
│ 🐘 PostgreSQL (Relational Data)                                   │
│    - users (profile, credentials)                                  │
│    - auth_tokens (refresh tokens, sessions)                        │
│    - friends (relationships, requests)                             │
│    - groups (metadata, members, settings)                          │
│                                                                    │
│ 🔷 ScyllaDB / Cassandra (Time-Series Data)                        │
│    - messages (chat history, timeline queries)                     │
│    - message_timeline (inbox per user)                             │
│    - High write throughput, horizontal scaling                     │
│                                                                    │
│ 🔴 Redis (Cache & Real-time State)                                │
│    - online_status (user presence)                                 │
│    - typing_indicator (who is typing)                              │
│    - unread_count (message counters)                               │
│    - session_cache (JWT blacklist, temp data)                      │
│                                                                    │
│ 📦 Object Storage (S3 / MinIO / Cloudflare R2)                    │
│    - images (avatars, photos)                                      │
│    - videos (compressed, transcoded)                               │
│    - files (documents, attachments)                                │
│    - CDN integration for fast delivery                             │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 1.2 Nguyên Tắc Thiết Kế

| Nguyên tắc                 | Mô tả                                                                                                |
| -------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Separation of Concerns** | Mỗi service chỉ xử lý một domain cụ thể                                                              |
| **Single Responsibility**  | BFF không chứa business logic                                                                        |
| **Event-Driven**           | Các service giao tiếp qua Kafka                                                                      |
| **Polyglot**               | Chọn ngôn ngữ phù hợp cho từng service (Java cho performance & scalability, NestJS cho productivity) |
| **Stateless Services**     | All state trong database/cache, dễ scale horizontal                                                  |
| **API Gateway Pattern**    | Centralized authentication, routing, rate limiting                                                   |

---

## 2. 📦 CHI TIẾT CÁC TẦNG

### 2.1 Client Layer

#### 🌐 React Web Application

**Technology Stack:**

- React 18+ với TypeScript
- Redux Toolkit / Zustand (state management)
- Socket.io-client (WebSocket)
- TanStack Query (data fetching)
- Tailwind CSS / Material-UI

**Core Features:**

- Real-time chat interface
- Group chat management
- Media upload & preview
- User profile management
- Friend requests & management
- Responsive design

**Deployment:**

- Platform: **Cloudflare Pages** / Vercel / Netlify
- Build: `npm run build` → static files
- Auto HTTPS + CDN
- **Chi phí: 0$ (Free tier)**

---

#### 📱 React Native Mobile Application

**Technology Stack:**

- React Native 0.72+
- TypeScript
- Redux Toolkit
- Socket.io-client
- React Navigation
- React Native Firebase (Push notifications)

**Core Features:**

- Native chat UI
- Push notifications (FCM)
- Camera integration
- Offline support
- Background message sync

**Deployment:**

- Apple App Store: **$99/năm**
- Google Play Store: **$25 (one-time)**
- CI/CD: GitHub Actions / Bitrise

---

### 2.2 API Gateway

#### Kong / Envoy / Nginx

**Responsibilities:**

| Chức năng             | Mô tả                                           |
| --------------------- | ----------------------------------------------- |
| **Authentication**    | Verify JWT token from headers                   |
| **Rate Limiting**     | Prevent abuse (100 req/min per user)            |
| **Routing**           | Forward requests to appropriate services        |
| **Load Balancing**    | Distribute traffic across service instances     |
| **SSL Termination**   | Handle HTTPS/TLS                                |
| **WebSocket Upgrade** | Proxy WebSocket connections to Realtime Gateway |

**Configuration Example (Kong):**

```yaml
services:
  - name: auth-service
    url: http://auth-service:3001
    routes:
      - name: auth-route
        paths:
          - /api/auth

  - name: bff-service
    url: http://bff-service:3000
    routes:
      - name: bff-route
        paths:
          - /api/v1

plugins:
  - name: jwt
    config:
      secret_is_base64: false
  - name: rate-limiting
    config:
      minute: 100
```

**Deployment:**

- Docker container
- Nginx as reverse proxy (lightweight option)
- **Chi phí: 0$ (open-source)**

---

### 2.3 BFF Layer (Backend for Frontend)

#### NestJS Application

**Technology Stack:**

- NestJS (Node.js + TypeScript)
- Axios / node-fetch (HTTP client)
- Class Validator (DTO validation)

**Responsibilities:**

- ✅ Aggregate data từ multiple microservices
- ✅ Transform API responses phù hợp với UI needs
- ✅ Handle authentication forwarding
- ✅ Optimize số lượng requests từ client
- ❌ **KHÔNG** chứa business logic
- ❌ **KHÔNG** kết nối trực tiếp database

**Example API Endpoint:**

```typescript
// GET /api/v1/chat/conversations
// BFF aggregates data from multiple services
async getConversations(userId: string) {
  const [conversations, unreadCounts, presenceStatus] = await Promise.all([
    this.chatService.getUserConversations(userId),      // Chat Core
    this.chatService.getUnreadCounts(userId),           // Redis
    this.presenceService.getUsersStatus(userIds)        // Presence Service
  ]);

  return this.transformForUI(conversations, unreadCounts, presenceStatus);
}
```

**Deployment:**

- Docker container
- 1 instance (0.5-1GB RAM)
- PM2 for process management
- **Chi phí: Gộp trong VPS**

---

### 2.4 Core Microservices

#### 🔐 Auth Service (NestJS)

**Database:** PostgreSQL

**Core Features:**

- User registration & login
- JWT token generation & validation
- Refresh token mechanism
- Password hashing (bcrypt)
- OAuth integration (Google, Facebook)

**API Endpoints:**

```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh
POST   /api/auth/logout
POST   /api/auth/verify-email
POST   /api/auth/reset-password
```

**Database Schema:**

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  token VARCHAR(512) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

#### 👤 User Service (NestJS)

**Database:** PostgreSQL

**Core Features:**

- User profile CRUD
- Avatar upload
- User search
- Privacy settings

**API Endpoints:**

```
GET    /api/users/:id
PUT    /api/users/:id
GET    /api/users/search?q=keyword
POST   /api/users/:id/avatar
GET    /api/users/:id/settings
PUT    /api/users/:id/settings
```

---

#### 👥 Friend Service (NestJS)

**Database:** PostgreSQL

**Core Features:**

- Send friend requests
- Accept/Reject requests
- Friend list management
- Block users

**API Endpoints:**

```
POST   /api/friends/request
POST   /api/friends/accept/:requestId
POST   /api/friends/reject/:requestId
GET    /api/friends
DELETE /api/friends/:friendId
POST   /api/friends/block/:userId
```

**Database Schema:**

```sql
CREATE TABLE friendships (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  friend_id UUID REFERENCES users(id),
  status VARCHAR(20), -- pending, accepted, blocked
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);
```

---

#### 👨‍👩‍👧 Group Service (NestJS)

**Database:** PostgreSQL

**Core Features:**

- Create/Delete groups
- Add/Remove members
- Group settings (avatar, name)
- Admin permissions

**API Endpoints:**

```
POST   /api/groups
GET    /api/groups/:id
PUT    /api/groups/:id
DELETE /api/groups/:id
POST   /api/groups/:id/members
DELETE /api/groups/:id/members/:userId
PUT    /api/groups/:id/settings
```

---

#### 🟢 Presence Service (Java)

**Database:** Redis

**Core Features:**

- Track online/offline status
- Typing indicators
- Last seen timestamp
- High-performance real-time updates

**Why Java?**

- Spring Boot with reactive programming for high concurrency
- Excellent Redis integration with Spring Data Redis
- Low latency (~5ms response time)
- Enterprise-grade reliability and scalability

**API Endpoints:**

```
POST   /api/presence/online
POST   /api/presence/offline
GET    /api/presence/status/:userId
POST   /api/presence/typing
GET    /api/presence/batch (bulk status check)
```

**Redis Data Structure:**

```
SET user:presence:{userId} "online" EX 300    // 5 min TTL
SET user:lastseen:{userId} {timestamp}
SET typing:{conversationId}:{userId} 1 EX 5   // 5 sec TTL
```

---

#### 💬 Chat Core Service (Java)

**Database:** ScyllaDB / PostgreSQL

**Core Features:**

- Send messages (1-1, group)
- Edit/Delete messages
- Message history & pagination
- Read receipts
- Message search

**Why Java?**

- Spring Boot with JPA for robust database operations
- Excellent Kafka integration for event-driven architecture
- Handle 10,000+ concurrent connections with virtual threads (Java 21)
- Enterprise-grade transaction management

**API Endpoints:**

```
POST   /api/chat/send
PUT    /api/chat/messages/:id
DELETE /api/chat/messages/:id
GET    /api/chat/conversations/:id/messages
POST   /api/chat/messages/:id/read
GET    /api/chat/search?q=keyword
```

**ScyllaDB Schema:**

```cql
CREATE TABLE messages (
  conversation_id UUID,
  message_id TIMEUUID,
  sender_id UUID,
  content TEXT,
  attachments LIST<TEXT>,
  created_at TIMESTAMP,
  PRIMARY KEY (conversation_id, message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);

CREATE TABLE user_conversations (
  user_id UUID,
  conversation_id UUID,
  last_message_time TIMESTAMP,
  unread_count INT,
  PRIMARY KEY (user_id, last_message_time, conversation_id)
) WITH CLUSTERING ORDER BY (last_message_time DESC);
```

---

#### ⚡ Realtime Gateway (Java)

**Core Features:**

- WebSocket connection hub (STOMP protocol)
- Maintain connection pool
- Route messages to correct users
- Handle reconnection logic

**Why Java?**

- Spring WebSocket with STOMP for standardized messaging
- Handle 100,000+ concurrent WebSocket connections per server
- Excellent integration with Spring Security for authentication
- Built-in message broker support

**Architecture:**

```java
// WebSocket Configuration
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
  @Override
  public void configureMessageBroker(MessageBrokerRegistry config) {
    config.enableSimpleBroker("/topic", "/queue");
    config.setApplicationDestinationPrefixes("/app");
  }
}

// Message Broadcasting
@Autowired
private SimpMessagingTemplate messagingTemplate;

public void sendToUser(String username, ChatMessage message) {
  messagingTemplate.convertAndSendToUser(username, "/queue/messages", message);
}
```

**Deployment Considerations:**

- Sticky sessions (load balancer)
- Redis Pub/Sub for multi-instance coordination

---

#### 🖼 Media Processor Service (Java)

**Core Features:**

- Image resize & compress
- Video transcoding
- Thumbnail generation
- Format conversion

**Why Java?**

- Thumbnailator library for efficient image processing
- Spring Boot for robust file handling
- Excellent AWS S3 SDK integration
- Kafka consumer for async processing

**Workflow:**

```
1. User uploads media → Object Storage (S3)
2. Event published to Kafka: media.uploaded
3. Media Processor consumes event
4. Process media (resize, compress)
5. Save processed files to S3
6. Update database with URLs
```

---

#### 🔔 Notification Service (Java / NestJS - Optional)

**Core Features:**

- Firebase Cloud Messaging (FCM)
- Email notifications
- SMS (Twilio)
- In-app notifications

**Kafka Consumer:**

```java
@KafkaListener(topics = "notification.send")
public void handleNotification(NotificationEvent event) {
  switch(event.getType()) {
    case PUSH:
      fcmService.sendPush(event);
      break;
    case EMAIL:
      emailService.send(event);
      break;
  }
}
```

---

### 2.5 Event Bus

#### Apache Kafka / Redpanda

**Why Event-Driven?**

- Decouple services
- Asynchronous processing
- Reliable message delivery
- Easy to add new consumers

**Key Topics:**

| Topic                   | Producer  | Consumer                | Purpose             |
| ----------------------- | --------- | ----------------------- | ------------------- |
| `message.created`       | Chat Core | Notification, Analytics | New message event   |
| `message.read`          | Chat Core | Notification            | Read receipt        |
| `notification.send`     | Multiple  | Notification Service    | Send notifications  |
| `user.presence.changed` | Presence  | Analytics               | Track online status |
| `media.uploaded`        | Chat Core | Media Processor         | Process media files |

**Configuration (Redpanda for Cost-Effective MVP):**

```yaml
# docker-compose.yml
services:
  redpanda:
    image: vectorized/redpanda
    command:
      - redpanda start
      - --smp 1
      - --memory 1G
      - --reserve-memory 0M
    ports:
      - "9092:9092"
```

**Chi phí:** 0$ (self-hosted)

---

### 2.6 Data Layer

#### 🐘 PostgreSQL

**Use Cases:**

- User profiles
- Authentication data
- Friend relationships
- Group metadata
- **Anything requiring ACID transactions**

**Deployment Options:**

| Option               | Chi phí    | Pros                     | Cons                |
| -------------------- | ---------- | ------------------------ | ------------------- |
| Self-hosted (Docker) | 0$         | Full control             | Require maintenance |
| Supabase             | ~$25/month | Managed, free tier 500MB | Limited free tier   |
| Neon                 | ~$20/month | Serverless, auto-scale   | Higher latency      |
| AWS RDS              | ~$15/month | Reliable, backup         | Complex setup       |

**Recommended:** Self-hosted for MVP, migrate to Supabase when scaling

---

#### 🔷 ScyllaDB / Cassandra

**Use Cases:**

- Chat messages (high write throughput)
- Message timeline (time-series queries)
- Horizontal scaling

**MVP Strategy:**

> 💡 **Khuyên dùng PostgreSQL trước, sau đó migrate sang ScyllaDB khi có >100K users**

**Why?**

- PostgreSQL đủ tốt cho MVP (< 100K messages/day)
- Giảm complexity
- Dễ debug & maintain

**Migration Path:**

```
MVP (0-10K users) → PostgreSQL
Growth (10K-100K) → PostgreSQL + read replicas
Scale (100K+)     → ScyllaDB cho messages
```

---

#### 🔴 Redis

**Use Cases:**

| Use Case         | Data Structure                 | TTL       |
| ---------------- | ------------------------------ | --------- |
| Online status    | `SET user:online:{userId}`     | 5 min     |
| Typing indicator | `SET typing:{convId}:{userId}` | 5 sec     |
| Unread count     | `HASH unread:{userId}`         | No expiry |
| Session cache    | `SET session:{token}`          | 1 hour    |
| Rate limiting    | `INCR ratelimit:{userId}`      | 1 min     |

**Deployment:**

- Docker container (512MB-1GB RAM)
- Enable persistence (RDB + AOF)
- **Chi phí:** 0$ (self-hosted)

---

#### 📦 Object Storage

**Options:**

| Provider          | Chi phí    | Bandwidth   | Storage   |
| ----------------- | ---------- | ----------- | --------- |
| **Cloudflare R2** | ~$5/month  | FREE egress | $0.015/GB |
| Backblaze B2      | ~$5/month  | $0.01/GB    | $0.005/GB |
| AWS S3            | ~$10/month | $0.09/GB    | $0.023/GB |
| MinIO (self-host) | VPS cost   | FREE        | FREE      |

**Recommended:** Cloudflare R2 (free bandwidth saves money)

---

## 3. 🏗️ KIẾN TRÚC DEPLOY

### Nguyên Tắc Deploy

✅ **KHÔNG Kubernetes ban đầu** (quá phức tạp & tốn kém)  
✅ **Docker + Docker Compose** (đơn giản, dễ maintain)  
✅ **1-2 VPS là đủ cho MVP**  
✅ **Monorepo hoặc Multi-repo** (tuỳ team preference)

### Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         INTERNET                            │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼──────────┐
         │   Cloudflare DNS     │
         │   + DDoS Protection  │
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │  Cloudflare Pages    │
         │  (React Web Static)  │
         └──────────────────────┘
                     │
         ┌───────────▼──────────┐
         │    VPS #1            │
         │  (Backend Core)      │
         ├──────────────────────┤
         │ - Kong Gateway       │
         │ - BFF (NestJS)       │
         │ - Auth Service       │
         │ - User Service       │
         │ - Friend Service     │
         │ - Group Service      │
         │ - Chat Core (Go)     │
         │ - Realtime GW (Go)   │
         │ - Presence (Go)      │
         │ - Media Proc (Go)    │
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │    VPS #2            │
         │  (Data Layer)        │
         ├──────────────────────┤
         │ - PostgreSQL         │
         │ - Redis              │
         │ - Redpanda (Kafka)   │
         │ - MinIO (optional)   │
         └──────────────────────┘
                     │
         ┌───────────▼──────────┐
         │  Cloudflare R2       │
         │  (Object Storage)    │
         └──────────────────────┘
```

---

## 4. 🖥️ HẠ TẦNG CƠ BẢN

### Recommended VPS Providers

| Provider         | Gói đề xuất    | RAM  | CPU    | Storage   | Bandwidth | Chi phí       |
| ---------------- | -------------- | ---- | ------ | --------- | --------- | ------------- |
| **Hetzner**      | CX31           | 8GB  | 2 vCPU | 80GB SSD  | 20TB      | €10.19 (~$11) |
| **Hetzner**      | CX41           | 16GB | 4 vCPU | 160GB SSD | 20TB      | €18.59 (~$20) |
| **Vultr**        | High Frequency | 8GB  | 2 vCPU | 128GB SSD | 3TB       | $24           |
| **DigitalOcean** | Basic Droplet  | 8GB  | 4 vCPU | 160GB SSD | 5TB       | $48           |
| **Contabo**      | VPS M          | 16GB | 6 vCPU | 400GB SSD | 32TB      | €8.99 (~$10)  |

### Recommended Setup

#### ⭐ Option 1: Budget MVP (< $20/month)

```
VPS #1 (Contabo VPS M - 16GB RAM)
├── All backend services
├── PostgreSQL
├── Redis
└── Redpanda

External:
├── Cloudflare Pages (Frontend) - FREE
└── Cloudflare R2 (Storage) - ~$5/month

💰 Total: ~$15/month
```

#### ⭐ Option 2: Recommended (< $35/month)

```
VPS #1 (Hetzner CX41 - 16GB RAM) - Backend Core
├── Kong Gateway
├── BFF + All NestJS services
├── Java services (Chat, Realtime, Presence, Media)
└── Nginx reverse proxy

VPS #2 (Hetzner CX21 - 4GB RAM) - Data Layer
├── PostgreSQL
├── Redis
└── Redpanda

External:
├── Cloudflare Pages (Frontend) - FREE
└── Cloudflare R2 (Storage) - ~$5/month

💰 Total: ~$35/month
```

#### 🚀 Option 3: Production-Ready (< $60/month)

```
VPS #1 (Hetzner CX41 - 16GB) - Backend Services
VPS #2 (Hetzner CX31 - 8GB) - Data Layer
VPS #3 (Hetzner CX21 - 4GB) - Monitoring

+ Cloudflare Pages
+ Cloudflare R2
+ UptimeRobot (monitoring)

💰 Total: ~$50-60/month
```

---

## 5. 📦 DEPLOY TỪNG COMPONENT

### 5.1 🌐 React Web (Frontend)

#### Build & Deploy

```bash
# Build production
npm run build

# Deploy to Cloudflare Pages
npx wrangler pages publish dist

# Or push to GitHub (auto-deploy)
git push origin main
```

#### Environment Variables

```env
VITE_API_URL=https://api.yourdomain.com
VITE_WS_URL=wss://api.yourdomain.com
VITE_FIREBASE_API_KEY=xxx
```

**Chi phí:** 0$ (Unlimited bandwidth on Cloudflare)

---

### 5.2 📱 React Native (Mobile)

#### Build iOS

```bash
cd ios
pod install
cd ..

# Build for TestFlight
npx react-native run-ios --configuration Release
```

#### Build Android

```bash
cd android
./gradlew assembleRelease

# APK location: android/app/build/outputs/apk/release/
```

**Chi phí:**

- Apple Developer: $99/năm
- Google Play: $25 (one-time)

---

### 5.3 🚪 Kong API Gateway

#### Docker Compose

```yaml
version: "3.8"

services:
  kong-database:
    image: postgres:15
    environment:
      POSTGRES_DB: kong
      POSTGRES_USER: kong
      POSTGRES_PASSWORD: kong
    volumes:
      - kong_data:/var/lib/postgresql/data

  kong-migration:
    image: kong:3.4
    command: kong migrations bootstrap
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-database
    depends_on:
      - kong-database

  kong:
    image: kong:3.4
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-database
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    ports:
      - "80:8000" # HTTP
      - "443:8443" # HTTPS
      - "8001:8001" # Admin API
    depends_on:
      - kong-migration

volumes:
  kong_data:
```

**Deploy:**

```bash
docker-compose up -d
```

**Chi phí:** 0$ (included in VPS)

---

### 5.4 🧠 BFF + NestJS Services

#### Docker Compose

```yaml
version: "3.8"

services:
  bff:
    build:
      context: ./services/bff
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - AUTH_SERVICE_URL=http://auth-service:3001
      - USER_SERVICE_URL=http://user-service:3002
    restart: unless-stopped

  auth-service:
    build:
      context: ./services/auth
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:pass@postgres:5432/auth
      - JWT_SECRET=${JWT_SECRET}
    restart: unless-stopped

  user-service:
    build:
      context: ./services/user
      dockerfile: Dockerfile
    ports:
      - "3002:3002"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/users
    restart: unless-stopped

  friend-service:
    build: ./services/friend
    ports:
      - "3003:3003"
    restart: unless-stopped

  group-service:
    build: ./services/group
    ports:
      - "3004:3004"
    restart: unless-stopped
```

#### Dockerfile (Shared for all NestJS services)

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM node:18-alpine

WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

EXPOSE 3000

CMD ["node", "dist/main"]
```

**Resource Usage (per service):**

- Memory: 200-400MB
- CPU: < 10%

**Chi phí:** Gộp trong VPS

---

### 5.5 ⚡ Go Services (Chat, Realtime, Presence, Media)

#### Docker Compose

```yaml
version: "3.8"

services:
  chat-core:
    build:
      context: ./services/chat-core
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=scylladb
      - REDIS_HOST=redis
      - KAFKA_BROKERS=redpanda:9092
    restart: unless-stopped

  realtime-gateway:
    build: ./services/realtime-gateway
    ports:
      - "8081:8081"
    environment:
      - REDIS_HOST=redis
    restart: unless-stopped

  presence-service:
    build: ./services/presence
    ports:
      - "8082:8082"
    environment:
      - REDIS_HOST=redis
    restart: unless-stopped

  media-processor:
    build: ./services/media-processor
    environment:
      - S3_ENDPOINT=https://xxx.r2.cloudflarestorage.com
      - S3_ACCESS_KEY=${S3_ACCESS_KEY}
      - S3_SECRET_KEY=${S3_SECRET_KEY}
    restart: unless-stopped
```

#### Dockerfile (Multi-stage for Go)

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

**Resource Usage (per service):**

- Memory: 50-150MB
- CPU: < 5%

**Chi phí:** Gộp trong VPS

---

### 5.6 🔄 Redpanda (Kafka-compatible)

#### Docker Compose

```yaml
version: "3.8"

services:
  redpanda:
    image: vectorized/redpanda:latest
    command:
      - redpanda start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      - --advertise-kafka-addr internal://redpanda:9092,external://localhost:19092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:18082
      - --advertise-pandaproxy-addr internal://redpanda:8082,external://localhost:18082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      - --rpc-addr redpanda:33145
      - --advertise-rpc-addr redpanda:33145
      - --smp 1
      - --memory 1G
      - --reserve-memory 0M
    ports:
      - "19092:19092"
      - "18081:18081"
      - "18082:18082"
    volumes:
      - redpanda_data:/var/lib/redpanda/data
    restart: unless-stopped

volumes:
  redpanda_data:
```

**Why Redpanda instead of Kafka?**

- Kafka-compatible API
- **10x lighter** (1GB RAM vs 10GB for Kafka)
- Easier to deploy & maintain
- Perfect for MVP

**Chi phí:** 0$ (self-hosted)

---

### 5.7 🐘 PostgreSQL

#### Docker Compose

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: chatapp
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: chatapp
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped
    command:
      - "postgres"
      - "-c"
      - "max_connections=200"
      - "-c"
      - "shared_buffers=256MB"

volumes:
  postgres_data:
```

#### Database Initialization

```sql
-- init.sql
CREATE DATABASE auth;
CREATE DATABASE users;
CREATE DATABASE friends;
CREATE DATABASE groups;
CREATE DATABASE messages; -- fallback for MVP

-- Create user
CREATE USER chatapp_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE auth TO chatapp_user;
GRANT ALL PRIVILEGES ON DATABASE users TO chatapp_user;
GRANT ALL PRIVILEGES ON DATABASE friends TO chatapp_user;
GRANT ALL PRIVILEGES ON DATABASE groups TO chatapp_user;
```

**Backup Strategy:**

```bash
# Daily backup cron job
0 2 * * * docker exec postgres pg_dumpall -U chatapp > /backups/db_$(date +\%Y\%m\%d).sql
```

**Chi phí:** 0$ (self-hosted)

---

### 5.8 🔴 Redis

#### Docker Compose

```yaml
version: "3.8"

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command:
      - "redis-server"
      - "--appendonly yes"
      - "--maxmemory 512mb"
      - "--maxmemory-policy allkeys-lru"
    restart: unless-stopped

volumes:
  redis_data:
```

**Chi phí:** 0$ (self-hosted)

---

### 5.9 📦 Object Storage

#### Option 1: Cloudflare R2 (Recommended)

**Setup:**

1. Create Cloudflare account
2. Enable R2
3. Create bucket: `chatapp-media`
4. Get Access Key & Secret

**Configuration:**

```env
S3_ENDPOINT=https://xxx.r2.cloudflarestorage.com
S3_ACCESS_KEY=xxx
S3_SECRET_KEY=xxx
S3_BUCKET=chatapp-media
S3_REGION=auto
```

**Chi phí:** ~$5/month (10GB storage + unlimited egress)

---

#### Option 2: MinIO (Self-hosted)

```yaml
version: "3.8"

services:
  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: admin
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    restart: unless-stopped

volumes:
  minio_data:
```

**Chi phí:** 0$ (sử dụng VPS storage)

---

### 5.10 🔔 Push Notifications (Firebase)

#### Setup

1. Create Firebase project
2. Download `google-services.json` (Android) & `GoogleService-Info.plist` (iOS)
3. Add to React Native project
4. Get Server Key from Firebase Console

#### Backend Integration (NestJS)

```typescript
import * as admin from "firebase-admin";

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY,
  }),
});

// Send notification
await admin.messaging().send({
  token: deviceToken,
  notification: {
    title: "New Message",
    body: "You have a new message from John",
  },
  data: {
    conversationId: "123",
    messageId: "456",
  },
});
```

**Chi phí:** 0$ (FCM is free)

---

## 6. 💰 ƯỚC TÍNH CHI PHÍ

### 💡 MVP - Budget Build (< $20/month)

| Thành phần                | Nhà cung cấp           | Chi phí/tháng   |
| ------------------------- | ---------------------- | --------------- |
| **VPS 16GB** (All-in-one) | Contabo VPS M          | $10             |
| **Frontend Hosting**      | Cloudflare Pages       | $0              |
| **Object Storage**        | Cloudflare R2 (10GB)   | $5              |
| **Database**              | Self-hosted PostgreSQL | $0              |
| **Cache**                 | Self-hosted Redis      | $0              |
| **Message Queue**         | Self-hosted Redpanda   | $0              |
| **Push Notification**     | Firebase FCM           | $0              |
| **Domain**                | Namecheap              | $1              |
| **SSL Certificate**       | Let's Encrypt          | $0              |
| **Mobile Publishing**     | Apple + Google         | $10 (amortized) |
|                           | **TỔNG**               | **~$26/tháng**  |

**Capacity:**

- ~1,000-5,000 concurrent users
- ~100,000 messages/day
- ~10GB media storage

---

### ⭐ Recommended - Production Ready (< $50/month)

| Thành phần              | Nhà cung cấp           | Cấu hình      | Chi phí/tháng  |
| ----------------------- | ---------------------- | ------------- | -------------- |
| **VPS #1** (Backend)    | Hetzner CX41           | 16GB / 4 vCPU | $20            |
| **VPS #2** (Data Layer) | Hetzner CX31           | 8GB / 2 vCPU  | $11            |
| **Frontend Hosting**    | Cloudflare Pages       | Unlimited     | $0             |
| **Object Storage**      | Cloudflare R2          | 50GB          | $5-10          |
| **Database**            | Self-hosted PostgreSQL | -             | $0             |
| **Cache**               | Self-hosted Redis      | -             | $0             |
| **Message Queue**       | Self-hosted Redpanda   | -             | $0             |
| **CDN**                 | Cloudflare             | Free tier     | $0             |
| **Monitoring**          | UptimeRobot            | Free tier     | $0             |
| **Domain**              | Namecheap              | .com          | $12/năm (~$1)  |
| **SSL**                 | Let's Encrypt          | Auto-renew    | $0             |
| **Mobile**              | Apple + Google         | -             | $10            |
|                         | **TỔNG**               |               | **~$47/tháng** |

**Capacity:**

- ~10,000-20,000 concurrent users
- ~1,000,000 messages/day
- ~100GB media storage
- 99.5% uptime

---

### 🚀 Scale-Ready (< $100/month)

| Thành phần              | Nhà cung cấp     | Cấu hình      | Chi phí/tháng   |
| ----------------------- | ---------------- | ------------- | --------------- |
| **VPS #1** (Backend)    | Hetzner CX51     | 32GB / 8 vCPU | $39             |
| **VPS #2** (Data Layer) | Hetzner CX41     | 16GB / 4 vCPU | $20             |
| **VPS #3** (Monitoring) | Hetzner CX21     | 4GB / 2 vCPU  | $5              |
| **Load Balancer**       | Hetzner LB       | -             | $6              |
| **Frontend**            | Cloudflare Pages | -             | $0              |
| **Object Storage**      | Cloudflare R2    | 200GB         | $15             |
| **CDN**                 | Cloudflare       | Free          | $0              |
| **Backup Storage**      | Backblaze B2     | 100GB         | $5              |
| **Monitoring**          | Grafana Cloud    | Free tier     | $0              |
| **Domain**              | -                | -             | $1              |
| **Mobile**              | -                | -             | $10             |
|                         | **TỔNG**         |               | **~$101/tháng** |

**Capacity:**

- ~50,000-100,000 concurrent users
- ~10,000,000 messages/day
- ~500GB media storage
- 99.9% uptime
- Full monitoring & alerting

---

### 📊 So Sánh Chi Phí Theo Scale

| Metrics          | MVP       | Recommended | Scale-Ready  |
| ---------------- | --------- | ----------- | ------------ |
| **Chi phí**      | $26/tháng | $47/tháng   | $101/tháng   |
| **Users**        | 1K-5K     | 10K-20K     | 50K-100K     |
| **Messages/day** | 100K      | 1M          | 10M          |
| **Storage**      | 10GB      | 100GB       | 500GB        |
| **Uptime SLA**   | 95%       | 99.5%       | 99.9%        |
| **Support**      | Community | Self        | Professional |

---

## 7. 📈 SCALING STRATEGY

### Phase 1: MVP (0-5K users)

**Setup:**

```
1 VPS (All-in-one)
├── All services in Docker Compose
├── PostgreSQL for everything
└── Basic monitoring
```

**Bottleneck:**

- Single point of failure
- CPU/Memory contention

---

### Phase 2: Growth (5K-20K users)

**Setup:**

```
VPS #1: Backend services
VPS #2: Databases + Kafka

Optimizations:
├── Add read replicas for PostgreSQL
├── Redis cluster (master-slave)
└── Separate Kafka from database server
```

**Bottleneck:**

- Database write load
- WebSocket connection limits

---

### Phase 3: Scale (20K-100K users)

**Setup:**

```
VPS #1-2: Backend (load balanced)
VPS #3: PostgreSQL primary
VPS #4: PostgreSQL replicas
VPS #5: Redis cluster
VPS #6: Kafka cluster

Migrations:
├── PostgreSQL → ScyllaDB for messages
├── Add CDN for static assets
└── Separate media processing queue
```

**Bottleneck:**

- Network bandwidth
- Database connections

---

### Phase 4: Massive Scale (100K+ users)

**Setup:**

```
Kubernetes (GKE / EKS / AKS)
├── Auto-scaling pods
├── Managed databases
├── Global CDN
├── Multi-region deployment
└── Observability stack
```

**Estimated Cost:** $500-2000/month

---

## 🎯 TỔNG KẾT

### ✅ Ưu Điểm Kiến Trúc

| Ưu điểm          | Mô tả                                   |
| ---------------- | --------------------------------------- |
| **Chi phí thấp** | Bắt đầu chỉ với $26/tháng               |
| **Dễ deploy**    | Docker Compose, không cần Kubernetes    |
| **Scalable**     | Microservices → dễ scale từng phần      |
| **Modern stack** | NestJS + Go + React = Production-ready  |
| **Event-driven** | Kafka → Reliable & Decoupled            |
| **Polyglot**     | Dùng ngôn ngữ phù hợp cho từng use case |

### ⚠️ Trade-offs

| Challenge             | Mitigation                      |
| --------------------- | ------------------------------- |
| **Single VPS = SPOF** | Backup thường xuyên, monitoring |
| **No auto-scaling**   | Manual scaling khi cần          |
| **Self-managed**      | Require DevOps skills           |
| **No 99.99% SLA**     | Acceptable cho MVP              |

### 📝 Next Steps

1. ✅ Setup Git repository (monorepo or multi-repo)
2. ✅ Initialize services với boilerplate
3. ✅ Setup Docker Compose cho local dev
4. ✅ Implement Auth Service first
5. ✅ Deploy to VPS
6. ✅ Setup CI/CD (GitHub Actions)
7. ✅ Monitoring & Logging (Grafana + Loki)
8. ✅ Load testing với k6
9. ✅ Security audit
10. ✅ Documentation

---

## 📚 TÀI LIỆU THAM KHẢO

### Technology Documentation

- [NestJS Documentation](https://docs.nestjs.com/)
- [Go Documentation](https://go.dev/doc/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/docs/)
- [Kafka/Redpanda Documentation](https://docs.redpanda.com/)
- [Kong Gateway](https://docs.konghq.com/)
- [React Documentation](https://react.dev/)
- [React Native](https://reactnative.dev/)

### DevOps & Deployment

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Cloudflare Pages](https://developers.cloudflare.com/pages/)
- [Cloudflare R2](https://developers.cloudflare.com/r2/)

### Best Practices

- [12 Factor App](https://12factor.net/)
- [Microservices Patterns](https://microservices.io/)
- [API Design Guidelines](https://github.com/microsoft/api-guidelines)
- [WebSocket Best Practices](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)

---

## 🤝 SUPPORT & CONTACT

**Maintainer:** [Your Name]  
**Email:** [your.email@example.com]  
**Repository:** [GitHub Link]  
**Documentation:** [Notion/Confluence Link]

---

**Version:** 1.0.0  
**Last Updated:** December 29, 2025  
**License:** MIT

---

> 💡 **Lời khuyên:** Bắt đầu đơn giản với MVP setup ($26/tháng), validate product-market fit, sau đó scale dần dần. Đừng over-engineer từ đầu!

> 🚀 **Remember:** "Premature optimization is the root of all evil" - Donald Knuth
