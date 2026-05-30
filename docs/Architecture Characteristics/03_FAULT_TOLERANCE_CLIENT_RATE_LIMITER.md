# Fault Tolerance - Client Rate Limiter

## Tieu Chi Cham Diem

**Fault Tolerance - Rate Limiter client, API call 1 service - 0.25 diem**

Yeu cau: co co che gioi han request tu client de tranh spam hoac qua tai.

## Da Toi Uu Trong Code

Da bo sung client-side duplicate request limiter cho ca web va mobile.

| Thanh phan | File | Vai tro |
|---|---|---|
| Web helper | `apps/web/src/utils/apiFaultTolerance.ts` | Chan request trung lap trong khoang ngan |
| Web authorized API | `apps/web/src/utils/authorizedAxios.ts` | Gan limiter vao request da dang nhap |
| Web public API | `apps/web/src/utils/publicAxios.ts` | Gan limiter vao login/register/public API |
| Mobile helper | `apps/mobile/src/api/apiFaultTolerance.ts` | Chan request trung lap tren mobile |
| Mobile authorized API | `apps/mobile/src/api/authorizedAxios.ts` | Gan limiter vao request da dang nhap |
| Mobile public API | `apps/mobile/src/api/publicAxios.ts` | Gan limiter vao public API |

## Cach Hoat Dong

Client tao key cho moi request theo:

```txt
METHOD + URL + PARAMS
```

Neu cung mot request duoc goi lap lai trong **800ms**, request sau bi chan ngay tai client va khong gui len server.

Y nghia:

- Giam spam do user double click.
- Giam request trung lap khi UI render/submit nhieu lan.
- Bao ve backend som tu phia client.
- Khong thay the server rate limiter, ma la lop bao ve bo sung.

## Cach Dien Dat Voi Thay Co

Co the noi:

> O phia client, em bo sung mot lop duplicate request limiter trong Axios. Moi request duoc dinh danh bang method, URL va params. Neu user bam qua nhanh hoac UI goi trung cung mot API trong 800ms, client se chan request lap lai truoc khi no di den server. Co che nay giup giam spam tu UI va giam tai cho Gateway.
>
> Em van giu server/gateway rate limiter rieng, vi client-side limiter chi la lop phong ve dau tien. Neu co nguoi bo qua frontend va goi API truc tiep, Gateway van co rate limiter de bao ve backend.

## Cach Demo Chi Tiet

### Cach 1 - Demo Bang Browser DevTools

1. Mo web `https://www.binchat.me`.
2. Mo DevTools -> tab `Network`.
3. Tim mot hanh dong de bam nhanh nhieu lan, vi du search/contact hoac nut goi API profile/list.
4. Bam lien tuc that nhanh.
5. Giai thich: request trung lap trong 800ms se bi chan o client, nen so request len Network it hon so lan click.

### Cach 2 - Demo Bang Console Neu Co The Import Axios Instance

Neu dang dev local va co the goi API tu code, tao 2 request giong nhau gan nhu cung luc:

```ts
authorizedAxios.get('/api/users/profile');
authorizedAxios.get('/api/users/profile');
```

Request thu hai se bi reject voi code:

```txt
CLIENT_RATE_LIMITED
```

### Cach 3 - Chi Code Khi Bao Cao

Neu khong muon demo live, mo file:

```txt
apps/web/src/utils/apiFaultTolerance.ts
```

Chi cac diem:

- `recentRequests = new Map<string, number>()`
- `DEFAULT_DUPLICATE_WINDOW_MS = 800`
- `createClientRateLimitError(...)`
- `attachClientRateLimiter(...)`

## Luu Y Khi Bi Hoi

Neu thay hoi "client limiter co du chong tan cong khong?", tra loi:

> Khong. Client limiter chi giam spam tu UI va loi thao tac nguoi dung. Bao ve that su phai co them Gateway/server rate limiter, va he thong cua em da bo sung ca hai lop.

