# Kustomize Best Practices

## 📋 Project Structure Best Practices

### 1. Directory Organization

```
├── base/                          # Environment-agnostic resources
│   ├── kustomization.yaml         # Base kustomization
│   ├── namespace.yaml             # Optional: namespace definition
│   └── components/                # Logical application components
│       ├── web-app/
│       ├── database/
│       └── cache/
├── overlays/                      # Environment-specific customizations
│   ├── dev/
│   ├── staging/
│   ├── production/
│   └── local/                     # Optional: for local development
├── components/                    # Reusable components
│   ├── monitoring/
│   ├── security/
│   └── scaling/
└── environments/                  # Alternative to overlays/
    ├── region-a/
    │   ├── dev/
    │   ├── staging/
    │   └── prod/
    └── region-b/
```

### 2. Naming Conventions

```yaml
# Use consistent naming patterns
metadata:
  name: app-component-environment  # e.g., webapp-frontend-prod
  labels:
    app.kubernetes.io/name: webapp
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: ecommerce
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/managed-by: kustomize
    environment: production
```

## 🔧 Configuration Management

### 1. ConfigMap and Secret Patterns

```yaml
# Use generators for configuration
configMapGenerator:
- name: app-config
  behavior: merge  # merge, replace, create
  literals:
  - database_url=postgres://...
  - log_level=info
  files:
  - config.properties
  - logging.conf

secretGenerator:
- name: app-secrets
  type: kubernetes.io/tls
  files:
  - tls.crt
  - tls.key
```

### 2. Environment-Specific Configuration

```yaml
# Base configuration - minimal and generic
# overlays/dev/kustomization.yaml
configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - log_level=debug
  - replicas=1
  - database_pool_size=5

# overlays/production/kustomization.yaml
configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - log_level=error
  - replicas=5
  - database_pool_size=20
```

## 🏷️ Resource Management

### 1. Labels and Annotations

```yaml
# Standard labels (base/kustomization.yaml)
commonLabels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/managed-by: kustomize

# Environment-specific labels (overlays/*/kustomization.yaml)
commonLabels:
  environment: production
  team: platform
  cost-center: engineering
```

### 2. Resource Naming

```yaml
# Use namePrefix for environment separation
namePrefix: prod-

# Use nameSuffix for versioning
nameSuffix: -v2

# Result: prod-webapp-v2
```

## 🔄 Patching Strategies

### 1. Strategic Merge Patches

```yaml
# Preferred for simple updates
patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    spec:
      replicas: 3
      template:
        spec:
          containers:
          - name: webapp
            resources:
              requests:
                cpu: 500m
                memory: 512Mi
```

### 2. JSON Patches (RFC 6902)

```yaml
# Use for precise operations
patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 5
    - op: add
      path: /spec/template/spec/nodeSelector
      value:
        node-type: compute
```

### 3. Patch Files

```yaml
# For complex patches, use separate files
patches:
- path: production-resources.yaml
  target:
    kind: Deployment
    name: webapp
```

## 🔐 Security Best Practices

### 1. Secret Management

```yaml
# DON'T commit secrets to Git
# Use external secret management

# For non-production environments only
secretGenerator:
- name: dev-secrets
  literals:
  - password=dev_password_only

# Production: Use external tools
# - Sealed Secrets
# - External Secrets Operator
# - Google Secret Manager
# - AWS Secrets Manager
```

### 2. Security Contexts

```yaml
# Always define security contexts
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: app
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

### 3. Network Policies

```yaml
# Include network policies in production
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webapp-netpol
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## 📊 Resource Management

### 1. Resource Requests and Limits

```yaml
# Always set resource requests and limits
containers:
- name: webapp
  resources:
    requests:
      cpu: 100m      # Guaranteed CPU
      memory: 128Mi   # Guaranteed memory
    limits:
      cpu: 500m      # Maximum CPU
      memory: 512Mi   # Maximum memory
```

### 2. Horizontal Pod Autoscaling

