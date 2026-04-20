# UML Diagrams — BinChat

> PlantUML source code cho các sơ đồ UML trong báo cáo đồ án.

---

## 3.1.1 — Sơ đồ Use Case Tổng quát

```plantuml
@startuml UC_TONG_QUAT
!theme plain
skinparam actorStyle awesome
skinparam packageStyle rectangle
skinparam usecase {
  BackgroundColor LightYellow
  BorderColor DarkGoldenRod
  ArrowColor Gray
}
skinparam actor {
  BackgroundColor LightBlue
  BorderColor Navy
}

left to right direction

actor "Khách\n(Guest)" as Guest
actor "Người dùng\n(User)" as User
actor "Quản trị nhóm\n(GroupAdmin)" as GroupAdmin
actor "Quản trị hệ thống\n(Admin)" as Admin

User <|-- GroupAdmin : extends

rectangle "BinChat System" {

  package "Xác thực" {
    usecase "Đăng ký tài khoản" as UC_REGISTER
    usecase "Xác thực OTP" as UC_OTP
    usecase "Đăng nhập" as UC_LOGIN
    usecase "Đăng xuất" as UC_LOGOUT
    usecase "Đặt lại mật khẩu" as UC_RESET_PWD
    usecase "Đổi mật khẩu" as UC_CHANGE_PWD
    usecase "Quản lý thiết bị" as UC_DEVICES
  }

  package "Hồ sơ" {
    usecase "Xem hồ sơ cá nhân" as UC_VIEW_PROFILE
    usecase "Cập nhật hồ sơ" as UC_EDIT_PROFILE
    usecase "Đổi ảnh đại diện" as UC_AVATAR
  }

  package "Bạn bè" {
    usecase "Tìm kiếm người dùng" as UC_SEARCH_USER
    usecase "Gửi lời mời kết bạn" as UC_FRIEND_REQ
    usecase "Chấp nhận/Từ chối lời mời" as UC_FRIEND_ACCEPT
    usecase "Hủy lời mời kết bạn" as UC_FRIEND_CANCEL
    usecase "Xóa bạn bè" as UC_UNFRIEND
  }

  package "Nhắn tin" {
    usecase "Mở cuộc trò chuyện trực tiếp" as UC_OPEN_DIRECT
    usecase "Tạo nhóm chat" as UC_CREATE_GROUP
    usecase "Gửi tin nhắn text" as UC_SEND_TEXT
    usecase "Gửi file / ảnh / video" as UC_SEND_FILE
    usecase "Trả lời tin nhắn" as UC_REPLY
    usecase "Chuyển tiếp tin nhắn" as UC_FORWARD
    usecase "Thu hồi tin nhắn" as UC_REVOKE
    usecase "Xóa tin nhắn (phía mình)" as UC_DELETE
    usecase "Chỉnh sửa tin nhắn" as UC_EDIT_MSG
    usecase "Bày tỏ cảm xúc (Reaction)" as UC_REACT
    usecase "Xem lịch sử tin nhắn" as UC_HISTORY
    usecase "Ghim tin nhắn" as UC_PIN
  }

  package "Gọi điện" {
    usecase "Gọi thoại / video" as UC_CALL
    usecase "Chấp nhận cuộc gọi" as UC_ACCEPT_CALL
    usecase "Từ chối cuộc gọi" as UC_REJECT_CALL
    usecase "Kết thúc cuộc gọi" as UC_END_CALL
  }

  package "Quản lý nhóm" {
    usecase "Thêm thành viên" as UC_ADD_MEMBER
    usecase "Xóa thành viên" as UC_KICK_MEMBER
    usecase "Thay đổi vai trò" as UC_CHANGE_ROLE
    usecase "Cấm thành viên" as UC_BAN
    usecase "Cập nhật thông tin nhóm" as UC_UPDATE_GROUP
    usecase "Cài đặt nhóm" as UC_GROUP_SETTINGS
    usecase "Giải tán nhóm" as UC_DISSOLVE
    usecase "Rời nhóm" as UC_LEAVE
  }

  package "Cài đặt cá nhân" {
    usecase "Ghim / Lưu trữ cuộc trò chuyện" as UC_PIN_CONV
    usecase "Tắt thông báo" as UC_MUTE
    usecase "Đọc tin nhắn" as UC_READ
  }
}

' Guest
Guest --> UC_REGISTER
Guest --> UC_OTP
Guest --> UC_LOGIN
Guest --> UC_RESET_PWD

' User
User --> UC_LOGOUT
User --> UC_CHANGE_PWD
User --> UC_DEVICES
User --> UC_VIEW_PROFILE
User --> UC_EDIT_PROFILE
User --> UC_AVATAR
User --> UC_SEARCH_USER
User --> UC_FRIEND_REQ
User --> UC_FRIEND_ACCEPT
User --> UC_FRIEND_CANCEL
User --> UC_UNFRIEND
User --> UC_OPEN_DIRECT
User --> UC_CREATE_GROUP
User --> UC_SEND_TEXT
User --> UC_SEND_FILE
User --> UC_REPLY
User --> UC_FORWARD
User --> UC_REVOKE
User --> UC_DELETE
User --> UC_EDIT_MSG
User --> UC_REACT
User --> UC_HISTORY
User --> UC_CALL
User --> UC_ACCEPT_CALL
User --> UC_REJECT_CALL
User --> UC_END_CALL
User --> UC_PIN_CONV
User --> UC_MUTE
User --> UC_READ
User --> UC_LEAVE

' GroupAdmin
GroupAdmin --> UC_PIN
GroupAdmin --> UC_ADD_MEMBER
GroupAdmin --> UC_KICK_MEMBER
GroupAdmin --> UC_CHANGE_ROLE
GroupAdmin --> UC_BAN
GroupAdmin --> UC_UPDATE_GROUP
GroupAdmin --> UC_GROUP_SETTINGS
GroupAdmin --> UC_DISSOLVE

UC_REGISTER ..> UC_OTP : <<include>>
UC_RESET_PWD ..> UC_OTP : <<include>>
UC_SEND_FILE ..> UC_SEND_TEXT : <<extends>>
UC_REPLY ..> UC_SEND_TEXT : <<extends>>

@enduml
```

