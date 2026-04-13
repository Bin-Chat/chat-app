# 🔐 Cookie-Based JWT Authentication với Redis

## 📋 Tổng quan

Hệ thống đã được nâng cấp từ **Bearer Token** sang **Cookie-Based Authentication** với Redis để tăng cường bảo mật.

### ✅ Cải tiến chính:

1. **Access Token** → Lưu trong **HttpOnly Cookie** (không thể bị XSS đánh cắp)
2. **Refresh Token** → Lưu trong **Redis** (có thể revoke ngay lập tức)
3. **Device Management** → Hỗ trợ multi-device login/logout
4. **CORS với Credentials** → Frontend tự động gửi cookies

---

## 🔄 Luồng hoạt động mới

### **1️⃣ Register/Login**

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant Redis
    participant PostgreSQL

    Client->>Gateway: POST /api/auth/login<br/>{phoneNumber, password, deviceId?}
    Gateway->>AuthService: Forward request + cookies
    AuthService->>PostgreSQL: Verify user credentials
    PostgreSQL-->>AuthService: User data
    AuthService->>AuthService: Generate deviceId (if not provided)
    AuthService->>AuthService: Generate Access Token (15m)
    AuthService->>AuthService: Generate Refresh Token (7d)
    AuthService->>Redis: SET refresh:userId:deviceId = refreshToken (TTL 7d)
    Redis-->>AuthService: OK
    AuthService->>Gateway: Response + Set-Cookie headers
    Gateway->>Client: Set-Cookie: accessToken, refreshToken, deviceId<br/>{user: {...}, deviceId, message}
```

**Request:**

```bash
POST /api/auth/login
Content-Type: application/json

{
  "phoneNumber": "0123456789",
  "password": "password123",
  "deviceId": "web-chrome-abc123"  # Optional
}
```

**Response:**

```json
{
  "user": {
    "id": "uuid",
    "phoneNumber": "0123456789",
    "fullName": "Nguyễn Văn A"
  },
  "deviceId": "web-chrome-abc123",
  "message": "Đăng nhập thành công"
}
```

**Cookies được set:**

```
Set-Cookie: accessToken=eyJhbGc...; HttpOnly; Secure; SameSite=Strict; Max-Age=900
Set-Cookie: refreshToken=eyJhbGc...; HttpOnly; Secure; SameSite=Strict; Max-Age=604800
Set-Cookie: deviceId=web-chrome-abc123; Secure; SameSite=Strict; Max-Age=604800
```

---

### **2️⃣ Access Protected Route**

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant PostgreSQL

    Client->>Gateway: GET /api/auth/profile<br/>Cookie: accessToken=...
    Gateway->>AuthService: Forward request + cookies
    AuthService->>AuthService: Extract accessToken from cookie
    AuthService->>AuthService: Verify JWT signature
    AuthService->>PostgreSQL: Find user by ID
    PostgreSQL-->>AuthService: User data
    AuthService->>Gateway: User profile
    Gateway->>Client: User profile
```

**Request:**

```bash
GET /api/auth/profile
Cookie: accessToken=eyJhbGc...
```

**Response:**

```json
{
  "id": "uuid",
  "phoneNumber": "0123456789",
  "fullName": "Nguyễn Văn A",
  "isActive": true,
  "createdAt": "2026-02-06T..."
}
```

---

### **3️⃣ Refresh Token**

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant Redis
    participant PostgreSQL

    Client->>Gateway: POST /api/auth/refresh<br/>Cookie: refreshToken=..., deviceId=...
    Gateway->>AuthService: Forward request + cookies
    AuthService->>AuthService: Extract refreshToken from cookie
    AuthService->>AuthService: Verify JWT signature
    AuthService->>Redis: GET refresh:userId:deviceId
    Redis-->>AuthService: refreshToken value
    AuthService->>AuthService: Compare tokens
    alt Token hợp lệ
        AuthService->>PostgreSQL: Find user
        PostgreSQL-->>AuthService: User data
        AuthService->>AuthService: Generate new Access Token
        AuthService->>AuthService: Generate new Refresh Token
        AuthService->>Redis: SET refresh:userId:deviceId = new refreshToken
        Redis-->>AuthService: OK
        AuthService->>Gateway: Response + new cookies
        Gateway->>Client: Set new cookies
    else Token không hợp lệ hoặc đã bị revoke
        AuthService->>Gateway: 401 Unauthorized
        Gateway->>Client: 401 Unauthorized
    end
