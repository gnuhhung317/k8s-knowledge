# Observability Theory - Lý thuyết Quan sát Hệ thống

## 1. Observability vs Monitoring

### Monitoring (Traditional)
- **Known unknowns**: Theo dõi những gì bạn biết có thể fail
- **Predefined dashboards**: Metrics được định nghĩa trước
- **Reactive**: Phản ứng với alerts đã được setup

### Observability (Modern)
- **Unknown unknowns**: Khám phá những vấn đề chưa biết
- **Exploratory analysis**: Tự do khám phá dữ liệu
- **Proactive**: Hiểu hệ thống để prevent issues

## 2. Three Pillars of Observability

### 2.1 Metrics (Định lượng)
```
Metrics = Numbers over Time
├── Counters (tăng dần)
├── Gauges (giá trị tức thời)
├── Histograms (phân phối)
└── Summaries (percentiles)
```

#### Key Metric Types:
- **Business Metrics**: Revenue, user signups, conversion rate
- **Application Metrics**: Request rate, response time, error rate
- **Infrastructure Metrics**: CPU, memory, disk, network
- **Kubernetes Metrics**: Pod restarts, resource usage, cluster health

### 2.2 Logs (Định tính)
```
Logs = Events with Context
├── Structured (JSON, key-value)
├── Semi-structured (Apache logs)
└── Unstructured (free text)
```

#### Log Levels Hierarchy:
```
FATAL   - Application crash
ERROR   - Error occurred but app continues
WARN    - Potential issue, needs attention
INFO    - General information
DEBUG   - Detailed debugging info
TRACE   - Very detailed execution flow
```

### 2.3 Traces (Luồng xử lý)
```
Trace = Request Journey
├── Span 1: Frontend (100ms)
├── Span 2: Auth Service (20ms)
├── Span 3: Business Logic (50ms)
└── Span 4: Database (30ms)
Total: 200ms
```

## 3. Prometheus Deep Dive

### 3.1 Prometheus Architecture
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Targets   │◄───│ Prometheus  │───▶│ Alertmanager│
│             │    │   Server    │    │             │
│ - Node Exp  │    │ - TSDB      │    │ - Routing   │
│ - App Metrics│    │ - Rules     │    │ - Grouping  │
│ - K8s API   │    │ - Scraping  │    │ - Silencing │
└─────────────┘    └─────────────┘    └─────────────┘
                           │
                           ▼
                   ┌─────────────┐
                   │   Grafana   │
                   │ - Dashboard │
                   │ - Alerting  │
                   │ - Users     │
                   └─────────────┘
```

### 3.2 PromQL (Prometheus Query Language)
```promql
# Instant vector - giá trị tại thời điểm hiện tại
http_requests_total

# Range vector - giá trị trong khoảng thời gian
http_requests_total[5m]

# Rate - tốc độ thay đổi
rate(http_requests_total[5m])

# Aggregation - tổng hợp
sum(rate(http_requests_total[5m])) by (service)

# Percentile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### 3.3 Metric Types trong Prometheus
```go
// Counter - chỉ tăng
prometheus.NewCounterVec(prometheus.CounterOpts{
    Name: "http_requests_total",
    Help: "Total HTTP requests",
}, []string{"method", "status"})

// Gauge - có thể tăng/giảm
prometheus.NewGaugeVec(prometheus.GaugeOpts{
    Name: "memory_usage_bytes",
    Help: "Memory usage in bytes",
}, []string{"instance"})

// Histogram - phân phối giá trị
prometheus.NewHistogramVec(prometheus.HistogramOpts{
    Name: "http_request_duration_seconds",
    Help: "HTTP request duration",
    Buckets: prometheus.DefBuckets,
}, []string{"method"})
```

## 4. Logging Best Practices

### 4.1 Structured Logging
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "service": "user-service",
  "trace_id": "abc123",
  "span_id": "def456",
  "user_id": "user123",
  "action": "login",
  "duration_ms": 150,
  "status": "success"
}
```

### 4.2 Log Correlation
```
Request ID: req-123
├── Frontend: [req-123] User login attempt
├── Auth Service: [req-123] Validating credentials
├── Database: [req-123] User query executed
└── Frontend: [req-123] Login successful
```

### 4.3 Log Aggregation Pipeline
```
Application Logs
       │
       ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Fluentd    │───▶│Elasticsearch│───▶│   Kibana    │
