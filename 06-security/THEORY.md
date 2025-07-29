# Security Theory - Lý thuyết Bảo mật Kubernetes

## 1. RBAC (Role-Based Access Control)

### Khái niệm cốt lõi (80/20)
RBAC là hệ thống phân quyền dựa trên vai trò, gồm 3 thành phần chính:

#### 1.1 Identity (Danh tính)
- **User**: Con người sử dụng kubectl
- **ServiceAccount**: Tài khoản cho pods/applications

#### 1.2 Permissions (Quyền hạn)
- **Role**: Quyền trong 1 namespace cụ thể
- **ClusterRole**: Quyền toàn cluster

#### 1.3 Binding (Liên kết)
- **RoleBinding**: Gán Role cho User/ServiceAccount trong namespace
- **ClusterRoleBinding**: Gán ClusterRole cho User/ServiceAccount toàn cluster

### Best Practices RBAC
```yaml
# Principle of Least Privilege
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]  # Chỉ read, không write
```

## 2. Pod Security Standards

### 3 Security Levels
1. **Privileged**: Không hạn chế (legacy workloads)
2. **Baseline**: Ngăn chặn privilege escalation
3. **Restricted**: Hardened security (production recommended)

### Security Context Hierarchy
```
Pod SecurityContext
├── Container SecurityContext (override pod)
├── runAsUser/runAsGroup
├── fsGroup
└── seccompProfile
```

### Key Security Controls
- **runAsNonRoot**: Không chạy root
- **readOnlyRootFilesystem**: Filesystem chỉ đọc
- **allowPrivilegeEscalation**: false
- **capabilities**: Drop ALL, add specific

## 3. Network Security

### NetworkPolicy Model
```
Default: Allow All
├── Deny All (explicit)
├── Allow Specific (whitelist)
└── Ingress + Egress rules
```

### Traffic Flow Control
- **Ingress**: Traffic vào pod
- **Egress**: Traffic ra khỏi pod
- **podSelector**: Chọn pods áp dụng policy
- **namespaceSelector**: Chọn namespace

### Micro-segmentation Pattern
```
Frontend ──→ Backend ──→ Database
   │           │           │
   └── Only HTTP  └── Only DB port
```

## 4. Image Security

### Supply Chain Security
1. **Base Image**: Sử dụng minimal images (alpine, distroless)
2. **Vulnerability Scanning**: Trivy, Clair, Snyk
3. **Image Signing**: Cosign, Notary
4. **Private Registry**: Harbor, ECR, ACR

### Image Security Best Practices
- Scan images trong CI/CD pipeline
- Sử dụng specific tags (không dùng :latest)
- Multi-stage builds để giảm attack surface
- Regular updates và patching

## 5. Secrets Management

### Kubernetes Secrets Limitations
- Base64 encoded (NOT encrypted)
- Stored in etcd
- Accessible to anyone with API access

### External Secret Management
- **HashiCorp Vault**
- **AWS Secrets Manager**
- **Azure Key Vault**
- **External Secrets Operator**

## 6. Admission Controllers

### Built-in Security Controllers
- **PodSecurity**: Enforce Pod Security Standards
- **ResourceQuota**: Limit resource usage
- **LimitRange**: Set default/max resource limits
- **NetworkPolicy**: Network segmentation

### Custom Admission Controllers
- **OPA Gatekeeper**: Policy as Code
- **Kyverno**: YAML-based policies
- **Falco**: Runtime security monitoring

## 7. Runtime Security

### Container Runtime Security
- **Seccomp**: System call filtering
- **AppArmor/SELinux**: Mandatory Access Control
- **Capabilities**: Fine-grained privileges

### Monitoring & Detection
- **Falco**: Behavioral monitoring
- **Sysdig**: Container security platform
- **Aqua Security**: Full-stack security

## 8. Security Scanning & Compliance

### Vulnerability Assessment
```bash
# Image scanning
trivy image nginx:latest

# Cluster scanning
kube-bench  # CIS Kubernetes Benchmark
kube-hunter # Penetration testing
```

### Compliance Frameworks
- **CIS Kubernetes Benchmark**
- **NIST Cybersecurity Framework**
- **SOC 2 Type II**
- **PCI DSS** (for payment processing)

## 9. Security Monitoring

### Key Metrics to Monitor
- Failed authentication attempts
- Privilege escalation attempts
- Unusual network traffic
- Resource consumption anomalies
- Image pull from untrusted registries

### Logging Security Events
```yaml
# Audit Policy Example
rules:
- level: Request
  resources:
  - group: ""
    resources: ["secrets"]
  verbs: ["get", "list"]
```

## 10. Incident Response

### Security Incident Playbook
1. **Detection**: Automated alerts
2. **Containment**: Isolate affected resources
3. **Investigation**: Analyze logs and events
4. **Remediation**: Patch vulnerabilities
5. **Recovery**: Restore normal operations
6. **Lessons Learned**: Update security policies

### Emergency Procedures
```bash
# Isolate compromised pod
kubectl label pod suspicious-pod quarantine=true
kubectl apply -f quarantine-networkpolicy.yaml

# Revoke access
kubectl delete rolebinding compromised-user-binding
```

## Key Takeaways (80/20 Rule)

### 20% Effort, 80% Security Impact:
1. **RBAC với least privilege**
2. **Pod Security Standards (restricted)**
3. **NetworkPolicy cho micro-segmentation**
4. **Image vulnerability scanning**
5. **Resource quotas và limits**
6. **Non-root containers**
7. **Read-only filesystems**
8. **Secret management best practices**

### Security Checklist
- [ ] RBAC implemented với least privilege
- [ ] Pod Security Standards enforced
- [ ] NetworkPolicy cho network segmentation
- [ ] Images được scan vulnerabilities
- [ ] Containers chạy non-root
- [ ] Resource limits được set
- [ ] Secrets không hardcode trong images
- [ ] Audit logging enabled
- [ ] Regular security assessments
- [ ] Incident response plan sẵn sàng