#!/bin/bash

# Kustomize Demo Setup Script for Existing GKE Cluster
# This script prepares your existing GKE cluster for the Kustomize demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Kustomize Demo Setup for Existing GKE"
    echo "=============================================="
    echo -e "${NC}"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check kustomize
    if ! command -v kustomize &> /dev/null; then
        print_warning "kustomize not found. Installing..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/ 2>/dev/null || mv kustomize /usr/local/bin/
    fi
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        print_warning "gcloud CLI not found. Some features may be limited."
    fi
    
    print_success "Prerequisites check completed"
}

check_cluster_connection() {
    print_status "Checking cluster connection..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        print_error "Please ensure you have the correct kubeconfig and cluster access."
        exit 1
    fi
    
    CLUSTER_NAME=$(kubectl config current-context)
    print_success "Connected to cluster: $CLUSTER_NAME"
    
    # Show cluster info
    print_status "Cluster information:"
    kubectl cluster-info --context=$CLUSTER_NAME | head -5
}

setup_namespaces() {
    print_status "Setting up namespaces..."
    
    namespaces=("webapp-dev" "webapp-staging" "webapp-prod")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            print_warning "Namespace $ns already exists"
        else
            kubectl create namespace "$ns"
            print_success "Created namespace: $ns"
        fi
        
        # Add labels for better organization
        kubectl label namespace "$ns" environment="${ns#webapp-}" --overwrite
        kubectl label namespace "$ns" managed-by="kustomize-demo" --overwrite
    done
}

setup_storage_classes() {
    print_status "Setting up storage classes..."
    
    # Check if we're on GKE
    if kubectl get nodes -o yaml | grep -q "gke"; then
        # Create SSD storage class for production
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd-retain
  labels:
    app: kustomize-demo
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
        print_success "Created SSD storage class for production"
    else
        print_warning "Not running on GKE, skipping GCE-specific storage class"
    fi
}

install_prometheus_operator() {
    print_status "Checking for Prometheus Operator..."
    
    if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        print_success "Prometheus Operator already installed"
    else
        print_warning "ServiceMonitor CRD not found. Installing Prometheus Operator..."
        
        # Install Prometheus Operator
        kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
        
        # Wait for CRDs to be ready
        print_status "Waiting for Prometheus Operator CRDs..."
        kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=60s
        
        print_success "Prometheus Operator installed"
    fi
}

setup_rbac() {
    print_status "Setting up RBAC..."
    
    # Create service accounts for each environment
    environments=("dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        namespace="webapp-$env"
        sa_name="webapp-sa"
        
        # Create service account
        kubectl create serviceaccount "$sa_name" -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -
        
        # Create role binding
        kubectl create rolebinding "webapp-$env-binding" \
            --clusterrole=view \
            --serviceaccount="$namespace:$sa_name" \
            -n "$namespace" \
            --dry-run=client -o yaml | kubectl apply -f -
            
        print_success "RBAC configured for $namespace"
    done
}

validate_demo_readiness() {
    print_status "Validating demo readiness..."
    
    # Check if we can build kustomizations
    for env in dev staging production; do
        if kustomize build "overlays/$env" > /dev/null 2>&1; then
            print_success "Kustomization valid for $env"
        else
            print_error "Kustomization invalid for $env"
            exit 1
        fi
    done
    
    # Check node resources
    print_status "Checking cluster resources..."
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
    
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    print_status "Cluster has $NODE_COUNT nodes"
    
    if [ "$NODE_COUNT" -lt 3 ]; then
        print_warning "Consider having at least 3 nodes for production-like demo"
    fi
}

create_demo_secrets() {
    print_status "Creating demo secrets (for development only)..."
    
    # Only create secrets for dev and staging - production should use external secret management
    for env in dev staging; do
        namespace="webapp-$env"
        
        # Create database credentials
        kubectl create secret generic db-credentials \
            --from-literal=username="${env}_user" \
            --from-literal=password="${env}_password_$(date +%s)" \
            -n "$namespace" \
            --dry-run=client -o yaml | kubectl apply -f -
            
        print_success "Demo secrets created for $namespace"
    done
    
    print_warning "Production secrets should be managed externally (Google Secret Manager, etc.)"
}

show_next_steps() {
    print_status "Setup completed! Here's what to do next:"
    echo
    echo -e "${GREEN}1. Deploy to Development:${NC}"
    echo "   kubectl apply -k overlays/dev"
    echo
    echo -e "${GREEN}2. Deploy to Staging:${NC}"
    echo "   kubectl apply -k overlays/staging"
    echo
    echo -e "${GREEN}3. Deploy to Production:${NC}"
    echo "   kubectl apply -k overlays/production"
    echo
    echo -e "${GREEN}4. Use the deployment script:${NC}"
    echo "   ./scripts/deploy.sh dev"
    echo "   ./scripts/deploy.sh staging"
    echo "   ./scripts/deploy.sh production"
    echo
    echo -e "${GREEN}5. Monitor deployments:${NC}"
    echo "   ./scripts/monitor.sh"
    echo
    echo -e "${YELLOW}Note: Update domain names in ingress files before deploying staging/production${NC}"
}

# Main execution
main() {
    print_header
    
    check_prerequisites
    check_cluster_connection
    setup_namespaces
    setup_storage_classes
    install_prometheus_operator
    setup_rbac
    create_demo_secrets
    validate_demo_readiness
    
    print_success "Demo setup completed successfully!"
    show_next_steps
}

# Run main function
main "$@"
