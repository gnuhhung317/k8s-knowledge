# Observability Labs - Thực hành Quan sát Hệ thống

## Lab 1: Prometheus + Grafana Setup

### Bước 1: Deploy Prometheus Stack
```bash
# Tạo namespace
kubectl create namespace monitoring

# Deploy Prometheus
kubectl apply -f prometheus/prometheus-config.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml
kubectl apply -f prometheus/prometheus-service.yaml

# Deploy Node Exporter
kubectl apply -f prometheus/node-exporter.yaml

# Verify deployment
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

### Bước 2: Deploy Grafana
```bash
# Deploy Grafana
kubectl apply -f grafana/grafana-config.yaml
kubectl apply -f grafana/grafana-deployment.yaml
kubectl apply -f grafana/grafana-service.yaml

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Login credentials: admin/admin
# Import dashboards: 1860 (Node Exporter), 6417 (Kubernetes)
```

### Bước 3: Verify Metrics Collection
```bash
# Access Prometheus UI
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Test queries:
# - up (all targets status)
# - rate(container_cpu_usage_seconds_total[5m])
# - container_memory_usage_bytes
```

## Lab 2: Application Metrics

### Bước 1: Deploy Sample App với Metrics
```bash
# Deploy sample application
kubectl apply -f sample-app/app-with-metrics.yaml

# Deploy ServiceMonitor
kubectl apply -f sample-app/service-monitor.yaml

# Generate traffic
kubectl apply -f sample-app/load-generator.yaml
```

### Bước 2: Create Custom Dashboard
```bash
# Import custom dashboard
kubectl apply -f grafana/custom-dashboard.yaml

# Key metrics to monitor:
# - http_requests_total
# - http_request_duration_seconds
# - application_errors_total
```

## Lab 3: EFK Logging Stack

### Bước 1: Deploy Elasticsearch
```bash
# Create logging namespace
kubectl create namespace logging

# Deploy Elasticsearch
kubectl apply -f elasticsearch/elasticsearch-config.yaml
kubectl apply -f elasticsearch/elasticsearch-deployment.yaml
kubectl apply -f elasticsearch/elasticsearch-service.yaml

# Wait for Elasticsearch to be ready
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s
```

### Bước 2: Deploy Kibana
```bash
# Deploy Kibana
kubectl apply -f kibana/kibana-config.yaml
kubectl apply -f kibana/kibana-deployment.yaml
kubectl apply -f kibana/kibana-service.yaml

# Access Kibana
kubectl port-forward -n logging svc/kibana 5601:5601
```

### Bước 3: Deploy Fluentd
```bash
# Deploy Fluentd DaemonSet
kubectl apply -f fluentd/fluentd-config.yaml
kubectl apply -f fluentd/fluentd-daemonset.yaml

# Verify log collection
kubectl logs -n logging -l app=fluentd
```

### Bước 4: Configure Log Analysis
```bash
# Create index pattern in Kibana: logstash-*
# Create visualizations:
# - Log levels over time
# - Error rate by service
# - Top error messages
```

## Lab 4: Distributed Tracing với Jaeger

### Bước 1: Deploy Jaeger
```bash
# Create tracing namespace
kubectl create namespace tracing

# Deploy Jaeger All-in-One
kubectl apply -f jaeger/jaeger-deployment.yaml
kubectl apply -f jaeger/jaeger-service.yaml

# Access Jaeger UI
kubectl port-forward -n tracing svc/jaeger-query 16686:16686
```

### Bước 2: Deploy Microservices với Tracing
```bash
# Deploy microservices
kubectl apply -f microservices/frontend.yaml
kubectl apply -f microservices/backend.yaml
kubectl apply -f microservices/database.yaml

# Generate traced requests
kubectl apply -f microservices/traffic-generator.yaml
```

### Bước 3: Analyze Traces
```bash
# View traces in Jaeger UI
# - Search by service
# - Analyze latency distribution
# - Find error traces
# - Compare trace timelines
```

## Lab 5: Alerting Setup

### Bước 1: Configure Alertmanager
```bash
# Deploy Alertmanager
kubectl apply -f alerting/alertmanager-config.yaml
kubectl apply -f alerting/alertmanager-deployment.yaml
kubectl apply -f alerting/alertmanager-service.yaml
```

### Bước 2: Create Alert Rules
```bash
# Apply Prometheus alert rules
kubectl apply -f alerting/prometheus-rules.yaml

