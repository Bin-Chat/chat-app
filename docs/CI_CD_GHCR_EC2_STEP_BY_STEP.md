# Huong Dan CI/CD Production Bang GHCR + EC2 Cho Nguoi Moi

File nay huong dan tung buoc cach nang cap CI/CD BinChat theo huong chuan hon:

```txt
GitHub Actions build Docker image
-> push image len GHCR
-> EC2 pull image
-> Docker Compose restart service
-> health check
-> neu loi thi rollback tag cu
```

Muc tieu: EC2 khong phai build code nua. EC2 chi tai image da build san ve va chay.

## 1. Luong hoat dong tong quan

### 1.1 Luong hien tai

Hien tai backend dang deploy kieu:

```txt
Ban push code len GitHub
  -> GitHub Actions SSH vao EC2
  -> EC2 git pull source code
  -> EC2 docker compose build
  -> EC2 docker compose up
```

Nghia la EC2 vua la server chay app, vua la may build Docker image.

Van de:

- Build tren EC2 lau.
- EC2 it RAM nen de loi.
- NPM download tren EC2 hay bi `ECONNRESET`.
- Rollback phien ban cu kho.
- Neu build fail, server production bi anh huong.

### 1.2 Luong moi de xuat

Luong moi:

```txt
Developer push code
  -> GitHub Actions chay test/build
  -> GitHub Actions build Docker image
  -> GitHub Actions push image len GHCR
  -> GitHub Actions SSH vao EC2
  -> EC2 docker compose pull image moi
  -> EC2 docker compose up -d service can deploy
  -> EC2 health check
```

Vai tro tung phan:

```txt
GitHub Actions: may build
GHCR: kho chua image Docker
EC2: may chay app production
Docker Compose: quan ly container tren EC2
```

### 1.3 Vi sao can GHCR?

GHCR la GitHub Container Registry. No la kho chua Docker image cua GitHub.

Thay vi EC2 tu build:

```txt
EC2 lay source code -> build image
```

Ta lam:

```txt
GitHub Actions build image -> push len GHCR -> EC2 pull image
```

Ket qua:

- Deploy nhanh hon.
- EC2 nhe hon.
- Loi build xay ra tren GitHub Actions, khong xay ra tren EC2.
- Co image tag de rollback.

## 2. Kien truc CI/CD moi

### 2.1 Cac repo trong BinChat

Root repo:

```txt
chat-app
```

Repo con/submodule:

```txt
apps/web
apps/mobile
gateway
services/auth
services/user
services/friend
services/notification
services/upload
services/chat
services/ai
```

Backend production gom cac service Docker:

```txt
api-gateway
auth-service
user-service
friend-service
notification-service
upload-service
chat-service
ai-service
```

### 2.2 Image production tren GHCR

Nen dat image nhu sau:

```txt
ghcr.io/<github-owner>/api-gateway
ghcr.io/<github-owner>/auth-service
ghcr.io/<github-owner>/user-service
ghcr.io/<github-owner>/friend-service
ghcr.io/<github-owner>/notification-service
ghcr.io/<github-owner>/upload-service
ghcr.io/<github-owner>/chat-service
ghcr.io/<github-owner>/ai-service
```

Vi du neu org la `bin-chat`:

```txt
ghcr.io/bin-chat/api-gateway:main
ghcr.io/bin-chat/auth-service:main
ghcr.io/bin-chat/chat-service:main
```

### 2.3 Image tag nen dung

Moi image nen co it nhat 2 tag:

```txt
main
<git-sha>
```

Vi du:

```txt
ghcr.io/bin-chat/auth-service:main
ghcr.io/bin-chat/auth-service:a1b2c3d
```

Y nghia:

- `main`: tag moi nhat cua branch main.
- `a1b2c3d`: tag co dinh theo commit, dung de rollback.

Production chuan nen deploy theo commit tag. De don gian luc dau co the deploy `main`.

## 3. Cac buoc se lam

Ta se lam theo thu tu:

```txt
1. Chuan bi GHCR permissions
2. Tao docker-compose.prod-images.yml
3. Tao .env.images tren EC2
4. Tao workflow build-push image
5. Tao workflow deploy EC2 pull image
6. Login GHCR tren EC2
7. Chay deploy lan dau
8. Test health
9. Rollback khi can
```

