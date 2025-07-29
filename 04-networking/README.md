# 04. Networking - CNI, Service Mesh, NetworkPolicy

## Mục tiêu
- Hiểu sâu về Kubernetes networking model
- Thực hành với CNI plugins (Cilium/Calico)
- Triển khai Service Mesh (Istio/Linkerd)
- Implement NetworkPolicy cho security

## Kubernetes Networking Model

### Fundamental Requirements
1. **Pod-to-Pod**: Mọi pod có thể giao tiếp trực tiếp
2. **Node-to-Pod**: Nodes có thể reach mọi pod
3. **No NAT**: Pod IP là real IP, không có translation
4. **Service Discovery**: DNS-based service resolution

### Network Architecture
```
┌─────────────────┐    ┌─────────────────┐
│     Pod A       │    │     Pod B       │
│   10.244.1.10   │◄──►│   10.244.2.20   │
└─────────────────┘    └─────────────────┘
         │                       │
┌─────────────────┐    ┌─────────────────┐
│    Node 1       │    │    Node 2       │
│  192.168.1.10   │◄──►│  192.168.1.11   │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
              Cluster Network
```

## CNI (Container Network Interface)

### Cilium - eBPF-based Networking
```bash
# Install Cilium
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.14.5 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true

# Verify installation
cilium status
cilium connectivity test
```

### Hubble - Network Observability
```bash
# Enable Hubble UI
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# CLI monitoring
hubble observe --follow
hubble observe --from-pod default/nginx --to-pod default/backend
```

### Hands-on: Network Flow Analysis
```bash
# Deploy test applications
kubectl apply -f network-test-apps.yaml

# Monitor traffic with Hubble
hubble observe --pod nginx --follow
hubble observe --verdict DROPPED

# Analyze network policies
hubble observe --type policy-verdict
```

## Service Mesh - Istio

### Architecture Components
- **Envoy Proxy**: Sidecar proxy
- **Istiod**: Control plane (Pilot, Citadel, Galley)
- **Ingress Gateway**: Entry point

### Installation
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PWD/istio-1.19.0/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable sidecar injection
kubectl label namespace default istio-injection=enabled
```

### Hands-on: Traffic Management
```bash
# Deploy Bookinfo sample app
kubectl apply -f samples/bookinfo/platform/kustomize/base

# Create Gateway and VirtualService
kubectl apply -f bookinfo-gateway.yaml

# Traffic splitting (Canary)
kubectl apply -f reviews-v2-canary.yaml

# Circuit breaker
kubectl apply -f destination-rule-circuit-breaker.yaml
```

### Security Features
```yaml
# Mutual TLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT

# Authorization Policy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-read
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-reviews"]
    to:
    - operation:
        methods: ["GET"]
```

## NetworkPolicy - Micro-segmentation

### Default Deny Policy
```yaml
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

### Hands-on: Multi-tier Security
```bash
# Deploy 3-tier app
kubectl apply -f 3tier-app.yaml

# Apply network policies
kubectl apply -f frontend-netpol.yaml
kubectl apply -f backend-netpol.yaml
kubectl apply -f database-netpol.yaml

# Test connectivity
kubectl exec -it frontend-pod -- curl backend-service
kubectl exec -it frontend-pod -- curl database-service  # Should fail
```

### Advanced NetworkPolicy Patterns
```yaml
# Allow DNS
- to: []
  ports:
  - protocol: UDP
    port: 53

# Allow specific namespaces
- from:
  - namespaceSelector:
      matchLabels:
        name: production

# Allow external traffic
- to: []
  ports:
  - protocol: TCP
    port: 443
```

## Service Types Deep Dive

### LoadBalancer với MetalLB
```bash
# Install MetalLB for bare metal
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Configure IP pool
kubectl apply -f metallb-config.yaml

# Test LoadBalancer service
kubectl apply -f nginx-loadbalancer.yaml
kubectl get svc nginx-lb
```

### Ingress Controllers
```bash
# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/kind/deploy.yaml

# Create Ingress resource
kubectl apply -f app-ingress.yaml

# Test with curl
curl -H "Host: myapp.local" http://localhost
```

## DNS và Service Discovery

### CoreDNS Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

### Service Discovery Testing
```bash
# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- sh
nslookup kubernetes.default.svc.cluster.local
nslookup my-service.my-namespace.svc.cluster.local

# Test service endpoints
kubectl get endpoints my-service
kubectl describe service my-service
```

## Troubleshooting Network Issues

### Common Problems
```bash
# Pod can't reach service
kubectl exec -it pod-name -- nslookup service-name
kubectl get endpoints service-name

# NetworkPolicy blocking traffic
kubectl describe networkpolicy policy-name
kubectl logs -n kube-system -l k8s-app=cilium

# CNI issues
kubectl get pods -n kube-system
kubectl logs -n kube-system cilium-xxx

# Service mesh issues
istioctl proxy-status
istioctl proxy-config cluster pod-name
kubectl logs pod-name -c istio-proxy
```

### Network Debugging Tools
```bash
# Install netshoot for debugging
kubectl run netshoot --image=nicolaka/netshoot --rm -it -- bash

# Inside netshoot pod
tcpdump -i any -n host 10.244.1.10
ss -tulpn
iptables -L -n -v
```

## Performance Optimization

### IPVS Mode
```yaml
# kube-proxy config
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  scheduler: "rr"  # round-robin
```

### EndpointSlices
```bash
# Check EndpointSlices (auto-enabled in newer versions)
kubectl get endpointslices
kubectl describe endpointslice service-name-xxx
```

## Best Practices

### Network Security
1. **Default deny**: Start with restrictive NetworkPolicies
2. **Least privilege**: Only allow necessary traffic
3. **Namespace isolation**: Use namespace-based policies
4. **Regular audits**: Review and update policies

### Service Mesh
1. **Gradual rollout**: Enable sidecar injection gradually
2. **Monitor performance**: Watch latency and resource usage
3. **Security first**: Enable mTLS from day one
4. **Observability**: Use distributed tracing

### Performance
1. **CNI choice**: Consider eBPF-based solutions
2. **IPVS mode**: For large clusters (>1000 services)
3. **DNS caching**: Tune CoreDNS for your workload
4. **Network policies**: Minimize policy complexity

## Câu hỏi suy ngẫm
1. Tại sao Service Mesh cần sidecar proxy?
2. Khi nào nên dùng NetworkPolicy vs Service Mesh security?
3. Làm thế nào để debug network connectivity issues?
4. IPVS vs iptables: khi nào nên chuyển đổi?

## Tiếp theo
Chuyển sang [05. Deployment & Release](../05-deployment/) để học về GitOps, Helm, CI/CD.