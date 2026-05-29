# Deploy Web Len Vercel

File nay huong dan deploy `apps/web` len Vercel. Web la React + Vite, build ra static files.

## 1. Dieu kien truoc khi deploy web

Ban can co:

- Backend AWS EC2 da chay va co URL HTTPS: `https://api.binchat.me`.
- Repo da push len GitHub.
- Tai khoan Vercel.

Test backend truoc:

```bash
curl https://api.binchat.me/api/health
```

Neu health chua OK, chua deploy web voi domain production.

## 2. Luu y quan trong ve Socket.IO trong source hien tai

`apps/web/src/services/appSocket.ts` hien dang dung:

```ts
socket = io('/', {
  path: '/socket.io',
  withCredentials: true,
  transports: ['websocket', 'polling'],
});
```

Khi deploy len Vercel, `io('/')` se ket noi ve chinh domain Vercel. Trong khi Socket.IO backend nam o AWS. Nen co 2 cach.

### Cach A - Khuyen nghi: sua code dung `VITE_SOCKET_URL`

Sua thanh:

```ts
socket = io(import.meta.env.VITE_SOCKET_URL || import.meta.env.VITE_API_URL || '/', {
  path: '/socket.io',
  withCredentials: true,
  transports: ['websocket', 'polling'],
});
```

Sau do tren Vercel dat:

```env
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

### Cach B - Dung rewrite tren Vercel

Tao file `apps/web/vercel.json`:

```json
{
  "rewrites": [
    {
      "source": "/socket.io/:path*",
      "destination": "https://api.binchat.me/socket.io/:path*"
    }
  ]
}
```

Cach B de giu code cu, nhung Cach A ro rang hon.

## 3. Import project vao Vercel

1. Vao https://vercel.com
2. Dang nhap bang GitHub.
3. Chon `Add New...` -> `Project`.
4. Chon repo `chat-app`.
5. O man hinh configure:
   - Framework Preset: `Vite`.
   - Root Directory: `apps/web`.
   - Install Command: `npm install`.
   - Build Command: `npm run build`.
   - Output Directory: `dist`.
6. Mo phan Environment Variables.
7. Them:

```env
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

8. Bam `Deploy`.

## 4. Neu Vercel bi loi monorepo/workspace

Neu build loi do workspace/root lockfile, thu cau hinh:

| Setting | Gia tri |
|---|---|
| Root Directory | `apps/web` |
| Install Command | `npm install` |
| Build Command | `npm run build` |
| Output Directory | `dist` |

Neu van loi vi dependency nam o root, dung:

| Setting | Gia tri |
|---|---|
| Root Directory | `.` |
| Install Command | `npm ci` |
| Build Command | `npm run web:build` |
| Output Directory | `apps/web/dist` |

Voi repo nay, root `package.json` co script:

```json
"web:build": "npm run build --workspace=@chat-app/web"
```

Nen cach Root Directory `.` thuong an toan hon neu workspace phuc tap.

## 5. Them custom domain `binchat.me` cho web

Muc tieu:

| Domain | Noi dung tro ve dau |
|---|---|
| `binchat.me` | Web React tren Vercel |
| `www.binchat.me` | Web React tren Vercel, thuong redirect ve `binchat.me` |
| `api.binchat.me` | Backend EC2, khong tro ve Vercel |

Luu y quan trong: `api.binchat.me` la backend, da tro bang A record ve Elastic IP/Public IPv4 cua EC2. Khong sua record `api` sang Vercel.

### 5.1 Add domain trong Vercel

1. Vao Vercel project web.
2. Chon `Settings`.
3. Chon `Domains`.
4. Add domain:

```txt
binchat.me
```

5. Add them domain:

```txt
www.binchat.me
```

6. Vercel se hien cac DNS record can tao. Thong thuong Vercel yeu cau:

```txt
A      @      76.76.21.21
CNAME  www    cname.vercel-dns.com
```

Neu Vercel hien gia tri khac, uu tien lam theo man hinh Vercel.

### 5.2 Sua DNS hien tai cua `binchat.me`

Trong DNS provider cua ban, hien dang co nhieu A record cho host `@`:

```txt
@ -> 185.199.108.153
@ -> 185.199.109.153
@ -> 185.199.110.153
@ -> 185.199.111.153
```

Day la IP GitHub Pages. Neu muon `binchat.me` chay tren Vercel, hay xoa 4 record GitHub Pages nay va thay bang record Vercel:

```txt
Type: A
Host/Name: @
Value: 76.76.21.21
TTL: Automatic
```

