# Đóng Góp Của Các Thành Viên — BinChat

> Tổng hợp chi tiết từ lịch sử commit (file-level) của **11 repository**:
> `root`, `apps/web`, `apps/mobile`, `services/auth`, `services/chat`, `services/user`, `services/friend`, `services/upload`, `services/notification`, `gateway`, `infrastructure`.

---

## 1. Đào Ngọc Anh

**GitHub:** `DaoNgocAnh25092004` | **Email:** `daongocanh25092004@gmail.com`

### Quản lý dự án & DevOps

| Ngày       | Repo | Công việc cụ thể                                                                         |
| ---------- | ---- | ---------------------------------------------------------------------------------------- |
| 2026-02-07 | root | Khởi tạo repo gốc, cấu hình submodules, thiết lập workspace                              |
| 2026-02-07 | root | Viết script `setup-submodules.bat` cài đặt dependencies tự động (nhiều lần cải tiến)     |
| 2026-03-02 | root | Cập nhật submodule reference cho gateway                                                 |
| 2026-03-24 | root | Cập nhật toàn bộ submodule references                                                    |
| 2026-04-07 | root | Thêm submodule chat, friend, upload vào repo gốc                                         |
| 2026-04-07 | root | Viết tài liệu luồng upload (`UPLOAD_FLOW.md`) và script deploy Lambda                    |
| 2026-04-14 | root | Cập nhật `run-all.bat`: cải thiện quản lý dependencies, khởi động infrastructure         |
| 2026-04-14 | root | Cập nhật tài liệu system messages                                                        |
| 2026-04-20 | root | Viết tài liệu UML kiến trúc hiện tại và kiến trúc tối ưu (EC2, CI/CD)                    |
| 2026-05-07 | root | Triển khai tính năng AI: seeding tài liệu, index messages, rewrite, summarize, translate |
| 2026-05-07 | root | Cải thiện `setup-submodules.bat` với xử lý lỗi                                           |
| 2026-05-17 | root | Cập nhật submodule commits (mobile, web, chat, upload)                                   |

### services/auth

| Ngày       | Công việc cụ thể                                                                                                    |
| ---------- | ------------------------------------------------------------------------------------------------------------------- |
| 2026-02-07 | Khởi tạo auth service                                                                                               |
| 2026-03-24 | Hoàn thiện toàn bộ tính năng **xác thực & phân quyền**: đăng ký, đăng nhập, JWT access/refresh token, bảo vệ routes |
| 2026-04-14 | Thêm **quản lý thiết bị**: liệt kê thiết bị đang đăng nhập, đăng xuất từ xa (remote logout)                         |

### services/user

| Ngày       | Công việc cụ thể                                                                       |
| ---------- | -------------------------------------------------------------------------------------- |
| 2026-03-24 | Tích hợp **Kafka**: broadcast dữ liệu user sau khi đăng ký để các service khác đồng bộ |
| 2026-04-07 | Refactor cấu trúc code user service                                                    |

### services/upload

| Ngày       | Công việc cụ thể                                                                                |
| ---------- | ----------------------------------------------------------------------------------------------- |
| 2026-04-07 | Hoàn thiện **upload file lên S3 + Lambda**: hình ảnh, video, file tài liệu (presigned URL flow) |
| 2026-05-17 | Thêm **hỗ trợ audio**: cập nhật file policy và DTO cho category `audio`                         |

### services/chat (khởi tạo)

| Ngày       | Công việc cụ thể                                                         |
| ---------- | ------------------------------------------------------------------------ |
| 2026-04-07 | Khởi tạo chat service: NestJS framework, kết nối MongoDB, tích hợp Kafka |
| 2026-05-17 | Thêm type `audio` vào schema attachment và message types trong MongoDB   |

### gateway

| Ngày       | Công việc cụ thể                                                     |
| ---------- | -------------------------------------------------------------------- |
| 2026-03-24 | Fix JWT strategy: trích xuất token từ cookie, bảo vệ routes `/users` |

### infrastructure

| Ngày       | Công việc cụ thể                                                            |
| ---------- | --------------------------------------------------------------------------- |
| 2026-03-24 | Tạo **database riêng biệt** cho từng microservice (PostgreSQL init scripts) |

