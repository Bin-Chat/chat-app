# Hướng dẫn kiểm thử tính năng Gọi thoại / Video

## Môi trường kiểm thử

- Web: `http://localhost:5173`
- Mở **2 tab trình duyệt** (hoặc 2 trình duyệt khác nhau) với 2 tài khoản khác nhau
- Đảm bảo Docker đang chạy: `docker compose up -d`

---

## TC01 — Gọi thành công (Completed Call)

**Mục tiêu**: Hai bên kết nối được, timer chạy, kết thúc bình thường.

**Bước thực hiện**:

1. Tab A: Mở cuộc trò chuyện với B → nhấn icon gọi thoại/video
2. Tab B: Nhận modal thông báo gọi đến → nhấn **Bắt máy**
3. Kiểm tra tab A: không còn "Đang gọi…", timer bắt đầu chạy
4. Kiểm tra tab B: hiển thị giao diện cuộc gọi, timer đồng bộ
5. Tab A: nhấn **Kết thúc**

**Kết quả mong đợi**:

- [x] Tab A: hiện "Đang gọi…" → sau khi B bắt máy: timer chạy
- [x] Tab B: hiển thị stream của A (audio/video)
- [x] Tab A: hiển thị stream của B (audio/video)
- [x] Cả hai giao diện đóng sau khi kết thúc
- [x] Chat box hiển thị: `📞 Cuộc gọi thoại - MM:SS` (hoặc 📹 nếu là video)

---

## TC02 — Người gọi hủy trước khi bắt máy (Cancelled)

**Mục tiêu**: A gọi → A hủy trước khi B nhấn bắt máy.

**Bước thực hiện**:

1. Tab A: Gọi cho B
2. Tab A: Nhấn **Kết thúc** trong khi B chưa bắt máy

**Kết quả mong đợi**:

- [x] Tab B: modal gọi đến biến mất
- [x] Chat box: `📞 Cuộc gọi thoại bị hủy`
- [x] Không có system message dư thừa

---

## TC03 — Cuộc gọi bị từ chối (Declined)

**Bước thực hiện**:

1. Tab A: Gọi cho B
2. Tab B: Nhấn **Từ chối**

**Kết quả mong đợi**:

- [x] Tab A: toast "Cuộc gọi bị từ chối", giao diện gọi đóng
- [x] Chat box: `📞 Cuộc gọi thoại bị từ chối`

---

## TC04 — Cuộc gọi nhỡ — timeout 45 giây (Missed)

**Bước thực hiện**:

1. Tab A: Gọi cho B
2. **Không** nhấn bắt máy, chờ 45 giây

**Kết quả mong đợi**:

- [x] Sau 45s: Tab B modal tự đóng
- [x] Tab A: giao diện gọi đóng
- [x] Chat box: `📞 Cuộc gọi thoại nhỡ`

---

## TC05 — Người nhận đang bận (Busy)

**Bước thực hiện**:

1. Tab B: Đã trong cuộc gọi với C
2. Tab A: Gọi cho B
3. Tab B: Nhận thông báo "bận" (hoặc tự động từ chối)

**Kết quả mong đợi**:

- [x] Tab A: toast "Người dùng đang bận"
- [x] Tab B: không bị gián đoạn cuộc gọi đang có

---

## TC06 — Gọi video — kiểm tra video track

**Bước thực hiện**:

1. Tab A: Nhấn icon gọi **video**
2. Tab B: Bắt máy
3. Kiểm tra stream video xuất hiện ở cả hai bên
4. Tab A: Nhấn **Tắt camera** → B không còn thấy video của A
5. Tab A: Nhấn **Bật camera** → B thấy video A trở lại

**Kết quả mong đợi**:

- [x] VideoTile hiển thị đúng stream từng phía
- [x] PiP (picture-in-picture) của local stream xuất hiện góc dưới phải
- [x] Tắt camera: video track disabled (màn hình tối), không dừng stream

---

## TC07 — Chia sẻ màn hình (Screen Sharing)

**Bước thực hiện**:

1. Đang trong cuộc gọi (video hoặc audio)
2. Tab A: Nhấn **icon màn hình** → chọn cửa sổ muốn chia sẻ
3. Kiểm tra Tab B nhận được stream màn hình
4. Tab A: Nhấn lại icon màn hình → dừng chia sẻ
5. Kiểm tra Tab A trở lại camera (nếu là video call)

**Kết quả mong đợi** (audio call — không có video sender ban đầu):

- [x] Screen share track được thêm vào PC (addTrack, không phải replaceTrack)
- [x] B nhìn thấy màn hình A
- [x] Sau khi dừng, track bị remove

