# Networking - Labs thực hành

## 🚀 Lab 1: Basic Networking và Service Discovery

### Bước 1: Deploy Test Applications
```bash
# Deploy 3-tier application
kubectl apply -f network-test-apps.yaml

# Verify deployments
kubectl get deployments
kubectl get services
kubectl get pods -o wide --show-labels
```

### Bước 2: Test Pod-to-Pod Communication
```bash
# Get pod IPs
kubectl get pods -o wide

# Test direct pod communication
FRONTEND_POD=$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND_IP=$(kubectl get pods -l app=backend -o jsonpath='{.items[0].status.podIP}')

kubectl exec -it $FRONTEND_POD -- curl -m 5 http://$BACKEND_IP

# Test cross-node communication
kubectl get pods -o wide | grep -E "(frontend|backend|database)"
```

### Bước 3: Service Discovery Testing
```bash
# Test DNS resolution
kubectl exec -it $FRONTEND_POD -- nslookup backend-service
kubectl exec -it $FRONTEND_POD -- nslookup backend-service.default.svc.cluster.local

# Test service connectivity
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service:8080
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://database-service:5432

# Check environment variables
kubectl exec -it $FRONTEND_POD -- env | grep -E "(BACKEND|DATABASE)_SERVICE"
```

### Bước 4: Endpoints Investigation
```bash
# Check service endpoints
kubectl get endpoints
kubectl describe endpoints backend-service

# Scale backend và observe endpoints
kubectl scale deployment backend --replicas=4
kubectl get endpoints backend-service -w

# Scale down
kubectl scale deployment backend --replicas=2
```

## 🔌 Lab 2: CNI và Network Debugging

### Bước 1: Network Debugging Pod
```bash
# Deploy netshoot for debugging
kubectl run netshoot --image=nicolaka/netshoot --rm -it -- bash

# Trong netshoot pod:
# Check network interfaces
ip addr show

# Check routes
ip route show

# Check iptables rules
iptables -L -n | head -20

# Test connectivity
ping 8.8.8.8
nslookup kubernetes.default.svc.cluster.local
```

### Bước 2: CNI Plugin Investigation
```bash
# Check CNI config (trên node)
docker exec k8s-learning-control-plane cat /etc/cni/net.d/10-kindnet.conflist

# Check CNI binaries
docker exec k8s-learning-control-plane ls -la /opt/cni/bin/

# Check pod network namespace
POD_NAME=$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- ip netns list 2>/dev/null || echo "netns command not available"
```

### Bước 3: Network Performance Testing
```bash
# Deploy iperf3 server
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: iperf3-server
  labels:
    app: iperf3-server
spec:
  containers:
  - name: iperf3
    image: networkstatic/iperf3
    command: ["iperf3", "-s"]
    ports:
    - containerPort: 5201
---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-service
spec:
  selector:
    app: iperf3-server
  ports:
  - port: 5201
    targetPort: 5201
EOF

# Deploy iperf3 client
kubectl run iperf3-client --image=networkstatic/iperf3 --rm -it -- iperf3 -c iperf3-service -t 10

# Cleanup
kubectl delete pod iperf3-server
kubectl delete service iperf3-service
```

## 🎯 Lab 3: Service Types và Load Balancing

### Bước 1: ClusterIP Service
```bash
# Test ClusterIP (already deployed)
kubectl get service backend-service

# Test load balancing
for i in {1..10}; do
  kubectl exec -it $FRONTEND_POD -- curl -s http://backend-service:8080 | grep -o "Server: .*"
done
```

### Bước 2: NodePort Service
```bash
# Create NodePort service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Test NodePort access
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "NodePort accessible at: http://$NODE_IP:30080"

# From host machine (if accessible)
curl http://localhost:30080 || echo "Access via kind port mapping"
```

### Bước 3: LoadBalancer Service (Cloud simulation)
```bash
# Create LoadBalancer service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
EOF

# Check service (will be pending without cloud provider)
kubectl get service frontend-loadbalancer
kubectl describe service frontend-loadbalancer
```

