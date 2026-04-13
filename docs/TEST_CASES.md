# Test Cases — Chat App Features

Phiên bản: 2.0 | Ngày cập nhật sau khi hoàn thiện implementation

---

## Mục lục
1. [Fix Bug: Revoke Window 15 phút → 24 giờ](#1-fix-bug-revoke-window)
2. [Fix Bug: Reaction 1-per-user (replace, không cộng dồn)](#2-fix-bug-reaction-1-per-user)
3. [Fix Bug: System Messages với tên actor](#3-fix-bug-system-messages)
4. [Fix Bug: Giới hạn tối đa 5 Admin/nhóm](#4-fix-bug-max-5-admin)
5. [Feature: Chỉnh sửa tin nhắn (Edit Message)](#5-feature-edit-message)
6. [Feature: Ghim tin nhắn (Pin Message)](#6-feature-pin-message)
7. [Feature: Cài đặt trò chuyện nhóm](#7-feature-conversation-settings)
8. [Feature: Áp dụng cài đặt khi gửi tin/thêm thành viên](#8-feature-enforce-settings)
9. [Feature: Cấm thành viên (Ban Member)](#9-feature-ban-member)
10. [Feature: Cài đặt riêng người dùng (My Settings)](#10-feature-my-settings)
11. [Feature: Typing Indicator](#11-feature-typing-indicator)
12. [Feature: Mark as Read](#12-feature-mark-as-read)

---

## 1. Fix Bug: Revoke Window

### TC-1.1 — Thu hồi trong vòng 24 giờ → THÀNH CÔNG
- **Precondition**: Người dùng A gửi tin nhắn cách đây 23h 59m
- **Action**: Người dùng A nhấn "Thu hồi"
- **Expected**: Tin nhắn bị thu hồi thành công; màn hình hiển thị "Tin nhắn đã được thu hồi"

### TC-1.2 — Thu hồi sau 24 giờ → THẤT BẠI
- **Precondition**: Người dùng A gửi tin nhắn cách đây hơn 24 giờ
- **Action**: Người dùng A nhấn "Thu hồi"
- **Expected**: Backend trả về lỗi `403 Forbidden` với message "...trong vòng 24 giờ"; toast lỗi hiện ra; tin nhắn không bị thu hồi

### TC-1.3 — Nút Thu hồi chỉ hiện trong 24 giờ (Frontend)
- **Precondition**: Tin nhắn của mình (isMine=true), chưa bị thu hồi, `createdAt` cách đây 23h59m
- **Expected**: Nút RotateCcw (thu hồi) **hiện** trong action bar
- **Precondition 2**: `createdAt` cách đây > 24h
- **Expected 2**: Nút thu hồi **không hiện**

### TC-1.4 — Người B không thể thu hồi tin nhắn của A
- **Precondition**: Người B nhận tin nhắn từ A
- **Expected**: Nút thu hồi không hiện trong message bubble của B; API call với messageId của A sẽ trả về `403`

---

## 2. Fix Bug: Reaction 1-per-user

### TC-2.1 — React emoji đầu tiên
- **Action**: User click 👍 trên một tin nhắn
- **Expected**: Reaction `{ userId, emoji: '👍' }` được thêm vào `message.reactions`; hiển thị badge 👍 1

### TC-2.2 — React emoji khác → thay thế, không thêm
- **Precondition**: User đã react 👍 trên tin nhắn
- **Action**: User click ❤️
- **Expected**: 👍 bị xóa; ❤️ được thêm; tổng reaction của user này vẫn là 1

### TC-2.3 — React lại emoji cũ → xóa (toggle off)
- **Precondition**: User đã react ❤️
- **Action**: User click ❤️ lần nữa
- **Expected**: Reaction bị xóa hoàn toàn; không còn badge nào cho user này

### TC-2.4 — Nhiều user react cùng emoji → đếm đúng
- **Precondition**: User A react 👍, User B react 👍
- **Expected**: Badge 👍 hiển thị số 2

### TC-2.5 — Dữ liệu db không có duplicate userId
- **Backend Unit Test**: Sau khi `toggleReaction` thực thi, query `message.reactions` → không có 2 entry nào có cùng `userId`

---

## 3. Fix Bug: System Messages với tên Actor

### TC-3.1 — Thêm thành viên → system message có tên
- **Action**: Owner "Nguyễn Văn A" thêm "Lê Thị B" vào nhóm
- **Expected**: System message: `"Nguyễn Văn A đã thêm Lê Thị B vào nhóm"`

### TC-3.2 — Xóa thành viên → system message có tên
- **Action**: Admin "Trần C" xóa "Phạm D" khỏi nhóm
- **Expected**: `"Trần C đã xóa Phạm D khỏi nhóm"`

### TC-3.3 — Rời nhóm → system message đúng
- **Action**: User "Hoàng E" rời nhóm
- **Expected**: `"Hoàng E đã rời nhóm"`

### TC-3.4 — Thay đổi vai trò → system message đúng
- **Action**: Owner thăng "Nguyễn F" lên Admin
- **Expected**: `"... đã thăng Nguyễn F lên Phó nhóm"` (hoặc tương tự)

### TC-3.5 — System message có `type: 'system'` trong DB
- **Backend**: Sau `insertSystemMessage`, query message record → `type === 'system'`

### TC-3.6 — System message không hiện bubble bình thường
- **Frontend**: Tin nhắn có `senderId === 'system'` được render dưới dạng centered text pill, không dùng MessageBubble component

---

## 4. Fix Bug: Giới hạn Max 5 Admin

### TC-4.1 — Thăng admin thứ 5 → THÀNH CÔNG
- **Precondition**: Nhóm hiện có 4 admins
- **Action**: Owner thăng thêm 1 member lên admin
- **Expected**: Thành công; nhóm có 5 admins

### TC-4.2 — Thăng admin thứ 6 → THẤT BẠI
- **Precondition**: Nhóm đã có 5 admins (kể cả owner)
- **Action**: Owner cố thăng thêm 1 member
- **Expected**: API trả về `400 Bad Request` với message "Nhóm đã có tối đa 5 quản trị viên"; toast lỗi hiện ra

### TC-4.3 — Owner không bị tính vào 5 admins
- **Precondition**: Nhóm có owner + 4 admins
- **Verify**: Gọi changeRole → kiểm tra count admin không bao gồm owner

---

## 5. Feature: Edit Message

### TC-5.1 — Chỉnh sửa trong vòng 30 phút → THÀNH CÔNG
- **Precondition**: Tin nhắn văn bản của mình, gửi cách đây < 30 phút
- **Action**: Nhấn nút bút chì (Pencil) → text input được fill sẵn nội dung cũ → sửa → gửi
- **Expected**:
  - Tin nhắn được cập nhật nội dung mới trong UI
  - `message.isEdited = true`, `message.editedAt` được set
  - Hiển thị nhãn "(đã chỉnh sửa)" sau nội dung
  - Các thành viên khác nhận socket event `message:edited` và thấy cập nhật realtime

### TC-5.2 — Chỉnh sửa sau 30 phút → THẤT BẠI
- **Precondition**: Tin nhắn gửi cách đây > 30 phút
- **Expected**: Nút bút chì không hiện; nếu gọi API trực tiếp → `403`

### TC-5.3 — Người khác không thể chỉnh sửa tin nhắn của mình
- **Precondition**: User B xem tin nhắn của User A
- **Expected**: Nút chỉnh sửa không hiện với User B (`isMine = false`)

### TC-5.4 — Chỉnh sửa tin nhắn trống → THẤT BẠI
- **Action**: Xóa toàn bộ nội dung, nhấn gửi
- **Expected**: Toast validation lỗi hoặc nút send bị disabled

### TC-5.5 — Cancel edit mode
- **Action**: Nhấn nút × trong banner "Đang chỉnh sửa"
- **Expected**: Text input trở về trạng thái ban đầu (trống), banner biến mất, không gửi request

### TC-5.6 — Tin nhắn đã thu hồi không thể sửa
- **Precondition**: Tin nhắn đã bị thu hồi (`revokedAt != null`)
- **Expected**: Nút bút chì không hiện

### TC-5.7 — System message không thể sửa
- **Precondition**: `type === 'system'`
- **Expected**: Nút bút chì không hiện

---

## 6. Feature: Pin Message

### TC-6.1 — Admin ghim tin nhắn
- **Precondition**: User là admin/owner trong nhóm, tin nhắn chưa bị thu hồi
- **Action**: Nhấn nút Pin trên tin nhắn
- **Expected**:
  - API `POST /conversations/:id/pin` gọi thành công
  - `pinnedMessages` của conversation được cập nhật
  - PinnedMessageBanner hiện ở đầu ChatRoom với nội dung tin nhắn
  - Các thành viên khác nhận socket `message:pinned`

### TC-6.2 — Bỏ ghim tin nhắn
- **Precondition**: Tin nhắn đang được ghim
- **Action**: Nhấn lại nút Pin
- **Expected**:
  - API `DELETE /messages/:id/pin` gọi thành công
  - Tin nhắn bị xóa khỏi `pinnedMessages`
  - Nếu không còn tin ghim, banner biến mất
  - Socket `message:unpinned` phát đến các thành viên

### TC-6.3 — Member thường không thể ghim (trong nhóm)
- **Precondition**: User có role 'member'
- **Expected**: Nút Pin không hiện trong action bar

### TC-6.4 — Trong trò chuyện 1-1, cả hai user đều ghim được
- **Precondition**: Direct conversation giữa A và B
- **Expected**: Cả A và B đều thấy nút Pin (isAdminOrOwner không bắt buộc trong direct)

### TC-6.5 — Giới hạn 50 tin nhắn ghim
- **Precondition**: Đã ghim 50 tin nhắn
- **Action**: Cố ghim thêm 1 tin
- **Expected**: API trả về lỗi; toast "Đã đạt giới hạn tin nhắn ghim"

### TC-6.6 — Click PinnedMessageBanner → scroll đến tin nhắn
- **Action**: Click vào banner
- **Expected**: MessageList scroll đến tin nhắn ghim và highlight

---

## 7. Feature: Conversation Settings

### TC-7.1 — Owner toggle "Chỉ Admin gửi tin" → BẬT
- **Precondition**: `settings.onlyAdminCanSend = false`
- **Action**: Owner toggle bật trong GroupInfoPanel
- **Expected**:
  - API `PATCH /conversations/:id/settings` gọi với `{ onlyAdminCanSend: true }`
  - Conversation `settings` trong store được cập nhật
  - Socket `conversation:settings` phát đến tất cả thành viên

### TC-7.2 — Socket cập nhật settings realtime
- **Action**: Owner thay đổi settings
- **Expected**: Member khác nhận event `conversation:settings`, store update không cần refresh

### TC-7.3 — Chỉ Owner thấy section Cài đặt nhóm
- **Precondition**: User role = 'admin' hoặc 'member'
- **Expected**: Section "Cài đặt nhóm" không hiện trong GroupInfoPanel

---

## 8. Feature: Enforce Settings

### TC-8.1 — `onlyAdminCanSend = true` → Member không gửi được
- **Precondition**: `settings.onlyAdminCanSend = true`; User có role 'member'
- **Action**: User cố gửi tin nhắn
- **Expected**: API trả về `403`; toast lỗi hiện ra; tin nhắn không xuất hiện trong chat

### TC-8.2 — `onlyAdminCanSend = true` → Admin vẫn gửi được
- **Precondition**: Same as above; User role = 'admin'
- **Expected**: Tin nhắn gửi thành công bình thường

### TC-8.3 — `allowMemberInvite = false` → Member không thêm được người
- **Precondition**: `settings.allowMemberInvite = false`; User role = 'member'
- **Action**: Cố gọi `POST /conversations/:id/members`
- **Expected**: API `403`; toast lỗi

### TC-8.4 — `allowMemberInvite = false` → Admin vẫn thêm được
- **Precondition**: Same; User role = 'admin' hoặc 'owner'
- **Expected**: Thêm thành viên thành công

---

## 9. Feature: Ban Member

### TC-9.1 — Admin ban member → member không gửi được
- **Precondition**: User A là admin; User B là member
- **Action**: A ban B (không có bannedUntil → permanent)
- **Expected**:
  - B có `isBanned = true` trong participants
  - Badge "Bị cấm" hiện trong GroupInfoPanel
  - Khi B cố gửi tin → API `403` với message "Bạn đã bị cấm gửi tin nhắn"

### TC-9.2 — Ban có thời hạn → tự động hết hạn
- **Action**: Ban B đến `bannedUntil = now + 1 giờ`
- **Expected**: Trong vòng 1 giờ, B không gửi được; sau 1 giờ, B gửi bình thường (backend auto-unban khi `sendMessage` check `bannedUntil` hết hạn)

### TC-9.3 — Unban member → gửi được lại
- **Action**: Admin nhấn bỏ cấm (nút Ban màu cam)
- **Expected**: `isBanned = false`; B gửi tin nhắn thành công

### TC-9.4 — Owner không thể bị ban bởi Admin
- **Backend**: Kiểm tra trong `banMember` service → nếu target là owner → throw `ForbiddenException`

### TC-9.5 — Admin không thể ban Admin khác (chỉ Owner mới được)
- **Backend**: `banMember` kiểm tra role hierarchy

### TC-9.6 — Socket event khi bị ban
- **Expected**: User B nhận event `member:banned`; client dispatch `fetchConversations` để refresh trạng thái

---

## 10. Feature: My Settings (Per-user Conversation Settings)

### TC-10.1 — Pin conversation (isPinned)
- **Action**: User gọi `PATCH /conversations/:id/me` với `{ isPinned: true }`
- **Expected**: Conversation xuất hiện ở đầu danh sách (sort theo isPinned)

### TC-10.2 — Mute conversation
- **Action**: `{ isMuted: true, muteUntil: ISO date }`
- **Expected**: Không nhận toast notification từ conversation này cho đến hết thời gian muteUntil

### TC-10.3 — Muted state không ảnh hưởng người khác
- **Expected**: User B vẫn nhận notification bình thường khi A đang mute

---

## 11. Feature: Typing Indicator

### TC-11.1 — Gõ text → hiện typing indicator cho người khác
- **Precondition**: User A và B trong cùng conversation
- **Action**: A bắt đầu gõ
- **Expected**: B thấy indicator "A đang gõ..." ở dưới messages list; 3 chấm bounce animation

### TC-11.2 — Dừng gõ 4 giây → typing indicator tự ẩn
- **Action**: A dừng gõ 4 giây
- **Expected**: Indicator biến mất ở màn hình của B

### TC-11.3 — Gửi tin → typing stop ngay lập tức
- **Action**: A gửi tin nhắn
- **Expected**: Typing indicator ẩn ngay trước/khi tin nhắn xuất hiện

### TC-11.4 — Nhiều người gõ cùng lúc
- **Precondition**: A, B, C đều đang gõ
- **Expected**: Indicator hiển thị "3 người đang gõ..."

### TC-11.5 — Disconnect → typing tự dọn
- **Action**: User A đóng tab/mất mạng
- **Expected**: Gateway cleanup timeout, B không thấy indicator "treo" mãi

### TC-11.6 — Typing indicator chỉ hiện trong conversation đang mở
- **Expected**: Conversation khác của A không bị ảnh hưởng

---

## 12. Feature: Mark as Read

### TC-12.1 — Mở conversation → mark as read
- **Action**: User mở một conversation có unread messages
- **Expected**: `POST /conversations/:id/read` gọi; `lastReadAt` của participant được cập nhật

### TC-12.2 — Unread count reset về 0
- **Expected**: Sau khi mark as read, badge số tin chưa đọc biến mất

### TC-12.3 — Mark as read không ảnh hưởng người khác
- **Expected**: Người khác vẫn có `lastReadAt` của họ

---

## Kiểm tra tích hợp (Integration)

### TC-INT-1 — Toàn bộ flow Edit Message end-to-end
1. A gửi tin nhắn: "Xin chào"
2. A nhấn bút chì → edit thành "Xin chào bạn"
3. B (đang online) nhận socket `message:edited`
4. B thấy "Xin chào bạn (đã chỉnh sửa)"
5. DB: `messages.content = 'Xin chào bạn'`, `isEdited = true`, `editedAt` có giá trị

### TC-INT-2 — Toàn bộ flow Pin + Banner
1. Admin A ghim tin nhắn của B
2. PinnedMessageBanner hiện cho tất cả thành viên (qua socket)
3. Member click vào banner → scroll đến tin nhắn
4. Admin A bỏ ghim → banner biến mất

### TC-INT-3 — Toàn bộ flow Group Settings
1. Owner bật `onlyAdminCanSend`
2. Member cố gửi → lỗi
3. Owner tắt lại → Member gửi được
4. Tất cả thao tác realtime qua socket

### TC-INT-4 — Typing ở nhiều conversation cùng lúc
1. User có 2 conversation tab mở
2. Trong conv1 gõ → typing update chỉ đến conv1
3. conv2 không bị ảnh hưởng

---

## Test Cases phụ: Bảo mật

### TC-SEC-1 — JWT `name` claim không được tin tưởng cho display name
- System messages lấy tên từ JWT payload `name`; verify rằng payload được ký đúng với secret

### TC-SEC-2 — Ban member không thể bypass qua direct API call
- User không có quyền cố gọi `POST /conversations/:id/members/:memberId/ban`
- **Expected**: `401` nếu không có token; `403` nếu không đủ role

### TC-SEC-3 — Edit message của người khác bị chặn ở backend
- User B gọi `PATCH /chat/messages/:idOfA` với token của B
- **Expected**: `403 Forbidden`

### TC-SEC-4 — Unrevoke / Re-send đã thu hồi bị chặn
- Cố gọi `sendMessage` với messageId đã thu hồi
- **Expected**: Không cho phép "khôi phục" tin đã thu hồi

---

## Trạng thái thực thi

| # | Test | Backend | Frontend | Ghi chú |
|---|------|---------|----------|---------|
| 1.x | Revoke window 24h | ✅ | ✅ | |
| 2.x | Reaction 1-per-user | ✅ | ✅ | |
| 3.x | System message actor | ✅ | ✅ | |
| 4.x | Max 5 admin | ✅ | ✅ | |
| 5.x | Edit message | ✅ | ✅ | |
| 6.x | Pin message | ✅ | ✅ | |
| 7.x | Group settings | ✅ | ✅ | |
| 8.x | Enforce settings | ✅ | N/A | Backend only |
| 9.x | Ban member | ✅ | ✅ | |
| 10.x | My settings | ✅ | - | API only, no UI yet |
| 11.x | Typing indicator | ✅ | ✅ | |
| 12.x | Mark as read | ✅ | - | API ready, no auto-trigger yet |
