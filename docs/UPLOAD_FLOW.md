# Upload Flow - Avatar, Chat Image, Video, Document

> **Trạng thái:** image-processor ✅ hoạt động | video-dispatcher ⏳ chờ MediaConvert permission

---

## 0. Kiến trúc tổng quan nhanh

```
Client
  │
  ├─1─ POST /api/uploads/presign  ──► Upload Service
  │                                       │ trả về presignedUrl + objectKey
  ├─2─ PUT <presignedUrl>  ────────────► S3 (trực tiếp, không qua backend)
  │
  ├─3─ POST /api/uploads/finalize  ───► Upload Service (HeadObject + trả cdnUrl)
  │
  └─4─ cdnUrl lưu vào DB
           │
           └─ S3 trigger (async)
               ├─ avatars/* / chats/images/*  ──► Lambda image-processor
               │         tạo __thumb / __medium / __large (.webp)
               └─ chats/videos/*  ─────────────► Lambda video-dispatcher
                         tạo HLS 360p/720p/1080p + thumbnail
```

**Frontend dùng variant theo ngữ cảnh:**

| Ngữ cảnh                      | Variant         | Kích thước   |
| ----------------------------- | --------------- | ------------ |
| Avatar trong danh sách / chat | `__thumb.webp`  | 128×128 crop |
| Avatar lớn / profile panel    | `__medium.webp` | max 512px    |
| Lightbox / xem ảnh full       | `__large.webp`  | max 1080px   |
| Ảnh chat thumbnail            | `__thumb.webp`  | 128×128 crop |
| Ảnh chat inline               | `__medium.webp` | max 512px    |
| Ảnh chat full-screen          | `__medium.webp` | max 1080px   |

Nếu variant chưa tồn tại (Lambda chưa xử lý xong), fallback về URL gốc.

---

## 1. Tong quan kien truc upload

He thong upload su dung mo hinh:

1. Client xin `presignedUrl` tu Upload Service
2. Client upload file truc tiep len AWS S3 bang `PUT`
3. Client goi `finalize` de backend xac nhan file da ton tai
4. Backend tra ve `cdnUrl` (CloudFront) de luu vao DB

Muc tieu:

- Giam tai backend (khong stream file qua API Gateway)
- Tang toc do upload
- De scale

Thanh phan lien quan:

- API Gateway (`/api/uploads/*`)
- Upload Service (NestJS)
- AWS S3 bucket
- AWS CloudFront
- Lambda image-processor (cho anh)
- Lambda video-dispatcher + AWS MediaConvert (cho video)

---

## 2. Luong Upload anh (avatar / chat image)

### 2.1 Presign

Client goi:

- `POST /api/uploads/presign`

Payload:

```json
{
  "category": "avatar",
  "filename": "me.jpg",
  "mimeType": "image/jpeg",
  "fileSize": 345678
}
```

Upload Service validate:

- Extension cho phep theo category
- MIME type hop le
- Kich thuoc file trong gioi han
- Khong thuoc blocked extension

Neu hop le, service tra ve:

```json
{
  "presignedUrl": "https://...",
  "objectKey": "avatars/<userId>/2026/03/<uuid>.jpg",
  "method": "PUT",
  "headers": {
    "Content-Type": "image/jpeg"
  },
  "expiresAt": "2026-03-26T...Z"
}
```

### 2.2 Client PUT len S3

Client upload truc tiep:

- Method: `PUT`
- URL: `presignedUrl`
- Header: `Content-Type` dung voi mime da khai bao
- Body: file binary

### 2.3 Finalize

Sau khi PUT thanh cong, client goi:

- `POST /api/uploads/finalize`

Payload:

```json
{
  "objectKey": "avatars/<userId>/2026/03/<uuid>.jpg",
  "category": "avatar"
}
```

Upload Service dung `HeadObject` de xac nhan file da ton tai tren S3, roi tra ve:

```json
{
  "objectKey": "avatars/<userId>/2026/03/<uuid>.jpg",
  "cdnUrl": "https://d1lcfg5g3uvpfy.cloudfront.net/avatars/<userId>/2026/03/<uuid>.jpg",
  "size": 345678,
  "contentType": "image/jpeg"
}
```

