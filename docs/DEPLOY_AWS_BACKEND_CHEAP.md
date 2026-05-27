# Deploy Backend Len AWS EC2 Gia Re

File nay huong dan tung buoc deploy backend BinChat len AWS EC2 theo cach de hieu va tiet kiem chi phi. Phuong an la: 1 EC2 instance chay Docker Compose, web deploy rieng len Vercel, upload file dung S3.

## 1. Muc tieu kien truc

Tren EC2 se chay:

- API Gateway: `3000`.
- Auth service: `3010`.
- User service: `3020`.
- Friend service: `3025`.
- Notification service: `3030`.
- Upload service: `3035`.
- Chat service: `3040`.
- AI service: `3050`.
- PostgreSQL.
- MongoDB.
- Redis.
- Redpanda.
- Qdrant.
- coturn.
- Caddy reverse proxy HTTPS.

Ben ngoai chi nen truy cap:

- `443`: HTTPS API Gateway.
- `80`: HTTP de Caddy cap Let's Encrypt certificate.
- `22`: SSH, gioi han IP cua ban.
- `3478` va `49152-49200/udp`: TURN neu can call audio/video.

Khong public database va service noi bo.

## 2. Chon EC2 sao cho it ton tien

Repo nay co nhieu container, nen `t2.micro`/`t3.micro` thuong qua yeu neu chay day du AI, Redpanda, Qdrant, Mongo, Postgres.

Khuyen nghi:

| Nhu cau | Instance | RAM | Ghi chu |
|---|---|---:|---|
| Demo rat tiet kiem, co swap | `t3.small` | 2GB | De dung nhat vi x86_64, co the duoi tai nang |
| Re hon neu chap nhan ARM | `t4g.small` | 2GB | Thuong re hon, nhung can dam bao image/package chay ARM OK |
| On dinh hon | `t3.medium` | 4GB | Khuyen nghi neu demo cho nhieu nguoi |
| Production nghiem tuc | `t3.medium` tro len | 4GB+ | Sau nay nen tach DB ra managed service |

De it loi cho nguoi moi, chon `t3.small` hoac `t3.medium` voi Ubuntu x86_64.

Ghi chu ve chi phi:

- EC2 On-Demand tinh tien theo thoi gian instance chay.
- EBS tinh tien theo dung luong provisioned, nen dung `gp3` 30GB luc dau.
- Public IPv4/Elastic IP co tinh phi, ke ca dang gan vao resource. Neu dung domain production, Elastic IP van nen dung de IP khong doi.
- Data transfer out ra Internet co the tinh phi khi vuot muc free/allowance.
- OpenAI API tinh tien rieng theo usage.

## 3. Tao AWS Budget truoc

Lam buoc nay dau tien de tranh bat ngo tien.

1. Dang nhap AWS Console.
2. Tim `AWS Budgets`.
3. Chon `Create budget`.
4. Chon `Cost budget`.
5. Budget name: `binchat-ec2-monthly-budget`.
6. Period: `Monthly`.
7. Budget amount:
   - Demo: `15 USD`.
   - Neu dung `t3.medium`: `35 USD` tro len.
8. Tao alert:
   - 50% actual.
   - 80% actual.
   - 100% forecasted.
9. Nhap email cua ban.
10. Bam `Create budget`.

## 4. Tao EC2 instance

### 4.1 Vao EC2 Launch Instance

1. Vao AWS Console.
2. Tim `EC2`.
3. Chon Region gan Viet Nam, vi du `Asia Pacific (Singapore) ap-southeast-1`.
4. Chon `Instances`.
5. Bam `Launch instances`.

### 4.2 Name and tags

Name:

```txt
binchat-backend-prod
```

### 4.3 Application and OS Images

Chon:

```txt
Ubuntu Server 24.04 LTS (HVM), SSD Volume Type
```

Neu khong co 24.04, chon:

```txt
Ubuntu Server 22.04 LTS
```

Architecture:

- Neu chon `t3.small`/`t3.medium`: `64-bit (x86)`.
- Neu chon `t4g.small`: `64-bit (Arm)`.

### 4.4 Instance type

Chon mot trong:

```txt
t3.small
```

Hoac on dinh hon:

