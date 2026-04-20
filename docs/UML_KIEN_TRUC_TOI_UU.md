# UML — Kiến trúc tối ưu (Free/Low-cost) + Deployment EC2 + CI/CD

> **BinChat** — Phiên bản tối ưu chi phí, phù hợp học tập / demo  
> Thay thế các dịch vụ tốn kém bằng free-tier: Neon, Atlas, Upstash, Cloudflare R2, Resend

---

## Bảng so sánh: Hiện tại → Tối ưu

| Thành phần | Hiện tại (tốn tiền) | Tối ưu (miễn phí / rẻ) | Tiết kiệm |
|---|---|---|---|
| PostgreSQL | Self-host Docker | **Neon.tech** Serverless (free 0.5GB) | EC2 RAM |
| MongoDB | Self-host Docker | **MongoDB Atlas M0** (free 512MB) | EC2 RAM |
| Redis | Self-host Docker | **Upstash Redis** (free 10k req/day) | EC2 RAM |
| Kafka | Self-host Redpanda | **Upstash Kafka** (free 10k msg/day) | EC2 RAM |
| S3 + egress | AWS S3 (egress $$) | **Cloudflare R2** (egress free, 10GB/month) | ~$50/TB |
| Lambda | AWS Lambda ($) | **Cloudflare Workers** (free 100k req/day) | ~$3/month |
| Email | Gmail SMTP (giới hạn) | **Resend.com** (free 3k/month) | Deliverability |
| TURN Server | coturn self-host | **Metered.ca** (free 50GB/month) | Bảo mật |
| Monitoring | Không có | **Grafana Cloud** (free 10k series) | Observability |
| CDN | CloudFront | **Cloudflare CDN** (free unlimited) | ~$8/month |
| CI/CD | Thủ công | **GitHub Actions** (free 2000 min/month) | Zero manual |
| Compute | EC2 t3.medium $33/mo | **EC2 t3.small $15/mo** (DB ra ngoài) | ~$18/month |

---

## Sơ đồ 1 — Kiến trúc tối ưu + VPC Deployment

