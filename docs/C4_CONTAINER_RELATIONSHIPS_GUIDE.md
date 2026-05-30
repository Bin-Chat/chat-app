# C4 Container Relationships Guide - BinChat

File nay dung de ve lai C4 Container Diagram cho BinChat. Muc tieu la the hien dung frontend, API Gateway, backend services, Kafka, database/storage va cac luong giao tiep chinh.

## 1. Cach Hieu Tong Quan

Trong C4 Container Diagram, khong can ve tung class hay tung function. Chi can ve cac container lon:

- Web App
- Mobile App
- Caddy Reverse Proxy
- API Gateway
- Auth Service
- User Service
- Friend Service
- Chat Service
- Upload Service
- AI Service
- Notification Service
- Redpanda Kafka
- PostgreSQL
- MongoDB
- Redis
- Qdrant
- AWS S3
- SMTP/Gmail
- Coturn

Nen chia diagram thanh cac vung:

```txt
Clients | API Gateway / Edge | Core Backend Services | Databases / Storage | Event Platform | External Services
```

## 2. Client Den API Gateway

Client giao tiep voi backend bang 2 kieu ket noi song song:

- HTTPS REST API
- Socket.IO realtime

Khong nen chi ve moi HTTPS, vi realtime cua chat can Socket.IO.

### 2.1 REST API

REST API dung cho cac request binh thuong:

- Dang ky
- Dang nhap
- Lay profile
- Tim user
- Danh sach ban be
- Tao loi moi ket ban
- Lay conversation
- Gui message neu dung HTTP endpoint
- Xin presigned upload URL
- Finalize upload
- Goi AI endpoint

Luong ve:

```txt
End User
-> Web App / Mobile App
-> HTTPS REST API
-> Caddy Reverse Proxy
-> API Gateway
-> Backend Service tuong ung
```

Tren diagram, canh tu Web/Mobile den Caddy co the ghi:

```txt
HTTPS REST
```

Canh tu Caddy den API Gateway ghi:

```txt
Reverse proxy REST
```

### 2.2 Socket.IO Realtime

Socket.IO dung cho realtime:

- Tin nhan moi
- Typing
- Online/offline
- Reaction
- Tin nhan bi thu hoi
- AI bot reply
- AI typing
- Notification ban be
- Trang thai call neu co

Luong ve:

```txt
End User
-> Web App / Mobile App
-> Socket.IO over HTTPS / WebSocket
-> Caddy Reverse Proxy
-> API Gateway Socket.IO Server
```

Socket.IO ban dau co the di bang HTTPS polling, sau do upgrade len WebSocket neu duoc.

Tren diagram, canh tu Web/Mobile den Caddy nen ghi:

```txt
HTTPS REST + Socket.IO/WebSocket
```

Canh tu Caddy den API Gateway nen ghi:

```txt
Reverse proxy REST + Socket.IO
```

Quan trong:

```txt
Client khong connect Socket.IO truc tiep vao Chat Service.
Client chi connect Socket.IO vao API Gateway.
API Gateway la noi quan ly socket room, user online va emit realtime event ve client.
```

## 3. API Gateway Den Cac Service

API Gateway la cua vao chung cua backend. API Gateway nhan request tu client va route den service phu hop.

Ve cac moi quan he HTTP:

```txt
API Gateway -> Auth Service
API Gateway -> User Service
API Gateway -> Friend Service
API Gateway -> Chat Service
API Gateway -> Upload Service
API Gateway -> AI Service
```

Y nghia:

```txt
API Gateway -> Auth Service
Dang ky, dang nhap, refresh token, logout, OTP, xac thuc tai khoan.

API Gateway -> User Service
Profile, avatar, search user, thong tin nguoi dung.

API Gateway -> Friend Service
Gui loi moi ket ban, chap nhan, tu choi, danh sach ban be.

API Gateway -> Chat Service
Conversation, message, task, note, reminder, poll.

API Gateway -> Upload Service
Presigned upload, finalize upload, xoa file, xu ly media.

API Gateway -> AI Service
AI chat, moderation, summary, translation, RAG/search.
```

Tren diagram nen ve API Gateway ben trai cac core services, sau do ke cac mui ten HTTP den tung service.

## 4. Socket.IO Va Kafka Realtime

API Gateway khong chi route REST. No con consume Kafka event va emit ve client qua Socket.IO.

Luong tong quat:

```txt
Backend Service
-> Kafka
-> API Gateway
-> Socket.IO/WebSocket
-> Web App / Mobile App
```

Vi du:

```txt
Chat Service -> Kafka -> API Gateway -> Socket.IO -> Client
AI Service -> Kafka -> API Gateway -> Socket.IO -> Client
Friend Service -> Kafka -> API Gateway -> Socket.IO -> Client
```

