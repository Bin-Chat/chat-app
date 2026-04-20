# UML — Triển khai với k3s (Kubernetes nhẹ trên EC2)

> **k3s** là bản Kubernetes nhẹ của Rancher Labs — chạy được trên EC2 t3.medium, tiêu tốn ~512MB RAM,  
> phù hợp để **học Kubernetes** mà không tốn tiền EKS ($72/tháng).  
> Tất cả sơ đồ dùng **PlantUML**.

---

## So sánh: Docker Compose vs k3s vs EKS

| Tiêu chí | Docker Compose | **k3s (đề xuất)** | EKS |
|---|---|---|---|
| Chi phí | $0 (overhead) | $0 (overhead) | ~$72/tháng control plane |
| Cài đặt | 1 lệnh | 1 lệnh | AWS Console + eksctl |
| Auto-restart | `restart: unless-stopped` | Pod restartPolicy | Managed |
| Health check | Docker healthcheck | Liveness/Readiness Probe | Managed |
| Rolling update | Không có | ✅ `kubectl rollout` | ✅ |
| Rollback | Thủ công | ✅ `kubectl rollout undo` | ✅ |
| Scale ngang | Không có | ✅ `kubectl scale` | ✅ Auto Scaling |
| ConfigMap/Secret | `.env` file | ✅ Kubernetes Secret | ✅ |
| Ingress / Routing | Nginx thủ công | ✅ Nginx Ingress Controller | ✅ ALB Ingress |
| Học Kubernetes | ❌ | ✅ Cú pháp y chang | ✅ |
| RAM overhead | ~50MB | ~512MB | N/A |

> **Kết luận**: k3s dùng cùng `kubectl`, cùng YAML manifest với Kubernetes thật → kiến thức chuyển sang EKS/GKE dễ dàng sau này.

---

## Sơ đồ 1 — Kiến trúc k3s trên EC2 (VPC Tier Architecture)

