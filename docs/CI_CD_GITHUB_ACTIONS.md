# CI/CD Bang GitHub Actions

File nay huong dan thiet lap CI/CD cho BinChat:

- Kiem tra build khi push/pull request.
- Deploy backend len EC2 bang SSH.
- Deploy web len Vercel.
- Trigger Android build bang Expo EAS.

## 1. Y tuong tong quan

Phuong an re nhat:

- Khong dung Docker registry rieng.
- Khong dung AWS ECR.
- Khong dung ECS.
- GitHub Actions SSH vao EC2, chay `git pull`, `docker compose up -d --build`.
- Web de Vercel tu deploy tu GitHub hoac deploy bang Vercel CLI.
- Android de EAS Build build tren cloud Expo.

## 2. Tao GitHub Secrets

Vao GitHub repo:

1. `Settings`.
2. `Secrets and variables`.
3. `Actions`.
4. `New repository secret`.

Them cac secret sau.

### 2.1 Secret cho backend deploy

| Secret | Noi dung |
|---|---|
| `EC2_HOST` | IP hoac domain server, vi du `api.example.com` |
| `EC2_USER` | Thuong la `ubuntu` neu dung Ubuntu AMI |
| `EC2_SSH_KEY` | Private key SSH de vao EC2 |
| `EC2_PORT` | Thuong la `22` |

Lay private key:

```bash
cat ~/.ssh/id_ed25519
```

Dan toan bo noi dung vao secret `EC2_SSH_KEY`, bao gom:

```txt
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

### 2.2 Secret cho Vercel CLI neu can

Neu ban de Vercel auto deploy tu GitHub thi khong can nhom nay.

Neu muon deploy bang workflow:

| Secret | Noi dung |
|---|---|
| `VERCEL_TOKEN` | Token tu Vercel account |
| `VERCEL_ORG_ID` | Org/team ID |
| `VERCEL_PROJECT_ID` | Project ID |

Lay token:

1. Vao Vercel.
2. Account Settings.
3. Tokens.
4. Create token.

Lay org/project ID:

```bash
npm i -g vercel
vercel login
cd apps/web
vercel link
cat .vercel/project.json
```

### 2.3 Secret cho Expo EAS

| Secret | Noi dung |
|---|---|
| `EXPO_TOKEN` | Token cua Expo |

Lay token:

1. Vao https://expo.dev
2. Account settings.
3. Access tokens.
4. Create token.

## 3. Workflow CI kiem tra build

Tao file:

```txt
.github/workflows/ci.yml
```

Noi dung:

```yaml
name: CI

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  web-build:
    name: Build web
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Build web
        run: npm run web:build

  backend-build:
    name: Build backend images
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Build docker images
        run: docker compose build
```

Neu repo private va co submodule private, can cau hinh SSH key/deploy key rieng cho submodule.

## 4. Workflow deploy backend len EC2

Tao file:

```txt
.github/workflows/deploy-backend.yml
```

Noi dung:

```yaml
name: Deploy Backend

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "services/**"
      - "gateway/**"
      - "docker-compose.yml"
      - "package.json"
      - "package-lock.json"
      - ".github/workflows/deploy-backend.yml"

concurrency:
  group: deploy-backend-production
  cancel-in-progress: false

jobs:
  deploy:
    name: Deploy to EC2
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Deploy by SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          port: ${{ secrets.EC2_PORT }}
          script_stop: true
          script: |
            set -e
            cd ~/apps/chat-app
            git fetch --all
            git reset --hard origin/main
            git submodule update --init --recursive
            docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d --build
            docker image prune -f
            docker ps
```

Can biet:

- `.env` production nam tren server, khong commit vao GitHub.
- Workflow khong in secret ra log.
- `git reset --hard origin/main` tren server chi dung vi server la ban deploy, khong chua code edit tay. Neu ban hay sua code truc tiep tren server, doi thanh `git pull`.

## 5. Them approval truoc khi deploy production

De tranh push la deploy ngay:

1. Vao GitHub repo.
2. `Settings` -> `Environments`.
3. Tao environment `production`.
4. Bat `Required reviewers`.
5. Chon ban hoac leader.

Workflow tren co:

```yaml
environment: production
```

Nen GitHub se cho approve truoc khi deploy.

## 6. Workflow deploy web bang Vercel CLI

Neu da ket noi Vercel voi GitHub, khong can workflow nay. Vercel tu deploy la de nhat.

Neu muon GitHub Actions tu deploy:

Tao file:

```txt
.github/workflows/deploy-web-vercel.yml
```

Noi dung:

```yaml
name: Deploy Web to Vercel

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "apps/web/**"
      - "package.json"
      - "package-lock.json"
      - ".github/workflows/deploy-web-vercel.yml"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install Vercel CLI
        run: npm install -g vercel

      - name: Pull Vercel environment
        run: vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}

      - name: Build
        run: vercel build --prod --token=${{ secrets.VERCEL_TOKEN }}
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}

      - name: Deploy
        run: vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

## 7. Workflow trigger Android EAS Build

Truoc khi dung CI, phai build thanh cong 1 lan tren may local bang EAS. Ly do: EAS can tao project ID, credentials, `eas.json`.

Tao file:

```txt
.github/workflows/eas-android.yml
```

Noi dung:

```yaml
name: EAS Android Build

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "apps/mobile/**"
      - "package.json"
      - "package-lock.json"
      - ".github/workflows/eas-android.yml"

jobs:
  build:
    name: Trigger Android build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Setup Expo and EAS
        uses: expo/expo-github-action@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}

      - name: Install dependencies
        run: npm ci

      - name: Trigger EAS Android build
        working-directory: apps/mobile
        run: eas build --platform android --profile preview --non-interactive --no-wait
```

`--no-wait` giup GitHub Actions thoat sau khi trigger build, khong ton phut CI trong luc Expo build.

## 8. Kiem tra workflow sau khi tao

1. Commit cac file workflow.
2. Push len GitHub.
3. Vao tab `Actions`.
4. Chon workflow.
5. Bam `Run workflow` neu workflow co `workflow_dispatch`.
6. Xem log.

Neu loi SSH:

- Kiem tra `EC2_HOST`.
- Kiem tra `EC2_USER`.
- Kiem tra private key co dung khong.
- Kiem tra public key co nam trong `~/.ssh/authorized_keys` tren server khong.

Neu loi Docker:

- SSH vao server.
- Chay thu lenh deploy bang tay.
- Xem `docker compose logs`.

## 9. Nguyen tac bao mat khi dung CI/CD

- Khong commit `.env`.
- Khong in secret bang `echo`.
- Dung GitHub Environments de yeu cau approval khi deploy production.
- Private key SSH chi nen co quyen vao server deploy.
- Neu duoc, tao user rieng `deploy` thay vi dung `ubuntu`.
- Khong mo database ra Internet.
- Backup database truoc khi deploy thay doi lon.

## 10. Nguon tham khao

- GitHub Actions secrets: https://docs.github.com/actions/reference/encrypted-secrets
- GitHub Actions contexts: https://docs.github.com/actions/learn-github-actions/contexts
- GitHub deployments/environments: https://docs.github.com/actions/deployment/about-deployments/deploying-with-github-actions
- appleboy ssh-action: https://github.com/appleboy/ssh-action
- Expo build on CI: https://docs.expo.dev/build/building-on-ci/
- Vercel CLI deploy: https://vercel.com/docs/cli/deploy