```txt
t3.medium
```

Neu dung T3/T4g burstable, trong Advanced details nen de y `Credit specification`.

- De tiet kiem va tranh phi CPU credit bat ngo: chon `standard` neu AWS console cho chon.
- Neu de `unlimited`, khi CPU vuot credit co the phat sinh phi CPU credit.

### 4.5 Key pair

1. Chon `Create new key pair`.
2. Name: `binchat-ec2-key`.
3. Key pair type: `ED25519` neu co, hoac `RSA`.
4. Private key file format:
   - `.pem` neu dung terminal/Git Bash/WSL/macOS/Linux.
   - `.ppk` neu dung PuTTY.
5. Bam `Create key pair`.
6. Tai file ve va cat giu can than. Ai co private key nay co the SSH vao server.

Tren Linux/macOS/WSL/Git Bash:

```bash
chmod 400 ~/Downloads/binchat-ec2-key.pem
```

### 4.6 Network settings

Chon:

- VPC: default VPC.
- Subnet: default subnet trong region da chon.
- Auto-assign public IP: `Enable`.

Security Group:

Tao security group moi:

```txt
binchat-backend-sg
```

Inbound rules:

| Type | Protocol | Port | Source | Ghi chu |
|---|---|---:|---|---|
| SSH | TCP | 22 | `My IP` | Chi IP cua ban |
| HTTP | TCP | 80 | `0.0.0.0/0` | Cho Let's Encrypt |
| HTTPS | TCP | 443 | `0.0.0.0/0` | API public |
| Custom TCP | TCP | 3478 | `0.0.0.0/0` | TURN neu dung call |
| Custom UDP | UDP | 3478 | `0.0.0.0/0` | TURN neu dung call |
| Custom UDP | UDP | 49152-49200 | `0.0.0.0/0` | TURN relay |

Neu chua dung call audio/video, co the tam khong mo `3478` va `49152-49200`.

Khong them cac port:

- `3000`.
- `3010`.
- `3020`.
- `3025`.
- `3030`.
- `3035`.
- `3040`.
- `3050`.
- `5432`.
- `27017`.
- `6379`.
- `19092`.
- `6333`.

Viec reverse proxy qua Caddy se lam Internet chi can port `443`.

### 4.7 Storage

Chon:

```txt
30 GiB gp3
```

Ly do:

- Docker images + volumes DB se ton dung luong.
- 8GB mac dinh qua it.
- `gp3` co baseline performance tot va de doan chi phi.

Neu app co upload/file/cache nhieu, tang len `50GB`.

### 4.8 Launch

Bam `Launch instance`.

Doi 1-3 phut den khi:

- Instance state: `Running`.
- Status checks: `2/2 checks passed`.

## 5. Gan Elastic IP

Neu chi test nhanh, co the dung public IP tu dong. Nhung khi stop/start EC2, IP co the doi. Production nen dung Elastic IP.

1. EC2 Console.
2. Ben trai chon `Elastic IPs`.
3. Bam `Allocate Elastic IP address`.
4. Chon Amazon IPv4 address pool.
5. Bam `Allocate`.
6. Chon IP vua tao.
7. `Actions` -> `Associate Elastic IP address`.
8. Resource type: `Instance`.
9. Chon instance `binchat-backend-prod`.
10. Bam `Associate`.

Can nho: Elastic IP/public IPv4 co tinh phi. Neu xoa server, phai release Elastic IP neu khong dung nua.

## 6. Tro domain ve EC2

Neu co domain, tao DNS record:

```txt
Type: A
Name: api
Value: <ELASTIC_IP>
TTL: Auto
```

Ket qua:

```txt
api.example.com -> <ELASTIC_IP>
```

Neu dung Cloudflare, de proxy `DNS only` luc dau cho de cap Let's Encrypt. Sau khi chay on dinh co the bat proxy tuy nhu cau.

Kiem tra DNS:

```bash
nslookup api.example.com
```

## 7. SSH vao EC2

### 7.1 SSH bang terminal

Voi Ubuntu AMI, user mac dinh la `ubuntu`:

```bash
ssh -i ~/Downloads/binchat-ec2-key.pem ubuntu@<ELASTIC_IP>
```

