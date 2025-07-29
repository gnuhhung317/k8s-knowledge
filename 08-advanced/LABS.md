# Advanced Topics Labs - Thực hành Chủ đề Nâng cao

## Lab 1: Istio Service Mesh

### Bước 1: Install Istio
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default -y

# Verify installation
kubectl get pods -n istio-system
```

### Bước 2: Deploy Sample Application
```bash
# Enable sidecar injection
kubectl label namespace default istio-injection=enabled

# Deploy Bookinfo application
kubectl apply -f istio/bookinfo-app.yaml

# Deploy gateway
kubectl apply -f istio/bookinfo-gateway.yaml

# Get ingress IP
kubectl get svc istio-ingressgateway -n istio-system
```

### Bước 3: Traffic Management
```bash
# Apply destination rules
kubectl apply -f istio/destination-rules.yaml

# Route all traffic to v1
kubectl apply -f istio/virtual-service-all-v1.yaml

# Route traffic based on user
kubectl apply -f istio/virtual-service-reviews-test-v2.yaml

# Test routing
curl -H "end-user: jason" http://$GATEWAY_URL/productpage
```

### Bước 4: Security với mTLS
```bash
# Enable strict mTLS
kubectl apply -f istio/peer-authentication.yaml

# Verify mTLS
istioctl authn tls-check productpage-v1-xxx.default

# Check certificates
istioctl proxy-config secret productpage-v1-xxx.default
```

## Lab 2: ArgoCD GitOps

### Bước 1: Install ArgoCD
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Bước 2: Access ArgoCD UI
```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login: admin / <password from step 1>
# Or use CLI
argocd login localhost:8080
```

### Bước 3: Create GitOps Application
```bash
# Create application via CLI
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Or apply YAML
kubectl apply -f argocd/sample-app.yaml

# Sync application
argocd app sync guestbook
```

### Bước 4: GitOps Workflow
```bash
# Watch sync status
argocd app get guestbook --watch

# Make changes in Git repo
# ArgoCD will detect and sync automatically

# Manual sync if needed
argocd app sync guestbook

# Rollback if needed
argocd app rollback guestbook
```

## Lab 3: Advanced Deployments với Argo Rollouts

### Bước 1: Install Argo Rollouts
```bash
# Install controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

### Bước 2: Blue-Green Deployment
```bash
# Deploy blue-green rollout
kubectl apply -f rollouts/blue-green-rollout.yaml

# Watch rollout
kubectl argo rollouts get rollout blue-green-demo --watch

# Promote to green
kubectl argo rollouts promote blue-green-demo
```

### Bước 3: Canary Deployment
```bash
# Deploy canary rollout
kubectl apply -f rollouts/canary-rollout.yaml

# Update image to trigger rollout
kubectl argo rollouts set image canary-demo app=nginx:1.21

# Watch canary progress
kubectl argo rollouts get rollout canary-demo --watch

# Promote manually
kubectl argo rollouts promote canary-demo

# Abort if issues
kubectl argo rollouts abort canary-demo
```

### Bước 4: Analysis và Metrics
```bash
# Deploy with analysis
kubectl apply -f rollouts/canary-with-analysis.yaml

# Check analysis results
kubectl describe analysisrun canary-demo-xxx

# View metrics
kubectl get analysistemplate success-rate -o yaml
```

## Lab 4: Custom Resource Definitions (CRDs)

### Bước 1: Create Simple CRD
```bash
# Apply CRD definition
kubectl apply -f crds/database-crd.yaml

# Verify CRD
kubectl get crd databases.example.com
kubectl describe crd databases.example.com
```

### Bước 2: Create Custom Resources
```bash
# Create database instances
kubectl apply -f crds/database-instances.yaml

# List custom resources
kubectl get databases
kubectl describe database postgres-db
```

### Bước 3: Build Simple Controller
```bash
# Install kubebuilder
curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)
chmod +x kubebuilder && mv kubebuilder /usr/local/bin/

# Create new project
kubebuilder init --domain example.com --repo github.com/example/database-operator

# Create API
kubebuilder create api --group apps --version v1 --kind Database

# Implement controller logic (see crds/controller-example.go)
# Build and deploy
make docker-build docker-push IMG=your-registry/database-operator:latest
make deploy IMG=your-registry/database-operator:latest
```

## Lab 5: Policy as Code với OPA Gatekeeper

### Bước 1: Install Gatekeeper
```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Wait for pods
kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system
```

### Bước 2: Create Constraint Template
```bash
# Apply constraint template
kubectl apply -f policies/require-labels-template.yaml

# Verify template
kubectl get constrainttemplates
```

### Bước 3: Create Constraints
```bash
# Apply constraint
kubectl apply -f policies/require-labels-constraint.yaml

# Test policy
kubectl apply -f policies/test-pod-without-labels.yaml  # Should fail
kubectl apply -f policies/test-pod-with-labels.yaml     # Should succeed
```

