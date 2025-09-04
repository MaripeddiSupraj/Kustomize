#!/bin/bash

# GKE Cluster Setup Script for Kustomize Learning Project
# This script creates a production-ready GKE cluster with best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID=""
CLUSTER_NAME="kustomize-demo"
REGION="us-central1"
ZONE="us-central1-a"
NODE_COUNT=3
MACHINE_TYPE="e2-standard-4"
DISK_SIZE="50"
MIN_NODES=1
MAX_NODES=10

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

# Function to show usage
show_usage() {
    cat << EOF
GKE Cluster Setup Script

Usage: $0 --project-id <PROJECT_ID> [options]

Required:
  --project-id     GCP Project ID

Options:
  --cluster-name   Cluster name (default: kustomize-demo)
  --region         GCP region (default: us-central1)
  --zone           GCP zone (default: us-central1-a)
  --node-count     Initial node count (default: 3)
  --machine-type   Node machine type (default: e2-standard-4)
  --disk-size      Node disk size in GB (default: 50)
  --min-nodes      Minimum nodes for autoscaling (default: 1)
  --max-nodes      Maximum nodes for autoscaling (default: 10)
  -h, --help       Show this help message

Examples:
  $0 --project-id my-gcp-project
  $0 --project-id my-project --cluster-name prod-cluster --region us-west1

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first:"
        print_error "https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first:"
        print_error "https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to authenticate and set project
setup_gcp_auth() {
    print_status "Setting up GCP authentication and project..."
    
    # Set the project
    gcloud config set project "$PROJECT_ID"
    
    # Verify authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_warning "Not authenticated with gcloud. Running authentication..."
        gcloud auth login
    fi
    
    print_success "GCP authentication setup complete"
}

# Function to enable required APIs
enable_apis() {
    print_status "Enabling required GCP APIs..."
    
    local apis=(
        "container.googleapis.com"
        "compute.googleapis.com"
        "monitoring.googleapis.com"
        "logging.googleapis.com"
        "cloudasset.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
    
    print_success "All required APIs enabled"
}

# Function to create GKE cluster
create_cluster() {
    print_status "Creating GKE cluster: $CLUSTER_NAME"
    print_status "Project: $PROJECT_ID"
    print_status "Region: $REGION"
    print_status "Machine Type: $MACHINE_TYPE"
    print_status "Initial Nodes: $NODE_COUNT"
    print_status "Autoscaling: $MIN_NODES - $MAX_NODES nodes"
    
    # Check if cluster already exists
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME already exists in region $REGION"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Deleting existing cluster..."
            gcloud container clusters delete "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet
        else
            print_status "Using existing cluster"
            return 0
        fi
    fi
    
    # Create the cluster with production best practices
    gcloud container clusters create "$CLUSTER_NAME" \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --machine-type="$MACHINE_TYPE" \
        --disk-size="$DISK_SIZE" \
        --num-nodes="$NODE_COUNT" \
        --enable-autoscaling \
        --min-nodes="$MIN_NODES" \
        --max-nodes="$MAX_NODES" \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-network-policy \
        --enable-ip-alias \
        --enable-autoprovisioning \
        --max-surge=1 \
        --max-unavailable=0 \
        --enable-shielded-nodes \
        --enable-autorepair \
        --enable-autoupgrade \
        --maintenance-window-start="2023-01-01T09:00:00Z" \
        --maintenance-window-end="2023-01-01T17:00:00Z" \
        --maintenance-window-recurrence="FREQ=WEEKLY;BYDAY=SA,SU" \
        --logging=SYSTEM,WORKLOAD \
        --monitoring=SYSTEM \
        --enable-cloud-logging \
        --enable-cloud-monitoring \
        --node-labels="environment=production,managed-by=kustomize" \
        --node-taints="" \
        --preemptible=false \
        --spot=false \
        --enable-private-nodes \
        --master-ipv4-cidr="172.16.0.0/28" \
        --enable-master-authorized-networks \
        --master-authorized-networks="0.0.0.0/0" \
        --cluster-version="latest" \
        --release-channel="regular" \
        --enable-workload-identity \
        --workload-pool="$PROJECT_ID.svc.id.goog" \
        --enable-cluster-autoscaling \
        --max-nodes-per-pool=1000 \
        --enable-vertical-pod-autoscaling \
        --security-posture=standard \
        --workload-vulnerability-scanning=standard
        
    print_success "GKE cluster created successfully!"
}

# Function to get cluster credentials
get_credentials() {
    print_status "Getting cluster credentials..."
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
        
    print_success "Cluster credentials configured"
}

# Function to install cluster components
install_cluster_components() {
    print_status "Installing cluster components..."
    
    # Install metrics server (if not already installed)
    if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        print_status "Installing metrics-server..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    fi
    
    # Install NGINX Ingress Controller (optional, GKE has built-in)
    read -p "Do you want to install NGINX Ingress Controller? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
    fi
    
    print_success "Cluster components installed"
}

# Function to verify cluster setup
verify_cluster() {
    print_status "Verifying cluster setup..."
    
    # Check cluster info
    echo ""
    print_status "Cluster Information:"
    kubectl cluster-info
    echo ""
    
    # Check nodes
    print_status "Cluster Nodes:"
    kubectl get nodes -o wide
    echo ""
    
    # Check system pods
    print_status "System Pods:"
    kubectl get pods -n kube-system
    echo ""
    
    print_success "Cluster verification complete"
}

# Function to show next steps
show_next_steps() {
    cat << EOF

${GREEN}🎉 GKE Cluster Setup Complete!${NC}

Your cluster is ready for Kustomize deployments. Here are the next steps:

${BLUE}1. Deploy to Development:${NC}
   ./scripts/deploy.sh dev

${BLUE}2. Deploy to Staging:${NC}
   ./scripts/deploy.sh staging

${BLUE}3. Deploy to Production:${NC}
   ./scripts/deploy.sh production

${BLUE}4. Monitor your deployments:${NC}
   kubectl get pods -A
   kubectl top nodes
   kubectl top pods -A

${BLUE}5. Clean up (when done):${NC}
   gcloud container clusters delete $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID

${YELLOW}Important Notes:${NC}
- Your cluster has autoscaling enabled ($MIN_NODES-$MAX_NODES nodes)
- Network policies are enabled for security
- Workload Identity is configured for GCP service integration
- Monitoring and logging are enabled

${YELLOW}Estimated Costs:${NC}
- Base cluster: ~\$73/month (3 x e2-standard-4 nodes)
- Additional costs for: Load balancers, persistent disks, egress traffic

Happy Kustomizing! 🚀

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-id)
            PROJECT_ID="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --zone)
            ZONE="$2"
            shift 2
            ;;
        --node-count)
            NODE_COUNT="$2"
            shift 2
            ;;
        --machine-type)
            MACHINE_TYPE="$2"
            shift 2
            ;;
        --disk-size)
            DISK_SIZE="$2"
            shift 2
            ;;
        --min-nodes)
            MIN_NODES="$2"
            shift 2
            ;;
        --max-nodes)
            MAX_NODES="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if project ID is provided
if [[ -z "$PROJECT_ID" ]]; then
    print_error "Project ID is required"
    show_usage
    exit 1
fi

# Main execution
main() {
    print_status "Starting GKE cluster setup"
    echo ""
    
    check_prerequisites
    setup_gcp_auth
    enable_apis
    create_cluster
    get_credentials
    install_cluster_components
    verify_cluster
    show_next_steps
    
    print_success "GKE setup script completed successfully!"
}

# Run main function
main
