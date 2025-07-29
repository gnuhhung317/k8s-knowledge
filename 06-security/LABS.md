# Security Labs - Thực hành Bảo mật Kubernetes

## Lab 1: RBAC (Role-Based Access Control)

### Bước 1: Tạo ServiceAccount và Role
```bash
# Tạo namespace cho lab
kubectl create namespace security-lab

# Apply RBAC resources
kubectl apply -f developer-serviceaccount.yaml
kubectl apply -f developer-role.yaml
kubectl apply -f developer-rolebinding.yaml
```

### Bước 2: Test RBAC permissions
```bash
# Test quyền của developer
kubectl auth can-i get pods --as=system:serviceaccount:security-lab:developer -n security-lab
kubectl auth can-i create pods --as=system:serviceaccount:security-lab:developer -n security-lab
kubectl auth can-i delete deployments --as=system:serviceaccount:security-lab:developer -n security-lab

# Test với kubectl proxy
kubectl proxy &
curl -H "Authorization: Bearer $(kubectl get secret developer-token -n security-lab -o jsonpath='{.data.token}' | base64 -d)" \
  http://localhost:8001/api/v1/namespaces/security-lab/pods
```

## Lab 2: Pod Security Standards

### Bước 1: Apply Pod Security Standards
```bash
# Label namespace với security level
kubectl label namespace security-lab pod-security.kubernetes.io/enforce=restricted
kubectl label namespace security-lab pod-security.kubernetes.io/audit=restricted
kubectl label namespace security-lab pod-security.kubernetes.io/warn=restricted

# Test với secure và insecure pods
kubectl apply -f secure-pod.yaml
kubectl apply -f insecure-pod.yaml  # Sẽ bị reject
```

### Bước 2: Security Context Testing
```bash
# Deploy pod với security context
kubectl apply -f security-context-pod.yaml

# Kiểm tra security context
kubectl exec security-demo -- ps aux
kubectl exec security-demo -- id
```

## Lab 3: Network Security với NetworkPolicy

### Bước 1: Deploy test applications
```bash
# Deploy frontend, backend, database
kubectl apply -f network-test-apps.yaml

# Test connectivity trước khi apply NetworkPolicy
kubectl exec frontend-pod -- curl backend-service
kubectl exec backend-pod -- curl database-service
```

### Bước 2: Apply NetworkPolicy
```bash
# Apply network policies
kubectl apply -f deny-all-networkpolicy.yaml
kubectl apply -f allow-frontend-to-backend.yaml
kubectl apply -f allow-backend-to-database.yaml

# Test connectivity sau khi apply NetworkPolicy
kubectl exec frontend-pod -- curl backend-service  # Should work
kubectl exec frontend-pod -- curl database-service  # Should fail
```

## Lab 4: Image Security

### Bước 1: Image Scanning
```bash
# Scan image với trivy
trivy image nginx:latest
trivy image nginx:1.21-alpine

# Compare vulnerabilities
trivy image --severity HIGH,CRITICAL nginx:latest
```

### Bước 2: Private Registry
```bash
# Create secret for private registry
kubectl create secret docker-registry regcred \
  --docker-server=your-registry.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@example.com

# Deploy pod using private registry
kubectl apply -f private-registry-pod.yaml
```

## Troubleshooting Commands

```bash
# Check RBAC permissions
kubectl auth can-i --list --as=system:serviceaccount:security-lab:developer

# Debug NetworkPolicy
kubectl describe networkpolicy -n security-lab

# Check Pod Security violations
kubectl get events --field-selector reason=FailedCreate

# View security context
kubectl get pod security-demo -o jsonpath='{.spec.securityContext}'
```

## Best Practices Checklist

- [ ] Principle of least privilege cho RBAC
- [ ] Non-root containers
- [ ] Read-only root filesystem
- [ ] Network segmentation với NetworkPolicy
- [ ] Image vulnerability scanning
- [ ] Secret management
- [ ] Resource limits và quotas
- [ ] Pod Security Standards enforcement