# Scalability

## Tieu Chi Cham Diem

**Scalability - 0.5 diem**

Yeu cau: co huong scale horizontal/vertical hoac su dung load balancer/service scaling.

## Trang Thai Hien Tai

Production demo hien tai dang chay backend tren **mot EC2** bang Docker Compose. Vi vay, he thong **chua co autoscaling that su** nhu Kubernetes/ECS Auto Scaling hoac nhieu EC2 sau Load Balancer.

Tuy nhien, kien truc da co nen tang de scale:

| Thanh phan | Ho tro scale nhu the nao |
|---|---|
| Microservices | Auth, User, Friend, Chat, Upload, AI, Notification tach rieng, co the scale tung service |
| API Gateway | Gom entrypoint API/Socket, co the dat sau Load Balancer neu co nhieu instance |
| Docker image GHCR | Build image san tren GitHub Container Registry, EC2 chi pull image ve chay |
| Docker Compose override | `docker-compose.prod-images.yml` tach build khoi deploy, phu hop production image-based deploy |
| Vercel web | Frontend static duoc Vercel phuc vu, khong ton tai tren EC2 |
| S3/CloudFront | Upload/media co the tach ra khoi EC2, giam tai server |
| Redis/PostgreSQL/MongoDB/Redpanda/Qdrant | Stateful services duoc tach container rieng, co the thay bang managed services khi scale lon |
| Kafka/Redpanda | Consumer group cho phep scale cac consumer xu ly event |

## Cach Dien Dat De Dat Diem Cao

Co the noi:

> Ve Scalability, em thiet ke backend theo microservice thay vi monolith. Cac domain nhu Auth, User, Friend, Chat, Upload, AI va Notification duoc tach thanh service rieng. Moi service co Docker image rieng tren GHCR, nen khi can scale co the scale dung service dang qua tai thay vi scale toan bo he thong.
>
> Hien tai demo production chay tren mot EC2 de toi uu chi phi. Tuy nhien, huong scale da ro: frontend nam tren Vercel, media upload day sang S3/CloudFront, backend service da container hoa, event async di qua Redpanda Kafka. Khi tai tang, em co the scale vertical bang cach nang EC2, hoac scale horizontal bang cach chay nhieu instance service sau Load Balancer/ECS/Kubernetes.

## Huong Scale Vertical

Scale vertical la tang cau hinh may:

- Nang EC2 tu `t3.micro/t3.small` len `t3.medium/t3.large`.
- Tang RAM/CPU khi Docker containers bi thieu tai nguyen.
- Tach database ra RDS/MongoDB Atlas neu DB an tai nguyen EC2.

Uu diem:

- De lam.
- Phu hop demo/small production.

Nhuoc diem:

- Van co single point of failure.
- Co gioi han tai nguyen cua mot may.

## Huong Scale Horizontal

Scale horizontal la chay nhieu ban sao service:

1. Dat API Gateway sau AWS Application Load Balancer.
2. Chay nhieu EC2/ECS task cho cac service stateless.
3. Tach state ra ngoai:
   - PostgreSQL -> RDS.
   - MongoDB -> MongoDB Atlas.
   - Redis -> ElastiCache.
   - Redpanda/Kafka -> MSK hoac Redpanda managed.
   - Upload -> S3/CloudFront.
4. Moi service co the scale rieng theo CPU/RAM/traffic.

## Luu Y Voi Docker Compose Hien Tai

Docker Compose hien tai co the dung cho demo production, nhung neu scale nhieu replicas ngay tren cung EC2 thi can can than:

- Mot so service dang map host port co dinh, vi du `3010:3010`, `3040:3040`.
- Neu chay 2 replica cung map mot port se bi conflict.
- De scale tot hon, chi nen expose API Gateway ra ngoai, cac service con chi nam trong Docker network.
- Hoac chuyen sang ECS/Kubernetes de co service discovery va load balancing noi bo.

## Cach Tra Loi Khi Bi Hoi "Da Scale Duoc Chua?"

Nen tra loi:

> Hien tai em chua bat autoscaling that su vi demo can toi uu chi phi. Nhung kien truc da san sang cho scale: service tach rieng, image day len GHCR, state co the tach sang managed service, web tren Vercel va media tren S3. Buoc tiep theo la dua backend len ECS/Kubernetes hoac nhieu EC2 sau ALB de scale horizontal.