```

**Request:**

```bash
POST /api/auth/refresh
Cookie: refreshToken=eyJhbGc...; deviceId=web-chrome-abc123
```

**Response:** (giống login, set cookies mới)

---

### **4️⃣ Logout (Single Device)**

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant Redis

    Client->>Gateway: POST /api/auth/logout<br/>Cookie: accessToken, deviceId
    Gateway->>AuthService: Forward request + cookies
    AuthService->>AuthService: Verify accessToken
    AuthService->>Redis: DEL refresh:userId:deviceId
    Redis-->>AuthService: OK
    AuthService->>Gateway: Response + Clear-Cookie headers
    Gateway->>Client: Clear-Cookie: accessToken, refreshToken, deviceId
```

**Request:**

```bash
POST /api/auth/logout
Cookie: accessToken=...; deviceId=...
```

**Response:**

```json
{
  "message": "Đăng xuất thành công"
}
```

**Cookies bị xóa:**

```
Set-Cookie: accessToken=; Max-Age=0
Set-Cookie: refreshToken=; Max-Age=0
Set-Cookie: deviceId=; Max-Age=0
```

---

### **5️⃣ Logout All Devices**

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant AuthService
    participant Redis

    Client->>Gateway: POST /api/auth/logout-all<br/>Cookie: accessToken
    Gateway->>AuthService: Forward request + cookies
    AuthService->>AuthService: Verify accessToken
    AuthService->>Redis: KEYS refresh:userId:*
    Redis-->>AuthService: [key1, key2, key3]
    AuthService->>Redis: DEL key1, key2, key3
    Redis-->>AuthService: OK
    AuthService->>Gateway: Response + Clear-Cookie headers
    Gateway->>Client: Clear cookies
```

**Request:**

```bash
POST /api/auth/logout-all
Cookie: accessToken=...
```

**Response:**

```json
{
  "message": "Đã đăng xuất tất cả thiết bị"
}
```

---

## 🛡️ Bảo mật

### **Cookie Options:**

```typescript
{
  httpOnly: true,        // JS không thể đọc → Chống XSS
  secure: true,          // Chỉ gửi qua HTTPS → Chống MITM
  sameSite: 'strict',    // Chống CSRF
  maxAge: 900000         // 15 phút (accessToken)
}
```

### **Redis Key Pattern:**

```
refresh:{userId}:{deviceId}
```

**Ví dụ:**

```
refresh:123e4567-e89b-12d3-a456-426614174000:web-chrome-abc123
refresh:123e4567-e89b-12d3-a456-426614174000:mobile-ios-xyz789
```

---

## 🔧 Cấu hình

### **Docker Compose:**

```yaml
redis:
  image: redis:7-alpine
  ports:
    - '6379:6379'

auth-service:
  environment:
    - REDIS_HOST=redis
    - REDIS_PORT=6379
```

### **Auth Service (.env):**

```env
REDIS_HOST=redis
REDIS_PORT=6379
JWT_SECRET=...
JWT_REFRESH_SECRET=...
JWT_ACCESS_EXPIRATION=15m
JWT_REFRESH_EXPIRATION=7d
```

### **API Gateway (.env):**

```env
CORS_ORIGIN=http://localhost:5173,http://localhost:3000
```

---

## 📝 Testing với Postman

### **1. Login:**

```javascript
// Request
POST http://localhost:3000/api/auth/login
Content-Type: application/json

{
  "phoneNumber": "0901234567",
  "password": "password123"
}

// Test Script
pm.test("Should set cookies", function () {
    pm.expect(pm.cookies.has('accessToken')).to.be.true;
    pm.expect(pm.cookies.has('refreshToken')).to.be.true;
    pm.expect(pm.cookies.has('deviceId')).to.be.true;
});
```

### **2. Get Profile (cookies tự động gửi):**

```javascript
// Request
GET http://localhost:3000/api/auth/profile
// Không cần header Authorization, cookies tự động gửi!
```

### **3. Refresh Token:**

```javascript
// Request
POST http://localhost:3000/api/auth/refresh
// Cookies tự động gửi
```

### **4. Logout:**

```javascript
// Request
POST http://localhost:3000/api/auth/logout

