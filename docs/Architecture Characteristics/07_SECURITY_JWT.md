# Security - JSON Web Token (JWT)

## Tieu Chi Cham Diem

**Securities - JSON Web Token (JWT) - 0.25 diem**

Yeu cau: ap dung JWT dung cho authentication/authorization.

## Code Hien Co

JWT la phan kha day du trong source hien tai.

| Thanh phan | Bang chung | Vai tro |
|---|---|---|
| API Gateway JWT strategy | `gateway/api-gateway/src/auth/jwt.strategy.ts` | Validate access token tu cookie hoac Bearer token |
| API Gateway JWT guard | `gateway/api-gateway/src/auth/jwt-auth.guard.ts` | Bao ve route proxy |
| Gateway protected routes | `gateway/api-gateway/src/proxy/proxy.controller.ts` | Nhieu route dung `@UseGuards(JwtAuthGuard)` |
| Auth JWT strategy | `services/auth/src/auth/strategies/jwt.strategy.ts` | Validate access token trong Auth Service |
| Refresh JWT strategy | `services/auth/src/auth/strategies/jwt-refresh.strategy.ts` | Validate refresh token |
| Token signing | `services/auth/src/auth/auth.service.ts` | Tao access token va refresh token |
| Cookie security | `services/auth/src/auth/auth.controller.ts` | Set `accessToken`, `refreshToken`, `deviceId` qua cookie |
| Service guards | `services/user`, `services/friend`, `services/chat`, `services/upload` | Cac service co `JwtAuthGuard` rieng |
| Role guard | Auth/User service | Ho tro authorization theo role |

## Luong JWT Tong Quan

1. User dang nhap bang email/password.
2. Auth Service kiem tra thong tin dang nhap.
3. Auth Service tao:
   - Access token: dung cho request ngan han.
   - Refresh token: dung de cap lai access token.
4. Token duoc gan vao cookie, trong do access/refresh token la `httpOnly`.
5. Client goi API qua API Gateway.
6. API Gateway dung JWT Strategy de verify token.
7. Neu token hop le, request moi duoc proxy vao service noi bo.
8. Neu access token het han, client goi refresh token va retry request cu.

## Cach Dien Dat De Dat Diem Cao

Co the trinh bay:

> He thong ap dung JWT theo mo hinh access token va refresh token. Access token duoc dung de xac thuc cac request ngan han, refresh token dung de cap lai access token khi het han. API Gateway la lop bao ve dau vao, validate JWT truoc khi cho request di vao cac microservice. Ngoai Gateway, tung service nhu Auth, User, Friend, Chat, Upload cung co JwtAuthGuard rieng, nen neu co request bo qua Gateway thi service van co lop bao ve.
>
> Refresh token va session thiet bi duoc quan ly bang Redis, giup logout, revoke token va force logout nhanh hon. Cookie `httpOnly` giup giam rui ro token bi doc truc tiep bang JavaScript.

## Diem Manh

- Co JWT guard o Gateway va service.
- Ho tro cookie va Bearer token.
- Co refresh token.
- Refresh/session lien ket Redis.
- Co role guard cho authorization.

## Diem Can Luu Y Khi Bao Cao

Nen phan biet:

- **Authentication:** xac minh user la ai bang JWT.
- **Authorization:** kiem tra user co quyen gi bang role/guard.

Neu thay co hoi "JWT co an toan tuyet doi khong?", tra loi:

> JWT chi la co che xac thuc/uy quyen. Do do em ket hop them cookie httpOnly, refresh token, Redis session, expiration time va guard o nhieu lop de giam rui ro.

