# Core Objects - Lý thuyết chuyên sâu

## 🎯 Tổng quan Core Objects

Kubernetes Core Objects là những building blocks cơ bản để chạy applications. Chúng được thiết kế theo nguyên tắc **composition over inheritance**.

```mermaid
graph TB
    subgraph "Workload Objects"
        POD[Pod<br/>Smallest deployable unit]
        DEP[Deployment<br/>Stateless apps]
        STS[StatefulSet<br/>Stateful apps]
        DS[DaemonSet<br/>Node-level services]
        JOB[Job<br/>Run-to-completion]
        CJ[CronJob<br/>Scheduled jobs]
    end
    
    subgraph "Service Objects"
        SVC[Service<br/>Network abstraction]
        ING[Ingress<br/>HTTP routing]
        EP[Endpoints<br/>Service backends]
    end
    
    subgraph "Storage Objects"
        PV[PersistentVolume<br/>Storage resource]
        PVC[PersistentVolumeClaim<br/>Storage request]
        SC[StorageClass<br/>Dynamic provisioning]
    end
    
    DEP --> POD
    STS --> POD
    DS --> POD
    JOB --> POD
    CJ --> JOB
    
    SVC --> EP
    ING --> SVC
    
    PVC --> PV
    SC --> PV
    POD --> PVC
```

## 🏗️ Pod - Đơn vị cơ bản nhất

### Bản chất của Pod

Pod không phải là container, mà là **wrapper** xung quanh 1 hoặc nhiều containers:

```mermaid
graph TB
    subgraph "Pod"
        subgraph "Shared Resources"
            NET[Network Namespace<br/>Shared IP]
            VOL[Volumes<br/>Shared storage]
            IPC[IPC Namespace<br/>Shared memory]
        end
        
        subgraph "Containers"
            MAIN[Main Container<br/>nginx]
            SIDE[Sidecar Container<br/>log-forwarder]
            INIT[Init Container<br/>setup]
        end
        
        MAIN -.-> NET
        SIDE -.-> NET
        MAIN -.-> VOL
        SIDE -.-> VOL
        INIT -.-> VOL
    end
```

### Pod Lifecycle chi tiết

```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> ContainerCreating: Scheduler assigns node
    ContainerCreating --> Running: All containers started
    ContainerCreating --> ImagePullBackOff: Image pull failed
    ImagePullBackOff --> ContainerCreating: Retry
    Running --> Succeeded: All containers completed successfully
    Running --> Failed: At least one container failed
    Running --> CrashLoopBackOff: Container keeps crashing
    CrashLoopBackOff --> Running: Container starts successfully
    Succeeded --> [*]
    Failed --> [*]
    
    note right of Pending
        - Pod accepted by cluster
        - Waiting for scheduling
        - Image pulling
    end note
    
    note right of Running
        - At least one container running
        - Or starting/restarting
    end note
```

### Pod Design Patterns

#### 1. Sidecar Pattern
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-example
spec:
  containers:
  # Main application
  - name: web-server
    image: nginx
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  # Sidecar: Log forwarder
  - name: log-forwarder
    image: fluent/fluent-bit
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
      readOnly: true
  
  volumes:
  - name: shared-logs
    emptyDir: {}
```

#### 2. Init Container Pattern
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-example
spec:
  initContainers:
  - name: init-db
    image: busybox
    command: ['sh', '-c', 'until nslookup mydb; do sleep 2; done']
  
  containers:
  - name: web-app
    image: nginx
```

#### 3. Ambassador Pattern
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-example
spec:
  containers:
  - name: web-app
    image: my-app
    env:
    - name: DB_HOST
      value: "localhost"  # Connect to ambassador
  
  - name: db-ambassador
    image: ambassador/ambassador
    # Proxy connections to actual database
