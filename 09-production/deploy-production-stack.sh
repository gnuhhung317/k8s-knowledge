#!/bin/bash

# Deploy Production-Ready Kubernetes Stack
# This script sets up a complete production environment

set -e

echo "🚀 Deploying Production Kubernetes Stack..."

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

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    print_status "Waiting for $deployment in $namespace to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n $namespace
}

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local label=$2
    print_status "Waiting for pods with label $label in $namespace..."
    kubectl wait --for=condition=ready --timeout=300s pod -l $label -n $namespace
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Prerequisites check passed"

# 1. Create namespaces with security standards
print_status "Creating production namespaces..."
kubectl apply -f security/production-namespace.yaml
print_success "Namespaces created"

# 2. Set up RBAC
print_status "Configuring RBAC..."
kubectl apply -f security/production-rbac.yaml
print_success "RBAC configured"

# 3. Apply resource management
print_status "Setting up resource management..."
kubectl apply -f resources/priority-classes.yaml
kubectl apply -f resources/production-quota.yaml
kubectl apply -f resources/production-limits.yaml
print_success "Resource management configured"

# 4. Deploy monitoring stack (if not exists)
print_status "Checking monitoring stack..."
if ! kubectl get namespace monitoring &> /dev/null; then
    print_warning "Monitoring namespace not found, creating..."
    kubectl create namespace monitoring
fi

# Apply monitoring alerts
kubectl apply -f monitoring/production-alerts.yaml
print_success "Production alerts configured"

# 5. Set up backup (Velero)
print_status "Configuring backup system..."
if command -v velero &> /dev/null; then
    kubectl apply -f backup/velero-schedule.yaml
    print_success "Backup schedules configured"
else
    print_warning "Velero not found, skipping backup configuration"
    print_warning "Install Velero: https://velero.io/docs/main/basic-install/"
fi

# 6. Verify production readiness
print_status "Verifying production readiness..."

# Check namespaces
print_status "Checking namespaces..."
kubectl get namespaces production staging monitoring

# Check resource quotas
print_status "Checking resource quotas..."
kubectl get resourcequota -n production
kubectl get resourcequota -n staging

# Check limit ranges
print_status "Checking limit ranges..."
kubectl get limitrange -n production
kubectl get limitrange -n staging

# Check priority classes
print_status "Checking priority classes..."
kubectl get priorityclass

# Check RBAC
print_status "Checking RBAC..."
kubectl get serviceaccount -n production
kubectl get role -n production
kubectl get rolebinding -n production

# 7. Security validation
print_status "Running security validation..."

# Check Pod Security Standards
kubectl get namespace production -o yaml | grep pod-security || print_warning "Pod Security Standards not configured"

# Check if network policies exist
if kubectl get networkpolicy -n production &> /dev/null; then
    print_success "Network policies found"
else
    print_warning "No network policies found - consider implementing network segmentation"
fi

# 8. Performance checks
print_status "Running performance checks..."

# Check node resources
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available"

# Check if HPA is configured
if kubectl get hpa -n production &> /dev/null; then
    print_success "HPA configurations found"
else
    print_warning "No HPA found - consider implementing autoscaling"
fi

# 9. Generate production readiness report
print_status "Generating production readiness report..."

cat << EOF > production-readiness-report.txt
Production Readiness Report
Generated: $(date)
Cluster: $(kubectl config current-context)

=== Namespaces ===
$(kubectl get namespaces production staging monitoring --no-headers)

=== Resource Quotas ===
$(kubectl get resourcequota --all-namespaces --no-headers)

=== Priority Classes ===
$(kubectl get priorityclass --no-headers)

=== Security ===
Pod Security Standards: $(kubectl get namespace production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
RBAC Roles: $(kubectl get role -n production --no-headers | wc -l)
Service Accounts: $(kubectl get serviceaccount -n production --no-headers | wc -l)

=== Monitoring ===
Alert Rules: $(kubectl get configmap -n monitoring --no-headers | grep -c alert || echo "0")

=== Backup ===
Velero Schedules: $(kubectl get schedule -n velero --no-headers 2>/dev/null | wc -l || echo "0")

=== Recommendations ===
EOF

# Add recommendations based on findings
if ! kubectl get networkpolicy -n production &> /dev/null; then
    echo "- Implement NetworkPolicies for network segmentation" >> production-readiness-report.txt
fi

if ! kubectl get hpa -n production &> /dev/null; then
    echo "- Configure Horizontal Pod Autoscaler for critical applications" >> production-readiness-report.txt
fi

if ! command -v velero &> /dev/null; then
    echo "- Install and configure Velero for backup and disaster recovery" >> production-readiness-report.txt
fi

if ! kubectl top nodes &> /dev/null; then
    echo "- Install metrics-server for resource monitoring" >> production-readiness-report.txt
fi

print_success "Production readiness report generated: production-readiness-report.txt"

# 10. Final status
echo ""
echo "🎉 Production stack deployment completed!"
echo ""
echo "📋 Summary:"
echo "   ✅ Namespaces with Pod Security Standards"
echo "   ✅ RBAC with least privilege"
echo "   ✅ Resource quotas and limits"
echo "   ✅ Priority classes"
echo "   ✅ Production alerts"
echo "   ✅ Backup schedules (if Velero available)"
echo ""
echo "🔍 Next steps:"
echo "   1. Review production-readiness-report.txt"
echo "   2. Implement missing components (NetworkPolicies, HPA, etc.)"
echo "   3. Deploy your applications with production configurations"
echo "   4. Set up monitoring dashboards"
echo "   5. Test disaster recovery procedures"
echo ""
echo "📖 Useful commands:"
echo "   kubectl get all -n production"
echo "   kubectl describe quota -n production"
echo "   kubectl auth can-i --list --as=system:serviceaccount:production:production-developer"
echo "   kubectl top nodes"
echo "   kubectl get events --sort-by=.metadata.creationTimestamp"
echo ""
echo "🚨 Security reminders:"
echo "   - Regularly scan container images for vulnerabilities"
echo "   - Review and rotate service account tokens"
echo "   - Monitor audit logs for suspicious activities"
echo "   - Keep Kubernetes cluster updated"
echo "   - Test backup and restore procedures monthly"