#!/bin/bash

# Kubernetes Troubleshooting Toolkit
# A comprehensive script for debugging Kubernetes issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

print_section() {
    echo -e "\n${BLUE}[SECTION]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "kubectl is available and connected to cluster"
}

# Function to get cluster overview
cluster_overview() {
    print_header "CLUSTER OVERVIEW"
    
    print_section "Cluster Information"
    kubectl cluster-info
    
    print_section "Node Status"
    kubectl get nodes -o wide
    
    print_section "Node Resources"
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"
    
    print_section "Cluster Components"
    kubectl get pods -n kube-system
    
    print_section "Recent Events"
    kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces | tail -10
}

# Function to check pod issues
check_pods() {
    print_header "POD ANALYSIS"
    
    print_section "All Pods Status"
    kubectl get pods --all-namespaces -o wide
    
    print_section "Problematic Pods"
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
    
    print_section "Pod Resource Usage"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null || print_warning "Metrics server not available"
    
    print_section "Recent Pod Events"
    kubectl get events --field-selector involvedObject.kind=Pod --sort-by=.metadata.creationTimestamp | tail -10
}

# Function to check services and networking
check_networking() {
    print_header "NETWORK ANALYSIS"
    
    print_section "Services"
    kubectl get svc --all-namespaces
    
    print_section "Endpoints"
    kubectl get endpoints --all-namespaces
    
    print_section "Ingress"
    kubectl get ingress --all-namespaces
    
    print_section "Network Policies"
    kubectl get networkpolicy --all-namespaces
    
    print_section "CoreDNS Status"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
}

# Function to check storage
check_storage() {
    print_header "STORAGE ANALYSIS"
    
    print_section "Persistent Volumes"
    kubectl get pv
    
    print_section "Persistent Volume Claims"
    kubectl get pvc --all-namespaces
    
    print_section "Storage Classes"
    kubectl get storageclass
    
    print_section "Volume Attachments"
    kubectl get volumeattachment 2>/dev/null || print_info "No volume attachments found"
}

# Function to check resources and quotas
check_resources() {
    print_header "RESOURCE ANALYSIS"
    
    print_section "Resource Quotas"
    kubectl get resourcequota --all-namespaces
    
    print_section "Limit Ranges"
    kubectl get limitrange --all-namespaces
    
    print_section "Priority Classes"
    kubectl get priorityclass
    
    print_section "Horizontal Pod Autoscalers"
    kubectl get hpa --all-namespaces
    
    print_section "Vertical Pod Autoscalers"
    kubectl get vpa --all-namespaces 2>/dev/null || print_info "VPA not installed"
}

# Function to check security
check_security() {
    print_header "SECURITY ANALYSIS"
    
    print_section "Service Accounts"
    kubectl get serviceaccount --all-namespaces
    
    print_section "Roles and ClusterRoles"
    kubectl get role,clusterrole --all-namespaces | head -20
    
    print_section "Role Bindings"
    kubectl get rolebinding,clusterrolebinding --all-namespaces | head -20
    
    print_section "Pod Security Policies"
    kubectl get psp 2>/dev/null || print_info "PSP not available (deprecated in K8s 1.25+)"
    
    print_section "Security Context Constraints (OpenShift)"
    kubectl get scc 2>/dev/null || print_info "SCC not available (OpenShift only)"
}

# Function to debug specific pod
debug_pod() {
    local pod_name=$1
    local namespace=${2:-default}
    
    if [ -z "$pod_name" ]; then
        print_error "Pod name is required"
        return 1
    fi
    
    print_header "DEBUGGING POD: $pod_name (namespace: $namespace)"
    
    print_section "Pod Details"
    kubectl describe pod $pod_name -n $namespace
    
    print_section "Pod Logs (Current)"
    kubectl logs $pod_name -n $namespace --tail=50 || print_warning "Cannot get current logs"
    
    print_section "Pod Logs (Previous)"
    kubectl logs $pod_name -n $namespace --previous --tail=50 2>/dev/null || print_info "No previous logs available"
    
    print_section "Pod Events"
    kubectl get events --field-selector involvedObject.name=$pod_name -n $namespace
    
    print_section "Pod Resource Usage"
    kubectl top pod $pod_name -n $namespace 2>/dev/null || print_warning "Metrics not available"
}