```plantuml
@startuml K3S_ARCHITECTURE

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam defaultFontName Arial
skinparam ArrowColor #555555
skinparam component {
  BackgroundColor #D6EAF8
  BorderColor #2980B9
}
skinparam database {
  BackgroundColor #FEF9E7
  BorderColor #F39C12
}
skinparam package {
  BorderColor #888888
  FontSize 12
}

title BinChat — k3s trên EC2 (Kubernetes nhẹ, $0 overhead)

'===========================================================
' LEFT: DevOps Workflow
'===========================================================
package "DevOps Workflow" #LightYellow {
  actor "Developer" as Dev
  component "GitHub\nRepository" as GH
  component "GitHub Actions\n(CI/CD Runner)" as GA
  component "Docker Hub\n(Image Registry)" as DHub

  Dev -down-> GH : git push main
  GH -down-> GA : trigger deploy.yml
  GA -down-> DHub : docker build\n& push :$SHA
}

'===========================================================
' AWS Cloud
'===========================================================
cloud "AWS Cloud" #AliceBlue {

  component "Cloudflare\n(DNS + CDN + DDoS)\nbinchat.app" as CF

  package "VPC — 10.0.0.0/16" {

    '--- Tier 1: Public ---
    package "Tier 1 — Public Subnet\n(Security Group: 80, 443, 6443*)" #LightBlue {
      component "Nginx Ingress Controller\n(k3s built-in Traefik hoặc Nginx)\n- SSL termination (Let's Encrypt)\n- Route /api/* → Gateway Service\n- Route /socket.io/* → Gateway Service\n- WebSocket upgrade\n- Rate limiting" as Ingress

      note right of Ingress
        *6443: kubectl API server port
        chỉ mở cho IP dev (SSH tunnel)
        Không mở public
      end note
    }

    '--- Tier 2: EC2 + k3s ---
    package "Tier 2 — EC2 t3.medium (2vCPU, 4GB RAM)\nPrivate App Subnet — k3s Single Node" #LightGreen {

      component "k3s Server\n(Control Plane + Worker\ntrên cùng 1 máy)" as K3S

      package "Kubernetes Namespace: binchat" {

        package "Deployments (Pods)" {
          component "api-gateway\nDeployment\nreplicas: 1\nPort: 3000" as GW
          component "auth-service\nDeployment\nreplicas: 1\nPort: 3010" as AUTH
          component "user-service\nDeployment\nreplicas: 1\nPort: 3020" as USER
          component "friend-service\nDeployment\nreplicas: 1\nPort: 3025" as FRIEND
          component "chat-service\nDeployment\nreplicas: 1\nPort: 3040" as CHAT
          component "upload-service\nDeployment\nreplicas: 1\nPort: 3035" as UPLOAD
          component "notification-service\nDeployment\nreplicas: 1\nPort: 3030" as NOTIF
        }

        package "Data StatefulSets (nếu self-host)" {
          database "PostgreSQL\nStatefulSet\n+ PersistentVolume" as PG
          database "MongoDB\nStatefulSet\n+ PersistentVolume" as Mongo
          database "Redis\nStatefulSet\n+ PersistentVolume" as Redis
          component "Redpanda\nStatefulSet\nKafka-compatible" as Kafka
        }

        package "Kubernetes Resources" {
          component "ConfigMap\n(non-secret config)" as CM
          component "Secret\n(JWT, DB passwords,\nAPI keys)" as SEC
          component "Services\n(ClusterIP cho internal\nNodePort cho Ingress)" as SVC
          component "Ingress Resource\n(routing rules)" as ING
        }
      }
    }

    '--- Tier 3: Managed Data (alternative) ---
    package "Tier 3 — Managed Data\n(Thay StatefulSets nếu tiết kiệm RAM)" #LightGoldenRodYellow {
      database "Neon.tech\n(Postgres Free)" as Neon
      database "MongoDB Atlas M0\n(Free 512MB)" as Atlas
      database "Upstash Redis\n(Free)" as UpRedis
      component "Upstash Kafka\n(Free)" as UpKafka
    }

    '--- Tier 4: Observability ---
    package "Tier 4 — Observability" #MistyRose {
      component "Prometheus\n(k3s built-in\nhoặc Grafana Cloud)" as Prom
      component "Grafana\n(hoặc Grafana Cloud Free)" as Grafana
    }
  }

  package "External Services" #Lavender {
    component "Cloudflare R2\n(Media storage)" as R2
    component "Resend.com\n(Email)" as Resend
    component "Metered.ca\n(TURN/WebRTC)" as Turn
    component "Expo Push\n(Mobile notify)" as ExpoPush
  }
}

package "Clients" #Honeydew {
  actor "Web Browser" as Web
  actor "Mobile (Expo)" as Mobile
}

'===========================================================
' Connections
'===========================================================

' DevOps → k3s
GA -right-> K3S : kubectl apply -f k8s/\n(via SSH tunnel / kubeconfig secret)
DHub -right-> K3S : pull image khi deploy

' DNS
CF -down-> Ingress : HTTPS binchat.app
Web -up-> CF : HTTPS
Mobile -up-> CF : HTTPS

' Ingress → Gateway
Ingress -down-> GW : /api/* + /socket.io/*

' Gateway → Services (ClusterIP)
GW -down-> AUTH : ClusterIP:3010
GW -down-> USER : ClusterIP:3020
GW -down-> FRIEND : ClusterIP:3025
GW -down-> CHAT : ClusterIP:3040
GW -down-> UPLOAD : ClusterIP:3035

' Services → Data
AUTH -down-> PG
USER -down-> PG
FRIEND -down-> PG
CHAT -down-> Mongo
AUTH -down-> Redis
GW -down-> Redis : socket presence

' Kafka
CHAT -right-> Kafka : produce
NOTIF -down-> Kafka : consume

' External services
UPLOAD -right-> R2
NOTIF -right-> Resend
NOTIF -right-> ExpoPush
GW -right-> Turn

' Config injection
SEC -up-> GW : envFrom secretRef
CM -up-> GW : envFrom configMapRef

' Observability
GW -right-> Prom : /metrics
Prom -right-> Grafana

@enduml
```