```

## 🚀 Deployment - Quản lý Stateless Apps

### Deployment Controller Logic

```mermaid
sequenceDiagram
    participant U as User
    participant D as Deployment
    participant RS as ReplicaSet
    participant P as Pod
    
    U->>D: kubectl apply deployment.yaml
    D->>D: Create/Update Deployment
    D->>RS: Create new ReplicaSet (v2)
    RS->>P: Create new Pods
    
    Note over D,RS: Rolling Update Process
    D->>RS: Scale up new RS (v2)
    D->>RS: Scale down old RS (v1)
    
    alt Update successful
        D->>RS: Delete old ReplicaSet (v1)
    else Update failed
        D->>RS: Rollback to old RS (v1)
        D->>RS: Delete failed RS (v2)
    end
```

### Rolling Update Strategies

#### 1. RollingUpdate (Default)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # Tối đa 25% pods mới
    maxUnavailable: 25%  # Tối đa 25% pods unavailable
```

**Ví dụ với 4 replicas**:
```mermaid
gantt
    title Rolling Update Timeline
    dateFormat X
    axisFormat %s
    
    section Old Pods
    Pod 1 (v1) :active, old1, 0, 6
    Pod 2 (v1) :active, old2, 0, 8
    Pod 3 (v1) :active, old3, 0, 10
    Pod 4 (v1) :active, old4, 0, 12
    
    section New Pods
    Pod 5 (v2) :new1, 2, 14
    Pod 6 (v2) :new2, 4, 14
    Pod 7 (v2) :new3, 6, 14
    Pod 8 (v2) :new4, 8, 14
```

#### 2. Recreate Strategy
```yaml
strategy:
  type: Recreate
```

```mermaid
gantt
    title Recreate Strategy Timeline
    dateFormat X
    axisFormat %s
    
    section Old Pods
    All Pods (v1) :active, old, 0, 4
    
    section Downtime
    No Pods :crit, down, 4, 6
    
    section New Pods
    All Pods (v2) :new, 6, 10
```

### Deployment Best Practices

#### Resource Management
```yaml
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

#### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Sự khác biệt giữa Liveness và Readiness**:

```mermaid
graph TB
    subgraph "Liveness Probe"
        LP[Liveness Check] --> LF{Failed?}
        LF -->|Yes| RESTART[Restart Container]
        LF -->|No| CONTINUE[Continue Running]
    end
    
    subgraph "Readiness Probe"
        RP[Readiness Check] --> RF{Failed?}
        RF -->|Yes| REMOVE[Remove from Service]
        RF -->|No| SERVE[Serve Traffic]
    end
```

## 🗃️ StatefulSet - Stateful Applications

### StatefulSet vs Deployment

| Aspect | Deployment | StatefulSet |
|--------|------------|-------------|
| Pod Names | Random (nginx-abc123) | Ordered (mysql-0, mysql-1) |
| Network Identity | Dynamic IP | Stable hostname |
| Storage | Shared or none | Dedicated per pod |
| Scaling | Parallel | Sequential |
| Updates | Rolling | Rolling (ordered) |

### StatefulSet Guarantees

```mermaid
graph TB
    subgraph "StatefulSet: mysql"
        POD0[mysql-0<br/>mysql-0.mysql.default.svc.cluster.local]
        POD1[mysql-1<br/>mysql-1.mysql.default.svc.cluster.local]
        POD2[mysql-2<br/>mysql-2.mysql.default.svc.cluster.local]
    end
    
    subgraph "Persistent Volumes"
        PVC0[mysql-data-mysql-0<br/>10Gi]
        PVC1[mysql-data-mysql-1<br/>10Gi]
        PVC2[mysql-data-mysql-2<br/>10Gi]
    end
    
    POD0 --> PVC0
    POD1 --> PVC1
    POD2 --> PVC2
    
    subgraph "Headless Service"
        SVC[mysql<br/>ClusterIP: None]
    end
    
    SVC -.-> POD0
    SVC -.-> POD1
    SVC -.-> POD2
```

### Scaling StatefulSet

```mermaid
sequenceDiagram
    participant U as User
    participant SS as StatefulSet
    participant P0 as mysql-0
    participant P1 as mysql-1
    participant P2 as mysql-2
    
    Note over SS: Initial state: 1 replica
    SS->>P0: Create mysql-0
    P0-->>SS: Ready
    
    U->>SS: Scale to 3 replicas
    SS->>P1: Create mysql-1 (wait for mysql-0)
    P1-->>SS: Ready
    SS->>P2: Create mysql-2 (wait for mysql-1)
    P2-->>SS: Ready
    
    Note over SS: Scale down to 1
    U->>SS: Scale to 1 replica
    SS->>P2: Delete mysql-2 (reverse order)
    SS->>P1: Delete mysql-1
    Note over P0: mysql-0 remains
