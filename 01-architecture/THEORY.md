# Kiến trúc Kubernetes - Lý thuyết chuyên sâu

## 🏗️ Tổng quan kiến trúc hệ thống

Kubernetes được thiết kế theo mô hình **Master-Worker** với sự phân tách rõ ràng giữa **Control Plane** (não bộ) và **Data Plane** (cơ bắp).

### 🧠 Control Plane - Bộ não của cluster

```mermaid
graph TB
    subgraph "Control Plane"
        API[kube-apiserver<br/>API Gateway]
        ETCD[etcd<br/>Distributed Database]
        SCHED[kube-scheduler<br/>Pod Placement Engine]
        CM[kube-controller-manager<br/>Control Loops]
        CCM[cloud-controller-manager<br/>Cloud Integration]
    end
    
    subgraph "Data Plane"
        KUBELET[kubelet<br/>Node Agent]
        PROXY[kube-proxy<br/>Network Proxy]
        RUNTIME[Container Runtime<br/>containerd/CRI-O]
    end
    
    subgraph "External Clients"
        KUBECTL[kubectl]
        DASHBOARD[Dashboard]
        APPS[Applications]
    end
    
    KUBECTL --> API
    DASHBOARD --> API
    APPS --> API
    
    API <--> ETCD
    API --> SCHED
    API --> CM
    API --> CCM
    
    API <--> KUBELET
    KUBELET --> RUNTIME
    KUBELET --> PROXY
```

### 🔄 Luồng xử lý từ kubectl → container

```mermaid
sequenceDiagram
    participant U as User
    participant K as kubectl
    participant API as kube-apiserver
    participant E as etcd
    participant S as kube-scheduler
    participant C as kube-controller
    participant KL as kubelet
    participant CR as Container Runtime
    
    U->>K: kubectl create deployment nginx
    K->>API: HTTP POST /api/v1/deployments
    API->>API: Authentication & Authorization
    API->>API: Admission Controllers
    API->>E: Store Deployment object
    E-->>API: Confirm storage
    API-->>K: 201 Created
    K-->>U: deployment.apps/nginx created
    
    Note over C: Deployment Controller watches
    C->>API: GET /api/v1/deployments
    C->>API: POST /api/v1/replicasets
    API->>E: Store ReplicaSet object
    
    Note over C: ReplicaSet Controller watches
    C->>API: POST /api/v1/pods
    API->>E: Store Pod object (Pending)
    
    Note over S: Scheduler watches for unscheduled pods
    S->>API: GET /api/v1/pods?fieldSelector=spec.nodeName=""
    S->>S: Filtering & Scoring algorithms
    S->>API: PATCH /api/v1/pods/{name} (bind to node)
    API->>E: Update Pod.spec.nodeName
    
    Note over KL: kubelet watches for pods on its node
    KL->>API: GET /api/v1/pods?fieldSelector=spec.nodeName=node1
    KL->>CR: Create container
    CR->>CR: Pull image & start container
    KL->>API: PATCH /api/v1/pods/{name}/status (Running)
    API->>E: Update Pod status
```

## 🔍 Chi tiết từng component

### 1. kube-apiserver - Cổng vào duy nhất

**Vai trò**: 
- REST API server cho toàn bộ cluster
- Xác thực, phân quyền, validation
- Admission controllers
- Proxy tới etcd

**Tại sao quan trọng**:
- Single point of truth cho cluster state
- Stateless - có thể scale horizontal
- Tất cả components khác chỉ giao tiếp qua API server

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
spec:
  containers:
  - name: kube-apiserver
    image: k8s.gcr.io/kube-apiserver:v1.28.0
    command:
    - kube-apiserver
    - --advertise-address=192.168.1.100
    - --etcd-servers=https://127.0.0.1:2379
    - --audit-log-path=/var/log/audit.log
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

### 2. etcd - Bộ não lưu trữ

**Vai trò**:
- Distributed key-value store
- Lưu trữ toàn bộ cluster state
- RAFT consensus algorithm
- Watch mechanism cho real-time updates

**Cấu trúc dữ liệu**:
```
/registry/
├── pods/
│   ├── default/
│   │   └── nginx-xxx
├── deployments/
│   └── default/
│       └── nginx
├── services/
├── configmaps/
└── secrets/
```

**Tại sao critical**:
- Mất etcd = mất toàn bộ cluster state
- Performance của etcd ảnh hưởng trực tiếp tới cluster
- Cần backup thường xuyên

### 3. kube-scheduler - Bộ phân bổ thông minh

**Vai trò**:
- Quyết định pod chạy trên node nào
- 2-phase process: Filtering + Scoring
- Pluggable scheduling framework

**Thuật toán scheduling**:

```mermaid
flowchart TD
    A[Unscheduled Pod] --> B[Filtering Phase]
    B --> C{Node có đủ resources?}
    C -->|No| D[Remove node]
    C -->|Yes| E{Node có taint?}
    E -->|Yes & No toleration| D
    E -->|No or Has toleration| F[Scoring Phase]
    F --> G[Calculate scores]
    G --> H[Select highest score node]
    H --> I[Bind pod to node]
```

**Filtering predicates**:
- NodeResourcesFit: CPU, Memory, Storage
- NodeAffinity: Node selectors
- PodAffinity/AntiAffinity: Pod placement rules
- Taints/Tolerations: Node restrictions

**Scoring priorities**:
- LeastRequestedPriority: Prefer nodes with less resource usage
- BalancedResourceAllocation: Balance CPU/Memory ratio
- NodeAffinityPriority: Prefer nodes matching affinity

