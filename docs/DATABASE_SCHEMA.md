# Database Schema — BinChat

> Tài liệu mô tả toàn bộ các bảng/collection, trường dữ liệu, kiểu dữ liệu, ràng buộc và mối quan hệ giữa các entity trong hệ thống.

---

## Tổng quan các Database

| Database         | Engine        | Service sử dụng | Mục đích                     |
| ---------------- | ------------- | --------------- | ---------------------------- |
| `auth_service`   | PostgreSQL 15 | auth-service    | Tài khoản, xác thực, JWT     |
| `user_service`   | PostgreSQL 15 | user-service    | Thông tin profile người dùng |
| `friend_service` | PostgreSQL 15 | friend-service  | Quan hệ bạn bè               |
| `chat` (MongoDB) | MongoDB 7     | chat-service    | Cuộc trò chuyện, tin nhắn    |
| Redis            | Redis 7       | auth-service    | OTP tạm thời, session cache  |
| S3 + CloudFront  | AWS           | upload-service  | Lưu trữ file/ảnh/video       |

---

## Class Diagram — Toàn bộ Schema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PostgreSQL — auth_service DB                         │
│                                                                             │
│  ┌────────────────────────────────────┐                                     │
│  │             users                  │                                     │
│  ├────────────────────────────────────┤                                     │
│  │ + id: UUID (PK)                    │                                     │
│  │ + email: VARCHAR(255) UNIQUE       │                                     │
│  │ + passwordHash: VARCHAR            │                                     │
│  │ + fullName: VARCHAR                │                                     │
│  │ + isActive: BOOLEAN = true         │                                     │
│  │ + isEmailVerified: BOOLEAN = false │                                     │
│  │ + role: ENUM('user','admin')       │                                     │
│  │ + resetPasswordOtp: VARCHAR(6)     │                                     │
│  │ + resetPasswordOtpExpires: TIMESTAMP│                                    │
│  │ + createdAt: TIMESTAMP             │                                     │
│  │ + updatedAt: TIMESTAMP             │                                     │
│  └────────────────────────────────────┘                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        PostgreSQL — user_service DB                         │
│                                                                             │
│  ┌────────────────────────────────────┐                                     │
│  │          user_profiles             │                                     │
│  ├────────────────────────────────────┤                                     │
│  │ + id: UUID (PK)     ←──── Kafka sync từ auth_service.users.id           │
│  │ + email: VARCHAR(255) UNIQUE       │                                     │
│  │ + fullName: VARCHAR                │                                     │
│  │ + avatar: VARCHAR (CDN URL)        │                                     │
│  │ + phone: VARCHAR(20)               │                                     │
│  │ + bio: TEXT                        │                                     │
│  │ + role: VARCHAR(20) = 'user'       │                                     │
│  │ + isActive: BOOLEAN = true         │                                     │
│  │ + createdAt: TIMESTAMP             │                                     │
│  │ + updatedAt: TIMESTAMP             │                                     │
│  └────────────────────────────────────┘                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                       PostgreSQL — friend_service DB                        │
│                                                                             │
│  ┌────────────────────────────────────┐                                     │
│  │          user_cache                │                                     │
│  ├────────────────────────────────────┤   Kafka sync từ auth_service       │
│  │ + id: UUID (PK)    ←──────────────┼── user.registered event            │
│  │ + email: VARCHAR(255) UNIQUE       │   user.profile.updated event       │
│  │ + fullName: VARCHAR                │                                     │
│  │ + avatar: VARCHAR (CDN URL)        │                                     │
│  │ + isActive: BOOLEAN = true         │                                     │
│  │ + createdAt: TIMESTAMP             │                                     │
│  │ + updatedAt: TIMESTAMP             │                                     │
│  └──────────────┬─────────────────────┘                                    │
│                 │ 1                                                         │
│          referenziert von                                                   │
│                 │ N                                                         │
│  ┌──────────────▼─────────────────────┐                                    │
│  │           friendships              │                                     │
│  ├────────────────────────────────────┤                                     │
│  │ + id: UUID (PK)                    │                                     │
│  │ + requesterId: UUID (FK→user_cache)│                                     │
│  │ + addresseeId: UUID (FK→user_cache)│                                     │
│  │ + status: ENUM                     │                                     │
│  │     'pending'                      │                                     │
│  │     'accepted'                     │                                     │
│  │     'declined'                     │                                     │
│  │     'blocked'                      │                                     │
│  │ + createdAt: TIMESTAMP             │                                     │
│  │ + updatedAt: TIMESTAMP             │                                     │
│  │                                    │                                     │
│  │ INDEX UNIQUE(requesterId, addresseeId)                                  │
│  └────────────────────────────────────┘                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         MongoDB — chat database                             │
│                                                                             │
│  ┌────────────────────────────────────────────────────┐                    │
│  │                  conversations                      │                    │
│  ├────────────────────────────────────────────────────┤                    │
│  │ + _id: ObjectId (PK)                               │                    │
│  │ + type: String ENUM('direct','group')              │                    │
│  │ + name?: String                (group only)        │                    │
│  │ + avatar?: String              (group only)        │                    │
│  │                                                    │                    │
│  │ + participants: [Participant]                      │                    │
│  │   └─ userId: String  (UUID ref → auth users.id)   │                    │
│  │   └─ joinedAt: Date                               │                    │
│  │                                                    │                    │
│  │ + lastMessage?: LastMessage                        │                    │
│  │   └─ senderId: String                             │                    │
│  │   └─ content: String                              │                    │
│  │   └─ type: String ('text'|'attachment')           │                    │
│  │   └─ sentAt: Date                                 │                    │
│  │                                                    │                    │
│  │ + createdAt: Date (auto)                           │                    │
│  │ + updatedAt: Date (auto)                           │                    │
│  │                                                    │                    │
│  │ INDEX: participants.userId                         │                    │
│  │ INDEX: lastMessage.sentAt DESC                     │                    │
│  └──────────────────────┬─────────────────────────────┘                    │
│                         │ 1 conversation : N messages                      │
│                         │                                                  │
│  ┌──────────────────────▼─────────────────────────────┐                    │
│  │                    messages                         │                    │
│  ├────────────────────────────────────────────────────┤                    │
│  │ + _id: ObjectId (PK)                               │                    │
│  │ + conversationId: ObjectId (FK→conversations._id) │                    │
│  │ + senderId: String (UUID ref → auth users.id)      │                    │
│  │ + content: String = ''                             │                    │
│  │ + revokedAt?: Date = null                          │                    │
│  │                                                    │                    │
│  │ + attachments: [Attachment]                        │                    │
│  │   └─ url: String (CloudFront URL)                 │                    │
│  │   └─ type: ENUM('image','video','file')           │                    │
│  │   └─ filename: String                             │                    │
│  │   └─ size: Number (bytes)                         │                    │
│  │   └─ mimeType: String                             │                    │
│  │   └─ width?: Number                               │                    │
│  │   └─ height?: Number                              │                    │
│  │   └─ duration?: Number (video, giây)              │                    │
│  │   └─ thumbnailUrl?: String                        │                    │
│  │                                                    │                    │
│  │ + reactions: [Reaction]                            │                    │
│  │   └─ userId: String                               │                    │
│  │   └─ emoji: String                                │                    │
│  │                                                    │                    │
│  │ + deletedFor: [String]  (mảng userId đã xóa)      │                    │
│  │                                                    │                    │
│  │ + readBy: [ReadReceipt]                            │                    │
│  │   └─ userId: String                               │                    │
│  │   └─ readAt: Date                                 │                    │
│  │                                                    │                    │
│  │ + forwardedFrom?: ForwardInfo                      │                    │
│  │   └─ messageId: String                            │                    │
│  │   └─ conversationId: String                       │                    │
│  │   └─ senderId: String                             │                    │
│  │                                                    │                    │
│  │ + createdAt: Date (auto)                           │                    │
│  │ + updatedAt: Date (auto)                           │                    │
│  │                                                    │                    │
│  │ INDEX: conversationId                              │                    │
│  └────────────────────────────────────────────────────┘                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              Redis                                          │
│                                                                             │
│   Key pattern: pending_otp:{email}   TTL: 900s   Value: "123456"           │
│   Key pattern: otp:{userId}          TTL: 900s   Value: "123456"           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Chi tiết từng Entity