// Test Script
pm.test("Should clear cookies", function () {
    pm.expect(pm.cookies.has('accessToken')).to.be.false;
});
```

---

## 🔄 Migrate từ Bearer Token

### **Frontend Changes:**

#### **Trước (Bearer Token):**

```typescript
// ❌ Cũ
const response = await axios.post('/api/auth/login', {
  phoneNumber,
  password,
});

// Lưu token vào localStorage (không an toàn!)
localStorage.setItem('accessToken', response.data.accessToken);

// Thêm vào header mỗi request
axios.defaults.headers.common['Authorization'] = `Bearer ${accessToken}`;
```

#### **Sau (Cookie-Based):**

```typescript
// ✅ Mới
import axios from 'axios';

// Config axios để gửi cookies
axios.defaults.withCredentials = true;

// Login - không cần lưu token
const response = await axios.post('/api/auth/login', {
  phoneNumber,
  password,
});

// Cookies tự động được set bởi browser
// Các request sau tự động gửi cookies
await axios.get('/api/auth/profile'); // Không cần header!
```

---

## 🧪 Kiểm tra Redis

### **Kết nối Redis:**

```bash
docker exec -it chat-redis redis-cli
```

### **Xem tất cả refresh tokens:**

```bash
KEYS refresh:*
```

### **Xem token của user cụ thể:**

```bash
KEYS refresh:123e4567-e89b-12d3-a456-426614174000:*
```

### **Xem giá trị token:**

```bash
GET refresh:123e4567-e89b-12d3-a456-426614174000:web-chrome-abc123
```

### **Xóa token thủ công (force logout):**

```bash
DEL refresh:123e4567-e89b-12d3-a456-426614174000:web-chrome-abc123
```

---

## ⚠️ Lưu ý quan trọng

### **1. Production:**

- ✅ Bật `secure: true` (HTTPS only)
- ✅ Dùng `sameSite: 'strict'`
- ✅ Set Redis password
- ✅ Dùng strong JWT secrets

### **2. Mobile App:**

- Cookie-based auth **không phù hợp** cho mobile
- Mobile nên dùng Bearer Token (Authorization header)
- Có thể hỗ trợ cả 2 modes: cookie cho web, bearer cho mobile

### **3. Subdomain:**

Nếu frontend ở subdomain khác, config cookie domain:

```typescript
{
  domain: '.example.com',  // Share cookie giữa app.example.com và api.example.com
  sameSite: 'lax'          // Strict không work với subdomain
}
```

---

## 📊 So sánh Bearer vs Cookie

| Feature          | Bearer Token                   | Cookie-Based                      |
| ---------------- | ------------------------------ | --------------------------------- |
| **Bảo mật XSS**  | ❌ localStorage dễ bị đánh cắp | ✅ HttpOnly cookie không đọc được |
| **Bảo mật CSRF** | ✅ Không bị                    | ⚠️ Cần SameSite                   |
| **Revoke token** | ❌ Phải đợi expire             | ✅ Xóa Redis = logout ngay        |
| **Multi-device** | ❌ Khó quản lý                 | ✅ Redis tracking                 |
| **Mobile App**   | ✅ Dễ dùng                     | ❌ Phức tạp                       |
| **Web App**      | ⚠️ OK nhưng kém                | ✅ **Best Practice**              |

---

## 🚀 Deployment

### **Rebuild Docker images:**

```bash
# Stop services
docker-compose down

# Rebuild với dependencies mới
docker-compose build --no-cache auth-service api-gateway

