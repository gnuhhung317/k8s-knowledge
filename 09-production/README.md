# 09. Production - Production-Ready Kubernetes

## Mục tiêu
- Production-ready cluster setup
- High Availability và Disaster Recovery
- Security hardening và compliance
- Performance optimization và cost management
- Monitoring, alerting và incident response

## Production Readiness Checklist

### 🏗️ Infrastructure & Architecture
- [ ] Multi-zone/Multi-region cluster setup
- [ ] High Availability control plane (3+ masters)
- [ ] Dedicated node pools cho workload types
- [ ] Network segmentation và security groups
- [ ] Load balancer configuration
- [ ] DNS và certificate management

### 🔒 Security Hardening
- [ ] RBAC với least privilege principle
- [ ] Pod Security Standards enforcement
- [ ] Network policies implementation
- [ ] Image vulnerability scanning
- [ ] Secrets management với external providers
- [ ] Audit logging enabled
- [ ] Regular security assessments

### 📊 Observability & Monitoring
- [ ] Comprehensive metrics collection
- [ ] Centralized logging
- [ ] Distributed tracing
- [ ] SLI/SLO definitions
- [ ] Alerting rules và runbooks
- [ ] Dashboard hierarchy
- [ ] On-call procedures

### 🚀 Deployment & Operations
- [ ] GitOps workflow implementation
- [ ] Blue-green/Canary deployment strategies
- [ ] Automated testing pipelines
- [ ] Resource quotas và limits
- [ ] PodDisruptionBudgets
- [ ] Backup và restore procedures
- [ ] Disaster recovery plan

## High Availability Architecture

### Multi-Zone Cluster Setup
```
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer                        │
└─────────────────┬───────────────┬───────────────────────┘
                  │               │
    ┌─────────────▼─────────────┐ │ ┌─────────────────────┐
    │         Zone A            │ │ │       Zone B        │
    │ ┌─────────┐ ┌───────────┐ │ │ │ ┌─────────────────┐ │
    │ │Master 1 │ │Worker 1-3 │ │ │ │ │   Worker 4-6    │ │
    │ └─────────┘ └───────────┘ │ │ │ └─────────────────┘ │
    └───────────────────────────┘ │ └─────────────────────┘
                                  │
                ┌─────────────────▼─────────────────┐
                │              Zone C               │
                │ ┌─────────┐ ┌─────────────────────┐ │
                │ │Master 2 │ │    Worker 7-9       │ │
                │ │Master 3 │ │                     │ │
                │ └─────────┘ └─────────────────────┘ │
                └───────────────────────────────────┘
```

### Node Pool Strategy
```yaml
# System node pool - for system components
system-pool:
  node_count: 3
  machine_type: e2-standard-2
  taints:
    - key: CriticalAddonsOnly
      value: "true"
      effect: NoSchedule

# Application node pool - for user workloads
app-pool:
  node_count: 6
  machine_type: e2-standard-4
  auto_scaling:
    min_nodes: 3
    max_nodes: 20

# GPU node pool - for ML workloads
gpu-pool:
  node_count: 0
  machine_type: n1-standard-4
  accelerator:
    type: nvidia-tesla-k80
    count: 1
  auto_scaling:
    min_nodes: 0
    max_nodes: 5
```

## Security Best Practices

### 1. Pod Security Standards
```yaml
# Enforce restricted security standard
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 2. Network Policies
```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 3. RBAC Strategy
```yaml
# Production RBAC hierarchy
Cluster Admin (Break Glass)
├── Platform Team (Cluster-wide)
├── SRE Team (Monitoring + Debugging)
├── Security Team (Policies + Auditing)
└── Development Teams (Namespace-scoped)
```

## Resource Management

### 1. Resource Quotas
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    persistentvolumeclaims: "50"
    services.loadbalancers: "5"
```

### 2. Limit Ranges
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
```

