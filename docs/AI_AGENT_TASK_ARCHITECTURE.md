# 🤖 AI Agent & Task Management — Kiến trúc hệ thống

> Tài liệu này mô tả kiến trúc **AI Agent thông minh** kết hợp với **Hệ thống quản lý công việc nhóm** trong BinChat — một chat app microservices realtime.

---

## 1. 🎯 Sơ đồ tổng quan kiến trúc

```mermaid
%%{init: {'theme':'base', 'themeVariables': {'primaryColor':'#dbeafe','primaryBorderColor':'#2563eb','lineColor':'#475569','fontSize':'13px'}}}%%
flowchart TB
    subgraph Client["🖥️ CLIENT TIER"]
        WEB["🌐 Web App<br/>(React + Vite)"]
        MOB["📱 Mobile App<br/>(Expo + RN)"]
    end

    subgraph Gateway["🚪 GATEWAY"]
        GW["API Gateway<br/>(NestJS + Socket.IO)"]
    end

    subgraph Services["⚙️ MICROSERVICES"]
        AUTH["🔐 Auth"]
        USER["👤 User"]
        CHAT["💬 Chat<br/>+ Task Manager"]
        AI["🤖 AI Agent<br/>(OpenAI gpt-4o-mini)"]
        UPLOAD["📤 Upload"]
        NOTIF["🔔 Notification"]
        FRIEND["👥 Friend"]
    end

    subgraph Bus["📡 EVENT BUS"]
        KAFKA{{"Apache Kafka"}}
    end

    subgraph Data["💾 DATA LAYER"]
        MONGO[("🍃 MongoDB<br/>Messages • Tasks")]
        PG[("🐘 PostgreSQL<br/>Users • Auth")]
        REDIS[("⚡ Redis<br/>Sessions • Cache")]
        S3[("☁️ S3 / R2<br/>Media")]
    end

    WEB <-->|"HTTPS + WS"| GW
    MOB <-->|"HTTPS + WS"| GW
    GW --> AUTH
    GW --> USER
    GW --> CHAT
    GW --> UPLOAD
    GW --> FRIEND

    CHAT <-.->|"Events"| KAFKA
    AI <-.->|"Events"| KAFKA
    NOTIF <-.->|"Events"| KAFKA
    GW <-.->|"Socket fan-out"| KAFKA

    AI <-->|"Internal HTTP<br/>(x-service-secret)"| CHAT

    CHAT --> MONGO
    AUTH --> PG
    USER --> PG
    AUTH --> REDIS
    UPLOAD --> S3

    style AI fill:#fef3c7,stroke:#f59e0b,stroke-width:3px
    style CHAT fill:#dbeafe,stroke:#2563eb,stroke-width:3px
    style KAFKA fill:#e0e7ff,stroke:#6366f1,stroke-width:2px
```

---

## 2. 🧠 Luồng AI Agent (OpenAI Tool-Calling Loop)

```mermaid
%%{init: {'theme':'base'}}%%
sequenceDiagram
    autonumber
    actor User as 👤 User
    participant FE as 🖥️ Web/Mobile
    participant GW as 🚪 Gateway
    participant CHAT as 💬 Chat Service
    participant KAFKA as 📡 Kafka
    participant AI as 🤖 AI Service
    participant LLM as 🧠 OpenAI gpt-4o-mini
    participant TOOLS as 🛠️ Internal Tools

    User->>FE: "@bot hãy tạo công việc cho nhóm:<br/>1. Viết báo cáo (Linh, gấp)<br/>2. Kiểm thử (Minh, mai 9h)"
    FE->>GW: POST /api/chat/messages
    GW->>CHAT: forward
    CHAT->>KAFKA: emit chat.message.created
    KAFKA-->>AI: deliver event
    Note over AI: Detect @bot mention<br/>→ trigger agent

    AI->>KAFKA: emit agent.typing (start)
    KAFKA-->>GW: forward → socket "bot:typing"

    rect rgb(255, 247, 224)
        Note over AI,LLM: 🔁 Agent Loop (MAX 5 iterations)
        AI->>LLM: chat.completions.create<br/>(messages + 10 tools)
        LLM-->>AI: tool_calls = [<br/> create_task_list({tasks: [...]}),<br/> list_tasks(...)<br/>]

        loop For each tool_call
            AI->>TOOLS: dispatch(tool_name, args, ctx)
            TOOLS->>CHAT: POST /chat/internal/tasks<br/>x-service-secret
            CHAT->>CHAT: TaskService.createTasksBatch()
            CHAT->>KAFKA: emit chat.task.created (batch)
            CHAT->>KAFKA: emit chat.task.assigned (per assignee)
            CHAT-->>TOOLS: { batchId, tasks[] }
            TOOLS-->>AI: tool result JSON
        end

        AI->>LLM: continue with tool results
        LLM-->>AI: final text reply
    end

    AI->>KAFKA: emit agent.typing (stop)
    AI->>KAFKA: emit agent.bot_reply { content, conversationId }

    KAFKA-->>CHAT: deliver agent.bot_reply
    CHAT->>CHAT: persist Message (senderId=bot)
    CHAT->>KAFKA: emit chat.message.created

    KAFKA-->>GW: deliver message + task events
    GW->>FE: socket "message:new"
    GW->>FE: socket "task:created" (batch)
    GW->>FE: socket "task:assigned" (Linh, Minh)

    FE->>User: 💬 Hiển thị tin nhắn bot<br/>📋 Hiển thị TaskListMessage card<br/>🔔 Toast cho người được giao
```

