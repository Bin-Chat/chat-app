# Performance - Redis CRUD/Cache

## Tieu Chi Cham Diem

**Performance - Redis CRUD 1 object - 0.25 diem**

Yeu cau: su dung Redis hop ly cho caching hoac toi uu hieu nang.

## Code Hien Co

He thong da dung Redis o nhieu noi, khong chi tao dependency cho co.

| Vi tri | Redis dung de lam gi | Bang chung |
|---|---|---|
| Auth Service | Luu OTP, refresh token, active device/session | `services/auth/src/redis/redis.service.ts` |
| AI Service | Generic cache get/set/del | `services/ai/src/redis/redis.service.ts` |
| AI Translation | Cache ket qua dich | `services/ai/src/translation/translation.service.ts` |
| AI Summary | Cache ket qua tom tat | `services/ai/src/summary/summary.service.ts` |
| AI Agent | Luu lich su hoi thoai tam thoi voi TTL | `services/ai/src/agent/agent.service.ts` |

## Vi Du Redis CRUD 1 Object

Co the lay object OTP/session de trinh bay:

- **Create/Update:** luu OTP bang Redis key co TTL.
- **Read:** doc OTP de xac thuc.
- **Delete:** xoa OTP sau khi da xac thuc thanh cong.

Trong Auth Service, Redis duoc dung voi cac nhom key nhu:

- `otp:{userId}`
- `refresh:{userId}:{deviceId}`
- `session:device:{userId}:{deviceId}`

Y nghia:

- OTP la du lieu tam thoi, khong nen luu lau trong database.
- Refresh token/session can truy xuat nhanh khi user dang nhap, logout, force logout.
- Redis co TTL nen tu het han, giam viec phai viet job don du lieu.

## Cach Dien Dat De Dat Diem Cao

Co the trinh bay nhu sau:

> Ve Performance, em dung Redis cho cac du lieu co tan suat truy cap cao va vong doi ngan. Vi du OTP, refresh token va session thiet bi duoc luu trong Redis thay vi truy van database moi lan xac thuc. Redis ho tro get/set/del nhanh tren RAM va co TTL, nen phu hop voi du lieu tam thoi.
>
> Ngoai Auth Service, AI Service cung dung Redis de cache ket qua translation va summary. Nhung request AI thuong ton chi phi va do tre cao, nen cache giup giam so lan goi model/logic xu ly lai cung mot noi dung.

## Diem Manh

- Redis duoc dung dung tinh chat: du lieu tam thoi, can nhanh, co TTL.
- Giam tai cho PostgreSQL va cac logic AI ton thoi gian.
- Co CRUD ro rang tren Redis object.

## Cach Demo Nhanh

Neu muon demo Redis CRUD:

```bash
sudo docker exec -it chat-redis redis-cli
KEYS *
GET otp:<userId>
TTL otp:<userId>
```

Neu khong muon show du lieu nhay cam, chi nen demo key test:

```bash
sudo docker exec -it chat-redis redis-cli
SET demo:architecture redis-cache EX 60
GET demo:architecture
DEL demo:architecture
```

