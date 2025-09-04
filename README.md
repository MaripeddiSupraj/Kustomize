# Kustomize Learning Project 🚀

This repository demonstrates **production-ready Kustomize configurations** with enterprise-grade best practices for managing Kubernetes deployments across multiple environments. Perfect for teams transitioning from Helm or starting fresh with GitOps.

## 🔒 Important Security Notice

⚠️ **CRITICAL:** This repository contains **DEMO PASSWORDS** for learning purposes only!

### For Demo/Learning Only:
- Development and staging environments use **hardcoded demo passwords**
- These are clearly marked as `DEMO ONLY` or `changeme123`
- **NEVER use these passwords in real environments**

### For Production Use:
- Production overlay **does NOT** include hardcoded secrets
- Use external secret management:
  - Google Secret Manager
  - AWS Secrets Manager
  - Azure Key Vault
  - External Secrets Operator
  - HashiCorp Vault

### Demo Passwords Used (CHANGE THESE!):
```yaml
# DEMO ONLY - NOT FOR PRODUCTION
username: webapp_user
password: changeme123        # Base
password: dev_password123    # Development
password: staging_secure_password456  # Staging
```

### Production Secret Management:
```bash
# Example: Create production secrets externally
kubectl create secret generic db-credentials \
  --from-literal=username="real_production_user" \
  --from-literal=password="$(generate-secure-password)" \
  -n webapp-prod
```

---

## 🏗️ Project Structure

```
├── README.md                 # This comprehensive guide
├── base/                     # Base configurations (environment-agnostic)
│   ├── kustomization.yaml    # Main base configuration
│   ├── web-app/              # Web application manifests
│   │   ├── deployment.yaml   # Secure, production-ready deployment
│   │   ├── service.yaml      # Service definition
│   │   └── configmap.yaml    # Application configuration
│   └── database/             # Database manifests
│       ├── statefulset.yaml  # PostgreSQL StatefulSet
│       └── service.yaml      # Database service
├── overlays/                 # Environment-specific configurations
│   ├── dev/                  # Development environment
│   │   └── kustomization.yaml
│   ├── staging/              # Staging environment
│   │   ├── kustomization.yaml
│   │   ├── ingress.yaml      # GKE Ingress with SSL
│   │   ├── hpa.yaml          # Horizontal Pod Autoscaler
│   │   └── network-policy.yaml
│   └── production/           # Production environment
│       ├── kustomization.yaml
│       ├── ingress.yaml      # Production Ingress with Armor
│       ├── hpa.yaml          # Advanced HPA
│       ├── vpa.yaml          # Vertical Pod Autoscaler
│       ├── pdb.yaml          # Pod Disruption Budget
│       ├── network-policy.yaml
│       ├── service-monitor.yaml
│       └── backup-cronjob.yaml
├── components/               # Reusable components
│   └── monitoring/           # Monitoring stack component
├── scripts/                  # Deployment and utility scripts
├── examples/                 # Advanced examples and patterns
│   ├── advanced/             # Expert-level Kustomize patterns
│   │   ├── README.md         # Advanced concepts guide
│   │   ├── replacements.yaml # Variable substitution examples
│   │   ├── multi-base.yaml   # Multi-base composition
│   │   ├── transformers.yaml # Custom transformers
│   │   ├── plugins.yaml      # Plugin system examples
│   │   ├── openapi-validation.yaml
│   │   └── variable-substitution.yaml
│   └── gitops/              # GitOps integration examples
│       └── README.md        # CI/CD patterns and workflows
└── docs/                    # Documentation and examples
```

## 📚 What You'll Learn

- ✅ **Kustomize Fundamentals**: Base/overlay patterns, patching, transformations
- ✅ **Production Best Practices**: Security, monitoring, backup strategies
- ✅ **Environment Management**: Dev/staging/prod configurations
- ✅ **GKE Integration**: Ingress, SSL certificates, Cloud Armor
- ✅ **Scaling & Reliability**: HPA, VPA, PDB, anti-affinity rules
- ✅ **Security**: Network policies, RBAC, security contexts
- ✅ **Monitoring**: ServiceMonitor, Prometheus integration
- ✅ **GitOps Workflows**: CI/CD integration patterns
- ✅ **Migration from Helm**: Key differences and migration strategies

## 🤔 What is Kustomize?

