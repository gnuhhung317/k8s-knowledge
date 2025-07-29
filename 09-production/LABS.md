# Production Labs - Thực hành Triển khai Production

## Lab 1: High Availability Cluster Setup

### Bước 1: Multi-Zone Cluster Configuration
```bash
# Create production cluster with multiple zones
gcloud container clusters create production-cluster \
  --zone=us-central1-a \
  --additional-zones=us-central1-b,us-central1-c \
  --num-nodes=2 \
  --machine-type=e2-standard-4 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10 \
  --enable-autorepair \
  --enable-autoupgrade

# Or using kind for local testing
kubectl apply -f cluster-setup/multi-node-cluster.yaml
```

### Bước 2: Node Pool Configuration
```bash
# Create system node pool
gcloud container node-pools create system-pool \
  --cluster=production-cluster \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --num-nodes=1 \
  --node-taints=CriticalAddonsOnly=true:NoSchedule

# Create application node pool
gcloud container node-pools create app-pool \
  --cluster=production-cluster \
  --zone=us-central1-a \
  --machine-type=e2-standard-4 \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=20

# Apply node pool configurations
kubectl apply -f cluster-setup/node-pools.yaml
```

### Bước 3: Verify High Availability
```bash
# Check node distribution
kubectl get nodes -o wide

# Check zone distribution
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone

# Test node failure simulation
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## Lab 2: Security Hardening

### Bước 1: Pod Security Standards
```bash
# Create production namespace with security standards
kubectl apply -f security/production-namespace.yaml

# Test pod security enforcement
kubectl apply -f security/secure-pod.yaml      # Should succeed
kubectl apply -f security/insecure-pod.yaml    # Should fail
```

### Bước 2: RBAC Implementation
```bash
# Create production RBAC
kubectl apply -f security/production-rbac.yaml

# Test RBAC permissions
kubectl auth can-i get pods --as=system:serviceaccount:production:developer
kubectl auth can-i delete deployments --as=system:serviceaccount:production:developer

# Create service account token
kubectl apply -f security/service-account-token.yaml
```

### Bước 3: Network Policies
```bash
# Apply default deny policy
kubectl apply -f security/default-deny-networkpolicy.yaml

# Apply application-specific policies
kubectl apply -f security/production-networkpolicies.yaml

# Test network connectivity
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# Try to connect to different services
```

### Bước 4: Image Security
```bash
# Scan images for vulnerabilities
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest

# Create image policy
kubectl apply -f security/image-policy.yaml

# Test image policy enforcement
kubectl apply -f security/test-image-policy.yaml
```

## Lab 3: Resource Management

### Bước 1: Resource Quotas và Limits
```bash
# Apply resource quotas
kubectl apply -f resources/production-quota.yaml

# Apply limit ranges
kubectl apply -f resources/production-limits.yaml

# Test resource enforcement
kubectl apply -f resources/test-resource-limits.yaml
```

### Bước 2: Priority Classes
```bash
# Create priority classes
kubectl apply -f resources/priority-classes.yaml

# Deploy applications with priorities
kubectl apply -f resources/critical-app.yaml
kubectl apply -f resources/normal-app.yaml

# Test priority scheduling
kubectl get pods -o wide --sort-by=.spec.priority
```

### Bước 3: Pod Disruption Budgets
```bash
# Create PodDisruptionBudgets
kubectl apply -f resources/pod-disruption-budgets.yaml

# Test disruption scenarios
kubectl drain <node-name> --ignore-daemonsets
```

## Lab 4: Autoscaling Configuration

### Bước 1: Horizontal Pod Autoscaler
```bash
# Install metrics server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Deploy application with HPA
kubectl apply -f autoscaling/hpa-demo.yaml

# Generate load to test scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# while true; do wget -q -O- http://hpa-demo-service; done

# Watch HPA scaling
kubectl get hpa -w
```

### Bước 2: Vertical Pod Autoscaler
```bash
# Install VPA
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
./hack/vpa-install.sh

# Deploy VPA example
kubectl apply -f autoscaling/vpa-demo.yaml

# Check VPA recommendations
kubectl describe vpa vpa-demo
```

### Bước 3: Cluster Autoscaler
```bash
# Deploy cluster autoscaler
kubectl apply -f autoscaling/cluster-autoscaler.yaml

# Create workload to trigger node scaling
kubectl apply -f autoscaling/scale-test-workload.yaml

# Monitor cluster scaling
kubectl get nodes -w
kubectl logs -n kube-system deployment/cluster-autoscaler
```

## Lab 5: Backup và Disaster Recovery

### Bước 1: Velero Backup Setup
```bash
# Install Velero
wget https://github.com/vmware-tanzu/velero/releases/latest/download/velero-linux-amd64.tar.gz
tar -xvf velero-linux-amd64.tar.gz
sudo mv velero-linux-amd64/velero /usr/local/bin/

# Configure backup storage
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.5.0 \
  --bucket velero-backups \
  --secret-file ./credentials-velero

# Create backup schedule
kubectl apply -f backup/velero-schedule.yaml
```

### Bước 2: ETCD Backup
```bash
# Create ETCD backup script
kubectl apply -f backup/etcd-backup-cronjob.yaml

# Manual ETCD backup
kubectl exec -n kube-system etcd-master -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  snapshot save /tmp/etcd-backup.db
```

### Bước 3: Disaster Recovery Testing
```bash
# Create test application
kubectl apply -f backup/test-application.yaml

# Create backup
velero backup create test-backup --include-namespaces test-app

# Simulate disaster (delete namespace)
kubectl delete namespace test-app

# Restore from backup
velero restore create --from-backup test-backup

