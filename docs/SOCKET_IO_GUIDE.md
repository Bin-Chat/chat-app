# Socket.io — Hướng dẫn từ A đến Z trong dự án Bin Chat

## 1. Socket.io là gì?

### HTTP truyền thống — "hỏi-đáp"

Bình thường, trình duyệt giao tiếp với server theo kiểu **HTTP request/response**:

```
Browser                    Server
  │── GET /api/friends ────▶│
  │◀─── 200 OK [data] ──────│
  │                          │
  │  (sau 5 giây...)         │
  │── GET /api/friends ────▶│   ← browser phải hỏi lại
  │◀─── 200 OK [data] ──────│
```

- Browser **chủ động hỏi**, server **trả lời**.
- Server **không thể** chủ động đẩy dữ liệu về browser.
- Nếu muốn cập nhật real-time, browser phải **polling** (hỏi lại mỗi vài giây) — rất lãng phí.

### WebSocket — "kênh 2 chiều luôn mở"

**WebSocket** giải quyết vấn đề bằng cách tạo một **kết nối TCP bền vững** giữa browser và server:

```
Browser                    Server
  │── WebSocket Handshake ──▶│   (bắt đầu từ HTTP Upgrade)
  │◀── 101 Switching ────────│
  │                          │
  │        [kết nối mở — cả 2 đầu đều có thể gửi]
  │                          │
  │◀── "bạn có lời mời" ─────│   ← server chủ động đẩy
  │                          │
  │── "tôi accept bạn X" ───▶│   ← browser gửi bất kỳ lúc nào
  │                          │
  │◀── "bạn X đã accept" ────│   ← server đẩy lại
```

### Socket.io là gì so với WebSocket thuần?

**Socket.io** là thư viện xây trên WebSocket, thêm nhiều tính năng:

| Tính năng           | WebSocket thuần  | Socket.io |
| ------------------- | ---------------- | --------- |
| Kết nối 2 chiều     | ✅               | ✅        |
| Tự động reconnect   | ❌               | ✅        |
| Fallback về polling | ❌               | ✅        |
| Rooms (phòng)       | ❌               | ✅        |
| Namespaces          | ❌               | ✅        |
| Events có tên       | ❌ (chỉ message) | ✅        |

**Rooms** là tính năng quan trọng nhất mà dự án này dùng.

---

## 2. Khái niệm cốt lõi

### Event (sự kiện)

Thay vì gửi raw message, Socket.io dùng **named events**:

```javascript
// Gửi event
socket.emit('friend:request_received', { friendshipId: '...', requesterId: '...' });

// Lắng nghe event
socket.on('friend:request_received', (data) => {
  console.log('Có lời mời mới:', data);
});
```

### Room (phòng)

Room là **nhóm các socket**. Server có thể broadcast đến tất cả socket trong một room:

```javascript
// Server: đưa socket vào room
socket.join('user:abc-123');

// Server: gửi event đến tất cả trong room
server.to('user:abc-123').emit('friend:request_received', payload);
```

Trong dự án này, **mỗi user có 1 room riêng** tên `user:{userId}`. Dù user mở 5 tab trình duyệt, tất cả đều ở trong cùng room → nhận được event ngay lập tức trên tất cả tab.

### Socket ID

Mỗi **kết nối WebSocket** có một ID duy nhất (string ngẫu nhiên). Một user có thể có nhiều socket ID (nhiều tab) nhưng chỉ 1 userId.

---

## 3. Kiến trúc trong dự án