**Kustomize** is a Kubernetes-native configuration management tool that lets you customize YAML manifests without using templates. It's built into `kubectl` and follows a declarative approach to manage Kubernetes applications across different environments.

### 🎯 Core Philosophy

Unlike templating tools (like Helm), Kustomize uses **strategic merge patches** and **composition** to customize Kubernetes resources. You define a base configuration and then apply environment-specific patches on top of it.

```
Base Configuration + Environment Patches = Final Deployment
```

### 🔧 How Kustomize Works

#### 1. **Base Resources** (Foundation)
Your core application manifests without environment-specific details:

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    spec:
      containers:
      - name: webapp
        image: nginx:1.21
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
```

#### 2. **Overlays** (Customizations)
Environment-specific modifications applied to base resources:

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Production customizations
replicas:
- name: webapp
  count: 5

images:
- name: nginx
  newTag: 1.21.6

patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    spec:
      template:
        spec:
          containers:
          - name: webapp
            resources:
              requests:
                cpu: 500m
                memory: 512Mi
```

#### 3. **The Magic** ✨
When you run `kubectl apply -k overlays/production`, Kustomize:
1. Takes the base deployment (2 replicas, 100m CPU)
2. Applies production patches (5 replicas, 500m CPU)
3. Updates the image tag to 1.21.6
4. Generates the final YAML
5. Deploys to Kubernetes

### 🏗️ Key Concepts Explained

#### **Strategic Merge vs JSON Patch**

**Strategic Merge** (Most Common):
```yaml
# Original
spec:
  containers:
  - name: webapp
    resources:
      requests:
        cpu: 100m

# Patch (merges intelligently)
spec:
  containers:
  - name: webapp
    resources:
      requests:
        memory: 256Mi  # Adds memory, keeps CPU
```

**JSON Patch** (Precise Operations):
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

#### **Generators** (Dynamic Resources)
Create ConfigMaps and Secrets on-the-fly:

```yaml
configMapGenerator:
- name: app-config
  literals:
  - database_url=postgres://localhost:5432/mydb
  - log_level=info
  files:
  - application.properties

secretGenerator:
- name: app-secrets
  literals:
  - api_key=supersecret123
  - db_password=secretpassword
```

#### **Transformers** (Bulk Changes)
Apply changes to multiple resources:

```yaml
# Add prefix to all resource names
namePrefix: prod-

# Add suffix to all resource names
nameSuffix: -v2

# Set namespace for all resources
namespace: production

# Add labels to all resources
commonLabels:
  environment: production
  team: backend
```

### 🆚 Kustomize vs Other Tools

| Tool | Approach | Learning Curve | Use Case |
|------|----------|----------------|----------|
| **Kustomize** | Patching/Composition | Gentle | Environment management |
| **Helm** | Templating | Steep | Package management |
| **Jsonnet** | Programming | Steep | Complex logic |
| **Plain YAML** | Manual | None | Simple deployments |

### 🎯 Why Choose Kustomize?

✅ **No Templating** - Pure YAML, no learning template syntax
✅ **Kubernetes Native** - Built into kubectl, no extra tools
✅ **GitOps Friendly** - Works seamlessly with Git workflows
✅ **Composable** - Mix and match configurations easily
✅ **Declarative** - Describe what you want, not how to get there
✅ **Debuggable** - Easy to see what's being deployed

### 🔄 Typical Workflow

```bash
# 1. Create base resources
mkdir -p base
# Add your deployment.yaml, service.yaml, etc.

# 2. Create environment overlays
mkdir -p overlays/{dev,staging,production}

# 3. Preview what will be deployed
kubectl kustomize overlays/production

# 4. Deploy to cluster
kubectl apply -k overlays/production

# 5. Update and redeploy
# Edit overlay files and rerun step 4
```

### 🏢 Real-World Example

Imagine you have a web application that needs to run differently in each environment:

**Development:**
- 1 replica
- Small resources
- Debug logging
- No ingress

**Staging:**
- 3 replicas  
- Medium resources
- Info logging
- Internal ingress

**Production:**
- 5 replicas
- Large resources  
- Error logging only
- Public ingress with SSL

With Kustomize, you define the application **once** in base/, then create small patches for each environment instead of maintaining 3 separate YAML files.

### 🎓 Learning Path

1. **Understand the basics** ← You are here!
2. **Try simple base + overlay**
3. **Learn patching strategies**
4. **Master generators and transformers**
5. **Build production workflows**

