#!/bin/bash

# Deploy Advanced Kubernetes Stack
# This script demonstrates advanced Kubernetes patterns

set -e

echo "🚀 Deploying Advanced Kubernetes Stack..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "⏳ Waiting for $deployment in $namespace to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n $namespace
}

# 1. Install Istio (if not present)
if ! command_exists istioctl; then
    echo "📦 Installing Istio..."
    curl -L https://istio.io/downloadIstio | sh -
    export PATH=$PWD/istio-*/bin:$PATH
fi

echo "🕸️ Setting up Istio Service Mesh..."
istioctl install --set values.defaultRevision=default -y

# Enable sidecar injection
kubectl label namespace default istio-injection=enabled --overwrite

# Deploy Bookinfo application
echo "📚 Deploying Bookinfo sample application..."
kubectl apply -f istio/bookinfo-app.yaml
kubectl apply -f istio/bookinfo-gateway.yaml
kubectl apply -f istio/destination-rules.yaml

# 2. Install ArgoCD
echo "🔄 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

wait_for_deployment argocd argocd-server

# Get ArgoCD admin password
echo "🔑 ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# Deploy sample GitOps application
echo "📱 Deploying GitOps applications..."
kubectl apply -f argocd/sample-app.yaml

# 3. Install Argo Rollouts
echo "🎯 Installing Argo Rollouts..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

wait_for_deployment argo-rollouts argo-rollouts-controller

# Deploy rollout examples
echo "🔄 Deploying rollout examples..."
kubectl apply -f rollouts/canary-rollout.yaml
kubectl apply -f rollouts/blue-green-rollout.yaml

# 4. Install Custom Resource Definitions
echo "🔧 Installing Custom Resource Definitions..."
kubectl apply -f crds/database-crd.yaml

# Create custom resource instances
echo "💾 Creating database instances..."
kubectl apply -f crds/database-instances.yaml

# 5. Verify installations
echo "✅ Verifying installations..."

echo "📊 Istio components:"
kubectl get pods -n istio-system

echo "🔄 ArgoCD components:"
kubectl get pods -n argocd

echo "🎯 Argo Rollouts components:"
kubectl get pods -n argo-rollouts

echo "📚 Bookinfo application:"
kubectl get pods -l app=productpage

echo "💾 Custom databases:"
kubectl get databases

echo ""
echo "🎉 Advanced stack deployed successfully!"
echo ""
echo "🔗 Access URLs (use kubectl port-forward):"
echo "   Istio Kiali:    kubectl port-forward -n istio-system svc/kiali 20001:20001"
echo "   ArgoCD:         kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "   Bookinfo:       kubectl port-forward svc/productpage 9080:9080"
echo ""
echo "🔑 ArgoCD Login: admin / <password shown above>"
echo ""
echo "🎯 Useful commands:"
echo "   istioctl proxy-status"
echo "   kubectl argo rollouts list rollouts"
echo "   kubectl get applications -n argocd"
echo "   kubectl get databases"
echo ""
echo "📖 Next steps:"
echo "   1. Explore Istio traffic management"
echo "   2. Set up GitOps workflows"
echo "   3. Practice canary deployments"
echo "   4. Create custom operators"