```
┌───────────────────────────────────────────────────────────────────────┐
│                       BACKEND                                         │
│                                                                       │
│  Friend Service (:3025)                                               │
│  ├─ sendRequest()   → kafkaClient.emit('friend.request.sent', ...)    │
│  ├─ acceptRequest() → kafkaClient.emit('friend.request.accepted', ...)│
│  └─ ...                                                               │
│                              │                                        │
│                   Kafka (Redpanda broker)                             │
│                              │                                        │
│  API Gateway (:3000)         │                                        │
│  ├─ FriendEventsConsumer ────┘  (subscribe Kafka topics)             │
│  │    └─ socketGateway.emitToUser(userId, event, payload)            │
│  │                                                                    │
│  └─ SocketGateway (WebSocket server)                                  │
│       ├─ Lắng nghe kết nối từ browser                                │
│       ├─ Nhận event 'join' → đưa socket vào room user:{userId}       │
│       └─ emitToUser() → server.to('user:{id}').emit(event, payload)  │
│                                                                       │
└──────────────────────────────────│───────────────────────────────────┘
                                   │ WebSocket (ws://)
┌──────────────────────────────────│───────────────────────────────────┐
│                       FRONTEND                                        │
│                                                                       │
│  FriendSocketInitializer (providers/)                                 │
│  └─ useEffect → friendSocket.connect(userId)                          │
│       ├─ socket.emit('join', { userId })  → đăng ký room             │
│       ├─ socket.on('friend:request_received') → dispatch + toast     │
│       ├─ socket.on('friend:request_accepted') → dispatch + fetch     │
│       └─ ...                                                          │
│                                                                       │
│  Redux Store (friendSlice)                                            │
│  ├─ receivedRequests: FriendRequest[]                                 │
│  ├─ friends: FriendItem[]                                             │
│  └─ sentRequests: SentRequest[]                                       │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 4. Backend — SocketGateway

File: `gateway/api-gateway/src/socket/socket.gateway.ts`

```typescript
@WebSocketGateway({
  cors: { origin: 'http://localhost:5173', credentials: true },
})
export class SocketGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server; // ← Server socket.io, dùng để broadcast

  // Map: userId → Set<socketId>
  // Dùng để track xem user nào đang kết nối (hỗ trợ multi-tab)
  private readonly userSockets = new Map<string, Set<string>>();

  // Gọi khi có browser kết nối WebSocket
  handleConnection(client: Socket) {
    console.log('Connected:', client.id);
  }

  // Gọi khi browser ngắt kết nối (đóng tab, mất mạng...)
  handleDisconnect(client: Socket) {
    const userId = client.data?.userId;
    if (userId) {
      const sockets = this.userSockets.get(userId);
      sockets?.delete(client.id);
      if (sockets?.size === 0) this.userSockets.delete(userId);
    }
  }

  // Lắng nghe event 'join' từ browser
  // Browser gửi: socket.emit('join', { userId: 'abc-123' })
  @SubscribeMessage('join')
  handleJoin(@MessageBody() data: { userId: string }, @ConnectedSocket() client: Socket) {
    client.data.userId = data.userId; // lưu vào socket metadata
    client.join(`user:${data.userId}`); // đưa vào room
    // track socket
    if (!this.userSockets.has(data.userId)) {
      this.userSockets.set(data.userId, new Set());
    }
    this.userSockets.get(data.userId)!.add(client.id);
  }

  // Hàm tiện ích: gửi event đến tất cả socket của 1 user
  emitToUser(userId: string, event: string, payload: unknown) {
    // server.to(room) → tìm tất cả socket trong room → emit event
    this.server.to(`user:${userId}`).emit(event, payload);
  }
}
```

**Điểm quan trọng:**

- `@WebSocketServer()` inject instance của socket.io `Server` vào property `server`.
- `@SubscribeMessage('join')` decorates handler cho event có tên `'join'`.
- `client.join(room)` đưa socket này vào room — sau đó `server.to(room).emit(...)` sẽ deliver đến socket này.
- `OnGatewayConnection` / `OnGatewayDisconnect` là interfaces của NestJS để hook vào lifecycle.

---

## 5. Backend — FriendEventsConsumer

File: `gateway/api-gateway/src/socket/friend-events.consumer.ts`

```typescript
@Controller()
export class FriendEventsConsumer {
  constructor(private readonly socketGateway: SocketGateway) {}