---

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"

# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Install gcloud CLI
curl https://sdk.cloud.google.com | bash

# Verify installations
kubectl version --client
kustomize version
gcloud version
```

### Option 1: Use Existing GKE Cluster (Recommended for Demo)

If you already have a GKE cluster running, you can use it for this demo:

```bash
# Ensure you're connected to your cluster
kubectl cluster-info

# Run the automated setup script
./scripts/setup-demo.sh

# This script will:
# ✅ Check prerequisites (kubectl, kustomize, gcloud)
# ✅ Verify cluster connectivity
# ✅ Create demo namespaces (webapp-dev, webapp-staging, webapp-prod)
# ✅ Set up storage classes for GKE
# ✅ Install Prometheus Operator (for monitoring)
# ✅ Configure RBAC
# ✅ Create demo secrets (dev/staging only)
# ✅ Validate everything is ready
```

### Option 2: Create New GKE Cluster

If you need to create a new cluster:

```bash
# Set your project and preferences
export PROJECT_ID="your-gcp-project-id"
export CLUSTER_NAME="kustomize-demo"
export REGION="us-central1"

# Create GKE cluster with recommended settings
gcloud container clusters create $CLUSTER_NAME \
  --project=$PROJECT_ID \
  --region=$REGION \
  --machine-type=e2-standard-4 \
  --num-nodes=3 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-network-policy \
  --enable-ip-alias \
  --enable-autoprovisioning \
  --enable-vertical-pod-autoscaling

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID

# Run setup script
./scripts/setup-demo.sh
```

## 🎯 Deployment Guide

### 1. Development Environment

Perfect for local development and testing:

```bash
# Preview what will be deployed
kubectl kustomize overlays/dev

# Deploy to development
kubectl apply -k overlays/dev

# Verify deployment
kubectl get all -n webapp-dev

# Port forward for local testing
kubectl port-forward -n webapp-dev svc/dev-web-app-service 8080:80
```

### 2. Staging Environment

Production-like environment for testing:

```bash
# Create namespace
kubectl create namespace webapp-staging

# Deploy with staging configuration
kubectl apply -k overlays/staging

# Check ingress and SSL certificate
kubectl get ingress -n webapp-staging
kubectl get managedcertificate -n webapp-staging

# Monitor HPA
kubectl get hpa -n webapp-staging
```

### 3. Production Environment

Enterprise-grade production deployment:

```bash
# Create namespace
kubectl create namespace webapp-prod

# Deploy to production
kubectl apply -k overlays/production

# Verify all components
kubectl get all,pdb,hpa,vpa,networkpolicy -n webapp-prod

# Check backup jobs
kubectl get cronjob -n webapp-prod
```

## 🧑‍🎓 Beginner's Step-by-Step Testing Guide

**Perfect for newcomers!** Follow these exact commands to test Kustomize across multiple environments.

### 🏁 Pre-Flight Check

```bash
# 1. Verify you're in the right directory
pwd
# Should show: /Users/your-username/Documents/GCP/Kustomize

# 2. Check you're connected to your cluster
kubectl cluster-info
# Should show your GKE cluster info

# 3. Verify kustomize is available
kubectl kustomize --help
# Should show kustomize command options
```

### 🎯 Step 1: Explore Before Deploying

Let's understand what we're about to deploy:

```bash
# See the project structure
tree -L 3

# Check what's in base (your core application)
ls -la base/
cat base/kustomization.yaml

# Check what's in each environment
ls -la overlays/dev/
ls -la overlays/staging/
ls -la overlays/production/
```

### 🎯 Step 2: Preview Each Environment (No Deployment Yet!)

**Development Preview:**
```bash
echo "=== DEVELOPMENT ENVIRONMENT PREVIEW ==="
kubectl kustomize overlays/dev

# Notice:
# - All resources have "dev-" prefix
# - Namespace is "webapp-dev"
# - Only 1 replica
# - Minimal resources
```

**Staging Preview:**
```bash
echo "=== STAGING ENVIRONMENT PREVIEW ==="
kubectl kustomize overlays/staging

# Notice additional resources:
# - Ingress for external access
# - HorizontalPodAutoscaler
# - NetworkPolicy for security
# - 3 replicas
```

**Production Preview:**
```bash
echo "=== PRODUCTION ENVIRONMENT PREVIEW ==="
kubectl kustomize overlays/production

