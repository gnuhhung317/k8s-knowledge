# Labs thực hành - Kiến trúc Kubernetes

## 🚀 Lab 1: Setup cluster với kind và khám phá Control Plane

### Bước 1: Tạo cluster
```bash
# Tạo cluster với config tùy chỉnh
kind create cluster --config=kind-config.yaml --name=k8s-learning

# Verify cluster
kubectl cluster-info
kubectl get nodes -o wide
```

### Bước 2: Khám phá Control Plane components
```bash
# Xem tất cả pods trong kube-system
kubectl get pods -n kube-system -o wide

# Chi tiết từng component
kubectl describe pod -n kube-system kube-apiserver-k8s-learning-control-plane
kubectl describe pod -n kube-system etcd-k8s-learning-control-plane
kubectl describe pod -n kube-system kube-scheduler-k8s-learning-control-plane
kubectl describe pod -n kube-system kube-controller-manager-k8s-learning-control-plane
```

### Bước 3: SSH vào control plane node
```bash
# Truy cập vào control plane container
docker exec -it k8s-learning-control-plane bash

# Xem processes đang chạy
ps aux | grep kube
ps aux | grep etcd

# Xem config files
ls -la /etc/kubernetes/
cat /etc/kubernetes/manifests/kube-apiserver.yaml
cat /etc/kubernetes/manifests/etcd.yaml
```

## 🔍 Lab 2: Theo dõi luồng kubectl → container

### Bước 1: Enable audit logging
```bash
# Apply audit policy (đã có trong kind-config.yaml)
kubectl apply -f audit-policy.yaml

# Restart API server để apply audit policy
docker exec k8s-learning-control-plane \
  sed -i '/--audit-log-path/d' /etc/kubernetes/manifests/kube-apiserver.yaml
docker exec k8s-learning-control-plane \
  sed -i '/command:/a\    - --audit-log-path=/var/log/audit/audit.log' /etc/kubernetes/manifests/kube-apiserver.yaml
docker exec k8s-learning-control-plane \
  sed -i '/command:/a\    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml' /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Bước 2: Tạo deployment và theo dõi
```bash
# Tạo deployment
kubectl create deployment nginx --image=nginx:1.21

# Theo dõi events theo thời gian
kubectl get events --sort-by=.metadata.creationTimestamp

# Xem chi tiết deployment
kubectl describe deployment nginx
kubectl describe replicaset $(kubectl get rs -o name | head -1)
kubectl describe pod $(kubectl get pods -o name | head -1)
```

### Bước 3: Xem logs của các components
```bash
# API Server logs
kubectl logs -n kube-system kube-apiserver-k8s-learning-control-plane | tail -20

# Scheduler logs
kubectl logs -n kube-system kube-scheduler-k8s-learning-control-plane | tail -20

# Controller Manager logs
kubectl logs -n kube-system kube-controller-manager-k8s-learning-control-plane | tail -20

# kubelet logs (trên node)
docker exec k8s-learning-control-plane journalctl -u kubelet | tail -20
```

## 🗄️ Lab 3: Khám phá etcd - Trái tim của cluster

### Bước 1: Truy cập etcd
```bash
# Exec vào etcd pod
kubectl exec -it -n kube-system etcd-k8s-learning-control-plane -- sh

# Hoặc từ control plane node
docker exec -it k8s-learning-control-plane bash
```

### Bước 2: Khám phá dữ liệu trong etcd
```bash
# Set environment variables
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

# Xem tất cả keys
etcdctl get / --prefix --keys-only | head -20

# Xem cấu trúc thư mục
etcdctl get /registry --prefix --keys-only | grep -E "^/registry/[^/]+/$" | sort | uniq

# Xem pods
etcdctl get /registry/pods --prefix --keys-only

# Xem chi tiết một pod
POD_KEY=$(etcdctl get /registry/pods/default --prefix --keys-only | head -1)
etcdctl get $POD_KEY
```

### Bước 3: Watch changes trong etcd
```bash
# Terminal 1: Watch pods
etcdctl watch /registry/pods --prefix

# Terminal 2: Tạo/xóa pods
kubectl run test-pod --image=busybox --rm -it -- sleep 30
kubectl delete pod test-pod
```

## 🔧 Lab 4: Backup và Restore etcd

### Bước 1: Tạo snapshot
```bash
# Tạo snapshot
etcdctl snapshot save /tmp/etcd-backup.db

# Verify snapshot
etcdctl snapshot status /tmp/etcd-backup.db
```

### Bước 2: Tạo test data
```bash
# Tạo một số resources
kubectl create namespace test-backup
kubectl create deployment test-app --image=nginx -n test-backup
kubectl create configmap test-config --from-literal=key=value -n test-backup

# Verify
kubectl get all -n test-backup
kubectl get configmap test-config -n test-backup
```

### Bước 3: Simulate disaster và restore
```bash
# Stop etcd (simulate disaster)
docker exec k8s-learning-control-plane mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# Wait for etcd to stop
kubectl get pods -n kube-system | grep etcd