### 2.4 Xu ly anh nen (Lambda image-processor)

S3 trigger Lambda khi co object moi trong:

- `avatars/*`
- `chats/images/*`

Lambda thuc hien:

- Download anh goc
- Tao 3 bien the webp:
  - `__thumb.webp` (128)
  - `__medium.webp` (512)
  - `__large.webp` (1080)
- Upload nguoc lai S3

Luu y:

- Co guard bo qua file da co suffix `__thumb|__medium|__large` de tranh loop vo han

---

## 3. Luong Upload video (chat)

### 3.1 Presign + PUT + Finalize

Luong giong upload anh, nhung:

- category: `video`
- key mau:
  - `chats/videos/2026/03/<uuid>.mp4`

### 3.2 Xu ly video nen (Lambda video-dispatcher)

S3 trigger Lambda khi object moi trong:

- `chats/videos/*`

Lambda video-dispatcher:

- Nhan su kien object moi
- Tao MediaConvert job
- Input: file goc tren S3
- Output: thu muc `outputs/` ben canh file goc

Ket qua du kien:

- HLS ABR:
  - 360p
  - 720p
  - 1080p
- Thumbnail frame (`thumb`)

Luu y:

- Video transcode la asynchronous
- Client khong can cho transcode xong moi gui tin nhan
- Neu can trang thai "dang xu ly", luu metadata vao DB va poll/tracking sau

---

## 4. Luong Upload document (PDF, docx, ...)

### 4.1 Presign + PUT + Finalize

Luong giong anh/video, voi:

- category: `document`
- key mau:
  - `chats/documents/2026/03/<uuid>.pdf`
  - `chats/documents/2026/03/<uuid>.docx`

### 4.2 Co Lambda khong?

Khong.

Document hien tai:

- Luu file goc tren S3
- Truy cap qua CloudFront URL
- Khong resize/transcode

Neu sau nay can scan virus hoac OCR:

- Them Lambda rieng cho prefix `chats/documents/*`

---

## 5. Chinh sach validation theo category

He thong ap dung:

- Allowlist extension + MIME theo category
- Blocklist extension nguy hiem (exe, sh, bat, cmd, ps1, ...)

Muc size toi da hien tai:

- avatar: 2 MB
- image: 10 MB
- video: 50 MB
- document: 20 MB

---

## 6. Mapping object key

- Avatar:
  - `avatars/<userId>/<yyyy>/<mm>/<uuid>.<ext>`
- Chat image:
  - `chats/images/<yyyy>/<mm>/<uuid>.<ext>`
- Chat video:
  - `chats/videos/<yyyy>/<mm>/<uuid>.<ext>`
- Chat document:
  - `chats/documents/<yyyy>/<mm>/<uuid>.<ext>`

---

## 7. Du lieu can luu trong DB

Nen luu it nhat:

- `objectKey`
- `cdnUrl`
- `mimeType`
- `size`
- `category`
- `status` (neu can theo doi transcode video)

---

## 8. Loi thuong gap va cach xu ly

1. `403` khi PUT S3

- Presigned URL het han
- Content-Type gui khong trung voi luc presign

2. `404` khi finalize

- PUT chua thanh cong
- objectKey gui sai

3. Video khong co HLS output

- Lambda video-dispatcher chua du quyen `mediaconvert:CreateJob`
- Sai `MEDIACONVERT_ENDPOINT` hoac `MEDIACONVERT_ROLE_ARN`

4. Anh khong tao variants

- Lambda image-processor chua du quyen S3 read/write
- S3 trigger filter sai prefix

---

## 9. Trinh tu tong ket (short)

1. Client xin presigned URL
2. Client PUT file len S3
3. Client finalize de lay cdnUrl
4. Backend luu cdnUrl vao DB
5. Lambda xu ly nen cho image/video (neu co)

---

## 10. Cách Lambda image-processor tạo variant

### 10.1 Quy tắc đặt tên variant

Cho mỗi ảnh gốc với key:

