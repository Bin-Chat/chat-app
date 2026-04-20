# Tài liệu Chi tiết — Tính năng Gọi Voice/Video (Call Feature)

> **Tài liệu này mô tả toàn bộ cơ chế hoạt động** của tính năng gọi thoại và gọi video trong BinChat — từ kiến trúc tổng quan, luồng tín hiệu WebRTC, quản lý trạng thái, UI/UX, đến các edge case và giới hạn kỹ thuật.

---

## Mục lục

1. [Tổng quan & Công nghệ](#1-tổng-quan--công-nghệ)
2. [Kiến trúc hệ thống](#2-kiến-trúc-hệ-thống)
3. [TURN Server — coturn](#3-turn-server--coturn)
4. [Socket Events — Signaling Protocol](#4-socket-events--signaling-protocol)
5. [Gateway — Quản lý phiên gọi](#5-gateway--quản-lý-phiên-gọi)
6. [WebRTC Hook — useWebRTC.ts](#6-webrtc-hook--usewebrtcts)
7. [Luồng gọi đơn (Direct Call)](#7-luồng-gọi-đơn-direct-call)
8. [Luồng gọi nhóm (Group Call — Mesh P2P)](#8-luồng-gọi-nhóm-group-call--mesh-p2p)
9. [ICE Candidate Buffering](#9-ice-candidate-buffering)
10. [Quản lý trạng thái (State Management)](#10-quản-lý-trạng-thái-state-management)
11. [Web — UI Components](#11-web--ui-components)
12. [Mobile — UI Components & Screens](#12-mobile--ui-components--screens)
13. [Xử lý Disconnect & Cleanup](#13-xử-lý-disconnect--cleanup)
14. [Hạn chế & Edge Cases](#14-hạn-chế--edge-cases)
15. [Biến môi trường](#15-biến-môi-trường)
16. [Cấu trúc file trong project](#16-cấu-trúc-file-trong-project)
17. [Sơ đồ tuần tự đầy đủ](#17-sơ-đồ-tuần-tự-đầy-đủ)

---

## 1. Tổng quan & Công nghệ

Tính năng Call sử dụng **WebRTC Peer-to-Peer (P2P)** để truyền tải media (âm thanh/video) **trực tiếp giữa các client** — không qua backend. Backend (API Gateway) chỉ đóng vai trò **Signaling Relay** — chuyển tiếp các thông điệp thiết lập kết nối (SDP offer/answer, ICE candidates).

### Lý do không dùng SFU/MCU (như mediasoup, Janus)

| Giải pháp | Ưu điểm                           | Nhược điểm                               | Chọn? |
| --------- | --------------------------------- | ---------------------------------------- | ----- |
| Mesh P2P  | Không cần media server, đơn giản  | Tốn bandwidth khi nhiều người (O(n²))    | ✅    |
| SFU       | Tốt cho nhóm lớn, 1 upload stream | Cần deploy media server riêng (phức tạp) | ❌    |
| MCU       | Trộn stream server-side           | Độ trễ cao, tốn CPU server               | ❌    |

**Mesh P2P** phù hợp với BinChat vì giới hạn **tối đa 8 người/cuộc gọi** — số connections tối đa là $\frac{8 \times 7}{2} = 28$ peers.

### Stack công nghệ

| Tầng          | Web                       | Mobile                                |
| ------------- | ------------------------- | ------------------------------------- |
| WebRTC API    | Native browser (built-in) | `react-native-webrtc` (native mod)    |
| Signaling     | Socket.io (appSocket)     | Socket.io (socketService)             |
| State         | Redux Toolkit (callSlice) | Zustand (callStore)                   |
| Media capture | `navigator.mediaDevices`  | `mediaDevices` từ react-native-webrtc |
| TURN server   | coturn 4.6.2              | coturn 4.6.2 (cùng)                   |
| Screen share  | `getDisplayMedia()` (web) | Không hỗ trợ (mobile limitation)      |

---

## 2. Kiến trúc hệ thống

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        TỔNG QUAN KIẾN TRÚC CALL                         │
│                                                                          │
│  ┌─────────────────┐    Socket.io WS    ┌──────────────────────────┐    │
│  │   User A (Web)  │◄──────────────────►│     API Gateway :3000    │    │
│  │                 │    Signaling only  │                          │    │
│  │  RTCPeerConn A  │                    │  SocketGateway           │    │
│  │  callSlice      │                    │  activeCalls: Map        │    │
│  │  useWebRTC.ts   │                    │  emitToUser()            │    │
│  └────────┬────────┘                    └──────────┬───────────────┘    │
│           │                                        │                    │
│           │  ← SDP Offer/Answer                    │ Socket.io WS       │
│           │  ← ICE Candidates                      │                    │
│           │  (relay qua Gateway)                   ▼                    │
│           │                             ┌──────────────────────────┐    │
│           │  P2P Media Stream           │  User B (Mobile)         │    │
│           │  (audio/video TRỰC TIẾP)    │                          │    │
│           └────────────────────────────►│  RTCPeerConn B           │    │
│                                         │  callStore               │    │
│                                         │  useWebRTC.ts (mobile)   │    │
│                                         └──────────────────────────┘    │
│                                                                          │
│                     ┌────────────────────────────┐                       │
│                     │  coturn TURN Server :3478   │                       │
│                     │                            │                       │
│                     │  Relay khi P2P không được   │                       │
│                     │  (NAT symmetric, firewall)  │                       │
│                     │  UDP relay: 49152-49200     │                       │
│                     └────────────────────────────┘                       │
└──────────────────────────────────────────────────────────────────────────┘
```

### Luồng dữ liệu tách biệt

```
Signaling (control plane):
  Client ──Socket.io──► Gateway ──Socket.io──► Client
  (SDP, ICE, call events — rất nhỏ, vài KB)

Media (data plane):
  Client ──────────── RTCPeerConnection ──────────── Client
  (audio/video stream — KHÔNG qua Gateway/Backend)
```

---

## 3. TURN Server — coturn

### Tại sao cần TURN?

WebRTC P2P yêu cầu 2 peer có thể "nhìn thấy" nhau qua mạng. Trong thực tế:

- **STUN**: Giúp peer biết địa chỉ IP public của mình (NAT traversal đơn giản)
- **TURN**: Khi 2 peer không kết nối trực tiếp được (NAT symmetric, corporate firewall), TURN **relay** media qua server

### Docker Compose Config

```yaml
coturn:
  image: coturn/coturn:4.6.2
  container_name: chat-coturn
  restart: unless-stopped
  ports:
    - '3478:3478/tcp' # TURN/STUN signaling
    - '3478:3478/udp' # TURN/STUN signaling
    - '49152-49200:49152-49200/udp' # Media relay range
  command: >
    -n
    --log-file=stdout
    --min-port=49152
    --max-port=49200
    --realm=chat.local
    --user=${TURN_USERNAME:-chatapp}:${TURN_PASSWORD:-chatapp_turn_secret}
    --no-tls
    --no-dtls
    --fingerprint
    --lt-cred-mech
  networks:
    - chat-network
```

### Giải thích tham số

| Tham số          | Ý nghĩa                                                             |
| ---------------- | ------------------------------------------------------------------- |
| `--lt-cred-mech` | Long-term credential mechanism (username:password cố định)          |
| `--realm`        | Realm của TURN server (tên domain giả)                              |
| `--no-tls`       | Không dùng TLS (internal docker network, không cần encrypt thêm)    |
| `--fingerprint`  | Thêm DTLS fingerprint vào TURN responses                            |
| `--min/max-port` | Dải UDP port để relay media — cần mở firewall nếu deploy production |

### ICE Server order (trong useWebRTC)

```typescript
iceServers: [
  { urls: 'stun:stun.l.google.com:19302' }, // 1. STUN Google (miễn phí, public)
  { urls: 'stun:stun1.l.google.com:19302' }, // 2. Backup STUN
  {
    urls: 'turn:localhost:3478', // 3. TURN local (fallback cuối)
    username: TURN_USERNAME,
    credential: TURN_PASSWORD,
  },
];
```

> Browser thử STUN trước (rẻ, nhanh). Chỉ dùng TURN nếu P2P thất bại → tiết kiệm bandwidth.

---

## 4. Socket Events — Signaling Protocol

### Danh sách đầy đủ

| #   | Direction       | Event           | Payload                                                                                                                     | Mô tả                                         |
| --- | --------------- | --------------- | --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| 1   | Client → Server | `call:initiate` | `{ callId, conversationId, callType, participantIds, callerName, callerAvatar? }`                                           | Caller bắt đầu cuộc gọi                       |
| 2   | Server → Client | `call:incoming` | `{ callId, conversationId, callType, callerId, callerName, callerAvatar? }`                                                 | Gửi đến tất cả người được mời                 |
| 3   | Client → Server | `call:accept`   | `{ callId }`                                                                                                                | Người nhận chấp nhận                          |
| 4   | Server → Client | `call:accepted` | `{ callId, userId, conversationId, callType }`                                                                              | Gửi đến tất cả đã accepted → trigger offer    |
| 5   | Client → Server | `call:reject`   | `{ callId }`                                                                                                                | Người nhận từ chối                            |
| 6   | Server → Client | `call:rejected` | `{ callId }`                                                                                                                | Gửi về caller                                 |
| 7   | Client → Server | `call:end`      | `{ callId }`                                                                                                                | Kết thúc cuộc gọi (từ bất kỳ participant nào) |
| 8   | Server → Client | `call:ended`    | `{ callId }`                                                                                                                | Gửi đến tất cả acceptedIds                    |
| 9   | Client → Server | `call:signal`   | `{ callId, targetUserId, signal: { type: 'offer'\|'answer'\|'candidate', sdp?: string, candidate?: RTCIceCandidateInit } }` | Relay SDP/ICE                                 |
| 10  | Server → Client | `call:signal`   | `{ callId, fromUserId, signal }`                                                                                            | Forward signal đến target                     |
| 11  | Client → Server | `call:busy`     | `{ callId, callerId }`                                                                                                      | Đang trong cuộc gọi khác                      |
| 12  | Server → Client | `call:busy`     | `{ callId }`                                                                                                                | Thông báo người nhận đang bận                 |

### Payload chi tiết — `call:signal`

```typescript
// SDP Offer (Caller → Callee)
{
  callId: "abc123",
  targetUserId: "user-b-uuid",
  signal: {
    type: "offer",
    sdp: "v=0\r\no=- 1234... (SDP string)"
  }
}

// SDP Answer (Callee → Caller)
{
  callId: "abc123",
  targetUserId: "user-a-uuid",
  signal: {
    type: "answer",
    sdp: "v=0\r\no=- 5678... (SDP string)"
  }
}

// ICE Candidate (bidirectional)
{
  callId: "abc123",
  targetUserId: "user-b-uuid",
  signal: {
    type: "candidate",
    candidate: {
      candidate: "candidate:1 1 UDP 2122252543 192.168.1.5 50000 typ host",
      sdpMid: "0",
      sdpMLineIndex: 0
    }
  }
}
```

---

## 5. Gateway — Quản lý phiên gọi

### File: `gateway/api-gateway/src/socket/socket.gateway.ts`

### `activeCalls` Map

```typescript
private activeCalls = new Map<string, {
  callId: string;
  conversationId: string;
  callType: 'audio' | 'video';
  callerId: string;
  participantIds: string[];   // tất cả người được mời (không gồm caller)
  acceptedIds: string[];      // đã accept (caller tự động được thêm vào)
  status: 'calling' | 'connected';
  startedAt: Date;
}>();
```

### Handler `call:initiate`

```typescript
@SubscribeMessage('call:initiate')
handleCallInitiate(client: Socket, payload) {
  const { callId, conversationId, callType, participantIds,
          callerName, callerAvatar } = payload;
  const callerId = client.data.userId;

  // Lưu session
  this.activeCalls.set(callId, {
    callId, conversationId, callType, callerId,
    participantIds,
    acceptedIds: [callerId],   // caller tự động join
    status: 'calling',
    startedAt: new Date(),
  });

  // Gửi call:incoming đến tất cả participant
  for (const uid of participantIds) {
    this.emitToUser(uid, 'call:incoming', {
      callId, conversationId, callType, callerId,
      callerName, callerAvatar,
    });
  }
}
```

### Handler `call:accept`

```typescript
@SubscribeMessage('call:accept')
handleCallAccept(client: Socket, payload) {
  const { callId } = payload;
  const userId = client.data.userId;
  const session = this.activeCalls.get(callId);
  if (!session) return;

  session.acceptedIds.push(userId);

  // Thông báo cho TẤT CẢ người đã accepted (kể cả caller)
  // → Mỗi người trong acceptedIds sẽ initiateOffer với userId mới
  for (const uid of session.acceptedIds) {
    if (uid !== userId) {  // không gửi lại cho chính mình
      this.emitToUser(uid, 'call:accepted', {
        callId, userId,
        conversationId: session.conversationId,
        callType: session.callType,
      });
    }
  }
}
```

### Handler `call:signal`

```typescript
@SubscribeMessage('call:signal')
handleCallSignal(client: Socket, payload) {
  const { callId, targetUserId, signal } = payload;
  const fromUserId = client.data.userId;

  // Pure relay — không xử lý nội dung signal
  this.emitToUser(targetUserId, 'call:signal', {
    callId, fromUserId, signal,
  });
}
```

### Handler `call:end`

```typescript
@SubscribeMessage('call:end')
handleCallEnd(client: Socket, payload) {
  const { callId } = payload;
  const session = this.activeCalls.get(callId);
  if (!session) return;

  // Thông báo tất cả acceptedIds
  for (const uid of session.acceptedIds) {
    if (uid !== client.data.userId) {
      this.emitToUser(uid, 'call:ended', { callId });
    }
  }

  this.activeCalls.delete(callId);
}
```

### Auto-cleanup khi disconnect

```typescript
handleDisconnect(client: Socket) {
  const userId = client.data.userId;
  if (!userId) return;

  // Tìm tất cả cuộc gọi user đang tham gia
  for (const [callId, session] of this.activeCalls.entries()) {
    if (!session.acceptedIds.includes(userId)) continue;

    // Xóa user khỏi acceptedIds
    session.acceptedIds = session.acceptedIds.filter(id => id !== userId);

    if (session.acceptedIds.length === 0) {
      // Không còn ai → xóa session
      this.activeCalls.delete(callId);
    } else {
      // Thông báo những người còn lại
      for (const uid of session.acceptedIds) {
        this.emitToUser(uid, 'call:ended', { callId });
      }
    }
  }
}
```

---

## 6. WebRTC Hook — useWebRTC.ts

### File Web: `apps/web/src/hooks/useWebRTC.ts`

### File Mobile: `apps/mobile/src/hooks/useWebRTC.ts`

### Cấu trúc dữ liệu trong hook

```typescript
// Mỗi remote peer có một RTCPeerConnection và pending ICE candidates
peerConnections: Map<userId, RTCPeerConnection>;
pendingCandidates: Map<userId, RTCIceCandidateInit[]>;

// Media streams
localStream: MediaStream | null; // stream từ camera/microphone mình
remoteStreams: Record<userId, MediaStream>; // streams từ các peer
```

### Exported API

```typescript
const {
  localStream,
  remoteStreams,
  isWebRTCAvailable, // (mobile only) false nếu trong Expo Go
  getLocalStream, // (video: boolean, audio: boolean) => Promise<MediaStream>
  initiateOffer, // (remoteUserId: string) => Promise<void>
  startScreenShare, // () => Promise<void>  (web only)
  stopScreenShare, // () => void
  cleanup, // () => void — dừng tracks, đóng tất cả peers
} = useWebRTC();
```

### Vòng đời của một RTCPeerConnection

```
initiateOffer(remoteUserId)
     ↓
createPeerConnection(remoteUserId)
  - new RTCPeerConnection(iceConfig)
  - localStream.tracks → pc.addTrack(track, localStream)
  - pc.ontrack → cập nhật remoteStreams[remoteUserId]
  - pc.onicecandidate → emit call:signal (type: candidate)
  - pc.oniceconnectionstatechange → cleanup khi disconnected
     ↓
pc.createOffer()
pc.setLocalDescription(offer)
emit('call:signal', { targetUserId: remoteUserId, signal: { type: 'offer', sdp } })
     ↓
[nhận call:signal từ remoteUserId]
  if type === 'answer':
    pc.setRemoteDescription(answer)
    → flush pendingCandidates
  if type === 'candidate':
    if !pc.remoteDescription → buffer vào pendingCandidates
    else → pc.addIceCandidate(candidate)
     ↓
[RTCPeerConnection.iceConnectionState === 'connected']
remoteStreams[remoteUserId] = stream  (từ pc.ontrack)
```

### Xử lý incoming offer (callee side)

```typescript
// Trong handleSignal, khi type === 'offer':
const pc = createPeerConnection(fromUserId); // tạo peer mới
await pc.setRemoteDescription(new RTCSessionDescription(signal));
// flush pending candidates (nếu có ICE đến trước offer)
for (const c of pendingCandidates.get(fromUserId) ?? []) {
  await pc.addIceCandidate(new RTCIceCandidate(c));
}
pendingCandidates.set(fromUserId, []);
// Tạo answer
const answer = await pc.createAnswer();
await pc.setLocalDescription(answer);
emit('call:signal', { targetUserId: fromUserId, signal: { type: 'answer', sdp: answer.sdp } });
```

### Sync trạng thái mute/video với Redux/Zustand

```typescript
// Web: useEffect theo dõi Redux state
useEffect(() => {
  if (!localStream) return;
  localStream.getAudioTracks().forEach((t) => (t.enabled = !isMuted));
}, [isMuted]);

useEffect(() => {
  if (!localStream) return;
  localStream.getVideoTracks().forEach((t) => (t.enabled = !isVideoOff));
}, [isVideoOff]);
```

### Mobile — Expo Go Detection

```typescript
// Graceful fallback nếu thiếu native module
let RTCPeerConnection: any = null;
let mediaDevices: any = null;
let isWebRTCAvailable = false;

try {
  const webrtc = require('react-native-webrtc');
  RTCPeerConnection = webrtc.RTCPeerConnection;
  mediaDevices = webrtc.mediaDevices;
  isWebRTCAvailable = true;
} catch {
  isWebRTCAvailable = false; // Expo Go mode
}
```

---

## 7. Luồng gọi đơn (Direct Call)

### Sequence Diagram

```
User A (Caller)             API Gateway              User B (Callee)
     │                           │                        │
     │ [nhấn nút Phone/Video]    │                        │
     │                           │                        │
     │ generateCallId()          │                        │
     │ dispatch(startCall())     │                        │
     │ emit(call:initiate) ─────►│                        │
     │ router.push('/call')      │                        │
     │                           │ activeCalls.set()      │
     │                           │ emit(call:incoming) ──►│
     │                           │                        │ setIncomingCall()
     │                           │                        │ Hiện IncomingCallModal/Banner
     │                           │                        │
     │                           │     [User B nhấn Accept]
     │                           │                        │
     │                           │◄──── emit(call:accept) │
     │                           │                        │ dispatch(acceptCall())
     │                           │                        │ router.push('/call')
     │                           │                        │ getLocalStream()
     │◄── emit(call:accepted) ───│                        │
     │                           │                        │
     │ getLocalStream()          │                        │
     │ initiateOffer(B)          │                        │
     │   createOffer()           │                        │
     │ emit(call:signal offer) ─►│─── emit(call:signal) ─►│
     │                           │                        │ setRemoteDescription(offer)
     │                           │                        │ createAnswer()
     │                           │◄── emit(call:signal) ──│
     │◄── emit(call:signal ans) ─│                        │
     │ setRemoteDescription(ans) │                        │
     │                           │                        │
     │══ICE exchange (bidirectional)══════════════════════│
     │                           │                        │
     │◄═══════ P2P Media Stream (audio/video) ═══════════►│
     │                           │                        │
     │ [User A nhấn Hang Up]     │                        │
     │ emit(call:end) ──────────►│                        │
     │ cleanup()                 │ activeCalls.delete()   │
     │ dispatch(endCall())       │ emit(call:ended) ──────►│
                                                          │ dispatch(endCall())
                                                          │ cleanup()
```

---

## 8. Luồng gọi nhóm (Group Call — Mesh P2P)

### Topology

Khi có $n$ người trong cuộc gọi, số kết nối P2P là $\frac{n(n-1)}{2}$:

| Số người | Số kết nối P2P |
| -------- | -------------- |
| 2        | 1              |
| 3        | 3              |
| 4        | 6              |
| 5        | 10             |
| 8        | 28 (max)       |

### Cơ chế "late joiner"

Khi User C join vào cuộc gọi đang có A và B:

```
[C emit call:accept]
     ↓
Gateway: acceptedIds = [A, B, C]
Gateway emit call:accepted { userId: C } → A và B
     ↓
A nhận → initiateOffer(C)     // A tạo RTCPeerConnection A↔C
B nhận → initiateOffer(C)     // B tạo RTCPeerConnection B↔C
     ↓
C nhận offer từ A → setRemoteDesc → createAnswer → gửi lại A
C nhận offer từ B → setRemoteDesc → createAnswer → gửi lại B
     ↓
Media stream: A↔B (đã có), A↔C (mới), B↔C (mới)
```

> **Quan trọng**: Người mới join (C) **không** phải tự emit offer đến ai. Những người đã có mặt (A, B) sẽ chủ động offer đến C. Điều này đảm bảo C không cần biết ai đang trong phòng.

### Xử lý trong `CallRoom.tsx` (web)

```typescript
// Khi nhận call:accepted — ai đó vừa join
appSocket.on('call:accepted', (data: { userId: string }) => {
  dispatch(addParticipant(data.userId));
  // Nếu mình là người đã trong phòng → tạo offer đến người mới
  if (myUserId !== data.userId) {
    initiateOffer(data.userId);
  }
});
```

---

## 9. ICE Candidate Buffering

### Vấn đề

ICE candidates thường được tạo ra **song song** với quá trình offer/answer. Trong nhiều trường hợp, candidate từ peer A đến peer B **trước khi** B set remote description xong → `addIceCandidate()` sẽ throw lỗi.

### Giải pháp — Buffer map

```typescript
const pendingCandidates = new Map<string, RTCIceCandidateInit[]>();

// Khi nhận candidate
const handleCandidate = async (fromUserId: string, candidate: RTCIceCandidateInit) => {
  const pc = peerConnections.get(fromUserId);

  if (!pc || !pc.remoteDescription) {
    // Chưa set remote desc → buffer lại
    if (!pendingCandidates.has(fromUserId)) {
      pendingCandidates.set(fromUserId, []);
    }
    pendingCandidates.get(fromUserId)!.push(candidate);
  } else {
    // Đã sẵn sàng → add ngay
    await pc.addIceCandidate(new RTCIceCandidate(candidate));
  }
};

// Sau khi setRemoteDescription xong → flush buffer
const flushPendingCandidates = async (userId: string) => {
  const pc = peerConnections.get(userId)!;
  const pending = pendingCandidates.get(userId) ?? [];
  for (const candidate of pending) {
    await pc.addIceCandidate(new RTCIceCandidate(candidate));
  }
  pendingCandidates.set(userId, []);
};
```

---

## 10. Quản lý trạng thái (State Management)

### Web — Redux `callSlice`

**File**: `apps/web/src/store/slices/callSlice.ts`

```typescript
interface CallSliceState {
  status: 'idle' | 'calling' | 'ringing' | 'connected';
  callId: string | null;
  conversationId: string | null;
  callType: 'audio' | 'video';
  participantIds: string[];
  initiatorId: string | null;
  incomingCall: IncomingCallInfo | null;
  isMuted: boolean;
  isVideoOff: boolean;
  isScreenSharing: boolean;
}
```

**Actions**:

| Action                | Khi nào dispatch                              | Effect                                             |
| --------------------- | --------------------------------------------- | -------------------------------------------------- |
| `startCall()`         | Caller nhấn Phone/Video button                | status → 'calling', lưu callId/convId/participants |
| `acceptCall()`        | Callee nhấn Accept                            | status → 'ringing', lưu thông tin cuộc gọi         |
| `setCallConnected()`  | WebRTC connected event                        | status → 'connected'                               |
| `addParticipant()`    | Nhận `call:accepted` (ai đó join)             | Thêm userId vào participantIds                     |
| `removeParticipant()` | Nhận `call:ended` của 1 người (partial leave) | Xóa userId khỏi participantIds                     |
| `setIncomingCall()`   | Nhận `call:incoming`                          | incomingCall = payload (hiện modal)                |
| `clearIncomingCall()` | Sau khi accept/reject                         | incomingCall = null (ẩn modal)                     |
| `endCall()`           | Hang up, nhận `call:ended`, `call:busy`       | Reset toàn bộ state về initialState                |
| `setMuted()`          | Nhấn nút mute                                 | isMuted toggle                                     |
| `setVideoOff()`       | Nhấn nút camera                               | isVideoOff toggle                                  |
| `setScreenSharing()`  | Start/Stop screen share                       | isScreenSharing toggle                             |

**Đăng ký reducer**:

```typescript
// apps/web/src/store/index.ts
combineReducers({ ..., call: callReducer })
```

### Mobile — Zustand `callStore`

**File**: `apps/mobile/src/store/callStore.ts`

Same state shape, same actions — nhưng dùng Zustand pattern:

```typescript
const useCallStore = create<CallState>((set) => ({
  status: 'idle',
  incomingCall: null,
  // ... same fields

  startCall: (payload) => set({ status: 'calling', ...payload }),
  setIncomingCall: (info) => set({ incomingCall: info }),
  endCall: () => set(initialState),
  // ...
}));
```

### Đăng ký event listeners

**Web** — `ChatSocketInitializer.tsx`:

```typescript
appSocket.on('call:incoming', (payload) => dispatch(setIncomingCall(payload)));
appSocket.on('call:rejected', () => {
  /* toast */ dispatch(endCall());
});
appSocket.on('call:ended', () => dispatch(endCall()));
appSocket.on('call:busy', () => {
  /* toast */ dispatch(clearIncomingCall());
  dispatch(endCall());
});
```

**Mobile** — `useChatSocket.ts`:

```typescript
const onCallIncoming = (payload) => setIncomingCall(payload);
const onCallEnded = () => endCall();
const onCallBusy = () => {
  clearIncomingCall();
  endCall();
};

socketService.on('call:incoming', onCallIncoming);
socketService.on('call:ended', onCallEnded);
socketService.on('call:busy', onCallBusy);

// Cleanup
return () => {
  socketService.off('call:incoming', onCallIncoming);
  socketService.off('call:ended', onCallEnded);
  socketService.off('call:busy', onCallBusy);
};
```

---

## 11. Web — UI Components

### `IncomingCallModal.tsx`

**File**: `apps/web/src/components/call/IncomingCallModal.tsx`

**Hiển thị khi**: `useAppSelector(s => s.call.incomingCall) !== null`

**Vị trí**: Fixed, top-center, z-index 9999 (trên CallRoom)

**Ringtone**: Tạo bằng Web Audio API (`AudioContext` oscillator) — không cần file âm thanh:

```typescript
const ctx = new AudioContext();
const osc = ctx.createOscillator();
osc.frequency.setValueAtTime(480, ctx.currentTime);
// Tạo beep mỗi 1.5 giây
```

**Actions**:

- **Accept**: `dispatch(acceptCall(...))` + `appSocket.emit('call:accept', { callId })` + `getLocalStream()` + CallRoom auto-shows
- **Decline**: `appSocket.emit('call:reject', { callId })` + `dispatch(clearIncomingCall())` + `dispatch(endCall())`

---

### `CallRoom.tsx`

**File**: `apps/web/src/components/call/CallRoom.tsx`

**Hiển thị khi**: `call.status !== 'idle'`

**Layout**:

```
┌──────────────────────────────────────────────────────────┐
│                    CALL ROOM (fullscreen)                 │
│  ┌────────────────────────────────────────────────────┐  │
│  │              Remote Video Grid                     │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐           │  │
│  │  │ User B  │  │ User C  │  │ User D  │           │  │
│  │  │ <video> │  │ <video> │  │ <video> │           │  │
│  │  └─────────┘  └─────────┘  └─────────┘           │  │
│  └────────────────────────────────────────────────────┘  │
│                                          ┌───────────┐   │
│                                          │ Local PiP │   │
│                                          │ <video>   │   │
│                                          │ (muted)   │   │
│                                          └───────────┘   │
│  ┌──────────────────────────────────────────────────┐    │
│  │  🎤 Mute  |  📷 Camera  |  🖥️ Screen  |  📵 Hang up │    │
│  └──────────────────────────────────────────────────┘    │
│  ⏱ 00:01:23                  [Conversation name]         │
└──────────────────────────────────────────────────────────┘
```

**Video Grid logic**:

- 1 remote: full screen
- 2 remotes: side by side (50/50)
- 3+ remotes: 3-column grid

**VideoTile component**: Dùng `useEffect` để attach `MediaStream` vào `<video>` element qua `videoRef.current.srcObject = stream`.

**Wiring**:

```typescript
// Khi nhận call:accepted → initiateOffer với người mới join
appSocket.on('call:accepted', (data) => {
  dispatch(addParticipant(data.userId));
  initiateOffer(data.userId);
});
```

---

### Call Buttons trong ChatRoom header

**File**: `apps/web/src/pages/private/chat/components/ChatRoom.tsx`

```tsx
{
  callState.status === 'idle' && (
    <>
      <button onClick={() => initiateCall('audio')}>
        <Phone />
      </button>
      <button onClick={() => initiateCall('video')}>
        <Video />
      </button>
    </>
  );
}
```

`initiateCall` tạo callId, emit `call:initiate`, dispatch `startCall`.

---

## 12. Mobile — UI Components & Screens

### `IncomingCallBanner` (inline trong `_layout.tsx`)

**Vị trí**: `position: 'absolute'`, top theo StatusBar height, `zIndex: 9999`

**Hiển thị khi**: `useCallStore(s => s.incomingCall) !== null`

**Actions**:

- **Accept** (📞 xanh): `socketService.emit('call:accept', ...)` + `acceptCallStore(...)` + `router.push('/call')`
- **Decline** (📵 đỏ): `socketService.emit('call:reject', ...)` + `clearIncomingCall()` + `endCall()`

### `app/call.tsx` — Full-screen Call Screen

**Truy cập**: Via Expo Router `/call` (đăng ký trong `_layout.tsx` Stack với `presentation: 'fullScreenModal'`)

**Flow**:

1. Mount → `getLocalStream(callType === 'video', true)` → hiện local video/audio
2. Nếu `!isWebRTCAvailable` → Alert hướng dẫn chạy `npx expo prebuild`
3. Hiện `RTCView` cho local + remote streams
4. Controls: Mute, Camera toggle, Hang up
5. Hang up: `emit('call:end')` + `cleanup()` + `endCall()` + `router.back()`

### Call Buttons trong `conversation/[id].tsx`

```tsx
{
  callStatus === 'idle' && (
    <>
      <TouchableOpacity onPress={() => initiateCall('audio')}>
        <Phone size={20} color="#6b7280" />
      </TouchableOpacity>
      <TouchableOpacity onPress={() => initiateCall('video')}>
        <Video size={20} color="#6b7280" />
      </TouchableOpacity>
    </>
  );
}
```

`initiateCall` tạo callId bằng `Math.random().toString(36)`, emit `call:initiate`, gọi `startCall`, navigate `/call`.

---

## 13. Xử lý Disconnect & Cleanup

### Khi user đóng browser tab / mất mạng

Gateway tự động phát hiện socket disconnect:

```typescript
handleDisconnect(client: Socket) {
  // Tìm tất cả cuộc gọi của user này
  for (const [callId, session] of this.activeCalls) {
    if (!session.acceptedIds.includes(userId)) continue;

    session.acceptedIds = session.acceptedIds.filter(id => id !== userId);

    if (session.acceptedIds.length === 0) {
      this.activeCalls.delete(callId);  // xóa session rỗng
    } else {
      // Notify những người còn lại
      for (const uid of session.acceptedIds) {
        this.emitToUser(uid, 'call:ended', { callId });
      }
    }
  }
}
```

### Client cleanup (`useWebRTC.cleanup()`)

```typescript
cleanup() {
  // Dừng tất cả tracks local
  localStream?.getTracks().forEach(t => t.stop());

  // Đóng tất cả peer connections
  for (const pc of peerConnections.values()) {
    pc.close();
  }

  // Reset state
  peerConnections.clear();
  pendingCandidates.clear();
  setLocalStream(null);
  setRemoteStreams({});
}
```

---

## 14. Cải tiến Gọi nhóm & UI (2026-04-19)

Các tính năng được bổ sung/sửa trong phiên cập nhật gần nhất:

### 14.1 Kết thúc cuộc gọi khi chỉ còn 1 người (Gateway)

**File**: `gateway/api-gateway/src/socket/socket.gateway.ts`

**Vấn đề**: Khi người còn lại trong cuộc gọi 1-1 hang up, người kia vẫn ở trạng thái `connected`.

**Fix**: Trong `handleCallEnd` và `handleDisconnect`, khi `acceptedIds.length <= 1` sau khi xóa 1 người thì tự động kết thúc cuộc gọi:

```typescript
// Sau khi xóa user khỏi acceptedIds:
if (session.acceptedIds.length <= 1) {
  // Chỉ còn ≤1 người → kết thúc cuộc gọi
  const remaining = session.acceptedIds;
  for (const uid of remaining) {
    this.emitToUser(uid, 'call:ended', { callId });
  }
  this.activeCalls.delete(callId);
}
```

---

### 14.2 Screen Share — Chia sẻ màn hình (Web)

**File**: `apps/web/src/hooks/useWebRTC.ts`

#### API `getDisplayMedia()`

```typescript
const screenStream = await navigator.mediaDevices.getDisplayMedia({
  video: { frameRate: 30, width: { ideal: 1920 }, height: { ideal: 1080 } },
  audio: false,
});
```

#### Signal `screen_share_status`

Screen share status được truyền đến các peer qua kênh `call:signal` với type tuỳ chỉnh `screen_share_status`:

```typescript
// Khi bắt đầu share:
appSocket.emit('call:signal', {
  callId,
  targetUserId: peerId,
  signal: { type: 'screen_share_status', isSharing: true },
});

// Khi dừng share:
appSocket.emit('call:signal', {
  callId,
  targetUserId: peerId,
  signal: { type: 'screen_share_status', isSharing: false },
});
```

Hook cập nhật `screenSharingUsers: Record<string, boolean>` khi nhận được signal này.

#### `isVideoOffRef` — giữ trạng thái camera khi restore

Trước khi bắt đầu screen share, camera state được lưu vào ref để restore đúng sau khi stop:

```typescript
const isVideoOffRef = useRef(isVideoOff);

// Khi start screen share:
isVideoOffRef.current = isVideoOff; // lưu lại
// Khi stop screen share:
localStream.getVideoTracks().forEach((t) => (t.enabled = !isVideoOffRef.current)); // restore
```

#### VideoTile — `forceContain` và auto-detect screen share

`VideoTile` nhận prop `forceContain?: boolean`. Khi `true`, dùng `object-fit: contain` thay vì `cover` để hiển thị đúng tỷ lệ màn hình share. VideoTile tự auto-detect bằng cách kiểm tra aspect ratio khi `loadedmetadata`:

```typescript
video.addEventListener('loadedmetadata', () => {
  const ratio = video.videoWidth / video.videoHeight;
  setIsScreenShare(ratio > 2.0); // màn hình thường có ratio > 2:1
});
```

---

### 14.3 `ongoingGroupCall` — Trạng thái theo dõi group call đang diễn ra

**File**: `apps/web/src/store/slices/callSlice.ts`

#### Field mới

```typescript
interface CallSliceState {
  // ... các field cũ
  ongoingGroupCall: IncomingCallInfo | null; // NEW
}
```

#### Action `setOngoingGroupCall`

```typescript
setOngoingGroupCall: (state, action: PayloadAction<IncomingCallInfo | null>) => {
  state.ongoingGroupCall = action.payload;
};
```

#### `endCall` giữ nguyên `ongoingGroupCall`

```typescript
endCall: (state) => ({ ...initialState, ongoingGroupCall: state.ongoingGroupCall });
```

Điều này cho phép user xem banner tham gia lại dù đã end/reject call.

#### Trigger trong `ChatSocketInitializer.tsx`

```typescript
appSocket.on('call:incoming', (payload) => {
  dispatch(setIncomingCall(payload));
  // Nếu là group call (> 2 người) → theo dõi để hiện rejoin banner
  if (payload.participantIds && payload.participantIds.length > 2) {
    dispatch(setOngoingGroupCall(payload));
  }
});

// Khi cuộc gọi bị huỷ (call:ended, call:rejected):
dispatch(setOngoingGroupCall(null));
```

---

### 14.4 Rejoin Banner — Tham gia lại group call đang diễn ra

**File**: `apps/web/src/pages/private/chat/components/ChatRoom.tsx`

#### Điều kiện hiển thị

```typescript
const showRejoinBanner =
  callState.ongoingGroupCall?.conversationId === conversationId && callState.status === 'idle';
```

#### UI

```tsx
{
  showRejoinBanner && (
    <div className="flex items-center gap-3 px-4 py-2.5 bg-green-500/10 border-b border-green-500/20 flex-shrink-0">
      <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
      <span className="text-[13px] text-green-700 font-medium flex-1">Đang có cuộc gọi nhóm</span>
      <button
        onClick={() => {
          const ongoing = callState.ongoingGroupCall!;
          appSocket.emit('call:accept', { callId: ongoing.callId });
          dispatch(
            acceptCall({
              callId: ongoing.callId,
              conversationId: ongoing.conversationId,
              callType: ongoing.callType,
              callerId: ongoing.callerId,
              currentUserId: currentUser?.id,
            })
          );
        }}
        className="text-[12px] font-semibold text-green-600 hover:text-green-700 ..."
      >
        Tham gia
      </button>
    </div>
  );
}
```

---

### 14.5 `acceptCall` — Fix callee không có sidebar

**File**: `apps/web/src/store/slices/callSlice.ts`

**Vấn đề**: Callee sau khi accept call, `participantIds` chỉ có `[callerId]` (1 người) nên `showSidebar = length >= 1` vẫn đúng nhưng sidebar thiếu chính mình.

**Fix**: Thêm `currentUserId` vào payload:

```typescript
acceptCall: (
  state,
  action: PayloadAction<{
    callId: string;
    conversationId: string;
    callType: 'audio' | 'video';
    callerId: string;
    currentUserId?: string; // NEW
  }>
) => {
  const ids = [action.payload.callerId];
  if (action.payload.currentUserId) ids.push(action.payload.currentUserId);
  state.participantIds = ids; // [callerId, currentUserId]
  // ...
};
```

Được pass từ `IncomingCallModal.tsx` và `ChatRoom.tsx` (rejoin button):

```typescript
dispatch(
  acceptCall({
    ...payload,
    currentUserId: currentUser?.id, // từ useAppSelector(s => s.auth.user)
  })
);
```

---

### 14.6 `useVoiceActivity` — Phát hiện người đang nói

**File**: `apps/web/src/components/call/CallRoom.tsx` (inline hook)

Dùng Web Audio API `AnalyserNode` để detect voice activity trong realtime:

```typescript
function useVoiceActivity(
  localStream: MediaStream | null,
  remoteStreams: Record<string, MediaStream>,
  localUserId?: string
): Record<string, boolean> {
  const [speaking, setSpeaking] = useState<Record<string, boolean>>({});

  useEffect(() => {
    const ctx = new AudioContext();
    const analysers = new Map<string, AnalyserNode>();

    const setupAnalyser = (userId: string, stream: MediaStream) => {
      const source = ctx.createMediaStreamSource(stream);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      source.connect(analyser);
      analysers.set(userId, analyser);
    };

    if (localStream && localUserId) setupAnalyser(localUserId, localStream);
    for (const [uid, stream] of Object.entries(remoteStreams)) {
      setupAnalyser(uid, stream);
    }

    const poll = setInterval(() => {
      const result: Record<string, boolean> = {};
      const buf = new Uint8Array(64);
      for (const [uid, analyser] of analysers) {
        analyser.getByteFrequencyData(buf);
        const avg = buf.reduce((s, v) => s + v, 0) / buf.length;
        result[uid] = avg > 12; // threshold
      }
      setSpeaking(result);
    }, 150);

    return () => {
      clearInterval(poll);
      ctx.close();
    };
  }, [localStream, remoteStreams, localUserId]);

  return speaking;
}
```

---

### 14.7 `ParticipantSidebar` — Sidebar danh sách participants

**File**: `apps/web/src/components/call/CallRoom.tsx`

Hiển thị bên phải CallRoom, liệt kê tất cả participants với avatar, tên và speaking indicator:

```tsx
<ParticipantSidebar
  participantIds={call.participantIds}
  speaking={voiceActivity}
  remoteStreams={remoteStreams}
  currentUserId={currentUser?.id}
/>
```

**Điều kiện hiển thị**: `call.participantIds.length >= 1`

**Speaking ring**: Avatar có `ring-2 ring-green-400` khi `speaking[userId] === true`.

---

### 14.8 `AudioGroupView` — Layout audio-only group call

**File**: `apps/web/src/components/call/CallRoom.tsx`

Khi `callType === 'audio'` và có nhiều participants, hiển thị grid avatar:

```tsx
function AudioGroupView({ participantIds, speaking }) {
  return (
    <div className="grid grid-cols-3 gap-4 p-8">
      {participantIds.map((uid) => (
        <div
          key={uid}
          className={cn(
            'flex flex-col items-center gap-2',
            speaking[uid] && 'ring-2 ring-green-400 rounded-full'
          )}
        >
          <UserAvatar userId={uid} size={64} />
          <UserName userId={uid} />
        </div>
      ))}
    </div>
  );
}
```

---

### 14.9 `GroupLayout` — Spotlight cho screen sharer

**File**: `apps/web/src/components/call/CallRoom.tsx`

Khi có người đang share màn hình, layout chuyển sang spotlight mode: stream của người share chiếm phần lớn màn hình, các participant khác thu nhỏ bên cạnh:

```tsx
function GroupLayout({ screenSharingUsers, remoteStreams, ... }) {
  const sharerUserId = Object.keys(screenSharingUsers).find(uid => screenSharingUsers[uid]);

  if (sharerUserId) {
    return (
      <div className="flex gap-2 h-full">
        {/* Spotlight — màn hình của người share */}
        <VideoTile
          stream={remoteStreams[sharerUserId]}
          userId={sharerUserId}
          forceContain={true}
          className="flex-1"
        />
        {/* Thumbnails — những người còn lại */}
        <div className="flex flex-col gap-2 w-40">
          {otherParticipants.map(uid => (
            <VideoTile key={uid} stream={remoteStreams[uid]} userId={uid} className="flex-1" />
          ))}
        </div>
      </div>
    );
  }
  // ... layout bình thường
}
```

---

### 14.10 Fix mobile "Body is unusable: Body has already been read"

**File**: `apps/mobile/src/services/socket.ts`

**Root cause**: socket.io-client 4.7+ sử dụng `fetch()` API cho polling transport. Trong React Native 0.81, native fetch theo chuẩn WHATWG nghiêm ngặt: response body chỉ được đọc một lần. Khi socket.io thực hiện polling và có path error/retry, body bị đọc 2 lần → "Body is unusable".

**Fix**: Chỉ dùng WebSocket transport, bỏ hoàn toàn polling:

```typescript
this.socket = io(getApiUrl(), {
  path: '/socket.io',
  // Force WebSocket only — polling dùng fetch() trong socket.io-client 4.7+,
  // gây "Body is unusable" với RN 0.81's WHATWG fetch implementation
  transports: ['websocket'],
  upgrade: false,
});
```

`upgrade: false` ngăn socket.io tự upgrade từ polling lên WebSocket (không cần thiết khi đã dùng WebSocket trực tiếp).

**Lợi ích bổ sung**: WebSocket-only cũng giảm latency do bỏ qua giai đoạn polling handshake.

---

## 15. Hạn chế & Edge Cases

| Tình huống                           | Xử lý hiện tại                                       | Ghi chú                                                |
| ------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------ |
| Gateway restart khi đang gọi         | Cuộc gọi bị mất (activeCalls là in-memory)           | Cần Redis để persist nếu muốn HA                       |
| User từ chối → caller thấy "Từ chối" | `call:rejected` event → toast notification           | Chỉ caller nhận, không notify các peer khác            |
| User bận (đang trong call khác)      | `call:busy` event từ client                          | Client detect qua `callStatus !== 'idle'` và emit busy |
| Nhiều hơn 8 người                    | Không có validation hiện tại                         | Cần thêm check trong `handleCallInitiate`              |
| Mobile Expo Go                       | `isWebRTCAvailable = false` + Alert hướng dẫn        | Cần `npx expo prebuild` để dùng native WebRTC          |
| ICE candidate đến trước offer        | Buffer trong `pendingCandidates` Map                 | Flush sau khi `setRemoteDescription` xong              |
| Người join muộn (group call)         | Existing participants tự initiate offer đến newcomer | Không cần newcomer biết ai đang trong phòng            |
| Screen share (mobile)                | Không hỗ trợ                                         | Web có `getDisplayMedia()`, mobile thiếu API           |
| Call history / lịch sử cuộc gọi      | Không lưu vào DB                                     | Có thể thêm sau (MongoDB collection `callLogs`)        |
| Reconnect khi mất mạng tạm thời      | Chưa implement reconnect logic                       | Cuộc gọi sẽ bị kết thúc                                |

---

## 15. Biến môi trường

### Web (`.env` hoặc Vite env)

```env
VITE_TURN_USERNAME=chatapp
VITE_TURN_PASSWORD=chatapp_turn_secret
```

### docker-compose (coturn service)

```env
TURN_USERNAME=chatapp
TURN_PASSWORD=chatapp_turn_secret
```

### Production checklist

- [ ] Đổi `TURN_USERNAME` và `TURN_PASSWORD` thành giá trị mạnh
- [ ] Mở firewall UDP `3478` và `49152-49200` cho coturn
- [ ] Thêm TLS nếu deploy production (`--cert` + `--pkey` trong coturn command)
- [ ] Thêm `VITE_TURN_SERVER_URL` để cấu hình URL TURN server động

---

## 16. Cấu trúc file trong project

```
chat-app/
├── docker-compose.yml                          ← coturn service
├── gateway/api-gateway/src/socket/
│   └── socket.gateway.ts                       ← 6 call handlers + activeCalls Map
├── apps/web/src/
│   ├── store/
│   │   ├── index.ts                            ← call: callReducer
│   │   └── slices/
│   │       ├── callSlice.ts                    ← Redux state + actions
│   │       └── index.ts                        ← re-export call actions
│   ├── hooks/
│   │   └── useWebRTC.ts                        ← RTCPeerConnection mesh (web)
│   ├── components/call/
│   │   ├── IncomingCallModal.tsx               ← Incoming call UI (web)
│   │   └── CallRoom.tsx                        ← Full-screen call UI (web)
│   ├── pages/private/chat/components/
│   │   └── ChatRoom.tsx                        ← Phone/Video buttons in header
│   ├── providers/
│   │   └── ChatSocketInitializer.tsx           ← call:incoming/rejected/ended/busy listeners
│   └── App.tsx                                 ← Mount IncomingCallModal + CallRoom
└── apps/mobile/
    ├── app/
    │   ├── _layout.tsx                         ← IncomingCallBanner + call screen in Stack
    │   ├── call.tsx                            ← Full-screen call screen (mobile)
    │   └── conversation/[id].tsx               ← Phone/Video buttons in header
    └── src/
        ├── store/callStore.ts                  ← Zustand call state
        ├── hooks/
        │   ├── useWebRTC.ts                    ← RTCPeerConnection mesh (mobile)
        │   └── useChatSocket.ts                ← call:incoming/ended/busy listeners
        └── services/socket.ts                  ← socketService (existing)
```

---

## 17. Sơ đồ tuần tự đầy đủ

### Gọi nhóm 3 người: A gọi B và C

```
A (Caller)          Gateway           B               C
    │                  │              │               │
    │ call:initiate    │              │               │
    │─────────────────►│              │               │
    │                  │ call:incoming│               │
    │                  │─────────────►│               │
    │                  │ call:incoming│               │
    │                  │─────────────────────────────►│
    │                  │              │               │
    │                  │ [B accept]   │               │
    │                  │◄─────────────│               │
    │                  │              │               │
    │ call:accepted(B) │              │               │
    │◄─────────────────│              │               │
    │                  │ call:accepted(B) to B itself  │
    │                  │ (skipped — B !== B)           │
    │                  │              │               │
    │ initiateOffer(B) │              │               │
    │  offer ─────────────────────────────────────►  │ (to B)
    │                  │              │ answer ──────►│
    │◄─────────────────────────────── answer          │
    │ ═══════════════ A↔B P2P connected ════════════  │
    │                  │              │               │
    │                  │ [C accept]   │               │
    │                  │◄─────────────────────────────│
    │                  │              │               │
    │ call:accepted(C) │              │               │
    │◄─────────────────│              │               │
    │                  │ call:accepted(C)             │
    │                  │─────────────►│               │
    │                  │              │               │
    │ initiateOffer(C) │              │               │
    │  offer ─────────────────────────────────────►   │ (to C)
    │                  │              │               │ answer
    │◄─────────────────────────────────────────────── │
    │ ════════════════ A↔C P2P connected ═════════════│
    │                  │              │               │
    │                  │              │initiateOffer(C)│
    │                  │              │  offer ───────►│
    │                  │              │◄─── answer     │
    │                  │              │               │
    │                  │ ════ B↔C P2P connected ════  │
    │                  │              │               │
    │ ═══════ FULL MESH: A↔B, A↔C, B↔C ═══════════════
```

---

_Tài liệu tạo ngày: 2026-04-17 — Mô tả chi tiết tính năng Gọi Voice/Video (Call Feature) của BinChat._
