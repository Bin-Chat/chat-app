# Architecture Characteristics - Summary Checklist

Tai lieu nay tong hop nhanh cac tieu chi trong bang diem va doi chieu voi source code hien tai cua Bin Chat. Cac file con trong thu muc nay di sau tung tieu chi, co bang chung code, cach dien dat khi bao cao, va phan nao can bo sung neu muon chac diem toi da.

## Bang Tong Hop

| Tieu chi | Diem | Trang thai hien tai | Bang chung chinh | Ket luan khi bao cao |
|---|---:|---|---|---|
| Availability 24/7 | 0.5 | Co kha tot | Docker `restart: unless-stopped`, `healthcheck`, Caddy reverse proxy, CI/CD health check + rollback | Co the trinh bay la he thong da co co che giam downtime trong muc demo/EC2 single-node |
| Performance - Redis CRUD/cache | 0.25 | Co | `services/auth/src/redis/redis.service.ts`, `services/ai/src/translation/translation.service.ts`, `services/ai/src/summary/summary.service.ts` | Dat: Redis duoc dung cho OTP/session/refresh token/cache AI |
| Fault Tolerance - Client rate limiter | 0.25 | Co | `apiFaultTolerance.ts` o web/mobile, gan vao `authorizedAxios` va `publicAxios` | Dat: chan duplicate request trong 800ms o client |
| Fault Tolerance - Retry 3-5s | 0.25 | Co | `attachRetry3s(...)` o web/mobile va `requestWithRetry(...)` o Gateway | Dat: retry GET/HEAD sau 3s khi network/timeout/5xx |
| Fault Tolerance - Server/Gateway rate limiter | 0.25 | Co | `ThrottlerModule` + `ThrottlerGuard` trong `gateway/api-gateway/src/app.module.ts` | Dat: Gateway chan request spam bang HTTP 429 |
| Fault Tolerance - Server API call 1 service | 0.25 | Co | Gateway proxy timeout 5s + retry 3s; Auth/AI service cung co timeout rieng | Dat: server-to-server call khong bi treo vo han |
| Security - JWT | 0.25 | Co tot | JWT strategy/guard o gateway va cac service, cookie httpOnly, refresh token Redis | Dat: authentication/authorization dung JWT |
| Scalability | 0.5 | Co huong scale, chua auto-scale | Microservice, Docker image GHCR, Vercel web, S3, Kafka/Redpanda, separate DB/cache | Trinh bay la co kha nang scale theo service; production hien la single EC2 demo |

## Diem Can Noi That Khi Bi Hoi

He thong hien tai phu hop muc demo production tren 1 EC2: co reverse proxy, Docker Compose, healthcheck, restart policy, CI/CD pull image va rollback. Tuy nhien, no chua phai kien truc high availability dung nghia nhu multi-AZ, load balancer nhieu EC2, autoscaling group.

Neu thay co hoi "da dam bao 24/7 tuyet doi chua?", nen tra loi:

> Trong pham vi demo, em giam downtime bang Docker restart policy, healthcheck, Caddy reverse proxy, CI/CD deploy co health check va rollback. Neu len production that, em se tach database sang managed service, them ALB + nhieu EC2/ECS replicas de loai bo single point of failure.

## Thu Tu File Nen Doc

1. `01_AVAILABILITY_24_7.md`
2. `02_PERFORMANCE_REDIS_CRUD_CACHE.md`
3. `03_FAULT_TOLERANCE_CLIENT_RATE_LIMITER.md`
4. `04_FAULT_TOLERANCE_RETRY_3_5S.md`
5. `05_FAULT_TOLERANCE_SERVER_RATE_LIMITER.md`
6. `06_FAULT_TOLERANCE_SERVER_API_CALL.md`
7. `07_SECURITY_JWT.md`
8. `08_SCALABILITY.md`
