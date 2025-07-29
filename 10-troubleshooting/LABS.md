# Troubleshooting Labs - Thực hành Debug và Giải quyết Vấn đề

## Lab 1: Pod Troubleshooting

### Bước 1: Pod Stuck in Pending
```bash
# Create a problematic pod
kubectl apply -f scenarios/pending-pod.yaml

# Investigate the issue
kubectl get pods
kubectl describe pod pending-pod

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Solution: Fix resource requests or add nodes
kubectl delete pod pending-pod
kubectl apply -f solutions/fixed-pending-pod.yaml
```

### Bước 2: CrashLoopBackOff Debugging
```bash
# Deploy crashing application
kubectl apply -f scenarios/crashloop-pod.yaml

# Check pod status
kubectl get pods
kubectl describe pod crashloop-pod

# Check logs
kubectl logs crashloop-pod
kubectl logs crashloop-pod --previous

# Check resource limits
kubectl describe pod crashloop-pod | grep -A 5 Limits

# Fix the issue
kubectl apply -f solutions/fixed-crashloop-pod.yaml
```

### Bước 3: ImagePullBackOff Resolution
```bash
# Create pod with wrong image
kubectl apply -f scenarios/imagepull-pod.yaml

# Investigate
kubectl describe pod imagepull-pod

# Check image pull secrets
kubectl get secrets
kubectl describe secret regcred

# Test image availability
docker pull wrong-image:latest

# Fix the issue
kubectl apply -f solutions/fixed-imagepull-pod.yaml
```

## Lab 2: Network Troubleshooting

### Bước 1: Service Connectivity Issues
```bash
# Deploy application with service
kubectl apply -f scenarios/network-app.yaml

# Test service connectivity
kubectl get svc
kubectl get endpoints

# Debug connectivity
kubectl run debug-pod --image=busybox --rm -it -- /bin/sh
# Inside pod:
# nslookup network-service
# wget -qO- network-service:80

# Check service configuration
kubectl describe service network-service

# Fix service selector
kubectl apply -f solutions/fixed-network-service.yaml
```

### Bước 2: DNS Resolution Problems
```bash
# Check CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run dns-test --image=busybox --rm -it -- /bin/sh
# nslookup kubernetes.default
# nslookup network-service.default.svc.cluster.local

# Check CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Restart CoreDNS if needed
kubectl rollout restart deployment/coredns -n kube-system
```

### Bước 3: Network Policy Debugging
```bash
# Apply restrictive network policy
kubectl apply -f scenarios/restrictive-networkpolicy.yaml

# Test connectivity (should fail)
kubectl exec -it debug-pod -- wget -qO- network-service:80

# Check network policies
kubectl get networkpolicy
kubectl describe networkpolicy deny-all

# Create proper network policy
kubectl apply -f solutions/allow-networkpolicy.yaml

# Test connectivity (should work)
kubectl exec -it debug-pod -- wget -qO- network-service:80
```

## Lab 3: Storage Troubleshooting

### Bước 1: PVC Stuck in Pending
```bash
# Create PVC with wrong storage class
kubectl apply -f scenarios/pending-pvc.yaml

# Check PVC status
kubectl get pvc
kubectl describe pvc pending-pvc

# Check storage classes
kubectl get storageclass
kubectl describe storageclass wrong-storage-class

# Check available PVs
kubectl get pv

# Fix storage class
kubectl apply -f solutions/fixed-pvc.yaml
```

### Bước 2: Volume Mount Issues
```bash
# Deploy pod with mount problems
kubectl apply -f scenarios/mount-issue-pod.yaml

# Check pod status
kubectl describe pod mount-issue-pod

# Check volume configuration
kubectl get pod mount-issue-pod -o yaml | grep -A 20 volumes

# Check file permissions
kubectl exec -it mount-issue-pod -- ls -la /data

# Fix mount configuration
kubectl apply -f solutions/fixed-mount-pod.yaml
```

## Lab 4: Performance Troubleshooting

### Bước 1: High CPU Usage Analysis
```bash
# Deploy CPU-intensive application
kubectl apply -f scenarios/cpu-intensive-app.yaml

# Monitor resource usage
kubectl top pods
kubectl top nodes

# Check resource limits
kubectl describe pod cpu-intensive-app | grep -A 5 Limits

# Profile CPU usage
kubectl exec -it cpu-intensive-app -- top
kubectl exec -it cpu-intensive-app -- ps aux --sort=-%cpu

# Optimize resource allocation
kubectl apply -f solutions/optimized-cpu-app.yaml
```

