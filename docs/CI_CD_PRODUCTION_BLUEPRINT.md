# CI/CD Production Blueprint Cho BinChat

File nay mo ta luong CI/CD chuan hon luong hien tai. Muc tieu la deploy nhanh, it loi tren EC2, rollback de, va phu hop khi project co nhieu service/nhieu repo.

## 1. Luong hien tai dang dung

Hien tai:

```txt
GitHub Actions
  -> SSH vao EC2
  -> git pull source code
  -> docker compose build tren EC2
  -> docker compose up
```

Uu diem:

- De lam.
- It ton tien.
- Khong can registry.

Nhuoc diem:

- EC2 phai build image, rat cham.
- EC2 yeu de bi loi npm/network.
- Rollback kho hon.
- Moi lan deploy co nguy co lam server bi nang.

## 2. Luong production nen huong toi

Luong xịn hon:

```txt
Developer push code
  -> GitHub Actions test/build
  -> GitHub Actions build Docker image
  -> Push image len Registry
  -> EC2 pull image moi
  -> docker compose up -d
  -> health check
  -> neu fail thi rollback image cu
```

EC2 luc nay khong build nua. EC2 chi:

```txt
docker compose pull
docker compose up -d
```

## 3. Thanh phan can co

### 3.1 Source repositories

Repo hien tai co nhieu repo con:

```txt
chat-app                  root orchestration repo
chat-app-ui-web           web repo/submodule
chat-app-service-auth
chat-app-service-user
chat-app-service-friend
chat-app-service-chat
chat-app-service-upload
chat-app-service-notification
chat-app-service-ai
chat-app-gateway
```

Root repo van nen giu vai tro dieu phoi:

```txt
docker-compose.prod-images.yml
deployment docs
infra scripts
workflow deploy to EC2
```

### 3.2 Container Registry

Registry la kho chua Docker image.

Co 2 lua chon:

```txt
GHCR = GitHub Container Registry
ECR  = AWS Elastic Container Registry
```

Khuyen nghi cho BinChat:

```txt
Giai doan tiep theo: GHCR
Production AWS nghiem tuc sau nay: ECR
```

Ly do chon GHCR truoc:

- Code nam tren GitHub.
- Setup nhanh hon ECR.
- GitHub Actions push image de.
- EC2 co the login GHCR bang token.

## 4. Image naming chuan

Dung image theo service:

```txt
ghcr.io/bin-chat/api-gateway
ghcr.io/bin-chat/auth-service
ghcr.io/bin-chat/user-service
ghcr.io/bin-chat/friend-service
ghcr.io/bin-chat/notification-service
ghcr.io/bin-chat/upload-service
ghcr.io/bin-chat/chat-service
ghcr.io/bin-chat/ai-service
```

Moi image nen co nhieu tag:

```txt
ghcr.io/bin-chat/auth-service:latest
ghcr.io/bin-chat/auth-service:main
ghcr.io/bin-chat/auth-service:<git-sha>
```

Vi du:

```txt
ghcr.io/bin-chat/auth-service:7a8f2c1
```

Deploy production nen uu tien tag commit SHA, khong nen chi dua vao `latest`.

## 5. Luong backend service repo rieng

Moi service repo co workflow rieng:

```txt
Push main vao chat-app-service-auth
  -> npm ci
  -> npm run build
  -> docker build
  -> docker push ghcr.io/bin-chat/auth-service:<sha>
  -> repository_dispatch ve root repo
```

Root repo nhan event:

```txt
repository_dispatch: backend-image-ready
```

Payload vi du:

```json
{
  "service": "auth-service",
  "image": "ghcr.io/bin-chat/auth-service:7a8f2c1"
}
```

Root repo deploy:

```txt
SSH vao EC2
  -> update image tag trong .env.deploy hoac compose override
  -> docker compose pull auth-service
  -> docker compose up -d auth-service api-gateway
  -> health check
```

## 6. Docker Compose production dung image

Thay vi:

```yaml
auth-service:
  build:
    context: ./services/auth
```

Dung:

```yaml
auth-service:
  image: ghcr.io/bin-chat/auth-service:${AUTH_SERVICE_TAG}
```

Tao file rieng:

```txt
docker-compose.prod-images.yml
```

Vi du:

```yaml
services:
  api-gateway:
    image: ghcr.io/bin-chat/api-gateway:${API_GATEWAY_TAG}

  auth-service:
    image: ghcr.io/bin-chat/auth-service:${AUTH_SERVICE_TAG}

  user-service:
    image: ghcr.io/bin-chat/user-service:${USER_SERVICE_TAG}

  friend-service:
    image: ghcr.io/bin-chat/friend-service:${FRIEND_SERVICE_TAG}

  upload-service:
    image: ghcr.io/bin-chat/upload-service:${UPLOAD_SERVICE_TAG}

  chat-service:
    image: ghcr.io/bin-chat/chat-service:${CHAT_SERVICE_TAG}

  notification-service:
    image: ghcr.io/bin-chat/notification-service:${NOTIFICATION_SERVICE_TAG}

  ai-service:
    image: ghcr.io/bin-chat/ai-service:${AI_SERVICE_TAG}
```

