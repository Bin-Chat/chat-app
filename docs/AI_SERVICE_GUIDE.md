# AI Service — Hướng dẫn sử dụng

**Base URL (qua API Gateway):** `http://localhost:3000/api/ai`  
**Base URL (trực tiếp):** `http://localhost:3050/api/ai`  
**Port:** 3050 | **Auth:** JWT cookie (tất cả route đều require đăng nhập)

---

## Mục lục

1. [Kiến trúc tổng quan](#kiến-trúc-tổng-quan)
2. [Health Check](#1-health-check)
3. [RAG Bot — Hỏi đáp tài liệu](#2-rag-bot--hỏi-đáp-tài-liệu)
4. [Index tài liệu](#3-index-tài-liệu)
5. [Semantic Search — Tìm kiếm ngữ nghĩa](#4-semantic-search--tìm-kiếm-ngữ-nghĩa)
6. [Conversation Summary — Tóm tắt hội thoại](#5-conversation-summary--tóm-tắt-hội-thoại)
7. [Auto Translation — Dịch tự động](#6-auto-translation--dịch-tự-động)
8. [Content Moderation — Kiểm duyệt nội dung](#7-content-moderation--kiểm-duyệt-nội-dung-tự-động-kafka)
9. [Kafka Events](#kafka-events)
10. [Cấu hình môi trường](#cấu-hình-môi-trường)
11. [Cấu trúc thư mục](#cấu-trúc-thư-mục)

---

## Kiến trúc tổng quan

```
Client ──→ API Gateway :3000 ──→ ai-service :3050
                                      │
                          ┌───────────┼───────────────┐
                          ▼           ▼               ▼
                       Qdrant      OpenAI           Redis
                       :6333    (GPT + Embed)      :6379
                    (vector DB)                   (cache)
                          │
                    ┌─────┴─────┐
              binchat_messages  binchat_documents
              (semantic search)  (RAG documents)
```

### Kafka Flow (Content Moderation)

```
chat-service ──→ [chat.message.created] ──→ ai-service
                                              │
                              ┌───────────────┤
                              ▼               ▼
                   ModerationConsumer  MessageIndexConsumer
                   (kiểm duyệt)        (index vào Qdrant)
                              │
                    [flagged = true]
                              │
                              ▼
                   [ai.message.moderated] ──→ chat-service
                                               (auto revoke)
```

---

## 1. Health Check

```http
GET /api/ai/health
```

**Response:**
```json
{
  "status": "ok",
  "service": "AI Service",
  "timestamp": "2026-04-20T10:00:00.000Z"
}
```

---

## 2. RAG Bot — Hỏi đáp tài liệu

Trả lời câu hỏi dựa trên tài liệu đã index vào Qdrant. Sử dụng `gpt-3.5-turbo` + vector search.

```http
POST /api/ai/ask
Content-Type: application/json
Cookie: access_token=<jwt>
```

**Request body:**
```json
{
  "question": "Quy trình xử lý đơn hàng như thế nào?",
  "collectionId": "project-abc"
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `question` | string | ✅ | Câu hỏi cần trả lời |
| `collectionId` | string | ❌ | Lọc theo bộ tài liệu cụ thể |

**Response:**
```json
{
  "question": "Quy trình xử lý đơn hàng như thế nào?",
  "answer": "Dựa trên tài liệu, quy trình xử lý đơn hàng gồm 3 bước: ..."
}
```

**Ví dụ (fetch):**
```typescript
const res = await fetch('/api/ai/ask', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({ question: 'Cách reset mật khẩu?', collectionId: 'faq' }),
});
const { answer } = await res.json();
```

---

## 3. Index tài liệu

Đưa văn bản vào hệ thống để RAG Bot có thể tìm kiếm. Văn bản sẽ được chia nhỏ thành chunks (1000 ký tự, overlap 100), embed và lưu vào Qdrant collection `binchat_documents`.

```http
POST /api/ai/documents/index
Content-Type: application/json
Cookie: access_token=<jwt>
```

**Request body:**
```json
{
  "text": "Nội dung tài liệu dài...",
  "collectionId": "faq",
  "source": "huong-dan-su-dung.pdf",
  "title": "Hướng dẫn sử dụng hệ thống"
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `text` | string | ✅ | Nội dung văn bản cần index |
| `collectionId` | string | ❌ | Nhóm tài liệu (để filter khi query) |
| `source` | string | ❌ | Tên file / nguồn gốc |
| `title` | string | ❌ | Tiêu đề tài liệu |

**Response:**
```json
{
  "message": "Document indexed successfully",
  "chunksIndexed": 12
}
```

---

## 4. Semantic Search — Tìm kiếm ngữ nghĩa

Tìm kiếm tin nhắn theo nghĩa, không phải theo từ khóa exact match. Tin nhắn được tự động index khi consume từ Kafka topic `chat.message.created`.

```http
POST /api/ai/search
Content-Type: application/json
Cookie: access_token=<jwt>
```

**Request body:**
```json
{
  "query": "hỏi về lịch họp tuần tới",
  "conversationId": "6642a1b3c0f4e200123abc45",
  "limit": 10
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `query` | string | ✅ | Cụm từ tìm kiếm |
| `conversationId` | string | ❌ | Giới hạn tìm trong 1 conversation |
| `limit` | number | ❌ | Số kết quả trả về (1–50, default: 10) |

**Response:**
```json
{
  "query": "hỏi về lịch họp tuần tới",
  "total": 3,
  "results": [
    {
      "messageId": "6642a1b3c0f4e200123abc99",
      "conversationId": "6642a1b3c0f4e200123abc45",
      "senderId": "user-id-123",
      "content": "Tuần tới họp vào thứ 3 lúc 9h nhé mọi người",
      "timestamp": "2026-04-18T08:30:00.000Z",
      "score": 0.92
    }
  ]
}
```

> **Lưu ý:** `score` từ 0 → 1, càng cao càng liên quan. Kết quả sắp xếp theo score giảm dần.

---

## 5. Conversation Summary — Tóm tắt hội thoại

Tóm tắt nội dung cuộc trò chuyện bằng GPT. Kết quả được cache Redis 1 giờ theo `conversationId + số lượng tin nhắn`.

```http
POST /api/ai/conversations/:id/summary
Content-Type: application/json
Cookie: access_token=<jwt>
```

**URL params:** `:id` = conversationId

**Request body:**
```json
{
  "messages": [
    {
      "senderId": "user-id-1",
      "content": "Anh ơi, dự án deadline khi nào?",
      "timestamp": "2026-04-20T08:00:00.000Z"
    },
    {
      "senderId": "user-id-2",
      "content": "Cuối tháng 4 em nhé, còn 10 ngày",
      "timestamp": "2026-04-20T08:01:00.000Z"
    }
  ]
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `messages` | array | ✅ | Mảng tin nhắn (tối thiểu 1) |
| `messages[].senderId` | string | ✅ | ID người gửi |
| `messages[].content` | string | ✅ | Nội dung tin nhắn |
| `messages[].timestamp` | string | ✅ | Thời gian (ISO 8601) |

**Response:**
```json
{
  "conversationId": "6642a1b3c0f4e200123abc45",
  "summary": "Cuộc trò chuyện về deadline dự án: deadline cuối tháng 4/2026, còn khoảng 10 ngày để hoàn thành."
}
```

**Ví dụ — Lấy 50 tin nhắn gần nhất rồi tóm tắt:**
```typescript
// Lấy messages từ API chat trước
const { messages } = await fetchMessages(conversationId, { limit: 50 });

const res = await fetch(`/api/ai/conversations/${conversationId}/summary`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({
    messages: messages.map((m) => ({
      senderId: m.senderId,
      content: m.content,
      timestamp: m.createdAt,
    })),
  }),
});
const { summary } = await res.json();
```

---

## 6. Auto Translation — Dịch tự động

Dịch văn bản sang ngôn ngữ đích bằng GPT. Kết quả được cache Redis 24 giờ (theo hash nội dung + ngôn ngữ đích).

```http
POST /api/ai/translate
Content-Type: application/json
Cookie: access_token=<jwt>
```

**Request body:**
```json
{
  "text": "Good morning! How are you doing today?",
  "targetLanguage": "Vietnamese",
  "sourceLanguage": "English"
}
```

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `text` | string | ✅ | Văn bản cần dịch |
| `targetLanguage` | string | ✅ | Ngôn ngữ đích (tên tiếng Anh: `Vietnamese`, `English`, `Japanese`, `Korean`, `Chinese`...) |
| `sourceLanguage` | string | ❌ | Ngôn ngữ nguồn (nếu không điền, GPT tự detect) |

**Response:**
```json
{
  "original": "Good morning! How are you doing today?",
  "translated": "Chào buổi sáng! Hôm nay bạn có khỏe không?",
  "targetLanguage": "Vietnamese"
}
```

**Ví dụ — Dịch nhanh 1 tin nhắn:**
```typescript
const res = await fetch('/api/ai/translate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({
    text: message.content,
    targetLanguage: 'Vietnamese',
  }),
});
const { translated } = await res.json();
```

---

## 7. Content Moderation — Kiểm duyệt nội dung (tự động, Kafka)

**Không cần gọi API thủ công.** Quá trình hoàn toàn tự động qua Kafka:

### Luồng hoạt động

```
1. User gửi tin nhắn
       ↓
2. chat-service lưu message + produce → [chat.message.created]
       ↓
3. ai-service.ModerationConsumer nhận event
       ↓
4. Gọi OpenAI omni-moderation-latest (FREE)
       ↓
5a. flagged = false → bỏ qua, không làm gì
5b. flagged = true  → produce → [ai.message.moderated]
       ↓
6. chat-service.AiModerationConsumer nhận event
       ↓
7. Auto revoke message + emit socket MESSAGE_REVOKED
       ↓
8. Tất cả client trong conversation thấy tin nhắn bị thu hồi
```

### Các category được kiểm tra (omni-moderation-latest)

| Category | Mô tả |
|----------|-------|
| `hate` | Nội dung thù ghét, phân biệt chủng tộc |
| `hate/threatening` | Đe dọa liên quan đến thù ghét |
| `harassment` | Quấy rối cá nhân |
| `harassment/threatening` | Đe dọa quấy rối |
| `self-harm` | Nội dung tự làm hại |
| `sexual` | Nội dung tình dục |
| `sexual/minors` | Nội dung tình dục liên quan đến trẻ em |
| `violence` | Nội dung bạo lực |
| `violence/graphic` | Bạo lực đồ họa |

> **Chi phí:** Model `omni-moderation-latest` hoàn toàn **miễn phí** từ OpenAI.

### Kafka payload `ai.message.moderated`

```json
{
  "messageId": "6642a1b3c0f4e200123abc99",
  "conversationId": "6642a1b3c0f4e200123abc45",
  "senderId": "user-id-123",
  "flagged": true,
  "categories": {
    "hate": false,
    "harassment": true,
    "violence": false
  },
  "categoryScores": {
    "hate": 0.002,
    "harassment": 0.95,
    "violence": 0.01
  },
  "timestamp": "2026-04-20T10:00:00.000Z"
}
```

---

## Kafka Events

| Topic | Producer | Consumer | Mô tả |
|-------|----------|----------|-------|
| `chat.message.created` | chat-service | ai-service (moderation + indexing) | Tin nhắn mới được gửi |
| `ai.message.moderated` | ai-service | chat-service | Tin nhắn vi phạm cần thu hồi |

---

## Cấu hình môi trường

Thêm vào file `.env` tại root project:

```env
# OpenAI API Key
# Lấy tại: https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-proj-your_key_here
```

Các biến khác (đã tự động cấu hình trong `docker-compose.yml`):

| Variable | Default | Mô tả |
|----------|---------|-------|
| `QDRANT_URL` | `http://qdrant:6333` | URL Qdrant vector DB |
| `REDIS_HOST` | `redis` | Redis host |
| `REDIS_PORT` | `6379` | Redis port |
| `KAFKA_BROKER` | `redpanda:9092` | Kafka broker |
| `CHAT_SERVICE_URL` | `http://chat-service:3040` | Chat service URL |

---

## Cấu trúc thư mục

```
services/ai/
├── Dockerfile
├── nest-cli.json
├── package.json
├── tsconfig.json
└── src/
    ├── main.ts                    — Khởi động, port 3050, kết nối Kafka
    ├── app.module.ts              — Import tất cả modules
    ├── qdrant/
    │   ├── qdrant.module.ts
    │   ├── qdrant.service.ts      — Khởi tạo collections, upsert, search
    │   └── embedding.service.ts  — OpenAI text-embedding-3-small (1536 dims)
    ├── kafka/
    │   ├── kafka.module.ts
    │   └── kafka-producer.service.ts
    ├── redis/
    │   ├── redis.module.ts
    │   └── redis.service.ts       — get/set/del với TTL
    ├── moderation/
    │   ├── moderation.module.ts
    │   ├── moderation.service.ts  — Gọi omni-moderation-latest
    │   └── moderation.consumer.ts — Consume chat.message.created → produce ai.message.moderated
    ├── rag/
    │   ├── rag.module.ts
    │   ├── rag.service.ts         — POST /ai/ask (RetrievalQA)
    │   ├── rag.controller.ts      — POST /ai/documents/index
    │   └── document-indexer.service.ts — chunk(1000) + embed + upsert
    ├── search/
    │   ├── search.module.ts
    │   ├── search.service.ts      — POST /ai/search
    │   ├── search.controller.ts
    │   ├── message-indexer.service.ts  — index message vào Qdrant
    │   └── message-index.consumer.ts  — Consume chat.message.created → index
    ├── summary/
    │   ├── summary.module.ts
    │   ├── summary.service.ts     — GPT + Redis cache 1h
    │   └── summary.controller.ts  — POST /ai/conversations/:id/summary
    └── translation/
        ├── translation.module.ts
        ├── translation.service.ts  — GPT + Redis cache 24h
        └── translation.controller.ts — POST /ai/translate
```

---

## OpenAI Models sử dụng

| Model | Feature | Chi phí |
|-------|---------|---------|
| `text-embedding-3-small` | Embedding (RAG + Search) | ~$0.02/1M tokens |
| `gpt-3.5-turbo` | RAG answer, Summary, Translation | ~$0.5/1M tokens |
| `omni-moderation-latest` | Content Moderation | **Miễn phí** |

---

## Qdrant Collections

| Collection | Dữ liệu | Dims |
|------------|---------|------|
| `binchat_messages` | Tin nhắn text từ conversations | 1536 |
| `binchat_documents` | Chunks từ tài liệu được index | 1536 |
