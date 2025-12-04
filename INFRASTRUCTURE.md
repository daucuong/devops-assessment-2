# ACME Platform Infrastructure Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [System Components](#system-components)
4. [Deployment Architecture](#deployment-architecture)
5. [Security](#security)
6. [Scalability](#scalability)
7. [Disaster Recovery](#disaster-recovery)
8. [Observability](#observability)
9. [Resource Tagging & Cost Management](#resource-tagging--cost-management)
10. [References](#references)

---

## Overview

This infrastructure implements the ACME platform—a containerized, cloud-native application stack with full high availability, automatic scaling, and comprehensive observability. The solution is deployed on Kubernetes using Terraform for infrastructure-as-code, with Helm for package management and ArgoCD for GitOps-based deployments.

**Technology Stack:**
- **Orchestration:** Kubernetes (any distribution)
- **Infrastructure as Code:** Terraform
- **Package Management:** Helm
- **GitOps:** ArgoCD
- **Service Mesh:** Istio (optional)
- **Ingress:** NGINX Ingress Controller
- **Database:** PostgreSQL (HA Cluster via CloudNativePG)
- **Observability:** Prometheus, Grafana, OpenTelemetry, Jaeger, Tempo
- **Security:** cert-manager, External Secrets Operator, Network Policies
- **Backup & Disaster Recovery:** Velero (backup orchestration and restoration)

---

## Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet / DNS                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┴──────────────────┐
         │                                  │
    ┌──────────────────────────────────────────┐
    │         www.acme.com (Single Domain)     │
    │  /       -> UI                           │
    │  /api    -> API                          │
    └────┬─────────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────────┐
    │  NGINX Ingress Controller(TLS Termination)│
    │  - LoadBalancer Service (2 replicas HA)   │
    │  - SSL/TLS via cert-manager (acme-tls)    │
    │  - Request timeouts: 600s                 │
    │  - Pod Anti-Affinity enabled              │
    └────┬──────────────────────────────────────┘
         │
    ┌────▼────────────────────────────────────────┐
    │         Kubernetes Cluster                  │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  Application Namespace               │   │
    │  │  ├─ UI Pods (acme/ui)                │   │
    │  │  │  └─ 2+ Replicas (HPA enabled)     │   │
    │  │  └─ API Pods (acme/api)              │   │
    │  │     └─ 2+ Replicas (HPA enabled)     │   │
    │  └──────────────────────────────────────┘   │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  Observability Namespace             │   │
    │  │  ├─ OpenTelemetry Collector          │   │
    │  │  ├─ Jaeger (Distributed Tracing)     │   │
    │  │  └─ Tempo (Trace Storage)            │   │
    │  └──────────────────────────────────────┘   │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  Monitoring Namespace                │   │
    │  │  ├─ Prometheus                       │   │
    │  │  └─ Grafana                          │   │
    │  └──────────────────────────────────────┘   │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  Database Namespace                  │   │
    │  │  └─ PostgreSQL HA Cluster (3 nodes)  │   │
    │  │     ├─ Primary                       │   │
    │  │     └─ Replicas + Standby            │   │
    │  └──────────────────────────────────────┘   │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  Security Namespace                  │   │
    │  │  ├─ cert-manager                     │   │
    │  │  ├─ External Secrets Operator        │   │
    │  │  └─ Istio (optional service mesh)    │   │
    │  └──────────────────────────────────────┘   │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  CI/CD Namespace (argocd)            │   │
    │  │  └─ ArgoCD Controller                │   │
    │  │     └─ Git-driven deployments        │   │
    │  └──────────────────────────────────────┘   │
    │                                             │
    │  ┌──────────────────────────────────────┐   │
    │  │  Backup Namespace (velero)           │   │
    │  │  └─ Velero Server                    │   │
    │  │     ├─ Scheduled backups             │   │
    │  │     └─ Backup/restore operations     │   │
    │  └──────────────────────────────────────┘   │
    └────┬────────────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────────┐
    │  Persistent Storage                       │
    │  ├─ PostgreSQL PVs (3x for HA cluster)    │
    │  ├─ Tempo Trace Storage (10Gi)            │
    │  └─ Jaeger Storage (if using DB backend)  │
    └───────────────────────────────────────────┘
```

---

## System Components

### 1. **User Interface (UI)**
- **Image:** `acme/ui`
- **Path:** `www.acme.com/` (root path, catch-all)
- **Ports:** 80/443 (exposed via NGINX Ingress)
- **Public:** Yes
- **Replicas:** 2+ (min) to 20+ (max, configurable via HPA)
- **Description:** .NET Core web frontend serving the ACME UI
- **Assumption:** The application is .NET Core latest version

**Resource Configuration (.NET Core Optimized):**
```
CPU Request:    250m      # .NET runtime baseline (~100-150m) + headroom
CPU Limit:      1000m     # 4x request for burst handling
Memory Request: 256Mi     # .NET GC + heap + application buffer
Memory Limit:   1Gi       # 4x request, critical for OOM prevention
```

**Horizontal Pod Autoscaling (HPA):**
```
Minimum Replicas:  2
Maximum Replicas:  20
CPU Threshold:     70%  # .NET responds well to CPU-based scaling
Memory Threshold:  80%  # Scale early to avoid OOM kills
```

**Rationale for .NET Core:**
- **.NET Runtime:** Requires ~100-150MB baseline for CLR + GC overhead
- **CPU Scaling:** 70% threshold optimal; prevents thrashing while maintaining responsiveness
- **Memory Protection:** 80% threshold + 4x limit prevents OOM kills (critical for .NET)
- **Burst Capacity:** 4x CPU limit handles temporary load spikes from .NET workloads

### 2. **REST API**
- **Image:** `acme/api`
- **Path:** `www.acme.com/api` (path-based routing, replaces domain-based api.acme.com)
- **Port:** 443 (HTTPS only, no HTTP)
- **Public:** Yes
- **Replicas:** 2+ (min) to 20+ (max, configurable via HPA)
- **Request Timeout:** 600 seconds (connect, send, read, body - backend processing)
- **Description:** .NET Core stateless REST API backend serving application logic
- **Environment Variables:**
  - `POSTGRES_URL` - Connection string to PostgreSQL
  - `METRICS_URL` - Endpoint for metrics collection
- **CORS Optimization:** Path-based routing (acme.com/api) avoids cross-origin configuration issues

**Resource Configuration (.NET Core Optimized):**
```
CPU Request:    250m      # .NET runtime baseline (~100-150m) + headroom
CPU Limit:      1000m     # 4x request for burst handling
Memory Request: 256Mi     # .NET GC + heap + application buffer
Memory Limit:   1Gi       # 4x request, critical for OOM prevention
```

**Horizontal Pod Autoscaling (HPA):**
```
Minimum Replicas:  2
Maximum Replicas:  20
CPU Threshold:     70%  # .NET responds well to CPU-based scaling
Memory Threshold:  80%  # Scale early to avoid OOM kills
```

**Rationale for .NET Core:**
- **.NET Runtime:** Requires ~100-150MB baseline for CLR + GC overhead
- **CPU Scaling:** 70% threshold optimal for API workloads; prevents request queuing
- **Memory Protection:** 80% threshold + 4x limit prevents OOM kills during traffic spikes
- **Burst Capacity:** 4x CPU limit handles API request bursts and complex operations
- **Request Timeout:** 600s accommodates long-running .NET operations (async processing, batch jobs)

### 3. **PostgreSQL Database**
- **Version:** 16 (latest)
- **Port:** 5432
- **Public:** No (private subnet, cluster-isolated)
- **Instances:** 3 (HA cluster configuration)
- **High Availability:** CloudNativePG operator for multi-node cluster
  - 1 Primary + 2 Read Replicas
  - Automatic failover
  - Streaming replication
- **Persistent Storage:** 
  - Storage Class: `standard` (configurable)
  - Each instance gets dedicated PVC
- **Backup & Recovery:**
  - RTO: 5 minutes (Recovery Time Objective)
  - RPO: 1 minute (Recovery Point Objective)
  - Automated backups via WAL archiving

### 4. **Metrics Collector**
- **Purpose:** Prometheus metrics aggregation
- **Port:** 8888 (internal collection)
- **Public:** No
- **Components:**
  - OpenTelemetry Collector (DaemonSet/Deployment)
  - Prometheus server
  - Custom metrics scrapers

---

## Deployment Architecture

### Kubernetes Namespaces

| Namespace | Purpose | Status |
|-----------|---------|--------|
| `application` | UI & API Pods | Core |
| `database` | PostgreSQL cluster | Core |
| `monitoring` | Prometheus & Grafana | Optional |
| `observability` | OpenTelemetry, Jaeger, Tempo | Optional |
| `ingress-nginx` | NGINX Ingress Controller | Core |
| `cert-manager` | Certificate management | Optional (recommended) |
| `argocd` | CI/CD orchestration | Optional |

### Helm Charts Deployed

| Chart | Source | Namespace | Purpose |
|-------|--------|-----------|---------|
| ACME Application | Local (`./helm/acme`) | `application` | UI & API services |
| NGINX Ingress | `ingress-nginx` | `ingress-nginx` | Traffic routing & TLS |
| cert-manager | `jetstack/cert-manager` | `cert-manager` | SSL/TLS certificate automation |
| External Secrets | `external-secrets/external-secrets` | `external-secrets` | Secret management from external vaults |
| Istio | `istio/istio` | `istio-system` | Service mesh (optional) |
| Prometheus | `kube-prometheus-stack` | `monitoring` | Metrics collection & storage |
| Grafana | `grafana/grafana` | `monitoring` | Metrics visualization |
| OpenTelemetry Collector | `open-telemetry/opentelemetry-collector` | `observability` | Trace & metric collection |
| Jaeger | `jaegertracing/jaeger` | `observability` | Distributed tracing (query UI) |
| Grafana Tempo | `grafana/tempo` | `observability` | Trace storage backend |
| CloudNativePG | `cloudnative-pg/cloudnative-pg` | `database` | PostgreSQL operator |
| ArgoCD | `argoproj/argo-cd` | `argocd` | GitOps continuous deployment |
| Velero | `vmware-tanzu/velero` | `velero` | Backup & disaster recovery |

### Terraform Modules

```
modules/
├── application/     # ACME UI & API Helm chart deployment
├── ingress/         # NGINX Ingress Controller setup
├── security/        # cert-manager, External Secrets, Istio, Network Policies
├── database/        # PostgreSQL HA cluster via CloudNativePG
├── monitoring/      # Prometheus & Grafana
├── cicd/            # ArgoCD deployment
├── observability/   # OpenTelemetry, Jaeger, Tempo
└── backup/          # Velero backup & disaster recovery
```

---

## Security

### HTTPS/TLS Termination
- **NGINX Ingress Controller** handles all TLS termination
- **cert-manager** automates certificate provisioning and renewal (when enabled)
- **TLS Secret:** `acme-tls` (referenced in Ingress resource)
- **Certificate Lifecycle:**
  - Configurable via Ingress annotations: `cert-manager.io/cluster-issuer`
  - Default issuer: `letsencrypt-prod` (optional, when cert-manager enabled)
- **Request Timeouts:**
  - Proxy Connect Timeout: 600 seconds
  - Proxy Send Timeout: 600 seconds
  - Proxy Read Timeout: 600 seconds
  - Proxy Body Timeout: 600 seconds
  - Max body size: 20MB
  - Log format: Upstream log format (detailed request information)
  - Worker Configuration: Auto-scaling workers with 2048 connections per worker

### Secret Management
- **External Secrets Operator** (optional) integrates with external vaults:
  - AWS Secrets Manager
  - HashiCorp Vault
  - Azure Key Vault
  - Google Secret Manager
- Database passwords stored as Kubernetes Secrets
- Sensitive Terraform variables marked with `sensitive = true`

### Network Security

#### Network Policies
- Implemented in `modules/security/network_policy.tf`
- **Egress Rules:** Restrict outbound traffic
  - API → PostgreSQL only (port 5432)
  - API → Metrics Collector only
  - API → External APIs (configurable)
- **Ingress Rules:** Restrict inbound traffic
  - NGINX → API (port 3000)
  - NGINX → UI (port 3000)
  - Database accessible only from application namespace
  - Observability components access limited to collection endpoints

#### Service Mesh (Istio - Optional)
- Provides mTLS between services
- Fine-grained traffic policies
- Circuit breakers & retries
- Rate limiting & fault injection for testing

### Database Security
- PostgreSQL runs in private namespace (not exposed to internet)
- Authentication: username/password (configurable)
- Network Policies restrict pod-to-pod access
- No public IP assigned to database service

---

## Scalability

### High Availability (NGINX Ingress)
- **Replicas:** 2 (minimum for HA)
- **Pod Disruption Budget:** Ensures 1 replica remains during maintenance
- **Pod Anti-Affinity:** Spreads replicas across different nodes
- **Metrics:** Enabled for Prometheus monitoring
- **Security:** Non-root container, read-only filesystem

### Horizontal Pod Autoscaling (HPA) - .NET Core Optimized
- **UI & API Pods:** Auto-scale based on CPU (70%) and Memory (80%) utilization
- **Configured Replicas:** 2 (minimum) → 20 (maximum, .NET workload scaling)
- **Metrics Source:** Kubernetes Metrics Server (built-in)
- **CPU Threshold (70%):** Optimal for .NET; prevents CPU thrashing, maintains responsiveness
- **Memory Threshold (80%):** Early scale trigger prevents OOM kills critical for .NET GC

### Resource Management (.NET Core Optimized)
```
Application Pods (.NET Core):
  CPU Request:     250m      # .NET runtime baseline (~100-150m) + headroom
  CPU Limit:       1000m     # 4x request for burst handling
  Memory Request:  256Mi     # .NET GC + heap + buffer
  Memory Limit:    1Gi       # 4x request, prevents OOM
  Min Replicas:    2
  Max Replicas:    20

NGINX Ingress Controller (HA):
  Replicas:        2
  CPU Request:     250m      # Per replica baseline
  CPU Limit:       1000m     # 4x request for peak handling
  Memory Request:  256Mi     # Connection buffers (~10KB per conn)
  Memory Limit:    512Mi     # Memory leak protection
  Pod Disruption:  minAvailable = 1
  Client timeout:  600s      # Long-running .NET operations
  Upstream timeout: 60s
  Worker Conn:     2048 per worker

OpenTelemetry Collector:
  CPU Request:     100m
  CPU Limit:       500m
  Memory Request:  128Mi
  Memory Limit:    512Mi
```

**Total Cluster Resources (minimum 2-node cluster):**
- **Per Node Requests:** 250m (NGINX) + 250m*2 (2x app) = 750m CPU, 256Mi + 256Mi*2 = 768Mi memory
- **Per Node Limits:** 1000m (NGINX) + 1000m*2 (2x app) = 3000m CPU, 512Mi + 1Gi*2 = 2.5Gi memory
- **Recommendation:** 4-8 CPU cores, 8-16GB memory per node minimum for .NET workloads

### Database Scalability
- **CloudNativePG HA cluster** with 3 instances
- Read replicas handle read-heavy workloads
- Stateless API layer scales independently
- Connection pooling recommended (PgBouncer or similar)

---

## Disaster Recovery

### Strategy

| Objective | Target | Implementation |
|-----------|--------|-----------------|
| **RTO** (Recovery Time) | 5 minutes | CloudNativePG failover automation |
| **RPO** (Recovery Point) | 1 minute | Continuous WAL streaming replication |
| **Backup Frequency** | Continuous | Streaming replication + WAL archiving |

### PostgreSQL HA Features
- **Automatic Failover:** Primary → Replica promotion (< 1 minute)
- **Streaming Replication:** Real-time WAL log shipping
- **Standby Clusters:** Support for geographically distributed replicas
- **Point-in-Time Recovery (PITR):** Restore to any point in transaction history

### Application Layer Recovery
- **Stateless Design:** Pods are ephemeral; data persists in PostgreSQL
- **ConfigMaps & Secrets:** Version-controlled via Git (ArgoCD)
- **Persistent Volumes:** PVC-backed storage survives pod restarts
- **Image Registry:** Container images must be accessible during recovery

### Velero Backup & Disaster Recovery
- **Scheduled Backups:** Automated daily backups of database and application configs
  - Database backups: Daily at 2 AM UTC
  - Application config backups: Daily at 3 AM UTC
- **Backup Retention:** 30 days default (configurable) 1 year for enterprise
- **Backup Scope:**
  - **Database:** PersistentVolumeClaims from `database` namespace
  - **Application Config:** ConfigMaps, Secrets, Deployments, Services, Ingresses from `application` namespace
- **Volume Snapshots:** Enabled for PVC-backed data
- **Storage Locations:** Local storage
- **Restore Capabilities:**
  - Point-in-time restore of specific resources
  - Full cluster restore from backups
  - Restore to same or different cluster
- **Monitoring:** Prometheus metrics from Velero for backup success/failure tracking

---

## Observability

### Metrics Collection

**Prometheus** (port 9090)
- Scrapes Kubernetes metrics from:
  - Node exporter
  - cAdvisor
  - Kubelet
  - Application custom metrics (via OTLP)
- 15-day default retention
- Alert rules can be defined for SLA monitoring

**Metrics Exposed by Application:**
- HTTP request rate & latency
- Error rates
- Custom business metrics (configurable)

### Visualization

**Grafana** (port 3000)
- Pre-built dashboards:
  - Kubernetes cluster health
  - Node & pod resource utilization
  - Application performance
  - Database health & replication status
- User-defined dashboards for custom metrics
- Alert integration with PagerDuty, Slack, etc.

### Distributed Tracing & Correlation ID

**Overview**
The platform supports distributed tracing across all .NET microservices using correlation IDs. Each request is assigned a unique identifier that propagates through the entire request chain, enabling end-to-end request tracing and debugging.

**OpenTelemetry Collector**
- Collects traces from instrumented applications
- Protocols supported:
  - OTLP gRPC (port 4317)
  - OTLP HTTP (port 4318)
  - Jaeger (port 14250)
  - Other legacy protocols
- Trace context format: **W3C Trace Context** (default; supports Jaeger, B3, OT Trace)
- Resource detection: Kubernetes labels and cloud provider metadata

**Jaeger** (Distributed Tracing)
- Query UI: traces visualization & search
- Backend storage: in-memory or Elasticsearch-backed
- Sampling: 10% default (configurable per environment)
- Accessible at: `http://jaeger-query.observability:16686`

**Grafana Tempo** (Trace Storage)
- Long-term trace storage (alternative to Jaeger)
- Storage backend: PersistentVolume (10Gi default)
- Integrated with Grafana for trace visualization
- Accessible at: `http://tempo.observability:3100`

#### Correlation ID Configuration

**Default Configuration:**
- **HTTP Header:** `X-Correlation-ID`
- **Format:** UUID v4 (e.g., `550e8400-e29b-41d4-a716-446655440000`)
- **Propagation:** W3C Trace Context standard
- **Baggage Support:** Enabled (cross-service context propagation)

**Configurable Variables** (in `modules/observability/variables.tf`):
```hcl
variable "enable_correlation_id_propagation" {
  default = true  # Enable/disable correlation ID support
}

variable "correlation_id_header_name" {
  default = "X-Correlation-ID"  # Custom header name
}

variable "trace_context_format" {
  default = "w3c"  # w3c, jaeger, b3, or ottrace
}

variable "enable_baggage_propagation" {
  default = true  # Propagate context across services
}
```

#### .NET Application Integration

**.NET Instrumentation Setup Examples**

1. **Install NuGet Packages:**
```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package System.Diagnostics.DiagnosticSource
```

2. **Configure in Program.cs** (ASP.NET Core):
```csharp
using OpenTelemetry.Trace;
using OpenTelemetry.Resources;
using OpenTelemetry.Exporter;

var builder = WebApplication.CreateBuilder(args);

// Configure OpenTelemetry tracing
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => 
        resource.AddService(
            serviceName: "acme-api",
            serviceVersion: "1.0.0"))
    .WithTracing(tracing => 
        tracing
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddEntityFrameworkCoreInstrumentation()
            .AddOtlpExporter(opt =>
            {
                opt.Endpoint = new Uri(
                    Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT") 
                    ?? "http://opentelemetry-collector.observability.svc:4317");
                opt.Protocol = OtlpExportProtocol.Grpc;
            }));

var app = builder.Build();
app.Run();
```

3. **Environment Variables** (Kubernetes Deployment):
```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://opentelemetry-collector.observability.svc:4317"
  - name: OTEL_SERVICE_NAME
    value: "acme-api"
  - name: OTEL_TRACES_SAMPLER
    value: "parentbased_always_on"
  - name: OTEL_PROPAGATORS
    value: "jaeger,baggage"
```

4. **Correlation ID Middleware** (.NET):
```csharp
// Add custom middleware to handle correlation IDs
public class CorrelationIdMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<CorrelationIdMiddleware> _logger;

    public CorrelationIdMiddleware(RequestDelegate next, 
        ILogger<CorrelationIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        const string correlationIdHeader = "X-Correlation-ID";
        
        // Get or generate correlation ID
        var correlationId = context.Request.Headers
            .TryGetValue(correlationIdHeader, out var headerValue) 
            ? headerValue.ToString() 
            : System.Guid.NewGuid().ToString();
        
        // Store in HttpContext for application access
        context.Items["CorrelationId"] = correlationId;
        
        // Add to response headers
        context.Response.Headers.Add(correlationIdHeader, correlationId);
        
        // Add to logging scope
        using (_logger.BeginScope(new Dictionary<string, object> 
            { { "CorrelationId", correlationId } }))
        {
            _logger.LogInformation("Request started with correlation ID: {CorrelationId}", 
                correlationId);
            
            await _next(context);
            
            _logger.LogInformation("Request completed with correlation ID: {CorrelationId}", 
                correlationId);
        }
    }
}

// Register in Program.cs
app.UseMiddleware<CorrelationIdMiddleware>();
```

#### Tracing Workflow

```
Client Request
    │
    ├─ Header: X-Correlation-ID: abc-123
    │
    ▼
NGINX Ingress (TLS Termination)
    │
    ├─ Forward X-Correlation-ID header
    │
    ▼
API Pod (acme-api)
    │
    ├─ CorrelationIdMiddleware extracts/generates ID
    ├─ Stores in HttpContext.Items
    ├─ Adds trace context to OpenTelemetry span
    │
    ▼
Downstream Service Call (acme-worker, etc.)
    │
    ├─ HttpClient adds X-Correlation-ID header
    ├─ OpenTelemetry adds W3C Trace-Parent header
    │
    ▼
OpenTelemetry Collector
    │
    ├─ Receives traces from all services
    ├─ Enriches with Kubernetes metadata
    ├─ Applies sampling (10% default)
    │
    ├─ Export to Jaeger
    │   └─ Real-time trace queries
    │
    └─ Export to Tempo
        └─ Long-term storage & analysis

Trace Lookup (Jaeger/Tempo UI)
    │
    ├─ Search by Correlation ID: abc-123
    ├─ View full request chain across services
    ├─ Analyze latency per service
    └─ Identify errors and bottlenecks
```

#### Monitoring Correlation IDs

**Sample Grafana Dashboard Queries:**

```promql
# Traces per correlation ID (Tempo)
sum by (correlation_id) (
  rate(tempo_distributor_trace_received_total[5m])
)

# Error rate by correlation ID
sum by (correlation_id) (
  rate(
    tempo_distributor_trace_received_total
    {span_status="error"}[5m]
  )
) / 
sum by (correlation_id) (
  rate(tempo_distributor_trace_received_total[5m])
)

# P95 latency by service
histogram_quantile(0.95, 
  rate(
    otel_rpc_server_duration_seconds_bucket[5m]
  )
)
```

#### Troubleshooting

**Check if correlation ID is propagating:**
```bash
# View logs with correlation ID
kubectl logs -n application <pod-name> | grep "X-Correlation-ID"

# Port-forward to Jaeger and search
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Open http://localhost:16686 and search by trace ID
```

**Verify OTEL Collector is receiving traces:**
```bash
# Check collector logs
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector | grep received

# Check for errors
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector | grep -i error
```

**Test correlation ID propagation locally:**
```bash
# Start a request with correlation ID header
curl -H "X-Correlation-ID: test-123" http://localhost:8000/api/data
```

### Health Checks

The platform uses comprehensive health checks for .NET applications to monitor pod lifecycle and resource utilization. All services implement three probe types that work together to ensure only healthy pods receive traffic.

#### .NET Health Check Implementation

**1. Install AspNetCore.HealthChecks NuGet Package:**
```bash
dotnet add package AspNetCore.HealthChecks.UI
dotnet add package AspNetCore.HealthChecks.SqlServer
dotnet add package HealthChecks.ApplicationStatus
```

**2. Configure Health Checks in Program.cs:**
```csharp
using HealthChecks.UI.Client;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

// Add health checks
builder.Services
    .AddHealthChecks()
    // Database connectivity check
    .AddSqlServer(
        connectionString: builder.Configuration.GetConnectionString("PostgreSQL"),
        name: "database",
        failureStatus: HealthStatus.Unhealthy,
        timeout: TimeSpan.FromSeconds(5))
    // CPU and Memory checks (custom)
    .AddCheck("cpu-usage", new CpuHealthCheck(threshold: 80), 
        HealthStatus.Degraded, tags: new[] { "metrics" })
    .AddCheck("memory-usage", new MemoryHealthCheck(threshold: 85), 
        HealthStatus.Degraded, tags: new[] { "metrics" })
    .AddCheck("request-queue", new RequestQueueHealthCheck(threshold: 100), 
        HealthStatus.Degraded, tags: new[] { "metrics" });

var app = builder.Build();

// Health check endpoints
app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = healthcheck => healthcheck.Tags.Contains("live"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    Predicate = healthcheck => healthcheck.Tags.Contains("ready"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/detailed", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.Run();
```

**3. Custom Health Check Classes:**

**CPU Usage Check:**
```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Diagnostics;

public class CpuHealthCheck : IHealthCheck
{
    private readonly int _threshold; // Percentage (0-100)
    private readonly Process _currentProcess;

    public CpuHealthCheck(int threshold = 80)
    {
        _threshold = threshold;
        _currentProcess = Process.GetCurrentProcess();
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var startTime = DateTime.UtcNow;
        var startCpuUsage = _currentProcess.TotalProcessorTime;

        System.Threading.Thread.Sleep(100); // Sample over 100ms

        var endTime = DateTime.UtcNow;
        var endCpuUsage = _currentProcess.TotalProcessorTime;

        var cpuUsedMs = (endCpuUsage - startCpuUsage).TotalMilliseconds;
        var totalMsPassed = (endTime - startTime).TotalMilliseconds;
        var cpuUsageTotal = cpuUsedMs / (Environment.ProcessorCount * totalMsPassed);
        var cpuPercent = cpuUsageTotal * 100;

        var status = cpuPercent < _threshold 
            ? HealthStatus.Healthy 
            : HealthStatus.Degraded;

        var data = new Dictionary<string, object>
        {
            { "CPU Usage (%)", Math.Round(cpuPercent, 2) },
            { "Threshold (%)", _threshold },
            { "Status", status.ToString() }
        };

        var message = $"CPU usage is {Math.Round(cpuPercent, 2)}% (threshold: {_threshold}%)";
        
        return Task.FromResult(
            status == HealthStatus.Healthy
                ? HealthCheckResult.Healthy(message, data)
                : HealthCheckResult.Degraded(message, null, data));
    }
}
```

**Memory Usage Check:**
```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Diagnostics;

public class MemoryHealthCheck : IHealthCheck
{
    private readonly int _threshold; // Percentage (0-100)

    public MemoryHealthCheck(int threshold = 85)
    {
        _threshold = threshold;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var process = Process.GetCurrentProcess();
        var workingSetMb = process.WorkingSet64 / (1024 * 1024);
        
        // Container memory limit from environment (Kubernetes)
        var memoryLimitMb = long.TryParse(
            Environment.GetEnvironmentVariable("MEMORY_LIMIT_MB"), 
            out var limit) 
            ? limit 
            : 1024; // Default to 1GB if not set

        var memoryPercent = (double)workingSetMb / memoryLimitMb * 100;

        var status = memoryPercent < _threshold 
            ? HealthStatus.Healthy 
            : HealthStatus.Degraded;

        var data = new Dictionary<string, object>
        {
            { "Working Set (MB)", Math.Round((double)workingSetMb, 2) },
            { "Memory Limit (MB)", memoryLimitMb },
            { "Usage (%)", Math.Round(memoryPercent, 2) },
            { "Threshold (%)", _threshold }
        };

        var message = $"Memory usage is {Math.Round(memoryPercent, 2)}% of {memoryLimitMb}MB (threshold: {_threshold}%)";

        return Task.FromResult(
            status == HealthStatus.Healthy
                ? HealthCheckResult.Healthy(message, data)
                : HealthCheckResult.Degraded(message, null, data));
    }
}
```

**Request Queue Check:**
```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;

public class RequestQueueHealthCheck : IHealthCheck
{
    private readonly int _threshold; // Max queued requests

    public RequestQueueHealthCheck(int threshold = 100)
    {
        _threshold = threshold;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        // Track request queue via middleware
        var queuedRequests = RequestQueueMiddleware.QueuedRequestCount;
        var status = queuedRequests < _threshold 
            ? HealthStatus.Healthy 
            : HealthStatus.Degraded;

        var data = new Dictionary<string, object>
        {
            { "Queued Requests", queuedRequests },
            { "Threshold", _threshold }
        };

        var message = $"{queuedRequests} requests queued (threshold: {_threshold})";

        return Task.FromResult(
            status == HealthStatus.Healthy
                ? HealthCheckResult.Healthy(message, data)
                : HealthCheckResult.Degraded(message, null, data));
    }
}

// Middleware to track queued requests
public class RequestQueueMiddleware
{
    public static int QueuedRequestCount = 0;
    private readonly RequestDelegate _next;

    public RequestQueueMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        Interlocked.Increment(ref QueuedRequestCount);
        try
        {
            await _next(context);
        }
        finally
        {
            Interlocked.Decrement(ref QueuedRequestCount);
        }
    }
}

// Register in Program.cs
app.UseMiddleware<RequestQueueMiddleware>();
```

**4. Kubernetes Probe Configuration:**

**Liveness Probe** (Restart pod if unhealthy):
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
    scheme: HTTP
  initialDelaySeconds: 30      # Wait 30s before first check
  periodSeconds: 10             # Check every 10s
  timeoutSeconds: 5             # Timeout after 5s
  failureThreshold: 3           # Fail after 3 consecutive failures
  successThreshold: 1           # Success after 1 passing check
```

**Readiness Probe** (Remove from load balancer if not ready):
```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
    scheme: HTTP
  initialDelaySeconds: 10       # Wait 10s before first check
  periodSeconds: 5              # Check every 5s
  timeoutSeconds: 3             # Timeout after 3s
  failureThreshold: 2           # Fail after 2 consecutive failures
  successThreshold: 1           # Success after 1 passing check
```

**Startup Probe** (Support slow-starting .NET apps):
```yaml
startupProbe:
  httpGet:
    path: /health/live
    port: 8080
    scheme: HTTP
  initialDelaySeconds: 0
  periodSeconds: 10             # Check every 10s
  timeoutSeconds: 5             # Timeout after 5s
  failureThreshold: 30          # Allow 30 failures × 10s = 5 minutes startup time
  successThreshold: 1           # Success after 1 passing check
```

**Complete Kubernetes Deployment Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: acme-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: acme-api
  template:
    metadata:
      labels:
        app: acme-api
    spec:
      containers:
      - name: acme-api
        image: acme/api:latest
        ports:
        - containerPort: 8080
        
        # Environment variables for health checks
        env:
        - name: MEMORY_LIMIT_MB
          valueFrom:
            resourceFieldRef:
              containerResource: limits.memory
              divisor: 1Mi
        
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        
        # Liveness: Restart if repeatedly unhealthy
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        # Readiness: Remove from load balancer if not ready
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        
        # Startup: Allow time for .NET runtime initialization
        startupProbe:
          httpGet:
            path: /health/live
            port: 8080
          periodSeconds: 10
          failureThreshold: 30
```

#### Health Check Endpoints

| Endpoint | Purpose | Probes | Metrics |
|----------|---------|--------|---------|
| `/health/live` | Application is running | Liveness, Startup | Basic status |
| `/health/ready` | Application is ready to receive traffic | Readiness | Dependencies (DB, cache) |
| `/health/detailed` | Comprehensive health report | Manual checks | CPU, memory, requests, database |

**Sample Response** (`/health/detailed`):
```json
{
  "status": "Degraded",
  "totalDuration": "00:00:00.2456789",
  "entries": {
    "database": {
      "data": {},
      "description": null,
      "duration": "00:00:00.0123456",
      "status": "Healthy",
      "tags": []
    },
    "cpu-usage": {
      "data": {
        "CPU Usage (%)": 45.67,
        "Threshold (%)": 80,
        "Status": "Healthy"
      },
      "description": "CPU usage is 45.67% (threshold: 80%)",
      "duration": "00:00:00.0654321",
      "status": "Healthy",
      "tags": ["metrics"]
    },
    "memory-usage": {
      "data": {
        "Working Set (MB)": 312.5,
        "Memory Limit (MB)": 1024,
        "Usage (%)": 30.52,
        "Threshold (%)": 85
      },
      "description": "Memory usage is 30.52% of 1024MB (threshold: 85%)",
      "duration": "00:00:00.0234567",
      "status": "Healthy",
      "tags": ["metrics"]
    },
    "request-queue": {
      "data": {
        "Queued Requests": 5,
        "Threshold": 100
      },
      "description": "5 requests queued (threshold: 100)",
      "duration": "00:00:00.0012345",
      "status": "Healthy",
      "tags": ["metrics"]
    }
  }
}
```

#### Health Check Monitoring

**Prometheus Metrics:**
- `health_check_status` - 1 (healthy) or 0 (unhealthy)
- `health_check_cpu_percent` - CPU usage percentage
- `health_check_memory_mb` - Memory usage in MB
- `health_check_request_queue` - Queued requests count

**Grafana Dashboard Queries:**
```promql
# Pod health status
health_check_status{pod="acme-api"}

# Memory trend (last 1 hour)
health_check_memory_mb{pod="acme-api"}[1h]

# CPU usage over time
health_check_cpu_percent{pod="acme-api"}[5m]

# Request queue depth
rate(health_check_request_queue{pod="acme-api"}[1m])
```

#### Health Check Best Practices

1. **Startup Probe (5 min timeout):** Accommodates .NET runtime JIT compilation and database initialization
2. **Readiness Probe (fast check):** Validates dependencies are healthy before routing traffic
3. **Liveness Probe (moderate check):** Detects hung or deadlocked processes
4. **Resource Thresholds:** CPU 80%, Memory 85% to trigger degraded state before limits
5. **Monitoring:** Export metrics to Prometheus for alerting on health trends

#### Troubleshooting Health Checks

**Pod stuck in NotReady:**
```bash
# Check readiness probe status
kubectl describe pod <pod-name> -n application

# Test endpoint directly
kubectl port-forward <pod-name> 8080:8080
curl http://localhost:8080/health/detailed
```

**High CPU/Memory in health checks:**
```bash
# Adjust thresholds in custom health check classes
# Or increase resource limits in Kubernetes manifest
```

**Health checks timing out:**
```bash
# Increase initialDelaySeconds for slow startup
# Increase timeoutSeconds if checks take long
# Verify network connectivity to dependencies
```

---

## Resource Tagging & Cost Management

### Tagging Strategy

All Kubernetes resources are comprehensively tagged using labels and annotations for:
- **Cost allocation** and billing analysis
- **Resource organization** and lifecycle management
- **Automation** and policy enforcement
- **Monitoring** and alerting

### Standard Labels

All resources receive the following standardized labels:

| Label | Value | Purpose |
|-------|-------|---------|
| `app.kubernetes.io/name` | Component name (e.g., `ingress-nginx`, `acme-database`) | Identifies the application/service |
| `app.kubernetes.io/component` | Component type (e.g., `ingress-controller`, `database`, `application`) | Categorizes the component type |
| `app.kubernetes.io/managed-by` | `terraform` | Indicates infrastructure-as-code ownership |
| `environment` | `dev`, `staging`, `prod` | Deployment environment (configurable) |
| `project` | `acme` | Project identifier (configurable) |
| `owner` | `platform` | Team responsible (configurable) |
| `cost-center` | Engineering team | For billing and cost allocation |
| `namespace-purpose` | Purpose of namespace | Clarifies namespace function |
| `resource-type` | Resource kind (e.g., `ingress`, `service`) | Resource classification |
| `managed-by` | `terraform` | IaC management indicator |

### Per-Module Tagging

Each Terraform module applies tags to its resources:

| Module | Resources Tagged | Component Label | Namespace Label |
|--------|------------------|-----------------|-----------------|
| `ingress` | NGINX Ingress, Namespace | `ingress-controller` | `ingress-controller` |
| `application` | Helm Release, Namespace | `application` | `application-services` |
| `database` | CloudNativePG, Namespace | `database` | `database-services` |
| `monitoring` | Prometheus, Grafana, Namespace | `monitoring` | `monitoring-services` |
| `observability` | OTEL, Jaeger, Tempo, Namespace | `observability` | `observability-services` |
| `security` | cert-manager, Istio, Namespace | `security` | `security-services` |
| `cicd` | ArgoCD, Namespace | `cicd` | `cicd-services` |
| `backup` | Velero, Namespace | `backup` | `backup-services` |

### Configurable Variables

All modules expose tagging variables for customization:

```hcl
# Apply custom environment and owner tags
terraform apply \
  -var="environment=prod" \
  -var="project_name=acme" \
  -var="owner=devops-team" \
  -var='common_tags={"cost-center":"engineering","team":"platform"}'
```

### Cost Management Integration

**Tagging enables:**
1. **Cost allocation**: Group expenses by `environment`, `project`, `owner`
2. **Budget enforcement**: Set policies based on tags
3. **Resource cleanup**: Identify and remove untagged resources
4. **Compliance**: Ensure all resources meet tagging requirements

**Example cost queries:**
```bash
# Cost by environment
kubectl get all --all-namespaces -L environment

# Cost by team
kubectl get all --all-namespaces -L owner

# Untagged resources (should be empty)
kubectl get all --all-namespaces -L project | grep '<none>'
```

### Label Selectors for Operations

Use labels to operate on resource groups:

```bash
# Scale all production application pods
kubectl scale deployment -l environment=prod,project=acme

# Delete all dev resources
kubectl delete all -l environment=dev

# Monitor staging resources
kubectl get pods -l environment=staging --watch

# Restart problematic pods by owner
kubectl rollout restart deployment -l owner=platform
```

---

## References

- [CloudNativePG Documentation](https://cloudnative-pg.io/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [NGINX Ingress Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/)
- [OpenTelemetry Best Practices](https://opentelemetry.io/docs/best-practices/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
- [Velero Documentation](https://velero.io/docs/main/)
