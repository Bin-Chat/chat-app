# Friend/Contact System — Tài liệu kỹ thuật

## Tổng quan

Hệ thống bạn bè gồm 3 tầng:

```
Frontend (React)
    ↕ REST API    ↕ Socket.io
API Gateway (:3000)
    ↕ HTTP Proxy  ↕ Kafka Consumer
Friend Service (:3025)   ←—  Kafka ←—  Friend Service
```

---

## Kiến trúc

```
Client (Browser)
     │  HTTP + JWT Cookie
     ▼
API Gateway (:3000)
  POST/GET/PATCH/DELETE /api/friends/*
  [JwtAuthGuard]
     │  HTTP Proxy
     ▼
Friend Service (:3025)
  ┌─────────────────────────────────────┐
  │  FriendController                   │
  │  FriendService                      │
  │  PostgreSQL: friend_service DB      │
  │    - friendships table              │
  │    - user_cache table               │
  └─────────────────────────────────────┘
         │  Kafka Consumer
         ▼
  Redpanda (Kafka)
    Topics:
    - user.registered      → sync user_cache
    - user.profile_updated → update user_cache
```

---

## Database Schema

### Bảng `friendships`

| Column      | Type      | Mô tả                                        |
| ----------- | --------- | -------------------------------------------- |
| id          | UUID PK   | Auto-generated                               |
| requesterId | UUID      | User gửi lời mời / người chặn                |
| addresseeId | UUID      | User nhận lời mời / người bị chặn            |
| status      | enum      | `pending`, `accepted`, `declined`, `blocked` |
| createdAt   | timestamp | Thời điểm tạo                                |
| updatedAt   | timestamp | Thời điểm cập nhật cuối                      |

**Unique constraint:** `(requesterId, addresseeId)` — tránh trùng lặp.

### Bảng `user_cache`

| Column    | Type      | Mô tả                                    |
| --------- | --------- | ---------------------------------------- |
| id        | UUID PK   | Khớp với `id` trong `auth_service.users` |
| email     | string    | Email user (unique)                      |
| fullName  | string    | Tên hiển thị                             |
| avatar    | string    | URL ảnh đại diện                         |
| isActive  | boolean   | Trạng thái tài khoản                     |
| createdAt | timestamp | Thời điểm tạo cache                      |
| updatedAt | timestamp | Thời điểm cập nhật cache                 |

> **Lưu ý:** `user_cache` được đồng bộ tự động từ `Auth Service` qua Kafka events.  
> Không có HTTP call trực tiếp giữa `friend-service` và `auth-service` / `user-service`.

---

## API Endpoints

Tất cả endpoints đều yêu cầu JWT trong cookie (`accessToken`) hoặc `Authorization: Bearer <token>` header.

### Friend Requests

| Method   | URL                                 | Mô tả                         |
| -------- | ----------------------------------- | ----------------------------- |
| `POST`   | `/api/friends/request`              | Gửi lời mời kết bạn           |
| `PATCH`  | `/api/friends/requests/:id/accept`  | Chấp nhận lời mời             |
| `PATCH`  | `/api/friends/requests/:id/decline` | Từ chối lời mời (xóa khỏi DB) |
| `DELETE` | `/api/friends/requests/:id`         | Thu hồi lời mời đã gửi        |

### Friend List

| Method   | URL                              | Mô tả                          |
| -------- | -------------------------------- | ------------------------------ |
| `GET`    | `/api/friends`                   | Danh sách bạn bè (sort by tên) |
| `GET`    | `/api/friends/requests/received` | Lời mời đang chờ (nhận được)   |
| `GET`    | `/api/friends/requests/sent`     | Lời mời đã gửi                 |
| `GET`    | `/api/friends/blocked`           | Danh sách đã chặn              |
| `DELETE` | `/api/friends/:friendId`         | Xóa bạn bè                     |

### Block

| Method   | URL                          | Mô tả              |
| -------- | ---------------------------- | ------------------ |
| `POST`   | `/api/friends/block/:userId` | Chặn người dùng    |
| `DELETE` | `/api/friends/block/:userId` | Bỏ chặn người dùng |

### Status Check

| Method | URL                           | Mô tả                                     |
| ------ | ----------------------------- | ----------------------------------------- |
| `GET`  | `/api/friends/status/:userId` | Trả về trạng thái quan hệ với user cụ thể |

