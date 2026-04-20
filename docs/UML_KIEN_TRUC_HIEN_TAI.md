# UML — Kiến trúc hiện tại + Deployment EC2 + CI/CD

> **BinChat** — Microservices Chat App  
> Tất cả sơ đồ dùng **PlantUML** — render bằng VS Code extension `PlantUML` hoặc [plantuml.com](https://www.plantuml.com/plantuml/uml)

---

## Sơ đồ 1 — Kiến trúc tổng thể + VPC Deployment trên EC2

> Sơ đồ này kết hợp **kiến trúc microservices**, **deployment trên EC2**, và **DevOps workflow** trong một view.  
> Tham khảo từ Fig 4. System Design (VPC Tier Architecture).

```plantuml
@startuml KIEN_TRUC_VA_DEPLOY

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam defaultFontName Arial
skinparam ArrowColor #555555
skinparam component {
  BackgroundColor #DDEEFF
  BorderColor #336699
}
skinparam database {
  BackgroundColor #FFF5CC
  BorderColor #CC9900
}
skinparam node {
  BackgroundColor #F0F0F0
  BorderColor #888888
}
skinparam package {
  BorderColor #999999
}

title BinChat — Kiến trúc Microservices + Deployment EC2 (VPC Tier Architecture)

'===========================================================
' LEFT: DevOps Workflow
'===========================================================
package "DevOps Workflow" #LightYellow {
  actor "Developer" as Dev
  component "GitHub\nRepository" as GitHub
  component "GitHub Actions\n(CI/CD Runner)" as GHActions
  component "Docker Hub\n(Image Registry)" as DockerHub

  Dev -down-> GitHub : git push\nmain branch
  GitHub -down-> GHActions : webhook trigger\n(on push)
  GHActions -down-> DockerHub : docker build\n& docker push :$SHA
}

'===========================================================
' RIGHT: AWS VPC
'===========================================================
cloud "AWS Cloud" #AliceBlue {

  component "Route 53\n(DNS)" as R53
  component "CloudFront CDN\n(Static + Media)" as CF

  R53 -right-> CF : resolve\nbinchat.app

  package "VPC — 10.0.0.0/16" {

    '--- Tier 1: Public Subnet ---
    package "Tier 1 — Public Subnet\n(API Gateway + Nginx)" #LightBlue {
      component "Nginx :443\n- SSL termination\n- Reverse proxy\n- Rate limiting\n- WebSocket upgrade" as Nginx
    }

    '--- Tier 2: Private App Subnet ---
    package "Tier 2 — EC2 t3.medium\n(Private App Subnet)" #LightGreen {

      component "Docker Compose\nOrchestrator" as DC

      package "Application Containers" {
        component "api-gateway :3000\nNestJS\n- JWT validate\n- HTTP proxy\n- Socket.io hub\n- Kafka consumer" as GW
        component "auth-service :3010\nNestJS\n- Register/Login\n- JWT issue\n- OTP (Redis)\n- Device track" as AUTH
        component "user-service :3020\nNestJS\n- Profile CRUD\n- User search\n- Kafka sync" as USER
        component "friend-service :3025\nNestJS\n- Friend requests\n- PENDING/ACCEPTED\n- BLOCKED" as FRIEND
        component "chat-service :3040\nNestJS\n- Messages\n- Conversations\n- Group chat\n- Kafka produce" as CHAT
        component "upload-service :3035\nNestJS\n- S3 presign\n- 2-step upload" as UPLOAD
        component "notification-service :3030\nNestJS\n- Kafka consumer\n- Gmail SMTP\n- No HTTP endpoint" as NOTIF
      }
    }

    '--- Tier 3: Data Subnet ---
    package "Tier 3 — Data Layer\n(same EC2, Docker volumes)" #LightGoldenRodYellow {
      database "PostgreSQL :5432\n- auth_service DB\n- user_service DB\n- friend_service DB" as PG
      database "MongoDB :27017\n- chat_service DB\n- messages collection\n- conversations" as Mongo
      database "Redis :6379\n- OTP cache (TTL)\n- Session / JWT\n- Rate counters" as Redis
      component "Redpanda :9092\n(Kafka-compatible)\n- Kafka topics\n- Event bus" as Kafka
      component "coturn :3478\n(STUN/TURN)\n- WebRTC relay\n- P2P fallback" as Coturn
    }

    '--- Tier 4: Observability ---
    package "Tier 4 — Observability" #MistyRose {
      component "Prometheus :9090\n(metrics scrape)" as Prom
      component "Grafana :3001\n(dashboards + alerts)" as Grafana
    }
  }

  '--- AWS Managed Services ---
  package "AWS Managed Services" #Lavender {
    component "S3 Bucket\n(media files)" as S3
    component "Lambda\n- image-processor\n- video-dispatcher" as Lambda
    component "CloudWatch\n(logs + alarms)" as CW
  }
}

'--- Clients ---
package "Clients" #Honeydew {
  actor "Web Browser\n(React + Vite)" as Web
  actor "Mobile App\n(Expo React Native)" as Mobile
}

'===========================================================
' Connections
'===========================================================

' DevOps → EC2
GHActions -right-> DC : SSH deploy\n(appleboy/ssh-action)\ndocker-compose pull\ndocker-compose up -d

DockerHub -right-> DC : docker pull\n(on deploy)

' DNS/CDN → Nginx
CF -down-> Nginx : HTTPS requests

' Clients → CDN/Nginx
Web -up-> CF : HTTPS + WSS
Mobile -up-> CF : HTTPS + WSS

' Nginx → Gateway
Nginx -down-> GW : proxy_pass :3000\n+ WebSocket upgrade

' Gateway → Services
GW -down-> AUTH : HTTP :3010
GW -down-> USER : HTTP :3020
GW -down-> FRIEND : HTTP :3025
GW -down-> CHAT : HTTP :3040
GW -down-> UPLOAD : HTTP :3035

' Services → Data
AUTH -down-> PG : TypeORM\nauth_service
USER -down-> PG : TypeORM\nuser_service
FRIEND -down-> PG : TypeORM\nfriend_service
CHAT -down-> Mongo : Mongoose
AUTH -down-> Redis : OTP + session
GW -right-> Redis : socket presence

' Kafka
AUTH -down-> Kafka : user.registered\nuser.updated
CHAT -down-> Kafka : message.sent
FRIEND -down-> Kafka : friend.accepted
NOTIF -down-> Kafka : consume all topics

' Upload → AWS
UPLOAD -down-> S3 : presigned PUT URL
S3 -right-> Lambda : ObjectCreated\ntrigger
CF -up-> S3 : serve media

' WebRTC
GW -down-> Coturn : ICE servers\nconfig

' Observability
GW -right-> Prom : GET /metrics
AUTH -right-> Prom : GET /metrics
Prom -right-> Grafana : query
CW -up-> Grafana : logs (optional)

@enduml
```

---

## Sơ đồ 2 — CI/CD Pipeline (GitHub Actions → EC2)

> Luồng đầy đủ từ khi developer push code đến khi hệ thống chạy trên EC2.

```plantuml
@startuml CICD_PIPELINE

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2
skinparam sequenceGroupHeaderFontSize 13
skinparam noteBackgroundColor #FFFACD
skinparam noteBorderColor #CCAA00

title BinChat — CI/CD Pipeline: GitHub Actions → EC2

actor "Developer" as Dev
participant "GitHub\n(main branch)" as GH
participant "GitHub Actions\nRunner (ubuntu-latest)" as GA
participant "Docker Hub\n(public repo)" as DHub
participant "EC2\n(Ubuntu 22.04)" as EC2
participant "Docker Compose\n(on EC2)" as DC
participant "/api/health\n(Gateway)" as HC

Dev -> GH : (1) git push origin main

note over GH
  Branch protection rules:
  - PR review required
  - CI must pass before merge
end note

GH -> GA : (2) Trigger workflow\n.github/workflows/deploy.yml

group Job 1 — Test & Lint [runs-on: ubuntu-latest]
  GA -> GA : actions/checkout@v4
  GA -> GA : actions/setup-node@v4 (Node 20)
  GA -> GA : npm ci
  GA -> GA : npm run lint --workspaces
  GA -> GA : npm run test:unit --workspaces
  alt Tests FAILED
    GA --> Dev : GitHub Status: FAILED\n❌ Fix code và push lại
  else Tests PASSED
    GA -> GA : ✅ CI passed — proceed
  end
end

group Job 2 — Build & Push [needs: test]
  GA -> GA : docker/setup-buildx-action@v3
  GA -> GA : docker/login-action@v3\n(DOCKER_USERNAME + DOCKER_TOKEN)
  note over GA
    Build 7 images (matrix strategy):
    - binchat/api-gateway
    - binchat/auth-service
    - binchat/user-service
    - binchat/friend-service
    - binchat/chat-service
    - binchat/upload-service
    - binchat/notification-service
  end note
  GA -> GA : docker build --platform linux/amd64\n-t binchat/<service>:${{ github.sha }}\n-t binchat/<service>:latest
  GA -> DHub : docker push binchat/<service>:$SHA\ndocker push binchat/<service>:latest
end

group Job 3 — Deploy to EC2 [needs: build-push, if: branch=main]
  GA -> GA : Setup SSH key\n(echo "$EC2_SSH_KEY" > key.pem\nchmod 600 key.pem)
  GA -> EC2 : (3) SSH connect\nssh -i key.pem ubuntu@$EC2_HOST
  activate EC2
  EC2 -> EC2 : export IMAGE_TAG=${{ github.sha }}
  EC2 -> DHub : docker-compose pull
  DHub --> EC2 : pull latest images
  EC2 -> DC : docker-compose up -d\n--remove-orphans
  DC --> EC2 : containers started
  loop Health Check — tối đa 10 lần, cách 10s
    EC2 -> HC : curl -sf http://localhost:3000/api/health
    HC --> EC2 : { "status": "ok" }
  end
  alt Health OK
    EC2 --> GA : exit 0 — deploy successful
    deactivate EC2
    GA --> Dev : (4) ✅ Deployed $SHA\nbinchat.app is live
    GA -> GH : GitHub Deployment Status: active
  else Health FAILED
    EC2 -> DC : Rollback:\nexport IMAGE_TAG=$PREV_SHA\ndocker-compose up -d
    EC2 --> GA : exit 1 — rolled back
    GA --> Dev : ❌ Deploy failed — auto rolled back\nCheck Actions logs
  end
end

note over Dev, HC
  GitHub Secrets cần cấu hình:
  EC2_HOST, EC2_USERNAME, EC2_SSH_KEY
  DOCKER_USERNAME, DOCKER_TOKEN
  POSTGRES_PASSWORD, JWT_SECRET, v.v.
end note

@enduml
```

---

## Sơ đồ 3 — Luồng xác thực JWT (2 trường hợp)

> Tham khảo Fig 4: **Quy trình check auth qua Auth Service** và **không qua Auth Service**.

```plantuml
@startuml AUTH_FLOW

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2
skinparam noteBackgroundColor #EEF8FF

title BinChat — Luồng xác thực JWT (API Gateway)

actor "Client\n(Web/Mobile)" as Client
participant "Nginx\n:443" as Nginx
participant "API Gateway\n:3000" as GW
participant "Auth Service\n:3010" as AUTH
database "Redis\n(blacklist)" as Redis
participant "Downstream\nService :3020~3040" as SVC

note over GW
  JWT lưu trong HttpOnly cookie
  (access_token, refresh_token)
end note

== TRƯỜNG HỢP 1: Gateway tự verify JWT (không gọi Auth Service) ==

Client -> Nginx : HTTPS Request\n+ Cookie: access_token=<JWT>
Nginx -> GW : proxy_pass :3000

GW -> GW : (1) Đọc JWT từ cookie
GW -> GW : (2) Verify signature\nbằng JWT_SECRET (env var)
GW -> GW : (3) Check exp (expiration)
GW -> Redis : (4) Check blacklist\nkey: blacklist:<jti>
Redis --> GW : null (không bị blacklist)
GW -> GW : (5) Extract payload:\nuser_id, role\n→ set header X-User-ID, X-User-Role
GW -> SVC : Forward request\n+ X-User-ID: 123\n+ X-User-Role: user

note right of GW
  ✅ Ưu điểm:
  - Giảm latency (không cần gọi Auth Service)
  - Không tạo bottleneck ở Auth Service
  - Stateless, gateway scale dễ
  - Auth Service down → các API khác vẫn chạy

  ❌ Nhược điểm:
  - Không revoke token ngay lập tức\n    (chỉ check blacklist Redis)
  - Nếu JWT bị lộ → tấn công đến khi hết hạn
end note

SVC --> GW : Response
GW --> Nginx : Response
Nginx --> Client : HTTPS Response

== TRƯỜNG HỢP 2: Qua Auth Service (validate đầy đủ) ==

Client -> Nginx : HTTPS Request\n(route /api/auth/*)
Nginx -> GW : proxy_pass :3000
GW -> AUTH : GET /api/auth/validate\n+ Header: Authorization: Bearer <JWT>
AUTH -> AUTH : (1) Verify signature
AUTH -> AUTH : (2) Check expiration
AUTH -> Redis : (3) Check Redis blacklist\n(có thể revoke ngay lập tức)
Redis --> AUTH : not blacklisted
AUTH -> AUTH : (4) Check device login status\n(device_id có trong DB không?)
AUTH --> GW : 200 OK + { user_id, role, ... }
GW -> GW : Set X-User-ID, X-User-Role headers
GW -> SVC : Forward request + headers

note right of AUTH
  ✅ Ưu điểm:
  - Revoke token ngay lập tức (Redis)
  - Kiểm tra device, block user real-time
  - Bảo mật hơn cho các route nhạy cảm

  ❌ Nhược điểm:
  - Tăng latency (thêm 1 HTTP call)
  - Auth Service là single point of failure
  - Tăng network traffic
end note

SVC --> GW : Response
GW --> Client : HTTPS Response

== Token hết hạn — Refresh Flow ==

Client -> GW : Request với expired access_token
GW -> GW : Verify → TokenExpiredError
GW --> Client : 401 Unauthorized
Client -> GW : POST /api/auth/refresh\n+ Cookie: refresh_token=<JWT_REFRESH>
GW -> AUTH : proxy → POST /refresh
AUTH -> AUTH : Verify refresh token (7d TTL)
AUTH -> Redis : Revoke old refresh token
AUTH -> AUTH : Issue new access_token (15m)\n+ new refresh_token (7d)
AUTH --> Client : Set-Cookie: access_token, refresh_token

@enduml
```

---

## Sơ đồ 4 — Luồng gửi tin nhắn real-time

```plantuml
@startuml MESSAGE_FLOW

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2

title BinChat — Luồng gửi tin nhắn (WebSocket + Kafka)

actor "Sender\n(Web/Mobile)" as Sender
actor "Receiver\n(Web/Mobile)" as Receiver
participant "API Gateway\n:3000\n(Socket.io hub)" as GW
participant "Chat Service\n:3040" as CHAT
database "MongoDB\n(messages)" as Mongo
queue "Redpanda\n(Kafka)" as Kafka
participant "Notification\nService :3030" as NOTIF
participant "Gmail SMTP" as SMTP

note over Sender
  Đã kết nối WebSocket
  sau khi đăng nhập
end note

== Kết nối WebSocket ==
Sender -> GW : ws://gateway:3000/\n+ Cookie: access_token
GW -> GW : Verify JWT từ cookie
GW -> GW : socket.join(userId)\nsocket.join(conversationId)

== Gửi tin nhắn ==
Sender -> GW : emit('send_message', {\n  conversationId,\n  content, type\n})

GW -> CHAT : HTTP POST /messages\n(proxy với X-User-ID header)
CHAT -> Mongo : insertOne(message)\n{ _id, conversationId,\n  senderId, content,\n  type, createdAt }
Mongo --> CHAT : { _id: "64abc..." }

CHAT -> Kafka : produce('chat.message.sent', {\n  messageId, conversationId,\n  senderId, receiverIds,\n  content, type\n})

CHAT --> GW : 201 Created\n{ message: { _id, content, ... } }

' Broadcast realtime
GW -> GW : io.to(conversationId)\n  .emit('new_message', message)
GW --> Receiver : emit('new_message', {\n  _id, content, senderId,\n  conversationId, createdAt\n})
GW --> Sender : emit('message_sent', { _id, status: 'sent' })

' Kafka → Notification
Kafka --> NOTIF : consume('chat.message.sent')
NOTIF -> NOTIF : Check: Receiver có\nonline không?

alt Receiver OFFLINE
  NOTIF -> SMTP : sendMail(\n  to: receiver@email.com,\n  subject: "Tin nhắn mới từ...",\n  body: content preview\n)
  SMTP --> NOTIF : 250 OK
else Receiver ONLINE
  note over NOTIF
    Không gửi email vì
    đã nhận qua WebSocket
  end note
end

@enduml
```

---

## Ghi chú kiến trúc hiện tại

| Thành phần | Công nghệ | Ghi chú |
|---|---|---|
| API Gateway | NestJS :3000 | JWT verify, HTTP proxy, Socket.io |
| Auth Service | NestJS + PostgreSQL :3010 | JWT 15m/7d, bcrypt, OTP Redis |
| User Service | NestJS + PostgreSQL :3020 | Profile, search, Kafka sync |
| Friend Service | NestJS + PostgreSQL :3025 | PENDING/ACCEPTED/DECLINED/BLOCKED |
| Chat Service | NestJS + MongoDB :3040 | Messages, conversations, groups |
| Upload Service | NestJS + S3 :3035 | Presign 2-step, CloudFront CDN |
| Notification Service | NestJS :3030 | Kafka consumer only, Gmail SMTP |
| Event Bus | Redpanda (Kafka API) :9092 | Single node, Kafka-compatible |
| Cache | Redis :6379 | OTP TTL, session, rate limiter |
| TURN Server | coturn :3478 | WebRTC P2P fallback |
| CI/CD | GitHub Actions | SSH → EC2, docker-compose pull & up |
| Registry | Docker Hub | Free public repo |
| Compute | EC2 t3.medium | 2vCPU, 4GB RAM, Ubuntu 22.04 |

### Điểm yếu cần cải thiện

| Vấn đề | Nguyên nhân | Giải pháp |
|---|---|---|
| Socket.io state in-memory | Không dùng Redis adapter | Thêm Upstash Redis adapter |
| Không có rate limiting | Gateway chưa cấu hình | Redis-based rate limit |
| MongoDB không có index | Schema không khai báo index | Thêm compound index |
| Không có monitoring | Chưa cài Prometheus/Grafana | Grafana Cloud free |
| coturn không TLS | Config đơn giản | TLS + credentials |
| Single-node Redpanda | Không có HA | Upstash Kafka managed |
| Lambda/S3 egress tốn tiền | AWS pricing | Cloudflare R2 + Workers |
