# Fault Tolerance - Server/Gateway Rate Limiter

## Tieu Chi Cham Diem

**Fault Tolerance - Rate Limiter phia server/gateway - 0.25 diem**

Yeu cau: co gioi han request o phia server/gateway de bao ve he thong.

## Da Toi Uu Trong Code

Da kich hoat rate limiter tai API Gateway bang `@nestjs/throttler`, gom 2 lop:

1. **Global rate limiter** trong `AppModule`: ap dung mac dinh cho toan Gateway.
2. **Endpoint/group-specific rate limiter** trong `ProxyController`: moi nhom API co nguong rieng theo rui ro.

| Thanh phan | File | Vai tro |
|---|---|---|
| Thu vien | `gateway/api-gateway/package.json` | Co dependency `@nestjs/throttler` |
| Cau hinh limiter | `gateway/api-gateway/src/app.module.ts` | Dung `ThrottlerModule.forRoot(...)` |
| Global guard | `gateway/api-gateway/src/app.module.ts` | Dung `APP_GUARD` + `ThrottlerGuard` |
| Limit theo endpoint | `gateway/api-gateway/src/proxy/proxy.controller.ts` | Dung `@Throttle(...)` cho tung nhom route |
| Production env | `gateway/api-gateway/.env.production` | `RATE_LIMIT_TTL_MS`, `RATE_LIMIT_MAX_REQUESTS` |

Mac dinh:

```txt
RATE_LIMIT_TTL_MS=60000
RATE_LIMIT_MAX_REQUESTS=120
```

Nghia la moi client/IP duoc goi toi da 120 request trong 60 giay.

Ngoai global limit, Gateway con dat policy rieng:

| Nhom endpoint | Limit | Ly do |
|---|---:|---|
| `GET /health` | 300 request/phut | Cho monitoring ping thuong xuyen |
| `auth/login`, `auth/register`, `auth/refresh`, OTP/password endpoints | 10 request/phut | Chong brute force, spam OTP/email, thu token lien tuc |
| `auth/*` con lai | 60 request/phut | Public auth endpoint nhung it nhay cam hon login/OTP |
| `users/search` | 60 request/phut | Search de bi spam khi user go lien tuc |
| `friends`, `friends/*` | 120 request/phut | Friend actions/list co tan suat vua phai |
| `uploads`, `uploads/*` | 30 request/phut | Presign/upload can limit chat de tranh spam file |
| `chat`, `chat/*` | 240 request/phut | Chat can thoang hon vi nguoi dung thao tac nhieu |
| `ai`, `ai/*` | 20 request/phut | AI ton chi phi/tai nguyen nen limit chat |

## Cach Hoat Dong

Tat ca request di qua Gateway deu qua `ThrottlerGuard`.

Neu client spam qua nguong:

- Gateway chan request.
- Khong forward vao Auth/User/Chat/Upload/AI service.
- Client nhan loi HTTP `429 Too Many Requests`.

## Cach Dien Dat Voi Thay Co

Co the noi:

> Em dat rate limiter tai API Gateway vi day la cua ngo duy nhat cua backend. Tat ca request HTTPS tu web/mobile deu di qua Gateway truoc khi vao microservice. He thong co global limit de bao ve toan bo Gateway, dong thoi co limit rieng cho tung nhom endpoint. Vi du login/OTP chi 10 request/phut de chong brute force, upload chi 30 request/phut de chong spam file, AI chi 20 request/phut vi ton tai nguyen, con chat duoc cho cao hon vi day la luong su dung chinh.

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

### Demo Endpoint Limit Rieng Cho Auth

Endpoint auth sensitive dang limit 10 request/phut. Co the test nhanh bang login sai:

```bash
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "Content-Type: application/json" \
    -d '{"email":"demo@example.com","password":"wrong"}' \
    https://api.binchat.me/api/auth/login
done
```

Ket qua mong doi:

- Nhung request dau co the tra ve `400`/`401`.
- Khi vuot 10 request/phut, Gateway tra ve `429`.

### Demo Upload/AI Limit

Neu da dang nhap va co cookie/token, co the spam API upload/AI de thay `429`. Khong nen demo bang production user that neu dang co nguoi dung that.

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
- `@Throttle(...)` trong `proxy.controller.ts`

## Luu Y Khi Bi Hoi

Neu thay hoi "tai sao khong dat rate limiter trong tung service?", tra loi:

> Dat o Gateway giup chan request som nhat truoc khi vao microservice. Ngoai global limit, em con tach policy theo endpoint vi moi API co muc rui ro khac nhau: login/OTP va AI can chat hon, chat can thoang hon, health endpoint can cho monitoring ping nhieu hon.