# Verify restoration
kubectl get pods -n test-app
```

## Lab 6: Monitoring và Alerting

### Bước 1: Production Monitoring Stack
```bash
# Deploy Prometheus for production
kubectl apply -f monitoring/prometheus-production.yaml

# Deploy Grafana with persistence
kubectl apply -f monitoring/grafana-production.yaml

# Deploy Alertmanager
kubectl apply -f monitoring/alertmanager-production.yaml
```

### Bước 2: SLI/SLO Implementation
```bash
# Deploy SLI recording rules
kubectl apply -f monitoring/sli-recording-rules.yaml

# Deploy SLO alerting rules
kubectl apply -f monitoring/slo-alerting-rules.yaml

# Create SLO dashboards
kubectl apply -f monitoring/slo-dashboards.yaml
```

### Bước 3: Production Alerts
```bash
# Apply critical production alerts
kubectl apply -f monitoring/production-alerts.yaml

# Test alert firing
kubectl apply -f monitoring/alert-test-scenarios.yaml

# Configure notification channels
kubectl apply -f monitoring/notification-config.yaml
```

## Lab 7: Performance Optimization

### Bước 1: Resource Right-sizing
```bash
# Deploy VPA for recommendations
kubectl apply -f optimization/vpa-recommendations.yaml

# Analyze resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Apply optimized resource settings
kubectl apply -f optimization/optimized-deployments.yaml
```

### Bước 2: Node Optimization
```bash
# Configure node affinity
kubectl apply -f optimization/node-affinity-examples.yaml

# Configure pod anti-affinity
kubectl apply -f optimization/pod-anti-affinity.yaml

# Test placement strategies
kubectl get pods -o wide
```

### Bước 3: Cost Optimization
```bash
# Deploy spot instance workloads
kubectl apply -f optimization/spot-instance-workloads.yaml

# Configure resource scheduling
kubectl apply -f optimization/resource-scheduling.yaml

# Monitor cost allocation
kubectl apply -f optimization/cost-monitoring.yaml
```

## Lab 8: Incident Response

### Bước 1: Incident Simulation
```bash
# Simulate high CPU usage
kubectl apply -f incidents/cpu-stress-test.yaml

# Simulate memory leak
kubectl apply -f incidents/memory-leak-test.yaml

# Simulate network issues
kubectl apply -f incidents/network-chaos.yaml
```

### Bước 2: Debugging Tools
```bash
# Deploy debugging tools
kubectl apply -f debugging/debug-toolkit.yaml

# Use kubectl debug
kubectl debug -it pod/problematic-pod --image=busybox --target=app

# Analyze with crictl
crictl ps
crictl logs <container-id>
crictl inspect <container-id>
```

### Bước 3: Emergency Procedures
```bash
# Emergency scale down
kubectl scale deployment production-app --replicas=0

# Emergency rollback
kubectl rollout undo deployment/production-app

# Emergency maintenance mode
kubectl patch service production-service -p '{"spec":{"selector":{}}}'

# Cordon nodes
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

## Lab 9: Compliance và Governance

### Bước 1: Policy as Code
```bash
# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Apply production policies
kubectl apply -f governance/production-policies.yaml

# Test policy enforcement
kubectl apply -f governance/policy-test-cases.yaml
```

### Bước 2: Audit Logging
```bash
# Configure audit policy
kubectl apply -f governance/audit-policy.yaml

# Enable audit logging (cluster configuration)
# Add to kube-apiserver:
# --audit-log-path=/var/log/audit.log
# --audit-policy-file=/etc/kubernetes/audit-policy.yaml

# Analyze audit logs
kubectl logs -n kube-system kube-apiserver-master | grep audit
```

### Bước 3: Compliance Reporting
```bash
# Run compliance scans
kubectl apply -f governance/compliance-scanner.yaml

# Generate compliance reports
kubectl apply -f governance/compliance-reports.yaml

# Review compliance status
kubectl get compliance-reports -o yaml
```

## Troubleshooting Commands

### Cluster Health
```bash
# Check cluster status
kubectl cluster-info
kubectl get componentstatuses

# Check node health
kubectl describe nodes
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Application Debugging
```bash
# Check pod status
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Check service connectivity
kubectl get endpoints
kubectl describe service <service-name>

# Network debugging
kubectl exec -it <pod-name> -- nslookup <service-name>
kubectl exec -it <pod-name> -- wget -qO- <service-url>
```

### Performance Analysis
```bash
# Resource utilization
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory

# HPA status
kubectl get hpa
kubectl describe hpa <hpa-name>

# VPA recommendations
kubectl describe vpa <vpa-name>
```

## Best Practices Checklist

### High Availability:
- [ ] Multi-zone cluster deployment
- [ ] Redundant control plane
- [ ] Pod disruption budgets
- [ ] Health checks configured
- [ ] Load balancer redundancy

### Security:
- [ ] Pod Security Standards enforced
- [ ] RBAC with least privilege
- [ ] Network policies implemented
- [ ] Image vulnerability scanning
- [ ] Secrets externally managed

### Performance:
- [ ] Resource requests/limits set
- [ ] Autoscaling configured
- [ ] Node affinity optimized
- [ ] Performance monitoring
- [ ] Cost optimization enabled

### Operations:
- [ ] Comprehensive monitoring
- [ ] Alerting rules configured
- [ ] Backup procedures tested
- [ ] Incident response plan
- [ ] Documentation updated

### Compliance:
- [ ] Policies as code
- [ ] Audit logging enabled
- [ ] Compliance scanning
- [ ] Regular reviews
- [ ] Evidence collection