# Notice enterprise features:
# - 5 replicas
# - Pod Disruption Budget
# - Vertical Pod Autoscaler
# - ServiceMonitor for monitoring
# - Backup CronJob
# - Advanced security policies
```

### 🎯 Step 3: Setup Your Cluster

Now let's prepare your cluster:

```bash
# Run the automated setup
./scripts/setup-demo.sh

# This creates namespaces and sets up prerequisites
# Watch the output carefully - it tells you what it's doing!
```

### 🎯 Step 4: Deploy Development (Your First Environment!)

```bash
echo "🚀 DEPLOYING DEVELOPMENT ENVIRONMENT"

# Deploy development
kubectl apply -k overlays/dev

# Watch the deployment
kubectl get pods -n webapp-dev -w
# Press Ctrl+C when pods are Running

# Check what was created
kubectl get all -n webapp-dev

# Test the application
kubectl port-forward -n webapp-dev svc/dev-web-app-service 8080:80 &
sleep 3
curl http://localhost:8080/health || echo "App is starting up..."
pkill -f "port-forward"
```

### 🎯 Step 5: Deploy Staging (More Features!)

```bash
echo "🚀 DEPLOYING STAGING ENVIRONMENT"

# Deploy staging
kubectl apply -k overlays/staging

# Watch HPA in action
kubectl get hpa -n webapp-staging -w &
HPA_PID=$!

# Monitor deployment
./scripts/monitor.sh staging

# Stop watching HPA
kill $HPA_PID 2>/dev/null || true

# Generate some load to test HPA (optional)
kubectl run load-generator --rm -i --tty --restart=Never --image=busybox \
  -- /bin/sh -c "while true; do wget -q -O- http://staging-web-app-service.webapp-staging.svc.cluster.local; done"
```

### 🎯 Step 6: Deploy Production (Full Enterprise!)

```bash
echo "🚀 DEPLOYING PRODUCTION ENVIRONMENT"

# Deploy production
kubectl apply -k overlays/production

# Monitor all production resources
./scripts/monitor.sh prod

# Check advanced features
echo "=== Production Features ==="
kubectl get hpa,vpa,pdb,networkpolicy -n webapp-prod
kubectl get cronjob -n webapp-prod
```

### 🎯 Step 7: Compare the Environments

Now let's see the differences Kustomize created:

```bash
echo "=== COMPARING ENVIRONMENTS ==="

# Compare replica counts
echo "Dev replicas:"
kubectl get deployment -n webapp-dev -o jsonpath='{.items[0].spec.replicas}'
echo ""

echo "Staging replicas:"
kubectl get deployment -n webapp-staging -o jsonpath='{.items[0].spec.replicas}'
echo ""

echo "Production replicas:"
kubectl get deployment -n webapp-prod -o jsonpath='{.items[0].spec.replicas}'
echo ""

# Compare resource requests
echo "=== RESOURCE COMPARISON ==="
echo "Development resources:"
kubectl get deployment -n webapp-dev -o jsonpath='{.items[0].spec.template.spec.containers[0].resources}'
echo ""

echo "Production resources:"
kubectl get deployment -n webapp-prod -o jsonpath='{.items[0].spec.template.spec.containers[0].resources}'
echo ""

# Count total resources per environment
echo "=== RESOURCE COUNT COMPARISON ==="
echo "Development resources: $(kubectl get all -n webapp-dev --no-headers | wc -l)"
echo "Staging resources: $(kubectl get all -n webapp-staging --no-headers | wc -l)"
echo "Production resources: $(kubectl get all -n webapp-prod --no-headers | wc -l)"
```

### 🎯 Step 8: Use the Monitoring Script

```bash
# Get a complete overview
./scripts/monitor.sh

# Check specific environment
./scripts/monitor.sh dev
./scripts/monitor.sh staging  
./scripts/monitor.sh prod
```

### 🎯 Step 9: Test Live Updates

Let's see how easy it is to update configurations:

```bash
echo "=== TESTING LIVE UPDATES ==="

# Check current development replicas
kubectl get deployment -n webapp-dev -o jsonpath='{.items[0].spec.replicas}'

# Update development to 2 replicas
# Edit overlays/dev/kustomization.yaml
# Change: count: 1 to count: 2

# Apply the update
kubectl apply -k overlays/dev

