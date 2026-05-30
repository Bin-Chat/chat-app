# Availability 24/7

## Tieu Chi Cham Diem

**Availability - 24/7 - 0.5 diem**

Yeu cau: co giai phap dam bao he thong hoat dong lien tuc va giam downtime.

## Code/Config Hien Co

He thong hien co nhieu co che tang kha nang song sot khi deploy production:

| Co che | Bang chung | Y nghia |
|---|---|---|
| Docker restart policy | `docker-compose.yml` dung `restart: unless-stopped` cho database, Redis, Kafka/Redpanda, backend services, Coturn | Neu container crash, Docker tu khoi dong lai |
| Healthcheck container | `docker-compose.yml` co `healthcheck` cho Postgres, Redis, MongoDB, Redpanda, API Gateway, Auth, User, Friend, Upload, Chat, AI | Docker biet service nao dang healthy/unhealthy |
| Dependency ordering | `depends_on` voi `condition: service_healthy` | API Gateway va service chi start khi dependency san sang |
| Reverse proxy HTTPS | Caddy reverse proxy tren EC2 cho `api.binchat.me` | Client chi goi public endpoint, backend nam sau proxy |
| CI/CD health check | `.github/workflows/deploy-backend-images-ec2.yml` goi `http://localhost:3000/api/health` va `https://api.binchat.me/api/health` sau deploy | Deploy xong phai pass health check moi duoc coi la thanh cong |
| Rollback image tag | `.github/workflows/deploy-backend-images-ec2.yml` luu `.env.images.previous` va rollback neu health check fail | Giam rui ro deploy ban loi len production |
| Frontend hosting | Web deploy tren Vercel | Frontend duoc tach khoi EC2 backend, Vercel tu phuc vu static app |

## Cach Dien Dat De Dat Diem Cao

Co the trinh bay nhu sau:

> Ve Availability, he thong cua em khong chi chay mot process Node truc tiep, ma toan bo backend duoc container hoa bang Docker Compose. Moi service deu co `restart: unless-stopped`, nen neu service bi crash thi Docker se tu khoi dong lai. Ngoai ra, cac service quan trong nhu API Gateway, Auth, User, Chat, Upload, AI va database deu co `healthcheck`, giup he thong phat hien trang thai healthy/unhealthy.
>
> Khi deploy, GitHub Actions khong restart tuy y ma se pull image moi, start container, sau do goi health endpoint cua API Gateway o ca local EC2 va domain public `api.binchat.me`. Neu health check that bai, workflow se rollback ve image tag truoc do thong qua file `.env.images.previous`. Cach nay giup giam downtime va tranh viec ban loi bi giu lai tren production.

## Diem Manh

- Backend co nhieu service rieng nen loi mot service khong nhat thiet lam sap toan bo source code.
- Docker restart giup tu khoi phuc khi process crash.
- Health check giup CI/CD biet deploy co thanh cong khong.
- Caddy nam truoc API Gateway, dam nhan HTTPS va reverse proxy.

## Diem Can Noi That

Hien tai production demo van chay tren **mot EC2**, nen chua phai high availability dung nghia. Neu EC2 chet hoac region loi thi backend van downtime.

Neu thay co hoi, nen tra loi:

> He thong hien tai dat muc availability tot cho demo production single-node. De len production that, em se nang cap bang Auto Scaling Group/ECS, ALB, managed database, multi-AZ va backup tu dong de loai bo single point of failure.

## Cach Demo Nhanh

Tren EC2:

```bash
sudo docker ps
curl https://api.binchat.me/api/health
sudo docker inspect api-gateway --format='{{json .State.Health}}'
```

Ket qua mong doi:

- Container co trang thai `Up` va nhieu service `healthy`.
- API health tra ve JSON `status: ok`.

