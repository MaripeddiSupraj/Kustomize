#!/bin/bash

# Monitoring and Status Script for Kustomize Demo
# Shows the status of deployments across all environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}"
    echo "=============================================="
    echo "        Kustomize Demo Status Monitor"
    echo "=============================================="
    echo -e "${NC}"
}

show_namespace_status() {
    local namespace=$1
    local env_name=$2
    
    echo -e "\n${BLUE}📊 $env_name Environment ($namespace)${NC}"
    echo "----------------------------------------"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        echo -e "${RED}❌ Namespace not found${NC}"
        return
    fi
    
    # Pods status
    echo -e "\n${YELLOW}Pods:${NC}"
    kubectl get pods -n "$namespace" --no-headers 2>/dev/null | while read line; do
        if echo "$line" | grep -q "Running"; then
            echo -e "  ${GREEN}✅ $line${NC}"
        elif echo "$line" | grep -q "Pending\|ContainerCreating"; then
            echo -e "  ${YELLOW}⏳ $line${NC}"
        else
            echo -e "  ${RED}❌ $line${NC}"
        fi
    done || echo "  No pods found"
    
    # Services
    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get svc -n "$namespace" --no-headers 2>/dev/null | while read line; do
        echo -e "  ${GREEN}🔗 $line${NC}"
    done || echo "  No services found"
    
    # Ingress (if exists)
    if kubectl get ingress -n "$namespace" &> /dev/null; then
        echo -e "\n${YELLOW}Ingress:${NC}"
        kubectl get ingress -n "$namespace" --no-headers 2>/dev/null | while read line; do
            echo -e "  ${GREEN}🌐 $line${NC}"
        done
    fi
    
    # HPA (if exists)
    if kubectl get hpa -n "$namespace" &> /dev/null; then
        echo -e "\n${YELLOW}Horizontal Pod Autoscaler:${NC}"
        kubectl get hpa -n "$namespace" --no-headers 2>/dev/null | while read line; do
            echo -e "  ${GREEN}📈 $line${NC}"
        done
    fi
    
    # PDB (if exists)
    if kubectl get pdb -n "$namespace" &> /dev/null; then
        echo -e "\n${YELLOW}Pod Disruption Budget:${NC}"
        kubectl get pdb -n "$namespace" --no-headers 2>/dev/null | while read line; do
            echo -e "  ${GREEN}🛡️ $line${NC}"
        done
    fi
    
    # Storage
    echo -e "\n${YELLOW}Persistent Volumes:${NC}"
    kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | while read line; do
        if echo "$line" | grep -q "Bound"; then
            echo -e "  ${GREEN}💾 $line${NC}"
        else
            echo -e "  ${YELLOW}⏳ $line${NC}"
        fi
    done || echo "  No PVCs found"
}

show_resource_usage() {
    echo -e "\n${BLUE}📊 Resource Usage${NC}"
    echo "----------------------------------------"
    
    # Node usage
    echo -e "\n${YELLOW}Node Resources:${NC}"
    kubectl top nodes 2>/dev/null || echo "  Metrics server not available"
    
    # Pod usage by namespace
    for ns in webapp-dev webapp-staging webapp-prod; do
        if kubectl get namespace "$ns" &> /dev/null; then
            echo -e "\n${YELLOW}Pod Resources ($ns):${NC}"
            kubectl top pods -n "$ns" 2>/dev/null || echo "  No metrics available"
        fi
    done
}

show_events() {
    echo -e "\n${BLUE}📋 Recent Events${NC}"
    echo "----------------------------------------"
    
    for ns in webapp-dev webapp-staging webapp-prod; do
        if kubectl get namespace "$ns" &> /dev/null; then
            echo -e "\n${YELLOW}Events in $ns:${NC}"
            kubectl get events -n "$ns" --sort-by='.lastTimestamp' | tail -5 2>/dev/null || echo "  No events"
        fi
    done
}

test_connectivity() {
    echo -e "\n${BLUE}🔌 Connectivity Tests${NC}"
    echo "----------------------------------------"
    
    for ns in webapp-dev webapp-staging webapp-prod; do
        if kubectl get namespace "$ns" &> /dev/null; then
            echo -e "\n${YELLOW}Testing $ns:${NC}"
            
            # Check if web service is accessible
            WEB_SVC=$(kubectl get svc -n "$ns" --no-headers | grep web-app | awk '{print $1}' | head -1)
            if [ -n "$WEB_SVC" ]; then
                if kubectl get endpoints "$WEB_SVC" -n "$ns" &> /dev/null; then
                    echo -e "  ${GREEN}✅ Web service has endpoints${NC}"
                else
                    echo -e "  ${RED}❌ Web service has no endpoints${NC}"
                fi
            fi
            
            # Check database connectivity
            DB_SVC=$(kubectl get svc -n "$ns" --no-headers | grep postgres | awk '{print $1}' | head -1)
            if [ -n "$DB_SVC" ]; then
                if kubectl get endpoints "$DB_SVC" -n "$ns" &> /dev/null; then
                    echo -e "  ${GREEN}✅ Database service has endpoints${NC}"
                else
                    echo -e "  ${RED}❌ Database service has no endpoints${NC}"
                fi
            fi
        fi
    done
}

show_quick_commands() {
    echo -e "\n${BLUE}🚀 Quick Commands${NC}"
    echo "----------------------------------------"
    echo
    echo -e "${YELLOW}Port Forward (Development):${NC}"
    echo "  kubectl port-forward -n webapp-dev svc/dev-web-app-service 8080:80"
    echo
    echo -e "${YELLOW}View Logs:${NC}"
    echo "  kubectl logs -f deployment/dev-web-app -n webapp-dev"
    echo "  kubectl logs -f deployment/staging-web-app -n webapp-staging"
    echo "  kubectl logs -f deployment/prod-web-app -n webapp-prod"
    echo
    echo -e "${YELLOW}Scale Deployments:${NC}"
    echo "  kubectl scale deployment dev-web-app --replicas=2 -n webapp-dev"
    echo
    echo -e "${YELLOW}Update with Kustomize:${NC}"
    echo "  kubectl apply -k overlays/dev"
    echo "  kubectl apply -k overlays/staging"
    echo "  kubectl apply -k overlays/production"
    echo
    echo -e "${YELLOW}Clean Up:${NC}"
    echo "  kubectl delete namespace webapp-dev webapp-staging webapp-prod"
}

# Main function
main() {
    print_header
    
    # Show status for each environment
    show_namespace_status "webapp-dev" "Development"
    show_namespace_status "webapp-staging" "Staging"
    show_namespace_status "webapp-prod" "Production"
    
    # Show resource usage
    show_resource_usage
    
    # Show recent events
    show_events
    
    # Test connectivity
    test_connectivity
    
    # Show helpful commands
    show_quick_commands
    
    echo -e "\n${GREEN}Monitor completed! 🎉${NC}"
}

# Handle arguments
case "${1:-}" in
    "events")
        show_events
        ;;
    "resources")
        show_resource_usage
        ;;
    "connectivity")
        test_connectivity
        ;;
    "dev")
        show_namespace_status "webapp-dev" "Development"
        ;;
    "staging")
        show_namespace_status "webapp-staging" "Staging"
        ;;
    "prod")
        show_namespace_status "webapp-prod" "Production"
        ;;
    *)
        main
        ;;
esac
