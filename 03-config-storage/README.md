# 03. Config & Storage - ConfigMap, Secret, Volumes

## Mục tiêu
- Quản lý configuration và secrets an toàn
- Hiểu sâu về storage patterns trong K8s
- Thực hành với StatefulSet và persistent volumes
- Khám phá advanced secret management

## ConfigMap - Configuration Management

### Tạo ConfigMap từ nhiều nguồn
```bash
# Từ literal values
kubectl create configmap app-config \
  --from-literal=database_url=mysql://localhost:3306/mydb \
  --from-literal=debug_mode=true

# Từ file
kubectl create configmap nginx-config --from-file=nginx.conf

# Từ directory
kubectl create configmap app-configs --from-file=configs/
```

### Sử dụng ConfigMap
```yaml
# Environment variables
env:
- name: DATABASE_URL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: database_url

# Volume mount
volumes:
- name: config-volume
  configMap:
    name: nginx-config
```

## Secret - Sensitive Data Management

### Secret Types
- **Opaque**: Generic secret (default)
- **kubernetes.io/dockerconfigjson**: Docker registry
- **kubernetes.io/tls**: TLS certificates
- **kubernetes.io/service-account-token**: Service account

### Hands-on: Advanced Secret Management
```bash
# Tạo TLS secret
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert/file \
  --key=path/to/key/file

# Docker registry secret
kubectl create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=myemail@example.com
```

### External Secret Management
```yaml
# Sealed Secrets example
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mysecret
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
```

## Storage - Volumes và Persistence

### Volume Types
- **emptyDir**: Temporary storage
- **hostPath**: Node filesystem
- **persistentVolumeClaim**: Dynamic storage
- **configMap/secret**: Configuration data

### Storage Classes và Dynamic Provisioning
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Hands-on: Persistent Volumes
```bash
# Tạo PVC
kubectl apply -f postgres-pvc.yaml

# Xem PV được tạo tự động
kubectl get pv
kubectl get pvc

# Test persistence
kubectl apply -f postgres-statefulset.yaml
kubectl exec -it postgres-0 -- psql -U postgres -c "CREATE TABLE test (id INT);"
kubectl delete pod postgres-0
# Verify data still exists after pod restart
```

## StatefulSet Deep Dive

### Volume Claim Templates
```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: "fast-ssd"
    resources:
      requests:
        storage: 10Gi
```

### Ordered Deployment và Scaling
```bash
# Scale up
kubectl scale statefulset postgres --replicas=3
# Pods tạo theo thứ tự: postgres-0, postgres-1, postgres-2

# Scale down
kubectl scale statefulset postgres --replicas=1
# Pods xóa theo thứ tự ngược: postgres-2, postgres-1
```

## Hands-on Labs

### Lab 1: WordPress với MySQL
```bash
# Deploy MySQL với persistent storage
kubectl apply -f mysql-persistent.yaml

# Deploy WordPress với ConfigMap
kubectl apply -f wordpress-configmap.yaml
kubectl apply -f wordpress-deployment.yaml

# Test persistence
kubectl delete pod mysql-xxx
# Verify WordPress still works
```

### Lab 2: Nginx với Custom Config
```bash
# Tạo custom nginx.conf
kubectl create configmap nginx-config --from-file=nginx.conf

# Deploy nginx với config
kubectl apply -f nginx-with-config.yaml

# Update config và reload
kubectl patch configmap nginx-config --patch='{"data":{"nginx.conf":"..."}}'
kubectl rollout restart deployment nginx
```

### Lab 3: Certificate Management
```bash
# Tạo self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=myapp.local"

# Tạo TLS secret
kubectl create secret tls myapp-tls --key=tls.key --cert=tls.crt

# Deploy app với HTTPS
kubectl apply -f https-app.yaml
```

## Best Practices

### ConfigMap Best Practices
1. **Immutable ConfigMaps**: Set `immutable: true` for better performance
2. **Size limits**: Keep under 1MB per ConfigMap
3. **Versioning**: Use labels for config versions
4. **Separation**: Separate config by environment/component

### Secret Security
1. **Encryption at rest**: Enable etcd encryption
2. **RBAC**: Restrict secret access
3. **External secret stores**: Use Vault, AWS Secrets Manager
4. **Rotation**: Implement secret rotation

### Storage Patterns
1. **StatefulSet**: For databases, message queues
2. **Deployment + PVC**: For shared storage
3. **DaemonSet + hostPath**: For node-level data
4. **Backup strategy**: Regular PV snapshots

## Troubleshooting

### ConfigMap Issues
```bash
# Check if ConfigMap exists
kubectl get configmap app-config -o yaml

# Verify mount in pod
kubectl exec -it pod-name -- ls -la /etc/config/
kubectl exec -it pod-name -- cat /etc/config/app.properties
```

### Storage Issues
```bash
# Check PVC status
kubectl describe pvc my-pvc

# Check storage class
kubectl get storageclass

# Check node storage
kubectl describe node node-name
```

## Câu hỏi suy ngẫm
1. Khi nào nên dùng Secret thay vì ConfigMap?
2. Tại sao StatefulSet cần volumeClaimTemplates?
3. Làm thế nào để backup/restore StatefulSet data?
4. External secret management có lợi ích gì?

## Tiếp theo
Chuyển sang [04. Networking](../04-networking/) để học về CNI, Service Mesh, NetworkPolicy.