### Bước 4: Headless Service
```bash
# Create headless service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-headless
spec:
  clusterIP: None
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
EOF

# Test DNS resolution for headless service
kubectl exec -it $FRONTEND_POD -- nslookup backend-headless
kubectl exec -it $FRONTEND_POD -- dig backend-headless.default.svc.cluster.local
```

## 🔒 Lab 4: Network Policies

### Bước 1: Default Deny Policy
```bash
# Apply default deny policy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Test connectivity (should fail)
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service:8080 || echo "Connection blocked by policy"
```

### Bước 2: Allow Frontend to Backend
```bash
# Allow frontend to backend communication
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

# Test connectivity (should work)
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service:8080
```

### Bước 3: Allow Backend to Database
```bash
# Allow backend to database
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
EOF

# Test database connectivity from backend
BACKEND_POD=$(kubectl get pods -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $BACKEND_POD -- nc -zv database-service 5432
```

### Bước 4: Allow DNS Resolution
```bash
# Allow DNS for all pods
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

# Test DNS resolution
kubectl exec -it $FRONTEND_POD -- nslookup backend-service
```

### Bước 5: Namespace-based Policies
```bash
# Create test namespace
kubectl create namespace test-ns
kubectl label namespace test-ns name=test-ns

# Deploy pod in test namespace
kubectl run test-pod --image=busybox --namespace=test-ns -- sleep 3600

# Allow cross-namespace communication
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-test-namespace
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: test-ns
    ports:
    - protocol: TCP
      port: 80
EOF

# Test cross-namespace connectivity
kubectl exec -it test-pod -n test-ns -- nc -zv backend-service.default.svc.cluster.local 8080
```

## 🌉 Lab 5: Ingress Controller

### Bước 1: Install NGINX Ingress Controller
```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx
```

### Bước 2: Create Ingress Resource
```bash
# Create ingress for frontend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 8080
EOF

# Check ingress
kubectl get ingress
kubectl describe ingress frontend-ingress
```

### Bước 3: Test Ingress
```bash
# Add host entry (for local testing)
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts

# Test ingress (kind exposes on localhost:80)
curl -H "Host: myapp.local" http://localhost/
curl -H "Host: myapp.local" http://localhost/api/

# Or use kubectl port-forward
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &
curl -H "Host: myapp.local" http://localhost:8080/
```

### Bước 4: TLS Ingress
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.local/O=myapp.local"

# Create TLS secret
kubectl create secret tls myapp-tls --key tls.key --cert tls.crt

# Update ingress with TLS
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress-tls
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - myapp.local
    secretName: myapp-tls
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
EOF

# Test HTTPS
curl -k -H "Host: myapp.local" https://localhost/
```

## 🔍 Lab 6: Network Troubleshooting

### Bước 1: DNS Issues
```bash
# Simulate DNS issue
kubectl scale deployment -n kube-system coredns --replicas=0

# Test DNS resolution (should fail)
kubectl exec -it $FRONTEND_POD -- nslookup backend-service || echo "DNS resolution failed"

# Fix DNS
kubectl scale deployment -n kube-system coredns --replicas=2
kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s

# Test again
kubectl exec -it $FRONTEND_POD -- nslookup backend-service
```

### Bước 2: Service Endpoint Issues
```bash
# Break service by changing selector
kubectl patch service backend-service -p '{"spec":{"selector":{"app":"nonexistent"}}}'

# Check endpoints (should be empty)
kubectl get endpoints backend-service

# Test connectivity (should fail)
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service:8080 || echo "No endpoints available"

# Fix service
kubectl patch service backend-service -p '{"spec":{"selector":{"app":"backend"}}}'

# Verify fix
kubectl get endpoints backend-service
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service:8080
```

### Bước 3: Network Policy Debugging
```bash
# Create overly restrictive policy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-all-egress
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  # No egress rules = block all
EOF

