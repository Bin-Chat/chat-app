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
│  │   └─ role: String ENUM('owner','admin','member')  │                    │
│  │   └─ joinedAt: Date                               │                    │
│  │   └─ isBanned: Boolean  (default false)           │                    │
│  │   └─ bannedUntil: Date? (null = vĩnh viễn)        │                    │
│  │   └─ isPinned: Boolean  (default false)           │                    │
│  │   └─ isArchived: Boolean (default false)          │                    │
│  │   └─ isMuted: Boolean   (default false)           │                    │
│  │   └─ muteUntil: Date?                             │                    │
│  │   └─ lastReadAt: Date?                            │                    │
│  │                                                    │                    │
│  │ + settings: ConversationSettings                  │                    │
│  │   └─ onlyAdminCanSend: Boolean (default false)    │                    │
│  │   └─ allowMemberInvite: Boolean (default true)    │                    │
│  │   └─ requireJoinApproval: Boolean (default false) │                    │
│  │   └─ chatHistoryForNewMembers: Boolean (def true) │                    │
│  │   └─ onlyAdminCanPin: Boolean (dynamic, no @Prop)  │                    │
│  │                                                    │                    │
│  │ + pinnedMessages: [PinnedMessage]   (max 50)      │                    │
│  │   └─ messageId: ObjectId                          │                    │
│  │   └─ pinnedBy: String (UUID)                      │                    │
│  │   └─ pinnedAt: Date                               │                    │
│  │                                                    │                    │
│  │ + lastMessage?: LastMessage                        │                    │
│  │   └─ senderId: String                             │                    │
│  │   └─ content: String                              │                    │
│  │   └─ type: String (default 'text')                │                    │
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
│  │ + type: String ENUM default 'text'                │                    │
│  │     'text'|'image'|'video'|'file'|'voice'|'system'│                    │
│  │ + content: String = ''                             │                    │
│  │ + isEdited: Boolean = false                        │                    │
│  │ + editedAt?: Date = null                           │                    │
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
│  │ + replyTo?: ReplyInfo                              │                    │
│  │   └─ messageId: String                            │                    │
│  │   └─ senderId: String                             │                    │
│  │   └─ content: String (trích dẫn, max 100 ký tự)  │                    │
│  │   └─ attachmentType?: String                      │                    │
│  │                                                    │                    │
│  │ + createdAt: Date (auto)                           │                    │
│  │ + updatedAt: Date (auto)                           │                    │
│  │                                                    │                    │
│  │ INDEX: {conversationId:1, createdAt:-1}            │                    │
│  │ INDEX: {conversationId:1, 'reactions.userId':1}    │                    │
│  └────────────────────────────────────────────────────┘                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              Redis                                          │
│                                                                             │
│   Key pattern: otp:pending:{email}           TTL: 900s   Value: "123456"   │
│   Key pattern: otp:{userId}                  TTL: 900s   Value: "123456"   │
│   Key pattern: refresh:{userId}:{deviceId}   TTL: 7d     Value: JWT token  │
│   Key pattern: session:active:{userId}:{type} TTL: 30d   Value: deviceId   │
│   Key pattern: session:device:{userId}:{did}  TTL: 30d   Value: JSON       │
│   Key pattern: session:deviceids:{userId}     TTL: 30d   Value: Set<did>   │
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

| Field            | Type                 | Mô tả                                           |
| ---------------- | -------------------- | ----------------------------------------------- |
| `_id`            | ObjectId             | MongoDB auto-generated ID                       |
| `type`           | String enum          | `'direct'` (2 người) \| `'group'` (nhiều người) |
| `name`           | String?              | Tên nhóm (chỉ group)                            |
| `avatar`         | String?              | Ảnh nhóm (chỉ group)                            |
| `description`    | String?              | Mô tả nhóm (tối đa 500 ký tự, chỉ group)        |
| `participants`   | Participant[]        | Danh sách thành viên (xem subdoc bên dưới)      |
| `settings`       | ConversationSettings | Cài đặt nhóm (owner-only để thay đổi)           |
| `pinnedMessages` | PinnedMessage[]      | Danh sách tin nhắn được ghim (tối đa 50)        |
| `lastMessage`    | LastMessage?         | Preview tin nhắn cuối                           |
| `createdAt`      | Date                 | Auto (timestamps: true)                         |
| `updatedAt`      | Date                 | Auto (timestamps: true)                         |