---

## 3.1.2 — Danh sách Tác nhân (Actors)

```plantuml
@startuml ACTOR_TABLE
!theme plain
skinparam classBackgroundColor LightYellow
skinparam classBorderColor DarkGoldenRod

class "Danh sách Tác nhân" as T << (T, LightBlue) >> {
  ..Khách (Guest)..
  Người chưa đăng nhập
  Có thể: đăng ký, xác thực OTP,
  đăng nhập, đặt lại mật khẩu
  ---
  ..Người dùng (User)..
  Đã xác thực qua JWT cookie
  Có thể thực hiện mọi tính năng
  cơ bản: nhắn tin, gọi điện,
  kết bạn, quản lý hồ sơ
  ---
  ..Quản trị nhóm (GroupAdmin)..
  Kế thừa từ User
  Có role 'owner' hoặc 'admin'
  trong một group conversation
  Thêm/xóa thành viên, cài đặt
  nhóm, giải tán nhóm
  ---
  ..Quản trị hệ thống (Admin)..
  role = 'admin' trong users table
  Quản lý toàn bộ hệ thống
  (chưa có giao diện Admin UI)
}

note right of T
  Phân quyền được kiểm tra bởi:
  - JwtAuthGuard (JWT cookie)
  - GroupRoleGuard (role trong conversation)
  - RolesGuard (system role)
end note

@enduml
```

---

## 3.1.3 — Danh sách Use Cases