Hoac:

```bash
ssh -i ~/Downloads/binchat-ec2-key.pem ubuntu@api.example.com
```

### 7.2 SSH bang EC2 Instance Connect

Neu khong muon dung terminal:

1. EC2 -> Instances.
2. Chon instance.
3. Bam `Connect`.
4. Chon `EC2 Instance Connect`.
5. Bam `Connect`.

Neu khong connect duoc, kiem tra Security Group port 22 co allow IP cua ban.

## 8. Cai Docker tren EC2

Chay tren EC2:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg git ufw htop unzip
```

Cai Docker:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
```

Dang xuat va vao lai:

```bash
exit
ssh -i ~/Downloads/binchat-ec2-key.pem ubuntu@api.example.com
```

Kiem tra:

```bash
docker --version
docker compose version
```

## 9. Tao swap de tranh het RAM

Voi `t3.small` 2GB RAM, nen tao swap 2GB hoac 4GB.

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h
```

Neu server cham, do swap chi la cuu canh. Giai phap ben hon la tang len `t3.medium`.

## 10. Clone source code

### 10.1 Repo public

```bash
mkdir -p ~/apps
cd ~/apps
git clone --recurse-submodules https://github.com/<owner>/<repo>.git chat-app
cd chat-app
```

### 10.2 Repo private

Tao SSH key tren EC2:

```bash
ssh-keygen -t ed25519 -C "ec2-binchat-deploy"
cat ~/.ssh/id_ed25519.pub
```

Copy public key, vao GitHub repo:

1. `Settings`.
2. `Deploy keys`.
3. `Add deploy key`.
4. Title: `ec2-binchat-deploy`.
5. Paste public key.
6. Neu server chi pull code, khong tick write access.

Clone:

```bash
mkdir -p ~/apps
cd ~/apps
git clone --recurse-submodules git@github.com:<owner>/<repo>.git chat-app
cd chat-app
```

## 11. Tao file `.env` production

Trong EC2:

```bash
cd ~/apps/chat-app
nano .env
```

Dan template:

```env
# Database
POSTGRES_PASSWORD=CHANGE_ME_STRONG_POSTGRES_PASSWORD

# Auth
JWT_SECRET=CHANGE_ME_LONG_RANDOM_SECRET
JWT_REFRESH_SECRET=CHANGE_ME_LONG_RANDOM_REFRESH_SECRET
INTERNAL_SERVICE_SECRET=CHANGE_ME_INTERNAL_SERVICE_SECRET

# OpenAI
OPENAI_API_KEY=sk-...
BOT_USER_ID=binchat-ai-bot

# Mail
MAIL_USER=your_email@gmail.com
MAIL_PASS=your_gmail_app_password_or_smtp_password
MAIL_FROM="Bin Chat" <no-reply@example.com>

# Upload S3
AWS_REGION=ap-southeast-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=binchat-media-prod

# Re nhat: dung public S3 object base URL.
# Sau nay co tien thi thay bang CloudFront URL.
CLOUDFRONT_URL=https://binchat-media-prod.s3.ap-southeast-1.amazonaws.com