Tren diagram, nen ve:

```txt
Kafka -> API Gateway
```

Label:

```txt
Consume realtime events
```

Va tu API Gateway ve Web/Mobile:

```txt
Socket.IO realtime
```

## 5. Service-To-Service Bang HTTP

Mot so service goi truc tiep service khac bang HTTP.

Nen ve cac moi quan he nay bang duong lien net, mau khac Kafka.

```txt
Auth Service -> User Service
AI Service -> Chat Service
AI Service -> User Service
```

### 5.1 Auth Service -> User Service

Auth quan ly credential, token, OTP. User quan ly profile.

Khi dang ky hoac dang nhap, Auth can tao hoac lay thong tin user.

```txt
Auth Service -> User Service: create/load user profile
```

### 5.2 AI Service -> Chat Service

AI can doc ngu canh hoi thoai hoac tao phan hoi bot.

```txt
AI Service -> Chat Service: read chat context / save bot reply
```

### 5.3 AI Service -> User Service

AI can thong tin user de ca nhan hoa xu ly.

```txt
AI Service -> User Service: load user profile
```

## 6. Service-To-Service Qua Kafka

Kafka dung cho giao tiep bat dong bo. Service A publish event vao Kafka. Service B consume event khi san sang.

Trong diagram, nen ve Kafka o duoi core services, giong mau:

```txt
Core Services
     |
     | dashed orange lines
     v
Redpanda Kafka
```

Dung mui ten net dut mau cam cho Kafka.

## 7. Quan He Kafka Can Ve

### 7.1 Auth -> Kafka -> Notification

```txt
Auth Service
-> Kafka: publish notification.email
-> Notification Service: consume notification.email
-> SMTP/Gmail: send email
```

Dung cho:

- OTP email
- Welcome email
- Verify account email
- Reset password email neu co

Luong:

```txt
Client dang ky
-> API Gateway
-> Auth Service
-> Kafka notification.email
-> Notification Service
-> SMTP/Gmail
-> User Email
```

### 7.2 Chat -> Kafka -> AI

```txt
Chat Service
-> Kafka: publish chat.message.created
-> AI Service: consume chat.message.created
```

Dung cho:

- AI moderation
- Bot reply
- Summary
- Translation
- Extract task/note/reminder
- Create embedding/RAG data

Luong:

```txt
Client gui message
-> API Gateway
-> Chat Service
-> MongoDB
-> Kafka chat.message.created
-> AI Service
```

### 7.3 AI -> Kafka -> Chat

```txt
AI Service
-> Kafka: publish ai.message.moderated / agent.bot_reply / agent.typing
-> Chat Service: consume AI events
```

Dung cho:

- Luu bot reply vao conversation
- Cap nhat moderation status
- Cap nhat typing cua bot

Luong:

```txt
AI Service xu ly xong
-> Kafka agent.bot_reply
-> Chat Service consume
-> MongoDB luu bot message
```

### 7.4 Chat/AI/Friend/User/Upload -> Kafka -> API Gateway

API Gateway consume realtime events de emit ve client.

```txt
Chat Service -> Kafka -> API Gateway -> Socket.IO -> Client
AI Service -> Kafka -> API Gateway -> Socket.IO -> Client
Friend Service -> Kafka -> API Gateway -> Socket.IO -> Client
User Service -> Kafka -> API Gateway -> Socket.IO -> Client
Upload Service -> Kafka -> API Gateway -> Socket.IO -> Client
```

Dung cho:

- New message
- Message revoked
- Reaction added
- Typing
- AI reply
- Friend request
- Friend accepted
- Avatar/profile update
- Upload completed

### 7.5 Upload -> Kafka -> Chat / API Gateway

```txt
Upload Service
-> Kafka: publish upload.completed / upload.deleted / upload.avatar.updated
-> Chat Service or API Gateway consume
```

Dung cho:

- File da upload xong
- Media message san sang hien thi
- Avatar user thay doi
- File bi xoa

## 8. Database Va Storage Ownership

Nen ve database/storage ben phai core services. Moi service doc/ghi database rieng.

### 8.1 PostgreSQL

```txt
Auth Service -> PostgreSQL
User Service -> PostgreSQL
Friend Service -> PostgreSQL
```

Luu:

- Auth account
- Credential
- Refresh token
- User profile
- Friendship
- Friend request

### 8.2 MongoDB

```txt
Chat Service -> MongoDB
```

Luu:

- Conversation
- Message
- Reaction
- Task
- Note
- Poll
- Reminder

### 8.3 Redis

```txt
Auth Service -> Redis
AI Service -> Redis
```

Dung cho:

- OTP
- Session/cache
- Token blacklist neu co
- AI temporary cache

### 8.4 Qdrant

```txt
AI Service -> Qdrant
```

