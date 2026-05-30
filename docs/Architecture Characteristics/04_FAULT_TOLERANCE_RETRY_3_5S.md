# Fault Tolerance - Retry 3-5s

## Tieu Chi Cham Diem

**Fault Tolerance - Retry 3-5s, API call 1 service - 0.25 diem**

Yeu cau: co co che retry hop ly khi service loi hoac timeout.

## Da Toi Uu Trong Code

Da bo sung retry policy delay **3 giay** cho ca client va API Gateway.

| Noi ap dung | File | Co che |
|---|---|---|
| Web Axios | `apps/web/src/utils/apiFaultTolerance.ts` | Retry GET/HEAD khi network error, timeout hoac 5xx |
| Mobile Axios | `apps/mobile/src/api/apiFaultTolerance.ts` | Retry GET/HEAD khi network error, timeout hoac 5xx |
| API Gateway proxy | `gateway/api-gateway/src/proxy/proxy.service.ts` | Retry GET/HEAD khi service noi bo loi/timeout |
| Env cau hinh | `gateway/api-gateway/.env.production` | `PROXY_RETRY_DELAY_MS=3000`, `PROXY_RETRY_ATTEMPTS=1` |

## Cach Hoat Dong

Retry chi ap dung cho request an toan:

- `GET`
- `HEAD`

Khong retry cac request tao/sua du lieu nhu:

- `POST`
- `PUT`
- `PATCH`
- `DELETE`

Ly do: neu retry POST gui tin nhan/upload/register, co the tao duplicate data.

Retry duoc kich hoat khi:

- Request timeout.
- Loi network.
- Server tra ve HTTP 5xx.

Mac dinh:

```txt
Delay: 3000ms
Attempts: 1 lan retry
```

## Cach Dien Dat Voi Thay Co

Co the noi:

> Em bo sung retry policy 3 giay cho cac API idempotent nhu GET/HEAD. Khi client hoac Gateway gap loi mang, timeout hoac service tra ve 5xx, request se cho 3 giay roi thu lai mot lan. Em khong retry POST/PUT/PATCH/DELETE de tranh tao trung du lieu, vi cac request nay co side effect.
>
> Co che retry co o ca client va server gateway. Client retry giup trai nghiem nguoi dung on dinh hon khi mat mang ngan. Gateway retry giup xu ly loi tam thoi khi goi sang service noi bo.

## Cach Demo Chi Tiet

### Demo Client Retry

1. Chay web local.
2. Tam thoi doi `VITE_API_URL` sang mot endpoint loi hoac tat mang ngan.
3. Goi mot API GET.
4. Mo DevTools -> Network.
5. Quan sat request bi fail, sau khoang 3 giay co request retry.

Neu khong muon pha production, chi code:

```txt
apps/web/src/utils/apiFaultTolerance.ts
```

Chi ham:

- `attachRetry3s(...)`
- `DEFAULT_RETRY_DELAY_MS = 3000`
- `isRetryable(...)`

### Demo Gateway Retry

Tren EC2 co the demo y tuong bang code/config, khong nen co tinh pha service production neu dang demo live.

Mo file:

```txt
gateway/api-gateway/src/proxy/proxy.service.ts
```

Chi cac diem:

- `PROXY_RETRY_DELAY_MS`
- `PROXY_RETRY_ATTEMPTS`
- `requestWithRetry(...)`
- `shouldRetry(...)`

Noi:

> Gateway chi retry GET/HEAD khi loi timeout/network/5xx. Neu retry van that bai, Gateway tra ve 503 co kiem soat cho client.