# Test connectivity (should fail)
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service:8080 || echo "Blocked by network policy"

# Debug network policies
kubectl get networkpolicies
kubectl describe networkpolicy block-all-egress

# Remove restrictive policy
kubectl delete networkpolicy block-all-egress
```

### Bước 4: Performance Issues
```bash
# Simulate high latency
kubectl run latency-test --image=busybox --rm -it -- sh -c "
  while true; do
    time nc -zv backend-service 8080
    sleep 1
  done
"

# Monitor network traffic
kubectl exec -it netshoot -- tcpdump -i any -n host backend-service
```

## 🎯 Lab 7: Advanced Networking Scenarios

### Bước 1: Multi-Namespace Communication
```bash
# Create production namespace
kubectl create namespace production
kubectl label namespace production name=production

# Deploy backend in production
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-prod
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-prod
  template:
    metadata:
      labels:
        app: backend-prod
        tier: backend
    spec:
      containers:
      - name: backend
        image: httpd:2.4
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: production
spec:
  selector:
    app: backend-prod
  ports:
  - port: 8080
    targetPort: 80
EOF

# Test cross-namespace communication
kubectl exec -it $FRONTEND_POD -- curl -m 5 http://backend-service.production.svc.cluster.local:8080
```

### Bước 2: External Service Integration
```bash
# Create external service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: httpbin.org
  ports:
  - port: 80
    targetPort: 80
EOF

# Test external service
kubectl exec -it $FRONTEND_POD -- curl -m 10 http://external-api/get
```

### Bước 3: Service Mesh Preparation
```bash
# Label namespace for Istio injection (if Istio is installed)
kubectl label namespace default istio-injection=enabled

# Restart pods to get sidecar injection
kubectl rollout restart deployment frontend
kubectl rollout restart deployment backend

# Check for sidecar containers
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

## 📊 Lab 8: Network Monitoring

### Bước 1: Network Metrics Collection
```bash
# Deploy network monitoring pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-monitor
spec:
  containers:
  - name: monitor
    image: nicolaka/netshoot
    command:
    - sh
    - -c
    - |
      while true; do
        echo "=== Network Statistics \$(date) ==="
        ss -tuln
        echo "=== Connection Tracking ==="
        netstat -i
        echo "=== DNS Queries ==="
        nslookup backend-service
        echo "================================"
        sleep 30
      done
EOF

kubectl logs network-monitor -f
```

### Bước 2: Traffic Analysis
```bash
# Generate traffic
kubectl run traffic-generator --image=busybox --rm -it -- sh -c "
  while true; do
    wget -qO- http://backend-service:8080
    sleep 1
  done
"

# Monitor traffic in another terminal
kubectl exec -it netshoot -- tcpdump -i any -n port 8080
```

## 🧹 Cleanup
```bash
# Remove network policies
kubectl delete networkpolicies --all

# Remove ingress resources
kubectl delete ingress --all
kubectl delete secrets myapp-tls

# Remove services
kubectl delete service frontend-nodeport frontend-loadbalancer backend-headless external-api

# Remove test namespaces
kubectl delete namespace test-ns production

# Remove test pods
kubectl delete pod netshoot network-monitor --ignore-not-found

# Clean up host file
sudo sed -i '/myapp.local/d' /etc/hosts

# Remove certificates
rm -f tls.key tls.crt

echo "Cleanup completed!"
```

## 🎓 Advanced Exercises

### Exercise 1: Custom CNI Plugin
Research và implement một CNI plugin đơn giản.

### Exercise 2: Service Mesh Implementation
Deploy Istio hoặc Linkerd và implement traffic management.

### Exercise 3: Network Security Audit
Tạo comprehensive network security policies cho multi-tier application.

### Exercise 4: Performance Optimization
Optimize network performance cho high-throughput applications.

### Exercise 5: Multi-Cluster Networking
Setup cross-cluster communication với tools như Submariner.