```
avatars/<userId>/2026/03/<uuid>.jpg
```

Lambda tạo thêm 3 file:

```
avatars/<userId>/2026/03/<uuid>__thumb.webp    ← 128×128, cover crop
avatars/<userId>/2026/03/<uuid>__medium.webp   ← max 512px, giữ tỉ lệ
avatars/<userId>/2026/03/<uuid>__large.webp    ← max 1080px, giữ tỉ lệ
```

File gốc `.jpg` **được giữ nguyên** (dùng làm fallback hoặc re-process).

### 10.2 Công thức tính CDN URL variant từ cdnUrl gốc

```
cdnUrl gốc:  https://d1lcfg5g3uvpfy.cloudfront.net/avatars/user1/2026/03/abc.jpg
                                                                        ↓ bỏ extension
thumb:       https://d1lcfg5g3uvpfy.cloudfront.net/avatars/user1/2026/03/abc__thumb.webp
medium:      https://d1lcfg5g3uvpfy.cloudfront.net/avatars/user1/2026/03/abc__medium.webp
large:       https://d1lcfg5g3uvpfy.cloudfront.net/avatars/user1/2026/03/abc__large.webp
```

### 10.3 Guard tránh loop

Lambda kiểm tra key có chứa `__thumb`, `__medium`, hoặc `__large` → bỏ qua, không xử lý tiếp.

---

## 11. Cách hoạt động Lambda video-dispatcher

### 11.1 Input

S3 ObjectCreated event cho key pattern `chats/videos/*` (không có `/outputs/`).

### 11.2 Output MediaConvert

MediaConvert ghi output vào:

```
chats/videos/2026/03/<uuid>/outputs/hls/         ← HLS playlist + segments
chats/videos/2026/03/<uuid>/outputs/thumb.jpg    ← thumbnail tại giây thứ 5
```

### 11.3 Preset HLS

| Track | Width | Height | Video bitrate | Audio bitrate |
| ----- | ----- | ------ | ------------- | ------------- |
| 360p  | 640   | 360    | 800 kbps      | 96 kbps       |
| 720p  | 1280  | 720    | 2500 kbps     | 128 kbps      |
| 1080p | 1920  | 1080   | 5000 kbps     | 192 kbps      |

Mỗi segment dài 6 giây.

### 11.4 Auto-discover endpoint

`video-dispatcher` tự gọi `mediaconvert:DescribeEndpoints` khi cold start để lấy endpoint account-specific, không cần cấu hình `MEDIACONVERT_ENDPOINT` bằng tay nữa (cần permission `mediaconvert:DescribeEndpoints` trên Lambda role).

---

## 12. Hướng dẫn test Lambda

### 12.1 Test image-processor (AWS Console)

1. Vào **Lambda → image-processor → Test**
2. Tạo test event (chọn template `Amazon S3 Put` hoặc dùng JSON dưới):

```json
{
  "Records": [
    {
      "s3": {
        "bucket": { "name": "binchat-s3" },
        "object": { "key": "avatars/test-user/2026/03/test-image.jpg" }
      }
    }
  ]
}
```

3. Kết quả mong đợi:
   - `NoSuchKey` → ảnh `test-image.jpg` không tổn tại trên S3 (bình thường với key giả)
   - Nếu dùng key thật: Lambda xử lý thành công, 3 variant xuất hiện trong S3

**Test với ảnh thật qua CLI:**

```bash
# Upload ảnh test lên S3
"C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp test.jpg s3://binchat-s3/avatars/test-user/2026/03/test.jpg --region ap-southeast-1

# Invoke Lambda trực tiếp
"C:\Program Files\Amazon\AWSCLIV2\aws.exe" lambda invoke \
  --function-name image-processor \
  --region ap-southeast-1 \
  --payload '{"Records":[{"s3":{"bucket":{"name":"binchat-s3"},"object":{"key":"avatars/test-user/2026/03/test.jpg"}}}]}' \
  /tmp/out.json

# Kiểm tra variant đã được tạo chưa
"C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 ls s3://binchat-s3/avatars/test-user/2026/03/ --region ap-southeast-1
```

