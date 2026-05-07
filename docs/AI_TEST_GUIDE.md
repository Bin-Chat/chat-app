# AI Service — Hướng dẫn test đầy đủ

> Base URL trực tiếp: `http://localhost:3050`  
> Qua API Gateway (cần JWT): `http://localhost:3000`  
> Tất cả request đều cần header `Content-Type: application/json`

---

## 0. Kiểm tra service khởi động

```bash
curl http://localhost:3050/api/ai/health
```

**Expected response:**
```json
{
  "status": "ok",
  "service": "AI Service",
  "timestamp": "2026-04-20T09:17:22.123Z"
}
```

---

## 1. Dịch tin nhắn — Translation

**Endpoint:** `POST /api/ai/translate`

### 1.1 Dịch sang tiếng Anh
```bash
curl -X POST http://localhost:3050/api/ai/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Chào buổi sáng, bạn có khỏe không?",
    "targetLanguage": "en"
  }'
```

### 1.2 Dịch sang tiếng Nhật (có khai báo ngôn ngữ gốc)
```bash
curl -X POST http://localhost:3050/api/ai/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Good morning, how are you?",
    "targetLanguage": "ja",
    "sourceLanguage": "en"
  }'
```

### 1.3 Dịch sang tiếng Việt
```bash
curl -X POST http://localhost:3050/api/ai/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "The weather is really nice today!",
    "targetLanguage": "vi"
  }'
```

**Expected response:**
```json
{
  "original": "The weather is really nice today!",
  "translated": "Thời tiết hôm nay thật đẹp!",
  "targetLanguage": "vi"
}
```

---

## 2. Tóm tắt hội thoại — Conversation Summary

**Endpoint:** `POST /api/ai/conversations/:id/summary`

> Hỗ trợ `fromDate` / `toDate` (ISO date string `YYYY-MM-DD`) để giới hạn khoảng thời gian.  
> Trả về bản tóm tắt có cấu trúc 4 phần: Tổng quan · Nội dung chính · Kết luận · Hành động.

### 2.1 Tóm tắt với date range (khuyến nghị)
```bash
curl -X POST http://localhost:3050/api/ai/conversations/CONVERSATION_ID/summary \
  -H "Content-Type: application/json" \
  -d '{
    "fromDate": "2026-04-13",
    "toDate": "2026-04-20",
    "messages": [
      { "senderId": "alice", "senderName": "Alice", "content": "Mọi người ơi, deadline dự án là thứ 6 này nhé", "timestamp": "2026-04-15T09:00:00Z" },
      { "senderId": "bob",   "senderName": "Bob",   "content": "Tôi đã xong phần backend rồi",                "timestamp": "2026-04-15T09:05:00Z" },
      { "senderId": "charlie","senderName":"Charlie","content": "Frontend còn 2 trang nữa, xong chiều nay",   "timestamp": "2026-04-15T09:10:00Z" },
      { "senderId": "alice", "senderName": "Alice", "content": "Tốt, tôi sẽ viết tài liệu và test ngày mai", "timestamp": "2026-04-15T09:15:00Z" },
      { "senderId": "bob",   "senderName": "Bob",   "content": "Tôi sẽ review code vào thứ 5",               "timestamp": "2026-04-15T09:20:00Z" }
    ]
  }'
```

**Expected response:**
```json
{
  "conversationId": "CONVERSATION_ID",
  "summary": "📋 TỔNG QUAN\nNhóm thảo luận tiến độ dự án với deadline thứ 6 (5 tin nhắn, từ 15/04/2026)\n\n🎯 NỘI DUNG CHÍNH\n• Bob hoàn thành backend\n• Charlie xong frontend chiều nay\n• Alice phụ trách tài liệu và test\n\n✅ KẾT LUẬN & QUYẾT ĐỊNH\n• Deadline thứ 6 được xác nhận\n\n⚡ HÀNH ĐỘNG CẦN THỰC HIỆN\n• Bob: review code vào thứ 5",
  "fromDate": "2026-04-13",
  "toDate": "2026-04-20",
  "messageCount": 5
}
```

### 2.2 Tóm tắt không có date range (toàn bộ messages)
```bash
curl -X POST http://localhost:3050/api/ai/conversations/CONVERSATION_ID/summary \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      { "senderId": "user-001", "content": "Ê tối nay đi ăn không?",      "timestamp": "2026-04-20T18:00:00Z" },
      { "senderId": "user-002", "content": "Đi thôi, tao đói rồi. Ăn gì?","timestamp": "2026-04-20T18:01:00Z" },
      { "senderId": "user-001", "content": "Ăn bún bò đi, chỗ quen đó",   "timestamp": "2026-04-20T18:02:00Z" },
      { "senderId": "user-002", "content": "OK gặp nhau lúc 7h nhé",       "timestamp": "2026-04-20T18:03:00Z" }
    ]
  }'
```

> **Cache key:** `ai:summary:{conversationId}:{count}:{fromDate}_{toDate}` — TTL 1h.  
> Gọi lại cùng params sẽ trả về cached (không gọi OpenAI).

