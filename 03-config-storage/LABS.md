# Config & Storage - Labs thực hành

## 🚀 Lab 1: ConfigMap Management

### Bước 1: Tạo ConfigMap từ nhiều nguồn
```bash
# Từ literal values
kubectl create configmap app-config \
  --from-literal=database_url=postgresql://localhost:5432/mydb \
  --from-literal=debug_mode=true \
  --from-literal=max_connections=100

# Từ file
echo "log_level=info" > app.properties
echo "timeout=30" >> app.properties
kubectl create configmap app-properties --from-file=app.properties

# Từ directory
mkdir config-dir
echo "server_name=myapp" > config-dir/server.conf
echo "port=8080" > config-dir/network.conf
kubectl create configmap app-configs --from-file=config-dir/

# Xem ConfigMaps
kubectl get configmaps
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
```

### Bước 2: Sử dụng ConfigMap trong Pod
```bash
# Environment variables
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env | grep -E '(DATABASE|DEBUG|MAX)'; sleep 3600"]
    env:
    - name: DATABASE_URL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_url
    - name: DEBUG_MODE
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: debug_mode
    envFrom:
    - configMapRef:
        name: app-config
        prefix: APP_
  restartPolicy: Never
EOF

# Xem environment variables
kubectl logs config-env-pod

# Volume mount
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-volume-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /config/; cat /config/*; sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: app-properties
  restartPolicy: Never
EOF

kubectl logs config-volume-pod
```

### Bước 3: ConfigMap Hot Reload
```bash
# Deploy nginx với ConfigMap
kubectl apply -f nginx-with-config.yaml

# Test initial config
kubectl port-forward service/nginx-custom-service 8080:80 &
curl http://localhost:8080/health

# Update ConfigMap
kubectl patch configmap nginx-config --patch '{"data":{"index.html":"<h1>Updated Content!</h1>"}}'

# Restart deployment để reload config
kubectl rollout restart deployment nginx-custom

# Verify update
curl http://localhost:8080/
```

## 🔐 Lab 2: Secret Management

### Bước 1: Tạo và quản lý Secrets
```bash
# Generic secret từ literal
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=supersecret123

# Secret từ file
echo -n "my-secret-token" > token.txt
kubectl create secret generic api-token --from-file=token=token.txt

# Docker registry secret
kubectl create secret docker-registry my-registry \
  --docker-server=myregistry.com \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=user@example.com

# TLS secret
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=myapp.local"
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key

# Xem secrets (data sẽ bị encode)
kubectl get secrets
kubectl describe secret db-credentials
kubectl get secret db-credentials -o yaml
```

### Bước 2: Sử dụng Secrets trong Pod
```bash
# Environment variables từ Secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Username: \$DB_USER; echo Password: \$DB_PASS; sleep 3600"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
  restartPolicy: Never
EOF

kubectl logs secret-env-pod

# Volume mount Secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /secrets/; cat /secrets/*; sleep 3600"]
    volumeMounts:
    - name: secret-volume
      mountPath: /secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
      defaultMode: 0400
  restartPolicy: Never
EOF

kubectl exec secret-volume-pod -- ls -la /secrets/
kubectl exec secret-volume-pod -- cat /secrets/username
```

### Bước 3: Secret Security Best Practices
```bash
# Encrypt secrets at rest (cluster admin task)
# /etc/kubernetes/encryption-config.yaml
cat <<EOF > encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: $(head -c 32 /dev/urandom | base64)
  - identity: {}
EOF

# RBAC for secrets
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
  resourceNames: ["db-credentials"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-binding
subjects:
- kind: ServiceAccount
  name: default
  namespace: default
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Test RBAC
kubectl auth can-i get secret db-credentials
kubectl auth can-i get secret api-token
```

## 💾 Lab 3: Volumes và Persistent Storage

### Bước 1: emptyDir và hostPath
```bash
# emptyDir volume
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "while true; do echo \$(date) >> /shared/log.txt; sleep 5; done"]
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  - name: reader
    image: busybox
    command: ["sh", "-c", "tail -f /shared/log.txt"]
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  volumes:
  - name: shared-data
    emptyDir:
      sizeLimit: 1Gi
EOF

# Xem logs từ reader container
kubectl logs emptydir-pod -c reader -f

# hostPath volume (chỉ cho development)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /host-data; echo 'Hello from pod' > /host-data/pod-file.txt; sleep 3600"]
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/k8s-hostpath
      type: DirectoryOrCreate
EOF

# Verify file trên node
docker exec k8s-learning-control-plane ls -la /tmp/k8s-hostpath/
```