```

## 🌐 Service - Network Abstraction

### Service Types Deep Dive

#### 1. ClusterIP (Default)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

```mermaid
graph TB
    subgraph "Cluster"
        SVC[Service<br/>ClusterIP: 10.96.1.100]
        POD1[Pod 1<br/>10.244.1.10:8080]
        POD2[Pod 2<br/>10.244.2.20:8080]
        POD3[Pod 3<br/>10.244.3.30:8080]
        
        CLIENT[Client Pod] --> SVC
        SVC --> POD1
        SVC --> POD2
        SVC --> POD3
    end
```

#### 2. NodePort
```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

```mermaid
graph TB
    subgraph "External"
        EXT[External Client]
    end
    
    subgraph "Cluster"
        NODE1[Node 1<br/>192.168.1.10:30080]
        NODE2[Node 2<br/>192.168.1.11:30080]
        
        SVC[Service<br/>NodePort: 30080]
        POD1[Pod 1]
        POD2[Pod 2]
        
        EXT --> NODE1
        EXT --> NODE2
        NODE1 --> SVC
        NODE2 --> SVC
        SVC --> POD1
        SVC --> POD2
    end
```

#### 3. LoadBalancer
```yaml
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
```

```mermaid
graph TB
    subgraph "Cloud Provider"
        LB[Load Balancer<br/>203.0.113.100]
    end
    
    subgraph "Cluster"
        NODE1[Node 1:30080]
        NODE2[Node 2:30080]
        SVC[Service]
        POD1[Pod 1]
        POD2[Pod 2]
        
        LB --> NODE1
        LB --> NODE2
        NODE1 --> SVC
        NODE2 --> SVC
        SVC --> POD1
        SVC --> POD2
    end
    
    EXT[External Client] --> LB
```

### Service Discovery

#### DNS-based Discovery
```bash
# Trong cluster, pods có thể access service qua:
curl http://my-service.default.svc.cluster.local
curl http://my-service.default.svc
curl http://my-service  # same namespace
```

#### Environment Variables
```bash
# Kubernetes tự động inject env vars
MY_SERVICE_SERVICE_HOST=10.96.1.100
MY_SERVICE_SERVICE_PORT=80
```

### Endpoints Controller

```mermaid
sequenceDiagram
    participant S as Service
    participant E as Endpoints
    participant P as Pod
    participant EP as Endpoints Controller
    
    Note over S,P: Pod starts with matching labels
    P->>EP: Pod Ready
    EP->>E: Add Pod IP to Endpoints
    E-->>S: Service routes to Pod
    
    Note over S,P: Pod becomes unready
    P->>EP: Pod NotReady
    EP->>E: Remove Pod IP from Endpoints
    E-->>S: Service stops routing to Pod
```

## ⚡ Job & CronJob - Batch Workloads

### Job Patterns

#### 1. Single Job
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: single-job
spec:
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["echo", "Hello World"]
      restartPolicy: Never
```

#### 2. Parallel Jobs với Work Queue
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
spec:
  parallelism: 3
  completions: 6
  template:
    spec:
      containers:
      - name: worker
        image: my-worker
        command: ["process-item"]
      restartPolicy: Never
```

```mermaid
graph TB
    subgraph "Job Controller"
        JOB[Job<br/>parallelism: 3<br/>completions: 6]
    end
    
    subgraph "Work Queue"
        Q[Queue<br/>item1, item2, item3, item4, item5, item6]
    end
    
    subgraph "Worker Pods"
        W1[Worker 1] --> Q
        W2[Worker 2] --> Q
        W3[Worker 3] --> Q
    end
    
    JOB --> W1
    JOB --> W2
    JOB --> W3
```