## 4. Buoc 1 - Chuan bi GitHub Packages/GHCR

### 4.1 GHCR nam o dau?

GHCR nam trong GitHub:

```txt
GitHub repo/org -> Packages
```

Khi workflow push image thanh cong, GitHub se hien package/image trong tab Packages.

### 4.2 Can token nao?

Neu workflow build image trong cung GitHub repo, co the dung:

```txt
GITHUB_TOKEN
```

Token nay GitHub tu cap cho workflow. Khong can tao secret rieng cho build/push image trong cung repo.

Trong workflow can set permission:

```yaml
permissions:
  contents: read
  packages: write
```

Y nghia:

- `contents: read`: workflow duoc doc source code.
- `packages: write`: workflow duoc push image len GHCR.

## 5. Buoc 2 - Tao Docker Compose dung image

### 5.1 Vi sao can file compose moi?

File `docker-compose.yml` hien tai dung:

```yaml
build:
  context: ./services/auth
```

Nghia la Docker Compose se build image tu source code.

Luong production moi can dung:

```yaml
image: ghcr.io/bin-chat/auth-service:${AUTH_SERVICE_TAG}
```

Nghia la Docker Compose se pull image co san tu GHCR.

### 5.2 Tao file `docker-compose.prod-images.yml`

Tao file o root repo:

```txt
docker-compose.prod-images.yml
```

Noi dung mau:

```yaml
services:
  api-gateway:
    image: ghcr.io/bin-chat/api-gateway:${API_GATEWAY_TAG:-main}
    build: null

  auth-service:
    image: ghcr.io/bin-chat/auth-service:${AUTH_SERVICE_TAG:-main}
    build: null

  user-service:
    image: ghcr.io/bin-chat/user-service:${USER_SERVICE_TAG:-main}
    build: null

  friend-service:
    image: ghcr.io/bin-chat/friend-service:${FRIEND_SERVICE_TAG:-main}
    build: null

  notification-service:
    image: ghcr.io/bin-chat/notification-service:${NOTIFICATION_SERVICE_TAG:-main}
    build: null

  upload-service:
    image: ghcr.io/bin-chat/upload-service:${UPLOAD_SERVICE_TAG:-main}
    build: null

  chat-service:
    image: ghcr.io/bin-chat/chat-service:${CHAT_SERVICE_TAG:-main}
    build: null

  ai-service:
    image: ghcr.io/bin-chat/ai-service:${AI_SERVICE_TAG:-main}
    build: null
```

Giai thich:

- `image`: ten image tren GHCR.
- `${AUTH_SERVICE_TAG:-main}`: neu khong co tag rieng thi dung `main`.
- `build: null`: vo hieu hoa `build` tu file `docker-compose.yml` goc.

Luu y: thay `bin-chat` bang owner/org GitHub that cua ban neu khac.

## 6. Buoc 3 - Tao `.env.images` tren EC2

### 6.1 File nay de lam gi?

`.env.images` luu tag image dang chay tren production.

Vi du:

```env
API_GATEWAY_TAG=main
AUTH_SERVICE_TAG=main
USER_SERVICE_TAG=main
FRIEND_SERVICE_TAG=main
NOTIFICATION_SERVICE_TAG=main
UPLOAD_SERVICE_TAG=main
CHAT_SERVICE_TAG=main
AI_SERVICE_TAG=main
```

Sau nay khi deploy commit cu the:

```env
AUTH_SERVICE_TAG=a1b2c3d
```

### 6.2 Tao tren EC2

SSH vao EC2:

```bash
ssh ubuntu@api.binchat.me
cd ~/chat-app
nano .env.images
```

Dan:

```env
API_GATEWAY_TAG=main
AUTH_SERVICE_TAG=main
USER_SERVICE_TAG=main
FRIEND_SERVICE_TAG=main
NOTIFICATION_SERVICE_TAG=main
UPLOAD_SERVICE_TAG=main
CHAT_SERVICE_TAG=main
AI_SERVICE_TAG=main
```

Khong commit `.env.images` neu ban muon quan ly tag rieng tren server.

## 7. Buoc 4 - Tao workflow build va push image

### 7.1 File workflow build all backend images

Tao:

```txt
.github/workflows/build-push-backend-images.yml
```