# Start lại
docker-compose up -d redis postgres api-gateway auth-service
```

### **Check logs:**

```bash
docker logs -f auth-service
docker logs -f api-gateway
docker logs -f chat-redis
```

---

## 🐛 Troubleshooting

### **Cookies không được set:**

1. Check CORS origin có đúng không
2. Check `credentials: true` trong CORS config
3. Check response headers có `Set-Cookie` không

### **401 Unauthorized:**

1. Check cookie có được gửi không (Network tab)
2. Check Redis có token không
3. Check JWT secret có đúng không

### **Redis connection error:**

1. Check Redis container đang chạy: `docker ps | grep redis`
2. Check REDIS_HOST environment variable
3. Test connection: `docker exec -it chat-redis redis-cli ping`

---

## 🔒 Single Session Per Device Type — 1 phiên mỗi loại thiết bị

### Nguyên tắc

Mỗi người dùng được đăng nhập **đồng thời trên 2 loại thiết bị** (1 web + 1 mobile). Nhưng **không thể đăng nhập 2 tab/trình duyệt web cùng lúc, hoặc 2 điện thoại cùng lúc**.

| Kịch bản                           | Kết quả             |
| ---------------------------------- | ------------------- |
| Laptop A + Điện thoại B            | ✅ Cả 2 hoạt động   |
| Laptop A + Laptop B (đăng nhập B)  | ⚡ Laptop A bị kick |
| iPhone A + Android B (đăng nhập B) | ⚡ iPhone A bị kick |

---

### Redis Keys

| Key                                  | Giá trị                           | TTL     |
| ------------------------------------ | --------------------------------- | ------- |
| `session:active:{userId}:web`        | `deviceId` của web đang active    | 30 ngày |
| `session:active:{userId}:mobile`     | `deviceId` của mobile đang active | 30 ngày |
| `session:device:{userId}:{deviceId}` | JSON metadata (type, name, time)  | 30 ngày |
| `session:deviceids:{userId}`         | Redis SET chứa tất cả deviceIds   | 30 ngày |
| `refresh:{userId}:{deviceId}`        | Refresh token                     | 7 ngày  |

**Device metadata JSON:**

```json
{
  "deviceType": "web",
  "deviceName": "Chrome trên Windows",
  "loginAt": "2026-03-01T10:00:00.000Z"
}
```

---

### JWT Payload (mới)

```typescript
{
  sub: userId,
  email: "user@example.com",
  deviceId: "web-abc123",
  deviceType: "web",   // ← thêm mới
  role: "user"
}
```

---

### Login Request (mới)

**Web:**

```json
{
  "phoneNumber": "0901234567",
  "password": "password123",
  "deviceType": "web",
  "deviceName": "Chrome trên Windows"
}
```

**Mobile:**

```json
{
  "phoneNumber": "0901234567",
  "password": "password123",
  "deviceType": "mobile",
  "deviceName": "Điện thoại"
}
```

---

### Luồng đăng nhập (`generateTokens`)

```mermaid
sequenceDiagram
    participant Device B (web mới)
    participant AuthService
    participant Redis
    participant Kafka

    Device B->>AuthService: POST /api/auth/login {deviceType: "web"}
    AuthService->>Redis: getActiveDevice(userId, "web") → oldWebDeviceId
    alt oldWebDeviceId ≠ deviceB
        AuthService->>Redis: deleteRefreshToken(userId, oldWebDeviceId)
        AuthService->>Redis: clearDeviceInfo + removeFromSet
        AuthService->>Kafka: auth.session.kicked {userId, deviceType: "web"}
    end
    AuthService->>Redis: saveRefreshToken(userId, deviceB)
    AuthService->>Redis: setActiveDevice(userId, deviceB, "web")
    AuthService->>Redis: saveDeviceInfo(userId, deviceB, {type, name, loginAt})
    AuthService->>Redis: addDeviceToSet(userId, deviceB)
    AuthService-->>Device B: Tokens + cookies
