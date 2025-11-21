# Kubernetes with Helm - Terraform Configuration

Modular Terraform configuration for deploying applications to Docker Desktop's Kubernetes with Helm package management.

## Directory Structure

```
.
├── main.tf                          # Main configuration with module calls
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── terraform.tfvars                 # Variable values
├── modules/
│   ├── kubernetes/
│   │   ├── main.tf                  # Kubernetes resources
│   │   ├── variables.tf             # Kubernetes variables
│   │   └── outputs.tf               # Kubernetes outputs
│   └── helm/
│       ├── main.tf                  # Helm releases
│       ├── variables.tf             # Helm variables
│       └── outputs.tf               # Helm outputs
└── README.md
```

## Prerequisites

- Docker Desktop with Kubernetes enabled
- Terraform >= 1.0
- kubectl

## Enable Kubernetes in Docker Desktop

1. Open Docker Desktop preferences
2. Go to **Kubernetes** tab
3. Check **Enable Kubernetes**
4. Click **Apply & Restart**

Verify:
```bash
kubectl cluster-info
```

## Quick Start

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Review variables**
   ```bash
   cat terraform.tfvars
   ```

3. **Plan deployment**
   ```bash
   terraform plan
   ```

4. **Apply configuration**
   ```bash
   terraform apply
   ```

## Module Overview

### kubernetes Module
Manages Kubernetes resources:
- **Deployment**: Application with configurable replicas
- **Service**: ClusterIP/LoadBalancer/NodePort
- **Ingress**: NGINX ingress rules (optional)
- **ConfigMap**: Application configuration
- **HPA**: Horizontal Pod Autoscaler (optional)

**Variables**: Image, replicas, resources, ingress, HPA settings

### helm Module
Manages Helm releases:
- **NGINX Ingress Controller**: HTTP(S) routing
- **Prometheus + Grafana**: Monitoring stack (optional)
- **Cert-Manager**: SSL/TLS certificate management (optional)

**Variables**: Namespaces, versions, resource limits, credentials

## Accessing Applications

### Application Service
```bash
kubectl port-forward -n env-app svc/example-service 8080:80
# Visit: http://localhost:8080
```

### Grafana Dashboard
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Visit: http://localhost:3000
# Credentials: admin / admin
```

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090
```

## Common Commands

```bash
# View all outputs
terraform output

# View specific output
terraform output port_forward_command

# Refresh state
terraform refresh

# Destroy all resources
terraform destroy
```

## Customization

Edit `terraform.tfvars` to customize:

```hcl
# Application
app_image       = "myapp:v1.0"
app_replicas    = 3

# Resources
cpu_limit       = "500m"
memory_limit    = "512Mi"

# Ingress
ingress_host    = "myapp.local"

# Monitoring
enable_monitoring = true

# Cert-Manager
enable_cert_manager = true
```

Then apply:
```bash
terraform plan
terraform apply
```

## Module Architecture

### Call Graph
```
main.tf
├── module.helm
│   └── Helm releases (NGINX, Prometheus, Cert-Manager)
└── module.kubernetes
    └── App resources (Deployment, Service, Ingress, ConfigMap, HPA)
```

### Provider Flow
```
Docker Desktop Kubernetes
├── Helm Provider (manages Helm releases)
└── Kubernetes Provider (manages k8s resources)
```

## Troubleshooting

### Kubernetes context not found
```bash
kubectl config current-context
# Ensure output is: docker-desktop
```

### Pods failing to start
```bash
kubectl describe pod -n env-app <pod-name>
kubectl logs -n env-app deployment/example-deployment
```

### Helm chart issues
```bash
helm repo update
helm list -A
```

### Port-forward connection refused
Check if pod is running:
```bash
kubectl get pods -n env-app -o wide
```

## Resource Requirements

- CPU: ~2 cores
- Memory: ~4-6 GB
- Disk: ~10 GB

Adjust resource limits in `terraform.tfvars` as needed.

## Advanced Usage

### Multiple Environments

Create separate variable files:
```bash
# Dev environment
terraform apply -var-file=dev.tfvars

# Prod environment  
terraform apply -var-file=prod.tfvars
```

### Custom Helm Values

Override Helm values in module variables:
```hcl
module "helm" {
  # ... other config
  prometheus_cpu_limit = "1000m"
}
```

## Contributing

When modifying modules, ensure:
1. Variables have descriptions
2. Outputs are meaningful
3. Naming is consistent
4. Documentation is updated

## License

MIT
# devops-assessment-2
