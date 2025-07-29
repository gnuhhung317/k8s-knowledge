# 06. Security - RBAC, Pod Security, Network Security

## Mục tiêu
- Implement comprehensive RBAC strategy
- Secure pods với Pod Security Standards
- Network micro-segmentation với NetworkPolicy
- Image security và supply chain protection

## RBAC (Role-Based Access Control)

### Core Components
- **User/ServiceAccount**: Who (identity)
- **Role/ClusterRole**: What (permissions)
- **RoleBinding/ClusterRoleBinding**: Who can do What

### Hands-on: RBAC Implementation
```bash
# Create service account
kubectl create serviceaccount developer

# Create role
kubectl apply -f developer-role.yaml

# Create role binding
kubectl apply -f developer-rolebinding.yaml

# Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:developer
kubectl auth can-i delete pods --as=system:serviceaccount:default:developer
```

### Advanced RBAC Patterns
```yaml
# Namespace-specific developer role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]

# Read-only cluster role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-reader
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

## Pod Security Standards

### Security Levels
1. **Privileged**: Unrestricted (default)
2. **Baseline**: Minimally restrictive
3. **Restricted**: Heavily restricted (recommended)

### Pod Security Standards Implementation
```yaml
# Namespace with Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: secure-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Hands-on: Secure Pod Configuration
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: var-cache
      mountPath: /var/cache/nginx
    - name: var-run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: var-cache
    emptyDir: {}
  - name: var-run
    emptyDir: {}
```

## Policy Engines

### OPA Gatekeeper
```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Create constraint template
kubectl apply -f required-labels-template.yaml

# Create constraint
kubectl apply -f required-labels-constraint.yaml
```

### Kyverno Policies
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-pod-resources
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-resources
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Resource requests and limits are required"
      pattern:
        spec:
          containers:
          - name: "*"
            resources:
              requests:
                memory: "?*"
                cpu: "?*"
              limits:
                memory: "?*"
                cpu: "?*"
```

## Network Security

### NetworkPolicy Patterns
```yaml
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

# Allow specific communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: loadbalancer
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 8080
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
```

### Hands-on: Multi-tier Network Security
```bash
# Deploy 3-tier application
kubectl apply -f 3tier-secure-app.yaml

# Apply network policies
kubectl apply -f network-policies/

# Test connectivity
kubectl exec -it frontend-pod -- curl backend-service:8080
kubectl exec -it frontend-pod -- curl database-service:5432  # Should fail

# Monitor denied traffic (with Cilium)
hubble observe --verdict DROPPED
```

## Image Security

### Image Scanning với Trivy
```bash
# Scan local image
trivy image nginx:1.21

# Scan in CI/CD
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest

# Generate SARIF report
trivy image --format sarif --output results.sarif myapp:latest
```

### Image Signing với Cosign
```bash
# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myregistry/myapp:v1.0.0

# Verify signature
cosign verify --key cosign.pub myregistry/myapp:v1.0.0
```

### Admission Controller for Image Policy
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: enforce
  background: false
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry/*"
      attestors:
      - entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
              -----END PUBLIC KEY-----
```

## Secrets Management

### External Secrets Operator
```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Configure AWS Secrets Manager
kubectl apply -f aws-secret-store.yaml

# Create external secret
kubectl apply -f external-secret.yaml
```

### Sealed Secrets
```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal -o yaml > mysealedsecret.yaml

# Apply sealed secret
kubectl apply -f mysealedsecret.yaml
```

## Security Monitoring

### Falco - Runtime Security
```bash
# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco --set falco.grpc.enabled=true

# Custom rules
kubectl apply -f falco-custom-rules.yaml

# Monitor alerts
kubectl logs -f -n falco -l app.kubernetes.io/name=falco
```

### Security Benchmarks
```bash
# Run CIS Kubernetes Benchmark
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench

# Run kube-hunter
kubectl create -f https://raw.githubusercontent.com/aquasecurity/kube-hunter/main/job.yaml
kubectl logs job/kube-hunter
```

## Hands-on Security Labs

### Lab 1: Complete RBAC Setup
1. Create multiple service accounts (developer, operator, viewer)
2. Define appropriate roles for each
3. Test permissions with `kubectl auth can-i`
4. Implement namespace isolation

### Lab 2: Pod Security Hardening
1. Deploy insecure pod
2. Apply Pod Security Standards
3. Fix security violations
4. Verify with security scanner

### Lab 3: Network Micro-segmentation
1. Deploy multi-tier application
2. Implement default-deny policies
3. Create specific allow rules
4. Test and monitor traffic

### Lab 4: Supply Chain Security
1. Set up image scanning in CI
2. Implement image signing
3. Create admission policies
4. Test with malicious image

## Security Best Practices

### Defense in Depth
1. **Identity**: Strong authentication/authorization
2. **Network**: Micro-segmentation with NetworkPolicy
3. **Compute**: Secure pod configuration
4. **Storage**: Encrypted volumes and secrets
5. **Application**: Secure coding practices

### Compliance Frameworks
1. **CIS Kubernetes Benchmark**: Security configuration
2. **NIST Cybersecurity Framework**: Risk management
3. **SOC 2**: Security controls
4. **PCI DSS**: Payment card security

### Security Automation
1. **Policy as Code**: Automated policy enforcement
2. **Continuous Scanning**: Regular vulnerability assessment
3. **Incident Response**: Automated threat detection
4. **Compliance Monitoring**: Continuous compliance checking

## Troubleshooting Security Issues

### RBAC Problems
```bash
# Debug RBAC
kubectl auth can-i --list --as=system:serviceaccount:default:mysa
kubectl describe rolebinding,clusterrolebinding --all-namespaces | grep mysa

# Check service account
kubectl get serviceaccount mysa -o yaml
kubectl describe secret mysa-token-xxx
```

### Pod Security Issues
```bash
# Check pod security violations
kubectl describe pod mypod
kubectl get events --field-selector involvedObject.name=mypod

# Test pod security standards
kubectl label namespace default pod-security.kubernetes.io/warn=restricted
```

## Câu hỏi suy ngẫm
1. Tại sao cần principle of least privilege?
2. NetworkPolicy có thay thế được Service Mesh security không?
3. Làm thế nào để balance security và usability?
4. Runtime security monitoring quan trọng như thế nào?

## Tiếp theo
Chuyển sang [07. Observability](../07-observability/) để học về Monitoring, Logging, Tracing.