---

## Sơ đồ 2 — CI/CD Pipeline với k3s (GitHub Actions → kubectl apply)

```plantuml
@startuml CICD_K3S

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2
skinparam noteBackgroundColor #FFFACD
skinparam noteBorderColor #CCAA00

title BinChat — CI/CD Pipeline: GitHub Actions → k3s (kubectl apply)

actor "Developer" as Dev
participant "GitHub\n(main branch)" as GH
participant "GitHub Actions\nRunner" as GA
participant "Docker Hub\n(Image Registry)" as DHub
participant "EC2\n(Ubuntu + k3s)" as EC2
participant "k3s API Server\n:6443" as K3SAPI
participant "k3s Kubelet\n(container runtime)" as Kubelet
participant "Ingress\n(/api/health)" as HC

Dev -> GH : git push origin main
note over GH
  File: .github/workflows/k3s-deploy.yml
  Trigger: push to main
end note

GH -> GA : Trigger workflow

group Job 1 — test [ubuntu-latest]
  GA -> GA : checkout + setup Node 20
  GA -> GA : npm ci
  GA -> GA : npm run lint --workspaces
  GA -> GA : npm run test:unit --workspaces
  alt FAILED
    GA --> Dev : ❌ CI failed — dừng lại
  else PASSED
    GA -> GA : ✅ Tiếp tục
  end
end

group Job 2 — build-push [needs: test]
  note over GA
    Matrix build 7 services song song:
    api-gateway, auth, user, friend,
    chat, upload, notification
  end note
  GA -> GA : docker/setup-buildx-action\n(cache via GitHub Actions Cache)
  GA -> GA : docker/login-action\n(DOCKER_USERNAME + DOCKER_TOKEN)
  GA -> GA : docker/build-push-action\n--platform linux/amd64\n--tag binchat/<svc>:$SHA\n--tag binchat/<svc>:latest\ncache-from: type=gha
  GA -> DHub : push :$SHA + :latest\n(7 images)
end

group Job 3 — deploy-k3s [needs: build-push, if: main]

  note over GA
    Cách kết nối k3s từ GitHub Actions:
    ── Option A (đơn giản): SSH tunnel ──
    SSH vào EC2, chạy kubectl trực tiếp
    ── Option B (clean): kubeconfig ──
    Lưu ~/.kube/config vào GitHub Secret
    GA kết nối thẳng tới k3s API :6443
  end note

  GA -> GA : Tạo SSH key\n(echo "$K3S_SSH_KEY" > key.pem\nchmod 600 key.pem)

  ' Update image tag trong manifest
  GA -> GA : sed -i "s|binchat/api-gateway:.*|binchat/api-gateway:$SHA|g"\n  k8s/deployments/api-gateway.yaml\n(lặp cho 7 services)

  ' Option A: SSH + kubectl trên EC2
  GA -> EC2 : SSH vào EC2
  activate EC2

  EC2 -> EC2 : cd ~/binchat-k8s
  GA -> EC2 : scp -r k8s/ ubuntu@EC2:~/binchat-k8s/
  EC2 -> K3SAPI : kubectl apply -f k8s/namespace.yaml
  EC2 -> K3SAPI : kubectl apply -f k8s/secrets/
  EC2 -> K3SAPI : kubectl apply -f k8s/configmaps/
  EC2 -> K3SAPI : kubectl apply -f k8s/deployments/
  EC2 -> K3SAPI : kubectl apply -f k8s/services/
  EC2 -> K3SAPI : kubectl apply -f k8s/ingress.yaml

  K3SAPI -> Kubelet : Schedule Pods với image mới\n(Rolling Update Strategy:\nmaxSurge: 1, maxUnavailable: 0)

  note over Kubelet
    Rolling Update:
    1. Tạo Pod mới với image :$SHA
    2. Chờ readinessProbe OK
    3. Xóa Pod cũ
    → Zero downtime!
  end note

  Kubelet -> DHub : pull binchat/<svc>:$SHA
  DHub --> Kubelet : image pulled
  Kubelet -> Kubelet : Start new Pods\nRun readinessProbe\n(GET /api/health)

  loop Wait for rollout (timeout 5m)
    EC2 -> K3SAPI : kubectl rollout status\ndeployment/api-gateway\n-n binchat
    K3SAPI --> EC2 : "successfully rolled out"
  end

  alt Rollout OK
    EC2 --> GA : exit 0
    deactivate EC2
    GA --> Dev : ✅ Deployed $SHA\nbinchat.app is live
  else Rollout FAILED (timeout)
    EC2 -> K3SAPI : kubectl rollout undo\ndeployment/api-gateway -n binchat
    note over K3SAPI
      k3s tự động rollback
      về ReplicaSet trước đó
      (image :$PREV_SHA)
    end note
    EC2 --> GA : exit 1
    GA --> Dev : ❌ Deploy failed — auto rolled back
  end
end

note over Dev, HC
  GitHub Secrets cần cấu hình:
  ──────────────────────────────────
  DOCKER_USERNAME     = <dockerhub-user>
  DOCKER_TOKEN        = <dockerhub-token>
  K3S_EC2_HOST        = <ec2-public-ip>
  K3S_EC2_USERNAME    = ubuntu
  K3S_SSH_KEY         = <private-key-pem>
  ──────────────────────────────────
  Kubernetes Secrets (trong k8s/secrets/):
  JWT_SECRET, POSTGRES_URL, MONGODB_URI
  REDIS_URL, KAFKA_BROKER, RESEND_API_KEY
  R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
end note

@enduml
```