Kết quả mong đợi sau invoke:

```
test.jpg           ← gốc
test__thumb.webp   ← 128×128
test__medium.webp  ← max 512px
test__large.webp   ← max 1080px
```

### 12.2 Test video-dispatcher (AWS Console)

> **Điều kiện:** Lambda role đã có `mediaconvert:DescribeEndpoints` + `mediaconvert:CreateJob`

1. Vào **Lambda → video-dispatcher → Test**
2. JSON test event:

```json
{
  "Records": [
    {
      "s3": {
        "bucket": { "name": "binchat-s3" },
        "object": { "key": "chats/videos/2026/03/test-video.mp4" }
      }
    }
  ]
}
```

3. Kết quả mong đợi - Lambda log:
   ```
   Discovered MediaConvert endpoint: https://xxxxxxxx.mediaconvert.ap-southeast-1.amazonaws.com
   MediaConvert job created: 1234567890123-abcdef for chats/videos/2026/03/test-video.mp4
   ```
4. Vào **AWS Console → MediaConvert → Jobs** để theo dõi tiến trình.

### 12.3 Test flow đầy đủ từ Frontend

1. Đăng nhập → vào **Settings → Ảnh đại diện**
2. Upload ảnh → sau khi upload thành công, `cdnUrl` trỏ đến ảnh gốc
3. Chờ ~2-5 giây → Lambda xử lý xong
4. Kiểm tra trên S3 Console: tìm key của ảnh vừa upload, xem có 3 variant `.webp` không
5. Frontend tự động dùng `__thumb.webp` cho avatar nhỏ, `__medium.webp` cho profile

### 12.4 Kiểm tra CloudWatch Logs

```bash
# Xem log gần nhất của image-processor
"C:\Program Files\Amazon\AWSCLIV2\aws.exe" logs tail /aws/lambda/image-processor \
  --region ap-southeast-1 --follow

# Xem log video-dispatcher
"C:\Program Files\Amazon\AWSCLIV2\aws.exe" logs tail /aws/lambda/video-dispatcher \
  --region ap-southeast-1 --follow
```

---

## 13. Biến môi trường Lambda

### image-processor

| Biến             | Giá trị                                 | Bắt buộc          |
| ---------------- | --------------------------------------- | ----------------- |
| `AWS_S3_BUCKET`  | `binchat-s3`                            | ✅                |
| `CLOUDFRONT_URL` | `https://d1lcfg5g3uvpfy.cloudfront.net` | ❌ (chỉ dùng log) |

### video-dispatcher

| Biến                    | Giá trị                                                                   | Bắt buộc |
| ----------------------- | ------------------------------------------------------------------------- | -------- |
| `AWS_S3_BUCKET`         | `binchat-s3`                                                              | ✅       |
| `MEDIACONVERT_ROLE_ARN` | `arn:aws:iam::935358944551:role/service-role/binchat-lamda-role-t8z975uz` | ✅       |
| `MEDIACONVERT_ENDPOINT` | _(tự động phát hiện nếu để trống)_                                        | ❌       |

---

## 14. Quyền IAM cần thiết