Tren EC2 co file:

```txt
.env.images
```

Noi dung:

```env
API_GATEWAY_TAG=7a8f2c1
AUTH_SERVICE_TAG=8b92ad0
USER_SERVICE_TAG=1cc89aa
FRIEND_SERVICE_TAG=39eaa10
UPLOAD_SERVICE_TAG=6fabc11
CHAT_SERVICE_TAG=ee30bd1
NOTIFICATION_SERVICE_TAG=192aa81
AI_SERVICE_TAG=abc9123
```

Deploy chi can doi tag service can deploy.

## 7. Rollback chuan

Truoc moi deploy, luu tag hien tai:

```bash
cp .env.images .env.images.previous
```

Neu deploy fail:

```bash
cp .env.images.previous .env.images
docker compose --env-file .env --env-file .env.images -f docker-compose.yml -f docker-compose.prod-images.yml pull
docker compose --env-file .env --env-file .env.images -f docker-compose.yml -f docker-compose.prod-images.yml up -d
```

Neu chi rollback 1 service:

```bash
docker compose --env-file .env --env-file .env.images -f docker-compose.yml -f docker-compose.prod-images.yml up -d auth-service
```

## 8. Health check va smoke test

Sau deploy backend:

```bash
curl -fsS https://api.binchat.me/api/health
```

Test CORS:

```bash
curl -i -X OPTIONS https://api.binchat.me/api/auth/login \
  -H "Origin: https://binchat.me" \
  -H "Access-Control-Request-Method: POST"
```

Test login endpoint neu co test user:

```bash
curl -i https://api.binchat.me/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"demo-password"}'
```

## 9. Web production flow

Web nen de Vercel build/deploy:

```txt
Push apps/web repo
  -> Vercel build
  -> Vercel deploy preview
  -> promote production
```

Hoac GitHub Actions:

```txt
GitHub Actions
  -> npm ci
  -> npm run build
  -> vercel build --prod
  -> vercel deploy --prebuilt --prod
```

Vercel env:

```env
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

## 10. Mobile flow

Mobile khong deploy moi lan backend thay doi.

Flow:

```txt
Push apps/mobile
  -> expo-doctor
  -> eas build --platform android --profile preview
```

Production app nen dung:

```env
EXPO_PUBLIC_API_URL=https://api.binchat.me
EXPO_PUBLIC_SOCKET_URL=https://api.binchat.me
```

## 11. Secrets can co neu dung GHCR

Trong service repo:

```txt
GHCR_TOKEN
ROOT_REPO_DISPATCH_TOKEN
```

`GHCR_TOKEN` can quyen push package/image.

Trong EC2:

```bash
echo "<GHCR_TOKEN>" | docker login ghcr.io -u <github-username> --password-stdin
```

Neu package public thi pull co the khong can login. Neu private thi EC2 bat buoc login.

## 12. Secrets can co neu dung ECR

Trong GitHub Actions:

```txt
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION=ap-southeast-1
AWS_ACCOUNT_ID
```

Tren EC2 tot nhat gan IAM Role co quyen:

```txt
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:GetDownloadUrlForLayer
ecr:BatchGetImage
```

ECR hop hon neu sau nay chuyen sang:

```txt
ECS
EKS
AWS App Runner
```

## 13. Chien luoc migration database

CI/CD xịn khong nen de TypeORM `synchronize=true` trong production.

Nen co lenh migration rieng:

```txt
npm run migration:run
```

Deploy production nen co buoc:

```txt
backup DB
run migration
deploy service
health check
```

Hien tai code dang tao schema nhanh khi `NODE_ENV=development`. Production lau dai nen viet migration cho:

```txt
auth-service
user-service
friend-service
```

## 14. Observability can them

Toi thieu nen co:

```txt
docker logs
healthcheck
UptimeRobot/Better Stack ping https://api.binchat.me/api/health
backup DB theo lich
disk usage alert
AWS Budget alert
```

Sau nay co the them:

```txt
Prometheus
Grafana
Loki
Sentry
OpenTelemetry
```

## 15. Giai doan trien khai de xuat

### Phase 1: Dang co

```txt
SSH vao EC2
EC2 build image
docker compose up
```

Dung cho demo.

### Phase 2: Nen lam tiep

```txt
GHCR
GitHub Actions build image
EC2 pull image
.env.images quan ly tag
rollback tag
```

Day la buoc dang tien nhat cho BinChat.

### Phase 3: Production AWS hon

```txt
ECR
EC2 IAM Role
RDS Postgres
DocumentDB/Mongo Atlas
S3 + CloudFront
ECS thay EC2 Docker Compose
```

## 16. Ket luan

Hien tai chua bat buoc dung registry. Nhung neu muon CI/CD chuan hon, nen nang theo thu tu:

```txt
1. GHCR
2. docker-compose.prod-images.yml
3. .env.images tag theo commit
4. EC2 docker compose pull
5. rollback bang tag cu
6. database migration rieng
7. monitoring/backup
```

Day la luong can bang nhat giua "xịn", de hieu, va khong doi ha tang qua lon.