### Bước 2: Memory Leak Investigation
```bash
# Deploy application with memory leak
kubectl apply -f scenarios/memory-leak-app.yaml

# Monitor memory usage over time
watch kubectl top pod memory-leak-app

# Check for OOM kills
kubectl describe pod memory-leak-app | grep -i "oom\|killed"

# Check application logs
kubectl logs memory-leak-app | grep -i "memory\|heap"

# Analyze memory usage
kubectl exec -it memory-leak-app -- free -h
kubectl exec -it memory-leak-app -- ps aux --sort=-%mem

# Fix memory leak
kubectl apply -f solutions/fixed-memory-app.yaml
```

### Bước 3: Slow Application Response
```bash
# Deploy slow application
kubectl apply -f scenarios/slow-app.yaml

# Test response time
kubectl exec -it debug-pod -- time wget -qO- slow-app:80

# Check application logs
kubectl logs slow-app --tail=50

# Profile application performance
kubectl exec -it slow-app -- netstat -an | grep ESTABLISHED

# Check database connections
kubectl exec -it slow-app -- ss -tuln

# Optimize application
kubectl apply -f solutions/optimized-slow-app.yaml
```

## Lab 5: Security Troubleshooting

### Bước 1: RBAC Permission Issues
```bash
# Create service account with limited permissions
kubectl apply -f scenarios/limited-rbac.yaml

# Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:limited-user
kubectl auth can-i create deployments --as=system:serviceaccount:default:limited-user

# Check role bindings
kubectl get rolebinding
kubectl describe rolebinding limited-binding

# Fix RBAC permissions
kubectl apply -f solutions/fixed-rbac.yaml

# Verify permissions
kubectl auth can-i --list --as=system:serviceaccount:default:limited-user
```

### Bước 2: Pod Security Policy Violations
```bash
# Apply restrictive pod security policy
kubectl apply -f scenarios/restrictive-psp.yaml

# Try to create privileged pod (should fail)
kubectl apply -f scenarios/privileged-pod.yaml

# Check pod security policy
kubectl get psp
kubectl describe psp restrictive-psp

# Check admission controller logs
kubectl logs -n kube-system kube-apiserver-* | grep admission

# Create compliant pod
kubectl apply -f solutions/compliant-pod.yaml
```

## Lab 6: Cluster-level Troubleshooting

### Bước 1: Node Issues
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node resources
kubectl top node <node-name>

# Check kubelet logs
ssh <node> "journalctl -u kubelet -f"

# Check container runtime
ssh <node> "systemctl status docker"
ssh <node> "systemctl status containerd"

# Drain problematic node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node after fix
kubectl uncordon <node-name>
```

### Bước 2: Control Plane Issues
```bash
# Check control plane pods
kubectl get pods -n kube-system

# Check API server
kubectl logs -n kube-system kube-apiserver-<master>

# Check etcd health
kubectl exec -n kube-system etcd-<master> -- etcdctl endpoint health

# Check scheduler
kubectl logs -n kube-system kube-scheduler-<master>

# Check controller manager
kubectl logs -n kube-system kube-controller-manager-<master>

# Check cluster info
kubectl cluster-info
kubectl cluster-info dump > cluster-dump.txt
```

## Lab 7: Monitoring và Alerting Debug

### Bước 1: Metrics Collection Issues
```bash
# Check metrics server
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Test metrics availability
kubectl top nodes
kubectl top pods

# Check metrics server logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Fix metrics collection
kubectl apply -f solutions/fixed-metrics-server.yaml
```

### Bước 2: Alert Investigation
```bash
# Check firing alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/alerts

# Check Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Check alert rules
kubectl get prometheusrule -n monitoring

# Test alert conditions
kubectl apply -f scenarios/trigger-alert.yaml

# Verify alert firing and resolution
kubectl delete -f scenarios/trigger-alert.yaml
```

## Lab 8: Application-Specific Debugging

### Bước 1: Database Connection Issues
```bash
# Deploy application with database
kubectl apply -f scenarios/db-app.yaml

# Check database connectivity
kubectl exec -it db-app -- nc -zv database-service 5432

# Check database logs
kubectl logs database-pod

# Check connection pool
kubectl exec -it db-app -- netstat -an | grep 5432

# Test database queries
kubectl exec -it database-pod -- psql -U user -d database -c "SELECT 1;"

# Fix connection issues
kubectl apply -f solutions/fixed-db-app.yaml
```

### Bước 2: Microservice Communication
```bash
# Deploy microservices
kubectl apply -f scenarios/microservices.yaml

# Test service-to-service communication
kubectl exec -it frontend-pod -- curl backend-service:8080/api