### 1. `users` — auth_service (PostgreSQL)

| Cột                       | Kiểu         | Ràng buộc         | Mô tả                                         |
| ------------------------- | ------------ | ----------------- | --------------------------------------------- |
| `id`                      | UUID         | PK, auto-generate | Định danh duy nhất                            |
| `email`                   | VARCHAR(255) | UNIQUE, NOT NULL  | Email đăng nhập                               |
| `passwordHash`            | VARCHAR      | NOT NULL          | bcrypt hash của mật khẩu                      |
| `fullName`                | VARCHAR      | NULLABLE          | Tên đầy đủ                                    |
| `isActive`                | BOOLEAN      | DEFAULT true      | Tài khoản có bị khóa không                    |
| `isEmailVerified`         | BOOLEAN      | DEFAULT false     | Đã xác thực email chưa                        |
| `role`                    | ENUM         | DEFAULT 'user'    | Quyền: 'user' \| 'admin'                      |
| `resetPasswordOtp`        | VARCHAR(6)   | NULLABLE          | OTP đặt lại mật khẩu (deprecated, dùng Redis) |
| `resetPasswordOtpExpires` | TIMESTAMP    | NULLABLE          | Hạn OTP (deprecated)                          |
| `createdAt`               | TIMESTAMP    | AUTO              | Thời điểm tạo                                 |
| `updatedAt`               | TIMESTAMP    | AUTO              | Thời điểm cập nhật                            |

