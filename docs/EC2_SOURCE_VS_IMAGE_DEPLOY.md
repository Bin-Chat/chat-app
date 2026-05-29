# EC2 Source Code vs Image Deploy

## 1. Vi sao code tren EC2 khong tu cap nhat?

Luon nho 2 thu khac nhau:

```txt
Source code tren EC2 = file trong thu muc ~/chat-app
App dang chay tren EC2 = Docker image/container
```

Hien tai CI/CD backend dang dung cach deploy bang image:

```txt
GitHub Actions build image
-> push image len GHCR
-> EC2 pull image moi
-> docker compose restart container
```

Workflow deploy khong chay `git pull` tren EC2, nen file trong `~/chat-app` co the khong doi. Dieu nay binh thuong.

## 2. Co can cap nhat source code tren EC2 khong?

Thong thuong la khong can.

Khi dung Docker image production, EC2 chi can cac file van hanh:

```txt
.env
.env.images
docker-compose.yml
docker-compose.env-production.yml
docker-compose.prod-images.yml
gateway/*/.env.production
services/*/.env.production
```

Code service that su da nam ben trong image:

```txt
ghcr.io/bin-chat/chat-service:main
ghcr.io/bin-chat/auth-service:main
...
```

Vi vay neu push code moi, cai can cap nhat la image/container, khong phai file source tren EC2.

## 3. Khi nao moi can `git pull` tren EC2?

Chi can `git pull` khi ban sua cac file van hanh o repo cha, vi du:

```txt
docker-compose.yml
docker-compose.env-production.yml
docker-compose.prod-images.yml
.github/workflows/*
docs/*
scripts/*
```

Vi du sua Docker Compose thi tren EC2 chay:

```bash
cd ~/chat-app
git pull
```

Sau do deploy lai:

```bash
sudo docker compose \
  --env-file .env \
  --env-file .env.images \
  -f docker-compose.yml \
  -f docker-compose.env-production.yml \
  -f docker-compose.prod-images.yml \
  up -d
```

## 4. Hai file production compose dung de lam gi?

### docker-compose.env-production.yml

File nay chuyen cau hinh tu local/dev sang production:

```txt
NODE_ENV=production
CORS_ORIGIN=https://binchat.me,https://www.binchat.me,http://localhost:5173
TURN realm=api.binchat.me
```

No cung bat moi service doc file `.env.production` rieng.

### docker-compose.prod-images.yml

File nay chuyen backend tu build source tren EC2 sang pull image GHCR:

```txt
build local tren EC2: tat
image GHCR: bat
```

Vi du:

```yaml
chat-service:
  image: ghcr.io/bin-chat/chat-service:${CHAT_SERVICE_TAG:-main}
  build: null
```

## 5. Quy trinh push code moi nen hieu nhu nay

Neu sua code service:

```txt
Push code service
-> cap nhat submodule trong chat-app neu can
-> GitHub Actions build image
-> Deploy Backend Images to EC2
-> EC2 pull image moi
-> container restart
```

Source trong `~/chat-app/services/chat` tren EC2 co the van cu, nhung app dang chay da moi neu image moi da duoc pull va container restart.

## 6. Cach kiem tra EC2 dang chay image nao

Tren EC2:

```bash
cd ~/chat-app
cat .env.images
sudo docker ps
sudo docker inspect chat-service --format '{{.Config.Image}}'
sudo docker inspect api-gateway --format '{{.Config.Image}}'
```

Kiem tra API:

```bash
curl https://api.binchat.me/api/health
```