---

## Sơ đồ 3 — Luồng Rolling Update (Zero Downtime)

```plantuml
@startuml K3S_ROLLING_UPDATE

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam sequenceArrowThickness 2

title k3s Rolling Update — Zero Downtime Deploy

participant "kubectl\n(GitHub Actions)" as KCT
participant "k3s API Server" as API
participant "ReplicaSet\n(old: v1 :SHA_OLD)" as RS_OLD
participant "ReplicaSet\n(new: v2 :SHA_NEW)" as RS_NEW
participant "Pod Old\n(api-gateway:SHA_OLD)" as POD_OLD
participant "Pod New\n(api-gateway:SHA_NEW)" as POD_NEW
participant "Ingress\n(Traefik/Nginx)" as Ingress
actor "User Traffic" as Traffic

' Initial state
note over POD_OLD
  Đang phục vụ traffic
  status: Running
  readinessProbe: OK
end note

Traffic -> Ingress : requests
Ingress -> POD_OLD : route traffic ✅

' Deploy starts
KCT -> API : kubectl apply -f api-gateway.yaml\n(image: binchat/api-gateway:SHA_NEW)

API -> RS_NEW : Tạo ReplicaSet mới\n(SHA_NEW, replicas: 0)

' Rolling strategy: maxSurge=1, maxUnavailable=0
note over API
  Strategy: RollingUpdate
  maxSurge: 1        → tối đa +1 Pod khi update
  maxUnavailable: 0  → không được giảm Pod sẵn có
end note

API -> RS_NEW : Scale up → tạo Pod mới\n(api-gateway:SHA_NEW)
RS_NEW -> POD_NEW : Start container

' Readiness check
loop readinessProbe (mỗi 5s, failThreshold: 3)
  API -> POD_NEW : GET /api/health\n(HTTP 200?)
  POD_NEW --> API : 200 OK
end

note over POD_NEW
  readinessProbe: PASSED
  Pod status: Ready
end note

' Traffic switches
API -> Ingress : Thêm Pod New vào Endpoints
Ingress -> POD_NEW : route traffic ✅ (song song với Pod Old)

' Remove old pod
API -> RS_OLD : Scale down → xóa Pod cũ
RS_OLD -> POD_OLD : Terminate (graceful shutdown)

note over POD_OLD
  Graceful shutdown:
  1. Nhận SIGTERM
  2. Dừng nhận request mới
  3. Hoàn thành request đang xử lý
  4. Exit 0 (sau terminationGracePeriodSeconds: 30s)
end note

POD_OLD -> Ingress : Báo Endpoints: remove
Ingress -> POD_NEW : 100% traffic ✅

Traffic -> Ingress : requests
Ingress -> POD_NEW : route traffic ✅

note over KCT, POD_NEW
  Kết quả: Zero downtime
  - Không có request nào bị gián đoạn
  - Pod Old tồn tại song song đến khi Pod New sẵn sàng
  - Auto rollback nếu readinessProbe thất bại
end note

@enduml
```