Noi dung:

```yaml
name: Build and Push Backend Images

on:
  workflow_dispatch:
    inputs:
      service:
        description: "Service to build"
        required: true
        default: all
        type: choice
        options:
          - all
          - api-gateway
          - auth-service
          - user-service
          - friend-service
          - notification-service
          - upload-service
          - chat-service
          - ai-service
  push:
    branches:
      - main
    paths:
      - "gateway/**"
      - "services/**"
      - ".github/workflows/build-push-backend-images.yml"

permissions:
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE_OWNER: bin-chat

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
          - service: api-gateway
            context: gateway/api-gateway
            image: api-gateway
          - service: auth-service
            context: services/auth
            image: auth-service
          - service: user-service
            context: services/user
            image: user-service
          - service: friend-service
            context: services/friend
            image: friend-service
          - service: notification-service
            context: services/notification
            image: notification-service
          - service: upload-service
            context: services/upload
            image: upload-service
          - service: chat-service
            context: services/chat
            image: chat-service
          - service: ai-service
            context: services/ai
            image: ai-service

    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Decide whether to build this service
        id: decide
        run: |
          selected="${{ github.event.inputs.service || 'all' }}"
          if [ "$selected" = "all" ] || [ "$selected" = "${{ matrix.service }}" ]; then
            echo "build=true" >> "$GITHUB_OUTPUT"
          else
            echo "build=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Set up Docker Buildx
        if: steps.decide.outputs.build == 'true'
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        if: steps.decide.outputs.build == 'true'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        if: steps.decide.outputs.build == 'true'
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_OWNER }}/${{ matrix.image }}
          tags: |
            type=raw,value=main
            type=sha,format=short

      - name: Build and push
        if: steps.decide.outputs.build == 'true'
        uses: docker/build-push-action@v6
        with:
          context: ./${{ matrix.context }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha,scope=${{ matrix.service }}
          cache-to: type=gha,mode=max,scope=${{ matrix.service }}
```

### 7.2 Giai thich workflow

`workflow_dispatch`:

- Cho phep bam `Run workflow` thu cong.
- Co the chon build tat ca hoac 1 service.

`permissions`:

- Cho workflow quyen push image len GHCR.

`REGISTRY`:

- Dung `ghcr.io`.

`IMAGE_OWNER`:

- Owner/org tren GitHub. Can sua `bin-chat` thanh owner that neu khac.

`matrix`:

- Dinh nghia 8 service backend.
- Moi service co context Docker rieng.

`docker/metadata-action`:

- Tu tao tag image.
- Co tag `main`.
- Co tag commit SHA ngan.

`docker/build-push-action`:

- Build Docker image.
- Push len GHCR.
- Dung cache GitHub Actions de lan sau build nhanh hon.

## 8. Buoc 5 - Login GHCR tren EC2

### 8.1 Vi sao EC2 can login?

Neu GHCR image private, EC2 phai login moi pull duoc.

### 8.2 Tao token

Vao GitHub:

```txt
Settings -> Developer settings -> Personal access tokens
```

Tao token co quyen:

```txt
read:packages
```

Neu image nam trong org, dam bao token co access org do.

### 8.3 Login tren EC2

SSH vao EC2:

```bash
ssh ubuntu@api.binchat.me
```

Login:

```bash
echo "<GHCR_TOKEN>" | sudo docker login ghcr.io -u <github-username> --password-stdin
```

Kiem tra:

```bash
sudo docker pull ghcr.io/bin-chat/api-gateway:main
```

Neu pull duoc la OK.

## 9. Buoc 6 - Deploy bang image tren EC2

### 9.1 Lenh deploy tay

Tren EC2:

```bash
cd ~/chat-app
sudo docker compose \
  --env-file .env \
  --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  pull
```

Sau do:

```bash
sudo docker compose \
  --env-file .env \
  --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  up -d --remove-orphans
```

Giai thich:

- `.env`: secret production.
- `.env.images`: tag image.
- `docker-compose.yml`: khai bao service, network, volumes.
- `docker-compose.env-production.yml`: override env production.
- `docker-compose.prod-images.yml`: override build thanh image tu GHCR.

### 9.2 Deploy 1 service

Vi du deploy auth service:

```bash
sudo docker compose \
  --env-file .env \
  --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  pull auth-service
```