### services/ai (thuộc root repo)

| Ngày       | Công việc cụ thể                                                                                                      |
| ---------- | --------------------------------------------------------------------------------------------------------------------- |
| 2026-05-07 | **AI Service**: seeding tài liệu, index tin nhắn vào vector store, rewrite tin nhắn, tóm tắt hội thoại, dịch ngôn ngữ |

---

## 2. Lê Thị Thuý Hiền

**GitHub:** `LeTThuyHien` | **Email:** `thuyhienle1664@gmail.com`

### apps/web (Frontend Web)

| Ngày       | Công việc cụ thể                                                                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-03-24 | Hoàn thiện UI & logic: **đăng ký, đăng nhập, quên mật khẩu**, layout tổng thể, tích hợp JWT                                                      |
| 2026-04-07 | Implement **friend service** (gửi/chấp nhận lời mời kết bạn), **chat service** (gửi/nhận tin nhắn), socket.io client, Redux slices quản lý state |
| 2026-04-14 | Tính năng **đếm tin chưa đọc**, đánh dấu hội thoại đã đọc                                                                                        |
| 2026-04-14 | Thêm **quản lý thiết bị** trong trang cài đặt (xem và đăng xuất thiết bị)                                                                        |
| 2026-04-20 | **WebRTC**: modal cuộc gọi đến (incoming call), luồng gọi thoại/video                                                                            |
| 2026-05-07 | **AI Modals**: tìm kiếm thông minh, tóm tắt hội thoại, viết lại tin nhắn, dịch ngôn ngữ                                                          |
| 2026-05-15 | **Voice message (web)**: ghi âm giọng nói, hiển thị tin nhắn audio trong chat                                                                    |
| 2026-05-15 | Thêm type `voice` vào attachment của chat service (phía web)                                                                                     |
| 2026-05-17 | **Audio message** hoàn chỉnh: hỗ trợ phát lại, chuyển đổi định dạng WAV, UI audio bubble                                                         |

### services/chat

| Ngày       | Công việc cụ thể                                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 2026-04-07 | Implement đầy đủ **chat service**: quản lý conversation (tạo, lấy danh sách, chi tiết), quản lý message (gửi, nhận, phân trang) |
| 2026-04-14 | **Chỉnh sửa tin nhắn** (edit), **ghim tin nhắn** (pin), **cấm thành viên** (ban), cập nhật DTO và schema MongoDB                |
| 2026-04-20 | **System messages**: xử lý tin nhắn hệ thống (thêm/xóa thành viên, đổi tên nhóm...), cập nhật schema                            |
| 2026-05-07 | Tích hợp **AI Moderation consumer** (Kafka), cải thiện xử lý thu hồi tin nhắn                                                   |

### services/notification

| Ngày       | Công việc cụ thể                                                                              |
| ---------- | --------------------------------------------------------------------------------------------- |
| 2026-03-24 | Implement **notification service**: gửi email xác nhận đăng ký, gửi email quên mật khẩu (OTP) |
| 2026-04-20 | Fix lỗi package dependencies                                                                  |

### apps/mobile

| Ngày       | Công việc cụ thể                                                       |
| ---------- | ---------------------------------------------------------------------- |
| 2026-05-15 | Cài đặt dependencies: `expo-av`, `expo-haptics`                        |
| 2026-05-15 | **Voice message (mobile)**: ghi âm, gửi và hiển thị tin nhắn giọng nói |
| 2026-05-15 | Thêm category `voice` vào upload service phía mobile                   |

---

## 3. Đoàn Ngọc Bảo Uyên

**GitHub:** `Doanngocbaouyen` | **Email:** `baouyenak@gmail.com`

### apps/mobile (Frontend Mobile — React Native / Expo)

