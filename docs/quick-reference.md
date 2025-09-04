# Kustomize Quick Reference

## 🚀 Quick Start Commands

```bash
# Setup demo (existing cluster)
./scripts/setup-demo.sh

# Deploy environments
kubectl apply -k overlays/dev
kubectl apply -k overlays/staging  
kubectl apply -k overlays/production

# Monitor deployments
./scripts/monitor.sh

# Cleanup
./scripts/cleanup.sh
```

## 📁 Directory Structure

```
kustomize-project/
├── base/                    # Environment-agnostic resources
│   ├── kustomization.yaml   # Base configuration
│   ├── web-app/            # Application components
│   └── database/           # Database components
├── overlays/               # Environment-specific configs
│   ├── dev/               # Development
│   ├── staging/           # Staging
│   └── production/        # Production
├── components/            # Reusable components
├── scripts/              # Automation scripts
└── docs/                 # Documentation
```

## 🔧 Essential Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `kubectl kustomize` | Preview generated YAML | `kubectl kustomize overlays/dev` |
| `kubectl apply -k` | Deploy with kustomize | `kubectl apply -k overlays/production` |
| `kubectl delete -k` | Delete with kustomize | `kubectl delete -k overlays/dev` |
| `kubectl diff -k` | Show differences | `kubectl diff -k overlays/staging` |
| `kustomize build` | Build without kubectl | `kustomize build overlays/production` |

## 📝 kustomization.yaml Structure

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Basic settings
metadata:
  name: my-app
  annotations:
    config.kubernetes.io/local-config: "true"

# Resources to include
resources:
- deployment.yaml
- service.yaml
- ../../base

# Transformations
namePrefix: prod-
nameSuffix: -v1
namespace: production

# Labels and annotations
commonLabels:
  app: webapp
  environment: production
commonAnnotations:
  managed-by: kustomize

# Images
images:
- name: nginx
  newTag: 1.21.6
- name: postgres
  newName: postgresql
  newTag: 14.7

# Replicas
replicas:
- name: webapp
  count: 5

# Generators
configMapGenerator:
- name: app-config
  literals:
  - key=value
  files:
  - config.properties

secretGenerator:
- name: app-secrets
  literals:
  - password=secret123
  type: Opaque

# Patches
patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3

patchesStrategicMerge:
- production-patch.yaml

patchesJson6902:
- target:
    version: v1
    kind: Deployment
    name: webapp
  path: json-patch.yaml
```

## 🏷️ Common Transformations

### Labels and Annotations
```yaml
commonLabels:
  app.kubernetes.io/name: webapp
  app.kubernetes.io/version: "1.0.0"
  environment: production

commonAnnotations:
  contact: team@company.com
  documentation: https://docs.company.com/webapp
```

### Images
```yaml
images:
- name: nginx
  newTag: 1.21.6-alpine
- name: postgres
  newName: postgresql
  newTag: 14.7
- name: app
  newName: registry.company.com/app
  newTag: v1.2.3
```

### Replicas
```yaml
replicas:
- name: frontend
  count: 3
- name: backend  
  count: 5
```

### Namespace
```yaml
namespace: production
```

### Name Prefix/Suffix
```yaml
namePrefix: prod-
nameSuffix: -v2
# Result: prod-webapp-v2
```

## 🔄 Patching Strategies

### 1. Strategic Merge Patch
```yaml
patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    spec:
      replicas: 5
      template:
        spec:
          containers:
          - name: webapp
            resources:
              requests:
                cpu: 500m
                memory: 512Mi
```

### 2. JSON Patch (RFC 6902)
```yaml
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
patches:
- path: production-resources.yaml
  target:
    kind: Deployment
    name: webapp
```

## 🏗️ Generators

### ConfigMap Generator
```yaml
configMapGenerator:
- name: app-config
  behavior: merge  # create, replace, merge
  literals:
  - DATABASE_HOST=postgres.example.com
  - LOG_LEVEL=info
  files:
  - application.properties
  - log4j.properties
  envs:
  - .env
