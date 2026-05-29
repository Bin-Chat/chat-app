# CI/CD GitHub Actions Cho BinChat

Tai lieu nay mo ta CI/CD thuc te cho setup hien tai:

- Web deploy len Vercel.
- Backend deploy len EC2 bang Docker Compose.
- Backend co nhieu service va nhieu repo con/submodule.
- Khong dung Docker Hub/ECR de tiet kiem chi phi.

## 1. Cac workflow da tao

```txt
.github/workflows/backend-ci.yml
.github/workflows/deploy-backend-ec2.yml
.github/workflows/deploy-web-vercel.yml
docs/templates/service-repo-dispatch-backend.yml
docs/templates/web-repo-dispatch.yml
```

Workflow cu `.github/workflows/ci-cd.yml` da duoc thay the vi khong con khop voi repo hien tai.

## 2. Cach hieu repo nhieu service/nhieu repo

Root repo `chat-app` la repo dieu phoi. Nhieu thu muc la submodule/repo rieng:

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

Voi mo hinh nay co 2 cach deploy:

1. Cap nhat submodule pointer trong root repo roi push root repo.
2. De EC2 pull latest branch `main` cua tung submodule khi deploy.

Workflow backend dang dung cach 2 de thuc te hon: khi deploy, EC2 vao tung submodule, `git fetch`, `checkout main`, `pull --ff-only`, roi build service co thay doi.

## 3. GitHub Secrets can tao

Vao GitHub repo:

```txt
Settings -> Secrets and variables -> Actions -> New repository secret
```

### Backend EC2

| Secret | Gia tri |
|---|---|
| `EC2_HOST` | `api.binchat.me` hoac `52.77.144.174` |
| `EC2_USER` | `ubuntu` |
| `EC2_PORT` | `22` |
| `EC2_SSH_KEY` | private key SSH de vao EC2 |

`EC2_SSH_KEY` phai gom day du:

```txt
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Public key tuong ung phai nam trong EC2:

```txt
~/.ssh/authorized_keys
```

### Web Vercel

| Secret | Gia tri |
|---|---|
| `VERCEL_TOKEN` | token tu Vercel |
| `VERCEL_ORG_ID` | org/team id |
| `VERCEL_PROJECT_ID` | project id cua web |

Lay Vercel project id:

```bash
cd apps/web
npx vercel login
npx vercel link
cat .vercel/project.json
```

Trong Vercel project cung can co env:

```env
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

## 4. Backend CI

File:

```txt
.github/workflows/backend-ci.yml
```

Chay khi PR/push dung cac path backend:

```txt
gateway/**
services/**
docker-compose.yml
docker-compose.env-production.yml
```

No lam:

- Detect service nao thay doi.
- Build Docker image cua service do tren GitHub runner.
- Dung GitHub Actions cache cho Docker layer.
- Khong push image len registry.

Muc dich: bat loi Dockerfile/build truoc khi deploy EC2.

## 5. Deploy Backend Len EC2

File:

```txt
.github/workflows/deploy-backend-ec2.yml
```

Co 2 cach chay:

- Tu dong khi push `main` co thay doi backend.
- Thu cong trong tab Actions bang `Run workflow`.

Workflow nay SSH vao EC2 va chay trong:

```txt
~/chat-app
```

No lam:

1. Pull root repo.
2. Sync submodule.
3. Pull latest `main` cua tung service repo/submodule.
4. So sanh commit hien tai voi lan deploy truoc.
5. Build service thay doi, tung service mot de tranh EC2 het RAM/npm ECONNRESET.
6. Chay:

```bash
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml up -d --no-build --remove-orphans
```

7. Health check:

```bash
curl http://localhost:3000/api/health
curl https://api.binchat.me/api/health
```

### Build mode

Khi chay thu cong, co input `build_mode`:

| Mode | Khi dung |
|---|---|
| `changed` | Mac dinh, chi build service co commit moi |
| `all` | Build lai tat ca service |
| `single` | Build lai 1 service |
| `none` | Khong build, chi recreate container |

Neu chon `single`, chon them `service`, vi du:

```txt
api-gateway
auth-service
chat-service
ai-service
```

## 6. Deploy Web Len Vercel

File:

```txt
.github/workflows/deploy-web-vercel.yml
```

Chay khi:

- Push thay doi `apps/web/**`.
- Chay thu cong trong tab Actions.

No lam:

1. Checkout root repo va submodule.
2. `npm ci` trong `apps/web`.
3. `npm run build`.
4. `vercel pull`.
5. `vercel build --prod`.
6. `vercel deploy --prebuilt --prod`.
7. Smoke check URL vua deploy.

Neu ban da noi Vercel truc tiep voi GitHub repo `apps/web`, co the tat workflow nay va de Vercel auto deploy. Nhung workflow nay huu ich khi muon root repo dieu phoi tat ca.

## 7. Chuan bi EC2 truoc khi bat CI/CD backend

Tren EC2 phai co:

```txt
~/chat-app
~/chat-app/.env
~/chat-app/docker-compose.yml
~/chat-app/docker-compose.env-production.yml
```

