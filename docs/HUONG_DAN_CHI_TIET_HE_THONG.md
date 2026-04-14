# Tài liệu Kỹ thuật Chi tiết — BinChat

> Tài liệu này mô tả chi tiết **từng chức năng của hệ thống**, luồng code từ Frontend → Backend, thư viện sử dụng, cách hoạt động và điều kiện để chức năng đó vận hành đúng.

---

## Mục lục

1. [Kiến trúc tổng quan](#1-kiến-trúc-tổng-quan)
2. [Khởi động hệ thống](#2-khởi-động-hệ-thống)
3. [Đăng ký tài khoản](#3-đăng-ký-tài-khoản)
4. [Đăng nhập & Xác thực JWT (Cookie)](#4-đăng-nhập--xác-thực-jwt-cookie)
5. [Tự động Refresh Token](#5-tự-động-refresh-token)
6. [Kết nối Socket.io Real-time](#6-kết-nối-socketio-real-time)
7. [Hệ thống Bạn bè](#7-hệ-thống-bạn-bè)
8. [Tạo / Mở Cuộc trò chuyện](#8-tạo--mở-cuộc-trò-chuyện)
9. [Gửi Tin nhắn Text](#9-gửi-tin-nhắn-text)
10. [Gửi File / Hình ảnh / Video (Upload)](#10-gửi-file--hình-ảnh--video-upload)
11. [Nhận Tin nhắn Real-time](#11-nhận-tin-nhắn-real-time)
12. [Thu hồi Tin nhắn](#12-thu-hồi-tin-nhắn)
13. [Xóa Tin nhắn (phía mình)](#13-xóa-tin-nhắn-phía-mình)
14. [Chuyển tiếp Tin nhắn](#14-chuyển-tiếp-tin-nhắn)
15. [Reaction Emoji trên Tin nhắn](#15-reaction-emoji-trên-tin-nhắn)
16. [Phân trang Tin nhắn (Cursor-based)](#16-phân-trang-tin-nhắn-cursor-based)
17. [Hệ thống Thông báo Email](#17-hệ-thống-thông-báo-email)
18. [Upload File lên S3 / CloudFront](#18-upload-file-lên-s3--cloudfront)
19. [API Gateway — Proxy Pattern](#19-api-gateway--proxy-pattern)
20. [Kafka — Event-Driven Communication](#20-kafka--event-driven-communication)
21. [Bảng tổng hợp API Endpoints](#21-bảng-tổng-hợp-api-endpoints)
22. [Thư viện sử dụng theo từng tầng](#22-thư-viện-sử-dụng-theo-từng-tầng)
23. [Bug Fixes & UI Cải thiện (2026-04-06)](#23-bug-fixes--ui-cải-thiện-2026-04-06)
24. [Bug Fixes & Tính năng mới (2026-04-06 – phiên 2)](#24-bug-fixes--tính-năng-mới-2026-04-06--phiên-2)
25. [Bug Fixes & Tính năng mới (2026-04-06 – phiên 3)](#25-bug-fixes--tính-năng-mới-2026-04-06--phiên-3)
26. [Quản lý Nhóm Chat (Group Chat Management)](#26-quản-lý-nhóm-chat-group-chat-management)
27. [Bug Fixes & Cải thiện Nhóm Chat (2026-04-07)](#27-bug-fixes--cải-thiện-nhóm-chat-2026-04-07)
28. [Hệ thống Presence (Hoạt động trực tuyến)](#28-hệ-thống-presence-hoạt-động-trực-tuyến)

---

## 1. Kiến trúc tổng quan

```
┌────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                              │
│                                                                    │
│   ┌───────────────────┐          ┌────────────────────────┐        │
│   │   Web App         │          │   Mobile App (Expo)    │        │
│   │   React 18        │          │   React Native 0.81    │        │
│   │   Redux Toolkit   │          │   Zustand              │        │
│   │   Tailwind CSS    │          │   NativeWind           │        │
│   │   Vite            │          │   Expo Router          │        │
│   └─────────┬─────────┘          └───────────┬────────────┘        │
└─────────────┼──────────────────────────────  ┼────────────────────┘
              │ HTTP (Cookie)                   │ HTTP (Cookie)
              │ Socket.io (WS)                  │ Socket.io (WS)
              ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      API GATEWAY (Port 3000)                        │
│                                                                     │
│  ┌──────────────┐  ┌──────────────────┐  ┌───────────────────────┐ │
│  │ Proxy Service│  │ Socket Gateway   │  │ Kafka Consumers       │ │
│  │ (forwardReq) │  │ (Socket.io srv)  │  │ FriendEventsConsumer  │ │
│  └──────┬───────┘  └────────┬─────────┘  │ ChatEventsConsumer    │ │
│         │                   │            └───────────────────────┘ │
└─────────┼───────────────────┼──────────────────────────────────────┘
          │ HTTP               │ emit to user rooms
          ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        MICROSERVICES                                │
│                                                                     │
│  ┌──────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌───────┐  │
│  │ Auth     │  │ User    │  │ Friend   │  │ Upload  │  │ Chat  │  │
│  │ :3010    │  │ :3020   │  │ :3030    │  │ :3050   │  │ :3040 │  │
│  │ PostgreSQL│  │ PostgreSQL│  │ PostgreSQL│  │ S3/CF  │  │ MongoDB│  │
│  │ Redis    │  │         │  │          │  │        │  │       │  │
│  └──────────┘  └─────────┘  └──────────┘  └─────────┘  └───────┘  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ Kafka Events
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    KAFKA (Message Broker)                           │
│                                                                     │
│  Topics: user.registered, user.profile.updated                     │
│          friend.request_sent, friend.request_accepted, ...         │
│          notification.send_email                                    │
│          chat.message.created, chat.message.revoked, ...           │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────┐
│       Notification Service             │
│       (Nodemailer → Gmail SMTP)        │
└────────────────────────────────────────┘
```

### Vai trò từng thành phần

| Thành phần               | Vai trò                                                          | Cơ sở dữ liệu       |
| ------------------------ | ---------------------------------------------------------------- | ------------------- |
| **api-gateway**          | Một điểm vào duy nhất, proxy HTTP đến service, quản lý Socket.io | Không có            |
| **auth-service**         | Đăng ký, đăng nhập, JWT, OTP, đổi mật khẩu                       | PostgreSQL + Redis  |
| **user-service**         | Thông tin profile người dùng                                     | PostgreSQL          |
| **friend-service**       | Kết bạn, lời mời, block                                          | PostgreSQL          |
| **upload-service**       | Presign URL lên S3, verify                                       | AWS S3 + CloudFront |
| **chat-service**         | Conversations, Messages, Reactions                               | MongoDB             |
| **notification-service** | Gửi email OTP, welcome                                           | Gmail SMTP          |

---

## 2. Khởi động hệ thống

### Cách khởi động

```bash
# Khởi động tất cả services bằng Docker Compose
docker-compose up -d

# Hoặc chạy từng service riêng lẻ (development)
cd services/auth && npm run start:dev       # :3010
cd services/user && npm run start:dev       # :3020
cd services/friend && npm run start:dev     # :3030
cd services/chat && npm run start:dev       # :3040    ← chạy trong services/chat, KHÔNG phải src/chat
cd services/upload && npm run start:dev     # :3050
cd gateway/api-gateway && npm run start:dev # :3000

# Frontend web
cd apps/web && npm run dev                  # :5173

# Mobile
cd apps/mobile && npx expo start
```

> ⚠️ **Lưu ý quan trọng**: Khi chạy `npm install` cho chat service, phải vào đúng thư mục `services/chat/`, không phải `services/chat/src/chat/`.

### Infrastructure cần thiết

| Service    | Docker Image              | Port  |
| ---------- | ------------------------- | ----- |
| PostgreSQL | postgres:15-alpine        | 5432  |
| Redis      | redis:7-alpine            | 6379  |
| MongoDB    | mongo:7                   | 27017 |
| Kafka      | confluentinc/cp-kafka     | 9092  |
| Zookeeper  | confluentinc/cp-zookeeper | 2181  |

---

## 3. Đăng ký tài khoản

### Luồng đầy đủ

```
[Web/Mobile] → POST /api/auth/register
     ↓
[API Gateway] → proxy → [Auth Service :3010]
     ↓
1. Kiểm tra email đã tồn tại chưa (PostgreSQL)
2. Nếu đã tồn tại và chưa verify → cho đăng ký lại (cập nhật password hash)
3. Nếu chưa tồn tại → tạo user mới với isEmailVerified = false
4. Hash password với bcrypt (10 salt rounds)
5. Tạo OTP 6 chữ số ngẫu nhiên
6. Lưu OTP vào Redis (TTL 900 giây = 15 phút)
     ↓
7. Emit Kafka event: notification.send_email
     ↓
[Notification Service] → nhận event → Nodemailer → Gmail SMTP → Email người dùng
     ↓
Response: { message: "Mã xác thực đã được gửi đến email của bạn" }
```

### Code path

**Frontend (Web)** — `apps/web/src/services/authServices.ts`

```typescript
// Gọi đăng ký
authServices.register({ email, password, fullName });
// → POST http://localhost:3000/api/auth/register
```

**API Gateway** — `gateway/api-gateway/src/proxy/proxy.controller.ts`

```
POST /api/auth/* → ProxyService.forwardRequest('auth', '/auth/*', 'POST', headers, body)
→ http://auth-service:3010/auth/register
```

**Auth Service** — `services/auth/src/auth/auth.service.ts`

```typescript
async register(dto: RegisterDto) {
  // 1. Kiểm tra email
  const existing = await this.userRepo.findOne({ where: { email } });

  // 2. Hash password
  const passwordHash = await bcrypt.hash(dto.password, 10);

  // 3. Tạo/cập nhật user với isEmailVerified = false

  // 4. Tạo OTP và lưu Redis
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  await this.redisService.savePendingOtp(dto.email, otp, 900); // 15 phút

  // 5. Gửi email qua Kafka
  await this.kafkaProducer.emit(NOTIFICATION_EVENTS.SEND_EMAIL, {
    to: dto.email,
    type: 'email_verification',
    data: { fullName: dto.fullName, otp },
  });
}
```

### Xác thực OTP

```
[Web/Mobile] → POST /api/auth/verify-registration { email, otp }
     ↓
[Auth Service]
1. Lấy OTP từ Redis
2. So sánh OTP
3. Nếu đúng → isEmailVerified = true
4. Xóa OTP khỏi Redis
5. Emit Kafka: user.registered (→ friend-service cache user)
6. Emit Kafka: notification.send_email (welcome email)
7. Tạo Access Token + Refresh Token (JWT)
8. Set cookies: accessToken, refreshToken, deviceId (httpOnly)
     ↓
Response: { user: {...}, deviceId: "..." }
```

### Thư viện sử dụng

| Thư viện      | Vai trò                        |
| ------------- | ------------------------------ |
| `bcrypt`      | Hash mật khẩu an toàn với salt |
| `@nestjs/jwt` | Tạo và verify JWT token        |
| `ioredis`     | Lưu OTP tạm vào Redis          |
| `kafkajs`     | Gửi event email qua Kafka      |

---

## 4. Đăng nhập & Xác thực JWT (Cookie)

### Luồng đăng nhập

```
[Web/Mobile] → POST /api/auth/login { email, password, deviceId? }
     ↓
[Auth Service]
1. Tìm user theo email (PostgreSQL)
2. So sánh password với bcrypt.compare()
3. Kiểm tra isEmailVerified = true
4. Kiểm tra isActive = true
5. Tạo Access Token (JWT, TTL: 15 phút)
6. Tạo Refresh Token (JWT, TTL: 30 ngày)
7. Set Cookies (httpOnly, secure, sameSite: 'none')
     ↓
Response: { user: { id, email, fullName, avatar, role }, deviceId }
```

### JWT Payload

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "role": "user",
  "deviceId": "device-uuid",
  "iat": 1700000000,
  "exp": 1700000900
}
```

### Cookie được set

```
accessToken: JWT (httpOnly, TTL 15 phút)
refreshToken: JWT (httpOnly, TTL 30 ngày)
deviceId: string (persistent across sessions)
```

### Xác thực request (Authorization Guard)

Mỗi request đến microservice đều có `Authorization: Bearer <accessToken>` header trong cookie được thêm tự động bởi browser.

**Auth Service** — `JwtAuthGuard` validate JWT:

1. Extract token từ `req.cookies.accessToken`
2. Verify với `jwtService.verify(token, { secret: JWT_SECRET })`
3. Set `req.user = { sub: userId, email, role }`

**Gateway** — khi proxy, chuyển nguyên cookie sang microservice:

```typescript
// proxy.service.ts
const requestHeaders = { ...headers };
// Cookie được đi kèm tự động vì axios gửi đầy đủ headers
```

---

## 5. Tự động Refresh Token

### Vấn đề

Access Token chỉ sống 15 phút. Khi hết hạn → server trả 401 → client phải tự động refresh mà không làm gián đoạn UX.

### Cơ chế Web (authorizedAxios)

**File**: `apps/web/src/utils/authorizedAxios.ts`

```
Request → API → 401 Response
     ↓
Response Interceptor kiểm tra 401
     ↓
Nếu là request /profile hoặc /refresh → reject bình thường
     ↓
Nếu là request bình thường:
  1. Đánh dấu _retry = true
  2. Lấy refreshTokenPromise (hoặc tạo mới)
     ↓
  POST /api/auth/refresh (với cookie refreshToken)
     ↓
  Auth Service kiểm tra refreshToken
  → Tạo accessToken mới → set cookie mới
     ↓
  3. Khi refresh xong → retry request gốc
  4. Nếu refresh fail → dispatch logoutUser()
```

### Hàng đợi request (Queue Pattern)

Tránh gọi refresh nhiều lần khi nhiều request cùng expire:

```typescript
let refreshTokenPromise: Promise<unknown> | null = null;
let subscribers: ((ok: boolean) => void)[] = [];

// Khi có request 401 thứ 2 đến khi đang refresh
new Promise((resolve, reject) => {
  subscribers.push((ok) => (ok ? resolve(originalRequest) : reject()));
});

// Khi refresh xong → thông báo tất cả
function onRefreshed(success: boolean) {
  subscribers.forEach((cb) => cb(success));
  subscribers = [];
}
```

### Cơ chế Mobile

Tương tự web, sử dụng `apps/mobile/src/api/authorizedAxios.ts` với cùng logic interceptor.

---

## 6. Kết nối Socket.io Real-time

### Kiến trúc Socket

```
[Client] ──WS──→ [API Gateway :3000/socket.io] ──→ [SocketGateway]
                                                          │
                                                   Quản lý rooms:
                                                   user:{userId}
                                                          │
                                         ←─ emit to room ─┘
```

### Web — appSocket singleton

**File**: `apps/web/src/services/appSocket.ts`

```typescript
// Singleton — chỉ tạo 1 socket duy nhất cho toàn bộ app
const appSocket = {
  connect(userId: string) {
    if (socket?.connected) return; // Không kết nối lại nếu đã có

    socket = io('/', {
      path: '/socket.io',
      withCredentials: true, // Gửi kèm cookie (JWT)
      transports: ['websocket', 'polling'],
    });

    socket.on('connect', () => {
      // Tham gia room của mình để nhận events
      socket.emit('join', { userId });
    });
  },
};
```

### Mobile — socketService class

**File**: `apps/mobile/src/services/socket.ts`

```typescript
class SocketService {
  connect(userId: string) {
    this.socket = io(SOCKET_URL, { path: '/socket.io' });

    this.socket.on('connect', () => {
      // Auto-emit join để vào room user:{userId}
      this.socket.emit('join', { userId: this._userId });
    });
  }
}
export const socketService = new SocketService(); // singleton
```

### Gateway — SocketGateway

**File**: `gateway/api-gateway/src/socket/socket.gateway.ts`

```typescript
@WebSocketGateway({ cors: { origin: [...], credentials: true } })
export class SocketGateway {
  // Map userId → Set<socketId> (hỗ trợ multi-tab)
  private userSockets = new Map<string, Set<string>>();

  @SubscribeMessage('join')
  handleJoin(data: { userId }, client: Socket) {
    client.data.userId = data.userId;
    client.join(`user:${data.userId}`);  // Tham gia room
  }

  // Gửi event đến tất cả socket của user (multi-tab)
  emitToUser(userId: string, event: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit(event, payload);
  }
}
```

### Khi nào socket kết nối

**Web** — trong `FriendSocketInitializer.tsx` (mount trong App.tsx):

```typescript
useEffect(() => {
  if (!user) {
    appSocket.disconnect();
    return;
  }
  appSocket.connect(user.id); // ← Kết nối khi user đăng nhập
}, [user]);
```

**Mobile** — trong `_layout.tsx` của tab group:

```typescript
useFriendSocket(); // → connect(userId) ngay khi user.id có
useChatSocket(); // → fetchConversations + đăng ký listeners
```

---

## 7. Hệ thống Bạn bè

### A. Gửi lời mời kết bạn

```
[User A click "Kết bạn"]
     ↓
POST /api/friend/requests { addresseeId: "userB_id" }
     ↓
[Friend Service]
1. Kiểm tra không tự kết bạn với mình
2. Kiểm tra chưa là bạn bè / không bị block
3. Tạo Friendship entity { status: 'pending', requesterId, addresseeId }
     ↓
4. Emit Kafka: friend.request_sent
     { requesterId, addresseeId, friendshipId }
     ↓
[API Gateway — FriendEventsConsumer]
5. socketGateway.emitToUser(addresseeId, 'friend:request_received', payload)
     ↓
[User B nhận socket event]
6. FriendSocketInitializer.onRequestReceived():
   → dispatch(fetchReceivedRequests()) // fetch API để có full thông tin sender
   → toast.info('Bạn có lời mời kết bạn mới')
```

### B. Chấp nhận lời mời

```
[User B click "Chấp nhận"]
     ↓
PATCH /api/friend/requests/:friendshipId/accept
     ↓
[Friend Service]
1. Kiểm tra friendshipId + addresseeId = current user
2. Cập nhật status = 'accepted', acceptedAt = now
     ↓
3. Emit Kafka: friend.request_accepted
   { friendshipId, requesterId, addresseeId }
     ↓
[Gateway → FriendEventsConsumer]
4. emitToUser(requesterId, 'friend:request_accepted', payload) // thông báo người gửi
5. emitToUser(addresseeId, 'friend:request_accepted', payload) // cập nhật cho người nhận
     ↓
[Cả 2 phía]
6. dispatch(socketRequestAccepted(payload)) // cập nhật state
7. dispatch(fetchFriends())                 // fetch danh sách bạn bè mới
```

### C. Các trạng thái Friendship

```
pending → accepted (khi addressee chấp nhận)
pending → declined (khi addressee từ chối)
pending → cancelled (khi requester hủy)
accepted → blocked (khi block)
```

### D. Real-time qua Kafka → Socket

```
Friend Service → Kafka → Gateway Consumer → Socket.io → Client
```

**Kafka Events Friend:**
| Event | Trigger | Listener |
|---|---|---|
| `friend.request_sent` | Gửi lời mời | `FriendEventsConsumer` → emit `friend:request_received` |
| `friend.request_accepted` | Chấp nhận | → emit `friend:request_accepted` |
| `friend.request_declined` | Từ chối | → emit `friend:request_declined` |
| `friend.request_cancelled` | Hủy | → emit `friend:request_cancelled` |
| `friend.unfriended` | Hủy bạn | → emit `friend:unfriended` |

### E. UserCache trong Friend Service

Friend Service không trực tiếp truy cập Auth/User Service. Nó lưu bản sao thông tin user trong bảng `user_cache` (PostgreSQL):

```
[Auth Service] → Kafka: user.registered → [Friend Service] → lưu user_cache
[User Service] → Kafka: user.profile.updated → [Friend Service] → cập nhật user_cache
```

---

## 8. Tạo / Mở Cuộc trò chuyện

### Luồng từ trang Contacts (nhấn "Nhắn tin")

**Web** — `apps/web/src/pages/private/contacts/components/FriendCard.tsx`

```typescript
const handleChat = async () => {
  const result = await dispatch(createConversation({ participantIds: [friend.user.id] })).unwrap(); // type: 'direct' (mặc định)

  navigate(`/chat/${result._id}`); // → mở ChatPage
};
```

**Mobile** — `apps/mobile/app/(app)/contacts.tsx`

```typescript
const { createConversation } = useChatStore();

const handleChat = async (userId: string) => {
  const conv = await createConversation([userId]);
  router.push(`/conversation/${conv._id}`);
};
```

### API Call

```
POST /api/chat/conversations
Body: { type: "direct", participantIds: ["userB_id"] }
     ↓
[Chat Service :3040]
1. allParticipants = [ currentUserId, ...participantIds ] (dedup)
2. Nếu type === 'direct' → kiểm tra conversation đã tồn tại (idempotent)
   - Query: { type: 'direct', participants có chứa cả 2, size = 2 }
   - Nếu tồn tại → return existing (không tạo mới)
3. Nếu chưa có → tạo mới trong MongoDB
     ↓
Response: Conversation object với _id
```

### Idempotency quan trọng

Cùng 2 người chat → luôn có duy nhất 1 conversation object. Dù click "Nhắn tin" nhiều lần cũng không tạo trùng.

```typescript
// chat.service.ts
const existing = await this.conversationModel.findOne({
  type: 'direct',
  'participants.userId': { $all: allParticipantIds }, // cả 2 đều có
  $expr: { $eq: [{ $size: '$participants' }, 2] }, // đúng 2 người
});
if (existing) return existing; // trả luôn conversation cũ
```

---

## 9. Gửi Tin nhắn Text

### Luồng đầy đủ

```
[User gõ tin nhắn + Enter]
     ↓
[MessageInput component]
1. Collect text + attachments
2. dispatch(sendMessage({ conversationId, content, attachments }))
     ↓
[chatSlice thunk → chatServices.sendMessage()]
POST /api/chat/conversations/:id/messages
Body: { content: "Hello", attachments: [] }
     ↓
[API Gateway → Chat Service :3040]
3. Xác thực JWT (JwtAuthGuard)
4. Kiểm tra user có trong conversation (ensureParticipant)
5. Lưu Message vào MongoDB
6. Update lastMessage trên Conversation document
7. Emit Kafka: chat.message.created
8. Emit Kafka: chat.conversation.updated
     ↓
[API Gateway — ChatEventsConsumer]
9. Nhận chat.message.created
10. Loop qua participants → emitToUser(userId, 'message:new', event)
     ↓
[Tất cả participants (kể cả người gửi)] nhận socket event
11. ChatSocketInitializer.onMessageNew(payload):
    → dispatch(socketMessageNew(payload))
    → cập nhật messages[conversationId] trong Redux
    → move conversation lên đầu list
    → auto-scroll đến tin mới
```

### State Redux sau khi nhận tin nhắn mới

```typescript
// chatSlice.ts — socketMessageNew reducer
state.messages[convId].push(msg);         // thêm vào cuối mảng
conv.lastMessage = { ... };               // cập nhật preview
state.conversations = [conv, ...rest];    // đẩy conversation lên đầu
```

### Auto-scroll logic (ChatRoom.tsx)

```typescript
useEffect(() => {
  const added = messages.length - prevMessagesLenRef.current;
  if (added <= 5) {
    // Chỉ scroll nếu ≤5 tin mới (không phải load batch cũ)
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }
  prevMessagesLenRef.current = messages.length;
}, [messages.length]);
```

---

## 10. Gửi File / Hình ảnh / Video (Upload)

### Luồng 3 bước (Presign → S3 Direct Upload → Finalize)

```
[User chọn file]
     ↓
Step 1: POST /api/uploads/presign
  Body: { category: 'image', filename: 'photo.jpg', mimeType: 'image/jpeg', fileSize: 1234567 }
     ↓
[Upload Service :3050]
  1. Validate extension không trong BLOCKED_EXTENSIONS (js, exe, sh...)
  2. Validate theo CATEGORY_POLICIES (image: max 10MB, jpg/png/gif/webp/...)
  3. Tạo objectKey = `uploads/{category}/{userId}/{uuid}.{ext}`
  4. Tạo presigned PUT URL (AWS S3, TTL 900s)
     ↓
Response: { presignedUrl: "https://s3.amazonaws.com/...", objectKey: "uploads/image/..." }

Step 2: PUT {presignedUrl}    ← TRỰC TIẾP Client → S3 (bypass backend)
  - XHR với upload progress callback
  - Content-Type: file.type
  - File binary data
  (S3 nhận và lưu file)

Step 3: POST /api/uploads/finalize
  Body: { objectKey: "uploads/image/user1/uuid.jpg", category: "image" }
     ↓
[Upload Service]
  1. HeadObject từ S3 để verify file tồn tại
  2. Construct CDN URL: `${CLOUDFRONT_URL}/${objectKey}`
     ↓
Response: { cdnUrl: "https://cdn.binchat.com/uploads/image/...", objectKey }
```

### Trong MessageInput.tsx

```typescript
const uploadFile = async (file: File, onProgress) => {
  // Step 1: Presign
  const { presignedUrl, objectKey } = await authServices.presignUpload({...});

  // Step 2: Upload trực tiếp lên S3 với XHR (có progress)
  await new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = (ev) => {
      onProgress(Math.round((ev.loaded / ev.total) * 100)); // 0-100%
    };
    xhr.open('PUT', presignedUrl);
    xhr.setRequestHeader('Content-Type', file.type);
    xhr.send(file);
  });

  // Step 3: Finalize → lấy CDN URL
  const { cdnUrl } = await authServices.finalizeUpload({ objectKey, category });
  return { url: cdnUrl, filename: file.name, size: file.size, mimeType: file.type };
};
```

### File categories và giới hạn

| Category   | Extensions                               | Max Size | Dùng cho         |
| ---------- | ---------------------------------------- | -------- | ---------------- |
| `avatar`   | jpg, jpeg, png, webp, gif                | 2MB      | Ảnh đại diện     |
| `image`    | jpg, jpeg, png, webp, gif, bmp           | 10MB     | Ảnh trong chat   |
| `video`    | mp4, mov, avi, mkv, webm                 | 50MB     | Video trong chat |
| `document` | pdf, doc, docx, xls, xlsx, ppt, txt, zip | 50MB     | File đính kèm    |

### Hiển thị Attachment trong MessageBubble

```
Attachments theo loại:
  type === 'image'  → <ImageGrid> (grid layout, lightbox)
  type === 'video'  → <video controls> (native player)
  type === 'file'   → link tải xuống với icon + tên file
```

---

## 11. Nhận Tin nhắn Real-time

### Luồng từ Kafka đến UI

```
Chat Service
  → kafkaProducer.emit('chat.message.created', {
      messageId, conversationId, senderId,
      participants: ['userA', 'userB'],
      content, attachments, createdAt
    })
     ↓
[Kafka Broker — topic: chat.message.created]
     ↓
[API Gateway — ChatEventsConsumer]
  @EventPattern('chat.message.created')
  handleMessageCreated(event) {
    for (const userId of event.participants) {
      socketGateway.emitToUser(userId, 'message:new', event);
    }
  }
     ↓
[Socket.io Room: user:userA và user:userB]
     ↓
[Client nhận event 'message:new']

  Web: ChatSocketInitializer → dispatch(socketMessageNew(payload))
  Mobile: useChatSocket → socketMessageNew(payload) [Zustand]
```

### ChatSocketInitializer đăng ký listeners

**Web** — `apps/web/src/providers/ChatSocketInitializer.tsx` (mount trong App.tsx, không render UI):

```typescript
// Maps raw socket payload → Message (payload.messageId → _id)
appSocket.on('message:new', (payload: MessageCreatedEvent) => {
  const msg: Message = {
    _id: payload.messageId ?? payload._id,  // socket payload dùng "messageId" không phải "_id"
    conversationId: payload.conversationId,
    senderId: payload.senderId,
    content: payload.content ?? '',
    attachments: payload.attachments ?? [],
    deletedFor: [],
    revokedAt: null,
    forwardedFrom: null,
    replyTo: payload.replyTo ?? null,
    reactions: [],
    createdAt: new Date(payload.createdAt).toISOString(),
    updatedAt: new Date(payload.createdAt).toISOString(),
  };
  dispatch(socketMessageNew(msg));
});
appSocket.on('message:revoked', ...)
appSocket.on('conversation:updated', ...)
appSocket.on('message:reaction', ...)
```

**Mobile** — `apps/mobile/src/providers/ChatSocketProvider.tsx` (mount trong \_layout.tsx, bao trong FriendSocketProvider):

```typescript
chatSocket.on('message:new', (payload) => {
  // Map payload.messageId → _id và populate các field mặc định
  const msg: Message = { _id: payload.messageId ?? payload._id, ... };
  socketMessageNew(msg);
});
chatSocket.on('message:revoked', ...)
chatSocket.on('message:reaction', ...)
chatSocket.on('conversation:updated', ...)
```

---

## 12. Tính năng Trả lời Tin nhắn (Reply)

### Tổng quan

Người dùng có thể trả lời một tin nhắn cụ thể. Tin trả lời hiển thị băng trích dẫn (quote band) phía trên nội dung; click vào băng sẽ cuộn đến tin gốc và highlight.

### Schema — `replyTo` trong Message

```typescript
// ReplyInfo (embedded trong Message)
{
  messageId: string;    // _id của tin được trả lời
  senderId: string;     // UUID người gửi tin gốc
  content: string;      // Trích dẫn (tối đa 100 ký tự)
  attachmentType?: 'image' | 'video' | 'file';  // loại file nếu có
}
```

### Luồng

```
[User click "Trả lời" (hover action / long-press mobile)]
     ↓
[ChatRoom/ConversationScreen: setReplyingTo(message)]
     ↓
[MessageInput/Input area: hiển thị reply preview strip với nút hủy]
     ↓
[User gõ nội dung và gửi]
     ↓
POST /api/chat/conversations/:id/messages
  body: { content, replyTo: { messageId, senderId, content, attachmentType? } }
     ↓
[chat-service: lưu message với replyTo field]
     ↓
[Kafka: MESSAGE_CREATED với replyTo trong payload]
     ↓
[Gateway: emit 'message:new' với replyTo]
     ↓
[Client: hiển thị bubble với băng quote phía trên]
```

### UI — Băng trích dẫn (Quote Band)

- **Trong bubble**: hiển thị tên người gửi + nội dung trích dẫn với `border-left` màu accent
- **Click vào băng**: scroll đến tin gốc + highlight ring 2s
- **Màu sắc**: tin của mình → `bg-white/20 border-white/60`; tin người khác → `bg-gray-50 border-[#0068FF]/50`

---

## 13. Thu hồi Tin nhắn

### Điều kiện

- Chỉ người gửi mới được thu hồi (`senderId === currentUserId`)
- Trong vòng **24 giờ** kể từ lúc gửi (`REVOKE_WINDOW_MS = 24 * 60 * 60 * 1000`)
- Không thu hồi lại tin đã thu hồi

### Hành vi

- **Thu hồi (Unsend)**: Tin nhắn biến mất ở cả hai phía, hiển thị placeholder _"Tin nhắn đã được thu hồi"_ cho tất cả participants.
- Placeholder vẫn có nút **Xóa** để user xóa hẳn khỏi view của mình.

### Luồng

```
[User hover tin nhắn → click button Thu hồi (RotateCcw icon)]
     ↓
[MessageBubble.handleRevoke()]
canRevoke = isMine && !isRevoked && (Date.now() - createdAt < 24 giờ)
     ↓
dispatch(revokeMessage({ messageId, conversationId }))
POST /api/chat/messages/:id/revoke
     ↓
[Chat Service]
1. Tìm message theo _id
2. Kiểm tra senderId === userId
3. Kiểm tra elapsed < 24 giờ
4. Set revokedAt = new Date()
5. Emit Kafka: chat.message.revoked { messageId, conversationId, participants }
     ↓
[Gateway → ChatEventsConsumer]
6. emitToUser(userId, 'message:revoked', event) cho TẤT CẢ participants
     ↓
[Client nhận 'message:revoked']
7. dispatch(socketMessageRevoked({ messageId, conversationId }))
   → msg.revokedAt = new Date().toISOString() trong Redux/Zustand
     ↓
[MessageBubble re-render]
8. Hiển thị: <i>Tin nhắn đã được thu hồi</i> (italic, mờ)
   + action panel "Xóa" trên hover để user xóa khỏi view của mình
```

---

## 13. Xóa Tin nhắn (phía mình)

### Ba trường hợp

| Trường hợp         | Ai thực hiện        | Button    | Hành vi                                       |
| ------------------ | ------------------- | --------- | --------------------------------------------- |
| **Thu hồi**        | Người gửi (≤24 giờ) | RotateCcw | Cả hai phía thấy placeholder                  |
| **Xóa ở phía tôi** | Người gửi           | Trash2    | Chỉ ẩn với mình, bên kia vẫn thấy bình thường |
| **Xóa**            | Người nhận          | Trash2    | Chỉ ẩn với mình, không có placeholder         |

Cả "Xóa ở phía tôi" và "Xóa" đều hiển thị **confirmation dialog** (dùng `@radix-ui/react-dialog`) với mô tả rõ hành vi trước khi thực hiện.

### Cơ chế Soft Delete

```
[User click Trash2 → confirmation dialog → confirm]
     ↓
DELETE /api/chat/messages/:id
     ↓
[Chat Service]
await this.messageModel.updateOne(
  { _id: messageId },
  { $addToSet: { deletedFor: userId } }  // thêm userId vào mảng
);
// KHÔNG xóa document, KHÔNG emit socket event
     ↓
[Chat Service → getMessages()]
// Khi query, filter ra các tin đã xóa:
const filter = {
  conversationId: conv._id,
  deletedFor: { $ne: userId }  // không lấy tin mà userId đã xóa
};
```

### Ẩn trên UI

```typescript
// ChatRoom.tsx
const visibleMessages = useMemo(() => {
  return messages.filter((m) => !m.deletedFor.includes(currentUser?.id ?? ''));
}, [messages, currentUser]);
```

---

## 14. Chuyển tiếp Tin nhắn

### Luồng

```
[User hover tin nhắn → click "Chuyển tiếp"]
     ↓
[MessageBubble onForward callback]
setForwardingMessageId(message._id)
→ ChatRoom render <ForwardModal messageId={...} />
     ↓
[ForwardModal hiện ra]
1. Hiển thị danh sách conversations (enriched với tên/avatar)
2. User tìm kiếm hoặc chọn conversation
3. Nhấn "Chuyển tiếp"
     ↓
dispatch(forwardMessage({ messageId, targetConversationId }))
POST /api/chat/messages/:id/forward
Body: { targetConversationId: "conv_id" }
     ↓
[Chat Service]
1. Tìm original message (kiểm tra không bị thu hồi)
2. Kiểm tra user là participant của cả 2 conversation (source + target)
3. Tạo message MỚI trong target conversation với:
   - content: original.content
   - attachments: original.attachments (copy)
   - forwardedFrom: { messageId, conversationId, senderId }  ← metadata
4. Update lastMessage của target conversation
5. Emit Kafka: chat.message.created + chat.conversation.updated
     ↓
[Tất cả participants ở target conversation nhận 'message:new']
6. Hiển thị với banner "Đã chuyển tiếp" màu xanh
```

### Hiển thị "Đã chuyển tiếp" trong MessageBubble

```typescript
{message.forwardedFrom && (
  <div className="flex items-center gap-1 text-[#0068FF] text-[11px] mb-1">
    <CornerUpRight className="w-3 h-3" />
    <span>Đã chuyển tiếp</span>
  </div>
)}
```

---

## 15. Reaction Emoji trên Tin nhắn

### Luồng Thêm/Xóa Reaction

```
[User click SmilePlus → chọn emoji]
     ↓
dispatch(reactToMessage({ messageId, conversationId, emoji, userId }))
POST /api/chat/messages/:id/react
Body: { emoji: "👍" }
     ↓
[Chat Service — toggleReaction()]
1. Kiểm tra message tồn tại và chưa bị thu hồi
2. Kiểm tra user là participant
3. Tìm TẤT CẢ reactions của userId trong message.reactions[]
   - Xóa toàn bộ reactions hiện tại của userId
   - Nếu emoji gửi lên KHÁC emoji vừa xóa (hoặc không có trước): THÊM reaction mới
   - Nếu emoji gửi lên GIỐNG emoji vừa xóa: không thêm (hiệu quả = toggle xóa)
   ⇒ **Kết quả**: mỗi userId chỉ có tối đa 1 reaction trên một message
4. Save message
5. Emit Kafka: chat.reaction.toggled
   { messageId, conversationId, participants, userId, emoji, action }
     ↓
[Gateway → ChatEventsConsumer]
6. emitToUser(uid, 'message:reaction', event) cho TẤT CẢ participants
     ↓
[Client nhận 'message:reaction']
7. dispatch(socketReactionToggled({ messageId, conversationId, userId, emoji }))
8. Reducer cập nhật reactions[]: xóa tất cả reactions của userId rồi thêm emoji mới (nếu action='added')
     ↓
[MessageBubble re-render]
9. Hiển thị grouped reactions: { emoji: "👍", count: 2 }
```

### Hiển thị Grouped Reactions

```typescript
// Gom nhóm reactions theo emoji
const grouped = message.reactions.reduce((acc, r) => {
  acc[r.emoji] = (acc[r.emoji] || 0) + 1;
  return acc;
}, {} as Record<string, number>);

// Hiển thị: 👍 2   ❤️ 1
Object.entries(grouped).map(([emoji, count]) => (
  <button onClick={() => handleReact(emoji)} key={emoji}>
    {emoji} {count}
  </button>
))
```

---

## 16. Phân trang Tin nhắn (Cursor-based)

### Tại sao dùng cursor thay vì offset?

- Offset `LIMIT 30 OFFSET 0` → khi có tin mới thêm → data bị lệch
- Cursor `createdAt < lastMessageTime` → luôn chính xác dù có tin mới

### Luồng Load More

```
[User scroll lên đầu danh sách tin nhắn]
     ↓
ChatRoom.handleScroll():
  if (container.scrollTop < 100 && hasMore && !loadingMessages) {
    const oldestMsg = messages[0]; // tin nhắn cũ nhất hiện tại
    dispatch(fetchMessages({ conversationId, cursor: oldestMsg._id }));
  }
     ↓
GET /api/chat/conversations/:id/messages?cursor={oldestMsgId}&limit=30
     ↓
[Chat Service — getMessages()]
  const filter = {
    conversationId: conv._id,
    deletedFor: { $ne: userId },
    ...(cursor ? { createdAt: { $lt: new Date(cursor) } } : {}),
  };

  const messages = await this.messageModel
    .find(filter)
    .sort({ createdAt: -1 })  // mới nhất trước
    .limit(31)                 // lấy 31 để biết còn nữa không
    .lean();

  const hasMore = messages.length > 30;
  if (hasMore) messages.pop(); // bỏ phần tử thứ 31

  return { messages, hasMore };
     ↓
[chatSlice — fetchMessages.fulfilled]
  // Thêm vào ĐẦU mảng (tin cũ ở đầu, tin mới ở cuối)
  const newMsgs = msgs.filter((m) => !existingIds.has(m._id)); // dedup
  messages[conversationId] = [...newMsgs, ...existing];
```

### Initial Load (không có cursor)

```
dispatch(fetchMessages({ conversationId }))
→ GET /api/chat/conversations/:id/messages?limit=30
→ Lấy 30 tin mới nhất
→ Hiển thị, auto-scroll xuống dưới
```

---

## 17. Hệ thống Thông báo Email

### Kiến trúc

```
[Auth/User/Friend Service]
  → kafkaProducer.emit('notification.send_email', { to, type, data })
     ↓
[Kafka Broker — topic: notification.send_email]
     ↓
[Notification Service — NotificationEventsConsumer]
  @EventPattern('notification.send_email')
  handleSendEmail(event: SendEmailEvent) {
    await this.mailService.sendEmail(event);
  }
     ↓
[MailService]
  1. Chọn template dựa trên event.type
  2. Điền data vào template HTML
  3. nodemailer.sendMail({ to, subject, html })
  4. Gmail SMTP gửi email
```

### Các loại email

| Type                 | Khi nào                   | Nội dung             |
| -------------------- | ------------------------- | -------------------- |
| `email_verification` | Đăng ký / resend OTP      | OTP code + hướng dẫn |
| `welcome`            | Sau khi verify thành công | Chào mừng            |
| `password_reset`     | Quên mật khẩu             | OTP đặt lại mật khẩu |

### Thư viện

| Thư viện                | Vai trò                     |
| ----------------------- | --------------------------- |
| `nodemailer`            | SMTP client gửi email       |
| `@nestjs/microservices` | Kafka consumer trong NestJS |

---

## 18. Upload File lên S3 / CloudFront

### Chi tiết kỹ thuật

**Presign** — `services/upload/src/upload/upload.service.ts`:

```typescript
async generatePresignedUrl(userId, dto) {
  const policy = CATEGORY_POLICIES[dto.category];

  // Validate extension và MIME type theo policy
  if (!policy.extensions.includes(ext))
    throw new BadRequestException(`Extension ".${ext}" không được phép`);

  // Tạo key duy nhất
  const objectKey = `uploads/${category}/${userId}/${uuidv4()}.${ext}`;

  // Tạo presigned URL từ AWS SDK
  const command = new PutObjectCommand({
    Bucket: this.bucket,
    Key: objectKey,
    ContentType: dto.mimeType,
    ContentLength: dto.fileSize,
  });
  const presignedUrl = await getSignedUrl(this.s3, command, { expiresIn: this.presignTtl });

  return { presignedUrl, objectKey };
}
```

**Finalize** — verify file đã upload:

```typescript
async finalizeUpload(dto) {
  // S3 HeadObject để kiểm tra file tồn tại
  await this.s3.send(new HeadObjectCommand({
    Bucket: this.bucket,
    Key: dto.objectKey,
  }));

  // Trả về CDN URL (CloudFront)
  return { cdnUrl: `${this.cloudfrontUrl}/${dto.objectKey}` };
}
```

### Lợi ích của Direct S3 Upload

- Backend không cần xử lý file → không tốn RAM/CPU
- File đi thẳng Client → S3 → CDN → nhanh hơn
- Presigned URL có TTL → an toàn, không cần lộ credentials

---

## 19. API Gateway — Proxy Pattern

### Cơ chế

**File**: `gateway/api-gateway/src/proxy/proxy.service.ts`

```typescript
// Map service name → URL
this.serviceUrls = new Map([
  ['auth',   'http://auth-service:3010'],
  ['user',   'http://user-service:3020'],
  ['friend', 'http://friend-service:3030'],
  ['upload', 'http://upload-service:3050'],
  ['chat',   'http://chat-service:3040'],
]);

// Khi có request đến /api/auth/* → forward đến auth-service
async forwardRequest(service, path, method, headers, body, query) {
  const url = `${serviceUrls.get(service)}${path}`;
  const response = await axios({ method, url, headers, data: body, params: query });
  return { status: response.status, data: response.data };
}
```

### Routing

| URL Pattern      | Forward đến                     |
| ---------------- | ------------------------------- |
| `/api/auth/*`    | `auth-service:3010/auth/*`      |
| `/api/users/*`   | `user-service:3020/users/*`     |
| `/api/friend/*`  | `friend-service:3030/*`         |
| `/api/uploads/*` | `upload-service:3050/uploads/*` |
| `/api/chat/*`    | `chat-service:3040/chat/*`      |

### Cookie Forwarding

Cookies (accessToken, refreshToken) được forward tự động qua header `Cookie` khi proxy request từ client đến các microservice.

---

## 20. Kafka — Event-Driven Communication

### Tổng quan

```
Service A làm việc → emit event → Kafka → Service B phản ứng (async)
```

Điều này giúp các service **tách biệt hoàn toàn** (loose coupling). Service A không cần biết Service B tồn tại.

### Tất cả Events

#### User Events

| Topic                  | Producer     | Consumer(s)    | Payload                                    |
| ---------------------- | ------------ | -------------- | ------------------------------------------ |
| `user.registered`      | auth-service | friend-service | `{ id, email, fullName, role, createdAt }` |
| `user.profile.updated` | user-service | friend-service | `{ id, fullName, avatar }`                 |

#### Friend Events

| Topic                      | Producer       | Consumer(s) | Payload                                      |
| -------------------------- | -------------- | ----------- | -------------------------------------------- |
| `friend.request_sent`      | friend-service | api-gateway | `{ requesterId, addresseeId, friendshipId }` |
| `friend.request_accepted`  | friend-service | api-gateway | `{ friendshipId, requesterId, addresseeId }` |
| `friend.request_declined`  | friend-service | api-gateway | `{ friendshipId }`                           |
| `friend.request_cancelled` | friend-service | api-gateway | `{ friendshipId }`                           |
| `friend.unfriended`        | friend-service | api-gateway | `{ userId, unfriendedId }`                   |

#### Notification Events

| Topic                     | Producer          | Consumer(s)          | Payload              |
| ------------------------- | ----------------- | -------------------- | -------------------- |
| `notification.send_email` | auth/user-service | notification-service | `{ to, type, data }` |

#### Chat Events

| Topic                        | Producer     | Consumer(s) | Payload                                                                           |
| ---------------------------- | ------------ | ----------- | --------------------------------------------------------------------------------- |
| `chat.message.created`       | chat-service | api-gateway | `{ messageId, conversationId, senderId, participants[], content, attachments[] }` |
| `chat.message.revoked`       | chat-service | api-gateway | `{ messageId, conversationId, participants[], revokedAt }`                        |
| `chat.message.edited`        | chat-service | api-gateway | `{ messageId, conversationId, participants[], content, editedAt }`                |
| `chat.message.pinned`        | chat-service | api-gateway | `{ messageId, conversationId, participants[], pinnedBy, pinnedAt }`               |
| `chat.message.unpinned`      | chat-service | api-gateway | `{ messageId, conversationId, participants[] }`                                   |
| `chat.conversation.updated`  | chat-service | api-gateway | `{ conversationId, participants[], lastMessage }`                                 |
| `chat.conversation.settings` | chat-service | api-gateway | `{ conversationId, participants[], settings }`                                    |
| `chat.reaction.toggled`      | chat-service | api-gateway | `{ messageId, conversationId, participants[], userId, emoji, action }`            |
| `chat.member.banned`         | chat-service | api-gateway | `{ conversationId, participants[], targetUserId, bannedUntil }`                   |
| `chat.member.unbanned`       | chat-service | api-gateway | `{ conversationId, participants[], targetUserId }`                                |

### Consumer trong Gateway

```typescript
// chat-events.consumer.ts
@EventPattern('chat.message.created')
handleMessageCreated(event: MessageCreatedEvent) {
  for (const userId of event.participants) {
    this.socketGateway.emitToUser(userId, 'message:new', event);
  }
}

@EventPattern('chat.message.revoked')
handleMessageRevoked(event) {
  for (const userId of event.participants) {
    this.socketGateway.emitToUser(userId, 'message:revoked', event);
  }
}
```

---

## 21. Bảng tổng hợp API Endpoints

### Auth Service

| Method | Path                            | Auth       | Mô tả                                   |
| ------ | ------------------------------- | ---------- | --------------------------------------- |
| POST   | `/api/auth/register`            | ❌         | Đăng ký, gửi OTP email                  |
| POST   | `/api/auth/verify-registration` | ❌         | Xác thực OTP, tạo tài khoản, set cookie |
| POST   | `/api/auth/resend-verification` | ❌         | Gửi lại OTP                             |
| POST   | `/api/auth/login`               | ❌         | Đăng nhập, set cookie                   |
| POST   | `/api/auth/logout`              | ✅         | Xóa cookie                              |
| POST   | `/api/auth/refresh`             | RefreshJWT | Làm mới access token                    |
| GET    | `/api/auth/profile`             | ✅         | Lấy thông tin user hiện tại             |
| POST   | `/api/auth/forgot-password`     | ❌         | Gửi OTP reset password                  |
| POST   | `/api/auth/reset-password`      | ❌         | Đặt lại mật khẩu                        |
| PATCH  | `/api/auth/change-password`     | ✅         | Đổi mật khẩu                            |

### Friend Service

| Method | Path                               | Auth | Mô tả                   |
| ------ | ---------------------------------- | ---- | ----------------------- |
| POST   | `/api/friend/requests`             | ✅   | Gửi lời mời kết bạn     |
| GET    | `/api/friend/requests/received`    | ✅   | Lấy lời mời nhận được   |
| GET    | `/api/friend/requests/sent`        | ✅   | Lấy lời mời đã gửi      |
| PATCH  | `/api/friend/requests/:id/accept`  | ✅   | Chấp nhận lời mời       |
| PATCH  | `/api/friend/requests/:id/decline` | ✅   | Từ chối lời mời         |
| DELETE | `/api/friend/requests/:id`         | ✅   | Hủy lời mời (requester) |
| GET    | `/api/friend/friends`              | ✅   | Danh sách bạn bè        |
| DELETE | `/api/friend/friends/:id`          | ✅   | Hủy kết bạn             |

### Chat Service

| Method | Path                                           | Auth | Mô tả                                 |
| ------ | ---------------------------------------------- | ---- | ------------------------------------- |
| POST   | `/api/chat/conversations`                      | ✅   | Tạo/tìm conversation (idempotent)     |
| GET    | `/api/chat/conversations`                      | ✅   | Danh sách conversations               |
| GET    | `/api/chat/conversations/:id`                  | ✅   | Chi tiết conversation                 |
| GET    | `/api/chat/conversations/:id/messages`         | ✅   | Tin nhắn (cursor-based, 30/page)      |
| POST   | `/api/chat/conversations/:id/messages`         | ✅   | Gửi tin nhắn                          |
| PATCH  | `/api/chat/messages/:id`                       | ✅   | Chỉnh sửa tin nhắn (cửa sổ 30 phút)   |
| PATCH  | `/api/chat/messages/:id/revoke`                | ✅   | Thu hồi tin nhắn (24 giờ)             |
| DELETE | `/api/chat/messages/:id`                       | ✅   | Xóa phía mình (soft delete)           |
| POST   | `/api/chat/messages/:id/forward`               | ✅   | Chuyển tiếp tin nhắn                  |
| POST   | `/api/chat/messages/:id/react`                 | ✅   | Toggle emoji reaction (1 per user)    |
| POST   | `/api/chat/messages/:id/pin`                   | ✅   | Ghim tin nhắn (max 50)                |
| DELETE | `/api/chat/messages/:id/pin`                   | ✅   | Bỏ ghim tin nhắn                      |
| GET    | `/api/chat/conversations/:id/pinned`           | ✅   | Danh sách tin đã ghim                 |
| POST   | `/api/chat/conversations/:id/read`             | ✅   | Đánh dấu đã đọc (cập nhật lastReadAt) |
| PATCH  | `/api/chat/conversations/:id/settings`         | ✅   | Cập nhật cài đặt nhóm (owner only)    |
| POST   | `/api/chat/conversations/:id/members/:uid/ban` | ✅   | Ban thành viên                        |
| DELETE | `/api/chat/conversations/:id/members/:uid/ban` | ✅   | Unban thành viên                      |
| PATCH  | `/api/chat/conversations/:id/me`               | ✅   | Cài đặt cá nhân (pin/archive/mute)    |
| GET    | `/api/chat/conversations/:id/members`          | ✅   | Danh sách thành viên nhóm             |
| POST   | `/api/chat/conversations/:id/members`          | ✅   | Thêm thành viên (owner/admin)         |
| DELETE | `/api/chat/conversations/:id/members`          | ✅   | Xóa thành viên (owner/admin)          |
| POST   | `/api/chat/conversations/:id/leave`            | ✅   | Rời nhóm (không phải owner)           |
| PATCH  | `/api/chat/conversations/:id`                  | ✅   | Cập nhật nhóm (tên/ảnh/mô tả)         |
| PATCH  | `/api/chat/conversations/:id/role`             | ✅   | Thay đổi vai trò (owner only)         |
| PATCH  | `/api/chat/conversations/:id/transfer`         | ✅   | Chuyển quyền chủ nhóm                 |
| DELETE | `/api/chat/conversations/:id`                  | ✅   | Giải tán nhóm (owner only)            |

### Upload Service

| Method | Path                    | Auth | Mô tả                        |
| ------ | ----------------------- | ---- | ---------------------------- |
| POST   | `/api/uploads/presign`  | ✅   | Lấy presigned S3 URL         |
| POST   | `/api/uploads/finalize` | ✅   | Xác nhận upload, lấy CDN URL |

### User Service

| Method | Path                     | Auth | Mô tả                           |
| ------ | ------------------------ | ---- | ------------------------------- |
| PATCH  | `/api/users/:id/profile` | ✅   | Cập nhật profile                |
| GET    | `/api/users/search`      | ✅   | Tìm kiếm user                   |
| POST   | `/api/users/batch`       | ✅   | Lấy profiles theo danh sách IDs |

---

## 22. Thư viện sử dụng theo từng tầng

### Web App (`apps/web`)

| Thư viện           | Version | Vai trò                                  |
| ------------------ | ------- | ---------------------------------------- |
| `react`            | 18      | UI framework                             |
| `react-router-dom` | v6      | Client-side routing                      |
| `@reduxjs/toolkit` | latest  | State management                         |
| `react-redux`      | latest  | React bindings for Redux                 |
| `axios`            | latest  | HTTP client                              |
| `socket.io-client` | latest  | Real-time WebSocket                      |
| `tailwindcss`      | 3       | Utility-first CSS                        |
| `framer-motion`    | latest  | Animations (AnimatePresence, motion.div) |
| `lucide-react`     | latest  | Icons (SVG components)                   |
| `react-toastify`   | latest  | Toast notifications                      |
| `date-fns`         | latest  | Date formatting (vi locale)              |
| `@radix-ui/*`      | latest  | Accessible UI primitives                 |
| `vite`             | latest  | Build tool                               |

### Mobile App (`apps/mobile`)

| Thư viện                         | Version | Vai trò                      |
| -------------------------------- | ------- | ---------------------------- |
| `expo`                           | SDK 53  | React Native platform        |
| `expo-router`                    | v4      | File-based routing           |
| `react-native`                   | 0.81    | Native UI framework          |
| `zustand`                        | latest  | Lightweight state management |
| `nativewind`                     | v4      | Tailwind CSS for RN          |
| `axios`                          | latest  | HTTP client                  |
| `socket.io-client`               | latest  | Real-time WebSocket          |
| `lucide-react-native`            | latest  | Icons cho React Native       |
| `react-native-safe-area-context` | latest  | Safe area (notch/etc)        |
| `@react-navigation/native`       | latest  | App navigation               |

### Backend — Tất cả Services

| Thư viện                        | Vai trò                       |
| ------------------------------- | ----------------------------- |
| `@nestjs/core`                  | NestJS framework              |
| `@nestjs/jwt`                   | JWT creation/validation       |
| `@nestjs/websockets`            | WebSocket/Socket.io           |
| `@nestjs/microservices`         | Kafka consumer                |
| `@nestjs/mongoose`              | MongoDB ORM (chat-service)    |
| `@nestjs/typeorm`               | PostgreSQL ORM                |
| `bcrypt`                        | Password hashing              |
| `kafkajs`                       | Kafka producer/consumer       |
| `ioredis`                       | Redis client                  |
| `mongoose`                      | MongoDB driver (chat-service) |
| `typeorm`                       | PostgreSQL ORM                |
| `nodemailer`                    | Email sending                 |
| `@aws-sdk/client-s3`            | S3 presign/HeadObject         |
| `@aws-sdk/s3-request-presigner` | Presigned URL generation      |
| `uuid`                          | Unique ID generation          |
| `cookie-parser`                 | Parse cookie headers          |
| `passport-jwt`                  | JWT strategy cho Passport     |

---

## Sơ đồ Data Flow tổng hợp

```
┌────────────────────────── Chat Feature Complete Flow ──────────────────────────┐
│                                                                                │
│  User A (Web)                                  User B (Mobile)                 │
│     │                                               │                          │
│  1. Click "Nhắn tin" ──POST /api/chat/conversations─►                          │
│     │       Chat Service: tìm hoặc tạo conversation                            │
│     │◄─── {_id: "conv123"} ──────────────────────────                          │
│  2. navigate("/chat/conv123")                                                  │
│     │                                                                          │
│  3. ChatRoom mount → GET /api/chat/conversations/conv123/messages              │
│     │       Chat Service: 30 tin nhắn mới nhất                                 │
│     │◄─── { messages[], hasMore } ──────────────────                           │
│     │                                                                          │
│  4. Gõ "Hello" + Enter ──POST /api/chat/conversations/conv123/messages         │
│     │       Chat Service:                                                      │
│     │       - Lưu MongoDB                                                      │
│     │       - Update lastMessage                                               │
│     │       - Emit Kafka: chat.message.created {participants:["A","B"]}        │
│     │                 │                                                        │
│     │         Kafka Broker                                                     │
│     │                 │                                                        │
│     │       API Gateway ChatEventsConsumer                                     │
│     │       - emitToUser("A", "message:new", payload)                          │
│     │       - emitToUser("B", "message:new", payload)                          │
│     │                 │                    │                                   │
│  ◄──── Socket event ──┘                    └──── Socket event ────►            │
│  dispatch(socketMessageNew)                socketMessageNew()                  │
│  → messages["conv123"].push(msg)           → messages["conv123"].push(msg)     │
│  → conv lên đầu list                       → conv lên đầu list                 │
│  → auto-scroll xuống dưới                 → FlatList re-render                 │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

_Tài liệu này được tạo tự động từ source code của dự án BinChat. Cập nhật lần cuối: 2026-04-06_

---

## 23. Bug Fixes & UI Cải thiện (2026-04-06)

### Bug 1: Tin nhắn 1-1 hiện lên Group Chat

**Nguyên nhân:**
Hai lỗi phối hợp với nhau:

1. `sendMessage.fulfilled` dùng `msg.conversationId` từ body API response (có thể là ObjectId object không phải string thuần) để làm key lưu vào `state.messages[...]`, tạo ra key sai.
2. `createConversation.fulfilled` set `state.activeConversationId = newId` ngay lập tức (trước khi `navigate()` thay URL), khiến `ChatPage` render `<ChatRoom>` với conversation ID sai trong thời gian ngắn.
3. `ChatPage` render `<ChatRoom conversationId={activeConversationId}>` thay vì dùng `conversationId` từ URL params — URL không phải source-of-truth.

**Fix áp dụng:**

```typescript
// chatSlice.ts — sendMessage.fulfilled
// Trước: const convId = msg.conversationId; (từ API response)
// Sau: dùng action.meta.arg.conversationId (từ thunk parameter — luôn đúng)
const convId = action.meta.arg.conversationId;

// chatSlice.ts — createConversation.fulfilled
// Xóa: state.activeConversationId = action.payload._id;
// Lý do: navigate() trong FriendCard sẽ trigger useEffect → setActiveConversation(url)

// ChatPage.tsx — single source of truth là URL
const { conversationId } = useParams();
// Dùng conversationId từ URL cho cả ConversationList và ChatRoom
<ChatRoom conversationId={conversationId} />
```

---

### Bug 2: Hover vào Message hiện nhiều Action Bar cùng lúc

**Nguyên nhân:**
Mỗi `MessageBubble` có `showActions` state riêng. Khi user di chuyển nhanh qua nhiều messages, timer 150ms của message trước chưa fire, khiến nhiều bubbles cùng `showActions = true`.

**Fix áp dụng:**
Di chuyển hover tracking lên `ChatRoom` level — chỉ một message được active tại một thời điểm:

```typescript
// ChatRoom.tsx
const [hoveredMsgId, setHoveredMsgId] = useState<string | null>(null);

<MessageBubble
  isHovered={hoveredMsgId === msg._id}
  onHoverIn={() => setHoveredMsgId(msg._id)}
  onHoverOut={() => setHoveredMsgId(null)}
/>

// MessageBubble.tsx — không còn showActions state, dùng prop
const showActions = isHovered; // controlled externally
```

---

### Cải thiện UI: Message Box giống Zalo hơn

**Thay đổi:**

| Trường hợp                      | Trước                              | Sau                                               |
| ------------------------------- | ---------------------------------- | ------------------------------------------------- |
| Tin nhắn **chỉ ảnh** (sender)   | `bg-[#0068FF]` xanh đè ảnh         | Không background, ảnh hiện tự nhiên               |
| Tin nhắn **chỉ ảnh** (receiver) | `bg-white border` viền ngoài       | Không background, ảnh hiện tự nhiên               |
| Timestamp ảnh                   | Ngoài bubble                       | **Overlay** trên ảnh (pill đen mờ, góc phải-dưới) |
| Ảnh đơn                         | `max-w-[280px] max-h-[280px]` cứng | `max-w-[300px] max-h-[320px]` tự nhiên            |
| Grid 2-3-4+ ảnh                 | `gap-1 rounded-lg` cắt góc         | `gap-[2px] rounded-xl overflow-hidden` mượt       |
| File attachment                 | Nhỏ, không nổi bật                 | Card lớn hơn, icon extension, size MB/KB          |
| Video                           | `border border-gray-200`           | Không border, rounded-lg                          |

**`imageOnly` flag (mới):**

```typescript
// MessageBubble.tsx
const imageOnly =
  images.length > 0 && files.length === 0 && videos.length === 0 && !message.content;
// → bubble wrapper không có bg, timestamp overlay trên ảnh
```

---

## 24. Bug Fixes & Tính năng mới (2026-04-06 – phiên 2)

### 1. Ghost "Nhóm chat" khi nhắn tin 1-1

**Nguyên nhân:**
Socket event `conversation:updated` mang payload `{ conversationId, lastMessage }`, nhưng reducer `socketConversationUpdated` tìm theo `_id`. Do `_id = undefined`, findIndex trả về `-1` → reducer `unshift` vào list một object không tên/type → `ConversationList` render "Nhóm chat".

**Fix:**

- `ChatSocketInitializer.tsx`: map `conversationId → _id` trước khi dispatch.
- `chatSlice.ts`: nếu `idx < 0` → `return` (không insert conversation lạ).

---

### 2. Gửi từng attachment thành message riêng

**Trước:** Tất cả ảnh/video/file trong một lần nhấn Send → cùng 1 message → chỉ thu hồi được nguyên lô.

**Sau:** Mỗi attachment → 1 message độc lập → thu hồi từng cái.

```typescript
// MessageInput.tsx — handleSend
for (const att of pendingAttachments) {
  const uploaded = await uploadFile(att.file, onProgress);
  await dispatch(sendMessage({ conversationId, attachments: [uploaded] })).unwrap();
}
```

---

### 3. Validation file size phía client

Constants `FILE_SIZE_LIMITS` (`image: 10 MB`, `video/file: 50 MB`) check kích thước trước khi upload. File vượt giới hạn bị toast lỗi ngay lập tức, không gọi API.

---

### 4. Thu hồi tin nhắn → xóa file trên S3

**Chat service** (`revokeMessage`): emit thêm `attachmentUrls` trong Kafka event `chat.message.revoked`.

**Upload service** (`UploadEventsConsumer`): handler `@EventPattern('chat.message.revoked')` gọi `deleteObjects(url)` cho từng URL → xóa file gốc + tất cả variants.

---

### 5. Video S3 variants – player với thumbnail

Lambda `video-dispatcher` tạo `__360p.mp4`, `__720p.mp4`, `__thumb.jpg` sau khi upload.

**Vấn đề với `<source>` chain:** Browser chỉ chuyển sang `<source>` tiếp theo khi MIME type không hỗ trợ, **không** chuyển khi HTTP 404 → Lambda variants chưa được xử lý xong sẽ bị 404 nhưng player không fallback.

**Giải pháp (phiên 3):** Upload thumbnail client-side → `thumbnailUrl` luôn sẵn sàng ngay; dùng `__360p.mp4` + original làm source chain:

```html
<!-- poster = client-uploaded thumbnail (luôn có) hoặc Lambda __thumb.jpg -->
<video poster="{thumbnailUrl ?? baseUrl+__thumb.jpg}">
  <source src="{baseUrl}__360p.mp4" type="video/mp4" />
  <!-- original luôn là fallback đáng tin cậy -->
  <source src="{v.url}" type="video/mp4" />
</video>
```

`deleteObjects()` trong upload service mở rộng để xóa cả `__thumb.jpg`, `__360p.mp4`, `__720p.mp4`.

---

### 6. Video & file không có background màu

`videoOnly` và `fileOnly` flags mới trong `MessageBubble.tsx` — giống `imageOnly`, không có `bg-[#0068FF]` wrapper.

---

### 7. Reaction picker – fix hover mất

**Nguyên nhân:** Action buttons nằm `absolute right-full` ngoài bounds của outer div → `onMouseLeave` của outer div fire khi mouse vào reaction picker → `isHovered = false` → picker ẩn.

**Fix:**

- `onMouseEnter={onHoverIn}` thêm vào cả action buttons div và reaction picker div.
- Reaction picker có overlay `fixed inset-0` → click ngoài để đóng, không phụ thuộc vào `isHovered`.

---

### 8. Emoji picker – tìm kiếm + duplicate key

- Thay `EMOJI_LIST` bằng `EMOJI_DATA[]` với trường `keywords` tiếng Việt.
- Search filter theo `keywords` hoặc unicode của emoji.
- Xóa emoji `😥` trùng lặp.
- Key: `emoji_${idx}` thay vì `emoji` (tránh duplicate key warning).

---

### 9. Sanitize filename trước khi upload

Tên file có ký tự đặc biệt (dấu ngoặc, dấu cộng, v.v.) bị backend reject do regex `^[\w\-. ]+$`.

**Fix (client-side):**

```typescript
// MessageInput.tsx — uploadFile()
const safeBase = baseName.replace(/[^\w\-. ]/g, '_').replace(/_+/g, '_');
const safeFilename = (safeBase || 'file') + ext;
// Tên hiển thị vẫn dùng file.name (tên gốc)
```

---

### 10. Browser notification khi có tin nhắn mới

`ChatSocketInitializer.tsx` request permission khi mount. Khi `message:new` arrive từ người khác và tab không focus → `new Notification(...)` với tên sender và nội dung tóm tắt.

---

## 25. Bug Fixes & Tính năng mới (2026-04-06 – phiên 3)

### 1. Màu file card bên người gửi bị mờ (invisible)

**Nguyên nhân:** Khi `fileOnly` (tin nhắn chỉ có file, không có ảnh/text), bubble wrapper không có background màu. File card dùng `bg-white/15` (alpha) → trở nên trong suốt trên nền trắng. Text `text-gray-800` cũng bị khuất.

**Fix (`MessageBubble.tsx` — web):**

| Element        | isMine + fileOnly                   | receiver + fileOnly                 |
| -------------- | ----------------------------------- | ----------------------------------- |
| Card wrapper   | `bg-gray-50 border border-gray-100` | `bg-gray-50 border border-gray-100` |
| Icon container | `bg-[#0068FF]/10`                   | `bg-[#0068FF]/10`                   |
| Icon text      | `text-[#0068FF]`                    | `text-[#0068FF]`                    |
| Filename text  | `text-gray-800`                     | `text-gray-800`                     |
| File size text | `text-gray-400`                     | `text-gray-400`                     |

---

### 2. Thông báo in-app khi có tin nhắn mới

**Web (`ChatSocketInitializer.tsx`):**

- `activeConversationId` lấy từ Redux state.
- Khi `message:new` arrive từ người khác:
  - Nếu `msg.conversationId !== activeConversationId` → `toast.info('senderName: nội dung', { autoClose: 4000, position: 'bottom-right' })` via `react-toastify`.
  - Browser notification (`new Notification(...)`) vẫn giữ, chỉ fire khi tab không focus.

**Mobile (`ChatSocketProvider.tsx` + `chatStore.ts` + `_layout.tsx`):**

- `inAppNotification: { id, title, body } | null` state trong chatStore.
- `showInAppNotification` / `clearInAppNotification` actions.
- ChatSocketProvider theo dõi `activeConversationId` qua `useRef` → gọi `showInAppNotification` khi cần.
- `NotificationBanner` component trong `_layout.tsx`: `Animated.View` slide-in từ trên, tự dismiss sau 4 giây.

---

### 3. Forward message – duplicate key warning

**Nguyên nhân (web):** Race condition — `forwardMessage.fulfilled` push message vào array, sau đó socket `message:new` deliver cùng `_id`.

**Fix (`chatSlice.ts` — web):**

```typescript
// forwardMessage.fulfilled reducer
if (!state.messages[convId].some((m) => m._id === msg._id)) {
  state.messages[convId].push(msg);
}
```

**Fix (`chatStore.ts` — mobile):**

```typescript
// forwardMessage action
set((s) => {
  const existing = s.messages[targetConversationId] ?? [];
  const alreadyExists = existing.some((m) => m._id === msg._id);
  return {
    messages: {
      ...s.messages,
      [targetConversationId]: alreadyExists ? existing : [...existing, msg],
    },
  };
});
```

---

### 4. Video thumbnail client-side

**Web (`MessageInput.tsx`):**

`extractVideoThumbnail(file: File): Promise<string | undefined>`

- Tạo `objectURL` → hidden `<video>` element → seek đến `min(duration * 0.1, 1s)`
- Canvas `drawImage` → `toDataURL('image/jpeg', 0.7)` tại 320px wide
- Timeout fallback 5s, cleanup objectURL
- Được gọi trong `handleFileSelect` → lưu data URL vào `att.preview`

`uploadFile(file, onProgress, thumbnailDataUrl?)` (extended):

1. Upload video gốc lên S3
2. Nếu `thumbnailDataUrl` & category = video: convert data URL → Blob → upload lên S3 như `image` category
3. Trả về `{ url, filename, size, mimeType, thumbnailUrl? }`

**Mobile:** Không có Canvas API → thumbnail lấy từ Lambda `__thumb.jpg` (sau khi Lambda xử lý) hoặc để trống. Preview strip trước khi gửi hiển thị placeholder video.

---

### 5. Video player với uploaded thumbnail

**Web (`MessageBubble.tsx` — `videoOnly` block):**

```tsx
{
  videos.map((v) => {
    const baseUrl = v.url.slice(0, v.url.lastIndexOf('.'));
    const posterUrl = v.thumbnailUrl ?? `${baseUrl}__thumb.jpg`;
    return (
      <video controls preload="metadata" poster={posterUrl}>
        <source src={`${baseUrl}__360p.mp4`} type="video/mp4" />
        <source src={v.url} type="video/mp4" />
      </video>
    );
  });
}
```

- `v.thumbnailUrl` = thumbnail đã upload từ client (luôn có)
- Fallback `__thumb.jpg` khi thumbnailUrl trống (Lambda đã xong)
- Chỉ dùng `__360p` + original (bỏ `__720p` không cần thiết)

**Mobile (`[id].tsx`):**

- Không có native video player (expo-av không được cài)
- Hiển thị thumbnail (`v.thumbnailUrl ?? __thumb.jpg`) + play icon overlay
- Tap → `Linking.openURL(v.url)` mở trong browser

---

### 6. Upload ảnh/video trên Mobile

**`src/services/uploadService.ts` (mới):**

- `uploadFile(uri, filename, mimeType, size, onProgress?)` → `UploadedAttachment`
- Flow: presign (`POST /api/upload/presign`) → `fetch(uri)` → Blob → `axios.PUT(uploadUrl, blob)`
- Sanitize filename (replace ký tự đặc biệt)
- FILE_SIZE_LIMITS: image 10 MB, video 50 MB

**`conversation/[id].tsx` — input area mới:**

- `pendingAttachments[]` state — mỗi item có `uri, filename, mimeType, size, type`
- Nút `Paperclip` → `expo-image-picker.launchImageLibraryAsync` (MultiSelect, All media types)
- Preview strip: ảnh thumbnail + video placeholder, nút ✕ xóa từng item
- `handleSend`: loop từng attachment → `uploadFile` → `sendMessage(conversationId, undefined, [uploaded])`; sau đó gửi text riêng nếu có

---

### 7. File card cải thiện (Mobile)

File card trong `MessageBubble` ([id].tsx) được cải thiện:

- Icon extension (DOC / PDF / MP4...) trong box tròn
- Hiển thị size (KB / MB)
- Màu sắc phân biệt sender/receiver (không transparent như trước)

---

### 10. Browser notification khi có tin nhắn mới

`ChatSocketInitializer.tsx` request permission khi mount. Khi `message:new` arrive từ người khác và tab không focus → `new Notification(...)` với tên sender và nội dung tóm tắt.

---

## 26. Quản lý Nhóm Chat (Group Chat Management)

### Tổng quan

Hệ thống hỗ trợ nhóm chat với phân quyền RBAC (Role-Based Access Control) gồm 3 vai trò:

| Vai trò                 | Quyền                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Owner** (Chủ nhóm)    | Toàn quyền: thêm/xóa thành viên, thay đổi vai trò, chuyển quyền, giải tán nhóm, cập nhật thông tin, cài đặt nhóm |
| **Admin** (Phó nhóm)    | Thêm thành viên, xóa thành viên (trừ owner/admin khác), cập nhật thông tin nhóm, ghim tin nhắn                   |
| **Member** (Thành viên) | Xem, chat, rời nhóm (khi `allowMemberInvite=true`: được thêm thành viên)                                         |

> **Giới hạn admin**: Một nhóm tối đa **5 admin** (không tính owner). Khi đã đủ 5 admin, `changeRole` sẽ throw `BadRequestException`.

> **System messages**: Mỗi hành động quản lý nhóm tự động tạo một tin nhắn hệ thống (type=`'system'`) kèm **tên người thực hiện** (`actorName` từ JWT payload). Các hành động sinh system message bao gồm:
>
> - Thêm/xóa/rời nhóm, đổi vai trò, chuyển quyền, giải tán nhóm
> - **Ghim / Bỏ ghim tin nhắn**: _"X đã ghim một tin nhắn"_ / _"X đã bỏ ghim một tin nhắn"_
> - **Cấm / Bỏ cấm thành viên**: _"X đã cấm một thành viên gửi tin nhắn"_ / _"X đã bỏ cấm một thành viên"_

### Schema

**Conversation** — thêm field `description`:

```
description?: String  // Mô tả nhóm (tối đa 500 ký tự)
```

**Participant** — thêm field `role`:

```
role: 'owner' | 'admin' | 'member'  // default: 'member'
```

### API Endpoints (chat-service → qua API Gateway)

| Method   | Endpoint                               | Mô tả                       | Quyền                   |
| -------- | -------------------------------------- | --------------------------- | ----------------------- |
| `GET`    | `/api/chat/conversations/:id/members`  | Lấy danh sách thành viên    | Participant             |
| `POST`   | `/api/chat/conversations/:id/members`  | Thêm thành viên             | Owner, Admin            |
| `DELETE` | `/api/chat/conversations/:id/members`  | Xóa thành viên              | Owner, Admin            |
| `POST`   | `/api/chat/conversations/:id/leave`    | Rời nhóm                    | Participant (trừ Owner) |
| `PATCH`  | `/api/chat/conversations/:id`          | Cập nhật thông tin nhóm     | Owner, Admin            |
| `PATCH`  | `/api/chat/conversations/:id/role`     | Thay đổi vai trò thành viên | Owner                   |
| `PATCH`  | `/api/chat/conversations/:id/transfer` | Chuyển quyền chủ nhóm       | Owner                   |
| `DELETE` | `/api/chat/conversations/:id`          | Giải tán nhóm               | Owner                   |

### Kafka Events

| Event                          | Payload chính                                | Mô tả                        |
| ------------------------------ | -------------------------------------------- | ---------------------------- |
| `chat.group.members_added`     | conversationId, addedUserIds, participants   | Thành viên mới được thêm     |
| `chat.group.member_removed`    | conversationId, removedUserId, participants  | Thành viên bị xóa            |
| `chat.group.member_left`       | conversationId, userId, participants         | Thành viên rời nhóm          |
| `chat.group.updated`           | conversationId, name?, avatar?, description? | Thông tin nhóm được cập nhật |
| `chat.group.role_changed`      | conversationId, targetUserId, newRole        | Vai trò thành viên thay đổi  |
| `chat.group.dissolved`         | conversationId, participants                 | Nhóm bị giải tán             |
| `chat.group.owner_transferred` | conversationId, oldOwnerId, newOwnerId       | Chuyển quyền chủ nhóm        |

### Socket Events (Gateway → Client)

Gateway consumer (`group-events.consumer.ts`) nhận Kafka events và emit tới tất cả participants qua Socket.io:

| Socket Event              | Xử lý client                                                          |
| ------------------------- | --------------------------------------------------------------------- |
| `group:members_added`     | Cập nhật participants, nếu user mới được thêm → refetch conversations |
| `group:member_removed`    | Xóa participant, nếu user bị xóa → refetch conversations              |
| `group:member_left`       | Xóa participant khỏi danh sách                                        |
| `group:updated`           | Cập nhật tên/avatar/mô tả nhóm                                        |
| `group:role_changed`      | Cập nhật vai trò thành viên                                           |
| `group:dissolved`         | Xóa conversation khỏi danh sách                                       |
| `group:owner_transferred` | Cập nhật vai trò owner/member                                         |

### Luồng hoạt động

#### Tạo nhóm

```
User → POST /api/chat/conversations { type: 'group', participantIds: [...], name: 'Tên nhóm' }
→ chat-service: Creator = owner, others = member
→ Kafka: chat.conversation.created → Gateway → Socket emit to participants
→ Client: conversation xuất hiện ở danh sách
```

#### Thêm thành viên

```
Owner/Admin → POST /api/chat/conversations/:id/members { memberIds: [...] }
→ chat-service: Verify role, add participants, insert system message
→ Kafka: chat.group.members_added → Gateway → Socket to all (old + new) participants
→ Client: Cập nhật danh sách thành viên
```

#### Chuyển quyền chủ nhóm

```
Owner → PATCH /api/chat/conversations/:id/transfer { newOwnerId }
→ chat-service: Old owner → member, new owner → owner
→ Kafka: chat.group.owner_transferred → Gateway → Socket to participants
→ Client: Cập nhật role hiển thị
```

#### Giải tán nhóm

```
Owner → DELETE /api/chat/conversations/:id
→ chat-service: Delete all messages + conversation
→ Kafka: chat.group.dissolved → Gateway → Socket to participants
→ Client: Xóa conversation khỏi danh sách, redirect về trang chủ
```

### Files liên quan

**Backend:**

- `services/chat/src/chat/schemas/conversation.schema.ts` — Schema với role + description
- `services/chat/src/chat/chat.service.ts` — 8 phương thức quản lý nhóm
- `services/chat/src/chat/chat.controller.ts` — 8 HTTP endpoints
- `services/chat/src/chat/guards/group-role.guard.ts` — RBAC helper
- `services/chat/src/chat/dto/` — DTOs (add-members, remove-member, update-group, change-role, transfer-owner)
- `services/chat/src/kafka/events/chat.events.ts` — 7 Kafka events + interfaces
- `gateway/api-gateway/src/socket/group-events.consumer.ts` — Kafka consumer cho group events

**Web Frontend:**

- `apps/web/src/store/slices/chatSlice.ts` — 8 thunks + 7 socket reducers
- `apps/web/src/providers/ChatSocketInitializer.tsx` — 7 group event listeners
- `apps/web/src/pages/private/chat/components/CreateGroupModal.tsx` — Modal tạo nhóm
- `apps/web/src/pages/private/chat/components/GroupInfoPanel.tsx` — Panel quản lý nhóm

**Mobile App:**

- `apps/mobile/src/store/chatStore.ts` — 7 group actions + 7 socket handlers
- `apps/mobile/src/hooks/useChatSocket.ts` — 7 group event listeners
- `apps/mobile/app/create-group.tsx` — Màn hình tạo nhóm
- `apps/mobile/app/group-info/[id].tsx` — Màn hình thông tin nhóm
- `apps/mobile/app/conversation/[id].tsx` — Hiển thị system messages + sender name trong nhóm

---

## 27. Bug Fixes & Cải thiện Nhóm Chat (2026-04-07)

### 27.1 Sửa lỗi Field Name Mismatch giữa Backend và Frontend

**Vấn đề:** Backend Kafka events sử dụng tên trường khác với frontend socket handlers, dẫn đến các tính năng real-time không hoạt động.

| Event                  | Backend gửi                 | Frontend mong đợi         | Ảnh hưởng                            |
| ---------------------- | --------------------------- | ------------------------- | ------------------------------------ |
| `group:role_changed`   | `memberId`                  | `targetUserId`            | Nâng/hạ quyền không cập nhật liền    |
| `group:updated`        | `changes: { name, avatar }` | `{ name, avatar }` (flat) | Đổi tên/ảnh nhóm không cập nhật liền |
| `group:member_removed` | `removedMemberId`           | `removedUserId`           | Xóa thành viên không phản ánh        |
| `group:members_added`  | `newMemberIds`              | `addedUserIds`            | Thành viên mới không thấy nhóm       |

**Giải pháp:** Normalize payload trong socket handler trước khi dispatch vào store:

```typescript
// ChatSocketInitializer.tsx (Web)
const onGroupRoleChanged = (payload: any) => {
  const targetUserId = payload.targetUserId || payload.memberId;
  dispatch(socketGroupRoleChanged({ ...payload, targetUserId }));
};

const onGroupUpdated = (payload: any) => {
  const normalized = { conversationId: payload.conversationId, ...payload.changes };
  dispatch(socketGroupUpdated(normalized));
};

const onGroupMemberRemoved = (payload: any) => {
  const removedUserId = payload.removedUserId || payload.removedMemberId;
  dispatch(socketGroupMemberRemoved({ ...payload, removedUserId }));
};
```

**Files thay đổi:**

- `apps/web/src/providers/ChatSocketInitializer.tsx` — Normalize tất cả field name
- `apps/mobile/src/hooks/useChatSocket.ts` — Cùng logic normalize
- `gateway/api-gateway/src/socket/group-events.consumer.ts` — Fix `removedUserId` field

### 27.2 Tạo nhóm không thông báo thành viên khác

**Vấn đề:** `createConversation` trong chat-service không emit Kafka event khi tạo nhóm → các thành viên khác (ngoài người tạo) phải refresh trang mới thấy nhóm mới.

**Giải pháp:** Emit `GROUP_MEMBERS_ADDED` event sau khi tạo nhóm:

```typescript
// chat.service.ts
if (dto.type === 'group') {
  const otherMemberIds = allParticipantIds.filter((id) => id !== userId);
  await this.kafkaProducer.emit(CHAT_EVENTS.GROUP_MEMBERS_ADDED, {
    conversationId: conversation._id.toString(),
    addedBy: userId,
    newMemberIds: otherMemberIds,
    participants: allParticipantIds,
  });
}
```

**File thay đổi:** `services/chat/src/chat/chat.service.ts`

### 27.3 Batch User Profile API

**Vấn đề:** Trong nhóm chat, thành viên không phải bạn bè không hiển thị tên/avatar (do `friends.find()` trả về null).

**Giải pháp:**

- Backend: `POST /api/users/batch` nhận `{ userIds: string[] }`, trả về `UserProfile[]`
- Frontend: `fetchGroupMemberProfiles` thunk cache profiles, fallback khi `friends.find()` null

**Files thay đổi:**

- `services/user/src/user/user.controller.ts` — Endpoint `POST /batch`
- `services/user/src/user/user.service.ts` — `findByIds()` method
- `apps/web/src/services/userServices.ts` — API client (new file)
- `apps/web/src/store/slices/chatSlice.ts` — `groupMemberProfiles` state + thunk

### 27.4 Cải thiện Image Grid (Mobile)

**Vấn đề:** Mobile ImageGrid hiển thị ảnh cố định 100×100px, không tối ưu layout như web.

**Giải pháp:** Cập nhật `ImageGrid` component trong mobile:

- 1 ảnh: hiển thị 60% width màn hình, vuông, bo góc 12px
- 2 ảnh: 2 cột cạnh nhau, mỗi ảnh chiếm 50% grid width
- 3 ảnh: 1 ảnh lớn trên + 2 ảnh nhỏ dưới (giống web)
- 4+ ảnh: 2×2 grid với overlay `+N` cho ảnh thừa

**File thay đổi:** `apps/mobile/app/conversation/[id].tsx`

---

## 28. Hệ thống Presence (Hoạt động trực tuyến)

### Mô tả

Hiển thị trạng thái online/offline và "Hoạt động X phút trước" cho từng user, tương tự Facebook Messenger.

### Kiến trúc

```
┌─────────────┐    connect/disconnect    ┌──────────────────────┐
│   Client    │ ◄──────────────────────► │  Socket Gateway      │
│ (Web/Mobile)│                          │  userSockets Map     │
│             │    user:online           │  lastSeen Map        │
│             │ ◄────────────────────────│                      │
│             │    user:offline          │  isUserOnline()      │
│             │ ◄────────────────────────│                      │
│             │                          │                      │
│             │    presence:check ──────►│  @SubscribeMessage   │
│             │ ◄── presence:result ────│  returns batch status │
└─────────────┘                          └──────────────────────┘
```

### Backend — Socket Gateway

Thêm vào `socket.gateway.ts`:

| Thành phần                      | Mô tả                                                                                      |
| ------------------------------- | ------------------------------------------------------------------------------------------ |
| `lastSeen: Map<string, string>` | Lưu timestamp ISO khi user disconnect                                                      |
| `handleDisconnect`              | Khi socket cuối disconnect → lưu lastSeen, emit `user:offline`                             |
| `handleJoin`                    | Khi socket đầu connect → emit `user:online`                                                |
| `presence:check`                | Client gửi `{ userIds: string[] }` → server trả `presence:result` với trạng thái từng user |

### Frontend — Redux / Zustand State

```typescript
interface PresenceInfo {
  online: boolean;
  lastSeen?: string; // ISO timestamp
}

// State
userPresence: Record<string, PresenceInfo>;

// Reducers
setUserOnline({ userId }); // → { online: true }
setUserOffline({ userId, lastSeen }); // → { online: false, lastSeen }
setPresenceBatch(Record<string, PresenceInfo>); // batch update
```

### Frontend — Hiển thị

**ChatRoom header:**

- Chat đơn: `"Đang hoạt động"` (xanh lá) hoặc `"Hoạt động 5 phút trước"` (xám)
- Chat nhóm: `"8 thành viên · 3 đang hoạt động"`

**ConversationList:**

- Avatar có chấm xanh/xám dựa vào `userPresence[otherUserId]?.online`

**Socket events đăng ký:**

- `user:online` → `setUserOnline`
- `user:offline` → `setUserOffline`
- `presence:result` → `setPresenceBatch`

**Emit khi mở conversation:**

```typescript
appSocket.emit('presence:check', { userIds: [...participantIds] });
```

### Files liên quan

- `gateway/api-gateway/src/socket/socket.gateway.ts` — Presence tracking logic
- `apps/web/src/store/slices/chatSlice.ts` — `userPresence` state + reducers
- `apps/web/src/providers/ChatSocketInitializer.tsx` — Socket event listeners
- `apps/web/src/pages/private/chat/components/ChatRoom.tsx` — Header hiển thị + emit check
- `apps/web/src/pages/private/chat/components/ConversationList.tsx` — Online dot
- `apps/web/src/services/appSocket.ts` — Thêm `emit()` method
- `apps/web/src/components/UserAvatar.tsx` — `online` prop hiển thị chấm xanh/xám

---

## 29. Chỉnh sửa Tin nhắn (Edit Message)

### Điều kiện

- Chỉ người gửi mới được chỉnh sửa (`senderId === currentUserId`)
- Trong vòng **30 phút** kể từ lúc gửi (`EDIT_WINDOW_MS = 30 * 60 * 1000`)
- Không chỉnh sửa tin đã thu hồi
- Không chỉnh sửa tin nhắn hệ thống (`type = 'system'`)

### Hành vi

- Sau khi chỉnh sửa: `isEdited = true`, `editedAt = new Date()`
- Tất cả participants nhận socket event `message:edited`
- UI hiển thị nhãn _"(đã chỉnh sửa)"_ kèm timestamp dưới nội dung

### Luồng

```
[User hover tin nhắn → click "Chỉnh sửa" (Pencil icon)]
     ↓
[MessageInput vào chế độ edit: hiển thị banner "Đang chỉnh sửa" + nội dung cũ điền sẵn]
     ↓
[User sửa nội dung + Enter / nhấn "Lưu"]
     ↓
dispatch(editMessage({ messageId, content }))
PATCH /api/chat/messages/:id
Body: { content: "nội dung mới" }
     ↓
[Chat Service — editMessage()]
1. Tìm message
2. Kiểm tra senderId === userId
3. Kiểm tra elapsed < EDIT_WINDOW_MS
4. msg.content = dto.content; msg.isEdited = true; msg.editedAt = new Date()
5. Emit Kafka: chat.message.edited { messageId, conversationId, participants, content, editedAt }
     ↓
[Gateway → ChatEventsConsumer]
6. emitToUser(uid, 'message:edited', event) cho TẤT CẢ participants
     ↓
[Client nhận 'message:edited']
7. dispatch(socketMessageEdited(payload))
   → Cập nhật content + isEdited + editedAt trong store
     ↓
[MessageBubble re-render]
8. Hiển thị nội dung mới + "(đã chỉnh sửa)" màu xám dưới text
```

### API

| Method | Path                     | Auth | Body              | Response        |
| ------ | ------------------------ | ---- | ----------------- | --------------- |
| PATCH  | `/api/chat/messages/:id` | ✅   | `{ content: "" }` | Updated message |

### Socket Event

| Event            | Payload                                            |
| ---------------- | -------------------------------------------------- |
| `message:edited` | `{ messageId, conversationId, content, editedAt }` |

### Triển khai Frontend

**Web** (`apps/web/`):

- `ChatRoom.tsx` — `editingMessage` state; click Pencil → set state + pre-fill input
- `MessageBubble.tsx` — `canEdit` prop; hiển thị button "Chỉnh sửa" (Pencil icon)
- `chatSlice.ts` — `socketMessageEdited` reducer cập nhật message trong store

**Mobile** (`apps/mobile/`):

- `chatServices.ts` — `editMessage(messageId, content)` gọi `PATCH /api/chat/messages/:id`
- `chatStore.ts` — `editMessage(messageId, conversationId, content)` action; `socketMessageEdited` cập nhật Zustand store
- `hooks/useChatSocket.ts` — lắng nghe socket event `message:edited` → gọi `socketMessageEdited`
- `conversation/[id].tsx`:
  - `MessageBubble` hiển thị button "Chỉnh sửa" (Pencil icon) khi `canEdit = isMine && !isRevoked && !isSystemMsg && diff < 30min`
  - `editingMessage` state; click → `setEditingMessage(msg)` + pre-fill `setText(msg.content)`
  - Banner vàng "Đang chỉnh sửa" phía trên input với nút ✕ để huỷ
  - `handleSend` kiểm tra `editingMessage`: nếu có → gọi `storeEditMessage(id, convId, text)`, không upload file

---

## 30. Ghim Tin nhắn (Pin Message)

### Điều kiện

- Chat đơn (direct): cả hai participants đều có thể ghim
- Chat nhóm (group): chỉ owner/admin mới được ghim
- Tối đa **50 tin nhắn** được ghim mỗi conversation
- Không ghim tin nhắn đã thu hồi

### Schema

Trường `pinnedMessages: PinnedMessage[]` trong `Conversation` (xem [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)):

```
pinnedMessages[]: { messageId, pinnedBy, pinnedAt }
```

### API

| Method | Path                                 | Auth | Mô tả                     |
| ------ | ------------------------------------ | ---- | ------------------------- |
| POST   | `/api/chat/messages/:id/pin`         | ✅   | Ghim tin nhắn             |
| DELETE | `/api/chat/messages/:id/pin`         | ✅   | Bỏ ghim tin nhắn          |
| GET    | `/api/chat/conversations/:id/pinned` | ✅   | Lấy danh sách tin đã ghim |

### Socket Events

| Event              | Payload                                             |
| ------------------ | --------------------------------------------------- |
| `message:pinned`   | `{ messageId, conversationId, pinnedBy, pinnedAt }` |
| `message:unpinned` | `{ messageId, conversationId }`                     |

### UI — Pinned Message Banner

- **Banner đa ghim**: hiển thị tin ghim hiện tại với cỏ (N/total) khi có nhiều tin ghìm
- Nút `ChevronDown` (↵) để cycle qua lần lượt tựng tin đã ghim
- Click vào nội dung banner → scroll đến tin gốc + highlight 2 giây
- **Thông báo kiểu Zalo**: sau khi ghim/bỏ ghim, hiển thị thanh đen mỏ nhạt phía dưới vùng tin nhắn (tự ẩn sau 4s):
  ```
  📌 Bạn đã ghim 1 tin nhắn [preview...] • Xem
  ```
- Nhấn **Xem** để scroll tới đúng tin đó

---

## 31. Cài đặt Nhóm Chat (Conversation Settings)

### Điều kiện

- Chỉ **owner** mới được thay đổi cài đặt nhóm

### Các cài đặt

| Setting                    | Default | Mô tả                                                     |
| -------------------------- | ------- | --------------------------------------------------------- |
| `onlyAdminCanSend`         | `false` | Khi `true`: chỉ owner/admin được gửi tin; member bị block |
| `allowMemberInvite`        | `true`  | Khi `false`: chỉ owner/admin được thêm thành viên mới     |
| `onlyAdminCanPin`          | `false` | Khi `true`: chỉ owner/admin được ghim tin nhắn            |
| `requireJoinApproval`      | `false` | (Reserved) Duyệt thành viên trước khi vào nhóm            |
| `chatHistoryForNewMembers` | `true`  | (Reserved) Cho phép member mới xem lịch sử cũ             |

### Enforcement

- `sendMessage`: kiểm tra `participant.isBanned` và `settings.onlyAdminCanSend`
- `addMembers`: kiểm tra `settings.allowMemberInvite` khi caller là `member`
- `pinMessage` / `unpinMessage`: kiểm tra `settings.onlyAdminCanPin`; khi `true` chỉ owner/admin được thao tác

### UI Frontend

- **Web**: Toggle button trong `GroupInfoPanel.tsx` (mục Cài đặt nhóm, chỉ hiển với owner)
- **Mobile**: Toggle button trong màn hình `GroupInfoScreen` (group-info/[id].tsx), chỉ hiển với owner
- Khi `onlyAdminCanSend = true` và người dùng hiện tại không phải owner/admin:
  - Ờ nhập tin nhắn bị ẩn/thay thế bằng thanh thông báo:
  ```
  ⓘ Chỉ trưởng/phó cộng đồng được gửi tin nhắn vào cộng đồng.
  ```
- Khi `onlyAdminCanPin = true` và người dùng không phải owner/admin:
  - Tùy chọn **Ghim tin nhắn** bị ẩn khỏi context menu (long-press) trên cả web lẫn mobile
- Cập nhật trạng thái toggle ngay lập tức (optimistic update) trước khi server xác nhận
- Socket event `conversation:settings` cũng cập nhật Redux/Zustand state để đồng bộ realtime cho các thiết bị khác

### API

| Method | Path                                   | Auth | Body                                             | Mô tả                    |
| ------ | -------------------------------------- | ---- | ------------------------------------------------ | ------------------------ |
| PATCH  | `/api/chat/conversations/:id/settings` | ✅   | `{ onlyAdminCanSend?, allowMemberInvite?, ... }` | Cập nhật cài đặt (owner) |

### Socket Event

| Event                   | Payload                        |
| ----------------------- | ------------------------------ |
| `conversation:settings` | `{ conversationId, settings }` |

---

## 32. Ban Thành viên (Member Ban)

### Điều kiện

- Chỉ **owner/admin** mới được ban thành viên
- Admin không được ban admin hoặc owner khác
- Ban có thể có thời hạn (`bannedUntil`) hoặc vĩnh viễn (`bannedUntil = null`)

### Hành vi

- Khi bị ban: `participant.isBanned = true`, `participant.bannedUntil = DateOrNull`
- `sendMessage` tự động kiểm tra: nếu `bannedUntil` đã hết hạn → auto unban trước khi cho gửi
- Member bị ban nhận socket event `member:banned`

### UI Frontend (thành viên bị cấm)

Khi người dùng đang bị cấm (`isBanned = true`):

- **Web**: Ô input bị thay thế bằng thanh đỏ (`bg-red-50`):
  ```
  🚫 Bạn đang bị cấm gửi tin nhắn trong nhóm này.
  ```
- **Mobile**: Tương tự, thanh nền đỏ thay thế input area
- **Danh sách thành viên** (bộ nhìn của admin/owner): Thành viên bị cấm hiện badge **"Bị cấm"** đỏ kề tên
- **Bộ nhìn admin/owner**: Có nút **Hủy cấm** (icon Ban màu xanh lá) trong member action sheet/list, click → gọi `DELETE .../ban`

### API

| Method | Path                                           | Auth | Body               | Mô tả            |
| ------ | ---------------------------------------------- | ---- | ------------------ | ---------------- |
| POST   | `/api/chat/conversations/:id/members/:uid/ban` | ✅   | `{ bannedUntil? }` | Ban thành viên   |
| DELETE | `/api/chat/conversations/:id/members/:uid/ban` | ✅   | —                  | Unban thành viên |

### Socket Events

| Event             | Payload                                     |
| ----------------- | ------------------------------------------- |
| `member:banned`   | `{ conversationId, memberId, bannedUntil }` |
| `member:unbanned` | `{ conversationId, memberId }`              |

> **System messages**: `banMember` và `unbanMember` cũng tạo tin nhắn hệ thống trong conversation:
> _"X đã cấm một thành viên gửi tin nhắn"_ / _"X đã bỏ cấm một thành viên"_

---

## 33. Cài đặt Cá nhân Cuộc trò chuyện (Per-user Settings)

Mỗi participant có thể cài đặt riêng cho conversation mà **không ảnh hưởng** đến người khác.

### Các cài đặt

| Trường       | Giá trị        | Mô tả                                             |
| ------------ | -------------- | ------------------------------------------------- |
| `isPinned`   | `boolean`      | Ghim conversation lên đầu danh sách               |
| `isArchived` | `boolean`      | Ẩn khỏi danh sách chính, vào thư mục "Đã lưu trữ" |
| `isMuted`    | `boolean`      | Tắt thông báo push cho conversation này           |
| `muteUntil`  | `Date \| null` | Tắt thông báo đến một thời điểm cụ thể            |

### API

| Method | Path                             | Auth | Body                                               | Mô tả               |
| ------ | -------------------------------- | ---- | -------------------------------------------------- | ------------------- |
| PATCH  | `/api/chat/conversations/:id/me` | ✅   | `{ isPinned?, isArchived?, isMuted?, muteUntil? }` | Lưu cài đặt cá nhân |

---

## 34. Typing Indicator

### Kiến trúc

Typing indicator được xử lý **hoàn toàn qua Socket.io** — không qua Kafka, không lưu DB.

```
[User bắt đầu gõ (debounce 300ms)]
     ↓
appSocket.emit('typing:start', { conversationId, userId })
     ↓
[Socket Gateway]
typingUsers.get(conversationId).set(userId, timeout)
setTimeout(() => auto-clear sau 5 giây
broadcastTyping(conversationId):
  → emit 'typing:update' { conversationId, typingUserIds: [...] }
  → đến conversation:{conversationId} room (trừ sender)
     ↓
[Client nhận 'typing:update']
dispatch(setTypingUsers({ conversationId, userIds }))
     ↓
[ChatRoom header / input area]
Hiển thị "Nguyễn Văn A đang gõ..." hoặc "3 người đang gõ..."
```

### Socket Events

| Direction       | Event           | Payload                                       |
| --------------- | --------------- | --------------------------------------------- |
| Client → Server | `typing:start`  | `{ conversationId, userId }`                  |
| Client → Server | `typing:stop`   | `{ conversationId, userId }`                  |
| Server → Client | `typing:update` | `{ conversationId, typingUserIds: string[] }` |

### Tham gia Room

Để nhận `typing:update`, client cần join room `conversation:{conversationId}`:

```typescript
// Khi mở conversation
appSocket.emit('conversation:join', { conversationId });
// Khi đóng conversation
appSocket.emit('conversation:leave', { conversationId });
```

### Auto-cleanup

- Nếu user dừng gõ mà không emit `typing:stop` → tự động clear sau **5 giây**
- Khi user disconnect → toàn bộ trạng thái typing bị clear

---

## 35. Mark as Read / Unread Count

### Cơ chế

Mỗi participant có `lastReadAt: Date | null` lưu trong `conversation.participants[]`. Unread count được tính **khi load danh sách conversation** bằng cách so sánh `lastMessage.sentAt > participant.lastReadAt`.

### Khi nào gọi `markAsRead`

- **Web**: Mỗi khi `conversationId` trong URL thay đổi (user click vào conversation hoặc navigate trực tiếp). `ChatPage.tsx` gọi `chatServices.markAsRead(conversationId)` sau `setActiveConversation`.
- **Mobile**: Khi `ConversationScreen` mount hoặc `conversationId` thay đổi. `conversation/[id].tsx` gọi `chatServices.markAsRead(conversationId)` trong `useEffect` cùng với `setActiveConversation`.

> **Lưu ý quan trọng**: Nếu chỉ gọi `setActiveConversation` (clear Redux/Zustand local state) mà **không** gọi `markAsRead` API, badge unread sẽ trở lại sau khi refresh vì `lastReadAt` trên backend chưa được cập nhật.

### Luồng

```
[User mở conversation]
     ↓
setActiveConversation(convId)          // clear badge ngay lập tức (UI)
chatServices.markAsRead(convId)        // ghi lastReadAt = now lên backend
     ↓
[Chat Service — markAsRead()]
participant.lastReadAt = new Date()
     ↓
[Sau khi refresh — fetchConversations()]
Tính lại: lastMessage.sentAt > lastReadAt → false → unreadCount = 0
     ↓
[ConversationList]
Badge số đỏ không hiện lại
```

### API

| Method | Path                               | Auth | Mô tả                             |
| ------ | ---------------------------------- | ---- | --------------------------------- |
| POST   | `/api/chat/conversations/:id/read` | ✅   | Đặt `lastReadAt = now` cho caller |

### Tính Unread Count khi khởi động (fetchConversations)

```typescript
// chatSlice (web) / chatStore (mobile)
for (const conv of conversations) {
  if (!conv.lastMessage) continue;
  const me = conv.participants.find((p) => p.userId === userId);
  if (!me) continue;
  const lastRead = me.lastReadAt;
  if (!lastRead || new Date(conv.lastMessage.sentAt) > new Date(lastRead)) {
    unreadCounts[conv._id] = 1; // có tin chưa đọc
  }
}
```

---

_Tài liệu cập nhật lần cuối: 2026-04-14 — Bao gồm tất cả tính năng từ chat_nghiep_vu.docx._