**Lưu ý bảo mật**: `passwordHash` không bao giờ được trả về API (dùng `@Exclude()` của class-transformer).

---

### 2. `user_profiles` — user_service (PostgreSQL)

| Cột         | Kiểu         | Ràng buộc        | Mô tả                             |
| ----------- | ------------ | ---------------- | --------------------------------- |
| `id`        | UUID         | PK (không auto)  | Giống `users.id` bên auth_service |
| `email`     | VARCHAR(255) | UNIQUE, NOT NULL | Sync từ auth                      |
| `fullName`  | VARCHAR      | NULLABLE         | Tên hiển thị                      |
| `avatar`    | VARCHAR      | NULLABLE         | URL ảnh đại diện (CloudFront)     |
| `phone`     | VARCHAR(20)  | NULLABLE         | Số điện thoại                     |
| `bio`       | TEXT         | NULLABLE         | Giới thiệu bản thân               |
| `role`      | VARCHAR(20)  | DEFAULT 'user'   | Sync từ auth                      |
| `isActive`  | BOOLEAN      | DEFAULT true     | Sync từ auth                      |
| `createdAt` | TIMESTAMP    | AUTO             | Thời điểm tạo                     |
| `updatedAt` | TIMESTAMP    | AUTO             | Thời điểm cập nhật                |

**Ghi chú**: Đây là bản sao của dữ liệu từ `auth_service.users`, được đồng bộ qua Kafka event `user.registered`. Không có `passwordHash`.

---

### 3. `user_cache` — friend_service (PostgreSQL)

| Cột         | Kiểu         | Ràng buộc       | Mô tả                             |
| ----------- | ------------ | --------------- | --------------------------------- |
| `id`        | UUID         | PK (không auto) | Giống `users.id` bên auth_service |
| `email`     | VARCHAR(255) | UNIQUE          | Sync từ auth                      |
| `fullName`  | VARCHAR      | NULLABLE        | Tên hiển thị                      |
| `avatar`    | VARCHAR      | NULLABLE        | URL ảnh đại diện                  |
| `isActive`  | BOOLEAN      | DEFAULT true    | Sync từ auth                      |
| `createdAt` | TIMESTAMP    | AUTO            | Thời điểm đồng bộ                 |
| `updatedAt` | TIMESTAMP    | AUTO            | Thời điểm cập nhật                |

**Mục đích**: Tránh HTTP call liên service khi cần enrich dữ liệu bạn bè. Sync qua Kafka: `user.registered` + `user.profile.updated`.

---

### 4. `friendships` — friend_service (PostgreSQL)

| Cột           | Kiểu      | Ràng buộc         | Mô tả                   |
| ------------- | --------- | ----------------- | ----------------------- |
| `id`          | UUID      | PK                | Định danh quan hệ       |
| `requesterId` | UUID      | NOT NULL          | UUID người gửi lời mời  |
| `addresseeId` | UUID      | NOT NULL          | UUID người nhận lời mời |
| `status`      | ENUM      | DEFAULT 'pending' | Trạng thái quan hệ      |
| `createdAt`   | TIMESTAMP | AUTO              | Ngày gửi lời mời        |
| `updatedAt`   | TIMESTAMP | AUTO              | Ngày cập nhật           |