```plantuml
@startuml KIEN_TRUC_TOI_UU

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam defaultFontName Arial
skinparam ArrowColor #555555
skinparam component {
  BackgroundColor #D5F5E3
  BorderColor #27AE60
}
skinparam database {
  BackgroundColor #FEF9E7
  BorderColor #F39C12
}
skinparam node {
  BackgroundColor #EBF5FB
  BorderColor #2980B9
}

title BinChat — Kiến trúc tối ưu + k3s trên EC2 (Free/Low-cost Services)

'===========================================================
' LEFT: DevOps Workflow
'===========================================================
package "DevOps Workflow" #LightYellow {
  actor "Developer" as Dev
  component "GitHub\nRepository" as GitHub
  component "GitHub Actions\n(Free 2000 min/month)\nCI: lint + test\nCD: build + deploy" as GHActions
  component "Docker Hub\n(Free public repo)" as DockerHub

  Dev -down-> GitHub : git push main
  GitHub -down-> GHActions : trigger k3s-deploy.yml\n(on push to main)
  GHActions -down-> DockerHub : docker build\n& push :$SHA\n(matrix: 7 services)
}

'===========================================================
' CLOUD ARCHITECTURE
'===========================================================
cloud "Cloud Infrastructure" #AliceBlue {

  '--- DNS + CDN ---
  component "Cloudflare\n(Free DNS + CDN)\n- binchat.app\n- HTTPS + DDoS\n- Cache edge" as CF

  package "AWS VPC — 10.0.0.0/16" {

    '--- Tier 1: Public Subnet ---
    package "Tier 1 — Public Subnet\n(Ingress + TLS)" #LightBlue {
      component "Nginx Ingress Controller\n(k3s built-in)\n- SSL termination (Let's Encrypt)\n- Route /api/* → Gateway Pod\n- Route /socket.io/* → Gateway Pod\n- WebSocket upgrade\n- Rate limiting" as Ingress

      note right of Ingress
        Security Group:
        Inbound: 80, 443 (0.0.0.0/0)
        Outbound: all to sg-app
        Port 6443 (kubectl): chỉ mở cho IP dev
      end note
    }

    '--- Tier 2: EC2 + k3s ---
    package "Tier 2 — EC2 t3.medium (2vCPU, 4GB RAM)\nPrivate App Subnet — k3s Single Node" #LightGreen {

      component "k3s\n(Kubernetes nhẹ — $0 overhead)\nControl Plane + Worker\ncùng 1 máy EC2" as K3S

      package "Namespace: binchat" {
        package "Deployments (Pods)" {
          component "api-gateway\nDeployment :3000\n- JWT verify\n- HTTP proxy\n- Socket.io" as GW
          component "auth-service\nDeployment :3010\n- Login/Register\n- JWT + OTP" as AUTH
          component "user-service\nDeployment :3020\n- Profile + Search" as USER
          component "friend-service\nDeployment :3025\n- Friend graph" as FRIEND
          component "chat-service\nDeployment :3040\n- Messages + Groups" as CHAT
          component "upload-service\nDeployment :3035\n- R2 presign URL" as UPLOAD
          component "notification-service\nDeployment :3030\n- Kafka consumer\n- Email + Push" as NOTIF
        }

        package "k8s Resources" {
          component "ClusterIP Services\n(internal routing)" as SVCS
          component "Ingress Resource\n(routing rules)" as INGRES
          component "Secrets\n(JWT, API keys,\nDB URLs)" as SEC
          component "ConfigMap\n(non-sensitive env)" as CM
        }
      }

      note right of K3S
        Rolling Update (zero downtime):
        kubectl apply → tạo Pod mới
        → chờ readinessProbe OK
        → xóa Pod cũ
        kubectl rollout undo (auto rollback)
      end note
    }

    '--- Tier 3: Managed Data ---
    package "Tier 3 — Managed Data\n(External Free Services)" #LightGoldenRodYellow {
      database "Neon.tech\nServerless Postgres\n- auth_service DB\n- user_service DB\n- friend_service DB\n(Free 0.5GB)" as Neon
      database "MongoDB Atlas M0\n- chat_service DB\n- messages + conversations\n(Free 512MB)" as Atlas
      database "Upstash Redis\n- OTP cache (TTL)\n- Socket presence\n- Rate counters\n(Free 10k req/day)" as UpRedis
      component "Upstash Kafka\n- notification.email\n- chat.message.sent\n- user.* / friend.*\n(Free 10k msg/day)" as UpKafka
    }

    '--- Tier 4: Observability ---
    package "Tier 4 — Observability\n(Free Managed Services)" #MistyRose {
      component "Grafana Cloud\n(Free 10k series)\n- Dashboards + Alerts" as GrafanaC
      component "Upstash Console\n(Redis + Kafka metrics)" as UpConsole
    }
  }

  '--- External Free Services ---
  package "External Free Services" #Lavender {
    component "Cloudflare R2\n- Media storage\n- Egress FREE\n(10GB free/month)" as R2
    component "Cloudflare Workers\n- Image processing\n- Resize → webp\n(100k req/day free)" as CFW
    component "Resend.com\n- Email\n(3k/month free)" as Resend
    component "Metered.ca TURN\n- WebRTC relay\n(50GB/month free)" as MeteredTURN
    component "Expo Push\n- Mobile push\n(FREE)" as ExpoPush
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

' DevOps → k3s
GHActions -right-> K3S : SSH + kubectl apply -f k8s/\n(scp manifests → EC2\n→ kubectl apply với image :$SHA\n→ kubectl rollout status\n→ rollback nếu fail)
DockerHub -right-> K3S : pull image :$SHA\n(khi Pod tạo mới)

' DNS/CDN → Ingress
CF -down-> Ingress : HTTPS proxy
Web -up-> CF : HTTPS
Mobile -up-> CF : HTTPS

' Ingress → Gateway Pod
Ingress -down-> GW : route /api/* + /socket.io/*\n(ClusterIP service)

' k3s internal routing
K3S -down-> SVCS : ClusterIP routing
SVCS -down-> GW
SVCS -down-> AUTH
SVCS -down-> USER

' Gateway → Services (ClusterIP)
GW -down-> AUTH : ClusterIP :3010
GW -down-> USER : ClusterIP :3020
GW -down-> FRIEND : ClusterIP :3025
GW -down-> CHAT : ClusterIP :3040
GW -down-> UPLOAD : ClusterIP :3035

' Config injection
SEC -up-> GW : envFrom secretRef
CM -up-> GW : envFrom configMapRef

' Services → Managed DBs
AUTH -down-> Neon : TLS Postgres
USER -down-> Neon : TLS Postgres
FRIEND -down-> Neon : TLS Postgres
CHAT -down-> Atlas : TLS MongoDB
AUTH -down-> UpRedis : HTTPS REST
GW -down-> UpRedis : HTTPS REST

' Kafka
AUTH -right-> UpKafka : SASL/SSL produce
CHAT -right-> UpKafka : SASL/SSL produce
FRIEND -right-> UpKafka : SASL/SSL produce
NOTIF -down-> UpKafka : consume

' Notification
NOTIF -right-> Resend : POST api.resend.com
NOTIF -right-> ExpoPush : POST exp.host/push

' Upload → R2
UPLOAD -down-> R2 : presigned PUT URL
R2 -right-> CFW : objectCreated webhook
CFW -right-> R2 : write thumb/medium/large.webp
CF -down-> R2 : serve media (egress free)

' WebRTC
GW -down-> MeteredTURN : ICE servers config

' Observability
GW -right-> GrafanaC : Prometheus remote_write
AUTH -right-> GrafanaC : metrics
UpConsole -up-> GrafanaC : Redis/Kafka metrics

@enduml
```

