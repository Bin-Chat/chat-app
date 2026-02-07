# 🚀 Chat Application - Microservices Architecture

> Dự án học tập: Xây dựng ứng dụng chat real-time với kiến trúc microservices, event-driven architecture

## 📋 Tổng Quan

Ứng dụng chat hiện đại với các tính năng:

- ✅ Real-time messaging (WebSocket)
- ✅ User authentication & authorization
- ✅ Friend & Group management
- ✅ Online/Offline presence
- ✅ Read receipts & typing indicators
- ✅ Media upload (images, videos)
- ✅ Event-driven architecture
- ✅ Horizontal scaling ready

## 🏗️ Kiến Trúc

```
┌─────────────┐
│   Frontend  │  React Web (Vite + TypeScript)
└──────┬──────┘
       │
┌──────▼──────┐
│ API Gateway │  Direct Access (No Gateway - Future: NestJS Gateway)
└──────┬──────┘
       │
┌──────▼──────────────────────────┐
│      Backend Services           │
├─────────────────────────────────┤
│ • Auth Service (NestJS) :3010   │
│ • User Service (NestJS)         │
│ • Social Service (NestJS)       │
│ • Chat Service (Java) :3001     │
│ • Realtime Gateway (Java) :3003 │
│ • Presence Service (Java) :3002 │
│ • Media Processor (Java) :3004  │
└──────┬──────────────────────────┘
       │
┌──────▼──────────────────────────┐
│      Data Layer                 │
├─────────────────────────────────┤
│ • PostgreSQL (main database)    │
│ • Redis (cache + pub/sub)       │
│ • Redpanda/Kafka (event bus)    │
│ • Cloudflare R2 (object storage)│
└─────────────────────────────────┘
```

## 📦 Tech Stack

### Backend

- **NestJS** (TypeScript) - Business logic services (Auth :3010, User, Social)
- **Java 21** with **Spring Boot 3.2** - High-performance services (Chat :3001, Realtime Gateway :3003, Presence :3002, Media Processor :3004)
- **PostgreSQL** - Primary database
- **Redis** - Cache, Pub/Sub, Presence
- **Redpanda (Kafka)** - Event streaming
- **JWT** - Authentication with access & refresh tokens

### Frontend

- **React 18+** with TypeScript
- **Vite** - Build tool
- **TanStack Query** - Data fetching
- **Zustand** - State management
- **Socket.io-client** - WebSocket connection
- **Tailwind CSS** - Styling

### DevOps

- **Docker** & **Docker Compose**
- **GitHub Actions** - CI/CD
- **Prometheus** - Metrics
- **Grafana** - Monitoring
- **npm** - Package manager (workspaces)

## 🚀 Quick Start

### Prerequisites

```bash
node >= 20.0.0
npm >= 10.0.0
docker >= 24.0.0
docker-compose >= 2.0.0
java >= 21
maven >= 3.9.0
```

### Installation

```bash
# 1. Clone repository
git clone <repo-url>
cd chat-app

# 2. Install dependencies (for NestJS services)
cd services/auth && npm install && cd ../..
cd services/user && npm install && cd ../..
cd services/social && npm install && cd ../..

# 3. Start infrastructure (Database, Redis, Kafka)
docker-compose up -d postgres redis redpanda

# 4. Start Auth Service
docker-compose up -d auth-service

# 5. Verify Auth Service is running
curl http://localhost:3010/api/auth/health

# 6. (Optional) Start other infrastructure services if needed
# docker-compose up -d redis redpanda
```

**Services URLs:**

- **API Gateway**: http://localhost:3000 (Entry point cho tất cả requests)
- **Auth Service**: http://localhost:3010/api/auth (Internal - đăng ký/đăng nhập)

**Chưa triển khai:**
- Chat Service (port 3001)
- Presence Service (port 3002) 
- Realtime Gateway (port 3003)
- Media Processor (port 3004)
- Web App (port 5173)

## 📁 Project Structure

```
chat-app/
├── apps/
│   ├── web/                 # React frontend (chưa triển khai)
│   └── mobile/              # React Native (chưa triển khai)
├── gateway/
│   └── api-gateway/         # ✓ API Gateway (NestJS) - Entry point
├── services/
│   ├── auth/                # ✓ Auth Service (NestJS) - Đăng ký/Đăng nhập
│   ├── user/                # User Service (chưa làm)
│   ├── social/              # Social Service (chưa làm)
│   ├── chat/                # Chat Service (chưa làm)
│   ├── presence/            # Presence Service (chưa làm)
│   ├── realtime-gateway/    # Realtime Gateway (chưa làm)
│   └── media-processor/     # Media Processor (chưa làm)
│   └── media-processor/     # Media Processor (Java/Spring Boot)
├── infrastructure/
│   ├── postgres/            # PostgreSQL init scripts
│   ├── prometheus/          # Monitoring configs
│   └── grafana/             # Dashboards
├── docs/                    # Documentation
├── scripts/                 # Build & deployment scripts
├── .github/                 # CI/CD workflows
├── docker-compose.yml       # Local development setup
├── package.json             # Monorepo config (npm workspaces)
└── README.md
```

## 🔧 Development

### Start individual services

```bash
# Start specific service
npm run dev --workspace=@chat-app/auth

# Start all backend services
npm run services:dev

# Start frontend
npm run web:dev

# Build all
npm run build

# Run tests
npm test

# Lint & format
npm run lint
npm run format
```

### Database Management

```bash
# Create migration
npm run db:migration:create --workspace=@chat-app/auth -- <name>

# Run migrations
npm run db:migrate

# Rollback
npm run db:rollback --workspace=@chat-app/auth

# Seed data
npm run db:seed
```

### Docker Commands

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all
docker-compose down

# Rebuild
docker-compose up -d --build
```

## 🧪 Testing

```bash
# Unit tests
npm test

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e

# Load testing
npm run test:load

# Coverage
npm run test:coverage
```

## 📊 Monitoring

- **Grafana**: http://localhost:3001
- **Prometheus**: http://localhost:9090
- **Redis Commander**: http://localhost:8081

## 🚢 Deployment

### Production Build

```bash
# Build all services
npm run build

# Build Docker images
docker-compose -f docker-compose.prod.yml build

# Deploy
docker-compose -f docker-compose.prod.yml up -d
```

### Environment Variables

See [.env.example](.env.example) for required environment variables.

## 📚 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [API Documentation](docs/API.md)
- [Development Guide](docs/DEVELOPMENT.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Contributing Guide](docs/CONTRIBUTING.md)

### Auth Service Documentation

- **[Auth Backend Guide](docs/AUTH_BACKEND_GUIDE.md)** - Chi tiết kiến trúc, flow, security của Auth Service
- **[Auth Frontend Integration](docs/AUTH_FRONTEND_INTEGRATION.md)** - Hướng dẫn tích hợp Auth APIs cho Web/Mobile
- **[Auth Summary](docs/AUTH_SUMMARY.md)** - Tóm tắt nhanh về chức năng đăng nhập/đăng ký
- **[Auth API Docs](services/auth/API_DOCS.md)** - Chi tiết các endpoints và usage

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 👥 Team

- **Your Name** - Full Stack Developer

## 🙏 Acknowledgments

- NestJS Team
- Go Community
- React Team
- Open Source Contributors

---

**Version**: 1.0.0  
**Last Updated**: January 3, 2026