│ - Collect   │    │ - Index     │    │ - Search    │
│ - Parse     │    │ - Store     │    │ - Visualize │
│ - Filter    │    │ - Query     │    │ - Dashboard │
└─────────────┘    └─────────────┘    └─────────────┘
```

## 5. Distributed Tracing

### 5.1 Trace Context Propagation
```
HTTP Headers:
├── traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
├── tracestate: rojo=00f067aa0ba902b7,congo=t61rcWkgMzE
└── baggage: userId=alice,serverNode=DF28
```

### 5.2 Span Relationships
```
Trace: User Checkout
├── Span: Frontend Request (Parent)
│   ├── Span: Auth Check (Child)
│   ├── Span: Inventory Check (Child)
│   │   └── Span: Database Query (Child)
│   └── Span: Payment Process (Child)
│       ├── Span: Payment Gateway (Child)
│       └── Span: Email Notification (Child)
```

### 5.3 Sampling Strategies
```
Head-based Sampling (at trace start):
├── Probabilistic: 1% of all traces
├── Rate Limiting: 100 traces/second
└── Adaptive: Adjust based on load

Tail-based Sampling (after trace complete):
├── Error Sampling: All traces with errors
├── Latency Sampling: Slow traces (>1s)
└── Business Sampling: Important user actions
```

## 6. Alerting Theory

### 6.1 Alert Fatigue Prevention
```
Alert Quality = Signal / Noise
├── High Signal: Actionable, urgent alerts
└── Low Noise: Reduce false positives
```

### 6.2 Alert Severity Matrix
```
           │ Urgent │ Not Urgent │
───────────┼────────┼────────────┤
Important  │  Page  │   Email    │
───────────┼────────┼────────────┤
Not Import │ Email  │ Dashboard  │
```

### 6.3 SLI/SLO/SLA Framework
```
SLI (Service Level Indicator):
├── Availability: 99.9% uptime
├── Latency: 95% requests < 200ms
└── Error Rate: < 0.1% errors

SLO (Service Level Objective):
├── Target: 99.9% availability
└── Time Window: 30 days

SLA (Service Level Agreement):
├── Commitment: 99.5% availability
└── Penalty: Credits if not met
```

## 7. Dashboard Design Theory

### 7.1 Information Hierarchy
```
Executive Dashboard (CEO view)
├── Business KPIs
├── Revenue metrics
└── User satisfaction

Operational Dashboard (SRE view)
├── System health
├── Performance metrics
└── Error rates

Debug Dashboard (Developer view)
├── Detailed metrics
├── Log correlation
└── Trace analysis
```

### 7.2 Visual Design Principles
```
Dashboard Layout:
├── Most Important (Top-left)
├── Related Metrics (Grouped)
├── Time Alignment (Same periods)
└── Color Coding (Red=bad, Green=good)
```

## 8. Observability Maturity Model

### Level 1: Basic Monitoring
- Infrastructure metrics
- Simple dashboards
- Basic alerting

### Level 2: Application Observability
- Application metrics
- Structured logging
- Custom dashboards

### Level 3: Full Observability
- Distributed tracing
- Correlation across pillars
- Proactive insights

### Level 4: AI-Driven Observability
- Anomaly detection
- Predictive alerting
- Auto-remediation

## 9. Cost Optimization Strategies

### 9.1 Data Lifecycle Management
```
Hot Data (0-7 days):
├── High performance storage
├── Real-time queries
└── Full resolution

Warm Data (7-90 days):
├── Medium performance storage
├── Batch queries
└── Reduced resolution

Cold Data (90+ days):
├── Archive storage
├── Rare access
└── Compressed format
```

### 9.2 Sampling and Aggregation
```
Raw Data → Sampling → Aggregation → Storage
├── 100% for errors
├── 10% for normal requests
├── 1% for health checks
└── Pre-aggregated summaries
```

## 10. Observability Anti-patterns

### ❌ Common Mistakes:
1. **Too many metrics**: High cardinality explosion
2. **Alert spam**: Too many non-actionable alerts
3. **Dashboard sprawl**: Too many unused dashboards
4. **Log everything**: Expensive and noisy
5. **No correlation**: Isolated metrics/logs/traces

### ✅ Best Practices:
1. **Meaningful metrics**: Focus on business impact
2. **Actionable alerts**: Every alert needs runbook
3. **Curated dashboards**: Regular review and cleanup
4. **Strategic logging**: Log what matters
5. **Unified view**: Correlate across all pillars

## Key Takeaways (80/20 Rule)

### 20% Effort, 80% Observability Value:
1. **Golden Signals**: Latency, Traffic, Errors, Saturation
2. **Structured Logging**: JSON format với correlation IDs
3. **Basic Dashboards**: System health + business metrics
4. **Smart Alerting**: Actionable alerts only
5. **Trace Critical Paths**: User-facing request flows
6. **Resource Monitoring**: CPU, Memory, Disk usage
7. **Error Tracking**: All errors với context
8. **Performance Baselines**: Know your normal