# Watch the new pod being created
kubectl get pods -n webapp-dev -w
# Press Ctrl+C after you see 2 pods running

echo "See how easy that was? No downtime, just a smooth update!"
```

### 🎯 Step 10: Understanding What You Achieved

Congratulations! You just:

✅ **Deployed the same application** to 3 different environments
✅ **Each environment** has different configurations automatically
✅ **Used a single command** per environment (`kubectl apply -k`)
✅ **No complex templating** - just simple YAML patches
✅ **Production-ready features** like auto-scaling, monitoring, backups
✅ **Security best practices** built-in

### 🧹 Step 11: Cleanup (Optional)

When you're done exploring:

```bash
# Clean up all environments
./scripts/cleanup.sh

# Or clean up one at a time
./scripts/cleanup.sh dev
./scripts/cleanup.sh staging
./scripts/cleanup.sh production
```

---

## 🎬 Complete Demo Walkthrough

Follow this step-by-step walkthrough to see Kustomize in action:

### Step 1: Initial Setup

```bash
# 1. Verify you're connected to your cluster
kubectl cluster-info

# 2. Run the setup script
./scripts/setup-demo.sh

# 3. Verify setup
./scripts/monitor.sh
```

### Step 2: Deploy Development Environment

```bash
# Preview what will be deployed
echo "=== Previewing Development Deployment ==="
kubectl kustomize overlays/dev

# Deploy to development
echo "=== Deploying to Development ==="
kubectl apply -k overlays/dev

# Monitor the deployment
kubectl rollout status deployment/dev-web-app -n webapp-dev
kubectl rollout status statefulset/dev-postgres -n webapp-dev

# Check status
./scripts/monitor.sh dev

# Test the application
kubectl port-forward -n webapp-dev svc/dev-web-app-service 8080:80 &
sleep 5
curl http://localhost:8080 || echo "App starting up..."
pkill -f "port-forward"
```

### Step 3: Deploy Staging Environment

```bash
# Deploy to staging (includes ingress, HPA, network policies)
echo "=== Deploying to Staging ==="
kubectl apply -k overlays/staging

# Watch HPA in action
kubectl get hpa -n webapp-staging -w &
HPA_PID=$!

# Monitor deployment
./scripts/monitor.sh staging

# Stop watching HPA
kill $HPA_PID 2>/dev/null || true

# Generate some load to test HPA (optional)
kubectl run load-generator --rm -i --tty --restart=Never --image=busybox \
  -- /bin/sh -c "while true; do wget -q -O- http://staging-web-app-service.webapp-staging.svc.cluster.local; done"
```

### Step 4: Deploy Production Environment

```bash
# Deploy to production (full enterprise setup)
echo "=== Deploying to Production ==="

# First, let's see what will be deployed
kubectl kustomize overlays/production | head -50

# Deploy
kubectl apply -k overlays/production

# Monitor all production resources
./scripts/monitor.sh prod

# Check advanced features
echo "=== Production Features ==="
kubectl get hpa,vpa,pdb,networkpolicy -n webapp-prod
kubectl get cronjob -n webapp-prod
```

### Step 5: Demonstrate Kustomize Power

```bash
# Show differences between environments
echo "=== Environment Differences ==="

echo "Development replicas:"
kubectl get deployment dev-web-app -n webapp-dev -o jsonpath='{.spec.replicas}'

echo "Staging replicas:"
kubectl get deployment staging-web-app -n webapp-staging -o jsonpath='{.spec.replicas}'

echo "Production replicas:"
kubectl get deployment prod-web-app -n webapp-prod -o jsonpath='{.spec.replicas}'

# Show resource differences
echo -e "\n=== RESOURCE DIFFERENCES ==="
for env in dev staging prod; do
  namespace="webapp-$env"
  echo "=== $env environment ==="
  kubectl get deployment "${env}-web-app" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .
done
```

### Step 6: Live Configuration Updates

```bash
# Demonstrate live updates using Kustomize
echo "=== Live Configuration Update Demo ==="

# Update development environment (add a label)
cd overlays/dev
# Add this to kustomization.yaml under commonLabels:
# demo-update: "live-demo"

# Apply the update
kubectl apply -k .
cd ../..

# Show the change
kubectl get deployment dev-web-app -n webapp-dev --show-labels
```

### Step 7: Monitoring and Troubleshooting

```bash
# Use the monitoring script
./scripts/monitor.sh