### Bước 4: Monitor Violations
```bash
# Check violations
kubectl get constraints
kubectl describe k8srequiredlabels must-have-team

# View violation details
kubectl get events --field-selector reason=FailedCreate
```

## Lab 6: Multi-cluster Management

### Bước 1: Setup Multiple Clusters
```bash
# Create additional clusters (using kind)
kind create cluster --name cluster1 --config kind-cluster1.yaml
kind create cluster --name cluster2 --config kind-cluster2.yaml

# Get cluster contexts
kubectl config get-contexts
```

### Bước 2: ArgoCD Multi-cluster
```bash
# Add clusters to ArgoCD
argocd cluster add kind-cluster1
argocd cluster add kind-cluster2

# List clusters
argocd cluster list

# Deploy to specific cluster
argocd app create app-cluster1 \
  --repo https://github.com/example/manifests \
  --path cluster1 \
  --dest-server https://cluster1-api-server \
  --dest-namespace default
```

### Bước 3: Cross-cluster Service Discovery
```bash
# Install Submariner (for cross-cluster networking)
subctl deploy-broker --kubeconfig cluster1-config
subctl join --kubeconfig cluster1-config broker-info.subm
subctl join --kubeconfig cluster2-config broker-info.subm

# Verify connectivity
subctl show connections
```

## Lab 7: Chaos Engineering

### Bước 1: Install Chaos Mesh
```bash
# Install Chaos Mesh
curl -sSL https://mirrors.chaos-mesh.org/v2.5.1/install.sh | bash

# Verify installation
kubectl get pods -n chaos-mesh
```

### Bước 2: Pod Chaos Experiments
```bash
# Kill random pods
kubectl apply -f chaos/pod-kill-chaos.yaml

# Network delay
kubectl apply -f chaos/network-delay-chaos.yaml

# CPU stress
kubectl apply -f chaos/stress-chaos.yaml
```

### Bước 3: Monitor Impact
```bash
# Watch experiment status
kubectl get podchaos -w

# Check application metrics
kubectl port-forward svc/prometheus 9090:9090
# Query: rate(http_requests_total[5m])

# Analyze results
kubectl describe podchaos pod-kill-example
```

## Lab 8: Performance Optimization

### Bước 1: Vertical Pod Autoscaler
```bash
# Install VPA
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
./hack/vpa-install.sh

# Apply VPA to deployment
kubectl apply -f optimization/vpa-example.yaml

# Check recommendations
kubectl describe vpa vpa-recommender
```

### Bước 2: Horizontal Pod Autoscaler
```bash
# Install metrics server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create HPA
kubectl apply -f optimization/hpa-example.yaml

# Generate load
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# while true; do wget -q -O- http://php-apache; done

# Watch scaling
kubectl get hpa -w
```

### Bước 3: Custom Metrics Scaling
```bash
# Install Prometheus Adapter
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-adapter prometheus-community/prometheus-adapter

# Create custom HPA
kubectl apply -f optimization/custom-metrics-hpa.yaml

# Monitor custom metrics
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
```

## Troubleshooting Commands

### Istio Debugging
```bash
# Check proxy configuration
istioctl proxy-config cluster productpage-v1-xxx.default

# Analyze configuration
istioctl analyze

# Check proxy status
istioctl proxy-status

# View access logs
kubectl logs productpage-v1-xxx -c istio-proxy
```

### ArgoCD Debugging
```bash
# Check application health
argocd app get myapp

# View sync history
argocd app history myapp

# Check controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Refresh application
argocd app refresh myapp
```

### Rollouts Debugging
```bash
# Check rollout status
kubectl argo rollouts status canary-demo

# View rollout events
kubectl describe rollout canary-demo

# Check analysis results
kubectl get analysisrun
kubectl describe analysisrun canary-demo-xxx
```

## Best Practices Checklist

### Service Mesh:
- [ ] Start with traffic management
- [ ] Enable mTLS gradually
- [ ] Monitor sidecar resource usage
- [ ] Use virtual services for routing
- [ ] Implement circuit breakers

### GitOps:
- [ ] Git as single source of truth
- [ ] Separate config from code repos
- [ ] Use declarative configurations
- [ ] Implement proper RBAC
- [ ] Monitor drift detection

### Advanced Deployments:
- [ ] Define success metrics
- [ ] Implement automated rollbacks
- [ ] Use analysis templates
- [ ] Monitor business KPIs
- [ ] Test rollback procedures

### CRDs and Operators:
- [ ] Follow Kubernetes conventions
- [ ] Implement proper validation
- [ ] Use controller-runtime
- [ ] Handle edge cases
- [ ] Provide clear documentation

### Multi-cluster:
- [ ] Consistent cluster configuration
- [ ] Centralized policy management
- [ ] Network connectivity planning
- [ ] Disaster recovery procedures
- [ ] Cost optimization strategies