**Embedded: `Participant`**

| Field         | Type    | Default    | Mô tả                                            |
| ------------- | ------- | ---------- | ------------------------------------------------ |
| `userId`      | String  | —          | UUID của user (ref logic tới auth users.id)      |
| `role`        | String  | `'member'` | `'owner'` \| `'admin'` \| `'member'`             |
| `joinedAt`    | Date    | now        | Ngày tham gia conversation                       |
| `isBanned`    | Boolean | false      | Thành viên đang bị cấm gửi tin                   |
| `bannedUntil` | Date?   | null       | Thời điểm hết hạn ban (null = vĩnh viễn)         |
| `isPinned`    | Boolean | false      | User đã ghim conversation này vào đầu danh sách  |
| `isArchived`  | Boolean | false      | User đã lưu trữ conversation (ẩn khỏi main list) |
| `isMuted`     | Boolean | false      | User đã tắt thông báo của conversation           |
| `muteUntil`   | Date?   | null       | Tắt thông báo đến khi (null = vô thới hạn)       |
| `lastReadAt`  | Date?   | null       | Lần cuối đọc tin nhắn (để tính unread count)     |

**Embedded: `ConversationSettings`** _(chỉ group, owner-only)_

| Field                      | Type    | Default | Mô tả                                       |
| -------------------------- | ------- | ------- | ------------------------------------------- |
| `onlyAdminCanSend`         | Boolean | false   | Chỉ owner/admin được gửi tin                |
| `allowMemberInvite`        | Boolean | true    | Member được thêm thành viên mới             |
| `requireJoinApproval`      | Boolean | false   | Cần owner/admin duyệt khi có người tham gia |
| `chatHistoryForNewMembers` | Boolean | true    | Thành viên mới xem được lịch sử trò chuyện  |
| `onlyAdminCanPin` ¹        | Boolean | false   | Chỉ owner/admin được ghim tin nhắn          |

> ¹ **Không có `@Prop()` trong Mongoose schema** — được đọc/ghi qua `(conv.settings as any)?.onlyAdminCanPin` trong `chat.service.ts`. MongoDB lưu động, TypeScript không có type-safety cho field này.

**Embedded: `PinnedMessage`** _(max 50 per conversation)_

| Field       | Type     | Mô tả                                 |
| ----------- | -------- | ------------------------------------- |
| `messageId` | ObjectId | Ref → messages.\_id                   |
| `pinnedBy`  | String   | UUID người ghim (phải là participant) |
| `pinnedAt`  | Date     | Thời điểm ghim                        |

**Embedded: `LastMessage`**

| Field      | Type   | Mô tả                        |
| ---------- | ------ | ---------------------------- |
| `senderId` | String | UUID người gửi tin cuối      |
| `content`  | String | Text preview (hoặc '[File]') |
| `type`     | String | default `'text'`             |
| `sentAt`   | Date   | Thời điểm gửi                |

**Indexes**:

- `participants.userId`: Tìm conversations của một user
- `lastMessage.sentAt DESC`: Sort theo tin nhắn mới nhất

---

### 6. `messages` — chat_service (MongoDB)

| Field            | Type          | Mô tả                                                                    |
| ---------------- | ------------- | ------------------------------------------------------------------------ |
| `_id`            | ObjectId      | MongoDB auto-generated ID                                                |
| `conversationId` | ObjectId      | FK → conversations.\_id                                                  |
| `senderId`       | String        | UUID người gửi (ref auth users.id)                                       |
| `type`           | String enum   | `'text'\|'image'\|'video'\|'file'\|'voice'\|'system'` (default `'text'`) |
| `content`        | String        | Nội dung text (default `''`)                                             |
| `isEdited`       | Boolean       | Có đã được chỉnh sửa không (default `false`)                             |
| `editedAt`       | Date?         | Thời điểm chỉnh sửa gần nhất (null = chưa chỉnh sửa)                     |
| `revokedAt`      | Date?         | Thời điểm thu hồi (null = chưa thu hồi)                                  |
| `revokedBy`      | String?       | Người/hệ thống thu hồi: `'user'` (người dùng) hoặc `'ai-moderation'` (AI kiểm duyệt) |
| `attachments`    | Attachment[]  | Danh sách file đính kèm                                                  |
| `reactions`      | Reaction[]    | Danh sách emoji reactions                                                |
| `deletedFor`     | String[]      | Mảng userId đã xóa tin (soft delete)                                     |
| `readBy`         | ReadReceipt[] | Mảng userId đã đọc                                                       |
| `forwardedFrom`  | ForwardInfo?  | Metadata nếu là tin chuyển tiếp                                          |
| `replyTo`        | ReplyInfo?    | Metadata tin trả lời (null nếu không phải reply)                         |
| `createdAt`      | Date          | Auto                                                                     |
| `updatedAt`      | Date          | Auto                                                                     |

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