# Test alerts
# - Scale down a deployment
# - Generate high CPU load
# - Create network issues
```

### Bước 3: Configure Notifications
```bash
# Configure Slack/Email notifications
# Edit alertmanager-config.yaml
# Add webhook URLs
# Test notification delivery
```

## Lab 6: End-to-End Observability

### Bước 1: Deploy Complete Stack
```bash
# Deploy everything
./deploy-observability-stack.sh

# Verify all components
kubectl get pods --all-namespaces | grep -E "(monitoring|logging|tracing)"
```

### Bước 2: Simulate Production Scenario
```bash
# Deploy e-commerce microservices
kubectl apply -f scenarios/ecommerce-app.yaml

# Simulate user traffic
kubectl apply -f scenarios/user-simulation.yaml

# Introduce failures
kubectl apply -f scenarios/chaos-engineering.yaml
```

### Bước 3: Troubleshooting Exercise
```bash
# Scenario: High latency reported
# 1. Check Grafana dashboards
# 2. Analyze logs in Kibana
# 3. Trace requests in Jaeger
# 4. Correlate findings
# 5. Identify root cause
```

## Lab 7: Performance Optimization

### Bước 1: Resource Monitoring
```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check Prometheus resource usage
kubectl describe pod -n monitoring -l app=prometheus
```

### Bước 2: Query Optimization
```bash
# Optimize expensive queries
# Use recording rules
kubectl apply -f optimization/recording-rules.yaml

# Configure retention policies
# Edit prometheus.yaml
```

### Bước 3: Storage Optimization
```bash
# Configure log retention
# Edit elasticsearch configuration
# Set up index lifecycle management

# Configure trace sampling
# Edit jaeger configuration
# Set sampling rates
```

## Troubleshooting Commands

### Prometheus Issues
```bash
# Check Prometheus config
kubectl exec -n monitoring prometheus-0 -- promtool check config /etc/prometheus/prometheus.yml

# Check targets
curl http://localhost:9090/api/v1/targets

# Check rules
curl http://localhost:9090/api/v1/rules
```

### Elasticsearch Issues
```bash
# Check cluster health
kubectl exec -n logging elasticsearch-0 -- curl -X GET "localhost:9200/_cluster/health?pretty"

# Check indices
kubectl exec -n logging elasticsearch-0 -- curl -X GET "localhost:9200/_cat/indices?v"

# Check node stats
kubectl exec -n logging elasticsearch-0 -- curl -X GET "localhost:9200/_nodes/stats?pretty"
```

### Jaeger Issues
```bash
# Check Jaeger health
kubectl exec -n tracing jaeger-0 -- wget -qO- http://localhost:14269/

# Check trace ingestion
kubectl logs -n tracing -l app=jaeger-collector

# Check storage backend
kubectl exec -n tracing jaeger-0 -- jaeger-query --help
```

## Best Practices Checklist

### Metrics:
- [ ] Use consistent naming conventions
- [ ] Include relevant labels
- [ ] Avoid high cardinality
- [ ] Set appropriate retention
- [ ] Use recording rules for expensive queries

### Logs:
- [ ] Use structured logging (JSON)
- [ ] Include correlation IDs
- [ ] Set appropriate log levels
- [ ] Configure log rotation
- [ ] Index optimization

### Traces:
- [ ] Configure appropriate sampling
- [ ] Include business context
- [ ] Propagate trace context
- [ ] Monitor collection overhead
- [ ] Set retention policies

### Dashboards:
- [ ] Follow information hierarchy
- [ ] Use consistent time ranges
- [ ] Include SLI/SLO metrics
- [ ] Regular review and cleanup
- [ ] Document dashboard purpose

### Alerts:
- [ ] Every alert has a runbook
- [ ] Alerts are actionable
- [ ] Appropriate severity levels
- [ ] Avoid alert fatigue
- [ ] Test alert delivery