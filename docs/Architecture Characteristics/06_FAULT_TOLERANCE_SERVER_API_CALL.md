# Fault Tolerance - Server API Call 1 Service

## Tieu Chi Cham Diem

**Fault Tolerance - Server API call 1 service - 0.25 diem**

Yeu cau: khi server goi sang service khac, can co timeout/retry/cach xu ly loi de tranh treo ca he thong.

## Da Toi Uu Trong Code

Da bo sung timeout va retry cho API Gateway khi forward request vao microservice.

| Luong goi | Bang chung | Co che |
|---|---|---|
| API Gateway -> Auth/User/Friend/Upload/Chat/AI | `gateway/api-gateway/src/proxy/proxy.service.ts` | Timeout 5s, retry GET/HEAD sau 3s |
| Auth Service -> User Service | `services/auth/src/auth/auth.service.ts` | `AbortController` timeout 2.5s |
| AI Service -> internal APIs | `services/ai/src/agent/agent-tools.service.ts` | Axios timeout 15s |
| AI Service -> OpenAI Moderation | `services/ai/src/moderation/moderation.service.ts` | Abort khi vuot timeout |

Production env:

```txt
PROXY_TIMEOUT_MS=5000
PROXY_RETRY_DELAY_MS=3000
PROXY_RETRY_ATTEMPTS=1
```

## Cach Hoat Dong

Khi client goi:

```txt
Client -> Caddy -> API Gateway -> Chat/User/Auth/... Service
```

Gateway se:

1. Tao request sang service noi bo.
2. Dat timeout 5 giay.
3. Neu request GET/HEAD bi network error, timeout hoac 5xx, Gateway cho 3 giay va retry mot lan.
4. Neu van loi, Gateway tra ve `503 Service Unavailable` co kiem soat.

## Cach Dien Dat Voi Thay Co

Co the noi:

> Trong microservice, server-to-server call neu khong co timeout se rat nguy hiem vi mot service bi treo co the lam Gateway treo theo. Vi vay em dat timeout 5 giay cho Gateway khi proxy vao cac service noi bo. Voi request an toan nhu GET/HEAD, Gateway se retry sau 3 giay neu gap loi tam thoi. Neu service van khong phan hoi, Gateway tra ve 503 thay vi de request treo vo han.

## Cach Demo Chi Tiet

### Demo Timeout/503 Khi Service Down

Tren EC2:

```bash
cd ~/chat-app
sudo docker stop user-service
```

Goi API user qua Gateway:

```bash
curl -i https://api.binchat.me/api/users/profile
```

Ket qua mong doi:

- Gateway khong treo vo han.
- Tra ve `503 Service Unavailable` hoac loi co kiem soat.

Bat lai service:

```bash
sudo docker start user-service
curl http://localhost:3020/api/users/health
curl https://api.binchat.me/api/health
```

### Demo Bang Code An Toan Hon

Mo file:

```txt
gateway/api-gateway/src/proxy/proxy.service.ts
```

Chi cac dong:

- `DEFAULT_PROXY_TIMEOUT_MS = 5000`
- `DEFAULT_PROXY_RETRY_DELAY_MS = 3000`
- `requestWithRetry(...)`
- `shouldRetry(...)`

## Luu Y Khi Bi Hoi

Neu thay hoi "tai sao chi retry GET/HEAD?", tra loi:

> GET/HEAD la request doc du lieu, retry an toan hon. POST/PUT/PATCH/DELETE co the tao/sua/xoa du lieu, neu retry tu dong co the tao duplicate message, duplicate upload hoac duplicate action, nen em khong retry cac method nay.