### Bước 2: PersistentVolume và PersistentVolumeClaim
```bash
# Tạo PersistentVolume (static provisioning)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/pv-data
    type: DirectoryOrCreate
EOF

# Tạo PersistentVolumeClaim
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-local
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

# Xem PV và PVC binding
kubectl get pv
kubectl get pvc
kubectl describe pv pv-local
kubectl describe pvc pvc-local

# Sử dụng PVC trong Pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo 'Persistent data' > /data/file.txt; cat /data/file.txt; sleep 3600"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: pvc-local
EOF

kubectl logs pvc-pod
```

### Bước 3: StorageClass và Dynamic Provisioning
```bash
# Tạo StorageClass (local storage)
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# Dynamic PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: local-storage
EOF

# Xem PVC status (sẽ pending cho đến khi có pod sử dụng)
kubectl get pvc dynamic-pvc

# Tạo pod sử dụng dynamic PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: dynamic-storage
      mountPath: /usr/share/nginx/html
  volumes:
  - name: dynamic-storage
    persistentVolumeClaim:
      claimName: dynamic-pvc
EOF

kubectl get pvc dynamic-pvc
kubectl get pv
```

## 🗃️ Lab 4: StatefulSet với Persistent Storage

### Bước 1: Deploy PostgreSQL StatefulSet
```bash
# Deploy PostgreSQL với persistent storage
kubectl apply -f postgres-statefulset.yaml

# Monitor StatefulSet deployment
kubectl get statefulsets -w
kubectl get pods -l app=postgres -w
kubectl get pvc

# Verify PostgreSQL is running
kubectl exec -it postgres-0 -- psql -U postgres -d myapp -c "SELECT version();"
```

### Bước 2: Test Data Persistence
```bash
# Connect và tạo data
kubectl exec -it postgres-0 -- psql -U postgres -d myapp

# Trong PostgreSQL shell:
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('John Doe', 'john@example.com'),
('Jane Smith', 'jane@example.com');

SELECT * FROM users;
\q

# Delete pod và verify data persistence
kubectl delete pod postgres-0
kubectl get pods -l app=postgres -w

# Reconnect và verify data
kubectl exec -it postgres-0 -- psql -U postgres -d myapp -c "SELECT * FROM users;"
```

### Bước 3: Scale StatefulSet
```bash
# Scale to 3 replicas
kubectl scale statefulset postgres --replicas=3

# Observe ordered creation
kubectl get pods -l app=postgres -w

# Verify each pod has its own storage
kubectl get pvc
kubectl exec -it postgres-1 -- df -h /var/lib/postgresql/data
kubectl exec -it postgres-2 -- df -h /var/lib/postgresql/data

# Test individual pod connectivity
kubectl exec -it postgres-1 -- psql -U postgres -d myapp -c "SELECT 'postgres-1' as pod_name;"
kubectl exec -it postgres-2 -- psql -U postgres -d myapp -c "SELECT 'postgres-2' as pod_name;"
```

## 🎯 Lab 5: WordPress với MySQL - Complete Application

### Deploy Complete Stack
```bash
# 1. MySQL Secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  mysql-root-password: $(echo -n "rootpassword123" | base64)
  mysql-user: $(echo -n "wpuser" | base64)
  mysql-password: $(echo -n "wppassword123" | base64)
  mysql-database: $(echo -n "wordpress" | base64)
EOF

# 2. MySQL StatefulSet
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-user
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-database
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: mysql-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 2Gi

---
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
EOF

# 3. WordPress ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: wordpress-config
data:
  WORDPRESS_DB_HOST: "mysql:3306"
  WORDPRESS_DB_NAME: "wordpress"
  WORDPRESS_TABLE_PREFIX: "wp_"
  WORDPRESS_DEBUG: "1"
EOF

# 4. WordPress Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.0
        env:
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-user
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        envFrom:
        - configMapRef:
            name: wordpress-config
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
spec:
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF
```