# Function to debug service
debug_service() {
    local service_name=$1
    local namespace=${2:-default}
    
    if [ -z "$service_name" ]; then
        print_error "Service name is required"
        return 1
    fi
    
    print_header "DEBUGGING SERVICE: $service_name (namespace: $namespace)"
    
    print_section "Service Details"
    kubectl describe service $service_name -n $namespace
    
    print_section "Service Endpoints"
    kubectl get endpoints $service_name -n $namespace
    
    print_section "Pods with Matching Labels"
    local selector=$(kubectl get service $service_name -n $namespace -o jsonpath='{.spec.selector}' 2>/dev/null)
    if [ ! -z "$selector" ]; then
        print_info "Service selector: $selector"
        kubectl get pods -n $namespace --show-labels | grep -E "$(echo $selector | sed 's/[{}"]//g' | sed 's/:/=/g')" || print_warning "No matching pods found"
    fi
}

# Function to run network connectivity test
test_connectivity() {
    local target=$1
    local port=${2:-80}
    
    if [ -z "$target" ]; then
        print_error "Target is required"
        return 1
    fi
    
    print_header "NETWORK CONNECTIVITY TEST"
    
    print_section "Creating test pod"
    kubectl run connectivity-test --image=busybox --rm -it --restart=Never -- /bin/sh -c "
        echo 'Testing connectivity to $target:$port'
        nc -zv $target $port
        echo 'DNS resolution test:'
        nslookup $target
        echo 'Ping test:'
        ping -c 3 $target
    " || print_error "Connectivity test failed"
}

# Function to generate troubleshooting report
generate_report() {
    local report_file="troubleshooting-report-$(date +%Y%m%d-%H%M%S).txt"
    
    print_header "GENERATING TROUBLESHOOTING REPORT"
    
    {
        echo "Kubernetes Troubleshooting Report"
        echo "Generated: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo "========================================="
        echo ""
        
        echo "=== CLUSTER OVERVIEW ==="
        kubectl cluster-info
        echo ""
        
        echo "=== NODE STATUS ==="
        kubectl get nodes -o wide
        echo ""
        
        echo "=== PROBLEMATIC PODS ==="
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
        echo ""
        
        echo "=== RECENT EVENTS ==="
        kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces | tail -20
        echo ""
        
        echo "=== RESOURCE USAGE ==="
        kubectl top nodes 2>/dev/null || echo "Metrics server not available"
        echo ""
        
        echo "=== STORAGE STATUS ==="
        kubectl get pv,pvc --all-namespaces
        echo ""
        
        echo "=== NETWORK STATUS ==="
        kubectl get svc,endpoints --all-namespaces
        echo ""
        
    } > $report_file
    
    print_success "Report generated: $report_file"
}

# Function to show help
show_help() {
    echo "Kubernetes Troubleshooting Toolkit"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  overview              Show cluster overview"
    echo "  pods                  Analyze pod issues"
    echo "  networking            Check networking components"
    echo "  storage               Check storage components"
    echo "  resources             Check resource usage and quotas"
    echo "  security              Check security configurations"
    echo "  debug-pod <name> [ns] Debug specific pod"
    echo "  debug-svc <name> [ns] Debug specific service"
    echo "  test-conn <target>    Test network connectivity"
    echo "  report                Generate troubleshooting report"
    echo "  all                   Run all checks"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 overview"
    echo "  $0 debug-pod my-pod default"
    echo "  $0 debug-svc my-service"
    echo "  $0 test-conn google.com"
    echo "  $0 all"
}

# Main function
main() {
    local command=${1:-help}
    
    case $command in
        overview)
            check_kubectl
            cluster_overview
            ;;
        pods)
            check_kubectl
            check_pods
            ;;
        networking)
            check_kubectl
            check_networking
            ;;
        storage)
            check_kubectl
            check_storage
            ;;
        resources)
            check_kubectl
            check_resources
            ;;
        security)
            check_kubectl
            check_security
            ;;
        debug-pod)
            check_kubectl
            debug_pod $2 $3
            ;;
        debug-svc)
            check_kubectl
            debug_service $2 $3
            ;;
        test-conn)
            check_kubectl
            test_connectivity $2 $3
            ;;
        report)
            check_kubectl
            generate_report
            ;;
        all)
            check_kubectl
            cluster_overview
            check_pods
            check_networking
            check_storage
            check_resources
            check_security
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"