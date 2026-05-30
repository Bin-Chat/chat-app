# Fault Tolerance - Server/Gateway Rate Limiter

## Tieu Chi Cham Diem

**Fault Tolerance - Rate Limiter phia server/gateway - 0.25 diem**

Yeu cau: co gioi han request o phia server/gateway de bao ve he thong.

## Da Toi Uu Trong Code

Da kich hoat global rate limiter tai API Gateway bang `@nestjs/throttler`.

| Thanh phan | File | Vai tro |
|---|---|---|
| Thu vien | `gateway/api-gateway/package.json` | Co dependency `@nestjs/throttler` |
| Cau hinh limiter | `gateway/api-gateway/src/app.module.ts` | Dung `ThrottlerModule.forRoot(...)` |
| Global guard | `gateway/api-gateway/src/app.module.ts` | Dung `APP_GUARD` + `ThrottlerGuard` |
| Production env | `gateway/api-gateway/.env.production` | `RATE_LIMIT_TTL_MS`, `RATE_LIMIT_MAX_REQUESTS` |

Mac dinh:

```txt
RATE_LIMIT_TTL_MS=60000
RATE_LIMIT_MAX_REQUESTS=120
```

Nghia la moi client/IP duoc goi toi da 120 request trong 60 giay.

## Cach Hoat Dong

Tat ca request di qua Gateway deu qua `ThrottlerGuard`.

Neu client spam qua nguong:

- Gateway chan request.
- Khong forward vao Auth/User/Chat/Upload/AI service.
- Client nhan loi HTTP `429 Too Many Requests`.

## Cach Dien Dat Voi Thay Co

Co the noi:

> Em dat rate limiter tai API Gateway vi day la cua ngo duy nhat cua backend. Tat ca request HTTPS tu web/mobile deu di qua Gateway truoc khi vao microservice. Khi mot client goi qua nhieu request trong 60 giay, Gateway tra ve HTTP 429 va khong forward request vao service noi bo. Cach nay bao ve toan bo backend khoi spam va qua tai.

## Cach Demo Chi Tiet Tren EC2

### Demo Bang curl

Chay lenh sau tren EC2 hoac may local:

```bash
for i in $(seq 1 140); do
  curl -s -o /dev/null -w "%{http_code}\n" https://api.binchat.me/api/health
done
```

Ket qua mong doi:

- Ban dau nhieu request tra ve `200`.
- Khi vuot nguong, mot so request tra ve `429`.

Neu health endpoint bi bo qua limiter trong tuong lai, demo bang API protected hoac login endpoint:

```bash
for i in $(seq 1 140); do
  curl -s -o /dev/null -w "%{http_code}\n" https://api.binchat.me/api/auth/login
done
```

### Demo Bang Code

Mo:

```txt
gateway/api-gateway/src/app.module.ts
```

Chi:

- `ThrottlerModule.forRoot`
- `ttl`
- `limit`
- `APP_GUARD`
- `ThrottlerGuard`

## Luu Y Khi Bi Hoi

Neu thay hoi "tai sao khong dat rate limiter trong tung service?", tra loi:

> Dat o Gateway giup chan request som nhat truoc khi vao microservice. Neu can bao ve sau hon, co the them rate limiter rieng cho Auth Service voi login/OTP de chong brute force.

