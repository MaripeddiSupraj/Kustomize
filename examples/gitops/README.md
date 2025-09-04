# GitOps Integration Examples
# Advanced CI/CD patterns with Kustomize

## ArgoCD Integration Example

```yaml
# .argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/company/k8s-manifests
    targetRevision: HEAD
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## Flux v2 Integration Example

```yaml
# flux-system/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: webapp-production
  namespace: flux-system
spec:
  interval: 5m
  path: "./overlays/production"
  prune: true
  sourceRef:
    kind: GitRepository
    name: webapp-manifests
  validation: client
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: prod-web-app
    namespace: webapp-prod
```

## GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy to GKE
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
    
    - name: Validate Kustomize builds
      run: |
        for env in dev staging production; do
          echo "Validating $env environment..."
          kustomize build overlays/$env > /tmp/$env.yaml
          
          # Validate YAML syntax
          yamllint /tmp/$env.yaml
          
          # Validate Kubernetes resources
          kubectl apply --dry-run=client -f /tmp/$env.yaml
        done
    
    - name: Security scan
      run: |
        # Check for hardcoded secrets
        grep -r "password\|secret\|key" overlays/ || true
        
        # Policy validation with OPA
        for env in dev staging production; do
          kustomize build overlays/$env | conftest verify --policy policies/
        done

  deploy-dev:
    if: github.event_name == 'pull_request'
    needs: validate
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: google-github-actions/setup-gcloud@v0
      with:
        service_account_key: ${{ secrets.GKE_SA_KEY }}
        project_id: ${{ secrets.GKE_PROJECT }}
    
    - name: Deploy to dev
      run: |
        gcloud container clusters get-credentials dev-cluster --region us-central1
        kustomize build overlays/dev | kubectl apply -f -
        
        # Wait for rollout
        kubectl rollout status deployment/dev-web-app -n webapp-dev

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: validate
    runs-on: ubuntu-latest
    environment: production
    steps:
    - uses: actions/checkout@v3
    - uses: google-github-actions/setup-gcloud@v0
      with:
        service_account_key: ${{ secrets.GKE_SA_KEY_PROD }}
        project_id: ${{ secrets.GKE_PROJECT_PROD }}
    
    - name: Deploy to production
      run: |
        gcloud container clusters get-credentials prod-cluster --region us-central1
        
        # Production deployment with approval gates
        kustomize build overlays/production | kubectl apply -f -
        
        # Verify health checks
        kubectl rollout status deployment/prod-web-app -n webapp-prod
        kubectl wait --for=condition=available --timeout=300s deployment/prod-web-app -n webapp-prod
```

## Tekton Pipeline Example

```yaml
# tekton/pipeline.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: kustomize-deploy
spec:
  params:
  - name: environment
    description: Target environment (dev/staging/production)
  - name: git-url
    description: Git repository URL
  - name: git-revision
    description: Git revision to deploy
    
  workspaces:
  - name: source
  - name: kubeconfig
    
  tasks:
  - name: fetch-source
    taskRef:
      name: git-clone
    params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.git-revision)
    workspaces:
    - name: output
      workspace: source
      
  - name: validate-kustomize
    runAfter: [fetch-source]
    taskSpec:
      workspaces:
      - name: source
      steps:
      - name: validate
        image: k8s.gcr.io/kustomize/kustomize:v5.0.0
        script: |
          #!/bin/bash
          cd $(workspaces.source.path)
          
          # Validate kustomization builds
          kustomize build overlays/$(params.environment) > /tmp/manifest.yaml
          
          # Validate resources
          kubectl apply --dry-run=client -f /tmp/manifest.yaml
    workspaces:
    - name: source
      workspace: source
      
  - name: deploy
    runAfter: [validate-kustomize]
    taskSpec:
      params:
      - name: environment
      workspaces:
      - name: source
      - name: kubeconfig
      steps:
      - name: deploy
        image: k8s.gcr.io/kustomize/kustomize:v5.0.0
        script: |
          #!/bin/bash
          cd $(workspaces.source.path)
          
          # Deploy using kustomize
          kustomize build overlays/$(params.environment) | kubectl apply -f -
          
          # Wait for deployment
          kubectl rollout status deployment/$(params.environment)-web-app
    params:
    - name: environment
      value: $(params.environment)
    workspaces:
    - name: source
      workspace: source
    - name: kubeconfig
      workspace: kubeconfig
```

## Progressive Delivery with Flagger

```yaml
# flagger/canary.yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: webapp
  namespace: webapp-prod
spec:
  # Deployment reference
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: prod-web-app
  
  # Service reference
  service:
    port: 80
    targetPort: 8080
    gateways:
    - webapp-gateway
    hosts:
    - webapp.production.example.com
  
  # Canary analysis
  analysis:
    interval: 30s
    threshold: 10
    maxWeight: 50
    stepWeight: 5
    
    # Metrics for promotion decision
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 30s
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    
    # Load testing
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://webapp.production.example.com/"
```

## Policy Validation Examples

```yaml
# policies/security-policy.rego
package kubernetes.security

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := "Containers must run as non-root user"
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.readOnlyRootFilesystem
  msg := "Containers must have read-only root filesystem"
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg := "Containers must have memory limits"
}
```

## Multi-Environment Promotion

```bash
#!/bin/bash
# scripts/promote.sh - Automated environment promotion

set -euo pipefail

promote_image() {
    local from_env=$1
    local to_env=$2
    local image_name=$3
    
    echo "Promoting $image_name from $from_env to $to_env..."
    
    # Get current image tag from source environment
    current_tag=$(kubectl kustomize overlays/$from_env | \
                  yq eval '.spec.template.spec.containers[] | select(.name == "'$image_name'") | .image' -)
    
    # Update target environment kustomization
    cd overlays/$to_env
    kustomize edit set image $image_name=$current_tag
    
    # Commit changes
    git add kustomization.yaml
    git commit -m "Promote $image_name to $to_env: $current_tag"
    
    echo "Promoted $image_name to $to_env"
}

# Promote from dev to staging
promote_image "dev" "staging" "nginx"
promote_image "dev" "staging" "postgres"

# Deploy to staging
kubectl apply -k overlays/staging

# Wait for staging deployment
kubectl rollout status deployment/staging-web-app -n webapp-staging

# Run staging tests
./scripts/test-staging.sh

# If tests pass, promote to production (manual approval required)
echo "Staging tests passed. Ready for production promotion."
echo "Run: ./scripts/promote.sh staging production"
```

This demonstrates production-ready GitOps integration patterns with Kustomize, including automated validation, progressive delivery, and multi-environment promotion workflows.