---

## Sơ đồ 2 — CI/CD Pipeline tối ưu (GitHub Actions → EC2)

```plantuml
@startuml CICD_TOI_UU

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2
skinparam noteBackgroundColor #FFFACD
skinparam noteBorderColor #CCAA00

title BinChat — CI/CD Pipeline tối ưu (GitHub Actions miễn phí → EC2)

actor "Developer" as Dev
participant "GitHub\n(main branch)" as GH
participant "GitHub Actions\n(Free runner)" as GA
participant "Docker Hub\n(Free public)\nhoặc ghcr.io" as DHub
participant "EC2 t3.small\n(Ubuntu 22.04)" as EC2
participant "Docker Compose" as DC
participant "Health Check\n/api/health" as HC

Dev -> GH : git push origin main

GH -> GA : Trigger: .github/workflows/deploy.yml

group Job 1 — test [ubuntu-latest]
  GA -> GA : checkout + setup Node 20
  GA -> GA : npm ci (cache node_modules)
  GA -> GA : npm run lint --workspaces
  GA -> GA : npm run test:unit --workspaces
  alt FAILED
    GA --> Dev : ❌ CI failed — không deploy
  else PASSED
    GA -> GA : ✅ Continue to build
  end
end

group Job 2 — build-push [needs: test, if: main branch]
  note over GA
    Matrix strategy — build 7 services song song:
    api-gateway, auth, user, friend, chat, upload, notification
  end note
  GA -> GA : docker/setup-buildx-action@v3\n(build cache via GitHub Actions Cache)
  GA -> GA : docker/login-action@v3\n(secrets: DOCKER_USERNAME + DOCKER_TOKEN)
  GA -> GA : docker/build-push-action@v5\ncache-from: type=gha\n(tăng tốc build ~3x)
  GA -> DHub : push binchat/<service>:$SHA\npush binchat/<service>:latest
end

group Job 3 — deploy-ec2 [needs: build-push, environment: production]
  GA -> GA : Tạo SSH key từ secret\nchmod 600 deploy_key
  GA -> EC2 : SSH (appleboy/ssh-action@v1)
  activate EC2
  EC2 -> EC2 : cd ~/binchat\nexport IMAGE_TAG=$SHA
  EC2 -> DHub : docker-compose pull
  DHub --> EC2 : images pulled
  EC2 -> DC : docker-compose up -d\n--remove-orphans
  DC --> EC2 : containers running

  loop Health check (max 10 lần × 10s)
    EC2 -> HC : curl -sf localhost:3000/api/health
    HC --> EC2 : {"status":"ok"}
  end

  alt Deploy OK
    EC2 --> GA : exit 0
    deactivate EC2
    GA --> Dev : ✅ Deployed to binchat.app\nCommit: $SHA
  else Deploy FAILED
    EC2 -> DC : Rollback:\nexport IMAGE_TAG=$PREV_SHA\ndocker-compose up -d
    GA --> Dev : ❌ Deploy failed — rolled back
  end
end

note over Dev, HC
  GitHub Secrets cần cấu hình:
  ─────────────────────────────
  EC2_HOST          = <ec2-public-ip>
  EC2_USERNAME      = ubuntu
  EC2_SSH_KEY       = <private-key-content>
  DOCKER_USERNAME   = <dockerhub-username>
  DOCKER_TOKEN      = <dockerhub-access-token>
  ─────────────────────────────
  App Secrets (trong .env.production trên EC2):
  POSTGRES_URL      = postgresql://neon.tech/...
  MONGODB_URI       = mongodb+srv://atlas...
  REDIS_URL         = https://upstash.io/...
  JWT_SECRET        = <secret>
  RESEND_API_KEY    = re_...
  CF_ACCOUNT_ID     = <cloudflare-account>
  R2_ACCESS_KEY     = <r2-key>
end note

@enduml
```

