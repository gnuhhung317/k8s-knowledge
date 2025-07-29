# Core Objects - Labs thực hành

## 🚀 Lab 1: Pod Lifecycle và Multi-Container Patterns

### Bước 1: Basic Pod
```bash
# Tạo pod từ YAML
kubectl apply -f basic-pod.yaml

# Theo dõi pod lifecycle
kubectl get pods -w

# Xem chi tiết pod
kubectl describe pod my-pod

# Xem logs
kubectl logs my-pod

# Exec vào container
kubectl exec -it my-pod -- /bin/bash
```

### Bước 2: Multi-Container Pod
```bash
# Deploy multi-container pod
kubectl apply -f multi-container-pod.yaml

# Xem tất cả containers trong pod
kubectl get pod multi-container-pod -o jsonpath='{.spec.containers[*].name}'

# Logs từ specific container
kubectl logs multi-container-pod -c web-server
kubectl logs multi-container-pod -c log-processor
kubectl logs multi-container-pod -c metrics-exporter

# Exec vào specific container
kubectl exec -it multi-container-pod -c web-server -- /bin/bash

# Port forward để test metrics
kubectl port-forward multi-container-pod 9113:9113
curl http://localhost:9113/metrics
```

### Bước 3: Pod Debugging
```bash
# Tạo pod có lỗi
kubectl run debug-pod --image=nginx:wrong-tag

# Debug pod stuck in ImagePullBackOff
kubectl describe pod debug-pod
kubectl get events --field-selector involvedObject.name=debug-pod

# Fix và recreate
kubectl delete pod debug-pod
kubectl run debug-pod --image=nginx:1.21
```

## 🚀 Lab 2: Deployment Strategies

### Bước 1: Basic Deployment
```bash
# Deploy nginx
kubectl apply -f nginx-deployment.yaml

# Xem deployment, replicaset, pods
kubectl get deployments
kubectl get replicasets
kubectl get pods -l app=nginx

# Scale deployment
kubectl scale deployment nginx --replicas=5
kubectl get pods -l app=nginx -w
```

### Bước 2: Rolling Update
```bash
# Update image
kubectl set image deployment/nginx nginx=nginx:1.21

# Theo dõi rollout
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx

# Xem chi tiết revision
kubectl rollout history deployment/nginx --revision=2

# Rollback nếu cần
kubectl rollout undo deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=1
```

### Bước 3: Blue-Green Deployment Manual
```bash
# Tạo Blue version
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

# Tạo Service trỏ tới Blue
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

# Test Blue version
kubectl get service myapp-service
curl http://<EXTERNAL-IP>

# Deploy Green version
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
EOF

# Switch traffic to Green
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"green"}}}'

# Verify switch
curl http://<EXTERNAL-IP>

# Cleanup Blue if Green is stable
kubectl delete deployment app-blue
```

## 🗃️ Lab 3: StatefulSet với Database

### Bước 1: Deploy MySQL StatefulSet
```bash
# Deploy MySQL
kubectl apply -f mysql-statefulset.yaml

# Xem StatefulSet và Pods
kubectl get statefulsets
kubectl get pods -l app=mysql
kubectl get pvc

# Xem pod naming pattern
kubectl get pods -l app=mysql -o wide
```

### Bước 2: Test Persistent Storage
```bash
# Connect to MySQL
kubectl exec -it mysql-0 -- mysql -u root -prootpassword

# Tạo database và table
CREATE DATABASE testapp;
USE testapp;
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO users VALUES (1, 'John Doe');
SELECT * FROM users;
EXIT;

# Delete pod và verify data persistence
kubectl delete pod mysql-0
kubectl get pods -l app=mysql -w

# Reconnect và verify data
kubectl exec -it mysql-0 -- mysql -u root -prootpassword -e "SELECT * FROM testapp.users;"
```