# TURN
TURN_USERNAME=binchat
TURN_PASSWORD=CHANGE_ME_TURN_PASSWORD
```

Tao secret manh:

```bash
openssl rand -hex 32
```

Dung ket qua cho:

- `POSTGRES_PASSWORD`.
- `JWT_SECRET`.
- `JWT_REFRESH_SECRET`.
- `INTERNAL_SERVICE_SECRET`.
- `TURN_PASSWORD`.

Khong commit file `.env`.

## 12. Tao S3 bucket cho upload

### 12.1 Tao bucket

1. AWS Console -> S3.
2. `Create bucket`.
3. Name: `binchat-media-prod`.
4. Region: cung EC2, vi du `ap-southeast-1`.
5. De default encryption.
6. Tao bucket.

### 12.2 S3 CORS

Bucket -> `Permissions` -> `Cross-origin resource sharing (CORS)`:

```json
[
  {
    "AllowedOrigins": [
      "https://chat.example.com",
      "https://your-vercel-project.vercel.app",
      "http://localhost:5173"
    ],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

### 12.3 IAM user cho upload service

1. AWS Console -> IAM.
2. Tao user `binchat-upload-service`.
3. Tao access key.
4. Gan inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:HeadObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::binchat-media-prod/*"
    }
  ]
}
```

### 12.4 Public read cho cach re nhat

Repo hien tao URL media bang `CLOUDFRONT_URL/objectKey`. Neu khong dung CloudFront, dat `CLOUDFRONT_URL` la S3 base URL va cho public read.

Bucket policy demo:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadUploadedObjects",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::binchat-media-prod/*"
    }
  ]
}
```

Cach nay re va de, nhung file co URL la public. Production nghiem tuc nen dung CloudFront/OAC hoac signed URL.

## 13. Tao Docker Compose override cho production

Tao file:

```bash
cd ~/apps/chat-app
nano docker-compose.prod.yml
```

Noi dung:

```yaml
services:
  api-gateway:
    environment:
      - NODE_ENV=production
      - CORS_ORIGIN=https://chat.example.com,https://your-vercel-project.vercel.app

  auth-service:
    environment:
      - NODE_ENV=production
      - INTERNAL_SERVICE_SECRET=${INTERNAL_SERVICE_SECRET}

  user-service:
    environment:
      - NODE_ENV=production
      - INTERNAL_SERVICE_SECRET=${INTERNAL_SERVICE_SECRET}

  friend-service:
    environment:
      - NODE_ENV=production

  notification-service:
    environment:
      - NODE_ENV=production

  upload-service:
    environment:
      - NODE_ENV=production

  chat-service:
    environment:
      - NODE_ENV=production
      - INTERNAL_SERVICE_SECRET=${INTERNAL_SERVICE_SECRET}

  ai-service:
    environment:
      - NODE_ENV=production
      - INTERNAL_SERVICE_SECRET=${INTERNAL_SERVICE_SECRET}
      - BOT_USER_ID=${BOT_USER_ID}
      - CORS_ORIGIN=https://chat.example.com,https://your-vercel-project.vercel.app

  coturn:
    command: >
      -n
      --log-file=stdout
      --min-port=49152
      --max-port=49200
      --realm=api.example.com
      --user=${TURN_USERNAME}:${TURN_PASSWORD}
      --no-tls
      --no-dtls
      --fingerprint
      --lt-cred-mech
```

Luu y database:

- Code TypeORM dang tao bang tu dong khi `NODE_ENV=development`.
- Neu database moi va repo chua co migration, lan dau co the can chay voi `NODE_ENV=development` de tao schema nhanh cho demo.
- Cach chuan production la viet migration cho auth/user/friend truoc.

## 14. Start backend

Chay:

```bash
cd ~/apps/chat-app
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

Xem container:

```bash
docker ps
```

Xem log:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml logs -f
```

Log tung service:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml logs -f api-gateway
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml logs -f auth-service
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml logs -f chat-service
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml logs -f ai-service
```

Test local tren EC2:

```bash
curl http://localhost:3000/api/health
curl http://localhost:3010/api/auth/health
curl http://localhost:3020/api/users/health
curl http://localhost:3040/api/chat/health
curl http://localhost:3050/api/ai/health
```

## 15. Cai HTTPS bang Caddy

Cai Caddy:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
```

Sua config:

```bash
sudo nano /etc/caddy/Caddyfile
```

Noi dung:

```caddyfile
api.example.com {
  encode gzip
  reverse_proxy localhost:3000
}
```

Reload:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy
```

Test:

```bash
curl https://api.example.com/api/health
```

Neu loi certificate:

- DNS A record da tro ve Elastic IP chua?
- Security Group mo port 80 va 443 chua?
- Caddy status co loi gi khong?

## 16. Cau hinh Vercel/mobile tro ve EC2

Web Vercel:

```env
VITE_API_URL=https://api.example.com
VITE_SOCKET_URL=https://api.example.com
```

Mobile Expo:

```env
EXPO_PUBLIC_API_URL=https://api.example.com
EXPO_PUBLIC_SOCKET_URL=https://api.example.com
```

Backend CORS:

```env
CORS_ORIGIN=https://chat.example.com,https://your-vercel-project.vercel.app
```

Sau khi sua `docker-compose.prod.yml`, restart:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 17. Backup du lieu

Tao thu muc:

```bash
mkdir -p ~/backups
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

Tai ve may:

```bash
scp -i ~/Downloads/binchat-ec2-key.pem ubuntu@api.example.com:~/backups/postgres-YYYY-MM-DD.sql .
scp -i ~/Downloads/binchat-ec2-key.pem ubuntu@api.example.com:~/backups/mongo-YYYY-MM-DD.archive .
```

Neu muon backup re hon nua, upload backup len S3 voi lifecycle xoa sau 7-30 ngay.

## 18. Update backend thu cong

```bash
cd ~/apps/chat-app
git pull
git submodule update --init --recursive
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d --build
docker image prune -f
```

Test:

```bash
curl https://api.example.com/api/health
docker ps
```

## 19. CI/CD GitHub Actions voi EC2

Xem file [CI_CD_GITHUB_ACTIONS.md](./CI_CD_GITHUB_ACTIONS.md). Tom tat:

- GitHub Actions SSH vao EC2.
- Chay `git fetch`, `git reset --hard origin/main`, `docker compose up -d --build`.
- `.env` production van nam tren EC2, khong dua len GitHub.

Secrets can co:

```txt
EC2_HOST=api.example.com
EC2_USER=ubuntu
EC2_SSH_KEY=<private key>
EC2_PORT=22
```

## 20. Loi thuong gap

### 20.1 Khong SSH duoc

Kiem tra:

- EC2 status checks da pass chua.
- Security Group port 22 co source la IP cua ban khong.
- Dung user `ubuntu`.
- File `.pem` co permission `chmod 400`.
- Dung dung Elastic IP/domain.

### 20.2 Docker build bi kill

Thuong do thieu RAM.

```bash
free -h
docker stats
```

Cach xu ly:

- Tao swap 4GB.
- Build tung service.
- Nang len `t3.medium`.

### 20.3 Het dung luong disk

Kiem tra:

```bash
df -h
docker system df
```

Don:

```bash
docker image prune -f
docker builder prune -f
```

Neu van day, tang EBS volume tu AWS Console, sau do tren Ubuntu:

```bash
lsblk
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h
```

Ten device co the khac, doc `lsblk` truoc khi chay.

### 20.4 Upload video loi ffmpeg

`services/upload` co xu ly video bang `ffmpeg`. Neu Docker image chua co ffmpeg, sua `services/upload/Dockerfile`:

```dockerfile
RUN apk add --no-cache curl ffmpeg
```

Rebuild:

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d --build upload-service
```

### 20.5 Realtime/socket khong chay

Kiem tra:

- Web da co `VITE_SOCKET_URL=https://api.example.com`.
- `appSocket.ts` da ket noi den env backend, khong phai `io('/')`.
- Caddy reverse proxy den `localhost:3000`.
- Security Group mo `443`.

### 20.6 Bi tinh tien bat ngo

Kiem tra:

- EC2 instance con running khong.
- Elastic IP co dang idle khong.
- EBS volume/snapshot con ton tai khong.
- NAT Gateway co bi tao nham khong.
- S3 co nhieu file/log khong.
- CloudWatch logs co tang manh khong.

## 21. Cach tat/xoa de ngung tinh tien

Neu chi tam ngung:

- Stop EC2 instance: ngung tien compute, nhung EBS va public IPv4/Elastic IP van co the con tinh phi.

Neu khong dung nua:

1. Backup DB neu can.
2. Terminate EC2 instance.
3. Delete EBS volume neu con ton tai.
4. Release Elastic IP.
5. Delete S3 bucket/object neu khong can.
6. Delete snapshots.
7. Xem Billing/Cost Explorer ngay hom sau.

## 22. Nguon tham khao

- EC2 On-Demand pricing: https://aws.amazon.com/ec2/pricing/on-demand/
- EC2 Free Tier usage: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html
- Public IPv4/Elastic IP charging: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html
- EBS pricing: https://aws.amazon.com/ebs/pricing/
- Launch EC2 instance: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/LaunchingAndUsingInstances.html
- Connect to Linux EC2 with SSH: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-to-linux-instance.html
- Security group rules: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules.html
- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html