---

## 3. Tìm kiếm ngữ nghĩa — Semantic Search

**Endpoint:** `POST /api/ai/search`

> Tin nhắn chỉ được index tự động khi **gửi qua Socket.IO** (Kafka → ai-service).  
> Chỉ trả về kết quả có `score >= 0.65` (mặc định). Tùy chỉnh bằng `minScore`.

### 3.1 Tìm kiếm đơn giản
```bash
curl -X POST http://localhost:3050/api/ai/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "ăn tối hôm nay",
    "limit": 5
  }'
```

### 3.2 Tìm kiếm trong một conversation với minScore tùy chỉnh
```bash
curl -X POST http://localhost:3050/api/ai/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "deadline dự án",
    "conversationId": "CONVERSATION_ID",
    "limit": 10,
    "minScore": 0.75
  }'
```

### 3.3 Tìm kiếm với ngưỡng thấp hơn (nhiều kết quả hơn)
```bash
curl -X POST http://localhost:3050/api/ai/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "meeting tomorrow morning",
    "limit": 10,
    "minScore": 0.5
  }'
```

**Expected response:**
```json
{
  "results": [
    {
      "messageId": "msg-abc123",
      "conversationId": "conv-xyz",
      "senderId": "user-001",
      "content": "Họp sáng mai lúc 9h nhé mọi người",
      "timestamp": "2026-04-19T15:00:00Z",
      "score": 0.89
    }
  ],
  "total": 1,
  "query": "meeting tomorrow morning"
}
```

> **Nếu chưa có tin nhắn nào index:** trả về `{ results: [], total: 0 }` (không lỗi).  
> **minScore:** range `0.0 → 1.0`, mặc định `0.65`. Tăng để lọc chặt hơn, giảm để nhiều kết quả hơn.

---

## 4. RAG Bot — Hỏi đáp AI

**Endpoint:** `POST /api/ai/ask`

> Dựa trên tài liệu đã được index vào collection `binchat_documents`.

### 4.1 Câu hỏi đơn giản (không có tài liệu nền)
```bash
curl -X POST http://localhost:3050/api/ai/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "BinChat là gì?"
  }'
```

### 4.2 Câu hỏi với collectionId cụ thể
```bash
curl -X POST http://localhost:3050/api/ai/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Cách sử dụng tính năng gửi file?",
    "collectionId": "binchat-docs"
  }'
```

**Expected response:**
```json
{
  "answer": "BinChat là ứng dụng chat thời gian thực hỗ trợ...",
  "question": "BinChat là gì?"
}
```

---

## 5. Index tài liệu — Document Indexing

**Endpoint:** `POST /api/ai/documents/index`

> Dùng để thêm tài liệu vào Qdrant để RAG Bot có thể trả lời.

### 5.1 Index tài liệu mô tả ứng dụng
```bash
curl -X POST http://localhost:3050/api/ai/documents/index \
  -H "Content-Type: application/json" \
  -d '{
    "text": "BinChat là ứng dụng nhắn tin thời gian thực hỗ trợ chat 1-1 và nhóm. Người dùng có thể gửi văn bản, hình ảnh, video và tài liệu. Ứng dụng sử dụng kiến trúc microservices với NestJS và React.",
    "collectionId": "binchat-docs",
    "source": "README.md",
    "title": "Giới thiệu BinChat"
  }'
```

### 5.3 Seed toàn bộ tài liệu BinChat (khuyến nghị trước khi test RAG)

Dùng seed script có sẵn — index 8 tài liệu về BinChat vào Qdrant:

```bash
# Chạy từ thư mục services/ai/
cd services/ai
npm run seed:rag
```

Script sẽ index các tài liệu: Giới thiệu BinChat, Tính năng chính, Tính năng AI, Hướng dẫn nhóm chat, Upload media, Hệ thống bạn bè, Kiến trúc kỹ thuật, FAQ.

Sau khi seed xong, RAG Bot có thể trả lời câu hỏi như:
- "BinChat có những tính năng AI nào?"
- "Làm sao thu hồi tin nhắn?"
- "Kiến trúc kỹ thuật của BinChat gồm những gì?"

**Expected response:**
```json
{
  "message": "Document indexed successfully",
  "id": "uuid-xxxx",
  "chunks": 1
}
```

---

## 6. Test luồng RAG hoàn chỉnh (Index → Ask)

Thực hiện tuần tự:

```bash
# Bước 1: Index tài liệu
curl -X POST http://localhost:3050/api/ai/documents/index \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Tính năng AI của BinChat gồm: dịch tin nhắn sang 50+ ngôn ngữ, tóm tắt hội thoại dài, tìm kiếm tin nhắn theo ngữ nghĩa, và hỏi đáp thông minh với RAG Bot. Tất cả được xây dựng trên OpenAI GPT-4.",
    "collectionId": "binchat-docs",
    "title": "Tính năng AI"
  }'

# Bước 2: Hỏi ngay sau đó
curl -X POST http://localhost:3050/api/ai/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "BinChat có những tính năng AI nào?",
    "collectionId": "binchat-docs"
  }'
```