**Enum `status`**:
| Giá trị | Ý nghĩa |
|---|---|
| `pending` | Đang chờ phản hồi |
| `accepted` | Đã là bạn bè |
| `declined` | Bị từ chối |
| `blocked` | Bị block |

**Index**: `UNIQUE(requesterId, addresseeId)` — đảm bảo mỗi cặp user chỉ có 1 relationship record.

---

### 5. `conversations` — chat_service (MongoDB)

| Field          | Type          | Mô tả                                           |
| -------------- | ------------- | ----------------------------------------------- |
| `_id`          | ObjectId      | MongoDB auto-generated ID                       |
| `type`         | String enum   | `'direct'` (2 người) \| `'group'` (nhiều người) |
| `name`         | String?       | Tên nhóm (chỉ group)                            |
| `avatar`       | String?       | Ảnh nhóm (chỉ group)                            |
| `description`  | String?       | Mô tả nhóm (tối đa 500 ký tự, chỉ group)       |
| `participants` | Participant[] | Danh sách thành viên                            |
| `lastMessage`  | LastMessage?  | Preview tin nhắn cuối                           |
| `createdAt`    | Date          | Auto (timestamps: true)                         |
| `updatedAt`    | Date          | Auto (timestamps: true)                         |

**Embedded: `Participant`**

| Field      | Type   | Mô tả                                            |
| ---------- | ------ | ------------------------------------------------ |
| `userId`   | String | UUID của user (ref logic tới auth users.id)      |
| `role`     | String | `'owner'` \| `'admin'` \| `'member'` (default)  |
| `joinedAt` | Date   | Ngày tham gia conversation                       |

**Embedded: `LastMessage`**

| Field      | Type   | Mô tả                        |
| ---------- | ------ | ---------------------------- |
| `senderId` | String | UUID người gửi tin cuối      |
| `content`  | String | Text preview (hoặc '[File]') |
| `type`     | String | `'text'` \| `'attachment'`   |
| `sentAt`   | Date   | Thời điểm gửi                |

**Indexes**:

- `participants.userId`: Tìm conversations của một user
- `lastMessage.sentAt DESC`: Sort theo tin nhắn mới nhất

---

### 6. `messages` — chat_service (MongoDB)

| Field            | Type          | Mô tả                                            |
| ---------------- | ------------- | ------------------------------------------------ |
| `_id`            | ObjectId      | MongoDB auto-generated ID                        |
| `conversationId` | ObjectId      | FK → conversations.\_id                          |
| `senderId`       | String        | UUID người gửi (ref auth users.id)               |
| `content`        | String        | Nội dung text (default `''`)                     |
| `revokedAt`      | Date?         | Thời điểm thu hồi (null = chưa thu hồi)          |
| `attachments`    | Attachment[]  | Danh sách file đính kèm                          |
| `reactions`      | Reaction[]    | Danh sách emoji reactions                        |
| `deletedFor`     | String[]      | Mảng userId đã xóa tin (soft delete)             |
| `readBy`         | ReadReceipt[] | Mảng userId đã đọc                               |
| `forwardedFrom`  | ForwardInfo?  | Metadata nếu là tin chuyển tiếp                  |
| `replyTo`        | ReplyInfo?    | Metadata tin trả lời (null nếu không phải reply) |
| `createdAt`      | Date          | Auto                                             |
| `updatedAt`      | Date          | Auto                                             |

**Embedded: `Attachment`**

| Field          | Type        | Mô tả                              |
| -------------- | ----------- | ---------------------------------- |
| `url`          | String      | CloudFront CDN URL                 |
| `type`         | String enum | `'image'` \| `'video'` \| `'file'` |
| `filename`     | String      | Tên file gốc                       |
| `size`         | Number      | Kích thước bytes                   |
| `mimeType`     | String      | MIME type (vd: `image/jpeg`)       |
| `width`        | Number?     | Chiều rộng (image/video)           |
| `height`       | Number?     | Chiều cao (image/video)            |
| `duration`     | Number?     | Thời lượng giây (video)            |
| `thumbnailUrl` | String?     | URL ảnh thumbnail (video)          |

**Embedded: `Reaction`**

| Field    | Type   | Mô tả                    |
| -------- | ------ | ------------------------ |
| `userId` | String | UUID người react         |
| `emoji`  | String | Ký tự emoji (vd: `'👍'`) |

**Embedded: `ForwardInfo`**

