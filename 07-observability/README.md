# 07. Observability - Monitoring, Logging, Tracing

## Mục tiêu
- Implement comprehensive monitoring với Prometheus + Grafana
- Centralized logging với ELK/EFK Stack
- Distributed tracing với Jaeger
- Application Performance Monitoring (APM)

## Three Pillars of Observability

### 1. Metrics (Prometheus + Grafana)
**Metrics** là dữ liệu số đo lường hiệu suất hệ thống theo thời gian.

#### Key Metrics Categories:
- **Infrastructure**: CPU, Memory, Disk, Network
- **Kubernetes**: Pod status, Node health, Resource usage
- **Application**: Request rate, Response time, Error rate (RED metrics)
- **Business**: User signups, Revenue, Feature usage

#### Prometheus Architecture:
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Targets   │───▶│ Prometheus  │───▶│   Grafana   │
│ (Exporters) │    │   Server    │    │ (Dashboard) │
└─────────────┘    └─────────────┘    └─────────────┘
```

### 2. Logs (EFK Stack)
**Logs** là records của events xảy ra trong hệ thống.

#### EFK Stack Components:
- **Fluentd/Fluent Bit**: Log collection và forwarding
- **Elasticsearch**: Log storage và indexing
- **Kibana**: Log visualization và analysis

#### Log Levels:
```
ERROR > WARN > INFO > DEBUG > TRACE
```

### 3. Traces (Jaeger)
**Traces** theo dõi request journey qua các microservices.

#### Distributed Tracing Concepts:
- **Trace**: End-to-end request journey
- **Span**: Individual operation trong trace
- **Tags**: Metadata về span
- **Baggage**: Cross-service context

## Hands-on Implementation

### Step 1: Deploy Monitoring Stack
```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus
kubectl apply -f prometheus/

# Deploy Grafana
kubectl apply -f grafana/

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80
# Login: admin/admin
```

### Step 2: Deploy Logging Stack
```bash
# Create logging namespace
kubectl create namespace logging

# Deploy Elasticsearch
kubectl apply -f elasticsearch/

# Deploy Kibana
kubectl apply -f kibana/

# Deploy Fluentd
kubectl apply -f fluentd/

# Access Kibana
kubectl port-forward -n logging svc/kibana 5601:5601
```

### Step 3: Deploy Tracing
```bash
# Create tracing namespace
kubectl create namespace tracing

# Deploy Jaeger
kubectl apply -f jaeger/

# Access Jaeger UI
kubectl port-forward -n tracing svc/jaeger-query 16686:16686
```

### Step 4: Deploy Sample Application
```bash
# Deploy microservices với observability
kubectl apply -f sample-app/

# Generate traffic
kubectl apply -f load-generator/
```

## Key Observability Patterns

### 1. Golden Signals (SRE)
- **Latency**: Response time của requests
- **Traffic**: Request rate
- **Errors**: Error rate
- **Saturation**: Resource utilization

### 2. RED Metrics (Request-focused)
- **Rate**: Requests per second
- **Errors**: Error percentage
- **Duration**: Response time distribution

### 3. USE Metrics (Resource-focused)
- **Utilization**: % time resource busy
- **Saturation**: Queue length/wait time
- **Errors**: Error count

## Alerting Strategy

### Alert Severity Levels:
1. **Critical**: Immediate action required (Page)
2. **Warning**: Action needed soon (Email)
3. **Info**: Awareness only (Dashboard)

### Alert Rules Examples:
```yaml
# High error rate
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
  for: 5m
  
# High memory usage
- alert: HighMemoryUsage
  expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
  for: 10m
```

## Dashboard Design Principles

### 1. Hierarchy of Information
```
Overview Dashboard
├── Service-specific Dashboards
├── Component Dashboards
└── Detailed Debugging Views
```

### 2. Dashboard Categories:
- **Executive**: High-level business metrics
- **Operational**: System health và performance
- **Debugging**: Detailed troubleshooting info

## Troubleshooting Workflow

### 1. Start with Symptoms
```
User Report → Metrics → Logs → Traces → Root Cause
```

### 2. Investigation Steps:
1. Check overall system health (Grafana)
2. Identify affected services (Metrics)
3. Examine error logs (Kibana)
4. Trace request flow (Jaeger)
5. Correlate timeline of events

## Best Practices

### Metrics:
- Use consistent naming conventions
- Include relevant labels
- Avoid high cardinality metrics
- Set appropriate retention policies

### Logs:
- Use structured logging (JSON)
- Include correlation IDs
- Log at appropriate levels
- Implement log rotation

### Traces:
- Sample appropriately (1-10%)
- Include business context
- Propagate trace context
- Monitor trace collection overhead

## Performance Considerations

### Resource Planning:
- **Prometheus**: 2-8GB RAM per million samples
- **Elasticsearch**: 3:1 RAM to disk ratio
- **Jaeger**: Storage scales with trace volume

### Retention Policies:
- **Metrics**: 15 days detailed, 1 year aggregated
- **Logs**: 30 days hot, 90 days warm, 1 year cold
- **Traces**: 7 days (due to volume)

## Integration với CI/CD

### Observability as Code:
```yaml
# Prometheus rules
- prometheus-rules.yaml
# Grafana dashboards
- dashboards/
# Alert configurations
- alertmanager.yaml
```

### Deployment Pipeline:
1. Deploy application
2. Deploy monitoring configs
3. Validate dashboards
4. Test alerts
5. Update runbooks

## Cost Optimization

### Storage Optimization:
- Use appropriate retention periods
- Implement data lifecycle policies
- Compress old data
- Use tiered storage

### Query Optimization:
- Use recording rules for expensive queries
- Implement query caching
- Optimize dashboard refresh rates
- Use appropriate time ranges

## Next Steps

Sau khi hoàn thành observability setup:
1. **[08. Advanced Topics](../08-advanced/)** - Service Mesh, GitOps, Advanced Patterns
2. **[09. Production](../09-production/)** - Production-ready deployments
3. **[10. Troubleshooting](../10-troubleshooting/)** - Common issues và solutions

## Quick Commands

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# View Grafana dashboards
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access Kibana
kubectl port-forward -n logging svc/kibana 5601:5601

# View Jaeger traces
kubectl port-forward -n tracing svc/jaeger-query 16686:16686

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```