```bash
sudo docker compose \
  --env-file .env \
  --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  up -d auth-service api-gateway
```

Vi sao restart them `api-gateway`?

- Gateway goi qua service noi bo.
- Neu service thay doi contract/API, restart gateway giup tranh stale connection.

## 10. Buoc 7 - Tao workflow deploy EC2 pull image

Tao:

```txt
.github/workflows/deploy-backend-images-ec2.yml
```

Noi dung:

```yaml
name: Deploy Backend Images to EC2

on:
  workflow_dispatch:
    inputs:
      service:
        description: "Service to deploy"
        required: true
        default: all
        type: choice
        options:
          - all
          - api-gateway
          - auth-service
          - user-service
          - friend-service
          - notification-service
          - upload-service
          - chat-service
          - ai-service
      tag:
        description: "Image tag to deploy, for example main or a short sha"
        required: true
        default: main

concurrency:
  group: deploy-backend-images-production
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy by SSH
        uses: appleboy/ssh-action@v1.2.0
        env:
          SERVICE: ${{ github.event.inputs.service }}
          TAG: ${{ github.event.inputs.tag }}
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          port: ${{ secrets.EC2_PORT || 22 }}
          envs: SERVICE,TAG
          script_stop: true
          command_timeout: 20m
          script: |
            set -Eeuo pipefail
            cd ~/chat-app

            COMPOSE="-f docker-compose.yml -f docker-compose.env-production.yml -f docker-compose.prod-images.yml"

            cp .env.images .env.images.previous || true

            set_tag() {
              key="$1"
              tag="$2"
              if grep -q "^${key}=" .env.images; then
                sed -i "s/^${key}=.*/${key}=${tag}/" .env.images
              else
                echo "${key}=${tag}" >> .env.images
              fi
            }

            if [ "$SERVICE" = "all" ]; then
              set_tag API_GATEWAY_TAG "$TAG"
              set_tag AUTH_SERVICE_TAG "$TAG"
              set_tag USER_SERVICE_TAG "$TAG"
              set_tag FRIEND_SERVICE_TAG "$TAG"
              set_tag NOTIFICATION_SERVICE_TAG "$TAG"
              set_tag UPLOAD_SERVICE_TAG "$TAG"
              set_tag CHAT_SERVICE_TAG "$TAG"
              set_tag AI_SERVICE_TAG "$TAG"
              target_services=""
            else
              case "$SERVICE" in
                api-gateway) set_tag API_GATEWAY_TAG "$TAG" ;;
                auth-service) set_tag AUTH_SERVICE_TAG "$TAG" ;;
                user-service) set_tag USER_SERVICE_TAG "$TAG" ;;
                friend-service) set_tag FRIEND_SERVICE_TAG "$TAG" ;;
                notification-service) set_tag NOTIFICATION_SERVICE_TAG "$TAG" ;;
                upload-service) set_tag UPLOAD_SERVICE_TAG "$TAG" ;;
                chat-service) set_tag CHAT_SERVICE_TAG "$TAG" ;;
                ai-service) set_tag AI_SERVICE_TAG "$TAG" ;;
                *) echo "Unknown service: $SERVICE"; exit 1 ;;
              esac
              target_services="$SERVICE api-gateway"
            fi

            sudo docker compose --env-file .env --env-file .env.images $COMPOSE pull $target_services
            sudo docker compose --env-file .env --env-file .env.images $COMPOSE up -d --remove-orphans $target_services

            for i in $(seq 1 30); do
              if curl -fsS http://localhost:3000/api/health; then
                echo
                exit 0
              fi
              sleep 5
            done

            echo "Health check failed. Rolling back .env.images"
            cp .env.images.previous .env.images
            sudo docker compose --env-file .env --env-file .env.images $COMPOSE pull $target_services
            sudo docker compose --env-file .env --env-file .env.images $COMPOSE up -d --remove-orphans $target_services
            exit 1
```

### 10.1 Giai thich workflow deploy

Input `service`:

- Chon service can deploy.
- `all` nghia la deploy tat ca.

Input `tag`:

- Chon image tag can deploy.
- Co the la `main`.
- Co the la commit SHA ngan.

`cp .env.images .env.images.previous`:

- Luu lai tag cu de rollback.