```plantuml
@startuml UC_LIST
!theme plain
skinparam classBackgroundColor LightCyan
skinparam classBorderColor SteelBlue

class "UC01 — Đăng ký tài khoản" { }
class "UC02 — Xác thực OTP" { }
class "UC03 — Đăng nhập" { }
class "UC04 — Đăng xuất" { }
class "UC05 — Đặt lại mật khẩu" { }
class "UC06 — Đổi mật khẩu" { }
class "UC07 — Quản lý thiết bị đăng nhập" { }
class "UC08 — Xem / Cập nhật hồ sơ" { }
class "UC09 — Đổi ảnh đại diện" { }
class "UC10 — Tìm kiếm người dùng" { }
class "UC11 — Gửi / Hủy lời mời kết bạn" { }
class "UC12 — Chấp nhận / Từ chối lời mời" { }
class "UC13 — Xóa bạn bè" { }
class "UC14 — Mở cuộc trò chuyện trực tiếp" { }
class "UC15 — Tạo nhóm chat" { }
class "UC16 — Gửi tin nhắn text" { }
class "UC17 — Gửi file / ảnh / video" { }
class "UC18 — Trả lời tin nhắn (Reply)" { }
class "UC19 — Chuyển tiếp tin nhắn (Forward)" { }
class "UC20 — Thu hồi tin nhắn" { }
class "UC21 — Xóa tin nhắn phía mình" { }
class "UC22 — Chỉnh sửa tin nhắn" { }
class "UC23 — Reaction emoji" { }
class "UC24 — Xem lịch sử tin nhắn" { }
class "UC25 — Ghim tin nhắn" { }
class "UC26 — Gọi thoại / video" { }
class "UC27 — Chấp nhận / Từ chối cuộc gọi" { }
class "UC28 — Kết thúc cuộc gọi" { }
class "UC29 — Thêm / Xóa thành viên nhóm" { }
class "UC30 — Thay đổi vai trò thành viên" { }
class "UC31 — Cấm thành viên (Ban)" { }
class "UC32 — Cập nhật thông tin nhóm" { }
class "UC33 — Cài đặt quyền nhóm" { }
class "UC34 — Giải tán nhóm" { }
class "UC35 — Rời nhóm" { }
class "UC36 — Ghim / Lưu trữ cuộc trò chuyện" { }
class "UC37 — Tắt thông báo (Mute)" { }
class "UC38 — Đánh dấu đã đọc" { }

@enduml
```

---

## 3.1.4 — Sơ đồ Hoạt động (Activity Diagrams)

### 3.1.4.1 — Đăng ký & Xác thực OTP

```plantuml
@startuml ACT_REGISTER
!theme plain
skinparam activityBackgroundColor LightYellow
skinparam activityBorderColor DarkGoldenRod

start

:Người dùng nhập email + mật khẩu + fullName;
:Client gọi POST /api/auth/register;

if (Email đã tồn tại?) then (có)
  :Trả về 409 Conflict;
  stop
else (không)
  :Auth service hash mật khẩu (bcrypt);
  :Tạo user mới (isEmailVerified = false);
  :Sinh OTP 6 chữ số;
  :Lưu OTP vào Redis\n(key: otp:pending:{email}, TTL: 900s);
  :Kafka emit: notification.email\n(type: email_verification, to: email);
  :Notification service gửi email OTP;
  :Trả về 201 Created;
  :Hiển thị màn hình nhập OTP;

  :Người dùng nhập OTP;
  :Client gọi POST /api/auth/verify-registration;

  if (OTP hết hạn?) then (có)
    :Trả về 400 Bad Request;
    stop
  else (không)
    if (OTP khớp?) then (không)
      :Trả về 400 Bad Request;
      stop
    else (có)
      :Set isEmailVerified = true;
      :Xóa OTP khỏi Redis;
      :Kafka emit: user.registered\n(id, email, fullName, role, createdAt);
      :user-service tạo UserProfile;
      :friend-service tạo UserCache;
      :Kafka emit: notification.email\n(type: welcome, to: email);
      :Trả về 200 OK;
      :Redirect tới trang đăng nhập;
    endif
  endif
endif

stop
@enduml
```

### 3.1.4.2 — Đăng nhập