---

## Sơ đồ 4 — Cấu trúc thư mục k8s manifests

```plantuml
@startuml K3S_FOLDER_STRUCTURE

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12

title Cấu trúc thư mục Kubernetes Manifests (k8s/)

package "chat-app/ (repo root)" {
  package "k8s/ (Kubernetes manifests)" #LightGreen {

    package "namespace.yaml" #LightBlue {
      component "Namespace: binchat" as NS
    }

    package "secrets/" #LightSalmon {
      component "app-secrets.yaml\n- JWT_SECRET\n- POSTGRES_URL\n- MONGODB_URI\n- REDIS_URL\n- KAFKA_BROKER\n- RESEND_API_KEY\n- R2_ACCESS_KEY_ID\n- R2_SECRET_ACCESS_KEY\n(base64 encoded)" as SECRETS
      note right of SECRETS
        Không commit file này lên git!
        Thêm vào .gitignore
        Dùng kubectl create secret
        hoặc sealed-secrets
      end note
    }

    package "configmaps/" #LightYellow {
      component "app-config.yaml\n- NODE_ENV=production\n- AUTH_SERVICE_URL=...\n- USER_SERVICE_URL=...\n(non-sensitive config)" as CM
    }

    package "deployments/" #LightGreen {
      component "api-gateway.yaml\n- image: binchat/api-gateway:SHA\n- replicas: 1\n- resources:\n    requests: cpu:100m, mem:128Mi\n    limits: cpu:500m, mem:512Mi\n- livenessProbe: /api/health\n- readinessProbe: /api/health\n- envFrom: secretRef + configMapRef" as D_GW
      component "auth-service.yaml\n(tương tự)" as D_AUTH
      component "chat-service.yaml\n(tương tự)" as D_CHAT
      component "... (7 deployments)" as D_REST
    }

    package "services/" #LightCyan {
      component "api-gateway-svc.yaml\n- type: ClusterIP\n- port: 3000" as S_GW
      component "auth-service-svc.yaml\n- type: ClusterIP\n- port: 3010" as S_AUTH
      component "... (7 ClusterIP services)" as S_REST
    }

    package "ingress.yaml" #Lavender {
      component "Ingress Resource\n- ingressClassName: nginx\n- host: binchat.app\n- /api/* → api-gateway-svc:3000\n- /socket.io/* → api-gateway-svc:3000\n- annotations:\n    nginx.ingress.kubernetes.io/proxy-read-timeout: '3600'\n    nginx.ingress.kubernetes.io/proxy-send-timeout: '3600'\n    nginx.ingress.kubernetes.io/websocket-services: api-gateway-svc" as ING
    }

    package "data/ (nếu self-host DB)" #Wheat {
      component "postgres-statefulset.yaml\n+ PersistentVolumeClaim" as PG_STS
      component "mongo-statefulset.yaml\n+ PersistentVolumeClaim" as MONGO_STS
      component "redis-statefulset.yaml\n+ PersistentVolumeClaim" as REDIS_STS
    }
  }

  package ".github/workflows/" #LightYellow {
    component "k3s-deploy.yml\n(CI/CD pipeline)" as WORKFLOW
  }
}

@enduml
```

