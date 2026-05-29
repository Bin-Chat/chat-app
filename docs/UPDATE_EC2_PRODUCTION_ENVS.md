# Cap Nhat .env.production Tren EC2

File nay huong dan cap nhat EC2 de backend dung cac file `.env.production` rieng cho tung service.

## 1. Cac file da tao

Tren may local da tao cac file:

```txt
gateway/api-gateway/.env.production
services/auth/.env.production
services/user/.env.production
services/friend/.env.production
services/notification/.env.production
services/upload/.env.production
services/chat/.env.production
services/ai/.env.production
docker-compose.env-production.yml
```

Luu y: cac file `.env.production` bi Git ignore de tranh push secret. File `docker-compose.env-production.yml` khong chua secret nen co the commit.

## 2. Dua file len EC2

Cach de nhat: SSH vao EC2 bang VS Code Remote SSH, mo thu muc:

```bash
~/chat-app
```

Sau do tao/copy cac file `.env.production` dung duong dan nhu muc 1.

Neu dung `scp` tu may local, vi du:

```bash
scp gateway/api-gateway/.env.production ubuntu@api.binchat.me:~/chat-app/gateway/api-gateway/.env.production
scp services/auth/.env.production ubuntu@api.binchat.me:~/chat-app/services/auth/.env.production
scp services/user/.env.production ubuntu@api.binchat.me:~/chat-app/services/user/.env.production
scp services/friend/.env.production ubuntu@api.binchat.me:~/chat-app/services/friend/.env.production
scp services/notification/.env.production ubuntu@api.binchat.me:~/chat-app/services/notification/.env.production
scp services/upload/.env.production ubuntu@api.binchat.me:~/chat-app/services/upload/.env.production
scp services/chat/.env.production ubuntu@api.binchat.me:~/chat-app/services/chat/.env.production
scp services/ai/.env.production ubuntu@api.binchat.me:~/chat-app/services/ai/.env.production
scp docker-compose.env-production.yml ubuntu@api.binchat.me:~/chat-app/docker-compose.env-production.yml
```

Neu SSH can key:

```bash
scp -i /path/to/binchat-ec2-key.pem gateway/api-gateway/.env.production ubuntu@api.binchat.me:~/chat-app/gateway/api-gateway/.env.production
```

## 3. Dien secret that tren EC2

Tren EC2:

```bash
cd ~/chat-app
```

Mo tung file va thay cac gia tri:

```txt
CHANGE_ME_COPY_FROM_ROOT_ENV
```

bang gia tri that trong file root:

```bash
nano .env
```

Vi du:

- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `DB_PASSWORD`
- `MAIL_USER`
- `MAIL_PASS`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `OPENAI_API_KEY`

Khong commit cac file `.env.production`.

## 4. Chay lai Docker Compose voi production env

Neu image da build roi:

```bash
cd ~/chat-app
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml up -d --no-build --force-recreate
```

Neu co sua code va can build lai:

```bash
cd ~/chat-app
sudo env COMPOSE_PARALLEL_LIMIT=1 docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml up -d --build
```

## 5. Kiem tra env da vao container

Kiem tra API Gateway:

```bash
sudo docker exec api-gateway printenv CORS_ORIGIN
sudo docker exec api-gateway printenv NODE_ENV
```

Ket qua dung:

```txt
https://binchat.me,https://www.binchat.me,http://localhost:5173
production
```

## 6. Test CORS login

Test origin root domain:

```bash
curl -i -X OPTIONS https://api.binchat.me/api/auth/login \
  -H "Origin: https://binchat.me" \
  -H "Access-Control-Request-Method: POST"
```

Test origin www:

```bash
curl -i -X OPTIONS https://api.binchat.me/api/auth/login \
  -H "Origin: https://www.binchat.me" \
  -H "Access-Control-Request-Method: POST"
```

Phai thay:

```txt
access-control-allow-origin: https://binchat.me
access-control-allow-credentials: true
```

hoac:

```txt
access-control-allow-origin: https://www.binchat.me
access-control-allow-credentials: true
```

## 7. Test health

```bash
curl https://api.binchat.me/api/health
sudo docker ps
```

Neu web van CORS error, xem domain tren thanh dia chi browser. Domain do phai nam trong `CORS_ORIGIN`.