### Test WordPress Application
```bash
# Monitor deployment
kubectl get all
kubectl get pvc

# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s

# Wait for WordPress to be ready
kubectl wait --for=condition=ready pod -l app=wordpress --timeout=300s

# Test database connectivity
kubectl exec -it mysql-0 -- mysql -u wpuser -pwppassword123 wordpress -e "SHOW TABLES;"

# Access WordPress
kubectl get service wordpress
kubectl port-forward service/wordpress 8080:80 &

# Open browser to http://localhost:8080
echo "WordPress should be accessible at http://localhost:8080"
```

## 🔧 Lab 6: Backup và Restore

### Database Backup Job
```bash
# Backup CronJob
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: mysql:8.0
            command:
            - sh
            - -c
            - |
              BACKUP_FILE="/backup/mysql-backup-\$(date +%Y%m%d-%H%M%S).sql"
              mysqldump -h mysql -u \$MYSQL_USER -p\$MYSQL_PASSWORD \$MYSQL_DATABASE > \$BACKUP_FILE
              echo "Backup completed: \$BACKUP_FILE"
              ls -la /backup/
            env:
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-user
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-password
            - name: MYSQL_DATABASE
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-database
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Manual backup trigger
kubectl create job --from=cronjob/mysql-backup manual-backup-$(date +%s)

# Monitor backup job
kubectl get jobs
kubectl logs job/manual-backup-<timestamp>
```

### Volume Snapshot (nếu CSI driver hỗ trợ)
```bash
# Volume Snapshot Class
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: hostpath.csi.k8s.io
deletionPolicy: Delete
EOF

# Volume Snapshot
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: mysql-storage-mysql-0
EOF

kubectl get volumesnapshots
```

## 📊 Lab 7: Monitoring Storage

### Storage Metrics Pod
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: storage-monitor
spec:
  containers:
  - name: monitor
    image: busybox
    command:
    - sh
    - -c
    - |
      while true; do
        echo "=== Storage Usage Report \$(date) ==="
        df -h /data
        echo "=== Directory Sizes ==="
        du -sh /data/* 2>/dev/null || echo "No subdirectories"
        echo "=== Inode Usage ==="
        df -i /data
        echo "================================"
        sleep 60
      done
    volumeMounts:
    - name: monitored-storage
      mountPath: /data
  volumes:
  - name: monitored-storage
    persistentVolumeClaim:
      claimName: wordpress-pvc
EOF

kubectl logs storage-monitor -f
```

## 🚨 Lab 8: Troubleshooting

### Common Storage Issues

#### PVC Stuck in Pending
```bash
# Tạo PVC sẽ stuck
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: stuck-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi  # Too large
  storageClassName: nonexistent-class
EOF

# Debug
kubectl describe pvc stuck-pvc
kubectl get events --field-selector involvedObject.name=stuck-pvc
```

#### Pod Can't Mount Volume
```bash
# Tạo pod với permission issues
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: mount-issue-pod
spec:
  securityContext:
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /data; touch /data/test.txt; sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-local
EOF

kubectl describe pod mount-issue-pod
kubectl logs mount-issue-pod
```

## 🧹 Cleanup
```bash
# Cleanup all resources
kubectl delete cronjobs --all
kubectl delete jobs --all
kubectl delete deployments --all
kubectl delete statefulsets --all
kubectl delete pods --all
kubectl delete services --all
kubectl delete pvc --all
kubectl delete pv --all
kubectl delete configmaps --all
kubectl delete secrets --all
kubectl delete storageclasses --all

# Cleanup files
rm -f app.properties token.txt tls.crt tls.key encryption-config.yaml
rm -rf config-dir
```

## 🎓 Advanced Exercises

### Exercise 1: Multi-Environment Configuration
Setup development, staging, production configs using ConfigMaps và Secrets.

### Exercise 2: Secret Rotation
Implement automated secret rotation với external tools.

### Exercise 3: Storage Performance Testing
Benchmark different storage classes và volume types.

### Exercise 4: Disaster Recovery
Implement complete backup/restore strategy cho stateful applications.

### Exercise 5: Configuration Validation
Create admission controllers để validate ConfigMap và Secret formats.