```plantuml
@startuml ACT_LOGIN
!theme plain
skinparam activityBackgroundColor LightCyan
skinparam activityBorderColor SteelBlue

start

:Người dùng nhập email + mật khẩu;
:Client gọi POST /api/auth/login\n(kèm deviceId, deviceType, deviceName);

:Auth service tìm user theo email;

if (User tồn tại?) then (không)
  :Trả về 401 Unauthorized;
  stop
else (có)
  if (Mật khẩu đúng?) then (không)
    :Trả về 401 Unauthorized;
    stop
  else (có)
    if (Email đã xác thực?) then (không)
      :Trả về 403 Forbidden;
      stop
    else (có)
      :Kiểm tra thiết bị active cùng type;
      if (Đã có thiết bị active cùng type?) then (có)
        :Xóa refresh token thiết bị cũ;
        :Xóa device info thiết bị cũ;
        :Emit auth.session.kicked\ncho thiết bị cũ qua Kafka;
      else (không)
      endif

      :Tạo Access Token (JWT, 15 phút);
      :Tạo Refresh Token (JWT, 7d/30d);
      :Lưu refresh token vào Redis;
      :Set session:active:{userId}:{deviceType};
      :Lưu device info vào Redis;
      :Set cookie httpOnly:\naccessToken + refreshToken;
      :Trả về 200 OK + user info;
      :Client kết nối Socket.io\n(gửi JWT cookie tự động);
      :Hiển thị trang chính;
    endif
  endif
endif

stop
@enduml
```

### 3.1.4.3 — Gửi Tin nhắn

```plantuml
@startuml ACT_SEND_MSG
!theme plain
skinparam activityBackgroundColor LightGreen
skinparam activityBorderColor DarkGreen

start

:Người dùng nhập nội dung tin nhắn;

if (Có file đính kèm?) then (có)
  :Client gọi POST /api/upload/presign\n(category, filename, mimeType, size);
  :Upload service kiểm tra file policy;

  if (File hợp lệ?) then (không)
    :Trả về 400 Bad Request;
    stop
  else (có)
    :Tạo presigned URL S3\n(TTL 5 phút);
    :Client PUT file trực tiếp lên S3;
    :Client gọi POST /api/upload/finalize\n(key, category);
    :Upload service tạo CloudFront URL;

    if (Category = video?) then (có)
      :Lambda video-dispatcher xử lý\nasync: tạo __360p.mp4 + __thumb.jpg;
    else (không)
    endif

    if (Category = image/avatar?) then (có)
      :Lambda image-processor tạo\ncác variant size;
    else (không)
    endif
  endif
else (không)
endif

:Client emit socket event: message:send\n(conversationId, content, type,\nattachments?, replyTo?);

:API Gateway xác thực JWT cookie;

if (JWT hợp lệ?) then (không)
  :Phát socket lỗi;
  stop
else (có)
  :Chat service lưu message vào MongoDB;
  :Cập nhật lastMessage trong Conversation;
  :Kafka emit: chat.message.created;
  :API Gateway broadcast message:new\ntới tất cả participants online;
  :Notification service gửi email\n(nếu participant offline);
  :Client cập nhật Redux state\n/ Zustand store;
  :Hiển thị tin nhắn trong ChatRoom;
endif

stop
@enduml
```

### 3.1.4.4 — Gọi Voice/Video

```plantuml
@startuml ACT_CALL
!theme plain
skinparam activityBackgroundColor LightYellow
skinparam activityBorderColor Orange

start

:Người dùng bấm nút gọi (audio/video);
:Client sinh callId (UUID + timestamp);
:Client emit: call:initiate\n(callId, conversationId, callType, participantIds);

:API Gateway lưu CallSession vào activeCalls Map;
:Gateway emit: call:incoming\ntới tất cả participantIds online;

fork
  :Người nhận thấy IncomingCallModal;
  :Người nhận emit: call:accept / call:reject;
  if (Accept?) then (có)
    :Gateway thêm userId vào acceptedIds;
    :Gateway emit: call:accepted tới caller;
    :Cả hai bên khởi tạo RTCPeerConnection\n(ICE: Google STUN + coturn TURN);
    :Trao đổi WebRTC offer/answer/ICE\nqua call:signal relay;
    :Kết nối P2P WebRTC thiết lập;
    :Cuộc gọi diễn ra;
  else (reject)
    :Gateway emit: call:rejected tới caller;
    :Caller thấy thông báo từ chối;
    stop
  endif
fork again
  if (Không có ai online?) then (có)
    :Gateway emit: call:busy tới caller;
    :Caller thấy thông báo bận;
    stop
  else (không)
  endif
end fork

:Người dùng bấm kết thúc;
:Client emit: call:end;
:Gateway emit: call:ended tới tất cả;
:Gateway xóa CallSession khỏi activeCalls;
:Đóng RTCPeerConnection hai phía;

stop
@enduml
```