---

## Sơ đồ 3 — Luồng gửi tin nhắn tối ưu (R2 + Upstash + Push Notification)

```plantuml
@startuml MESSAGE_FLOW_TOI_UU

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2

title BinChat tối ưu — Luồng gửi tin nhắn + Push Notification

actor "Sender\n(Web/Mobile)" as Sender
actor "Receiver\n(Mobile, offline)" as Receiver
participant "Cloudflare CDN\n+ DNS" as CF
participant "API Gateway\n:3000\n(Socket.io + Redis adapter)" as GW
participant "Chat Service\n:3040" as CHAT
database "MongoDB Atlas\n(messages)" as Atlas
database "Upstash Redis\n(presence)" as UpRedis
queue "Upstash Kafka" as UpKafka
participant "Notification\nService :3030" as NOTIF
participant "Resend.com\n(Email)" as Resend
participant "Expo Push\n(Mobile)" as ExpoPush

' Connect
Sender -> CF : WSS wss://binchat.app/
CF -> GW : WebSocket upgrade
GW -> GW : Verify JWT (cookie)
GW -> UpRedis : SET presence:<userId>\nEX 300s (5 phút TTL)
GW -> GW : socket.join(conversationId)

' Send message
Sender -> GW : emit('send_message', {\n  conversationId, content, type\n})

GW -> CHAT : POST /api/messages\n+ X-User-ID header
CHAT -> Atlas : insertOne({\n  conversationId,\n  senderId, content,\n  type, createdAt\n})
Atlas --> CHAT : { _id: "64abc..." }

CHAT -> UpKafka : produce('chat.message.sent', {\n  messageId, conversationId,\n  senderId, receiverIds,\n  content, type\n})

CHAT --> GW : 201 { message }

' Realtime broadcast
GW -> UpRedis : GET presence:<receiverId>
UpRedis --> GW : TTL > 0 (online)
GW -> GW : io.to(conversationId)\n  .emit('new_message', message)
GW --> Receiver : Socket emit new_message

' Kafka → Notification
UpKafka --> NOTIF : consume chat.message.sent

NOTIF -> UpRedis : GET presence:<receiverId>
UpRedis --> NOTIF : null (offline / TTL expired)

alt Receiver OFFLINE
  NOTIF -> Resend : POST /emails\n{\n  to: receiver@email,\n  subject: "Tin nhắn mới",\n  react: EmailTemplate\n}
  Resend --> NOTIF : { id: "re_xxx" }

  NOTIF -> ExpoPush : POST exp.host/--/api/v2/push/send\n{\n  to: "ExponentPushToken[xxx]",\n  title: "Sender Name",\n  body: content preview\n}
  ExpoPush --> Receiver : Push notification
else Receiver ONLINE
  note over NOTIF
    Đã nhận qua WebSocket
    → bỏ qua email + push
  end note
end

@enduml
```

---

## Sơ đồ 4 — Upload file lên Cloudflare R2