# Check service discovery
kubectl exec -it frontend-pod -- nslookup backend-service

# Trace request flow
kubectl logs frontend-pod | grep "request_id"
kubectl logs backend-pod | grep "request_id"

# Debug with distributed tracing
kubectl port-forward -n tracing svc/jaeger-query 16686:16686
```

## Lab 9: Emergency Scenarios

### Bước 1: Cluster Resource Exhaustion
```bash
# Simulate resource exhaustion
kubectl apply -f scenarios/resource-bomb.yaml

# Check cluster status
kubectl top nodes
kubectl get pods --all-namespaces | grep -v Running

# Emergency actions
kubectl delete deployment resource-bomb
kubectl scale deployment resource-bomb --replicas=0

# Check resource quotas
kubectl get resourcequota --all-namespaces

# Implement resource limits
kubectl apply -f solutions/resource-limits.yaml
```

### Bước 2: Security Incident Response
```bash
# Simulate security incident
kubectl apply -f scenarios/suspicious-pod.yaml

# Investigate suspicious activity
kubectl describe pod suspicious-pod
kubectl logs suspicious-pod

# Isolate the pod
kubectl label pod suspicious-pod quarantine=true
kubectl apply -f scenarios/quarantine-networkpolicy.yaml

# Collect evidence
kubectl exec suspicious-pod -- ps aux
kubectl exec suspicious-pod -- netstat -an

# Remove threat
kubectl delete pod suspicious-pod --force
```

## Lab 10: Advanced Debugging Techniques

### Bước 1: Debug with Ephemeral Containers
```bash
# Create problematic pod
kubectl apply -f scenarios/debug-target-pod.yaml

# Debug with ephemeral container (K8s 1.23+)
kubectl debug -it debug-target-pod --image=busybox --target=app

# Alternative: Create debug pod
kubectl run debug-pod --image=nicolaka/netshoot --rm -it -- /bin/bash

# Network debugging
kubectl exec -it debug-pod -- tcpdump -i eth0
kubectl exec -it debug-pod -- nmap -p 80 target-service
```

### Bước 2: Performance Profiling
```bash
# Deploy application for profiling
kubectl apply -f scenarios/profile-app.yaml

# CPU profiling
kubectl exec -it profile-app -- perf top
kubectl exec -it profile-app -- top -H

# Memory profiling
kubectl exec -it profile-app -- pmap $(pgrep app)
kubectl exec -it profile-app -- valgrind --tool=massif ./app

# Network profiling
kubectl exec -it profile-app -- iftop
kubectl exec -it profile-app -- ss -tuln
```

## Troubleshooting Cheat Sheet

### Quick Diagnosis Commands
```bash
# Pod issues
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Service issues
kubectl get svc,endpoints
kubectl describe service <service-name>

# Node issues
kubectl get nodes
kubectl describe node <node-name>
kubectl top nodes

# Resource issues
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
kubectl describe quota --all-namespaces

# Network issues
kubectl exec -it <pod> -- nslookup <service>
kubectl exec -it <pod> -- ping <target>
kubectl get networkpolicy

# Storage issues
kubectl get pv,pvc
kubectl describe pvc <pvc-name>

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector involvedObject.name=<resource>
```

### Emergency Commands
```bash
# Force delete stuck pod
kubectl delete pod <pod-name> --force --grace-period=0

# Restart deployment
kubectl rollout restart deployment <deployment-name>

# Scale down/up
kubectl scale deployment <deployment-name> --replicas=0
kubectl scale deployment <deployment-name> --replicas=3

# Drain node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Emergency rollback
kubectl rollout undo deployment <deployment-name>

# Cordon node
kubectl cordon <node-name>
```

## Best Practices Checklist

### Before Troubleshooting:
- [ ] Gather all relevant information
- [ ] Check recent changes
- [ ] Review monitoring dashboards
- [ ] Check system-wide health
- [ ] Document current state

### During Troubleshooting:
- [ ] Follow systematic approach
- [ ] Test one hypothesis at a time
- [ ] Document all steps taken
- [ ] Communicate with stakeholders
- [ ] Consider impact of changes

### After Resolution:
- [ ] Verify fix completely
- [ ] Update documentation
- [ ] Share learnings with team
- [ ] Implement prevention measures
- [ ] Schedule follow-up review

### Tools to Master:
- [ ] kubectl (describe, logs, exec, events)
- [ ] Debug containers and tools
- [ ] Monitoring dashboards
- [ ] Log aggregation systems
- [ ] Network debugging tools
- [ ] Performance profiling tools