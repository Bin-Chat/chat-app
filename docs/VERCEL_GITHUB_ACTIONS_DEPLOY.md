# Deploy Web Len Vercel Bang GitHub Actions

## 1. Muc tieu

Dung GitHub Actions de deploy web len Vercel bang token cua owner.

Ly do:

```txt
Nguoi khac push code
-> Vercel Git Integration co the block vi commit author khong co quyen tren Vercel
-> GitHub Actions deploy bang VERCEL_TOKEN cua owner
-> deploy van chay duoc
```

## 2. File workflow

Workflow nam trong repo web:

```txt
apps/web/.github/workflows/deploy-vercel.yml
```

Neu web repo duoc tach rieng, file nay nam o root cua web repo:

```txt
.github/workflows/deploy-vercel.yml
```

## 3. GitHub Secrets can co

Vao web repo tren GitHub:

```txt
Settings -> Secrets and variables -> Actions -> New repository secret
```

Them:

```txt
VERCEL_TOKEN
```

Token tao tai:

```txt
https://vercel.com/account/tokens
```

## 4. Cach workflow hoat dong

```txt
Push vao main
-> npm ci
-> vercel pull production settings
-> vercel build --prod
-> vercel deploy --prebuilt --prod
```

Workflow set env production:

```txt
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

## 5. Sau khi them workflow

Commit trong repo web:

```bash
git add .github/workflows/deploy-vercel.yml vercel.json
git commit -m "ci: deploy web to vercel with github actions"
git push origin main
```

GitHub Actions cua web repo se tu chay.

## 6. Co nen tat auto deploy tren Vercel khong?

Nen tat neu tiep tuc gap `Deployment Blocked`.

Vao Vercel project:

```txt
Project -> Settings -> Git -> Ignored Build Step
```

Dat command:

```bash
exit 0
```

Hoac dung tuy chon disable auto deploy neu UI Vercel hien co.

Luc do:

```txt
Vercel Git Integration: khong tu deploy nua
GitHub Actions: deploy production thay cho Vercel auto deploy
```