| Ngày       | Công việc cụ thể                                                                                                                                                                                                             |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-04-07 | Thiết lập nền tảng mobile: **auth service** (đăng nhập/đăng ký trên app), **chat service** (gửi/nhận tin nhắn), **friend service** (kết bạn), **upload service** (chọn và upload file), **state management** (Redux/Zustand) |
| 2026-04-14 | **Quản lý nhóm nâng cao**: ban/unban thành viên, quản lý cài đặt nhóm (đổi tên, đổi ảnh, phân quyền)                                                                                                                         |
| 2026-04-14 | **Chỉnh sửa tin nhắn**: UI và logic sửa tin nhắn đã gửi                                                                                                                                                                      |
| 2026-04-20 | **Cuộc gọi (WebRTC)**: luồng thực hiện cuộc gọi, nhận cuộc gọi đến, signaling, tích hợp WebRTC trên mobile                                                                                                                   |
| 2026-05-07 | **Tạo nhóm**: giới hạn số thành viên, tự động tạo tên nhóm từ danh sách thành viên được chọn                                                                                                                                 |
| 2026-05-17 | **Voice recording & playback hoàn chỉnh**: ghi âm, lưu file, upload, phát lại tin nhắn audio trên mobile                                                                                                                     |

### services/auth

| Ngày       | Công việc cụ thể                                                               |
| ---------- | ------------------------------------------------------------------------------ |
| 2026-04-07 | Thêm tính năng **đổi mật khẩu**, cập nhật API lấy thông tin profile người dùng |

---

## 4. Lê Tấn Phong

**GitHub:** `LeTanPhong3003` | **Email:** `letanphong400@gmail.com`

### gateway (API Gateway + WebSocket Server)

| Ngày       | Công việc cụ thể                                                                                                                                                                                                                                                                                                                                                                                |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-04-07 | Thiết lập toàn bộ **API Gateway**: cấu hình biến môi trường cho user, friend, upload service; cập nhật dependencies; tích hợp **Socket.io** real-time; implement **Kafka microservice** xử lý friend events; thêm proxy endpoints cho friend và upload service; tạo **chat/friend event consumers** để đẩy sự kiện real-time đến client; xử lý **group events** (tạo nhóm, thêm/xóa thành viên) |
| 2026-04-14 | Tính năng **typing indicator** (hiển thị "đang gõ"), xử lý sự kiện `session-kicked` khi đăng xuất từ xa                                                                                                                                                                                                                                                                                         |
| 2026-04-20 | **Call signaling**: xử lý toàn bộ luồng tín hiệu cuộc gọi (offer, answer, ICE candidate, hang up) qua WebSocket                                                                                                                                                                                                                                                                                 |
| 2026-05-07 | Thêm **proxy routes cho AI service**: định tuyến các request tới AI service, cấu hình URL service AI                                                                                                                                                                                                                                                                                            |
| 2026-05-21 | **Join Approval — Gateway**: thêm 3 Kafka consumers (`handleJoinRequested`, `handleJoinApproved`, `handleJoinDeclined`) → emit Socket.io `group:join_requested/approved/declined` tới đúng target (adminIds / requester / all participants)                                                                                                                                                     |

### services/chat (Join Approval)

| Ngày       | Công việc cụ thể                                                                                                                                                                                                                                                                                                                                                |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-21 | **Duyệt thành viên mới — Backend**: thêm schema `pendingMembers`, `inviteToken`, `inviteEnabled`; 3 Kafka events (`GROUP_JOIN_REQUESTED/APPROVED/DECLINED`); 7 service methods (`generateInviteLink`, `revokeInviteLink`, `joinByToken`, `getPendingJoinRequests`, `approveJoinRequest`, `declineJoinRequest`, `cancelJoinRequest`); 7 REST endpoints tương ứng |
| 2026-05-21 | **Fix nghiệp vụ `addMembers`**: member thêm người khi `requireJoinApproval=true` → đưa vào hàng chờ `pendingMembers`, emit `GROUP_JOIN_REQUESTED` (admin/owner vẫn bypass)                                                                                                                                                                                      |
| 2026-05-21 | **Fix nghiệp vụ `transferOwnership`**: tự động unban thành viên bị cấm khi được nhường quyền Chủ nhóm                                                                                                                                                                                                                                                           |

### services/friend

| Ngày       | Công việc cụ thể                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------ |
| 2026-04-07 | Implement **friend service**: logic gửi lời mời kết bạn, chấp nhận/từ chối lời mời, quản lý danh sách bạn bè |