> **Ràng buộc**: mỗi `userId` chỉ có **tối đa 1 reaction** trên mỗi message. Khi toggle cùng emoji → xóa. Khi chọn emoji khác → thay thế (remove + add). Không cho phép nhiều emoji cùng một người.

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

**Indexes**:

- `{ conversationId: 1, createdAt: -1 }`: Tìm tin nhắn theo conversation, sắp xếp mới nhất
- `{ conversationId: 1, 'reactions.userId': 1 }`: Tối ưu toggle reaction

---

### 7. Redis Keys

| Key Pattern                            | TTL  | Value               | Mục đích                                                |
| -------------------------------------- | ---- | ------------------- | ------------------------------------------------------- |
| `otp:pending:{email}`                  | 900s | String 6 chữ số     | OTP xác thực email khi đăng ký                          |
| `otp:{userId}`                         | 900s | String 6 chữ số     | OTP đặt lại mật khẩu                                    |
| `refresh:{userId}:{deviceId}`          | 7d\* | JWT refresh token   | Refresh token per device (\*30d nếu mobile)             |
| `session:active:{userId}:{deviceType}` | 30d  | deviceId            | deviceId active hiện tại theo loại (web/mobile)         |
| `session:device:{userId}:{deviceId}`   | 30d  | JSON DeviceInfo     | Thông tin thiết bị: `{deviceType, deviceName, loginAt}` |
| `session:deviceids:{userId}`           | 30d  | Redis Set<deviceId> | Tập hợp tất cả deviceId của user (quản lý phiên)        |

---

### 8. Gateway In-Memory Store — `activeCalls`

> Không phải database table. Đây là `Map` trong bộ nhớ của tiến trình **api-gateway** (`socket.gateway.ts`), quản lý các phiên gọi đang diễn ra.

```typescript
activeCalls: Map<callId, CallSession>;
```

**CallSession object**:

| Field            | Type                         | Mô tả                                            |
| ---------------- | ---------------------------- | ------------------------------------------------ |
| `callId`         | string                       | UUID do client tạo (random + timestamp)          |
| `conversationId` | string                       | MongoDB ObjectId của conversation                |
| `callType`       | `'audio'` \| `'video'`       | Loại cuộc gọi                                    |
| `callerId`       | string                       | UUID của người khởi tạo cuộc gọi                 |
| `participantIds` | string[]                     | Tất cả userId được mời (không bao gồm caller)    |
| `acceptedIds`    | string[]                     | Tất cả userId đã accept (bao gồm caller tự động) |
| `status`         | `'calling'` \| `'connected'` | Trạng thái cuộc gọi                              |
| `startedAt`      | Date                         | Thời điểm khởi tạo                               |

**Vòng đời**:

```
call:initiate  → activeCalls.set(callId, session)       [created]
call:accept    → session.acceptedIds.push(userId)        [updated]
call:end       → activeCalls.delete(callId)              [deleted]
disconnect     → cleanup calls where user in acceptedIds [auto GC]
```

> **Quan trọng**: `activeCalls` là **ephemeral** (mất khi restart gateway). Không có lịch sử cuộc gọi được lưu vào DB trong phiên bản hiện tại.