```yaml
# Include HPA for production workloads
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 3
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 3. Pod Disruption Budgets

```yaml
# Ensure availability during updates
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: webapp-pdb
spec:
  selector:
    matchLabels:
      app: webapp
  minAvailable: 2  # or maxUnavailable: 1
```

## 🔄 GitOps Integration

### 1. Repository Structure

```
├── apps/
│   ├── webapp/
│   │   ├── base/
│   │   └── overlays/
│   └── api/
├── infrastructure/
│   ├── monitoring/
│   └── ingress/
└── clusters/
    ├── dev/
    ├── staging/
    └── production/
```

### 2. CI/CD Pipeline Integration

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to staging
      run: |
        kubectl apply -k overlays/staging
        
    - name: Run tests
      run: |
        # Integration tests
        
    - name: Deploy to production
      if: github.ref == 'refs/heads/main'
      run: |
        kubectl apply -k overlays/production
```

### 3. ArgoCD Integration

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-prod
spec:
  project: default
  source:
    repoURL: https://github.com/company/k8s-configs
    path: overlays/production
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🧪 Testing and Validation

### 1. Dry Run Validation

```bash
# Always test before applying
kubectl apply -k overlays/production --dry-run=client
kubectl diff -k overlays/production

# Validate generated resources
kubectl kustomize overlays/production | kubectl apply --dry-run=client -f -
```

### 2. Schema Validation

```bash
# Use kubeval for schema validation
kubectl kustomize overlays/production | kubeval

# Use kustomize with built-in validation
kustomize build overlays/production --enable-alpha-plugins
```

### 3. Policy Validation

```bash
# Use OPA Gatekeeper or Polaris
kubectl kustomize overlays/production | conftest verify --policy opa-policies/
```

## 📝 Documentation

### 1. README Templates

```markdown
# Application Name

## Quick Start
\`\`\`bash
kubectl apply -k overlays/dev
\`\`\`

## Environments
- **dev**: Development environment
- **staging**: Pre-production testing
- **production**: Live environment

## Configuration
| Environment | Replicas | Resources | Ingress |
|-------------|----------|-----------|---------|
| dev         | 1        | 100m/128Mi| None    |
| staging     | 3        | 200m/256Mi| staging.app.com |
| production  | 5        | 500m/512Mi| app.com |
```

### 2. Kustomization Documentation

```yaml
# Document your kustomizations
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  annotations:
    config.kubernetes.io/local-config: "true"
    documentation: |
      This kustomization deploys the web application to production
      with high availability configuration including:
      - 5 replicas with anti-affinity
      - Resource limits and requests
      - Horizontal Pod Autoscaler
      - Pod Disruption Budget
```

## 🚨 Common Anti-Patterns

### ❌ Don't Do This

```yaml
# DON'T: Hardcode environment-specific values in base
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-production  # ❌ Environment in base
spec:
  replicas: 10             # ❌ Production values in base
```

```yaml
# DON'T: Use complex patches for simple changes
patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3             # ❌ Use replicas field instead
```

### ✅ Do This Instead

```yaml
# ✅ Keep base generic
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2              # ✅ Reasonable default

# ✅ Use built-in transformers
replicas:
- name: webapp
  count: 10                # ✅ Simple and clear
```

## 📊 Performance Tips

1. **Use Strategic Merge over JSON patches** when possible
2. **Minimize patch complexity** - prefer multiple simple patches
3. **Use generators efficiently** - avoid regenerating unchanged resources
4. **Organize resources logically** - group related resources
5. **Use components** for truly reusable patterns
6. **Profile large kustomizations** - use `kustomize build --load_restrictor none`

## 🔍 Troubleshooting

### Common Issues

1. **Patch not applying**: Check target selectors and patch format
2. **Resource conflicts**: Verify names and namespaces
3. **Generator issues**: Check file paths and literal values
4. **Performance problems**: Split large kustomizations

### Debug Commands

```bash
# See what kustomize generates
kustomize build overlays/production

# Check for issues
kustomize build overlays/production 2>&1 | grep -i error

# Validate syntax
kubectl apply -k overlays/production --dry-run=client --validate=true
```