  // @EventPattern('topic-name') → NestJS Kafka consumer
  // Khi Kafka có message với topic này, NestJS gọi hàm này
  @EventPattern('friend.request.sent')
  handleRequestSent(@Payload() event: FriendRequestSentEvent) {
    // Chỉ addressee (người nhận lời mời) mới được notify
    this.socketGateway.emitToUser(event.addresseeId, 'friend:request_received', event);
  }

  @EventPattern('friend.request.accepted')
  handleRequestAccepted(@Payload() event: FriendRequestAcceptedEvent) {
    // Notify CẢ 2 người:
    // - requester: "lời mời của tôi được chấp nhận"
    // - addressee: "tôi vừa chấp nhận, danh sách bạn cần update"
    this.socketGateway.emitToUser(event.requesterId, 'friend:request_accepted', event);
    this.socketGateway.emitToUser(event.addresseeId, 'friend:request_accepted', event);
  }

  // ... tương tự cho các events còn lại
}
```

**Luồng dữ liệu:** Friend Service → Kafka topic → FriendEventsConsumer → SocketGateway.emitToUser → browser

---

## 6. Frontend — friendSocket service

File: `apps/web/src/services/friendSocket.ts`

```typescript
import { io, Socket } from 'socket.io-client';

let socket: Socket | null = null; // singleton — chỉ 1 kết nối duy nhất

export const friendSocket = {
  connect(userId: string) {
    if (socket?.connected) return; // tránh connect 2 lần

    socket = io('/', {
      path: '/socket.io', // đường dẫn WebSocket endpoint
      withCredentials: true, // gửi cookie JWT lên server
      transports: ['websocket', 'polling'], // thử WebSocket trước, fallback về polling
    });

    socket.on('connect', () => {
      // Sau khi kết nối thành công, đăng ký vào room của user
      socket?.emit('join', { userId });
    });

    socket.on('disconnect', (reason) => {
      console.log('Disconnected:', reason);
      // socket.io tự reconnect nếu reason !== 'io client disconnect'
    });
  },

  disconnect() {
    socket?.disconnect();
    socket = null;
  },

  on(event: string, callback: Function) {
    socket?.on(event, callback);
  },

  off(event: string, callback?: Function) {
    socket?.off(event, callback);
  },
};
```

**Tại sao dùng singleton (`let socket`)?**

- Chỉ được tạo 1 kết nối WebSocket duy nhất cho toàn app.
- Nếu tạo nhiều instance, server sẽ thấy nhiều socket từ cùng browser — gây duplicate events.

**`transports: ['websocket', 'polling']`:**

- Thử kết nối bằng WebSocket trước.
- Nếu browser/proxy không support → fallback về HTTP long-polling (chậm hơn nhưng luôn hoạt động).

---

## 7. Frontend — FriendSocketInitializer

File: `apps/web/src/providers/FriendSocketInitializer.tsx`

```typescript
export function FriendSocketInitializer() {
  const dispatch = useAppDispatch();
  const user = useAppSelector((s) => s.auth.user);

  useEffect(() => {
    if (!user) {
      friendSocket.disconnect(); // logout → ngắt kết nối
      return;
    }

    friendSocket.connect(user.id); // đăng nhập → kết nối

    // ── Đăng ký handlers cho từng event ──────────────────
    const onRequestReceived = (_payload: any) => {
      toast.info('Bạn có lời mời kết bạn mới');
      // Fetch lại từ API thay vì dùng payload vì payload socket
      // chỉ có ID, không có thông tin đầy đủ của sender
      dispatch(fetchReceivedRequests());
    };

    const onRequestAccepted = (payload: any) => {
      // payload.requesterId: ID của người đã gửi lời mời ban đầu
      // Chỉ toast cho requester, không toast cho người vừa accept
      if (payload.requesterId === user.id) {
        toast.success('Lời mời kết bạn đã được chấp nhận');
      }
      dispatch(socketRequestAccepted(payload)); // cập nhật store
      dispatch(fetchFriends()); // refresh danh sách bạn
    };

    // ... register các events khác

    // ── Cleanup khi component unmount hoặc user thay đổi ──
    // QUAN TRỌNG: phải off handlers cũ trước khi đăng ký handlers mới
    // Nếu không → mỗi lần user object thay đổi, thêm 1 handler mới → duplicate
    return () => {
      friendSocket.off('friend:request_received', onRequestReceived);
      friendSocket.off('friend:request_accepted', onRequestAccepted);
      // ...
    };
  }, [user, dispatch]); // re-run khi user thay đổi (login/logout)

  return null; // không render UI gì
}
```

**Tại sao return null?**
Đây là pattern **"invisible component"** trong React — component chỉ chứa side effects (`useEffect`), không có UI. Được mount 1 lần trong `App.tsx` ở ngoài router, nên luôn active dù navigate đến trang nào.

**Tại sao `fetchReceivedRequests()` thay vì dùng payload?**

- Socket payload chỉ chứa: `{ friendshipId, requesterId, addresseeId, sentAt }` — không có tên, avatar của sender.
- `FriendRequest` type cần: `{ friendshipId, sentAt, sender: { id, fullName, avatar, ... } }`.
- Nếu dùng payload trực tiếp → card hiển thị "(Chưa đặt tên)".
- Giải pháp: dùng socket event như **trigger signal**, còn data thì fetch từ REST API.

---

## 8. Vite Proxy — tại sao cần?

File: `apps/web/vite.config.ts`

```typescript
proxy: {
  '/socket.io': {
    target: 'http://localhost:3000',
    ws: true,          // ← QUAN TRỌNG: bật WebSocket proxying
    changeOrigin: true,
  },
}
```

**Vấn đề:** Vite dev server chạy ở `:5173`, API Gateway ở `:3000`. Nếu frontend kết nối trực tiếp `ws://localhost:3000`, trình duyệt sẽ block vì CORS.