---

## Sơ đồ 5 — So sánh CI/CD: Docker Compose vs k3s

```plantuml
@startuml COMPARE_DEPLOY

skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12

title So sánh luồng Deploy: Docker Compose vs k3s

package "Docker Compose Deploy" #LightYellow {
  component "GitHub Actions" as GA1
  component "EC2" as EC2_1
  component "docker-compose\npull && up -d" as DC

  GA1 -down-> EC2_1 : SSH
  EC2_1 -down-> DC : chạy lệnh
  DC -right-> DC : pull image\nstop old\nstart new\n(có downtime ~5s)
}

package "k3s Deploy" #LightGreen {
  component "GitHub Actions" as GA2
  component "EC2 + k3s" as EC2_2
  component "kubectl apply\n-f k8s/" as KCT2
  component "Rolling Update\n(zero downtime)" as RU

  GA2 -down-> EC2_2 : SSH
  EC2_2 -down-> KCT2 : chạy lệnh
  KCT2 -down-> RU : k3s xử lý
  RU -right-> RU : tạo Pod mới\nwait readiness\nxóa Pod cũ\n(KHÔNG có downtime)
}

note bottom of DC
  ❌ Có downtime ~5-10s mỗi lần deploy
  ❌ Không có auto-rollback
  ❌ Không có health-gate
  ✅ Đơn giản, dễ debug
end note

note bottom of RU
  ✅ Zero downtime
  ✅ Auto-rollback nếu readinessProbe fail
  ✅ kubectl rollout undo
  ✅ Học được Kubernetes thật
  ⚠️ Cần thêm ~512MB RAM trên EC2
end note

@enduml
```

---

## Hướng dẫn cài k3s trên EC2

### 1. Cài k3s (1 lệnh)

```bash
# Trên EC2 Ubuntu 22.04
curl -sfL https://get.k3s.io | sh -

# Kiểm tra
kubectl get nodes
# NAME        STATUS   ROLES                  AGE   VERSION
# ip-10-0-x  Ready    control-plane,master   30s   v1.29.x+k3s1
```

### 2. Cài Nginx Ingress Controller

```bash
# k3s mặc định dùng Traefik, nếu muốn Nginx:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### 3. Tạo namespace và secrets

```bash
kubectl create namespace binchat

kubectl create secret generic app-secrets \
  --from-literal=JWT_SECRET=<your-secret> \
  --from-literal=POSTGRES_URL=postgresql://... \
  --from-literal=MONGODB_URI=mongodb+srv://... \
  --from-literal=REDIS_URL=rediss://... \
  -n binchat
```

### 4. Deploy

```bash
kubectl apply -f k8s/ -n binchat

# Theo dõi rolling update
kubectl rollout status deployment/api-gateway -n binchat

# Rollback nếu cần
kubectl rollout undo deployment/api-gateway -n binchat
```

### 5. Lấy kubeconfig để dùng từ local

```bash
# Trên EC2
sudo cat /etc/rancher/k3s/k3s.yaml

# Copy về máy local, thay server IP
# server: https://127.0.0.1:6443
# → server: https://<ec2-public-ip>:6443
```

---

## GitHub Secrets cần cấu hình

```
DOCKER_USERNAME     = <dockerhub-username>
DOCKER_TOKEN        = <dockerhub-access-token>
K3S_EC2_HOST        = <ec2-public-ip>
K3S_EC2_USERNAME    = ubuntu
K3S_SSH_KEY         = <private-key-pem-content>
```