---

## 3. 🧩 Sơ đồ thành phần (Component Diagram)

```mermaid
%%{init: {'theme':'base'}}%%
flowchart LR
    subgraph AI_SVC["🤖 services/ai"]
        AC[AgentConsumer<br/>@EventPattern]
        AS[AgentService<br/>.run loop]
        AT[AgentToolsService<br/>dispatch]
        ST[Tool Registry<br/>10 tools]
        AC --> AS --> AT --> ST
        AS <-->|"chat.completions"| OAI((OpenAI))
        AT -->|"axios + secret"| ICC
    end

    subgraph CHAT_SVC["💬 services/chat"]
        ICC[InternalChatController<br/>+ InternalGuard]
        TS[TaskService]
        NS[NoteService]
        MS[MessageService]
        ARC[AgentReplyConsumer]
        ICC --> TS
        ICC --> MS
        ARC --> MS
        TS --> MDB[(MongoDB<br/>Task schema)]
        MS --> MDB
    end

    subgraph GW_SVC["🚪 gateway"]
        CEC[ChatEventsConsumer<br/>Kafka → Socket]
        SG[SocketGateway<br/>emitToUser]
        CEC --> SG
    end

    subgraph FE["🖥️ Frontend"]
        CSI[ChatSocketInitializer<br/>web]
        UCS[useChatSocket<br/>mobile]
        TP[TaskPanel]
        TLM[TaskListMessage<br/>Card]
        CTM[CreateTaskModal]
        TP --> CTM
        CSI --> TP
        CSI --> TLM
        UCS --> TP
        UCS --> TLM
    end

    AS -->|emit agent.bot_reply<br/>agent.typing| KB[(Kafka)]
    TS -->|emit chat.task.*| KB
    KB --> ARC
    KB --> CEC
    SG -->|socket events| CSI
    SG -->|socket events| UCS

    style AI_SVC fill:#fef3c7,stroke:#f59e0b
    style CHAT_SVC fill:#dbeafe,stroke:#2563eb
    style GW_SVC fill:#dcfce7,stroke:#16a34a
    style FE fill:#fce7f3,stroke:#db2777
```

---

## 4. 🛠️ Bộ công cụ (Tools) của Agent

```mermaid
%%{init: {'theme':'base'}}%%
mindmap
  root((🤖 AI Agent<br/>10 Tools))
    💬 Conversation
      list_conversations
      search_messages
      get_recent_messages
    📝 Content
      summarize_conversation
      translate_text
      rewrite_text
    📋 Task Management
      create_task_list ⭐
      list_tasks
      mark_task_complete
    🔍 Knowledge
      web_search
```

---

## 5. 📋 Mô hình dữ liệu Task

```mermaid
%%{init: {'theme':'base'}}%%
erDiagram
    CONVERSATION ||--o{ TASK : "has many"
    USER ||--o{ TASK : "creates"
    USER ||--o{ TASK : "assigned to"
    TASK ||--o{ TASK_COMMENT : "has"
    TASK }o--|| MESSAGE : "embedded in<br/>(metadata.type='task_list_created')"
    TASK }o--o| TASK : "batch sibling<br/>(via batchId)"

    TASK {
        ObjectId _id PK
        ObjectId conversationId FK
        string createdBy FK
        string assigneeId FK "nullable"
        string batchId "UUID, groups AI-created tasks"
        string title
        string description
        enum status "todo|in_progress|done"
        enum priority "low|medium|high"
        Date dueDate "nullable"
        Date completedAt
        string completedBy
        TaskComment_arr comments
        Date createdAt
        Date updatedAt
    }

    TASK_COMMENT {
        ObjectId _id PK
        string userId FK
        string content
        Date createdAt
    }

    MESSAGE {
        ObjectId _id PK
        ObjectId conversationId FK
        string senderId "= 'system' for task_list_created"
        enum type "text|system|..."
        string content "human-readable summary"
        object metadata "{ type, batchId, tasks[], actorName }"
    }
```

