# Kustomize vs Helm: Migration Guide

## Quick Comparison

| Feature | Helm | Kustomize |
|---------|------|-----------|
| **Templating** | Go templates | Strategic merge patches |
| **Package Management** | Chart repositories | Git repositories |
| **Dependencies** | Chart dependencies | Resource references |
| **Values** | values.yaml | Patch files |
| **Release Management** | Helm releases | kubectl apply |
| **Rollbacks** | `helm rollback` | kubectl + Git |
| **Complexity** | High (learning curve) | Low (YAML native) |

## Migration Strategy

### 1. Analyze Your Helm Charts

```bash
# List your current Helm releases
helm list -A

# Examine a chart structure
helm show values my-chart
helm template my-chart
```

### 2. Convert Helm Templates to Base Resources

**Helm Chart Structure:**
```
my-chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
```

**Kustomize Structure:**
```
base/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── ingress.yaml
overlays/
├── dev/
├── staging/
└── production/
```

### 3. Convert Helm Values to Kustomize Patches

**Helm values.yaml:**
```yaml
replicaCount: 3
image:
  repository: nginx
  tag: "1.21"
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

**Kustomize overlay:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

replicas:
- name: web-app
  count: 3

images:
- name: nginx
  newTag: "1.21"

patches:
- target:
    kind: Deployment
    name: web-app
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 100m
          memory: 128Mi
```

### 4. Migration Examples

#### Example 1: Simple Web Application

**Helm Template:**
```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

**Kustomize Base:**
```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    spec:
      containers:
      - name: myapp
        image: nginx:1.21
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
```

#### Example 2: Environment-Specific Configuration

**Helm (multiple values files):**
```yaml
# values-prod.yaml
replicaCount: 5
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
ingress:
  enabled: true
  host: app.example.com
```

**Kustomize (production overlay):**
```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

replicas:
- name: myapp
  count: 5

patches:
- target:
    kind: Deployment
    name: myapp
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 1Gi

resources:
- ingress.yaml
```

### 5. Migration Steps

1. **Extract Static Resources**
   ```bash
   # Render Helm templates to get base YAML
   helm template my-release my-chart > base-resources.yaml
   
   # Split into individual files
   # Remove Helm-specific templating
   ```

2. **Create Base Kustomization**
   ```bash
   mkdir -p base
   # Move cleaned YAML files to base/
   # Create base/kustomization.yaml
   ```

3. **Create Environment Overlays**
   ```bash
   mkdir -p overlays/{dev,staging,production}
   # Create environment-specific kustomization.yaml files
   # Add patches for differences
   ```

4. **Test Migration**
   ```bash
   # Compare Helm output with Kustomize output
   helm template my-release my-chart > helm-output.yaml
   kubectl kustomize overlays/production > kustomize-output.yaml
   
   # Use diff tools to compare
   diff helm-output.yaml kustomize-output.yaml
   ```

### 6. Common Patterns

#### Conditional Resources (Helm `if` statements)

**Helm:**
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ...
{{- end }}
```

**Kustomize:**
```yaml
# Only include ingress.yaml in environments that need it
# overlays/production/kustomization.yaml
resources:
- ../../base
- ingress.yaml  # Only add where needed
```

#### Loops and Repeated Resources

**Helm:**
```yaml
{{- range .Values.services }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
spec:
  ports:
  - port: {{ .port }}
{{- end }}
```

**Kustomize:**
```yaml
# Create separate files for each service
# base/service-web.yaml
# base/service-api.yaml
# Include them in kustomization.yaml
resources:
- service-web.yaml
- service-api.yaml
```

### 7. Advantages After Migration

✅ **Simpler YAML** - No templating language to learn
✅ **Better Git Diffs** - Pure YAML changes are easier to review
✅ **GitOps Native** - Works seamlessly with GitOps workflows
✅ **No Runtime Dependencies** - No Tiller or Helm binary needed
✅ **Kubernetes Native** - Built into kubectl

### 8. When to Keep Helm

Consider keeping Helm for:
- Complex applications with many conditional resources
- Third-party charts from Helm repositories
- Applications requiring sophisticated package management
- Teams already heavily invested in Helm workflows

### 9. Hybrid Approach

You can use both tools together:
```bash
# Use Helm for third-party dependencies
helm install prometheus prometheus-community/kube-prometheus-stack

# Use Kustomize for your applications
kubectl apply -k overlays/production
```

## Migration Checklist

- [ ] Inventory existing Helm charts
- [ ] Identify chart dependencies
- [ ] Extract base resources from templates
- [ ] Create environment overlays
- [ ] Test deployments in dev environment
- [ ] Migrate secrets and ConfigMaps
- [ ] Update CI/CD pipelines
- [ ] Train team on Kustomize
- [ ] Document new workflows
- [ ] Plan rollback strategy