```plantuml
@startuml UPLOAD_R2

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2

title BinChat tối ưu — Upload file lên Cloudflare R2 (2-step presign)

actor "Client\n(Web/Mobile)" as Client
participant "API Gateway\n:3000" as GW
participant "Upload Service\n:3035" as UPLOAD
component "Cloudflare R2\n(S3-compatible API)" as R2
component "Cloudflare Workers\n(image processor)" as CFW
component "Cloudflare CDN\n(serve media)" as CFCDN

note over R2
  S3-compatible API
  Endpoint: https://<account>.r2.cloudflarestorage.com
  Egress: FREE (không tính phí khi serve qua CDN)
end note

== Bước 1: Lấy presigned URL ==

Client -> GW : POST /api/upload/presign\n{\n  filename: "photo.jpg",\n  contentType: "image/jpeg",\n  size: 2048576\n}
GW -> UPLOAD : proxy (+ X-User-ID)
UPLOAD -> UPLOAD : Validate:\n- size <= 50MB (image)\n- size <= 200MB (video)\n- contentType whitelist
UPLOAD -> R2 : S3 createPresignedUrl\n(PUT, key: uploads/uuid.jpg, TTL: 5m)
R2 --> UPLOAD : presignedUrl
UPLOAD --> Client : {\n  presignedUrl: "https://r2.../uploads/uuid.jpg?sig=...",\n  fileKey: "uploads/uuid.jpg",\n  expiresIn: 300\n}

== Bước 2: Upload trực tiếp lên R2 ==

Client -> R2 : PUT presignedUrl\n+ Content-Type: image/jpeg\n+ Body: raw file bytes
R2 --> Client : 200 OK

== Bước 3: Confirm upload ==

Client -> GW : POST /api/upload/confirm\n{ fileKey: "uploads/uuid.jpg", messageId }
GW -> UPLOAD : proxy
UPLOAD -> R2 : HeadObject (verify exists)
R2 --> UPLOAD : 200 + ContentLength, ETag

' Trigger Cloudflare Worker
R2 -> CFW : R2 Event Notification\n(objectCreated: uploads/uuid.jpg)
CFW -> R2 : GET original file
R2 --> CFW : raw image/video bytes

alt Image (jpg/png/gif/webp)
  CFW -> CFW : sharp library:\n- thumb_uuid.webp (200x200)\n- medium_uuid.webp (800px)\n- large_uuid.webp (1920px)
  CFW -> R2 : PUT processed/thumb_uuid.webp\nPUT processed/medium_uuid.webp\nPUT processed/large_uuid.webp
else Video (mp4/mov/webm)
  CFW -> CFW : ffmpeg wasm:\n- 360p thumbnail\n- 720p compressed
  CFW -> R2 : PUT processed/thumb_uuid.jpg\nPUT processed/720p_uuid.mp4
end

UPLOAD --> Client : {\n  status: "confirmed",\n  urls: {\n    original: "https://cdn.binchat.app/uploads/uuid.jpg",\n    thumb: "https://cdn.binchat.app/processed/thumb_uuid.webp",\n    medium: "https://cdn.binchat.app/processed/medium_uuid.webp"\n  }\n}

' Serve via CDN
Client -> CFCDN : GET cdn.binchat.app/processed/medium_uuid.webp
CFCDN -> R2 : fetch from R2 (first time)
R2 --> CFCDN : file bytes
CFCDN --> Client : serve (cached at edge)

note over CFCDN
  Cloudflare CDN:
  - Cache media ở edge node
  - Egress R2 → CDN = FREE
  - Tiết kiệm vs S3 + CloudFront ($0.09/GB)
end note

@enduml
```

---

## Ước tính chi phí

| Dịch vụ | Plan | Chi phí |
|---|---|---|
| EC2 t3.small | On-demand | ~$15/tháng |
| Cloudflare (DNS + CDN + R2 + Workers) | Free | $0 |
| Neon.tech (PostgreSQL) | Free 0.5GB | $0 |
| MongoDB Atlas | M0 Free 512MB | $0 |
| Upstash Redis | Free 10k req/day | $0 |
| Upstash Kafka | Free 10k msg/day | $0 |
| Resend.com | Free 3k emails/month | $0 |
| Metered.ca TURN | Free 50GB/month | $0 |
| Expo Push | Free | $0 |
| Grafana Cloud | Free 10k series | $0 |
| GitHub Actions | Free 2000 min/month | $0 |
| **TỔNG** | | **~$15/tháng** |

> Với EC2 Free Tier (t2.micro, 12 tháng đầu) → **$0/tháng** cho năm đầu tiên.

---

## Ghi chú triển khai

### GitHub Secrets cần cấu hình

```
EC2_HOST          = <public-ip-ec2>
EC2_USERNAME      = ubuntu
EC2_SSH_KEY       = <nội dung file .pem>
DOCKER_USERNAME   = <dockerhub-username>
DOCKER_TOKEN      = <dockerhub-access-token>
```

### File `.env.production` trên EC2

```
POSTGRES_URL=postgresql://user:pass@<neon-host>/auth_service?sslmode=require
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/chat_service
REDIS_URL=rediss://:<token>@<upstash-host>:6380
KAFKA_BROKER=<upstash-kafka-host>:9092
JWT_SECRET=<long-random-secret>
JWT_REFRESH_SECRET=<another-long-secret>
RESEND_API_KEY=re_xxxxx
CLOUDFLARE_ACCOUNT_ID=xxxxx
R2_ACCESS_KEY_ID=xxxxx
R2_SECRET_ACCESS_KEY=xxxxx
R2_BUCKET_NAME=binchat-media
METERED_API_KEY=xxxxx
```
