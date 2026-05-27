# Huong Dan Deploy Tong The

Tai lieu nay gom cac buoc deploy BinChat theo huong tiet kiem chi phi nhat nhung van chay du chuc nang:

- Backend microservices deploy len AWS EC2 bang Docker Compose.
- Web React/Vite deploy len Vercel.
- Mobile Expo build ra Android APK/AAB bang EAS Build.
- CI/CD dung GitHub Actions.

## 1. Kien truc cua repo nay

He thong hien tai co cac phan sau:

| Thanh phan | Thu muc | Port local | Ghi chu |
|---|---:|---:|---|
| API Gateway | `gateway/api-gateway` | `3000` | Diem vao duy nhat cho web/mobile, co Socket.IO |
| Auth service | `services/auth` | `3010` | Dang nhap, cookie, JWT, Redis session |
| User service | `services/user` | `3020` | Ho so user |
| Friend service | `services/friend` | `3025` | Ban be |
| Notification service | `services/notification` | `3030` | Email/Kafka notification |
| Upload service | `services/upload` | `3035` | S3 presigned upload |
| Chat service | `services/chat` | `3040` | Chat, group, poll, note, reminder, task |
| AI service | `services/ai` | `3050` | Moderation, search, summary, translate, rewrite, agent |
| Web app | `apps/web` | `5173` local | React + Vite |
| Mobile app | `apps/mobile` | `8081` local | Expo Router |

Ha tang chay kem:

- PostgreSQL: cho `auth`, `user`, `friend`.
- MongoDB: cho `chat`.
- Redis: session/cache.
- Redpanda: Kafka-compatible event bus.
- Qdrant: vector database cho AI search/RAG.
- coturn: TURN server cho WebRTC call.
- S3: luu file upload.

## 2. Phuong an it ton tien nhat nen dung

Dung:

- 1 AWS EC2 instance cho toan bo backend.
- 1 S3 bucket cho media upload.
- Vercel Hobby/Free cho web.
- Expo EAS Free cho Android build khi con trong gioi han mien phi.
- Cloudflare DNS free neu co domain.

Khong dung luc dau:

- Khong dung RDS vi ton them tien database rieng.
- Khong dung MSK vi Kafka managed rat dat.
- Khong dung ECS/Fargate luc moi bat dau vi phuc tap va kho kiem soat chi phi.
- Khong dung NAT Gateway vi day la nguon dot tien rat pho bien.
- Khong dung Load Balancer neu chi co 1 server.

Muc tieu chi phi cho demo/san pham nho:

| Khoan | Uoc luong |
|---|---:|
| EC2 `t3.small`/`t3.medium` | tinh theo gio, tuy region va instance |
| EBS gp3 30GB | tinh theo GB-thang |
| Public IPv4/Elastic IP | co tinh phi rieng |
| S3 neu upload it | thuong rat thap, tinh theo dung luong/request |
| Vercel Hobby | co the 0 USD |
| GitHub Actions | co the 0 USD neu repo trong gioi han mien phi |
| Expo EAS | co the 0 USD neu build it |
| Domain | tuy nha cung cap, co the khong can luc test |
| OpenAI API | tinh theo usage rieng |

Ghi chu quan trong: gia co the thay doi. Truoc khi tao resource that, mo trang pricing chinh thuc de kiem tra lai.

## 3. Nen doc cac file theo thu tu nao

1. [DEPLOY_AWS_BACKEND_CHEAP.md](./DEPLOY_AWS_BACKEND_CHEAP.md)
2. [DEPLOY_VERCEL_WEB.md](./DEPLOY_VERCEL_WEB.md)
3. [CI_CD_GITHUB_ACTIONS.md](./CI_CD_GITHUB_ACTIONS.md)
4. [BUILD_ANDROID_EXPO.md](./BUILD_ANDROID_EXPO.md)

## 4. Cac gia tri can chuan bi truoc

Ban nen co san:

- Tai khoan AWS.
- Tai khoan GitHub co repo code.
- Tai khoan Vercel.
- Tai khoan Expo.
- Tai khoan OpenAI va `OPENAI_API_KEY`.
- Email SMTP de gui mail, vi du Gmail App Password hoac SMTP provider khac.
- Domain rieng, vi du `api.example.com`, neu muon HTTPS dep va de dung cho mobile.

Ten mien khuyen nghi:

| Muc dich | Vi du |
|---|---|
| Backend API Gateway | `api.example.com` |
| Web Vercel | `chat.example.com` hoac domain Vercel mac dinh |
| S3/CDN media | `https://bucket.s3.region.amazonaws.com` luc re nhat |

## 5. Nhung diem can biet rieng cua source hien tai

1. Web goi API bang bien moi truong:

```env
VITE_API_URL=https://api.example.com
```

2. Mobile goi API bang bien moi truong:

```env
EXPO_PUBLIC_API_URL=https://api.example.com
EXPO_PUBLIC_SOCKET_URL=https://api.example.com
```

3. Web Socket.IO hien tai trong `apps/web/src/services/appSocket.ts` dang ket noi tuong doi bang `io('/')`. Khi deploy web len Vercel va backend nam o AWS, nen sua thanh:

```ts
socket = io(import.meta.env.VITE_SOCKET_URL || import.meta.env.VITE_API_URL || '/', {
  path: '/socket.io',
  withCredentials: true,
  transports: ['websocket', 'polling'],
});
```

Neu khong sua, socket se thu ket noi ve domain Vercel thay vi backend AWS.

4. Backend dung cookie auth. Vi vay CORS/cookie/cung HTTPS phai duoc cau hinh dung.

5. `services/upload` bat buoc co `CLOUDFRONT_URL`. Neu muon re nhat, co the tam dat gia tri nay la public S3 object base URL:

```env
CLOUDFRONT_URL=https://your-bucket-name.s3.ap-southeast-1.amazonaws.com
```

Sau nay khi co ngan sach, thay bang CloudFront distribution domain.

## 6. Nguon tham khao chinh thuc

- AWS EC2 pricing: https://aws.amazon.com/ec2/pricing/on-demand/
- AWS EC2 Free Tier: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html
- AWS EBS pricing: https://aws.amazon.com/ebs/pricing/
- AWS Budgets: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html
- S3 pricing: https://aws.amazon.com/s3/pricing/
- S3 presigned URLs: https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html
- Vercel Vite deploy: https://vercel.com/docs/frameworks/frontend/vite
- Vercel environment variables: https://vercel.com/docs/projects/environment-variables
- GitHub Actions secrets: https://docs.github.com/actions/reference/encrypted-secrets
- Expo EAS Build setup: https://docs.expo.dev/build/setup/
- Expo APK build: https://docs.expo.dev/build-reference/apk