### Lambda execution role (`binchat-lamda-role-t8z975uz`) cần:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:HeadObject"],
      "Resource": "arn:aws:s3:::binchat-s3/*"
    },
    {
      "Effect": "Allow",
      "Action": ["mediaconvert:DescribeEndpoints", "mediaconvert:CreateJob"],
      "Resource": "*"
    }
  ]
}
```

---

## 15. Xử lý video phía server (Upload Service — ffmpeg)

### 15.1 Tại sao cần xử lý phía server?

Lambda `video-dispatcher` chỉ được kích hoạt bởi S3 event trigger sau khi deploy trên AWS.
Trong môi trường **local/Docker dev**, Lambda không chạy nên không có variant nào được tạo.

Giải pháp: Upload Service tự xử lý video bằng **ffmpeg** ngay trong Docker container, chạy bất đồng bộ (fire-and-forget) sau khi `finalizeUpload` thành công.

### 15.2 Vị trí file

| File                                           | Vai trò                                              |
| ---------------------------------------------- | ---------------------------------------------------- |
| `services/upload/Dockerfile`                   | Cài `ffmpeg` vào runtime image (`apk add ffmpeg`)    |
| `services/upload/src/upload/upload.service.ts` | Phương thức `processVideoVariants()` + `runFfmpeg()` |

### 15.3 Khi nào được gọi

```
POST /api/uploads/finalize  { objectKey, category: "video" }
         │
         ▼
  finalizeUpload()
         │  HeadObject S3 xác nhận file tồn tại
         │  trả về FinalizeResult ngay cho client  ← không block
         │
         └─ (fire-and-forget)
              processVideoVariants(objectKey)
                   │
                   ├─ Download file gốc từ S3 vào /tmp/<uuid>/
                   ├─ ffmpeg → __thumb.jpg  (thumbnail)
                   ├─ ffmpeg → __360p.mp4   (360p H.264)
                   └─ Upload 2 variant trở lại S3
```

> **Client không cần chờ.** Sau khi nhận `cdnUrl` từ `finalize`, client gửi tin nhắn bình thường. Các variant được tạo trong nền, sẵn sàng sau ~10–30 giây tùy độ dài video.

### 15.4 Các variant được tạo ra

Cho file gốc `chats/videos/2026/03/<uuid>.mp4`:

| Variant   | S3 Key                                   | Mô tả                               |
| --------- | ---------------------------------------- | ----------------------------------- |
| Thumbnail | `chats/videos/2026/03/<uuid>__thumb.jpg` | Frame tại giây thứ 2, scale 640×360 |
| 360p      | `chats/videos/2026/03/<uuid>__360p.mp4`  | H.264 fast-start, crf 23, AAC 96k   |

> Nếu cần thêm 720p, bổ sung entry trong mảng `variants` trong `processVideoVariants()`.

### 15.5 Code mẫu — `processVideoVariants` trong upload.service.ts

```typescript
// services/upload/src/upload/upload.service.ts

private async processVideoVariants(objectKey: string): Promise<void> {
  this.logger.log(`[video] Starting processing: ${objectKey}`);
  const workDir = join(tmpdir(), randomUUID());
  await mkdir(workDir, { recursive: true });

  try {
    // 1. Download file gốc từ S3
    const ext = objectKey.includes('.') ? objectKey.slice(objectKey.lastIndexOf('.')) : '.mp4';
    const inputPath = join(workDir, `input${ext}`);

    const getRes = await this.s3.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: objectKey })
    );
    const chunks: Buffer[] = [];
    for await (const chunk of getRes.Body as AsyncIterable<Uint8Array>) {
      chunks.push(Buffer.from(chunk));
    }
    await writeFile(inputPath, Buffer.concat(chunks));

    const baseKey = objectKey.slice(0, objectKey.lastIndexOf('.'));

    // 2. Tạo thumbnail (seek 2s, fallback về frame 0 nếu video ngắn)
    const thumbPath = join(workDir, 'thumb.jpg');
    await this.runFfmpeg([
      '-ss', '2', '-i', inputPath,
      '-vframes', '1',
      '-vf', 'scale=640:360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2',
      '-q:v', '3', '-y', thumbPath,
    ]).catch(() =>
      this.runFfmpeg([
        '-i', inputPath, '-vframes', '1',
        '-vf', 'scale=640:360:force_original_aspect_ratio=decrease,pad=640:360:(ow-iw)/2:(oh-ih)/2',
        '-q:v', '3', '-y', thumbPath,
      ])
    );

    // 3. Tạo 360p variant
    const p360Path = join(workDir, '360p.mp4');
    await this.runFfmpeg([
      '-i', inputPath,
      '-vf', 'scale=-2:360',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
      '-c:a', 'aac', '-b:a', '96k',
      '-movflags', '+faststart', '-y', p360Path,
    ]);

    // 4. Upload variant lên S3
    const variants = [
      { localPath: thumbPath, s3Key: `${baseKey}__thumb.jpg`, contentType: 'image/jpeg' },
      { localPath: p360Path, s3Key: `${baseKey}__360p.mp4`,  contentType: 'video/mp4' },
    ];
    await Promise.all(
      variants.map(async ({ localPath, s3Key, contentType }) => {
        const body = await readFile(localPath);
        await this.s3.send(new PutObjectCommand({
          Bucket: this.bucket, Key: s3Key, Body: body, ContentType: contentType,
        }));
        this.logger.log(`[video] Uploaded variant: ${s3Key}`);
      })
    );

  } finally {
    await rm(workDir, { recursive: true, force: true }); // dọn /tmp
  }
}