---

## 6. 🔄 Vòng đời (Lifecycle) của một Task

```mermaid
%%{init: {'theme':'base'}}%%
stateDiagram-v2
    [*] --> todo: 📝 createTask /<br/>createTasksBatch
    todo --> in_progress: ▶️ user update<br/>status='in_progress'
    todo --> done: ✅ completeTask /<br/>checkbox tick
    in_progress --> done: ✅ completeTask
    in_progress --> todo: ↩️ uncheck
    done --> todo: ↩️ uncheck<br/>(reopen)
    todo --> [*]: 🗑️ deleteTask
    in_progress --> [*]: 🗑️ deleteTask
    done --> [*]: 🗑️ deleteTask

    note right of todo: 🟢 Mặc định<br/>Có thể bị quá hạn
    note right of done: completedAt + completedBy<br/>được set
```

---

## 7. 🚀 Kafka Topics & Realtime Fan-out

```mermaid
%%{init: {'theme':'base'}}%%
flowchart LR
    subgraph Producers["📤 Producers"]
        CHAT[Chat Service]
        AI[AI Service]
    end

    subgraph Topics["📡 Kafka Topics"]
        T1[chat.message.created]
        T2[chat.task.created]
        T3[chat.task.updated]
        T4[chat.task.completed]
        T5[chat.task.deleted]
        T6[chat.task.assigned]
        T7[agent.bot_reply]
        T8[agent.typing]
        T9[chat.bot.typing]
    end

    subgraph Consumers["📥 Consumers"]
        AI_C[AI: AgentConsumer]
        CHAT_C[Chat: AgentReplyConsumer]
        GW_C[Gateway: ChatEventsConsumer]
    end

    CHAT --> T1 --> AI_C
    CHAT --> T2 --> GW_C
    CHAT --> T3 --> GW_C
    CHAT --> T4 --> GW_C
    CHAT --> T5 --> GW_C
    CHAT --> T6 --> GW_C
    AI --> T7 --> CHAT_C
    AI --> T8 --> GW_C
    GW_C --> T9

    GW_C -->|"socket.emit"| SCK(((Socket.IO<br/>per-user room)))
    SCK -->|"task:created<br/>task:updated<br/>task:assigned"| FE[🖥️ Clients]

    style T2 fill:#dbeafe
    style T3 fill:#dbeafe
    style T4 fill:#dbeafe
    style T5 fill:#dbeafe
    style T6 fill:#dbeafe
```

---

## 8. 🎨 UI/UX Components

| Layer | Web | Mobile |
|---|---|---|
| **Header button** | `<CheckSquare>` icon in `ChatRoom.tsx` | `<CheckSquare>` in `conversation/[id].tsx` |
| **Task list view** | `TaskPanel` (right-drawer modal) | `TaskPanel` (bottom-sheet modal) |
| **Inline message** | `TaskListMessageCard` in `MessageBubble` | `TaskListMessage` in renderItem |
| **Create / edit** | `CreateTaskModal` | `CreateTaskModal` |
| **Realtime sync** | `ChatSocketInitializer` → `window.dispatchEvent` | `useChatSocket` → `DeviceEventEmitter` |

---

## 9. 💎 Điểm nổi bật kỹ thuật

✅ **Agent loop có giới hạn lặp** (MAX 5) — tránh infinite tool-calling
✅ **Internal service auth** — `x-service-secret` header chống truy cập trái phép
✅ **Batch operation 1-message** — AI tạo nhiều task chỉ phát 1 system message với metadata
✅ **Permission model 3 cấp** — assignee / creator / admin có quyền khác nhau
✅ **Realtime fan-out qua Kafka + Socket.IO room-per-user** — scale ngang dễ dàng
✅ **Inline interactive card** — checkbox trong message bubble đồng bộ realtime
✅ **Overdue detection client-side** — highlight đỏ khi `dueDate < now()`
✅ **Per-assignee toast notification** — chỉ người được giao mới nhận thông báo

---

## 10. 📊 Tóm tắt số liệu

| Hạng mục | Số lượng |
|---|---|
| AI tools | **10** |
| Kafka topics liên quan task & bot | **9** |
| API endpoint user-facing (task) | **6** |
| API endpoint internal (task/agent) | **4** |
| Socket events forwarded to client | **5 task + 2 bot** |
| UI components mới (web + mobile) | **6** |