---

## 3.2 — Sơ đồ Lớp (Class Diagram)

```plantuml
@startuml CLASS_DIAGRAM
!theme plain
skinparam classBackgroundColor LightYellow
skinparam classBorderColor DarkGoldenRod
skinparam packageBackgroundColor LightCyan
skinparam packageBorderColor SteelBlue
skinparam linetype ortho

package "auth_service (PostgreSQL)" {
  class User {
    +id: UUID <<PK>>
    +email: VARCHAR(255) <<UNIQUE>>
    +passwordHash: VARCHAR
    +fullName: VARCHAR
    +isActive: Boolean = true
    +isEmailVerified: Boolean = false
    +role: ENUM('user','admin')
    +createdAt: TIMESTAMP
    +updatedAt: TIMESTAMP
  }
}

package "user_service (PostgreSQL)" {
  class UserProfile {
    +id: UUID <<PK, Kafka sync>>
    +email: VARCHAR(255) <<UNIQUE>>
    +fullName: VARCHAR
    +avatar: VARCHAR
    +phone: VARCHAR(20)
    +bio: TEXT
    +role: VARCHAR(20) = 'user'
    +isActive: Boolean = true
    +createdAt: TIMESTAMP
    +updatedAt: TIMESTAMP
  }
}

package "friend_service (PostgreSQL)" {
  class UserCache {
    +id: UUID <<PK, Kafka sync>>
    +email: VARCHAR(255) <<UNIQUE>>
    +fullName: VARCHAR
    +avatar: VARCHAR
    +isActive: Boolean = true
    +createdAt: TIMESTAMP
    +updatedAt: TIMESTAMP
  }

  class Friendship {
    +id: UUID <<PK>>
    +requesterId: UUID <<FK→UserCache>>
    +addresseeId: UUID <<FK→UserCache>>
    +status: ENUM
    +createdAt: TIMESTAMP
    +updatedAt: TIMESTAMP
    --
    status values:
    'pending' | 'accepted'
    'declined' | 'blocked'
    ..
    UNIQUE(requesterId, addresseeId)
  }
}

package "chat_service (MongoDB)" {
  class Conversation {
    +_id: ObjectId <<PK>>
    +type: String ('direct'|'group')
    +name: String?
    +avatar: String?
    +description: String?
    +participants: Participant[]
    +settings: ConversationSettings
    +pinnedMessages: PinnedMessage[]
    +lastMessage: LastMessage?
    +createdAt: Date
    +updatedAt: Date
    --
    INDEX: participants.userId
    INDEX: lastMessage.sentAt DESC
  }

  class Participant <<embedded>> {
    +userId: String
    +role: String ('owner'|'admin'|'member')
    +joinedAt: Date = now
    +isBanned: Boolean = false
    +bannedUntil: Date?
    +isPinned: Boolean = false
    +isArchived: Boolean = false
    +isMuted: Boolean = false
    +muteUntil: Date?
    +lastReadAt: Date?
  }

  class ConversationSettings <<embedded>> {
    +onlyAdminCanSend: Boolean = false
    +allowMemberInvite: Boolean = true
    +requireJoinApproval: Boolean = false
    +chatHistoryForNewMembers: Boolean = true
    +onlyAdminCanPin: Boolean = false †
    --
    † stored dynamically (no @Prop)
  }

  class PinnedMessage <<embedded>> {
    +messageId: String
    +pinnedBy: String
    +pinnedAt: Date
  }

  class LastMessage <<embedded>> {
    +senderId: String
    +content: String
    +type: String = 'text'
    +sentAt: Date
  }

  class Message {
    +_id: ObjectId <<PK>>
    +conversationId: ObjectId <<FK>>
    +senderId: String
    +type: String = 'text'
    +content: String = ''
    +isEdited: Boolean = false
    +editedAt: Date?
    +revokedAt: Date?
    +attachments: Attachment[]
    +reactions: Reaction[]
    +deletedFor: String[]
    +readBy: ReadReceipt[]
    +forwardedFrom: ForwardInfo?
    +replyTo: ReplyInfo?
    +createdAt: Date
    +updatedAt: Date
    --
    INDEX: {conversationId:1, createdAt:-1}
    INDEX: {conversationId:1, reactions.userId:1}
  }

  class Attachment <<embedded>> {
    +url: String
    +type: String ('image'|'video'|'file')
    +filename: String
    +size: Number
    +mimeType: String
    +width: Number?
    +height: Number?
    +duration: Number?
    +thumbnailUrl: String?
  }

  class Reaction <<embedded>> {
    +userId: String
    +emoji: String
  }

  class ReadReceipt <<embedded>> {
    +userId: String
    +readAt: Date
  }

  class ForwardInfo <<embedded>> {
    +messageId: String
    +conversationId: String
    +senderId: String
  }

  class ReplyInfo <<embedded>> {
    +messageId: String
    +senderId: String
    +content: String
    +attachmentType: String?
  }
}

' Relationships
User "1" -right-> "1" UserProfile : Kafka sync\nuser.registered
User "1" -right-> "1" UserCache : Kafka sync\nuser.registered
UserProfile "1" --> "1" UserCache : Kafka sync\nuser.profile_updated
UserCache "1" -down-> "*" Friendship : requester
UserCache "1" -down-> "*" Friendship : addressee

Conversation "1" *-down- "*" Participant : contains
Conversation "1" *-down- "1" ConversationSettings : has
Conversation "1" *-down- "*" PinnedMessage : pins (max 50)
Conversation "1" *-right- "0..1" LastMessage : preview
Conversation "1" -down-> "*" Message : has

Message "1" *-down- "*" Attachment : contains
Message "1" *-down- "*" Reaction : has
Message "1" *-down- "*" ReadReceipt : tracked by
Message "1" *-right- "0..1" ForwardInfo : from
Message "1" *-right- "0..1" ReplyInfo : replies to

@enduml
```

