# LUỒNG HOẠT ĐỘNG VÀ HƯỚNG DẪN CHẠY HỆ THỐNG CHAT

## 📋 MỤC LỤC

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Luồng hoạt động hệ thống](#2-luồng-hoạt-động-hệ-thống)
3. [Cách chạy từng thành phần](#3-cách-chạy-từng-thành-phần)
4. [Các lệnh quan trọng](#4-các-lệnh-quan-trọng)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. TỔNG QUAN KIẾN TRÚC

### 1.1 Sơ đồ tổng quan

```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND                             │
│  React App (Port 5173) - Vite Dev / Nginx Production       │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP/WebSocket
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND SERVICES                         │
├─────────────────────────────────────────────────────────────┤
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│ │ Chat Service │  │   Presence   │  │   Realtime   │      │
│ │  Port 8083   │  │  Port 8084   │  │  Port 8085   │      │
│ │  (Messages)  │  │  (Online)    │  │  (WebSocket) │      │
│ └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│        │                 │                  │               │
│ ┌──────────────┐         │                  │               │
│ │    Media     │         │                  │               │
│ │  Port 8086   │         │                  │               │
│ │ (Upload/Img) │         │                  │               │
│ └──────┬───────┘         │                  │               │
└────────┼─────────────────┼──────────────────┼───────────────┘
         │                 │                  │
         ▼                 ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE                           │
├─────────────────────────────────────────────────────────────┤
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│ │  PostgreSQL  │  │    Redis     │  │   Redpanda   │      │
│ │  Port 5432   │  │  Port 6379   │  │  Port 19092  │      │
│ │   (Database) │  │   (Cache)    │  │   (Kafka)    │      │
│ └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Công nghệ sử dụng

| Thành phần            | Công nghệ                 | Version | Port                    |
| --------------------- | ------------------------- | ------- | ----------------------- |
| **Frontend**          | React + Vite + TypeScript | 18+     | 5173 (dev), 3000 (prod) |
| **Backend Services**  | Java Spring Boot          | 3.2.0   | 8083-8086               |
| **Build Tool**        | Maven                     | 3.9+    | -                       |
| **Database**          | PostgreSQL                | 15      | 5432                    |
| **Cache**             | Redis                     | 7       | 6379                    |
| **Message Queue**     | Redpanda (Kafka)          | Latest  | 19092, 18081-18082      |
| **Container**         | Docker + Docker Compose   | Latest  | -                       |
| **Web Server (Prod)** | Nginx                     | Alpine  | 80                      |

---

## 2. LUỒNG HOẠT ĐỘNG HỆ THỐNG

### 2.1 Luồng đăng nhập (Login Flow)

```
User → Frontend → Auth Service → Database
                       ↓
                   JWT Token
                       ↓
                   Frontend (Store Token)
                       ↓
               WebSocket Connection
```

**Chi tiết:**

1. User nhập username/password trên React App
2. Frontend gửi POST request đến `/api/auth/login`
3. Auth Service kiểm tra credentials với PostgreSQL
4. Nếu hợp lệ, tạo JWT token và trả về
5. Frontend lưu token vào localStorage/authStore
6. Frontend khởi tạo WebSocket connection với token

### 2.2 Luồng gửi tin nhắn (Send Message Flow)

```
User Input → Frontend → Chat Service → PostgreSQL
                           ↓
                     Kafka Producer
                           ↓
                    ┌──────┴──────┐
                    ▼             ▼
            Realtime Gateway   Other Services
                    ↓
              WebSocket Push
                    ↓
            Other Users (Frontend)
```

**Chi tiết:**

1. User nhập tin nhắn và nhấn Send
2. Frontend gửi POST `/api/chat/messages`
3. Chat Service:
   - Lưu message vào PostgreSQL
   - Publish event lên Kafka topic `chat.messages`
   - Trả về message đã tạo
4. Realtime Gateway subscribe Kafka:
   - Nhận event từ Kafka
   - Push message qua WebSocket đến users online
5. Frontend nhận message qua WebSocket và hiển thị

### 2.3 Luồng hiển thị trạng thái online (Presence Flow)

```
User Online → Frontend → Presence Service → Redis (TTL 30s)
                              ↓
                        Kafka Event
                              ↓
                     Realtime Gateway
                              ↓
                   WebSocket Broadcast
                              ↓
                      Other Users
```

**Chi tiết:**

1. Frontend gửi heartbeat mỗi 15s: POST `/api/presence/online`
2. Presence Service:
   - Set Redis key `presence:user:{userId}` với TTL 30s
   - Publish `user.online` event lên Kafka
3. Realtime Gateway:
   - Subscribe Kafka presence events
   - Broadcast status qua WebSocket
4. Frontend hiển thị dot xanh/xám bên cạnh tên user

### 2.4 Luồng upload media (Media Upload Flow)

```
User Select File → Frontend → Media Processor → S3/Storage
                                   ↓
                            Image Resize
                                   ↓
                          Return URLs
                                   ↓
                      Chat Service (Save)
```

**Chi tiết:**

1. User chọn hình/video
2. Frontend gửi multipart/form-data đến `/api/media/upload`
3. Media Processor:
   - Validate file type/size
   - Resize image (thumbnail, medium, original)
   - Upload lên S3 hoặc local storage
   - Publish `media.uploaded` event lên Kafka
4. Trả về URLs cho frontend
5. Frontend gửi message kèm media URLs
6. Chat Service lưu message với media URLs

### 2.5 Luồng typing indicator (Đang gõ...)

```
User Typing → Frontend → WebSocket → Realtime Gateway
                                           ↓
                                     Broadcast
                                           ↓
                                  Other Conversation Members
```

**Chi tiết:**

1. Frontend detect `onKeyPress` event
2. Gửi WebSocket message: `{"type": "typing", "conversationId": "123"}`
3. Realtime Gateway:
   - Parse message
   - Broadcast chỉ đến users trong conversation đó
4. Frontend nhận và hiển thị "User đang gõ..." trong 3s
5. Sau 3s tự động ẩn nếu không có typing event mới

---

## 3. CÁCH CHẠY TỪNG THÀNH PHẦN

### 3.1 Chạy toàn bộ hệ thống (RECOMMENDED)

#### Cách 1: Một lệnh chạy hết (Hybrid - Docker Backend + NPM Frontend)

```bash
# Windows
run-all.bat

# Linux/Mac
./run-all.sh
```

**Những gì script làm:**

1. ✅ Kiểm tra Docker đang chạy
2. ✅ Kiểm tra Node.js đã cài
3. ✅ Cài dependencies nếu chưa có
4. ✅ Start infrastructure (PostgreSQL, Redis, Kafka)
5. ✅ Build và start 4 backend services (Java)
6. ✅ Start frontend dev server (React)

**Kết quả:**

- Frontend: http://localhost:5173 (hot reload)
- Backend services: http://localhost:8083-8086
- Infrastructure: localhost:5432, 6379, 19092

#### Cách 2: Toàn bộ trong Docker (Production-like)

```bash
# Windows
docker-run-all.bat

# Linux/Mac
./docker-run-all.sh
```

**Khác biệt:**

- Frontend cũng chạy trong Docker với Nginx
- Không có hot reload cho frontend
- Giống production hơn

**Kết quả:**

- Frontend: http://localhost:3000 (qua Nginx)
- Backend services: http://localhost:8083-8086

#### Cách 3: Dùng NPM scripts

```bash
# Chạy hết (hybrid)
npm run start

# Chỉ chạy infrastructure
npm run dev

# Chỉ build services
npm run build
```

---

### 3.2 Chạy từng phần riêng lẻ

#### A. Chỉ chạy Infrastructure (PostgreSQL, Redis, Kafka)

```bash
# Windows
dev.bat

# Hoặc dùng Docker Compose
docker-compose up -d postgres redis redpanda

# Kiểm tra trạng thái
docker-compose ps
```

**Sử dụng khi:**

- Đang develop backend services locally (không dùng Docker)
- Chỉ cần database và cache để test

---

#### B. Chạy một Backend Service cụ thể

##### **Chat Service** (Port 8083)

```bash
# Chạy trong Docker
docker-compose up -d --build chat-service

# Hoặc chạy trực tiếp với Maven (development)
cd services/chat
mvn clean install
mvn spring-boot:run

# Hoặc chạy JAR file
java -jar target/chat-service-1.0.0.jar
```

**API Endpoints:**

- `GET /api/chat/messages` - Lấy danh sách tin nhắn
- `POST /api/chat/messages` - Gửi tin nhắn mới
- `GET /api/chat/conversations` - Lấy danh sách cuộc trò chuyện
- `DELETE /api/chat/messages/{id}` - Xóa tin nhắn

**Dependencies:**

- PostgreSQL (port 5432)
- Redis (port 6379)
- Kafka (port 19092)

---

##### **Presence Service** (Port 8084)

```bash
# Docker
docker-compose up -d --build presence-service

# Maven
cd services/presence
mvn spring-boot:run
```

**API Endpoints:**

- `POST /api/presence/online` - Đánh dấu user online
- `POST /api/presence/offline` - Đánh dấu user offline
- `GET /api/presence/status/{userId}` - Kiểm tra trạng thái user
- `GET /api/presence/online-users` - Lấy danh sách users đang online

**Dependencies:**

- Redis (port 6379)
- Kafka (port 19092)

---

##### **Realtime Gateway** (Port 8085)

```bash
# Docker
docker-compose up -d --build realtime-gateway

# Maven
cd services/realtime-gateway
mvn spring-boot:run
```

**WebSocket Endpoints:**

- `ws://localhost:8085/ws` - WebSocket endpoint
- `/app/chat` - Send message
- `/topic/messages` - Subscribe messages
- `/topic/presence` - Subscribe presence updates
- `/topic/typing` - Subscribe typing indicators

**Dependencies:**

- Redis (port 6379)
- Kafka (port 19092)

**Test WebSocket:**

```javascript
// Browser console
const socket = new WebSocket('ws://localhost:8085/ws');
socket.onopen = () => console.log('Connected');
socket.onmessage = (e) => console.log('Message:', e.data);
```

---

##### **Media Processor** (Port 8086)

```bash
# Docker
docker-compose up -d --build media-processor

# Maven
cd services/media-processor
mvn spring-boot:run
```

**API Endpoints:**

- `POST /api/media/upload` - Upload hình ảnh/video
- `GET /api/media/{fileId}` - Download media
- `DELETE /api/media/{fileId}` - Xóa media
- `POST /api/media/thumbnail` - Tạo thumbnail

**Dependencies:**

- Kafka (port 19092)
- S3 hoặc local file storage

**Test Upload:**

```bash
curl -X POST http://localhost:8086/api/media/upload \
  -F "file=@image.jpg" \
  -F "type=image"
```

---

#### C. Chạy Frontend

##### Development Mode (Hot Reload)

```bash
cd apps/web
npm install
npm run dev
```

**Truy cập:** http://localhost:5173

**Features:**

- ⚡ Hot Module Replacement (HMR)
- 🔍 TypeScript type checking
- 🎨 Tailwind CSS auto-compile
- 📦 Vite fast rebuild

##### Production Build

```bash
cd apps/web
npm run build
npm run preview
```

**Output:** `apps/web/dist/` folder

**Deploy với Nginx:**

```bash
# Chạy trong Docker
docker-compose up -d web

# Hoặc dùng Nginx local
cp -r apps/web/dist/* /var/www/html/
```

---

### 3.3 Build từng service

#### Build tất cả Java services

```bash
# Từ root folder
for /d %i in (services\*) do (
  cd %i
  mvn clean install
  cd ..\..
)
```

#### Build một service cụ thể

```bash
cd services/chat
mvn clean install

# Skip tests
mvn clean install -DskipTests

# Build Docker image
docker build -t chat-service:latest .
```

#### Build Frontend

```bash
cd apps/web
npm run build

# Output: apps/web/dist/
# Size: ~500KB (compressed)
```

---

## 4. CÁC LỆNH QUAN TRỌNG

### 4.1 Docker Commands

```bash
# Xem services đang chạy
docker-compose ps

# Xem logs tất cả services
docker-compose logs -f

# Xem logs một service
docker-compose logs -f chat-service

# Stop tất cả
docker-compose down

# Stop và xóa volumes
docker-compose down -v

# Rebuild một service
docker-compose up -d --build chat-service

# Restart một service
docker-compose restart chat-service

# Xem resource usage
docker stats
```

### 4.2 Database Commands

```bash
# Kết nối PostgreSQL
docker exec -it postgres psql -U postgres -d chatdb

# Queries hữu ích
SELECT * FROM messages ORDER BY created_at DESC LIMIT 10;
SELECT * FROM users WHERE online = true;
SELECT COUNT(*) FROM messages;

# Backup database
docker exec postgres pg_dump -U postgres chatdb > backup.sql

# Restore database
docker exec -i postgres psql -U postgres chatdb < backup.sql
```

### 4.3 Redis Commands

```bash
# Kết nối Redis
docker exec -it redis redis-cli

# Queries hữu ích
KEYS presence:*
GET presence:user:123
TTL presence:user:123
KEYS *
FLUSHALL  # Xóa tất cả (cẩn thận!)
```

### 4.4 Kafka Commands

```bash
# List topics
docker exec -it redpanda rpk topic list

# Tạo topic mới
docker exec -it redpanda rpk topic create test-topic

# Consume messages
docker exec -it redpanda rpk topic consume chat.messages

# Describe topic
docker exec -it redpanda rpk topic describe chat.messages
```

### 4.5 Maven Commands

```bash
# Clean build
mvn clean install

# Run tests
mvn test

# Skip tests
mvn install -DskipTests

# Run specific test
mvn test -Dtest=MessageServiceTest

# Generate dependency tree
mvn dependency:tree

# Update dependencies
mvn versions:use-latest-versions
```

### 4.6 NPM Commands

```bash
# Install dependencies
npm install

# Dev server
npm run dev

# Production build
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint

# Type check
npm run type-check

# Clean install
rm -rf node_modules package-lock.json && npm install
```

---

## 5. TROUBLESHOOTING

### 5.1 Docker Issues

#### Problem: "Docker is not running"

```bash
# Windows
# Start Docker Desktop manually hoặc:
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Linux
sudo systemctl start docker
```

#### Problem: "Port already in use"

```bash
# Tìm process đang dùng port
netstat -ano | findstr :8083

# Kill process (Windows)
taskkill /PID <PID> /F

# Linux
kill -9 <PID>
```

#### Problem: "Container unhealthy"

```bash
# Xem logs chi tiết
docker-compose logs chat-service

# Restart service
docker-compose restart chat-service

# Rebuild từ đầu
docker-compose up -d --build --force-recreate chat-service
```

---

### 5.2 Backend Service Issues

#### Problem: "Failed to connect to database"

**Giải pháp:**

```bash
# 1. Kiểm tra PostgreSQL có chạy không
docker-compose ps postgres

# 2. Kiểm tra credentials trong application.yml
services/chat/src/main/resources/application.yml

# 3. Restart database
docker-compose restart postgres

# 4. Check database logs
docker-compose logs postgres
```

#### Problem: "Kafka connection timeout"

**Giải pháp:**

```bash
# 1. Kiểm tra Redpanda
docker-compose ps redpanda

# 2. Kiểm tra topics
docker exec -it redpanda rpk topic list

# 3. Kiểm tra bootstrap servers trong code
# Phải là: localhost:19092 hoặc redpanda:9092 (internal)

# 4. Restart Redpanda
docker-compose restart redpanda
```

#### Problem: "Maven build failed"

**Giải pháp:**

```bash
# 1. Clean Maven cache
mvn clean

# 2. Update dependencies
mvn dependency:purge-local-repository

# 3. Check Java version
java -version  # Phải >= 21

# 4. Build với verbose
mvn clean install -X
```

---

### 5.3 Frontend Issues

#### Problem: "npm install failed"

**Giải pháp:**

```bash
# 1. Clear cache
npm cache clean --force

# 2. Delete node_modules
rm -rf node_modules package-lock.json

# 3. Reinstall
npm install

# 4. Try with legacy peer deps
npm install --legacy-peer-deps
```

#### Problem: "Cannot connect to backend API"

**Giải pháp:**

```bash
# 1. Check Vite proxy config
apps/web/vite.config.ts

# 2. Verify backend is running
curl http://localhost:8083/api/health

# 3. Check CORS settings
# Backend phải có:
@CrossOrigin(origins = "http://localhost:5173")

# 4. Check browser console for errors
# F12 → Console/Network tab
```

#### Problem: "WebSocket connection failed"

**Giải pháp:**

```bash
# 1. Verify Realtime Gateway is running
docker-compose ps realtime-gateway

# 2. Test WebSocket endpoint
# Browser console:
const ws = new WebSocket('ws://localhost:8085/ws');

# 3. Check nginx config nếu dùng production
apps/web/nginx.conf
# Phải có WebSocket upgrade headers

# 4. Check firewall
netsh advfirewall firewall add rule name="WebSocket" dir=in action=allow protocol=TCP localport=8085
```

---

### 5.4 Infrastructure Issues

#### Problem: "Redis connection refused"

```bash
# 1. Check Redis container
docker-compose ps redis

# 2. Test connection
docker exec -it redis redis-cli PING
# Response: PONG

# 3. Check port
netstat -an | findstr :6379

# 4. Restart Redis
docker-compose restart redis
```

#### Problem: "Redpanda image pull failed"

```bash
# Sửa docker-compose.yml
# Từ: vectorized/redpanda
# Thành: docker.redpanda.com/redpandadata/redpanda:latest

docker-compose pull redpanda
docker-compose up -d redpanda
```

---

### 5.5 Performance Issues

#### Problem: "Services chạy chậm"

**Giải pháp:**

```bash
# 1. Tăng memory cho Docker Desktop
# Settings → Resources → Memory: 4GB+

# 2. Check CPU/Memory usage
docker stats

# 3. Giảm số services chạy đồng thời
# Chỉ chạy services cần thiết

# 4. Build optimization
# Maven: mvn clean install -DskipTests
# Vite: npm run build -- --minify

# 5. Enable caching
# Redis: Check TTL values
# Browser: Enable HTTP cache
```

#### Problem: "Database queries slow"

```bash
# 1. Tạo indexes
CREATE INDEX idx_messages_created ON messages(created_at);
CREATE INDEX idx_conversations_updated ON conversations(updated_at);

# 2. Analyze query plans
EXPLAIN ANALYZE SELECT * FROM messages WHERE conversation_id = '123';

# 3. Increase connection pool
# application.yml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
```

---

## 6. MONITORING VÀ LOGGING

### 6.1 Xem Logs

```bash
# Tất cả services
docker-compose logs -f

# Một service với tail
docker-compose logs -f --tail=100 chat-service

# Grep logs
docker-compose logs chat-service | grep ERROR

# Export logs
docker-compose logs > logs.txt
```

### 6.2 Health Checks

```bash
# Check tất cả services
curl http://localhost:8083/actuator/health
curl http://localhost:8084/actuator/health
curl http://localhost:8085/actuator/health
curl http://localhost:8086/actuator/health

# Database
docker exec postgres pg_isready

# Redis
docker exec redis redis-cli PING

# Kafka
docker exec redpanda rpk cluster health
```

### 6.3 Metrics (Optional - Cần thêm Prometheus/Grafana)

```yaml
# Uncomment trong docker-compose.yml
prometheus:
  container_name: prometheus
  image: prom/prometheus:latest
  ports:
    - '9090:9090'

grafana:
  container_name: grafana
  image: grafana/grafana:latest
  ports:
    - '3000:3000'
```

**Truy cập:**

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

---

## 7. DEPLOYMENT

### 7.1 Deploy lên Production

#### Bước 1: Build Production Images

```bash
# Build tất cả services
docker-compose build

# Tag images
docker tag chat-service:latest your-registry.com/chat-service:v1.0.0
docker tag presence-service:latest your-registry.com/presence-service:v1.0.0
docker tag realtime-gateway:latest your-registry.com/realtime-gateway:v1.0.0
docker tag media-processor:latest your-registry.com/media-processor:v1.0.0
docker tag web:latest your-registry.com/web:v1.0.0

# Push to registry
docker push your-registry.com/chat-service:v1.0.0
# ... push other images
```

#### Bước 2: Configure Production Environment

```bash
# Tạo .env.production
DATABASE_URL=postgresql://prod-db:5432/chatdb
REDIS_URL=redis://prod-redis:6379
KAFKA_BOOTSTRAP=prod-kafka:9092
JWT_SECRET=your-super-secret-key-change-this
S3_BUCKET=your-s3-bucket
```

#### Bước 3: Deploy với Docker Compose

```bash
# Server production
docker-compose -f docker-compose.prod.yml up -d

# Hoặc dùng Kubernetes
kubectl apply -f k8s/
```

---

## 8. DEVELOPMENT WORKFLOW

### 8.1 Workflow khuyến nghị

```bash
# 1. Pull latest code
git pull origin main

# 2. Start infrastructure
dev.bat

# 3. Start backend service đang develop
cd services/chat
mvn spring-boot:run

# 4. Start frontend
cd apps/web
npm run dev

# 5. Make changes → Auto reload

# 6. Test
mvn test  # Backend
npm run test  # Frontend

# 7. Commit
git add .
git commit -m "feat: add new feature"
git push
```

### 8.2 Hotkeys hữu ích

| Action            | Shortcut            |
| ----------------- | ------------------- |
| Stop terminal     | Ctrl + C            |
| Clear terminal    | Ctrl + L hoặc `cls` |
| Search logs       | Ctrl + F            |
| Open new terminal | Ctrl + Shift + `    |
| Split terminal    | Ctrl + \            |

---

## 📚 TÀI LIỆU THAM KHẢO THÊM

- [README.md](./README.md) - Tổng quan dự án
- [KIEN_TRUC_HE_THONG_CHAT.md](./KIEN_TRUC_HE_THONG_CHAT.md) - Kiến trúc chi tiết
- [RUN_ALL_GUIDE.md](./RUN_ALL_GUIDE.md) - Hướng dẫn chạy nhanh
- [docker-compose.yml](./docker-compose.yml) - Cấu hình Docker

---

## ❓ CÂU HỎI THƯỜNG GẶP

**Q: Tôi nên dùng `run-all.bat` hay `docker-run-all.bat`?**

A:

- `run-all.bat` → Development (frontend có hot reload)
- `docker-run-all.bat` → Test production-like setup

**Q: Làm sao biết services đã start xong?**

A: Chờ ~2-5 phút, sau đó:

```bash
docker-compose ps  # Tất cả phải healthy
curl http://localhost:8083/actuator/health  # Phải return "UP"
```

**Q: Port 8083 đã được dùng bởi app khác?**

A: Sửa trong `docker-compose.yml`:

```yaml
ports:
  - '8093:8083' # Map port khác
```

**Q: Làm sao reset database về trạng thái ban đầu?**

A:

```bash
docker-compose down -v  # Xóa volumes
docker-compose up -d postgres  # Tạo lại
```

---

**Cập nhật:** 26/01/2026
**Tác giả:** Chat App Development Team