private runFfmpeg(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn('ffmpeg', args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stderr = '';
    proc.stderr.on('data', (d: Buffer) => { stderr += d.toString(); });
    proc.on('close', (code: number) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited ${code}: ${stderr.slice(-500)}`));
    });
    proc.on('error', (err: Error) =>
      reject(new Error(`ffmpeg spawn failed: ${err.message}`))
    );
  });
}
```

### 15.6 Gọi từ finalizeUpload

```typescript
async finalizeUpload(dto: FinalizeUploadDto): Promise<FinalizeResult> {
  // ... HeadObject verify ...

  // Fire-and-forget — không block response
  if (category === 'video') {
    this.processVideoVariants(objectKey).catch((err) =>
      this.logger.error(`Video processing failed for "${objectKey}": ${err.message}`)
    );
  }

  return result; // trả về ngay cho client
}
```

### 15.7 Frontend dùng variant video khi nào

| Ngữ cảnh                             | URL sử dụng         | Ghi chú                      |
| ------------------------------------ | ------------------- | ---------------------------- |
| Thumbnail trong chat bubble          | `<uuid>__thumb.jpg` | Ảnh JPEG, load nhanh         |
| Video player (chất lượng tiêu chuẩn) | `<uuid>__360p.mp4`  | Phù hợp mobile, kết nối chậm |
| Video player (đầy đủ)                | `<uuid>.mp4` (gốc)  | Dùng khi 360p chưa sẵn sàng  |

**Code helper frontend (`apps/web/src/utils/` hoặc mobile):**

```typescript
function getVideoVariant(cdnUrl: string, variant: '__thumb.jpg' | '__360p.mp4'): string {
  const dotIdx = cdnUrl.lastIndexOf('.');
  const base = dotIdx !== -1 ? cdnUrl.slice(0, dotIdx) : cdnUrl;
  return `${base}${variant}`;
}

// Ví dụ dùng:
const thumbUrl = getVideoVariant(attachment.cdnUrl, '__thumb.jpg'); // poster
const video360p = getVideoVariant(attachment.cdnUrl, '__360p.mp4'); // src chính
const videoOrig = attachment.cdnUrl; // fallback
```

**Trong VideoPlayer component:**

```tsx
<video poster={getVideoVariant(cdnUrl, '__thumb.jpg')} controls>
  {/* Ưu tiên 360p, fallback về gốc nếu chưa xử lý xong */}
  <source src={getVideoVariant(cdnUrl, '__360p.mp4')} type="video/mp4" />
  <source src={cdnUrl} type="video/mp4" />
</video>
```

### 15.8 Kiểm tra variant đã được tạo chưa

```bash
# Xem log upload service (Docker)
docker compose logs -f upload

# Kết quả mong đợi trong log:
# [video] Starting processing: chats/videos/2026/03/<uuid>.mp4
# [video] Downloaded chats/videos/... (12345678 bytes)
# [video] Uploaded variant: chats/videos/2026/03/<uuid>__thumb.jpg
# [video] Uploaded variant: chats/videos/2026/03/<uuid>__360p.mp4
# [video] Processing complete: chats/videos/2026/03/<uuid>.mp4
```

```bash
# Kiểm tra trên S3
aws s3 ls s3://binchat-s3/chats/videos/2026/03/ --region ap-southeast-1
# Kết quả mong đợi:
# <uuid>.mp4           ← file gốc
# <uuid>__thumb.jpg    ← thumbnail
# <uuid>__360p.mp4     ← 360p variant
```
