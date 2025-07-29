# 05. Deployment & Release - GitOps, Helm, CI/CD

## Mục tiêu
- Thành thạo deployment strategies
- Triển khai GitOps với Argo CD
- Quản lý packages với Helm
- Xây dựng CI/CD pipeline hoàn chỉnh

## Deployment Strategies

### Rolling Update Deep Dive
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # Tối đa 25% pods mới
    maxUnavailable: 25%  # Tối đa 25% pods unavailable
    progressDeadlineSeconds: 600  # Timeout cho deployment
```

### Blue-Green Deployment
```bash
# Deploy Blue version
kubectl apply -f app-blue.yaml

# Switch traffic to Green
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback if needed
kubectl patch service myapp -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Canary Deployment với Argo Rollouts
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10    # 10% traffic to canary
      - pause: {duration: 30s}
      - setWeight: 50    # 50% traffic to canary
      - pause: {duration: 30s}
      - setWeight: 100   # 100% traffic to canary
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:v2
```

## Helm - Package Manager

### Chart Structure
```
mychart/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── templates/          # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── _helpers.tpl    # Template helpers
├── charts/             # Dependencies
└── .helmignore        # Files to ignore
```

### Hands-on: Creating Custom Chart
```bash
# Create new chart
helm create myapp

# Customize values.yaml
helm template myapp ./myapp --values custom-values.yaml

# Install chart
helm install myapp-release ./myapp

# Upgrade chart
helm upgrade myapp-release ./myapp --set image.tag=v2

# Rollback
helm rollback myapp-release 1
```

### Advanced Helm Patterns
```yaml
# values.yaml
environments:
  dev:
    replicas: 1
    resources:
      requests:
        memory: "128Mi"
  prod:
    replicas: 3
    resources:
      requests:
        memory: "512Mi"

# deployment.yaml template
{{- $env := .Values.environments.dev }}
{{- if eq .Values.environment "prod" }}
{{- $env = .Values.environments.prod }}
{{- end }}

replicas: {{ $env.replicas }}
```

## GitOps với Argo CD

### Installation
```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Application Configuration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-config
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### ApplicationSet for Multi-Environment
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-environments
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev-cluster
        namespace: myapp-dev
      - cluster: staging
        url: https://staging-cluster
        namespace: myapp-staging
      - cluster: prod
        url: https://prod-cluster
        namespace: myapp-prod
  template:
    metadata:
      name: 'myapp-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/myapp-config
        targetRevision: HEAD
        path: 'environments/{{cluster}}'
      destination:
        server: '{{url}}'
        namespace: '{{namespace}}'
```

## Kustomize - Configuration Management

### Base và Overlays
```
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── dev-patches.yaml
    └── prod/
        ├── kustomization.yaml
        └── prod-patches.yaml
```

### Hands-on: Multi-Environment Config
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml

# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
patchesStrategicMerge:
- prod-patches.yaml
images:
- name: myapp
  newTag: v1.2.3
replicas:
- name: myapp
  count: 5
```

## CI/CD Pipeline End-to-End

### GitHub Actions Workflow
```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run tests
      run: |
        docker build -t myapp:test .
        docker run --rm myapp:test npm test

  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'myapp:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-results.sarif'

  build-and-push:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Build and push Docker image
      run: |
        docker build -t myregistry/myapp:${{ github.sha }} .
        docker push myregistry/myapp:${{ github.sha }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
    - name: Update Helm chart
      run: |
        git clone https://github.com/myorg/myapp-config
        cd myapp-config
        yq e '.image.tag = "${{ github.sha }}"' -i values.yaml
        git commit -am "Update image to ${{ github.sha }}"
        git push
```

## Advanced Deployment Patterns

### Feature Flags với ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  features.json: |
    {
      "newFeature": true,
      "betaFeature": false,
      "experimentalFeature": false
    }
```

### A/B Testing với Istio
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ab-test
spec:
  http:
  - match:
    - headers:
        user-type:
          exact: premium
    route:
    - destination:
        host: myapp
        subset: v2
      weight: 100
  - route:
    - destination:
        host: myapp
        subset: v1
      weight: 90
    - destination:
        host: myapp
        subset: v2
      weight: 10
```

## Monitoring Deployments

### Deployment Metrics
```yaml
# ServiceMonitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-metrics
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Alerting Rules
```yaml
groups:
- name: deployment.rules
  rules:
  - alert: DeploymentReplicasMismatch
    expr: kube_deployment_status_replicas != kube_deployment_spec_replicas
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Deployment {{ $labels.deployment }} has mismatched replicas"

  - alert: DeploymentRolloutStuck
    expr: kube_deployment_status_condition{condition="Progressing",status="false"} == 1
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "Deployment {{ $labels.deployment }} rollout is stuck"
```

## Best Practices

### Deployment Safety
1. **Health checks**: Always configure liveness/readiness probes
2. **Resource limits**: Set appropriate requests/limits
3. **Graceful shutdown**: Handle SIGTERM properly
4. **Rolling update**: Configure maxSurge/maxUnavailable
5. **Rollback plan**: Always have rollback strategy

### GitOps Principles
1. **Declarative**: Everything as code
2. **Versioned**: Git as single source of truth
3. **Immutable**: Don't modify running systems
4. **Pulled**: System pulls desired state
5. **Continuously reconciled**: Detect and correct drift

### Security in CI/CD
1. **Image scanning**: Scan for vulnerabilities
2. **Signed images**: Use cosign for image signing
3. **RBAC**: Limit deployment permissions
4. **Secrets management**: Use external secret stores
5. **Supply chain**: Verify build provenance

## Troubleshooting

### Deployment Issues
```bash
# Check deployment status
kubectl rollout status deployment/myapp
kubectl describe deployment myapp

# Check replica sets
kubectl get rs -l app=myapp
kubectl describe rs myapp-xxx

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Argo CD Issues
```bash
# Check application status
argocd app get myapp
argocd app sync myapp --force

# Check sync status
kubectl get applications -n argocd
kubectl describe application myapp -n argocd
```

## Câu hỏi suy ngẫm
1. Khi nào nên dùng Blue-Green vs Canary deployment?
2. GitOps có lợi ích gì so với push-based deployment?
3. Làm thế nào để rollback an toàn trong production?
4. Tại sao cần separate config repository?

## Tiếp theo
Chuyển sang [06. Security](../06-security/) để học về RBAC, Pod Security, Network Security.