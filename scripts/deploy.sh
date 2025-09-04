#!/bin/bash

# Kustomize Deployment Script
# Usage: ./deploy.sh <environment> [dry-run]

set -e

ENVIRONMENT=${1:-dev}
DRY_RUN=${2:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate environment
case $ENVIRONMENT in
    dev|staging|production)
        print_status "Deploying to $ENVIRONMENT environment"
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        print_error "Valid environments: dev, staging, production"
        exit 1
        ;;
esac

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    print_error "kustomize is not installed. Please install it first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

# Set overlay path
OVERLAY_PATH="overlays/$ENVIRONMENT"

if [ ! -d "$OVERLAY_PATH" ]; then
    print_error "Overlay directory not found: $OVERLAY_PATH"
    exit 1
fi

print_status "Building kustomization for $ENVIRONMENT..."

# Build the kustomization
if ! kustomize build "$OVERLAY_PATH" > "/tmp/kustomize-$ENVIRONMENT.yaml"; then
    print_error "Failed to build kustomization"
    exit 1
fi

print_success "Kustomization built successfully"

# Validate the generated YAML
print_status "Validating generated manifests..."
if ! kubectl apply --dry-run=client -f "/tmp/kustomize-$ENVIRONMENT.yaml" &> /dev/null; then
    print_error "Generated manifests are invalid"
    exit 1
fi

print_success "Manifests validation passed"

# Show what will be deployed
print_status "Resources to be deployed:"
kubectl apply --dry-run=client -f "/tmp/kustomize-$ENVIRONMENT.yaml" | grep -E "^(deployment|service|configmap|secret|ingress|hpa|pdb|networkpolicy)"

if [ "$DRY_RUN" = "true" ] || [ "$DRY_RUN" = "dry-run" ]; then
    print_warning "Dry run mode - no resources will be deployed"
    print_status "Generated manifest saved to: /tmp/kustomize-$ENVIRONMENT.yaml"
    exit 0
fi

# Confirm deployment
echo
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Deploy the resources
print_status "Deploying to Kubernetes cluster..."

if kubectl apply -f "/tmp/kustomize-$ENVIRONMENT.yaml"; then
    print_success "Deployment completed successfully!"
    
    # Show deployment status
    print_status "Checking deployment status..."
    kubectl get pods,svc,ingress -n "webapp-$ENVIRONMENT" 2>/dev/null || kubectl get pods,svc,ingress -n default
    
else
    print_error "Deployment failed"
    exit 1
fi

# Cleanup
rm -f "/tmp/kustomize-$ENVIRONMENT.yaml"

print_success "Deployment script completed!"