# Check logs across environments
echo "=== Application Logs ==="
kubectl logs -l app=web-app -n webapp-dev --tail=10
kubectl logs -l app=web-app -n webapp-staging --tail=10
kubectl logs -l app=web-app -n webapp-prod --tail=10

# Check events
echo "=== Recent Events ==="
./scripts/monitor.sh events
```

### Step 8: Cleanup (Optional)

```bash
# Clean up demo resources
./scripts/cleanup.sh

# Or clean up specific environments
./scripts/cleanup.sh dev
./scripts/cleanup.sh staging
./scripts/cleanup.sh production
```

## 🎓 Explore Advanced Concepts

Once you're comfortable with the basics, dive into expert-level patterns:

```bash
# Advanced variable substitution and replacements
kubectl kustomize examples/advanced/ --enable-alpha-plugins

# Multi-base composition patterns
cat examples/advanced/multi-base.yaml

# Custom transformer examples  
cat examples/advanced/transformers.yaml

# GitOps integration patterns
cat examples/gitops/README.md
```

---

## 📋 Complete Kustomize Concepts Coverage

This project now covers **ALL major Kustomize concepts** from beginner to expert level:

### 🎯 **Fundamental Concepts** ✅
- [x] **Base Resources** - Core application definitions
- [x] **Overlays** - Environment-specific customizations  
- [x] **Strategic Merge Patches** - Intelligent YAML merging
- [x] **JSON Patches** - Precise field operations
- [x] **Generators** - ConfigMaps and Secrets creation
- [x] **Transformers** - Bulk resource modifications
- [x] **Name/Namespace** - Resource naming strategies
- [x] **Labels/Annotations** - Metadata management
- [x] **Images** - Container image management

### 🚀 **Intermediate Concepts** ✅
- [x] **Components** - Reusable configuration blocks
- [x] **Multi-base Patterns** - Composing multiple bases
- [x] **Remote Resources** - Git and HTTP resource inclusion
- [x] **Replacements** - Advanced variable substitution
- [x] **Patch Strategies** - Different patching approaches
- [x] **Resource Ordering** - Dependency management
- [x] **Validation** - Schema and policy validation
- [x] **Environment Management** - Dev/staging/production patterns

### 🎓 **Advanced Concepts** ✅
- [x] **Custom Transformers** - Extending Kustomize functionality
- [x] **OpenAPI Validation** - Schema-based validation
- [x] **Plugin System** - Exec and Go plugins
- [x] **Replacements** - Modern variable substitution (successor to vars)
- [x] **Multi-base Patterns** - Composing multiple base configurations
- [x] **Variable Substitution** - Dynamic configuration across resources
- [x] **Generator Options** - Advanced generation behaviors
- [x] **Performance Optimization** - Large-scale optimization
- [x] **Complex Dependencies** - Inter-resource dependencies
- [x] **Multi-cluster Patterns** - Cross-cluster deployments
- [x] **GitOps Integration** - CI/CD workflow patterns

### 🏭 **Production Concepts** ✅
- [x] **Security Best Practices** - Security contexts, RBAC, network policies
- [x] **Monitoring Integration** - ServiceMonitor, Prometheus, Grafana
- [x] **Backup Strategies** - Automated backup and recovery
- [x] **Scaling Patterns** - HPA, VPA, replica management
- [x] **High Availability** - PDB, anti-affinity, fault tolerance
- [x] **Secret Management** - External secret integration
- [x] **Compliance** - Policy enforcement and validation
- [x] **Operational Excellence** - Monitoring, logging, alerting

### 🔧 **Development Workflow** ✅
- [x] **Local Development** - Testing and debugging
- [x] **Preview and Dry-run** - Safe deployment practices
- [x] **Live Updates** - Configuration updates without downtime
- [x] **Troubleshooting** - Common issues and solutions
- [x] **Migration Strategies** - Moving from Helm and other tools
- [x] **Testing Patterns** - Validation and quality assurance

### 📚 **Learning Progression** ✅
- [x] **Conceptual Understanding** - What and why
- [x] **Hands-on Examples** - Step-by-step tutorials
- [x] **Real-world Patterns** - Production-ready configurations
- [x] **Best Practices** - Industry standards and conventions
- [x] **Common Pitfalls** - What to avoid
- [x] **Advanced Techniques** - Expert-level patterns
