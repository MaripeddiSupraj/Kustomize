#!/bin/bash

# Cleanup Script for Kustomize Demo
# Safely removes demo resources from your cluster

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
    echo "       Kustomize Demo Cleanup Script"
    echo "=============================================="
    echo -e "${NC}"
}

cleanup_environment() {
    local env=$1
    local namespace="webapp-$env"
    
    print_status "Cleaning up $env environment ($namespace)..."
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace $namespace doesn't exist, skipping"
        return
    fi
    
    # Delete resources using kustomize
    if [ -d "overlays/$env" ]; then
        print_status "Deleting resources from overlays/$env..."
        kubectl delete -k "overlays/$env" --ignore-not-found=true
    fi
    
    # Delete namespace
    kubectl delete namespace "$namespace" --ignore-not-found=true
    
    print_success "Cleaned up $env environment"
}

cleanup_storage_classes() {
    print_status "Cleaning up demo storage classes..."
    
    kubectl delete storageclass ssd-retain --ignore-not-found=true
    
    print_success "Storage classes cleaned up"
}

cleanup_prometheus_operator() {
    echo
    read -p "Do you want to remove Prometheus Operator? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing Prometheus Operator..."
        kubectl delete -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml --ignore-not-found=true
        print_success "Prometheus Operator removed"
    else
        print_warning "Keeping Prometheus Operator"
    fi
}

show_remaining_resources() {
    print_status "Checking for remaining demo resources..."
    
    # Check for any remaining PVCs
    echo -e "\n${YELLOW}Remaining PVCs:${NC}"
    kubectl get pvc --all-namespaces | grep -E "(webapp|kustomize)" || echo "None found"
    
    # Check for any remaining PVs
    echo -e "\n${YELLOW}Remaining PVs:${NC}"
    kubectl get pv | grep -E "(webapp|kustomize)" || echo "None found"
    
    # Check for any remaining load balancers
    echo -e "\n${YELLOW}Remaining LoadBalancer services:${NC}"
    kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer | grep -E "(webapp|kustomize)" || echo "None found"
}

confirm_cleanup() {
    echo -e "${RED}⚠️  WARNING: This will delete all demo resources${NC}"
    echo -e "${RED}This includes:${NC}"
    echo "  - All webapp namespaces (dev, staging, prod)"
    echo "  - All deployed applications"
    echo "  - All persistent volumes and data"
    echo "  - Custom storage classes"
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Cleanup cancelled"
        exit 0
    fi
}

# Main function
main() {
    print_header
    
    # Confirm before proceeding
    confirm_cleanup
    
    # Clean up each environment
    cleanup_environment "dev"
    cleanup_environment "staging" 
    cleanup_environment "production"
    
    # Clean up shared resources
    cleanup_storage_classes
    
    # Optionally clean up Prometheus Operator
    cleanup_prometheus_operator
    
    # Show any remaining resources
    show_remaining_resources
    
    print_success "Demo cleanup completed!"
    print_status "Your cluster is ready for new demos"
}

# Handle command line arguments
case "${1:-}" in
    "dev")
        cleanup_environment "dev"
        ;;
    "staging")
        cleanup_environment "staging"
        ;;
    "production")
        cleanup_environment "production"
        ;;
    "storage")
        cleanup_storage_classes
        ;;
    "--force")
        # Skip confirmation for CI/CD
        cleanup_environment "dev"
        cleanup_environment "staging"
        cleanup_environment "production"
        cleanup_storage_classes
        ;;
    *)
        main
        ;;
esac