### 4. kube-controller-manager - Bộ điều khiển

**Vai trò**:
- Chạy các control loops
- Đảm bảo desired state = actual state
- Reconciliation pattern

**Các controllers quan trọng**:

```mermaid
graph LR
    subgraph "Controller Manager"
        DC[Deployment Controller]
        RC[ReplicaSet Controller]
        NC[Node Controller]
        SC[Service Controller]
        EC[Endpoint Controller]
        PC[PersistentVolume Controller]
    end
    
    DC --> RS[ReplicaSet]
    RC --> POD[Pod]
    NC --> NODE[Node Status]
    SC --> EP[Endpoints]
    EC --> SVC[Service]
    PC --> PV[PersistentVolume]
```

**Control Loop Pattern**:
```go
for {
    desired := getDesiredState()
    current := getCurrentState()
    
    if desired != current {
        makeChanges(desired, current)
    }
    
    sleep(reconcileInterval)
}
```

## 🛠️ Data Plane - Nơi workload chạy

### 1. kubelet - Agent trên mỗi node

**Vai trò**:
- Pod lifecycle management
- Container health monitoring
- Resource monitoring
- Volume management

**Quy trình tạo Pod**:

```mermaid
sequenceDiagram
    participant API as kube-apiserver
    participant KL as kubelet
    participant CR as Container Runtime
    participant CNI as CNI Plugin
    
    API->>KL: Pod spec (via watch)
    KL->>KL: Validate pod spec
    KL->>CNI: Setup pod network
    CNI-->>KL: Pod IP assigned
    KL->>CR: Create containers
    CR->>CR: Pull images
    CR->>CR: Start containers
    CR-->>KL: Containers running
    KL->>API: Update pod status
```

### 2. kube-proxy - Network proxy

**Vai trò**:
- Implement Service abstraction
- Load balancing
- Network rules management

**Service Implementation modes**:

```mermaid
graph TB
    subgraph "iptables mode (default)"
        SVC1[Service] --> IPT[iptables rules]
        IPT --> POD1[Pod 1]
        IPT --> POD2[Pod 2]
        IPT --> POD3[Pod 3]
    end
    
    subgraph "IPVS mode (high performance)"
        SVC2[Service] --> IPVS[IPVS load balancer]
        IPVS --> POD4[Pod 1]
        IPVS --> POD5[Pod 2]
        IPVS --> POD6[Pod 3]
    end
```

### 3. Container Runtime - Thực thi containers

**Vai trò**:
- Pull images
- Create/start/stop containers
- Manage container lifecycle

**CRI (Container Runtime Interface)**:
```mermaid
graph LR
    KUBELET[kubelet] --> CRI[CRI API]
    CRI --> CONTAINERD[containerd]
    CRI --> CRIO[CRI-O]
    CRI --> DOCKER[Docker Engine]
    
    CONTAINERD --> RUNC[runc]
    CRIO --> RUNC
    DOCKER --> RUNC
```

## 🎯 Tình huống thực tế: Deploy một web application

Hãy theo dõi toàn bộ luồng khi deploy một ứng dụng web:

```bash
kubectl create deployment webapp --image=nginx:1.21 --replicas=3
kubectl expose deployment webapp --port=80 --type=LoadBalancer
```

### Luồng xử lý chi tiết:

```mermaid
graph TD
    A[kubectl create deployment] --> B[API Server validates]
    B --> C[Store in etcd]
    C --> D[Deployment Controller detects]
    D --> E[Create ReplicaSet]
    E --> F[ReplicaSet Controller detects]
    F --> G[Create 3 Pods]
    G --> H[Scheduler assigns nodes]
    H --> I[kubelet pulls nginx image]
    I --> J[Containers start]
    J --> K[kubectl expose creates Service]
    K --> L[Endpoints Controller updates]
    L --> M[kube-proxy updates iptables]
    M --> N[LoadBalancer provisioned]
```

## 🔧 Troubleshooting thường gặp

### 1. Pod stuck in Pending
```bash
kubectl describe pod <pod-name>
# Check: Resources, NodeSelector, Taints/Tolerations
```

### 2. API Server không accessible
```bash
# Check control plane pods
kubectl get pods -n kube-system
# Check certificates
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

### 3. etcd corruption
```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save backup.db
# Restore from backup
ETCDCTL_API=3 etcdctl snapshot restore backup.db
```

## 💡 Best Practices

### 1. High Availability Control Plane
- Chạy 3 hoặc 5 control plane nodes (odd numbers)
- etcd cluster với 3+ members
- Load balancer cho API server

### 2. Security
- Enable audit logging
- Rotate certificates định kỳ
- Network policies cho control plane

### 3. Monitoring
- Monitor etcd performance
- API server latency
- Controller manager lag

## 🤔 Câu hỏi suy ngẫm

1. **Tại sao Kubernetes cần etcd thay vì database thông thường?**
   - Consistency requirements
   - Watch mechanism
   - Distributed consensus

2. **Điều gì xảy ra nếu kube-scheduler down?**
   - Pods mới sẽ stuck ở Pending
   - Pods hiện tại vẫn chạy bình thường
   - kubelet vẫn manage pods đã scheduled

3. **Làm thế nào để scale Control Plane?**
   - Add more API server instances (stateless)
   - Scale etcd cluster (odd numbers)
   - Use load balancer

4. **Tại sao cần RBAC cho kube-apiserver?**
   - Principle of least privilege
   - Multi-tenancy
   - Audit trail