| Field            | Type   | Mô tả                  |
| ---------------- | ------ | ---------------------- |
| `messageId`      | String | \_id của tin gốc       |
| `conversationId` | String | \_id conversation gốc  |
| `senderId`       | String | UUID người gửi tin gốc |

**Embedded: `ReplyInfo`**

| Field            | Type    | Mô tả                                                              |
| ---------------- | ------- | ------------------------------------------------------------------ |
| `messageId`      | String  | \_id tin nhắn được trả lời                                         |
| `senderId`       | String  | UUID người gửi tin được trả lời                                    |
| `content`        | String  | Trích dẫn nội dung (tối đa 100 ký tự)                              |
| `attachmentType` | String? | Loại file nếu tin gốc có đính kèm (`'image'`\|`'video'`\|`'file'`) |

**Embedded: `ReadReceipt`**

| Field    | Type   | Mô tả          |
| -------- | ------ | -------------- |
| `userId` | String | UUID người đọc |
| `readAt` | Date   | Thời điểm đọc  |

**Index**: `conversationId` — tìm kiếm tin nhắn theo conversation

---

### 7. Redis Keys

| Key Pattern           | TTL  | Value           | Mục đích                       |
| --------------------- | ---- | --------------- | ------------------------------ |
| `pending_otp:{email}` | 900s | String 6 chữ số | OTP xác thực email khi đăng ký |
| `otp:{userId}`        | 900s | String 6 chữ số | OTP đặt lại mật khẩu           |

---

## Mối quan hệ Cross-Service (Kafka Sync)

```
auth_service.users
       │
       │ Kafka: user.registered
       │ Payload: { id, email, fullName, role, createdAt }
       │
       ├──────────────────────► user_service.user_profiles  (CREATE)
       │
       └──────────────────────► friend_service.user_cache   (CREATE)

user_service.user_profiles
       │
       │ Kafka: user.profile.updated
       │ Payload: { id, fullName, avatar }
       │
       └──────────────────────► friend_service.user_cache   (UPDATE avatar, fullName)
```

**Quan hệ logic không có FK cứng**:

```
auth_service.users.id
    ↑ logical ref (không FK)
    │
    ├─ user_service.user_profiles.id
    ├─ friend_service.user_cache.id
    ├─ friend_service.friendships.requesterId
    ├─ friend_service.friendships.addresseeId
    ├─ chat_service.conversations[].participants[].userId
    ├─ chat_service.messages.senderId
    ├─ chat_service.messages.reactions[].userId
    ├─ chat_service.messages.deletedFor[]
    └─ chat_service.messages.readBy[].userId
```

---

## Upload Policy — AWS S3

Không có database table, S3 object key convention:

| Category   | Prefix             | Max Size | Extensions                               |
| ---------- | ------------------ | -------- | ---------------------------------------- |
| `avatar`   | `avatars/`         | 2 MB     | jpg, jpeg, png, webp                     |
| `image`    | `chats/images/`    | 10 MB    | jpg, jpeg, png, webp, gif                |
| `video`    | `chats/videos/`    | 50 MB    | mp4, mov, webm                           |
| `document` | `chats/documents/` | 50 MB    | pdf, doc, docx, xls, xlsx, ppt, txt, zip |

**Object key format**: `{prefix}/{userId}/{uuid}.{ext}`

Ví dụ: `chats/images/abc-123/550e8400-e29b-41d4-a716-446655440000.jpg`

---

## Tóm tắt quan hệ dạng bảng

```
┌──────────────────┬──────────────────────────────────────────────────────────┐
│    Entity A      │    Quan hệ với Entity B                                   │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ users (auth)     │ 1:1 → user_profiles (user_service) [qua Kafka]           │
│ users (auth)     │ 1:1 → user_cache (friend_service) [qua Kafka]            │
│ users (auth)     │ 1:N → friendships (requester)                             │
│ users (auth)     │ 1:N → friendships (addressee)                             │
│ users (auth)     │ 1:N → participants trong conversations                    │
│ users (auth)     │ 1:N → messages (sender)                                  │
│ users (auth)     │ 1:N → reactions trong messages                           │
│ conversations    │ 1:N → messages                                            │
│ messages         │ N:1 → conversations (conversationId)                     │
│ messages         │ self-ref → messages (forwardedFrom.messageId, optional)  │
└──────────────────┴──────────────────────────────────────────────────────────┘
```
