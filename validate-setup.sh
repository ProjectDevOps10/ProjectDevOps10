#!/bin/bash

# iAgent DevOps Setup Validation Script
# Validates that all components are properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Validation results
VALIDATION_PASSED=true
VALIDATION_WARNINGS=0

# Track validation results
mark_failed() {
    VALIDATION_PASSED=false
}

mark_warning() {
    VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
}

print_header "iAgent DevOps Setup Validation"

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_status "Node.js: $NODE_VERSION"
        if [[ $(node --version | cut -d'v' -f2 | cut -d'.' -f1) -lt 18 ]]; then
            print_error "Node.js version 18+ required"
            mark_failed
        fi
    else
        print_error "Node.js not found"
        mark_failed
    fi
    
    # Check AWS CLI
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
        print_status "AWS CLI: $AWS_VERSION"
        
        # Check AWS credentials
        if aws sts get-caller-identity &> /dev/null; then
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            AWS_REGION=$(aws configure get region)
            print_status "AWS Account: $ACCOUNT_ID"
            print_status "AWS Region: $AWS_REGION"
        else
            print_error "AWS credentials not configured or invalid"
            mark_failed
        fi
    else
        print_error "AWS CLI not found"
        mark_failed
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_status "Docker: $DOCKER_VERSION"
        
        # Check if Docker is running
        if docker info &> /dev/null; then
            print_status "Docker daemon is running"
        else
            print_error "Docker daemon is not running"
            mark_failed
        fi
    else
        print_error "Docker not found"
        mark_failed
    fi
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || echo "kubectl installed")
        print_status "kubectl: $KUBECTL_VERSION"
    else
        print_warning "kubectl not found (will be installed during setup)"
        mark_warning
    fi
    
    # Check CDK
    if command -v cdk &> /dev/null; then
        CDK_VERSION=$(cdk --version)
        print_status "AWS CDK: $CDK_VERSION"
    else
        print_warning "AWS CDK not found (will be installed during setup)"
        mark_warning
    fi
}

# Check scripts
check_scripts() {
    print_header "Checking Setup Scripts"
    
    REQUIRED_SCRIPTS=(
        "quick-devops-setup.sh"
        "setup-aws-environment.sh"
        "deploy-infrastructure.sh"
        "teardown-infrastructure.sh"
        "setup-github-actions.sh"
    )
    
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            print_status "Script: $script"
        else
            print_error "Script missing or not executable: $script"
            mark_failed
        fi
    done
}

# Check project structure
check_project_structure() {
    print_header "Checking Project Structure"
    
    REQUIRED_DIRS=(
        "apps/frontend"
        "apps/backend"
        "apps/infrastructure"
        "libs"
    )
    
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            print_status "Directory: $dir"
        else
            print_error "Directory missing: $dir"
            mark_failed
        fi
    done
    
    # Check key files
    REQUIRED_FILES=(
        "package.json"
        "nx.json"
        "apps/frontend/package.json"
        "apps/backend/package.json"
        "apps/infrastructure/package.json"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ -f "$file" ]; then
            print_status "File: $file"
        else
            print_error "File missing: $file"
            mark_failed
        fi
    done
}

# Check infrastructure configuration
check_infrastructure_config() {
    print_header "Checking Infrastructure Configuration"
    
    # Check cost-optimized stack
    if [ -f "apps/infrastructure/src/lib/cost-optimized-infrastructure-stack.ts" ]; then
        print_status "Cost-optimized infrastructure stack found"
    else
        print_error "Cost-optimized infrastructure stack missing"
        mark_failed
    fi
    
    # Check Kubernetes manifests
    if [ -d "apps/infrastructure/src/k8s" ]; then
        print_status "Kubernetes manifests directory found"
        K8S_FILES=$(ls apps/infrastructure/src/k8s/*.yaml 2>/dev/null | wc -l)
        if [ $K8S_FILES -gt 0 ]; then
            print_status "Kubernetes manifests: $K8S_FILES files"
        else
            print_warning "No Kubernetes manifest files found"
            mark_warning
        fi
    else
        print_warning "Kubernetes manifests directory missing"
        mark_warning
    fi
}

# Check GitHub configuration
check_github_config() {
    print_header "Checking GitHub Configuration"
    
    # Check if we're in a git repository
    if git rev-parse --git-dir &> /dev/null; then
        print_status "Git repository initialized"
        
        # Check for remote
        if git remote -v &> /dev/null; then
            REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "No origin remote")
            print_status "Git remote: $REMOTE_URL"
            
            if [[ $REMOTE_URL =~ github\.com ]]; then
                print_status "GitHub repository detected"
            else
                print_warning "Non-GitHub remote detected"
                mark_warning
            fi
        else
            print_warning "No git remotes configured"
            mark_warning
        fi
    else
        print_error "Not a git repository"
        mark_failed
    fi
    
    # Check GitHub Actions workflow
    if [ -f ".github/workflows/iagent-devops-pipeline.yml" ]; then
        print_status "GitHub Actions workflow found"
    else
        print_warning "GitHub Actions workflow not found (run setup-github-actions.sh)"
        mark_warning
    fi
}

# Check npm dependencies
check_dependencies() {
    print_header "Checking Dependencies"
    
    if [ -f "package-lock.json" ]; then
        print_status "package-lock.json found"
    else
        print_warning "package-lock.json not found (run npm install)"
        mark_warning
    fi
    
    if [ -d "node_modules" ]; then
        print_status "node_modules directory found"
    else
        print_warning "node_modules not found (run npm install)"
        mark_warning
    fi
}

# Show validation summary
show_validation_summary() {
    print_header "Validation Summary"
    
    if [ "$VALIDATION_PASSED" = true ]; then
        if [ $VALIDATION_WARNINGS -eq 0 ]; then
            print_status "🎉 All validations passed! Setup is ready."
            echo ""
            print_status "You can now run:"
            echo "  ./quick-devops-setup.sh"
            echo ""
        else
            print_warning "⚠️ Validation passed with $VALIDATION_WARNINGS warnings"
            echo ""
            print_warning "Setup will work but some components may need configuration"
            echo "You can still run: ./quick-devops-setup.sh"
            echo ""
        fi
        
        print_header "Estimated Costs"
        echo "💰 Monthly cost estimate with optimizations:"
        echo "  • EKS Control Plane: ~$73/month"
        echo "  • EC2 Spot Instances: ~$10-20/month"
        echo "  • NAT Gateway: ~$45/month"
        echo "  • ECR Storage: ~$2/month"
        echo "  • CloudWatch: ~$5/month"
        echo "  • Total: ~$135-145/month"
        echo ""
        echo "💡 Cost savings:"
        echo "  • Spot instances: ~70% savings on compute"
        echo "  • Single NAT gateway: ~50% savings on networking"
        echo "  • Auto-scaling to zero: ~90% savings when idle"
        echo "  • Lifecycle policies: Reduced storage costs"
        echo ""
        print_status "🗑️ Remember: Run ./teardown-infrastructure.sh to stop all charges!"
        
    else
        print_error "❌ Validation failed! Please fix the errors above before proceeding."
        echo ""
        print_error "Common fixes:"
        echo "  • Install missing prerequisites"
        echo "  • Configure AWS credentials: aws configure"
        echo "  • Start Docker desktop"
        echo "  • Run npm install"
        echo ""
        exit 1
    fi
}

# Main execution
main() {
    check_prerequisites
    echo ""
    check_scripts
    echo ""
    check_project_structure
    echo ""
    check_infrastructure_config
    echo ""
    check_github_config
    echo ""
    check_dependencies
    echo ""
    show_validation_summary
}

# Run main function
main "$@"