### Bước 3: Scale StatefulSet
```bash
# Scale to 3 replicas
kubectl scale statefulset mysql --replicas=3

# Observe ordered creation
kubectl get pods -l app=mysql -w

# Verify each pod has its own storage
kubectl get pvc
kubectl exec -it mysql-1 -- df -h /var/lib/mysql
kubectl exec -it mysql-2 -- df -h /var/lib/mysql
```

## 🌐 Lab 4: Service Discovery và Networking

### Bước 1: Service Types
```bash
# ClusterIP Service (default)
kubectl expose deployment nginx --port=80 --type=ClusterIP --name=nginx-clusterip

# NodePort Service
kubectl expose deployment nginx --port=80 --type=NodePort --name=nginx-nodeport

# LoadBalancer Service (nếu có cloud provider)
kubectl expose deployment nginx --port=80 --type=LoadBalancer --name=nginx-lb

# Xem services
kubectl get services
```

### Bước 2: Service Discovery Testing
```bash
# Tạo test pod
kubectl run test-pod --image=busybox:1.35 --rm -it -- sh

# Trong test pod, test DNS resolution
nslookup nginx-clusterip
nslookup nginx-clusterip.default.svc.cluster.local

# Test connectivity
wget -qO- http://nginx-clusterip
wget -qO- http://nginx-clusterip.default.svc.cluster.local

# Test environment variables
env | grep NGINX_CLUSTERIP
```

### Bước 3: Headless Service với StatefulSet
```bash
# Xem headless service của MySQL
kubectl get service mysql
kubectl describe service mysql

# Test từ pod khác
kubectl run mysql-client --image=mysql:8.0 --rm -it -- bash

# Trong mysql-client pod
nslookup mysql
nslookup mysql-0.mysql
nslookup mysql-1.mysql
nslookup mysql-2.mysql

# Connect to specific pod
mysql -h mysql-0.mysql -u root -prootpassword
mysql -h mysql-1.mysql -u root -prootpassword
```

## ⚡ Lab 5: Jobs và CronJobs

### Bước 1: Simple Job
```bash
# Run pi calculation job
kubectl apply -f pi-calculation-job.yaml

# Monitor job
kubectl get jobs
kubectl describe job pi-calculation

# Xem logs
kubectl logs job/pi-calculation

# Cleanup completed job
kubectl delete job pi-calculation
```

### Bước 2: Parallel Jobs
```bash
# Tạo parallel job
cat <<EOF | kubectl apply -f -
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
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo "Worker \$HOSTNAME started at \$(date)"
          sleep \$((RANDOM % 30 + 10))
          echo "Worker \$HOSTNAME completed at \$(date)"
      restartPolicy: Never
  backoffLimit: 4
EOF

# Monitor parallel execution
kubectl get jobs -w
kubectl get pods -l job-name=parallel-job -w

# Xem logs từ tất cả pods
for pod in $(kubectl get pods -l job-name=parallel-job -o name); do
  echo "=== $pod ==="
  kubectl logs $pod
done
```

### Bước 3: CronJob
```bash
# Deploy backup cronjob
kubectl apply -f pi-calculation-job.yaml

# Xem cronjob
kubectl get cronjobs
kubectl describe cronjob backup-cronjob

# Manually trigger job
kubectl create job --from=cronjob/backup-cronjob manual-backup

# Monitor job history
kubectl get jobs
kubectl get pods -l job-name=manual-backup
```

## 🎯 Lab 6: Multi-Tier Application

