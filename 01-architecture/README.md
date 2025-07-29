# 01. Kiến trúc Kubernetes & Control Plane

## Mục tiêu
- Hiểu sâu về Control Plane vs Data Plane
- Theo dõi luồng từ kubectl → container
- Thực hành với cluster thật (kind)
- Khám phá etcd và cách lưu trữ state

## Lý thuyết cốt lõi

### Control Plane Components
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   kube-apiserver│    │   etcd          │    │   kube-scheduler│
│   (API Gateway) │◄──►│   (State Store) │    │   (Pod Placer)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                                              │
         │                                              ▼
┌─────────────────┐                            ┌─────────────────┐
│   kubectl       │                            │ kube-controller │
│   (CLI Client)  │                            │ -manager        │
└─────────────────┘                            └─────────────────┘
```

### Data Plane Components
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   kubelet       │◄──►│   containerd    │◄──►│   Pod/Container │
│   (Node Agent)  │    │   (Runtime)     │    │   (Workload)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲
         │
┌─────────────────┐
│   kube-proxy    │
│   (Network)     │
└─────────────────┘
```

## Hands-on Labs

### Lab 1: Tạo cluster với kind
```bash
# Tạo cluster với config tùy chỉnh
kind create cluster --config=kind-config.yaml --name=k8s-learning

# Xem nodes
kubectl get nodes -o wide

# Xem pods system
kubectl get pods -n kube-system
```

### Lab 2: Khám phá Control Plane
```bash
# SSH vào control plane node
docker exec -it k8s-learning-control-plane bash

# Xem processes
ps aux | grep kube
ps aux | grep etcd

# Xem config files
ls -la /etc/kubernetes/
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Lab 3: Theo dõi luồng kubectl → container
```bash
# Bật audit log để theo dõi
kubectl apply -f audit-policy.yaml

# Tạo một pod và theo dõi
kubectl create deployment nginx --image=nginx
kubectl get events --sort-by=.metadata.creationTimestamp

# Xem logs của các components
kubectl logs -n kube-system kube-apiserver-k8s-learning-control-plane
kubectl logs -n kube-system kube-scheduler-k8s-learning-control-plane
```

### Lab 4: Khám phá etcd
```bash
# Cài đặt etcdctl
ETCD_VER=v3.5.10
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
sudo mv etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/

# Truy cập etcd trong cluster
kubectl exec -it -n kube-system etcd-k8s-learning-control-plane -- sh

# Xem tất cả keys
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get / --prefix --keys-only

# Xem một pod cụ thể
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/pods/default/nginx-xxx
```

## Bài tập thực hành

### Bài 1: Phân tích luồng tạo Pod
1. Tạo một pod với `kubectl run`
2. Theo dõi events và logs
3. Vẽ diagram luồng từ kubectl → container running

### Bài 2: Backup và restore etcd
1. Tạo snapshot etcd
2. Tạo một số resources
3. Restore từ snapshot
4. Verify data consistency

### Bài 3: Troubleshoot Control Plane
1. "Phá" một component (stop kube-scheduler)
2. Quan sát hành vi cluster
3. Khôi phục và giải thích

## Câu hỏi suy ngẫm
1. Tại sao etcd lại quan trọng đến vậy?
2. Điều gì xảy ra nếu kube-apiserver down?
3. Làm thế nào để scale Control Plane?
4. Tại sao cần RBAC cho kube-apiserver?

## Tài liệu tham khảo
- [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/)
- [etcd Documentation](https://etcd.io/docs/)
- [kind Documentation](https://kind.sigs.k8s.io/)

## Tiếp theo
Chuyển sang [02. Core Objects](../02-core-objects/) để học về Pod, Deployment, Service.