**Giải pháp:** Vite proxy tất cả request đến `/socket.io` từ `:5173` → chuyển tiếp đến `:3000`. Browser chỉ thấy kết nối đến `:5173` (same-origin) → không bị CORS block.

Trong `friendSocket.ts`:

```typescript
socket = io('/', {
  // ← kết nối đến chính nó (:5173)
  path: '/socket.io', // ← Vite proxy bắt path này và forward đến :3000
});
```

---

## 9. Luồng đầy đủ khi gửi lời mời kết bạn

```
UserA (Browser :5173)         Vite Proxy          API Gateway :3000      Kafka       Friend Service :3025
      │                           │                      │                  │                │
      │─ POST /api/friends/req ──▶│─────────────────────▶│                  │                │
      │                           │                      │─ proxy ─────────────────────────▶│
      │                           │                      │                  │                │
      │                           │                      │                  │◀─ emit ────────│
      │                           │                      │                  │  friend.req.sent
      │◀─ 201 Created ────────────│◀─────────────────────│                  │                │
      │                           │                      │◀─ consume ───────│                │
      │                           │                      │  FriendEventsConsumer             │
      │                           │                      │  .emitToUser(B, 'friend:req_recv')│
      │                           │                      │                  │                │
```

```
UserB (Browser :5173)         SocketGateway :3000
      │  [WebSocket connected]        │
      │  [in room user:B-id]          │
      │                               │── server.to('user:B-id').emit('friend:request_received', payload)
      │◀── event: request_received ───│
      │                               │
      │  FriendSocketInitializer:
      │  onRequestReceived() fires
      │  → toast.info('Bạn có lời mời kết bạn mới')
      │  → dispatch(fetchReceivedRequests())  ← API call lấy đủ info
      │  → Redux state.receivedRequests cập nhật
      │  → ReceivedRequestCard re-render với sender info đầy đủ
```

---

## 10. Lifecycle hoàn chỉnh của Socket trong app