---

## 3.3 — Sơ đồ Triển khai (Deployment Diagram)

```plantuml
@startuml DEPLOYMENT
!theme plain
skinparam nodeBackgroundColor LightYellow
skinparam nodeBorderColor DarkGoldenRod
skinparam databaseBackgroundColor LightBlue
skinparam databaseBorderColor Navy
skinparam cloudBackgroundColor LightGreen
skinparam cloudBorderColor DarkGreen
skinparam componentBackgroundColor LightCyan
skinparam componentBorderColor SteelBlue

cloud "Client Layer" {
  node "Web Browser" as WEB {
    component "React 18\n+ Vite\n+ Redux Toolkit\n+ Socket.io-client 4.6\n+ Tailwind CSS" as WebApp
  }

  node "Mobile Device" as MOBILE {
    component "React Native 0.81\n+ Expo 54\n+ Zustand\n+ Socket.io-client 4.7\n+ Expo Router" as MobileApp
  }
}

cloud "AWS Cloud" as AWS {
  node "S3 Bucket" as S3 {
    database "Object Storage\n(avatars/, chats/images/\nchats/videos/, chats/documents/)" as S3DB
  }

  node "CloudFront CDN" as CF {
    component "Edge Distribution\n(global cache)" as CDN
  }

  node "Lambda" as LAMBDA {
    component "image-processor\n(avatar variants)" as ImgLambda
    component "video-dispatcher\n(__360p, __thumb)" as VidLambda
  }
}

node "Docker Host (VPS / Local)" as DOCKER {

  node "api-gateway :3000" as GW {
    component "NestJS\nHTTP Proxy\nSocket.io Gateway\nJWT Auth\nactiveCalls Map" as GWApp
  }

  node "auth-service :3010" as AUTH {
    component "NestJS\nJWT / Bcrypt\nRedis Session\nKafka Producer" as AuthApp
  }

  node "user-service :3020" as USER {
    component "NestJS\nProfile Management\nKafka Consumer" as UserApp
  }

  node "friend-service :3025" as FRIEND {
    component "NestJS\nFriendship Logic\nKafka Producer/Consumer" as FriendApp
  }

  node "upload-service :3035" as UPLOAD {
    component "NestJS\nS3 Presign\nFile Policy\nKafka Consumer" as UploadApp
  }

  node "chat-service :3040" as CHAT {
    component "NestJS\nMessage / Conversation\nKafka Producer" as ChatApp
  }

  node "notification-service :3030" as NOTIF {
    component "NestJS\nNodemailer\nKafka Consumer" as NotifApp
  }

  node "coturn :3478/5349" as TURN {
    component "coturn 4.6.2\nSTUN + TURN server\nWebRTC relay" as TURNApp
  }

  database "PostgreSQL 15\n:5432" as PG {
    database "auth_service DB" as PGAUTH
    database "user_service DB" as PGUSER
    database "friend_service DB" as PGFRIEND
  }

  database "MongoDB 7\n:27017" as MONGO {
    database "chat DB\n(conversations, messages)" as MONGOCHAT
  }

  database "Redis 7\n:6379" as REDIS {
    database "Session / OTP / Device cache" as REDISDB
  }

  node "Redpanda (Kafka)\n:9092" as KAFKA {
    component "Topics:\nuser.registered\nuser.profile_updated\nfriend.request.*\nnotification.email\nchat.message.*\nupload.avatar_deleted\nauth.session.kicked" as KAFKATopics
  }
}

' Client → Gateway
WebApp -down-> GWApp : HTTPS :443\nWebSocket (WSS)
MobileApp -down-> GWApp : HTTPS :443\nWebSocket (WSS)

' Gateway → Services (HTTP proxy)
GWApp -down-> AuthApp : HTTP :3010
GWApp -down-> UserApp : HTTP :3020
GWApp -down-> FriendApp : HTTP :3025
GWApp -down-> UploadApp : HTTP :3035
GWApp -down-> ChatApp : HTTP :3040

' Services → Databases
AuthApp --> PGAUTH : TypeORM
UserApp --> PGUSER : TypeORM
FriendApp --> PGFRIEND : TypeORM
ChatApp --> MONGOCHAT : Mongoose
AuthApp --> REDISDB : ioredis

' Services → Kafka
AuthApp --> KAFKATopics : produce
UserApp --> KAFKATopics : produce / consume
FriendApp --> KAFKATopics : produce / consume
ChatApp --> KAFKATopics : produce
NotifApp --> KAFKATopics : consume
UploadApp --> KAFKATopics : consume

' Upload → AWS
UploadApp -right-> S3DB : AWS SDK S3\n(presign + delete)
S3DB --> CDN : origin
CDN -left-> WebApp : CDN URL (GET)
CDN -left-> MobileApp : CDN URL (GET)
S3DB --> ImgLambda : S3 trigger (PUT avatar)
S3DB --> VidLambda : S3 trigger (PUT video)

' WebRTC
WebApp .right.> TURNApp : WebRTC\nICE/TURN :3478
MobileApp .right.> TURNApp : WebRTC\nICE/TURN :3478

@enduml
```

---

> **Công cụ render:** Dán code vào [PlantUML Online Editor](https://www.plantuml.com/plantuml/uml/) hoặc dùng VS Code extension **PlantUML** (jebbs.plantuml).
>
> **Lưu ý:** Section 3.1.2 dùng class diagram style để trình bày bảng tác nhân do PlantUML không có table native.