### infrastructure

| Ngày       | Công việc cụ thể                                                                                                           |
| ---------- | -------------------------------------------------------------------------------------------------------------------------- |
| 2026-04-07 | Hoàn thiện **AWS Lambda functions**: `image-processor` (resize/optimize ảnh), `video-dispatcher` (xử lý và dispatch video) |

---

## Tổng hợp phân công theo tính năng

| Tính năng / Module                                                                                                   | Thành viên thực hiện            |
| -------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| Kiến trúc & DevOps (Docker, scripts, submodules)                                                                     | Đào Ngọc Anh                    |
| Authentication & Authorization (JWT, refresh token, register/login)                                                  | Đào Ngọc Anh                    |
| User Service (Kafka broadcast)                                                                                       | Đào Ngọc Anh                    |
| Upload Service (S3 + presigned URL, Lambda trigger)                                                                  | Đào Ngọc Anh                    |
| AI Service (search, rewrite, summarize, translate)                                                                   | Đào Ngọc Anh                    |
| Database initialization (PostgreSQL, schema tách biệt từng service)                                                  | Đào Ngọc Anh                    |
| Tài liệu kỹ thuật (UML, architecture docs)                                                                           | Đào Ngọc Anh                    |
| Web UI (auth, layout, Redux, friend/chat UI)                                                                         | Lê Thị Thuý Hiền                |
| Web UI (incoming call, AI modals, device management)                                                                 | Lê Thị Thuý Hiền                |
| Web UI (voice recording & audio playback)                                                                            | Lê Thị Thuý Hiền                |
| Chat Service (conversation, message CRUD, pin, ban, edit)                                                            | Lê Thị Thuý Hiền                |
| Chat Service (system messages, AI moderation, audio type)                                                            | Lê Thị Thuý Hiền & Đào Ngọc Anh |
| Notification Service (email OTP)                                                                                     | Lê Thị Thuý Hiền                |
| Mobile App (auth, chat, friend, upload, state management)                                                            | Đoàn Ngọc Bảo Uyên              |
| Mobile App (group management, ban/unban, edit message)                                                               | Đoàn Ngọc Bảo Uyên              |
| Mobile App (WebRTC calls, create group)                                                                              | Đoàn Ngọc Bảo Uyên              |
| Mobile App (voice recording & audio playback)                                                                        | Đoàn Ngọc Bảo Uyên              |
| Auth Service (change password, profile API)                                                                          | Đoàn Ngọc Bảo Uyên              |
| API Gateway (Socket.io, Kafka, proxy, event consumers)                                                               | Lê Tấn Phong                    |
| API Gateway (typing indicator, call signaling, AI proxy)                                                             | Lê Tấn Phong                    |
| Friend Service (friend request logic)                                                                                | Lê Tấn Phong                    |
| AWS Lambda (image-processor, video-dispatcher)                                                                       | Lê Tấn Phong                    |
| Poll/Voting — Chat Service (schema, DTOs, service, controller)                                                       | Đào Ngọc Anh                    |
| Poll/Voting — Gateway (Kafka → Socket.io bridge cho poll events)                                                     | Lê Tấn Phong                    |
| Poll/Voting — Web UI (PollBubble, CreatePollModal, Redux wiring)                                                     | Lê Thị Thuý Hiền                |
| Poll/Voting — Mobile UI (PollBubble, CreatePollModal, store wiring)                                                  | Đoàn Ngọc Bảo Uyên              |
| Join Approval — Chat Service (schema, events, 7 service methods, REST endpoints, addMembers & transferOwnership fix) | Lê Tấn Phong                    |
| Join Approval — Gateway (3 Kafka→Socket.io consumers cho join events)                                                | Lê Tấn Phong                    |
| Join Approval — Web UI (GroupInfoPanel: invite link, pending list, settings toggle; JoinGroup page; Redux slice)     | Lê Thị Thuý Hiền                |
| Join Approval — Mobile UI (group-info: invite link, pending list, settings toggle; store actions; socket hooks)      | Đoàn Ngọc Bảo Uyên              |