```
1. User mở trang web
   └─ App.tsx render
   └─ FriendSocketInitializer mount
   └─ useEffect chạy (user = null ban đầu → không connect)

2. User đăng nhập
   └─ fetchProfile thành công → Redux: state.auth.user = { id: '...', ... }
   └─ FriendSocketInitializer useEffect re-run (dependency [user] thay đổi)
   └─ friendSocket.connect(user.id) được gọi
   └─ socket = io('/') → WebSocket handshake với :5173
   └─ Vite proxy chuyển đến API Gateway :3000
   └─ SocketGateway.handleConnection() log "Connected: socket-id"
   └─ socket.on('connect') → socket.emit('join', { userId })
   └─ SocketGateway.handleJoin() → socket.join('user:abc-123')
   └─ Handlers (onRequestReceived, ...) được đăng ký

3. Người khác gửi lời mời cho user đang dùng
   └─ (xem luồng mục 9)
   └─ event 'friend:request_received' đến
   └─ toast.info() hiện thông báo
   └─ fetchReceivedRequests() → API call → Redux update → UI re-render

4. User logout
   └─ Redux: state.auth.user = null
   └─ FriendSocketInitializer useEffect cleanup chạy:
      └─ friendSocket.off(...) ← unregister tất cả handlers
   └─ useEffect chạy lại với user = null
      └─ friendSocket.disconnect() ← đóng WebSocket
   └─ SocketGateway.handleDisconnect() → xóa socket khỏi userSockets map

5. User đóng tab
   └─ Browser gửi TCP FIN → WebSocket đóng
   └─ SocketGateway.handleDisconnect() chạy tự động
   └─ socket bị xóa khỏi room → không nhận event nữa
```

---

## 11. Lỗi thường gặp và cách debug

### Không nhận được event

**Kiểm tra:**

1. Mở DevTools → Network → filter "WS" → xem có kết nối WebSocket không
2. Xem tab Messages của kết nối WS
3. Kiểm tra server logs: `[SocketGateway] User X joined room user:X`
4. Kiểm tra Kafka: event có được publish không?

```
# Kiểm tra Kafka topics
docker exec -it chat-redpanda rpk topic list
docker exec -it chat-redpanda rpk topic consume friend.request.sent --num 5
```

### Event bị duplicate (nhận 2 lần)

**Nguyên nhân:** Không cleanup handler trong `useEffect` return → mỗi render đăng ký thêm 1 handler mới.

```typescript
// ❌ Sai — không cleanup
useEffect(() => {
  friendSocket.on('event', handler);
  // không có return cleanup
});

// ✅ Đúng
useEffect(() => {
  friendSocket.on('event', handler);
  return () => {
    friendSocket.off('event', handler); // ← PHẢI có
  };
}, []);
```

### CORS error khi kết nối

**Kiểm tra** `vite.config.ts` có `ws: true` trong proxy config.

### User join room thành công nhưng không nhận event

**Kiểm tra** `emitToUser` dùng đúng `userId` (phải là UUID trong database, không phải tên hay email).

---

## 12. Tóm tắt file-by-file

| File                                                       | Vai trò                                                                    |
| ---------------------------------------------------------- | -------------------------------------------------------------------------- |
| `gateway/api-gateway/src/socket/socket.gateway.ts`         | Server WebSocket: nhận kết nối, quản lý rooms, emit events                 |
| `gateway/api-gateway/src/socket/friend-events.consumer.ts` | Kafka consumer: nhận events từ Friend Service, gọi emitToUser              |
| `gateway/api-gateway/src/socket/socket.module.ts`          | Wiring: khai báo providers, imports Kafka client                           |
| `apps/web/src/services/friendSocket.ts`                    | Client socket.io: singleton wrapper để connect/disconnect/on/off           |
| `apps/web/src/providers/FriendSocketInitializer.tsx`       | React component vô hình: connect khi login, off khi logout, dispatch Redux |
| `apps/web/vite.config.ts`                                  | Proxy `/socket.io` → API Gateway để tránh CORS                             |