```

> Điện thoại (mobile session) **không bị ảnh hưởng** khi web đăng nhập lại.

---

### Kiểm tra phiên (`JwtStrategy.validate`)

```typescript
async validate(payload: JwtPayload) {
  const user = await findUser(payload.sub);
  if (!user || !user.isActive) throw UnauthorizedException;

  // Kiểm tra per-type single session
  const deviceType = payload.deviceType ?? 'web';
  const activeDevice = await redisService.getActiveDevice(user.id, deviceType);
  if (activeDevice && activeDevice !== payload.deviceId) {
    throw new UnauthorizedException(
      'Phiên đăng nhập đã hết hạn vì tài khoản vừa đăng nhập ở thiết bị khác. Vui lòng đăng nhập lại.'
    );
  }
  return user;
}
```

---

### Proactive Kick qua Socket.IO

Khi thiết bị cũ bị dethrone, **Kafka event** được phát để kick proactive (không cần đợi 401):

```
Auth Service → Kafka (auth.session.kicked) → Gateway → Socket.IO (session:kicked) → Client
```

**Kafka event payload:**

```json
{ "userId": "uuid", "deviceType": "web" }
```

**Socket event payload (emitted to `user:{userId}` room):**

```json
{ "deviceType": "web", "reason": "Tài khoản đã đăng nhập từ thiết bị web khác" }
```

**Frontend filter (Web `FriendSocketInitializer.tsx`):**

```typescript
socket.on('session:kicked', (payload) => {
  if (payload?.deviceType && payload.deviceType !== 'web') return; // Bỏ qua nếu không phải web
  dispatch(forceLogout()); // Redux action, không gọi API
});
```

**Frontend filter (Mobile `useSessionSocket.ts`):**

```typescript
socket.on('session:kicked', (payload) => {
  if (payload?.deviceType && payload.deviceType !== 'mobile') return;
  Alert.alert('Phiên hết hiệu lực', '...', [{ text: 'OK', onPress: forceLogout }]);
});
```

---

### `forceLogout` — Đăng xuất không cần API

Thiết bị bị kick **không thể** gọi `POST /logout` (đã bị revoke → 401). Cả 2 platform dùng action nội bộ:

**Web (Redux action):**

```typescript
dispatch(forceLogout()); // Xoá localStorage + reset Redux state, không gọi API
```

**Mobile (Zustand action):**

```typescript
await forceLogout(); // Xoá cookies + reset store, không gọi API
```

---

### Quản lý thiết bị

#### API Endpoints

```
GET    /api/auth/devices          → Danh sách thiết bị đang đăng nhập
DELETE /api/auth/devices/:deviceId → Đăng xuất từ xa một thiết bị cụ thể
```

#### Response `GET /api/auth/devices`

```json
[
  {
    "deviceId": "web-abc123",
    "deviceType": "web",
    "deviceName": "Chrome trên Windows",
    "loginAt": "2026-03-01T10:00:00.000Z",
    "isCurrent": true
  },
  {
    "deviceId": "mobile-xyz789",
    "deviceType": "mobile",
    "deviceName": "Điện thoại",
    "loginAt": "2026-03-01T08:30:00.000Z",
    "isCurrent": false
  }
]
```

#### Luồng Remote Logout

```
DELETE /api/auth/devices/:deviceId
  → deleteRefreshToken(userId, targetDeviceId)
  → clearActiveDevice(userId, deviceType)
  → removeDeviceFromSet + clearDeviceInfo
  → emit Kafka: auth.session.kicked {userId, deviceType}
  → Gateway → Socket: session:kicked {deviceType}
  → Target device tự forceLogout
```

---

### Đăng xuất (`logout` / `logoutAll`)

```typescript
// logout: một thiết bị
const deviceInfo = await redisService.getDeviceInfo(userId, deviceId); // lấy deviceType
await redisService.deleteRefreshToken(userId, deviceId);
await redisService.clearActiveDevice(userId, deviceInfo.deviceType); // xoá đúng loại
await redisService.removeDeviceFromSet(userId, deviceId);
await redisService.clearDeviceInfo(userId, deviceId);

// logoutAll: tất cả thiết bị
await redisService.deleteAllRefreshTokens(userId);
await redisService.clearAllActiveDevices(userId); // xoá cả :web và :mobile
const allIds = await redisService.getAllDeviceIds(userId);
for (const id of allIds) await redisService.clearDeviceInfo(userId, id);
await redisService.clearDeviceSet(userId);
```

---

### Kiểm tra Redis

```bash
# Xem sessions đang active
GET session:active:{userId}:web
GET session:active:{userId}:mobile

# Xem thông tin thiết bị
GET session:device:{userId}:{deviceId}

# Xem danh sách tất cả deviceIds của user
SMEMBERS session:deviceids:{userId}

# Xoá thủ công (force logout)
DEL session:active:{userId}:web
DEL refresh:{userId}:{deviceId}
```

---

✅ **Hệ thống đã sẵn sàng với Cookie-Based Authentication và Per-Device-Type Single Session!**