> **SessionData** (JSON): `{ userId, deviceId, platform, userAgent, ip, createdAt, lastActiveAt }`
> `deviceId` sinh bởi client lần đầu kết nối và gửi kèm request. TTL mobile dài hơn web vì thiết bị di động ít logout thủ công.

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
       │ Kafka: user.profile_updated
       │ Payload: { id, fullName, avatar, updatedAt }
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
    ├─ chat_service.conversations[].pinnedMessages[].pinnedBy
    ├─ chat_service.messages.senderId
    ├─ chat_service.messages.reactions[].userId
    ├─ chat_service.messages.deletedFor[]
    └─ chat_service.messages.readBy[].userId
```

---

## Upload Policy — AWS S3

Không có database table, S3 object key convention:

| Category   | Prefix             | Max Size | Extensions                                          |
| ---------- | ------------------ | -------- | --------------------------------------------------- |
| `avatar`   | `avatars/`         | 2 MB     | jpg, jpeg, png, webp                                |
| `image`    | `chats/images/`    | 10 MB    | jpg, jpeg, png, webp, gif                           |
| `video`    | `chats/videos/`    | 50 MB    | mp4, mov, webm                                      |
| `document` | `chats/documents/` | 20 MB    | pdf, doc, docx, xls, xlsx, ppt, pptx, txt, zip, rar |

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
│ messages         │ self-ref → messages (forwardedFrom.messageId, optional)  │| conversations    │ self-ref → messages (pinnedMessages[].messageId)          |└──────────────────┴──────────────────────────────────────────────────────────┘
```

---

## Qdrant — ai-service

> **Qdrant** là vector database dùng cho các tính năng AI. Chạy trên port **6333**, sử dụng Docker image `qdrant/qdrant:latest`.

### Collection: `binchat_messages`

Lưu embedding của **tin nhắn chat** phục vụ Semantic Search.

| Payload Field | Type | Mô tả |
|---|---|---|
| `messageId` | `string` | ID tin nhắn (ObjectId) |
| `conversationId` | `string` | ID cuộc trò chuyện |
| `senderId` | `string` | ID người gửi |
| `content` | `string` | Nội dung tin nhắn (plain text) |
| `timestamp` | `string` | ISO datetime gửi tin nhắn |

**Vector:** 1536 chiều (float32), metric **Cosine**, model `text-embedding-3-small`

```json
{
  "id": "<uuid>",
  "vector": [0.123, -0.456, ...],
  "payload": {
    "messageId": "6630abc123...",
    "conversationId": "6630def456...",
    "senderId": "6630ghi789...",
    "content": "Hẹn nhau vào tối thứ 6 nhé",
    "timestamp": "2026-04-19T10:30:00.000Z"
  }
}
```

---

### Collection: `binchat_documents`

Lưu embedding của **tài liệu RAG** phục vụ RAG Bot (hỏi & đáp).

| Payload Field | Type | Mô tả |
|---|---|---|
| `text` | `string` | Nội dung đoạn văn (chunk, ≤500 ký tự) |
| `chunkIndex` | `number` | Thứ tự chunk trong tài liệu gốc |
| `collectionId` | `string` | Nhóm tài liệu (tùy chọn lọc khi query) |
| `source` | `string` | Nguồn tài liệu (URL, tên file...) |
| `title` | `string` | Tiêu đề tài liệu |

**Vector:** 1536 chiều (float32), metric **Cosine**, model `text-embedding-3-small`

---

## Redis — ai-service

> ai-service dùng Redis để cache kết quả OpenAI, giảm chi phí API và tăng tốc độ phản hồi.

| Key Pattern | TTL | Nội dung |
|---|---|---|
| `ai:summary:{conversationId}:{count}:{fromDate}_{toDate}` | **1 giờ** | Chuỗi tóm tắt cuộc trò chuyện có cấu trúc |
| `ai:translate:{md5(text+targetLang)}` | **24 giờ** | Chuỗi văn bản đã dịch |

**Ví dụ key:**
- `ai:summary:6630def456:42:2026-04-13_2026-04-20` — tóm tắt conversation `6630def456` với 42 tin nhắn từ 13/4 đến 20/4
- `ai:summary:6630def456:87:all` — tóm tắt không có date range filter
- `ai:translate:a1b2c3d4e5f6...` — bản dịch của "Hello world" sang `vi`