Sua `www`:

Neu dang co:

```txt
CNAME  www  binchat.me.
```

co the doi thanh:

```txt
Type: CNAME
Host/Name: www
Value: cname.vercel-dns.com
TTL: Automatic
```

Giu lai record backend:

```txt
Type: A
Host/Name: api
Value: <Elastic IP/Public IPv4 cua EC2>
TTL: Automatic
```

Vi du:

```txt
A      @      76.76.21.21
CNAME  www    cname.vercel-dns.com
A      api    52.77.144.174
```

### 5.3 Doi Vercel cap SSL

Sau khi sua DNS:

1. Quay lai Vercel `Settings` -> `Domains`.
2. Doi trang thai domain thanh `Valid Configuration`.
3. Doi Vercel cap SSL. Thuong mat vai phut, co khi lau hon tuy DNS cache.

Kiem tra DNS tu may ban:

```bash
nslookup binchat.me
nslookup www.binchat.me
nslookup api.binchat.me
```

Ket qua mong muon:

```txt
binchat.me      -> 76.76.21.21
www.binchat.me  -> cname.vercel-dns.com hoac IP Vercel
api.binchat.me  -> IP EC2
```

### 5.4 Cap nhat environment variables tren Vercel

Trong Vercel project:

1. `Settings`.
2. `Environment Variables`.
3. Them/sua:

```env
VITE_API_URL=https://api.binchat.me
VITE_SOCKET_URL=https://api.binchat.me
```

Chon ca:

```txt
Production
Preview
Development
```

Sau khi sua env, can `Redeploy` de bien moi co hieu luc.

### 5.5 Cap nhat CORS backend EC2

Sau khi co custom domain, quay lai backend EC2 va cap nhat:

```env
CORS_ORIGIN=https://binchat.me,https://www.binchat.me,https://your-vercel-project.vercel.app
```

Neu ban dang dung truc tiep `docker-compose.yml`, sua bien `CORS_ORIGIN` trong service `api-gateway`. Neu co `docker-compose.prod.yml`, sua trong file override.

Sau do restart backend tren EC2:

```bash
cd ~/chat-app
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Neu ban dang chay khong co file prod:

```bash
cd ~/chat-app
docker compose --env-file .env up -d
```

## 6. Kiem tra sau deploy

Mo web Vercel:

```txt
https://binchat.me
```

Checklist:

- Trang login hien dung.
- Dang ky tai khoan moi duoc.
- Dang nhap duoc.
- Refresh page van giu session.
- Tao conversation duoc.
- Gui tin nhan realtime duoc.
- Upload anh duoc.
- Neu co AI: go `@bot xin chao` bot tra loi.

## 7. Debug loi thuong gap

### 7.1 Build fail: TypeScript error

Chay local:

```bash
cd apps/web
npm install
npm run build
```

Sua loi TypeScript truoc khi deploy lai.

### 7.2 Goi API bi CORS

Mo DevTools -> Network -> request loi CORS.

Kiem tra:

- `VITE_API_URL` tren Vercel co dung `https://api.binchat.me`.
- Backend `CORS_ORIGIN` co domain Vercel.
- Da restart backend sau khi doi CORS.

### 7.3 Socket khong connect

Mo DevTools -> Console, tim loi `socket`.

Kiem tra:

- Da sua `appSocket.ts` dung `VITE_SOCKET_URL`.
- Vercel co env `VITE_SOCKET_URL=https://api.binchat.me`.
- Backend HTTPS hoat dong.
- Caddy reverse proxy co forward `/socket.io`.

### 7.4 Dang nhap OK nhung reload mat session

Nguyen nhan thuong la cookie:

- Frontend phai goi HTTPS.
- Backend phai cho credentials.
- Domain CORS phai chinh xac, khong dung wildcard `*` voi cookie.
- Auth service production cookie can cau hinh `secure` phu hop.

## 8. Deploy tu GitHub tu dong

Mac dinh, Vercel tu dong deploy:

- Push len branch `main`: production deployment.
- Tao pull request: preview deployment.

Neu muon dung GitHub Actions de deploy Vercel bang CLI, xem file [CI_CD_GITHUB_ACTIONS.md](./CI_CD_GITHUB_ACTIONS.md).

## 9. Nguon tham khao

- Vercel Vite: https://vercel.com/docs/frameworks/frontend/vite
- Vercel environment variables: https://vercel.com/docs/projects/environment-variables
- Vercel build settings: https://vercel.com/docs/builds/configure-a-build