Dung cho:

- Vector embedding
- Semantic search
- RAG memory

### 8.5 AWS S3

```txt
Upload Service -> AWS S3
```

Dung cho:

- Avatar
- Image
- Video
- Document
- Audio

### 8.6 SMTP/Gmail

```txt
Notification Service -> SMTP/Gmail
```

Dung cho:

- OTP email
- Welcome email
- Reset password email neu co

## 9. Luong Mau De Ve Tren Diagram

### 9.1 Dang ky tai khoan

```txt
Web/Mobile
-> HTTPS REST
-> Caddy
-> API Gateway
-> Auth Service
-> User Service
-> PostgreSQL
-> Kafka notification.email
-> Notification Service
-> SMTP/Gmail
-> User Email
```

### 9.2 Dang nhap

```txt
Web/Mobile
-> HTTPS REST
-> Caddy
-> API Gateway
-> Auth Service
-> PostgreSQL/Redis
-> Return token/cookie
```

### 9.3 Gui tin nhan realtime

```txt
Web/Mobile
-> Socket.IO/WebSocket or HTTPS REST
-> Caddy
-> API Gateway
-> Chat Service
-> MongoDB
-> Kafka chat.message.created
-> API Gateway consume
-> Socket.IO emit
-> Web/Mobile receiver
```

### 9.4 Tin nhan co AI bot

```txt
Chat Service
-> Kafka chat.message.created
-> AI Service
-> AI Service xu ly
-> Kafka agent.bot_reply
-> Chat Service
-> MongoDB
-> Kafka realtime event
-> API Gateway
-> Socket.IO
-> Web/Mobile
```

### 9.5 Upload anh/file

```txt
Web/Mobile
-> HTTPS REST
-> Caddy
-> API Gateway
-> Upload Service
-> AWS S3 presigned URL
-> Web/Mobile upload file directly to S3
-> Web/Mobile finalize upload
-> Upload Service
-> Kafka upload.completed
-> Chat Service/API Gateway
```

## 10. Goi Y Cach Ve Cho Dep

Nen bo tri nhu sau:

```txt
[Clients]        [API Gateway / Edge]        [Core Services]        [Databases]
End User         Caddy                       Auth                   PostgreSQL
Web App          API Gateway                 User                   MongoDB
Mobile App                                   Friend                 Redis
                                             Chat                   Qdrant
                                             Upload                 S3
                                             AI
                                             Notification

                         [Event Platform]
                         Redpanda Kafka

                         [External Services]
                         SMTP/Gmail
```

Quy uoc duong noi:

```txt
Duong den lien mau den:
HTTPS/HTTP request truc tiep

Duong net dut mau cam:
Kafka publish/consume event

Duong mau xam:
Read/write database

Duong mau xanh:
Storage/media upload

Duong mau do/nau:
Email/SMTP
```

Nen ghi label ngan tren duong noi:

```txt
HTTPS REST + Socket.IO
Reverse proxy
Auth APIs
Chat APIs
Publish notification.email
Consume notification.email
Publish chat.message.created
Consume chat.message.created
Publish agent.bot_reply
Consume AI events
Read / Write
Presigned upload
Send email
```

## 11. Doan Mo Ta Ngan De Dua Vao Bao Cao

BinChat su dung Web App va Mobile App lam client. Client giao tiep voi backend qua HTTPS REST API va Socket.IO/WebSocket. Tat ca request deu di qua Caddy Reverse Proxy de xu ly TLS va reverse proxy ve API Gateway. API Gateway la cua vao chung, chiu trach nhiem route REST request den cac microservice nhu Auth, User, Friend, Chat, Upload va AI. Ngoai REST, API Gateway con quan ly Socket.IO connection va emit realtime event ve client.

Giua cac backend service co hai kieu giao tiep. Kieu thu nhat la HTTP truc tiep, dung cho cac tac vu can ket qua ngay, vi du Auth goi User de tao hoac lay profile, AI goi Chat de lay ngu canh hoi thoai va goi User de lay thong tin nguoi dung. Kieu thu hai la Kafka event bat dong bo, dung cho cac tac vu realtime hoac xu ly nen. Vi du Auth publish notification.email vao Kafka, Notification consume event nay de gui email. Chat publish chat.message.created, AI consume de xu ly moderation/bot reply. AI publish agent.bot_reply hoac typing event, Chat va API Gateway consume de luu message va emit realtime ve client.

Moi service so huu du lieu rieng. Auth, User va Friend luu du lieu quan he trong PostgreSQL. Chat luu conversation/message/task/note/poll trong MongoDB. Auth va AI dung Redis cho OTP, session va cache. AI dung Qdrant cho vector/RAG. Upload dung AWS S3 de luu media. Notification dung SMTP/Gmail de gui email.
