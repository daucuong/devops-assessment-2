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
9. [Deployment Guide](#deployment-guide)
10. [Justifications & Design Decisions](#justifications--design-decisions)
11. [Shortcomings & Future Improvements](#shortcomings--future-improvements)

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
    ┌────▼─────────┐              ┌────────▼────────┐
    │  www.acme.com│              │  api.acme.com   │
    └────┬─────────┘              └────────┬────────┘
         │                                  │
    ┌────▼──────────────────────────────────▼────┐
    │  NGINX Ingress Controller (TLS Termination)│
    │  - LoadBalancer Service                    │
    │  - SSL/TLS via cert-manager                │
    └────┬───────────────────────────────────────┘
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
- **Domain:** `www.acme.com`
- **Ports:** 80/443 (exposed via NGINX Ingress)
- **Public:** Yes
- **Replicas:** 2+ (configurable via HPA)
- **Description:** Static/client-side web frontend serving the ACME UI
- **Resource Limits:** 100m CPU request, 500m limit; 128Mi memory request, 512Mi limit

### 2. **REST API**
- **Image:** `acme/api`
- **Domain:** `api.acme.com`
- **Port:** 443 (HTTPS only, no HTTP)
- **Public:** Yes
- **Replicas:** 2+ (configurable via HPA)
- **Description:** Stateless REST API backend serving application logic
- **Environment Variables:**
  - `POSTGRES_URL` - Connection string to PostgreSQL
  - `METRICS_URL` - Endpoint for metrics collection
- **Resource Limits:** 100m CPU request, 500m limit; 128Mi memory request, 512Mi limit

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

### Terraform Modules

```
modules/
├── application/     # ACME UI & API Helm chart deployment
├── ingress/         # NGINX Ingress Controller setup
├── security/        # cert-manager, External Secrets, Istio, Network Policies
├── database/        # PostgreSQL HA cluster via CloudNativePG
├── monitoring/      # Prometheus & Grafana
├── cicd/            # ArgoCD deployment
└── observability/   # OpenTelemetry, Jaeger, Tempo
```

---

## Security

### HTTPS/TLS Termination
- **NGINX Ingress Controller** handles all TLS termination
- **cert-manager** automates certificate provisioning and renewal
- Supports Let's Encrypt (staging and production)
- Configurable via Ingress annotations: `cert-manager.io/cluster-issuer`
- Default issuer: `letsencrypt-prod`

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

### Horizontal Pod Autoscaling (HPA)
- **UI & API Pods:** Auto-scale based on CPU utilization
- **Configured Replicas:** 2 (minimum) → configurable maximum
- **Metrics Source:** Kubernetes Metrics Server (built-in)

### Resource Management
```
Application Pods:
  CPU Request:     100m
  CPU Limit:       500m
  Memory Request:  128Mi
  Memory Limit:    512Mi

NGINX Controller:
  CPU Request:     100m
  CPU Limit:       500m
  Memory Request:  90Mi
  Memory Limit:    512Mi

OpenTelemetry Collector:
  CPU Request:     100m
  CPU Limit:       500m
  Memory Request:  128Mi
  Memory Limit:    512Mi
```

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

### Backup Recommendations
1. **WAL Archiving:** Store PostgreSQL WAL files in S3/GCS/Blob storage
2. **Full Database Backups:** Regular snapshots (daily/weekly)
3. **Infrastructure State:** Terraform state backed up to secure storage
4. **GitOps Repository:** All manifests version-controlled in Git (required for ArgoCD)

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

### Distributed Tracing

**OpenTelemetry Collector**
- Collects traces from instrumented applications
- Protocols supported:
  - OTLP gRPC (port 4317)
  - OTLP HTTP (port 4318)
  - Jaeger (port 14250)
  - Other legacy protocols

**Jaeger** (Distributed Tracing)
- Query UI: traces visualization & search
- Backend storage: in-memory or Elasticsearch-backed
- Sampling: 10% default (configurable)

**Grafana Tempo** (Trace Storage)
- Long-term trace storage (alternative to Jaeger)
- Storage backend: PersistentVolume (10Gi default)
- Integrated with Grafana for trace visualization

### Health Checks
- **Liveness Probe:** Pod restart on failure
- **Readiness Probe:** Remove from load balancer if not ready
- **Startup Probe:** Support for slow-starting applications

---

## Deployment Guide

### Prerequisites
- Kubernetes cluster (v1.28+)
- `kubectl` configured with cluster access
- Terraform (v1.0+)
- Helm (v3.0+)

### Environment Setup

1. **Create kubeconfig reference:**
   ```bash
   export KUBECONFIG=~/.kube/config
   export KUBE_CONTEXT=your-cluster-context
   ```

2. **Clone repository:**
   ```bash
   git clone https://github.com/daucuong/devops-assessment.git
   cd devops-assessment-2
   ```

3. **Configure variables:**
   - Edit `terraform.tfvars` for your environment
   - Set sensitive values: database password, Grafana password, Git credentials

### Deployment Steps

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Plan infrastructure:**
   ```bash
   terraform plan -out=tfplan
   ```

3. **Apply changes:**
   ```bash
   terraform apply tfplan
   ```

4. **Verify deployment:**
   ```bash
   kubectl get namespaces
   kubectl get pods -A
   kubectl get svc -A
   ```

5. **Access services:**
   - **UI:** https://www.acme.com (requires DNS pointing to Ingress IP)
   - **API:** https://api.acme.com
   - **Grafana:** `kubectl port-forward -n monitoring svc/grafana 3000:80`
   - **ArgoCD:** `kubectl port-forward -n argocd svc/argocd-server 8080:443`
   - **Jaeger:** `kubectl port-forward -n observability svc/jaeger-query 16686:16686`

### GitOps Setup (ArgoCD)

1. **Connect Git repository:**
   ```
   ArgoCD UI → Settings → Repositories → Connect repo
   ```

2. **Create Application:**
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: acme-app
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/daucuong/devops-assessment.git
       targetRevision: main
       path: k8s
     destination:
       server: https://kubernetes.default.svc
       namespace: application
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

3. **Automatic deployments:**
   - Any commit to `k8s/` directory triggers deployment
   - Failed deployments auto-rollback to previous version

---

## Justifications & Design Decisions

### 1. **Kubernetes as Orchestration Platform**
- **Why:** Industry standard for cloud-native applications, excellent scalability, vendor-agnostic
- **Trade-offs:** Operational complexity, requires cluster management expertise
- **Mitigation:** Use managed K8s services (EKS, GKE, AKS) to reduce operational burden

### 2. **Terraform for IaC**
- **Why:** Declarative, state-managed, broad provider support, excellent for multi-cloud
- **Trade-offs:** State file management, potential for drift
- **Mitigation:** Store state in remote backend (S3, Terraform Cloud), implement locking

### 3. **Helm for Package Management**
- **Why:** Industry standard, templating capabilities, version management
- **Trade-offs:** Templating can be complex; Kustomize is an alternative
- **Alternative:** Kustomize for simpler use cases, Pulumi for programmatic IaC

### 4. **NGINX Ingress Controller**
- **Why:** Lightweight, feature-rich, good performance
- **Trade-offs:** Limited to Layer 7; Istio provides more advanced routing
- **Alternative:** Istio (service mesh included), Traefik, Kong for API gateway features

### 5. **cert-manager for TLS**
- **Why:** Automates certificate lifecycle, integrates with Let's Encrypt
- **Trade-offs:** Additional CRD complexity
- **Why chosen:** Reduces manual certificate management burden

### 6. **CloudNativePG for PostgreSQL HA**
- **Why:** Native Kubernetes PostgreSQL operator, excellent HA support, PITR capability
- **Trade-offs:** Newer project vs. traditional managed databases
- **Alternatives:** 
  - AWS RDS PostgreSQL (managed, but vendor lock-in)
  - Patroni + StatefulSet (more complex, older approach)

### 7. **ArgoCD for GitOps**
- **Why:** Declarative, Git-driven deployments, automated sync, excellent RBAC
- **Trade-offs:** Additional component to manage
- **Alternatives:** Flux, Helm Operator, traditional CI/CD

### 8. **OpenTelemetry + Jaeger + Tempo**
- **Why:** Open standards, vendor-agnostic, comprehensive observability
- **Trade-offs:** Multiple components increase complexity
- **Simpler alternative:** ELK Stack, DataDog, New Relic (vendor solutions)

### 9. **Network Policies for Security**
- **Why:** Zero-trust networking, restricts lateral movement
- **Trade-offs:** Requires understanding of application communication
- **Enhancement:** Istio mTLS for encrypted service-to-service communication

---

## Shortcomings & Future Improvements

### Current Shortcomings

1. **Single Kubernetes Cluster**
   - No multi-region or multi-cloud support
   - Regional outage impacts all components
   - **Fix:** Implement multi-region active-active or active-passive setup

2. **Manual Secrets Management**
   - Secrets stored in `terraform.tfvars` (exposed in state file)
   - **Fix:** Integrate with HashiCorp Vault or cloud provider secret managers
   - **Implementation:** Enable External Secrets Operator module

3. **Limited Auto-Scaling Policies**
   - HPA only uses CPU metrics
   - No custom metric-based scaling
   - **Fix:** Implement custom metrics (request rate, queue depth) via KEDA

4. **Database Backup Strategy Incomplete**
   - No explicit WAL archiving configuration
   - **Fix:** Configure WAL archiving to S3/GCS/Blob storage
   - **Implementation:** Add backup policy to CloudNativePG spec

5. **No API Rate Limiting**
   - Vulnerable to abuse
   - **Fix:** Implement rate limiting at Ingress level (NGINX) or via Istio

6. **Monitoring Alerting Not Configured**
   - Prometheus collects metrics but no alert rules defined
   - **Fix:** Add PrometheusRule resources for critical metrics
   - **Example:** Database replication lag, API error rate > 5%

7. **No Pod Disruption Budgets**
   - Maintenance events could disrupt all replicas
   - **Fix:** Add PodDisruptionBudget for critical services

8. **Default Credentials**
   - Grafana, ArgoCD, PostgreSQL use weak/default passwords
   - **Fix:** Enforce strong passwords via Terraform variables and IaC

### Recommended Improvements

#### Priority 1 (Critical)
- [ ] Implement multi-region replication for database
- [ ] Configure WAL archiving for PostgreSQL backups
- [ ] Add comprehensive alert rules to Prometheus
- [ ] Enable RBAC for ArgoCD and restrict service account permissions
- [ ] Implement Pod Disruption Budgets for core services

#### Priority 2 (Important)
- [ ] Add Istio for advanced traffic management and security policies
- [ ] Implement KEDA for custom metric-based autoscaling
- [ ] Add API rate limiting at Ingress level
- [ ] Implement secret rotation policies
- [ ] Add comprehensive network policies for all namespaces

#### Priority 3 (Nice to Have)
- [ ] Implement service mesh observability (Kiali)
- [ ] Add container image scanning (Trivy/Snyk)
- [ ] Implement GitOps-based infrastructure updates
- [ ] Add multi-tenancy support via namespace isolation
- [ ] Implement cost monitoring and optimization

#### Technical Debt
- [ ] Abstract Helm values into configurable modules
- [ ] Add comprehensive test coverage for Terraform modules
- [ ] Create runbooks for common operational tasks
- [ ] Document troubleshooting procedures
- [ ] Implement canary deployments via Flagger

---

## Collaboration Points with Development Teams

### DevOps ↔ Application Teams

1. **Environment Variables**
   - Define all required env vars in documentation
   - Agree on default values for local development

2. **Health Checks**
   - Define liveness/readiness probe endpoints
   - Agree on timeout and failure thresholds

3. **Metrics Instrumentation**
   - Provide OpenTelemetry SDK examples
   - Define custom metrics to expose
   - Agree on sampling percentages

4. **Database Migrations**
   - Document migration procedures
   - Define rollback strategies
   - Agree on acceptable downtime

5. **Secret Management**
   - Define which values are secrets
   - Agree on secret rotation schedule
   - Provide examples of secret injection

6. **Observability SLOs**
   - Define success metrics (latency, error rate, availability)
   - Agree on alert severity levels
   - Establish oncall rotation

---

## References

- [CloudNativePG Documentation](https://cloudnative-pg.io/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/)
- [OpenTelemetry Best Practices](https://opentelemetry.io/docs/best-practices/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