**Response status check:**

```json
{
  "status": "none | pending | accepted | blocked | self",
  "friendshipId": "uuid (nếu tồn tại)",
  "isSender": true
}
```

---

## Request / Response Examples

### Gửi lời mời kết bạn

```http
POST /api/friends/request
Content-Type: application/json

{
  "addresseeId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response 201:**

```json
{
  "id": "uuid",
  "requesterId": "my-user-id",
  "addresseeId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "pending",
  "createdAt": "2026-03-25T10:00:00.000Z",
  "updatedAt": "2026-03-25T10:00:00.000Z"
}
```

### Lấy danh sách bạn bè

```http
GET /api/friends
```

**Response 200:**

```json
[
  {
    "friendshipId": "uuid",
    "friendSince": "2026-03-20T08:00:00.000Z",
    "user": {
      "id": "uuid",
      "email": "ban@example.com",
      "fullName": "Tên Bạn",
      "avatar": null,
      "isActive": true
    }
  }
]
```

### Lấy lời mời đang chờ

```http
GET /api/friends/requests/received
```

**Response 200:**

```json
[
  {
    "friendshipId": "uuid",
    "sentAt": "2026-03-25T09:30:00.000Z",
    "sender": {
      "id": "uuid",
      "email": "sender@example.com",
      "fullName": "Người Gửi",
      "avatar": null
    }
  }
]
```

---

## Kafka Event Flow

```
Auth Service
  │  Emit: user.registered  {id, email, fullName, createdAt}
  │  Emit: user.profile_updated  {id, fullName, avatar, updatedAt}
  │
  ▼
Redpanda (Kafka broker)
  │
  ├── user-service-consumer  → upsert user_profiles
  └── friend-service-consumer → upsert user_cache