---

## 7. Test qua API Gateway (cần JWT)

Lấy token sau khi đăng nhập:

```bash
# Đăng nhập lấy token
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpassword"}' \
  | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

# Dịch tin nhắn qua gateway
curl -X POST http://localhost:3000/api/ai/translate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "text": "Hello world",
    "targetLanguage": "vi"
  }'

# Hỏi AI qua gateway
curl -X POST http://localhost:3000/api/ai/ask \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "question": "Tính năng nổi bật của BinChat?"
  }'
```

---

## 8. Test Kiểm duyệt nội dung — Moderation

Moderation **không có HTTP endpoint** — trigger tự động qua Kafka khi gửi tin nhắn.

**Luồng:** Chat UI → Socket.IO → api-gateway → Kafka topic `chat.message.sent` → ai-service consume → OpenAI Moderation API → nếu vi phạm → Kafka `chat.message.flagged`

### 8.1 Test bằng cách gửi tin nhắn bình thường (qua UI)
1. Mở web app / mobile app, vào một cuộc trò chuyện
2. Gửi bất kỳ tin nhắn văn bản nào
3. Kiểm tra logs ai-service để xác nhận Kafka consumer đang chạy:

```bash
docker logs ai-service 2>&1 | grep -i "kafka\|moderat\|consumer" | tail -20
```

### 8.2 Kiểm tra Kafka consumer đang active
```bash
# Xem consumer groups
docker exec chat-redpanda rpk group list

# Xem lag của consumer group ai-service
docker exec chat-redpanda rpk group describe ai-service-group
```

### 8.3 Gửi trực tiếp vào Kafka topic để test (không cần UI)
```bash
# Gửi message event vào Kafka
docker exec -i chat-redpanda rpk topic produce chat.message.sent <<EOF
{"messageId":"test-mod-001","conversationId":"conv-test","content":"Hello, how are you?","senderId":"user-001","timestamp":"2026-04-20T10:00:00Z"}
EOF

# Kiểm tra logs xem ai-service có nhận không
docker logs ai-service 2>&1 | grep "test-mod-001" | tail -5
```

### 8.4 Xem kết quả moderation trong logs
```bash
# Log khi content an toàn
docker logs ai-service 2>&1 | grep -i "moderat" | tail -20

# Expected (tin nhắn không vi phạm):
# [ModerationConsumer] Message test-mod-001: safe
# Expected (tin nhắn vi phạm):
# [ModerationConsumer] Message xxx flagged: { hate: false, violence: true, ... }
```

---

## 9. Test Redis Cache

```bash
# Kết nối Redis và kiểm tra keys AI
docker exec chat-redis redis-cli KEYS "ai:*"

# Xem cache summary
docker exec chat-redis redis-cli KEYS "ai:summary:*"

# Xem cache translate
docker exec chat-redis redis-cli KEYS "ai:translate:*"

# Xem TTL của 1 key (giây còn lại)
docker exec chat-redis redis-cli TTL "ai:summary:CONVERSATION_ID:5:all"
# Hoặc với date range:
# docker exec chat-redis redis-cli TTL "ai:summary:CONVERSATION_ID:42:2026-04-13_2026-04-20"
```

---

## 10. Kịch bản test lỗi (Validation)

### Thiếu field bắt buộc
```bash
# Thiếu "question" → 400 Bad Request
curl -X POST http://localhost:3050/api/ai/ask \
  -H "Content-Type: application/json" \
  -d '{}'

# Thiếu "text" → 400 Bad Request
curl -X POST http://localhost:3050/api/ai/translate \
  -H "Content-Type: application/json" \
  -d '{"targetLanguage": "en"}'

# messages rỗng → 400 Bad Request
curl -X POST http://localhost:3050/api/ai/conversations/CONVERSATION_ID/summary \
  -H "Content-Type: application/json" \
  -d '{"messages": []}'
```

**Expected error response:**
```json
{
  "statusCode": 400,
  "message": ["question should not be empty"],
  "error": "Bad Request"
}
```

---

## Tóm tắt endpoints

| # | Chức năng | Method | Endpoint | Auth |
|---|-----------|--------|----------|------|
| 1 | Health check | GET | `/api/ai/health` | Không |
| 2 | Dịch tin nhắn | POST | `/api/ai/translate` | JWT (qua gateway) |
| 3 | Tóm tắt hội thoại | POST | `/api/ai/conversations/:id/summary` | JWT |
| 4 | Tìm kiếm ngữ nghĩa | POST | `/api/ai/search` | JWT |
| 5 | Hỏi đáp RAG | POST | `/api/ai/ask` | JWT |
| 6 | Index tài liệu | POST | `/api/ai/documents/index` | JWT |
| 7 | Kiểm duyệt | — | Kafka `chat.message.sent` | Tự động |
