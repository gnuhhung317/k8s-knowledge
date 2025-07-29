#!/bin/bash

echo "🚀 Setting up Kubernetes Learning Environment..."

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }

# Install kind if not exists
if ! command -v kind &> /dev/null; then
    echo "📦 Installing kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

# Install helm if not exists
if ! command -v helm &> /dev/null; then
    echo "📦 Installing helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Create kind cluster
echo "🔧 Creating kind cluster..."
kind create cluster --config=./01-architecture/kind-config.yaml --name=k8s-learning

# Install CNI (Cilium)
echo "🌐 Installing Cilium CNI..."
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.14.5 \
    --namespace kube-system \
    --set image.pullPolicy=IfNotPresent \
    --set ipam.mode=kubernetes

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=ready node --all --timeout=300s

echo "✅ Setup complete! Run 'kubectl get nodes' to verify."
echo "📚 Start with: cd 01-architecture && cat README.md"