```

> Friend Service subscribe cùng topics với User Service nhưng dùng consumer group khác (`friend-service-consumer`) nên nhận được tất cả events.

---

## Business Rules

1. **Self-request:** Không thể gửi lời mời kết bạn với chính mình.
2. **Duplicate request:** Nếu đã có lời mời `PENDING` → rejected 400. Nếu trước đó đã bị từ chối (`DECLINED`) → cho phép gửi lại.
3. **Accept:** Chỉ `addressee` (người nhận lời mời) mới có quyền accept.
4. **Cancel:** Chỉ `requester` (người gửi lời mời) mới có quyền thu hồi.
5. **Block:** Xóa bất kỳ mối quan hệ hiện tại nào trước khi tạo block record; chỉ có `blocker` mới thấy trong danh sách blocked.
6. **Send to blocked:** Nếu người dùng đang bị chặn → nhận 403 Forbidden.

---

## Frontend UI

### Trang `/contacts`

Giao diện 2 panel theo phong cách Zalo:

```
[DefaultLayout sidebar 68px]
│
├── [Sub-panel 280px | bg-white]
│     ├── Header: "Danh bạ" + nút [+ Thêm bạn]
│     ├── Search input (chỉ hiện ở tab Bạn bè)
│     ├── Tabs: [Bạn bè (N) | Lời mời (N) | Đã gửi (N)]
│     └── Scrollable list
│           ├── FriendCard (tab Bạn bè)
│           ├── ReceivedRequestCard (tab Lời mời)
│           └── SentRequestCard (tab Đã gửi)
│
└── [Main panel flex-1 | bg-#F0F2F5]
      ├── AddFriendPanel (khi bấm nút +)
      └── FriendProfilePanel (khi chọn contact / empty state)
```

### Redux State

```typescript
store.friend = {
  friends: FriendItem[];
  receivedRequests: FriendRequest[];
  sentRequests: SentRequest[];
  loadingFriends: boolean;
  loadingRequests: boolean;
  error: string | null;
}
```

### Service Layer (friendServices.ts)

Tất cả API calls đều dùng `authorizedAxios` (có JWT cookie + auto-refresh 401).

---

## Cách chạy

### Development (local)

```bash
# 1. Start infrastructure
docker-compose up postgres redis redpanda -d

# 2. Start friend-service
cd services/friend
npm install
npm run start:dev   # port 3025

# 3. Start API gateway
cd gateway/api-gateway
npm run start:dev   # port 3000

# 4. Start frontend
cd apps/web
npm run dev         # port 5173
```

### Docker (full stack)

```bash
docker-compose up --build
```

> **Lưu ý lần đầu chạy:** PostgreSQL sẽ chạy init script `01-databases.sql` tự động tạo `friend_service` database. Nếu container postgres đã tồn tại từ trước, cần xóa volume: `docker-compose down -v` rồi `up` lại.

---

## Lỗi thường gặp

| HTTP Code | Message                                | Nguyên nhân                            |
| --------- | -------------------------------------- | -------------------------------------- |
| 400       | Không thể kết bạn với chính mình       | requesterId === addresseeId            |
| 400       | Hai bạn đã là bạn bè                   | Friendship status = ACCEPTED           |
| 400       | Lời mời kết bạn đã được gửi            | Friendship status = PENDING            |
| 403       | Không thể gửi lời mời kết bạn          | Target user đã chặn requester          |
| 403       | Không có quyền thực hiện hành động này | Sai role (accept của người không nhận) |
| 404       | Người dùng không tồn tại               | addresseeId không có trong user_cache  |
| 404       | Lời mời kết bạn không tồn tại          | friendshipId sai hoặc đã bị xóa        |

---

## Tiếp theo

Sau khi Friend System hoàn chỉnh, bước tiếp theo là **Chat/Message Service**:

- Tạo `services/chat/` (port 3050)
- Entities: `conversations`, `messages`, `conversation_members`, `message_read_receipts`
- WebSocket/Realtime Gateway: Socket.io server cho tin nhắn real-time, typing indicators, online presence

---

## Real-time System (Socket.io)

Hệ thống real-time cho phép cập nhật trạng thái bạn bè **tức thì** mà không cần client polling. Kiến trúc gồm 3 lớp: **Friend Service → Kafka → API Gateway Socket.io → Frontend Redux**.

---

### Kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT (Browser)                            │
│                                                                     │
│  App.tsx                                                            │
│  └─ FriendSocketInitializer                                         │
│       └─ friendSocket.ts (socket.io-client)                         │
│            ├─ connect()   →  WS handshake  →  API Gateway :3000     │
│            │               emit('join', {userId})                   │
│            └─ on(event)   →  dispatch → Redux friendSlice           │
└────────────────────────────────┬────────────────────────────────────┘
                                 │  WebSocket (ws://)
                                 │  path: /socket.io
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    API GATEWAY  (:3000)                             │
│                                                                     │
│  SocketGateway (NestJS @WebSocketGateway)                           │
│  ├─ handleConnection()    → log connected                           │
│  ├─ handleDisconnect()    → clean userSockets map                   │
│  ├─ @SubscribeMessage('join') → client.join(`user:${userId}`)       │
│  │                             userSockets.set(userId, socketId)    │
│  └─ emitToUser(userId, event, payload)                              │
│       └─ server.to(`user:${userId}`).emit(event, payload)           │
│                                                                     │
│  FriendEventsConsumer (Kafka @EventPattern)                         │
│  ├─ friend.request.sent      → emitToUser(addresseeId, ...)         │
│  ├─ friend.request.accepted  → emitToUser(requesterId + addresseeId)│
│  ├─ friend.request.declined  → emitToUser(requesterId, ...)         │
│  ├─ friend.request.cancelled → emitToUser(addresseeId, ...)         │
│  └─ friend.unfriended        → emitToUser(userId + formerFriendId)  │
└────────────────────────────────┬────────────────────────────────────┘
                                 │  Kafka Consumer
                                 │  group: api-gateway-friend-events
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   REDPANDA (Kafka broker)                           │
│                                                                     │
│  Topics published by Friend Service:                                │
│  ├─ friend.request.sent                                             │
│  ├─ friend.request.accepted                                         │
│  ├─ friend.request.declined                                         │
│  ├─ friend.request.cancelled                                        │
│  └─ friend.unfriended                                               │
└────────────────────────────────┬────────────────────────────────────┘
                                 │  Kafka Emit (KafkaClient)
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  FRIEND SERVICE  (:3025)                            │
│                                                                     │
│  FriendService                                                      │
│  ├─ sendRequest()    → emit friend.request.sent                     │
│  ├─ acceptRequest()  → emit friend.request.accepted                 │
│  ├─ declineRequest() → emit friend.request.declined                 │
│  ├─ cancelRequest()  → emit friend.request.cancelled                │
│  └─ unfriend()       → emit friend.unfriended                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Connection Lifecycle

#### Bước 1 — Client kết nối WebSocket

Khi user đăng nhập thành công và `user` object xuất hiện trong Redux store, `FriendSocketInitializer` trong `App.tsx` gọi `friendSocket.connect(userId)`:

```typescript
// apps/web/src/services/friendSocket.ts
connect(userId: string) {
  if (socket?.connected) return;  // tránh kết nối trùng

  socket = io('/', {
    path: '/socket.io',
    withCredentials: true,          // gửi cookie JWT
    transports: ['websocket', 'polling'],
  });

  socket.on('connect', () => {
    socket?.emit('join', { userId });  // đăng ký vào room
  });
}
```

Vite dev proxy (`vite.config.ts`) chuyển tiếp `/socket.io` → `http://localhost:3000`:

```typescript
// apps/web/vite.config.ts
proxy: {
  '/socket.io': {
    target: 'http://localhost:3000',
    ws: true,
    changeOrigin: true,
  },
}
```

#### Bước 2 — Server nhận `join`, tạo room

```typescript
// gateway/api-gateway/src/socket/socket.gateway.ts
@SubscribeMessage('join')
handleJoin(@MessageBody() data: { userId: string }, @ConnectedSocket() client: Socket) {
  const { userId } = data;
  client.data.userId = userId;
  client.join(`user:${userId}`);  // socket vào room riêng theo userId

  if (!this.userSockets.has(userId)) {
    this.userSockets.set(userId, new Set());
  }
  this.userSockets.get(userId)!.add(client.id);  // hỗ trợ multi-tab
}
```

**Multi-tab/multi-device:** `userSockets: Map<userId, Set<socketId>>` — một user có thể mở nhiều tab, tất cả đều ở trong cùng room `user:{userId}`, nên event được broadcast đến tất cả tab cùng lúc.

#### Bước 3 — Client đăng ký lắng nghe event

```typescript
// apps/web/src/App.tsx — FriendSocketInitializer
useEffect(() => {
  if (!user) {
    friendSocket.disconnect();
    return;
  }
  friendSocket.connect(user.id);

  const onRequestReceived = (p) => {
    toast.info('Bạn có lời mời kết bạn mới');
    dispatch(socketRequestReceived(p));
  };
  const onRequestAccepted = (p) => {
    toast.success('Lời mời kết bạn đã được chấp nhận');
    dispatch(socketRequestAccepted(p));
  };
  const onRequestDeclined = (p) => dispatch(socketRequestDeclined(p));
  const onRequestCancelled = (p) => dispatch(socketRequestCancelled(p));
  const onUnfriended = (p) => dispatch(socketUnfriended(p));

  friendSocket.on('friend:request_received', onRequestReceived);
  friendSocket.on('friend:request_accepted', onRequestAccepted);
  friendSocket.on('friend:request_declined', onRequestDeclined);
  friendSocket.on('friend:request_cancelled', onRequestCancelled);
  friendSocket.on('friend:unfriended', onUnfriended);

  return () => {
    // cleanup khi user logout hoặc component unmount
    friendSocket.off('friend:request_received', onRequestReceived);
    // ... off all
  };
}, [user, dispatch]);
```

#### Bước 4 — Disconnect khi logout

Khi `user` trở về `null` (logout), `useEffect` cleanup chạy `friendSocket.disconnect()`, server tự động gọi `handleDisconnect()` và xóa socket khỏi `userSockets` map.

---

### Luồng chi tiết từng tác vụ

#### 1. Gửi lời mời kết bạn

```
UserA (Browser)          Friend Service           Kafka           API Gateway          UserB (Browser)
     │                        │                     │                  │                    │
     │──POST /api/friends/─── │                     │                  │                    │
     │     request             │                     │                  │                    │
     │                        │── emit ─────────────▶│                 │                    │
     │                        │  friend.request.sent │                 │                    │
     │                        │  {friendshipId,      │                 │                    │
     │                        │   requesterId: A,    │                 │                    │
     │                        │   addresseeId: B,    │                 │                    │
     │                        │   sentAt}            │                 │                    │
     │◀─── 201 Created ───────│                     │                 │                    │
     │                        │                     │─consume──────── ▶│                   │
     │                        │                     │                  │─emitToUser(B)─────▶│
     │                        │                     │                  │ 'friend:request_   │
     │                        │                     │                  │  received'         │
     │                        │                     │                  │                    │── dispatch ──▶
     │                        │                     │                  │                    │  socketRequestReceived
     │                        │                     │                  │                    │  toast.info
```

#### 2. Chấp nhận lời mời

```
UserB (Browser)          Friend Service           Kafka           API Gateway          UserA (Browser)
     │                        │                     │                  │                    │
     │──PATCH /requests/:id/──▶│                    │                  │                    │
     │        accept           │                     │                  │                    │
     │                        │── emit ─────────────▶│                 │                    │
     │                        │  friend.request.     │                 │                    │
     │                        │  accepted            │                 │                    │
     │◀─── 200 OK ────────────│                     │                 │                    │
     │                        │                     │─consume──────── ▶│                   │
     │                        │                     │                  │─emitToUser(A)─────▶│
     │                        │                     │                  │ 'friend:request_   │
     │                        │                     │                  │  accepted'         │
     │                        │                     │                  │                    │── dispatch ──▶
     │                        │                     │                  │                    │  socketRequestAccepted
     │                        │                     │                  │                    │  toast.success
     │                        │                     │                  │─emitToUser(B) ─────▶│ (chính UserB)
     │                        │                     │                  │ 'friend:request_   │── dispatch ──▶
     │                        │                     │                  │  accepted'         │  socketRequestAccepted
```

> **Lưu ý:** Khi accept, cả **requester** (A) và **addressee** (B) đều nhận được event `friend:request_accepted`. Cả hai đều cần refresh danh sách bạn bè.

#### 3. Từ chối / Thu hồi / Xóa bạn

| Tác vụ     | Ai nhận event | Kafka topic                | Socket.io event            |
| ---------- | ------------- | -------------------------- | -------------------------- |
| Từ chối    | Requester (A) | `friend.request.declined`  | `friend:request_declined`  |
| Thu hồi    | Addressee (B) | `friend.request.cancelled` | `friend:request_cancelled` |
| Xóa bạn bè | Cả A và B     | `friend.unfriended`        | `friend:unfriended`        |

---

### Kafka Topics — Payload chi tiết

#### `friend.request.sent`

```typescript
interface FriendRequestSentEvent {
  friendshipId: string; // UUID của bản ghi friendship
  requesterId: string; // userId người gửi
  addresseeId: string; // userId người nhận
  sentAt: Date;
}
```

#### `friend.request.accepted`

```typescript
interface FriendRequestAcceptedEvent {
  friendshipId: string;
  requesterId: string;
  addresseeId: string;
  acceptedAt: Date;
}
```

#### `friend.request.declined` / `friend.request.cancelled`

```typescript
interface FriendRequestDeclinedEvent {
  friendshipId: string;
  requesterId: string;
  addresseeId: string;
}
```

#### `friend.unfriended`

```typescript
interface FriendUnfriendedEvent {
  userId: string; // người chủ động xóa
  formerFriendId: string; // người bị xóa
}
```

---

### Socket.io Events — Client nhận

| Event name                 | Ai nhận                       | Payload type                  | Toast               |
| -------------------------- | ----------------------------- | ----------------------------- | ------------------- |
| `friend:request_received`  | addressee (B)                 | `FriendRequestSentEvent`      | `toast.info`        |
| `friend:request_accepted`  | requester (A) + addressee (B) | `FriendRequestAcceptedEvent`  | `toast.success` (A) |
| `friend:request_declined`  | requester (A)                 | `FriendRequestDeclinedEvent`  | —                   |
| `friend:request_cancelled` | addressee (B)                 | `FriendRequestCancelledEvent` | —                   |
| `friend:unfriended`        | cả A và B                     | `FriendUnfriendedEvent`       | —                   |

---

### Redux — friendSlice socket reducers

Mỗi socket event được map trực tiếp vào một reducer **synchronous** (không có async):

```typescript
// apps/web/src/store/slices/friendSlice.ts

socketRequestReceived(state, action: { payload: FriendRequest }) {
  // Chỉ thêm nếu chưa tồn tại (idempotent — tránh trùng khi refresh)
  const exists = state.receivedRequests.some(r => r.friendshipId === action.payload.friendshipId);
  if (!exists) state.receivedRequests.unshift(action.payload);
},

socketRequestAccepted(state, action: { payload: { friendshipId: string } }) {
  // Xóa khỏi cả sentRequests và receivedRequests (cả A lẫn B đều nhận event)
  state.sentRequests     = state.sentRequests.filter(r => r.friendshipId !== action.payload.friendshipId);
  state.receivedRequests = state.receivedRequests.filter(r => r.friendshipId !== action.payload.friendshipId);
},

socketRequestDeclined(state, action: { payload: { friendshipId: string } }) {
  state.sentRequests = state.sentRequests.filter(r => r.friendshipId !== action.payload.friendshipId);
},

socketRequestCancelled(state, action: { payload: { friendshipId: string } }) {
  state.receivedRequests = state.receivedRequests.filter(r => r.friendshipId !== action.payload.friendshipId);
},

socketUnfriended(state, action: { payload: { userId: string; formerFriendId: string } }) {
  const { userId, formerFriendId } = action.payload;
  // Lọc ra cả userId lẫn formerFriendId — hoạt động đúng cho cả 2 phía
  state.friends = state.friends.filter(f => f.user.id !== userId && f.user.id !== formerFriendId);
},
```

| Reducer                  | Tác động lên store                           |
| ------------------------ | -------------------------------------------- |
| `socketRequestReceived`  | Thêm đầu `receivedRequests` (idempotent)     |
| `socketRequestAccepted`  | Xóa khỏi `sentRequests` + `receivedRequests` |
| `socketRequestDeclined`  | Xóa khỏi `sentRequests`                      |
| `socketRequestCancelled` | Xóa khỏi `receivedRequests`                  |
| `socketUnfriended`       | Xóa khỏi `friends`                           |

> **Lưu ý:** Sau `socketRequestAccepted`, danh sách `friends` chưa được cập nhật tự động vì cần gọi lại API `/api/friends` để lấy thông tin đầy đủ của bạn mới. Component trang contacts sẽ call `dispatch(fetchFriends())` khi cần.

---

### Backend — SocketGateway chi tiết

```typescript
// gateway/api-gateway/src/socket/socket.gateway.ts

@WebSocketGateway({
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') ?? ['http://localhost:5173'],
    credentials: true,
  },
})
export class SocketGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  // Map lưu userId → Set<socketId> để hỗ trợ multi-tab
  private readonly userSockets = new Map<string, Set<string>>();

  handleConnection(client: Socket) {
    /* log */
  }

  handleDisconnect(client: Socket) {
    // Xóa socketId khỏi map, nếu Set rỗng thì xóa key luôn
    const userId = client.data?.userId;
    if (userId) {
      const sockets = this.userSockets.get(userId);
      sockets?.delete(client.id);
      if (sockets?.size === 0) this.userSockets.delete(userId);
    }
  }

  @SubscribeMessage('join')
  handleJoin(@MessageBody() { userId }: { userId: string }, @ConnectedSocket() client: Socket) {
    client.data.userId = userId;
    client.join(`user:${userId}`);
    this.userSockets.get(userId)?.add(client.id) ??
      this.userSockets.set(userId, new Set([client.id]));
  }

  emitToUser(userId: string, event: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit(event, payload);
    // server.to(room) broadcast đến TẤT CẢ socketId trong room user:{userId}
    // → tất cả tab của cùng user đều nhận được
  }
}
```

---

### Cấu hình Kafka cho API Gateway

`FriendEventsConsumer` được register là Kafka microservice trong `SocketModule`:

```typescript
// gateway/api-gateway/src/socket/socket.module.ts
ClientsModule.register([
  {
    name: 'KAFKA_CLIENT',
    transport: Transport.KAFKA,
    options: {
      client: {
        brokers: [process.env.KAFKA_BROKER ?? 'localhost:9092'],
      },
      consumer: {
        groupId: 'api-gateway-friend-events', // consumer group riêng
      },
    },
  },
]);
```

Biến môi trường trong `docker-compose.yml`:

```yaml
api-gateway:
  environment:
    KAFKA_BROKER: redpanda:9092
```

> **Consumer group riêng:** API Gateway dùng `groupId: api-gateway-friend-events` tách biệt với `friend-service-consumer` của các service khác. Cả hai đều subscribe cùng topic nhưng **độc lập** — event được deliver đủ cho mỗi group.
