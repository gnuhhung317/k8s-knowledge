# Kubernetes Learning Course

## Mục tiêu khóa học
- Hiểu sâu về bản chất và kiến trúc Kubernetes
- Thực hành hands-on với cluster thật
- Xây dựng pipeline CI/CD hoàn chỉnh
- Vận hành production-ready workloads

## Cấu trúc khóa học

### 1. [Kiến trúc & Control Plane](./01-architecture/)
- Control Plane vs Data Plane
- Luồng kubectl → container
- Lab với kind/k3d/minikube

### 2. [Core Objects](./02-core-objects/)
- Pod, Deployment, StatefulSet
- Service, Ingress
- Job/CronJob

### 3. [Config & Storage](./03-config-storage/)
- ConfigMap, Secret
- Volumes, StorageClass
- Stateful workloads

### 4. [Networking](./04-networking/)
- CNI, Service Mesh
- DNS, Ingress
- NetworkPolicy

### 5. [Deployment & Release](./05-deployment/)
- Rolling Update, Blue-Green
- Helm, GitOps
- Argo CD/Flux

### 6. [Security](./06-security/)
- RBAC, Pod Security
- NetworkPolicy
- Image Security

### 7. [Autoscaling & Observability](./07-observability/)
- HPA, VPA, KEDA
- Monitoring, Logging, Tracing
- Prometheus, Grafana

### 8. [Advanced Operations](./08-advanced-ops/)
- Backup/Restore
- Cluster Upgrade
- Resource Management

### 9. [CI/CD Pipeline](./09-cicd/)
- End-to-end pipeline
- Security scanning
- GitOps workflow

## Yêu cầu hệ thống
- Docker Desktop
- kubectl
- kind/k3d/minikube
- Helm
- Git

## Bắt đầu
```bash
cd kubernetes-courses
./setup.sh
```"# k8s-knowledge" 