### Deploy Complete E-commerce App
```bash
# 1. Database Tier
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: ecommerce
        - name: POSTGRES_USER
          value: admin
        - name: POSTGRES_PASSWORD
          value: password123
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
EOF

# 2. Backend API Tier
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
        tier: backend
    spec:
      containers:
      - name: api
        image: node:16-alpine
        command:
        - sh
        - -c
        - |
          cat > server.js << 'EOF'
          const http = require('http');
          const server = http.createServer((req, res) => {
            res.writeHead(200, {'Content-Type': 'application/json'});
            res.end(JSON.stringify({
              message: 'Backend API',
              hostname: require('os').hostname(),
              timestamp: new Date().toISOString()
            }));
          });
          server.listen(3000, () => console.log('Server running on port 3000'));
          EOF
          node server.js
        ports:
        - containerPort: 3000
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: ecommerce
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: backend-api
spec:
  selector:
    app: backend-api
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF

# 3. Frontend Tier
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  default.conf: |
    upstream backend {
        server backend-api:3000;
    }
    
    server {
        listen 80;
        
        location /api/ {
            proxy_pass http://backend/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

# 4. Background Jobs
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-report
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: report-generator
            image: busybox:1.35
            command:
            - sh
            - -c
            - |
              echo "Generating daily report at \$(date)"
              echo "Connecting to database: postgres:5432"
              echo "Report generated successfully"
          restartPolicy: OnFailure
EOF
```

### Test Multi-Tier Application
```bash
# Xem tất cả resources
kubectl get all

# Test database connectivity
kubectl exec -it postgres-0 -- psql -U admin -d ecommerce -c "SELECT version();"

# Test backend API
kubectl port-forward service/backend-api 3000:3000 &
curl http://localhost:3000

# Test frontend
kubectl get service frontend
# Access via LoadBalancer IP or port-forward
kubectl port-forward service/frontend 8080:80 &
curl http://localhost:8080/api/

# Test full flow
curl http://localhost:8080/api/
```

## 🔧 Lab 7: Troubleshooting Workshop

### Scenario 1: Pod Stuck in Pending
```bash
# Tạo pod với resource requests cao
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-hog
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "10Gi"
        cpu: "8"
EOF

# Debug
kubectl describe pod resource-hog
kubectl get nodes -o wide
kubectl describe nodes
```

### Scenario 2: ImagePullBackOff
```bash
# Tạo pod với wrong image
kubectl run broken-pod --image=nginx:nonexistent-tag

# Debug
kubectl describe pod broken-pod
kubectl get events --field-selector involvedObject.name=broken-pod
```

### Scenario 3: CrashLoopBackOff
```bash
# Tạo pod sẽ crash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "exit 1"]
EOF

# Debug
kubectl describe pod crash-pod
kubectl logs crash-pod --previous
```

### Scenario 4: Service Not Working
```bash
# Tạo service với wrong selector
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broken-service
spec:
  selector:
    app: wrong-label
  ports:
  - port: 80
    targetPort: 80
EOF

# Debug
kubectl describe service broken-service
kubectl get endpoints broken-service
kubectl get pods --show-labels
```

## 📊 Lab 8: Performance Testing

### Load Testing Deployment
```bash
# Tạo load test job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
spec:
  parallelism: 5
  completions: 5
  template:
    spec:
      containers:
      - name: load-tester
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          for i in \$(seq 1 100); do
            wget -qO- http://nginx-service/ > /dev/null
            sleep 0.1
          done
          echo "Load test completed"
      restartPolicy: Never
EOF

# Monitor during load test
kubectl get pods -l job-name=load-test -w
kubectl top pods
kubectl top nodes
```

## 🎓 Advanced Exercises

### Exercise 1: Custom Health Checks
Tạo application với custom health endpoints và configure appropriate probes.

### Exercise 2: Zero-Downtime Deployment
Implement zero-downtime deployment strategy với proper readiness probes.

### Exercise 3: Database Migration Job
Tạo Job để run database migrations trước khi deploy application.

### Exercise 4: Canary Deployment
Implement manual canary deployment với traffic splitting.

### Exercise 5: Multi-Environment Setup
Setup development, staging, production environments trong cùng cluster với namespaces.

## 🧹 Cleanup
```bash
# Cleanup tất cả resources
kubectl delete deployments --all
kubectl delete statefulsets --all
kubectl delete services --all
kubectl delete jobs --all
kubectl delete cronjobs --all
kubectl delete pods --all
kubectl delete pvc --all
kubectl delete configmaps --all
```