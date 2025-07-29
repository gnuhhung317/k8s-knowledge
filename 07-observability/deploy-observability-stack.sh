#!/bin/bash

# Deploy Observability Stack for Kubernetes
# This script deploys Prometheus, Grafana, and sample applications

set -e

echo "🚀 Deploying Kubernetes Observability Stack..."

# Create namespaces
echo "📁 Creating namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tracing --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus
echo "📊 Deploying Prometheus..."
kubectl apply -f prometheus/prometheus-config.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml
kubectl apply -f prometheus/prometheus-service.yaml
kubectl apply -f prometheus/node-exporter.yaml

# Wait for Prometheus to be ready
echo "⏳ Waiting for Prometheus to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring

# Deploy Grafana
echo "📈 Deploying Grafana..."
kubectl apply -f grafana/grafana-config.yaml
kubectl apply -f grafana/grafana-deployment.yaml
kubectl apply -f grafana/grafana-service.yaml

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

# Deploy sample application
echo "🔧 Deploying sample application..."
kubectl apply -f sample-app/app-with-metrics.yaml
kubectl apply -f sample-app/load-generator.yaml

# Wait for sample app to be ready
echo "⏳ Waiting for sample app to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/sample-app

echo "✅ Observability stack deployed successfully!"
echo ""
echo "🔗 Access URLs (use kubectl port-forward):"
echo "   Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo ""
echo "📊 Grafana Login: admin/admin"
echo ""
echo "🎯 Recommended Grafana Dashboards to import:"
echo "   - Node Exporter Full: 1860"
echo "   - Kubernetes Cluster Monitoring: 6417"
echo "   - NGINX Ingress Controller: 9614"
echo ""
echo "📋 Check deployment status:"
echo "   kubectl get pods -n monitoring"
echo "   kubectl get svc -n monitoring"
echo ""
echo "🔍 Test Prometheus queries:"
echo "   - up"
echo "   - rate(nginx_http_requests_total[5m])"
echo "   - container_memory_usage_bytes"
echo "   - node_cpu_seconds_total"