### CronJob Scheduling

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-tool
            command: ["backup-database"]
          restartPolicy: OnFailure
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
```

**Cron Schedule Examples**:
```
0 2 * * *     # Daily at 2 AM
*/15 * * * *  # Every 15 minutes
0 0 * * 0     # Weekly on Sunday
0 0 1 * *     # Monthly on 1st day
```

## 🎯 Tình huống thực tế: E-commerce Application

Hãy xem cách deploy một ứng dụng e-commerce hoàn chỉnh:

```mermaid
graph TB
    subgraph "Frontend Tier"
        FE_DEP[Frontend Deployment<br/>React App]
        FE_SVC[Frontend Service<br/>LoadBalancer]
        FE_POD1[Frontend Pod 1]
        FE_POD2[Frontend Pod 2]
        
        FE_DEP --> FE_POD1
        FE_DEP --> FE_POD2
        FE_SVC --> FE_POD1
        FE_SVC --> FE_POD2
    end
    
    subgraph "Backend Tier"
        BE_DEP[Backend Deployment<br/>Node.js API]
        BE_SVC[Backend Service<br/>ClusterIP]
        BE_POD1[Backend Pod 1]
        BE_POD2[Backend Pod 2]
        BE_POD3[Backend Pod 3]
        
        BE_DEP --> BE_POD1
        BE_DEP --> BE_POD2
        BE_DEP --> BE_POD3
        BE_SVC --> BE_POD1
        BE_SVC --> BE_POD2
        BE_SVC --> BE_POD3
    end
    
    subgraph "Database Tier"
        DB_STS[Database StatefulSet<br/>PostgreSQL]
        DB_SVC[Database Service<br/>Headless]
        DB_POD[Database Pod<br/>postgres-0]
        DB_PVC[PersistentVolumeClaim<br/>10Gi]
        
        DB_STS --> DB_POD
        DB_SVC --> DB_POD
        DB_POD --> DB_PVC
    end
    
    subgraph "Background Jobs"
        CRON[CronJob<br/>Daily Reports]
        JOB_POD[Job Pod]
        
        CRON --> JOB_POD
    end
    
    FE_POD1 --> BE_SVC
    FE_POD2 --> BE_SVC
    BE_POD1 --> DB_SVC
    BE_POD2 --> DB_SVC
    BE_POD3 --> DB_SVC
    JOB_POD --> DB_SVC
```

## 🔧 Troubleshooting Common Issues

### 1. Pod Stuck in Pending
```bash
kubectl describe pod <pod-name>
# Common causes:
# - Insufficient resources
# - Node selector mismatch
# - Taints/tolerations
# - PVC not bound
```

### 2. ImagePullBackOff
```bash
kubectl describe pod <pod-name>
# Common causes:
# - Wrong image name/tag
# - Private registry without credentials
# - Network issues
```

### 3. CrashLoopBackOff
```bash
kubectl logs <pod-name> --previous
# Common causes:
# - Application error
# - Missing configuration
# - Health check failures
```

### 4. Service Not Accessible
```bash
kubectl get endpoints <service-name>
kubectl describe service <service-name>
# Common causes:
# - Wrong selector labels
# - Pods not ready
# - Port mismatch
```

## 💡 Best Practices

### 1. Resource Management
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### 2. Labels và Selectors
```yaml
metadata:
  labels:
    app: my-app
    version: v1.0.0
    component: backend
    tier: api
```

### 3. Health Checks
- **Liveness**: Restart container nếu unhealthy
- **Readiness**: Remove từ service nếu not ready
- **Startup**: Cho phép slow-starting containers

### 4. Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

## 🤔 Câu hỏi suy ngẫm

1. **Khi nào nên dùng StatefulSet thay vì Deployment?**
   - Cần stable network identity
   - Ordered deployment/scaling
   - Persistent storage per pod

2. **Tại sao cần readiness probe khác với liveness probe?**
   - Liveness: Container health
   - Readiness: Application ready to serve

3. **Làm thế nào để zero-downtime deployment?**
   - Rolling update với maxUnavailable: 0
   - Proper readiness probes
   - Graceful shutdown

4. **Service mesh có thay thế được Service không?**
   - Service mesh bổ sung, không thay thế
   - Service: L4 load balancing
   - Service mesh: L7 features (retry, circuit breaker, etc.)