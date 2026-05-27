# Deploy Web Len Vercel

File nay huong dan deploy `apps/web` len Vercel. Web la React + Vite, build ra static files.

## 1. Dieu kien truoc khi deploy web

Ban can co:

- Backend AWS da chay va co URL HTTPS, vi du `https://api.example.com`.
- Repo da push len GitHub.
- Tai khoan Vercel.

Test backend truoc:

```bash
curl https://api.example.com/api/health
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
VITE_API_URL=https://api.example.com
VITE_SOCKET_URL=https://api.example.com
```

### Cach B - Dung rewrite tren Vercel

Tao file `apps/web/vercel.json`:

```json
{
  "rewrites": [
    {
      "source": "/socket.io/:path*",
      "destination": "https://api.example.com/socket.io/:path*"
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
VITE_API_URL=https://api.example.com
VITE_SOCKET_URL=https://api.example.com
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

## 5. Them custom domain cho web

Neu muon web o `chat.example.com`:

1. Vao Vercel project.
2. `Settings` -> `Domains`.
3. Add `chat.example.com`.
4. Vercel se huong dan tao DNS record.
5. Qua DNS provider tao record theo huong dan cua Vercel.
6. Doi Vercel cap SSL xong.

Sau khi co custom domain, quay lai backend AWS va cap nhat:

```env
CORS_ORIGIN=https://chat.example.com,https://your-vercel-project.vercel.app
```

Sau do restart backend:

```bash
cd ~/apps/chat-app
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 6. Kiem tra sau deploy

Mo web Vercel:

```txt
https://your-vercel-project.vercel.app
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

- `VITE_API_URL` tren Vercel co dung `https://api.example.com`.
- Backend `CORS_ORIGIN` co domain Vercel.
- Da restart backend sau khi doi CORS.

### 7.3 Socket khong connect

Mo DevTools -> Console, tim loi `socket`.

Kiem tra:

- Da sua `appSocket.ts` dung `VITE_SOCKET_URL`.
- Vercel co env `VITE_SOCKET_URL=https://api.example.com`.
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