# Restore from backup
docker exec k8s-learning-control-plane etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=k8s-learning-control-plane=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# Update etcd manifest to use restored data
docker exec k8s-learning-control-plane sed -i 's|/var/lib/etcd|/var/lib/etcd-restore|g' /tmp/etcd.yaml

# Start etcd again
docker exec k8s-learning-control-plane mv /tmp/etcd.yaml /etc/kubernetes/manifests/

# Verify restore
kubectl get all -n test-backup
```

## 🚨 Lab 5: Troubleshoot Control Plane

### Scenario 1: kube-scheduler down
```bash
# Stop scheduler
docker exec k8s-learning-control-plane mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/

# Tạo pod mới
kubectl run test-pending --image=nginx

# Observe pod stuck in Pending
kubectl get pods
kubectl describe pod test-pending

# Restore scheduler
docker exec k8s-learning-control-plane mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/

# Watch pod get scheduled
kubectl get pods -w
```

### Scenario 2: API Server certificate expired
```bash
# Check certificate expiry
docker exec k8s-learning-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep "Not After"

# Simulate expired cert (backup and modify)
docker exec k8s-learning-control-plane cp /etc/kubernetes/pki/apiserver.crt /tmp/apiserver.crt.backup

# Try kubectl commands (should fail)
kubectl get pods

# Restore certificate
docker exec k8s-learning-control-plane cp /tmp/apiserver.crt.backup /etc/kubernetes/pki/apiserver.crt
```

### Scenario 3: etcd corruption
```bash
# Backup current etcd
etcdctl snapshot save /tmp/healthy-backup.db

# Simulate corruption (stop etcd and corrupt data)
docker exec k8s-learning-control-plane mv /etc/kubernetes/manifests/etcd.yaml /tmp/
docker exec k8s-learning-control-plane rm -rf /var/lib/etcd/*

# Try to start etcd (will fail)
docker exec k8s-learning-control-plane mv /tmp/etcd.yaml /etc/kubernetes/manifests/

# Restore from backup
etcdctl snapshot restore /tmp/healthy-backup.db --data-dir=/var/lib/etcd-new
docker exec k8s-learning-control-plane mv /var/lib/etcd /var/lib/etcd-corrupted
docker exec k8s-learning-control-plane mv /var/lib/etcd-new /var/lib/etcd
```

## 📊 Lab 6: Performance Monitoring

### Monitor API Server
```bash
# API Server metrics
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# Check API Server health
kubectl get --raw /healthz
kubectl get --raw /readyz
```

### Monitor etcd
```bash
# etcd metrics
kubectl exec -n kube-system etcd-k8s-learning-control-plane -- \
  etcdctl endpoint health --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# etcd performance
kubectl exec -n kube-system etcd-k8s-learning-control-plane -- \
  etcdctl check perf --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

## 🎯 Bài tập tự thực hành

### Bài 1: Phân tích luồng tạo Pod chi tiết
1. Tạo một pod với `kubectl run debug-pod --image=busybox -- sleep 3600`
2. Theo dõi events với `kubectl get events --watch`
3. Vẽ sequence diagram cho toàn bộ luồng
4. Identify các điểm có thể fail

### Bài 2: Custom Scheduler
1. Tạo một custom scheduler đơn giản
2. Deploy pod với custom scheduler
3. So sánh với default scheduler

### Bài 3: etcd Performance Testing
1. Tạo script để tạo 1000 pods
2. Monitor etcd performance
3. Identify bottlenecks

### Bài 4: Control Plane HA
1. Tạo multi-master cluster với kind
2. Test failover scenarios
3. Measure recovery time

## 🔍 Debugging Commands Cheat Sheet

```bash
# Cluster info
kubectl cluster-info
kubectl cluster-info dump

# Component status
kubectl get componentstatuses
kubectl get nodes
kubectl top nodes

# System pods
kubectl get pods -n kube-system
kubectl describe pods -n kube-system

# Events
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector type=Warning

# Logs
kubectl logs -n kube-system kube-apiserver-<node-name>
kubectl logs -n kube-system kube-scheduler-<node-name>
kubectl logs -n kube-system kube-controller-manager-<node-name>

# etcd
etcdctl member list
etcdctl endpoint health
etcdctl endpoint status

# API Server
kubectl get --raw /healthz
kubectl get --raw /metrics
kubectl auth can-i '*' '*' --as=system:admin
```

## 🎓 Kiến thức nâng cao

### 1. Custom Resource Definitions (CRDs)
```bash
# Xem CRDs có sẵn
kubectl get crd

# Tạo custom resource
kubectl apply -f custom-resource.yaml
```

### 2. Admission Controllers
```bash
# Xem admission controllers đang enable
kubectl exec -n kube-system kube-apiserver-k8s-learning-control-plane -- \
  kube-apiserver --help | grep enable-admission-plugins
```

### 3. API Versions và Deprecation
```bash
# Xem API versions
kubectl api-versions
kubectl api-resources

# Check deprecated APIs
kubectl get pods -o yaml | grep apiVersion
```