`set_tag`:

- Sua tag image trong `.env.images`.

`docker compose pull`:

- Tai image moi tu GHCR.

`docker compose up -d`:

- Restart container bang image moi.

Health check fail:

- Copy lai `.env.images.previous`.
- Pull image cu.
- Up lai service cu.

## 11. Buoc 8 - Chay lan dau

### 11.1 Build image len GHCR

Vao GitHub Actions:

```txt
Build and Push Backend Images
```

Chon:

```txt
service: all
```

Chay workflow.

Sau khi xong, vao GitHub Packages kiem tra image da co chua.

### 11.2 Login GHCR tren EC2

Tren EC2:

```bash
echo "<GHCR_TOKEN>" | sudo docker login ghcr.io -u <github-username> --password-stdin
```

### 11.3 Deploy all

Vao GitHub Actions:

```txt
Deploy Backend Images to EC2
```

Chon:

```txt
service: all
tag: main
```

Chay workflow.

### 11.4 Test

```bash
curl https://api.binchat.me/api/health
```

## 12. Buoc 9 - Deploy 1 service sau nay

Vi du sua `auth-service`.

1. Push code auth.
2. Chay workflow build:

```txt
Build and Push Backend Images
service: auth-service
```

3. Lay tag commit SHA tu log workflow hoac GitHub Packages.
4. Chay workflow deploy:

```txt
Deploy Backend Images to EC2
service: auth-service
tag: <sha>
```

## 13. Buoc 10 - Rollback

### 13.1 Rollback tu workflow

Chay deploy lai voi tag cu.

Vi du:

```txt
service: auth-service
tag: old-sha
```

### 13.2 Rollback tren EC2

```bash
cd ~/chat-app
cp .env.images.previous .env.images
sudo docker compose --env-file .env --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  pull
sudo docker compose --env-file .env --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  up -d
```

## 14. Buoc 11 - Web CI/CD

Web nen dung Vercel.

Luong:

```txt
Push web
  -> GitHub Actions npm run build
  -> Vercel build
  -> Vercel deploy production
```

Secrets:

```txt
VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
```

Vercel env:

```env
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

Neu da link Vercel truc tiep voi repo web, co the de Vercel auto deploy, khong can GitHub Actions deploy web.

## 15. Buoc 12 - Database migration

CI/CD production khong nen chi dua vao `synchronize=true`.

Nen co migration rieng:

```txt
auth-service migrations
user-service migrations
friend-service migrations
```

Luong chuan:

```txt
backup DB
run migration
deploy image
health check
```

Voi demo hien tai co the chua lam migration ngay, nhung production that nen co.

## 16. Buoc 13 - Monitoring va backup

Nen co toi thieu:

```txt
AWS Budget alert
UptimeRobot ping https://api.binchat.me/api/health
backup Postgres hang ngay
backup Mongo hang ngay
docker image prune dinh ky
disk usage alert
```

Backup Postgres:

```bash
docker exec chat-postgres pg_dumpall -U chatapp > ~/backups/postgres-$(date +%F).sql
```

Backup Mongo:

```bash
docker exec chat-mongo mongodump --archive=/tmp/mongo.archive
docker cp chat-mongo:/tmp/mongo.archive ~/backups/mongo-$(date +%F).archive
```

## 17. Tong ket nen lam theo giai doan

### Giai doan 1

Dang co:

```txt
EC2 build image
Docker Compose up
```

### Giai doan 2

Nen lam tiep:

```txt
GHCR
GitHub Actions build image
EC2 pull image
.env.images
rollback bang tag
```

### Giai doan 3

Sau nay production hon:

```txt
ECR
RDS
Mongo Atlas hoac DocumentDB
ECS
CloudFront
monitoring/logging day du
```

## 18. Checklist hoan thanh

```txt
[ ] Tao docker-compose.prod-images.yml
[ ] Tao .env.images tren EC2
[ ] Tao workflow build-push-backend-images.yml
[ ] Tao workflow deploy-backend-images-ec2.yml
[ ] Login GHCR tren EC2
[ ] Build all images len GHCR
[ ] Deploy all images lan dau
[ ] Test https://api.binchat.me/api/health
[ ] Test login web
[ ] Test upload image S3
[ ] Test rollback 1 service
```