### 3. Priority Classes
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-priority
value: 1000
globalDefault: false
description: "Critical system components"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 500
description: "High priority applications"
```

## Backup & Disaster Recovery

### 1. Backup Strategy
```yaml
# Velero backup schedule
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - production
    - staging
    excludedResources:
    - events
    - events.events.k8s.io
    ttl: 720h0m0s
```

### 2. ETCD Backup
```bash
# Automated ETCD backup script
#!/bin/bash
ETCDCTL_API=3 etcdctl snapshot save backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

## Performance Optimization

### 1. Autoscaling Configuration
```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: production-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  minReplicas: 3
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 2. Cluster Autoscaler
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=gce
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=mig:name=gke-cluster-default-pool
```

## Monitoring & Alerting

### 1. SLI/SLO Definition
```yaml
# Service Level Indicators
slis:
  availability:
    description: "Percentage of successful requests"
    query: "rate(http_requests_total{status!~'5..'}[5m]) / rate(http_requests_total[5m])"
  latency:
    description: "95th percentile response time"
    query: "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
  error_rate:
    description: "Percentage of error requests"
    query: "rate(http_requests_total{status=~'5..'}[5m]) / rate(http_requests_total[5m])"

# Service Level Objectives
slos:
  availability: 99.9%
  latency: 200ms
  error_rate: 0.1%
```

### 2. Critical Alerts
```yaml
groups:
- name: production.rules
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      
  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
    for: 10m
    labels:
      severity: warning
```

## Cost Optimization

### 1. Resource Right-sizing
```yaml
# Vertical Pod Autoscaler
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: production-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      maxAllowed:
        cpu: 2
        memory: 4Gi
```

### 2. Spot Instance Strategy
```yaml
# Node pool with spot instances
spot-pool:
  node_count: 10
  machine_type: e2-standard-4
  preemptible: true
  taints:
    - key: spot-instance
      value: "true"
      effect: NoSchedule
  tolerations:
    - key: spot-instance
      operator: Equal
      value: "true"
      effect: NoSchedule
```

## Compliance & Governance

### 1. Policy as Code
```yaml
# OPA Gatekeeper policy
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: production-standards
spec:
  validationFailureAction: enforce
  rules:
  - name: require-resource-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Resource limits are required"
      pattern:
        spec:
          containers:
          - name: "*"
            resources:
              limits:
                memory: "?*"
                cpu: "?*"
```

### 2. Audit Logging
```yaml
# Audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Request
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

## Incident Response

### 1. Runbook Template
```markdown
# Incident Response Runbook

## High CPU Usage
1. Check HPA scaling
2. Verify resource limits
3. Check for resource leaks
4. Scale manually if needed

## Pod Crash Loop
1. Check pod logs
2. Verify resource limits
3. Check liveness/readiness probes
4. Review recent deployments

## Network Issues
1. Check NetworkPolicies
2. Verify DNS resolution
3. Test service connectivity
4. Check ingress configuration
```

### 2. Emergency Procedures
```bash
# Emergency scale down
kubectl scale deployment production-app --replicas=0

# Emergency rollback
kubectl rollout undo deployment/production-app

# Emergency maintenance mode
kubectl patch ingress production-ingress -p '{"spec":{"rules":[]}}'
```

## Next Steps

Sau khi hoàn thành production setup:
1. **[10. Troubleshooting](../10-troubleshooting/)** - Common issues và solutions
2. **Continuous Improvement** - Regular reviews và optimizations

## Quick Commands

```bash
# Health checks
kubectl get nodes
kubectl get pods --all-namespaces
kubectl top nodes
kubectl top pods --all-namespaces

# Security checks
kubectl auth can-i --list
kubectl get networkpolicies --all-namespaces
kubectl get psp

# Resource usage
kubectl describe quota --all-namespaces
kubectl describe limits --all-namespaces

# Backup verification
velero backup get
velero restore get
```