Docker dang chay:

```bash
docker --version
docker compose version
```

Neu user `ubuntu` chua dung Docker khong can sudo, workflow van OK vi lenh deploy dung `sudo docker`.

Can dam bao deploy key/SSH key tren EC2 co quyen pull root repo va cac submodule private.

Test thu tren EC2:

```bash
cd ~/chat-app
git pull
git submodule update --init --recursive
git submodule foreach --recursive 'git fetch origin'
```

Neu lenh nay fail vi permission, CI/CD cung se fail.

## 8. Xu ly submodule private

Neu service repo private, EC2 can deploy key.

Tren EC2 tao key:

```bash
ssh-keygen -t ed25519 -C "ec2-binchat-deploy"
cat ~/.ssh/id_ed25519.pub
```

Vao tung repo private tren GitHub:

```txt
Repo -> Settings -> Deploy keys -> Add deploy key
```

Paste public key. Neu EC2 chi pull code, khong tick write access.

## 9. Cach chay lan dau

1. Push cac workflow len GitHub.
2. Vao GitHub repo -> `Actions`.
3. Chon `Deploy Backend to EC2`.
4. Bam `Run workflow`.
5. Chon:

```txt
build_mode: all
update_submodules: true
```

Lan dau nen build `all` de workflow luu state commit. Cac lan sau chon `changed`.

## 10. Cach deploy khi chi sua 1 service

Vi du chi sua AI service:

1. Push code len repo `services/ai`.
2. Vao root repo GitHub -> Actions.
3. Chay `Deploy Backend to EC2`.
4. Chon:

```txt
build_mode: single
service: ai-service
update_submodules: true
```

Workflow se vao EC2, pull latest `services/ai`, build `ai-service`, recreate stack.

## 10.1 Tu dong deploy khi push vao repo service rieng

Neu ban muon push vao repo rieng, vi du `chat-app-service-ai`, roi tu dong yeu cau root repo deploy, dung template:

```txt
docs/templates/service-repo-dispatch-backend.yml
```

Copy file nay vao repo service rieng:

```txt
.github/workflows/request-deploy.yml
```

Sua:

```txt
<owner>/<root-repo>
<compose-service-name>
```

Vi du voi AI service:

```txt
<compose-service-name> = ai-service
```

Trong repo service rieng, tao secret:

```txt
ROOT_REPO_DISPATCH_TOKEN
```

Token nay can quyen `contents: read/write` hoac fine-grained permission duoc phep `repository dispatch` tren root repo.

Root workflow `.github/workflows/deploy-backend-ec2.yml` da lang nghe event:

```txt
repository_dispatch: backend-deploy
```

## 11. Cach deploy khi sua web

Neu dung workflow root:

1. Cap nhat submodule `apps/web` trong root repo, hoac push thay doi trong root neu dang lam truc tiep.
2. Chay `Deploy Web to Vercel`.

Neu Vercel dang link truc tiep repo `chat-app-ui-web`, thi chi can push repo web, Vercel tu deploy.

Neu muon repo web rieng trigger root workflow, copy:

```txt
docs/templates/web-repo-dispatch.yml
```

vao repo web:

```txt
.github/workflows/request-web-deploy.yml
```

Root workflow `.github/workflows/deploy-web-vercel.yml` da lang nghe event:

```txt
repository_dispatch: web-deploy
```

## 12. Rollback nhanh

### Backend

SSH vao EC2:

```bash
cd ~/chat-app
```

Rollback root repo:

```bash
git log --oneline -5
git checkout <old_commit>
git submodule update --init --recursive
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml up -d --no-build
```

Neu can build lai:

```bash
sudo env COMPOSE_PARALLEL_LIMIT=1 docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml build api-gateway
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml up -d --no-build
```

### Web

Vao Vercel:

```txt
Project -> Deployments -> chon deployment cu -> Promote to Production
```

## 13. Bao mat

- Khong commit `.env`.
- Khong commit `.env.production` co secret.
- Dung GitHub Environment `production` de bat approve truoc deploy.
- Chi mo public port `80`, `443`, va `22` gioi han My IP.
- Khong public database ports.
- Backup DB truoc khi deploy thay doi lon.

## 14. Loi thuong gap

### CORS sau deploy

Kiem tra tren EC2:

```bash
sudo docker exec api-gateway printenv CORS_ORIGIN
```

Phai co:

```txt
https://binchat.me,https://www.binchat.me
```

### Deploy fail vi Git permission

Tren EC2:

```bash
cd ~/chat-app
git pull
git submodule foreach --recursive 'git pull'
```

Repo nao fail thi them deploy key vao repo do.

### Docker build qua cham

Workflow da build tung service mot. Neu van cham:

- Nang EC2 len `t3.medium`.
- Tao swap.
- Chon `build_mode=single` khi chi sua 1 service.

### Health check fail

Xem log:

```bash
sudo docker logs api-gateway --tail=120
sudo docker compose --env-file .env -f docker-compose.yml -f docker-compose.env-production.yml ps
```