**Kết quả mong đợi** (video call):

- [x] Camera track được replaceTrack bằng screen track
- [x] Dừng chia sẻ → trở lại camera

---

## TC08 — Tắt / bật microphone

**Bước thực hiện**:

1. Đang trong cuộc gọi
2. Nhấn **icon mic** → tắt
3. Nói chuyện — B không nghe thấy
4. Nhấn lại → bật, B nghe bình thường

**Kết quả mong đợi**:

- [x] Audio track `.enabled = false` (không tắt track hẳn)
- [x] Icon mic đổi sang MicOff (đỏ)
- [x] B không nhận âm thanh khi A mute

---

## TC09 — Tắt / bật camera (Video Call)

**Bước thực hiện**:

1. Đang trong video call
2. Nhấn **icon camera** → tắt

**Kết quả mong đợi**:

- [x] Video track `.enabled = false`
- [x] Icon VideoOff hiện màu đỏ
- [x] B thấy màn hình tối thay vì video A

---

## TC10 — Gọi nhóm (Multi-party)

**Bước thực hiện**:

1. Tạo nhóm với A, B, C
2. A gọi nhóm (callType: audio hoặc video)
3. B bắt máy → A và B kết nối
4. C bắt máy → A tạo offer cho C, B tạo offer cho C
5. Kiểm tra tất cả 3 người nghe/thấy nhau

**Kết quả mong đợi**:

- [x] Video grid hiển thị đúng (1 remote → full; 2 remotes → 2 cột; 3+ → 3 cột)
- [x] Khi C disconnect: tile của C biến mất, không crash
- [x] Số người tham gia hiển thị đúng ở header

---

## TC11 — Mất kết nối và kết nối lại

**Bước thực hiện**:

1. Đang trong cuộc gọi
2. Tắt wifi của A trong 5 giây
3. Bật lại

**Kết quả mong đợi**:

- [x] PC state chuyển sang 'disconnected' → tile của A biến mất ở B
- [x] Sau khi bật lại: nếu ICE restart thành công → reconnect
- [x] Nếu PC 'failed': tile bị xóa khỏi remoteStreams, không crash

---

## TC12 — System messages trong chat box

**Mục tiêu**: Kiểm tra tất cả loại system message hiển thị đúng dạng pill.

| Kịch bản              | Nội dung mong đợi              |
| --------------------- | ------------------------------ |
| Gọi thoại hoàn thành  | `📞 Cuộc gọi thoại - 00:45`    |
| Gọi video hoàn thành  | `📹 Cuộc gọi video - 02:13`    |
| A hủy trước khi B bắt | `📞 Cuộc gọi thoại bị hủy`     |
| B từ chối             | `📞 Cuộc gọi thoại bị từ chối` |
| Timeout 45s (nhỡ)     | `📞 Cuộc gọi thoại nhỡ`        |

**Kiểm tra giao diện**:

- [x] Hiển thị dạng pill căn giữa, không phải bubble thông thường
- [x] Không có avatar, sender name
- [x] Không thể reply, react, forward, copy
- [x] Không thể thu hồi hoặc xóa phía mình

---

## Checklist lỗi đã sửa

| Lỗi                                           | File                        | Trạng thái                                   |
| --------------------------------------------- | --------------------------- | -------------------------------------------- |
| A hiện "Đang chờ đối phương…" dù B đã bắt máy | `useWebRTC.ts`              | ✅ Đã sửa (stream readiness gate)            |
| B không gửi track khi trả lời offer           | `useWebRTC.ts`              | ✅ Đã sửa (re-add tracks sau khi await gate) |
| Screen share lỗi với audio-only call          | `useWebRTC.ts`              | ✅ Đã sửa (addTrack thay vì replaceTrack)    |
| Gateway không trả outcome/duration            | `socket.gateway.ts`         | ✅ Đã sửa                                    |
| Không có timeout 45s cho cuộc gọi nhỡ         | `socket.gateway.ts`         | ✅ Đã sửa                                    |
| Modal gọi đến không đóng khi caller hủy       | `ChatSocketInitializer.tsx` | ✅ Đã sửa (`call:cancelled`)                 |
| Không có system message trong chat            | Nhiều file                  | ✅ Đã sửa                                    |
| System message bị hiển thị như bubble thường  | `MessageBubble.tsx`         | ✅ Đã sửa (pill UI)                          |
| Sender name xuất hiện với system message      | `ChatRoom.tsx`              | ✅ Đã sửa                                    |
