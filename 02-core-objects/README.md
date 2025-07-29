# 02. Core Objects - Pod, Deployment, Service

## Mục tiêu
- Hiểu sâu về Pod lifecycle và design patterns
- Thành thạo Deployment strategies
- Nắm vững Service types và networking
- Thực hành Job/CronJob cho batch workloads

## Pod - Đơn vị nhỏ nhất

### Pod Lifecycle
```
Pending → Running → Succeeded/Failed
    ↓
  ContainerCreating
    ↓
  ImagePullBackOff (nếu lỗi)
```

### Hands-on: Tự viết Pod YAML
```bash
# Tạo pod từ scratch (không dùng kubectl run)
kubectl apply -f basic-pod.yaml

# Debug pod
kubectl describe pod my-pod
kubectl logs my-pod -c container-name
kubectl exec -it my-pod -- /bin/bash

# Pod với multiple containers
kubectl apply -f multi-container-pod.yaml
```

## Deployment - Quản lý Pod replicas

### Rolling Update Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
    progressDeadlineSeconds: 600
```

### Hands-on Labs
```bash
# Tạo deployment và scale
kubectl apply -f nginx-deployment.yaml
kubectl scale deployment nginx --replicas=5

# Rolling update
kubectl set image deployment/nginx nginx=nginx:1.21
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx

# Rollback
kubectl rollout undo deployment/nginx --to-revision=1
```

## Service - Networking và Discovery

### Service Types
- **ClusterIP**: Internal communication
- **NodePort**: External access via node IP
- **LoadBalancer**: Cloud provider integration
- **ExternalName**: DNS CNAME mapping

### Hands-on: Service Discovery
```bash
# Tạo service và test connectivity
kubectl apply -f nginx-service.yaml

# Test từ pod khác
kubectl run test-pod --image=busybox --rm -it -- sh
nslookup nginx-service
wget -qO- http://nginx-service:80
```

## StatefulSet - Stateful Applications

### Key Features
- Stable network identity
- Ordered deployment/scaling
- Persistent storage per pod

### Hands-on: MySQL StatefulSet
```bash
kubectl apply -f mysql-statefulset.yaml
kubectl get pods -l app=mysql
kubectl get pvc
```

## Job & CronJob - Batch Workloads

### Job Patterns
- **Single completion**: Run once
- **Parallel jobs**: Multiple pods
- **Work queue**: Process items from queue

### Hands-on Labs
```bash
# Simple job
kubectl apply -f pi-calculation-job.yaml
kubectl logs job/pi-calculation

# CronJob for backup
kubectl apply -f backup-cronjob.yaml
kubectl get cronjobs
```

## Bài tập thực hành

### Bài 1: Multi-tier Application
Triển khai ứng dụng 3-tier:
1. Frontend (Deployment + Service)
2. Backend API (Deployment + Service)
3. Database (StatefulSet + Service)

### Bài 2: Blue-Green Deployment
1. Deploy version 1 (blue)
2. Deploy version 2 (green)
3. Switch traffic bằng cách update Service selector

### Bài 3: Batch Processing Pipeline
1. CronJob tải data
2. Job xử lý data
3. Job upload kết quả

## Troubleshooting Common Issues

### Pod Stuck in Pending
```bash
kubectl describe pod <pod-name>
# Check: resource constraints, node selectors, taints/tolerations
```

### ImagePullBackOff
```bash
kubectl describe pod <pod-name>
# Check: image name, registry credentials, network connectivity
```

### Service không accessible
```bash
kubectl get endpoints <service-name>
kubectl describe service <service-name>
# Check: selector labels, port configuration
```

## Best Practices

### Resource Management
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Câu hỏi suy ngẫm
1. Khi nào nên dùng StatefulSet thay vì Deployment?
2. Tại sao cần readiness probe khác với liveness probe?
3. Làm thế nào để zero-downtime deployment?
4. Service mesh có thay thế được Service không?

## Tiếp theo
Chuyển sang [03. Config & Storage](../03-config-storage/) để học về ConfigMap, Secret, Volumes.