```

### Secret Generator
```yaml
secretGenerator:
- name: app-secrets
  type: kubernetes.io/basic-auth
  literals:
  - username=admin
  - password=secret123
  files:
  - ssh-key=~/.ssh/id_rsa
  - tls.crt
  - tls.key
```

## 🧩 Components

Create reusable components:

```yaml
# components/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
- servicemonitor.yaml
- dashboard.yaml

configMapGenerator:
- name: monitoring-config
  literals:
  - scrape_interval=30s
```

Use in overlays:
```yaml
# overlays/production/kustomization.yaml
components:
- ../../components/monitoring
```

## 🎯 Environment Patterns

### Development
```yaml
# overlays/dev/kustomization.yaml
resources:
- ../../base

namePrefix: dev-
namespace: webapp-dev

replicas:
- name: webapp
  count: 1

configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=debug
  - REPLICAS=1
```

### Staging
```yaml
# overlays/staging/kustomization.yaml
resources:
- ../../base
- ingress.yaml
- hpa.yaml

namePrefix: staging-
namespace: webapp-staging

replicas:
- name: webapp
  count: 3

images:
- name: webapp
  newTag: staging-v1.2.3
```

### Production
```yaml
# overlays/production/kustomization.yaml
resources:
- ../../base
- ingress.yaml
- hpa.yaml
- vpa.yaml
- pdb.yaml
- backup-cronjob.yaml

namePrefix: prod-
namespace: webapp-prod

replicas:
- name: webapp
  count: 5

images:
- name: webapp
  newTag: v1.2.3
  # Use SHA for immutability in production
  # newTag: v1.2.3@sha256:abc123...
```

## 🔍 Debugging Commands

```bash
# Build and preview
kustomize build overlays/production

# Validate without applying
kubectl apply -k overlays/production --dry-run=client

# Show differences
kubectl diff -k overlays/production

# Debug patch application
kustomize build overlays/production --enable-alpha-plugins

# Check specific resources
kubectl kustomize overlays/production | grep -A 10 "kind: Deployment"

# Validate YAML syntax
kubectl kustomize overlays/production | yamllint -

# Check resource creation order
kubectl apply -k overlays/production --dry-run=server -o yaml
```

## 🚨 Common Errors and Solutions

### Error: Resource not found
```bash
# Check resource paths in kustomization.yaml
ls -la base/
cat base/kustomization.yaml
```

### Error: Patch target not found
```bash
# Verify target selector matches resource
kubectl kustomize base | grep -A 5 "kind: Deployment"
```

### Error: Invalid patch
```bash
# Check patch syntax
echo 'patch content' | yq eval .
```

### Error: Circular dependency
```bash
# Check for self-references in resources
grep -r "resources:" overlays/
```

## 📊 Performance Tips

1. **Use strategic merge** over JSON patches when possible
2. **Minimize large patches** - break into smaller, focused patches
3. **Use generators efficiently** - avoid regenerating unchanged content
4. **Organize resources logically** - group related resources together
5. **Profile builds** - use `time kustomize build` for large projects

## 🔗 Useful Links

- [Official Kustomize Docs](https://kustomize.io/)
- [Kubectl Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [Examples Repository](https://github.com/kubernetes-sigs/kustomize/tree/master/examples)
- [Best Practices](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)

## 🎓 Learning Path

1. **Start with base** - Create simple base resources
2. **Add overlays** - Create dev/staging/prod environments  
3. **Learn patching** - Master strategic merge and JSON patches
4. **Use generators** - ConfigMaps and Secrets
5. **Advanced features** - Components, transformers, plugins
6. **GitOps integration** - CI/CD workflows with ArgoCD/Flux

## 🛠️ This Project's Features

✅ **Production-ready configurations**
✅ **Security best practices** 
✅ **Monitoring integration**
✅ **Backup strategies**
✅ **Scaling configurations**
✅ **Network policies**
✅ **GitOps workflows**
✅ **Migration from Helm**
