# 08. Advanced Topics - Service Mesh, GitOps, Advanced Patterns

## Mục tiêu
- Implement Service Mesh với Istio
- GitOps workflow với ArgoCD
- Advanced deployment patterns
- Custom Resource Definitions (CRDs)
- Operators và Controllers

## Service Mesh với Istio

### Tại sao cần Service Mesh?
Khi microservices scale lên, chúng ta cần:
- **Traffic Management**: Load balancing, routing, failover
- **Security**: mTLS, authentication, authorization
- **Observability**: Metrics, logs, traces tự động
- **Policy Enforcement**: Rate limiting, circuit breaker

### Istio Architecture
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Istiod    │    │   Envoy     │    │   Envoy     │
│ (Control    │◄──▶│  Sidecar    │◄──▶│  Sidecar    │
│  Plane)     │    │ (Service A) │    │ (Service B) │
└─────────────┘    └─────────────┘    └─────────────┘
```

### Core Components:
- **Istiod**: Control plane (Pilot, Citadel, Galley)
- **Envoy Proxy**: Data plane sidecar
- **Istio Gateway**: Ingress/Egress traffic
- **Virtual Service**: Traffic routing rules
- **Destination Rule**: Load balancing, circuit breaker

## GitOps với ArgoCD

### GitOps Principles:
1. **Declarative**: Everything as code
2. **Versioned**: Git as single source of truth
3. **Pulled**: Automated deployment from Git
4. **Monitored**: Continuous reconciliation

### GitOps Workflow:
```
Developer → Git Push → ArgoCD → Kubernetes Cluster
    │                     │              │
    └── Code Review ──────┴── Sync ──────┘
```

### ArgoCD Benefits:
- **Automated Deployment**: Git-driven deployments
- **Drift Detection**: Cluster vs Git comparison
- **Rollback**: Easy revert to previous versions
- **Multi-cluster**: Manage multiple clusters
- **RBAC**: Fine-grained access control

## Advanced Deployment Patterns

### 1. Blue-Green Deployment
```yaml
# Blue (current) và Green (new) environments
# Switch traffic instantly
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: active-service
      previewService: preview-service
```

### 2. Canary Deployment
```yaml
# Gradual traffic shift: 10% → 50% → 100%
spec:
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 10m}
```

### 3. A/B Testing
```yaml
# Traffic split based on headers/cookies
spec:
  strategy:
    canary:
      trafficRouting:
        istio:
          virtualService:
            routes:
            - match:
              - headers:
                  user-type:
                    exact: premium
```

## Custom Resource Definitions (CRDs)

### Extending Kubernetes API:
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              size:
                type: string
              version:
                type: string
```

## Kubernetes Operators

### Operator Pattern:
```
Custom Resource → Controller → Reconciliation Loop
       │               │              │
       └── Desired ────┴── Observe ───┘
           State           Current
                          State
```

### Popular Operators:
- **Prometheus Operator**: Monitoring stack
- **Cert-Manager**: SSL certificate management
- **Velero**: Backup và restore
- **Strimzi**: Apache Kafka
- **PostgreSQL Operator**: Database management

## Hands-on Labs

### Lab 1: Istio Service Mesh
```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
istioctl install --set values.defaultRevision=default

# Enable sidecar injection
kubectl label namespace default istio-injection=enabled

# Deploy sample application
kubectl apply -f istio/bookinfo-app.yaml
kubectl apply -f istio/bookinfo-gateway.yaml
```

### Lab 2: ArgoCD GitOps
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Create application
kubectl apply -f argocd/sample-app.yaml
```

### Lab 3: Advanced Deployments
```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Deploy canary rollout
kubectl apply -f rollouts/canary-rollout.yaml
```

## Multi-cluster Management

### Cluster API (CAPI):
```yaml
# Declarative cluster management
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: production-cluster
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["192.168.0.0/16"]
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: AWSCluster
    name: production-cluster
```

### Fleet Management:
- **Rancher**: Multi-cluster management UI
- **Admiral**: Multi-cluster service mesh
- **Submariner**: Cross-cluster networking

## Policy as Code

### Open Policy Agent (OPA):
```rego
# Gatekeeper policy example
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  input.request.object.spec.containers[_].image
  not starts_with(input.request.object.spec.containers[_].image, "registry.company.com/")
  msg := "Images must come from company registry"
}
```

### Kyverno Policies:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-team-label
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Team label is required"
      pattern:
        metadata:
          labels:
            team: "?*"
```

## Performance Optimization

### Resource Management:
- **Vertical Pod Autoscaler (VPA)**: Right-size containers
- **Horizontal Pod Autoscaler (HPA)**: Scale replicas
- **Cluster Autoscaler**: Scale nodes
- **KEDA**: Event-driven autoscaling

### Cost Optimization:
- **Spot Instances**: Use cheaper compute
- **Resource Quotas**: Prevent resource waste
- **PodDisruptionBudgets**: Graceful scaling
- **Node Affinity**: Optimize placement

## Disaster Recovery

### Backup Strategies:
```yaml
# Velero backup
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: daily-backup
spec:
  includedNamespaces:
  - production
  schedule: "0 2 * * *"
  ttl: 720h0m0s
```

### Multi-region Setup:
- **Cross-region replication**
- **DNS failover**
- **Data synchronization**
- **Automated failover**

## Security Hardening

### Advanced Security:
- **Pod Security Standards**: Enforce security policies
- **Network Policies**: Micro-segmentation
- **Service Mesh Security**: mTLS, RBAC
- **Image Scanning**: Vulnerability assessment
- **Runtime Security**: Falco, Sysdig

## Next Steps

Sau khi hoàn thành advanced topics:
1. **[09. Production](../09-production/)** - Production-ready deployments
2. **[10. Troubleshooting](../10-troubleshooting/)** - Common issues và solutions

## Quick Commands

```bash
# Istio
istioctl proxy-status
istioctl analyze

# ArgoCD
argocd app list
argocd app sync myapp

# Argo Rollouts
kubectl argo rollouts get rollout myapp
kubectl argo rollouts promote myapp

# CRDs
kubectl get crd
kubectl describe crd databases.example.com

# Multi-cluster
kubectl config get-contexts
kubectl config use-context production
```