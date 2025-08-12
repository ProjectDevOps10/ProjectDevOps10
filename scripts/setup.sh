#!/bin/bash

# iAgent DevOps Project Setup Script (Bash)
# Complete infrastructure management for final project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
CLUSTER_NAME=${CLUSTER_NAME:-"iagent-cluster"}
PROJECT_NAME="iagent"
STACK_NAME="IAgentInfrastructureStack"
MONITORING_STACK_NAME="IAgentMonitoringStack"

# Set environment variables for non-interactive mode
export NX_SKIP_NX_CACHE="true"
export NX_VERBOSE_LOGGING="false"
export NX_INTERACTIVE="false"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists node; then
        missing_tools+=("Node.js")
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm")
    fi
    
    if ! command_exists aws; then
        missing_tools+=("AWS CLI")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("Docker")
    fi
    
    if ! command_exists git; then
        missing_tools+=("Git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid"
        print_status "Please run 'aws configure' and try again."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS credentials configured for account: $account_id"
    echo "$account_id"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    if [ ! -d "node_modules" ]; then
        npm install
        print_success "Dependencies installed"
    else
        print_status "Dependencies already installed, skipping..."
    fi
    
    # Sync TypeScript project references
    print_status "Syncing TypeScript project references..."
    npx nx sync --yes
}

# Function to bootstrap CDK
bootstrap_cdk() {
    print_status "Bootstrapping AWS CDK..."
    
    local account_id=$(check_aws_credentials)
    
    if ! aws cloudformation describe-stacks --stack-name CDKToolkit >/dev/null 2>&1; then
        print_status "CDK not bootstrapped, bootstrapping now..."
        cdk bootstrap "aws://$account_id/$AWS_REGION"
        print_success "CDK bootstrapped successfully"
    else
        print_status "CDK already bootstrapped, skipping..."
    fi
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    
    # Build infrastructure
    npx nx build infrastructure --yes
    
    # Deploy infrastructure
    npx nx run infrastructure:deploy --yes
    
    print_success "Infrastructure deployed successfully"
}

# Function to deploy monitoring
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    # Build monitoring
    npx nx build monitoring --yes
    
    # Deploy monitoring
    npx nx run monitoring:deploy --yes
    
    print_success "Monitoring stack deployed successfully"
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl for EKS cluster..."
    
    if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"; then
        # Wait for cluster to be ready
        print_status "Waiting for EKS cluster to be ready..."
        aws eks wait cluster-active --region "$AWS_REGION" --name "$CLUSTER_NAME"
        print_success "kubectl configured for EKS cluster"
    else
        print_warning "Failed to configure kubectl. The cluster might not be ready yet."
        print_status "You may need to wait for the infrastructure deployment to complete."
    fi
}

# Function to deploy Kubernetes manifests
deploy_k8s_manifests() {
    print_status "Deploying Kubernetes manifests..."
    
    # Create namespace
    kubectl apply -f apps/infrastructure/src/k8s/namespace.yaml
    
    # Create secrets (you need to update the secrets file with actual values)
    if [ -f "apps/infrastructure/src/k8s/secrets.yaml" ]; then
        kubectl apply -f apps/infrastructure/src/k8s/secrets.yaml
    else
        print_warning "Secrets file not found. Please create and apply secrets manually."
    fi
    
    # Deploy backend
    kubectl apply -f apps/infrastructure/src/k8s/backend-deployment.yaml
    
    # Wait for deployment to be ready
    print_status "Waiting for backend deployment to be ready..."
    kubectl rollout status deployment/iagent-backend -n iagent --timeout=300s
    
    print_success "Kubernetes manifests deployed successfully"
}

# Function to build and push Docker images
build_and_push_images() {
    print_status "Building and pushing Docker images..."
    
    # Get ECR registry
    local account_id=$(check_aws_credentials)
    local ecr_registry="$account_id.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ecr_registry"
    
    # Build and push backend image
    print_status "Building backend image..."
    docker build -t "$ecr_registry/iagent-backend:latest" -f apps/backend/Dockerfile .
    docker push "$ecr_registry/iagent-backend:latest"
    
    # Build and push frontend image
    print_status "Building frontend image..."
    docker build -t "$ecr_registry/iagent-frontend:latest" -f apps/frontend/Dockerfile .
    docker push "$ecr_registry/iagent-frontend:latest"
    
    print_success "Docker images built and pushed successfully"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    npx nx run-many --target=test --all --yes
    
    print_success "Tests completed successfully"
}

# Function to build applications
build_applications() {
    print_status "Building applications..."
    
    npx nx run-many --target=build --projects=frontend,backend --yes
    
    print_success "Applications built successfully"
}

# Function to show deployment status
show_status() {
    print_status "Checking deployment status..."
    
    echo ""
    echo "=== Deployment Status ==="
    
    # Check EKS cluster
    if aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
        print_success "EKS Cluster: Running"
    else
        print_error "EKS Cluster: Not found"
    fi
    
    # Check ECR repositories
    if aws ecr describe-repositories --repository-names iagent-backend --region "$AWS_REGION" >/dev/null 2>&1; then
        print_success "ECR Backend Repository: Exists"
    else
        print_error "ECR Backend Repository: Not found"
    fi
    
    if aws ecr describe-repositories --repository-names iagent-frontend --region "$AWS_REGION" >/dev/null 2>&1; then
        print_success "ECR Frontend Repository: Exists"
    else
        print_error "ECR Frontend Repository: Not found"
    fi
    
    # Check CloudFormation stacks
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        print_success "Infrastructure Stack: Running"
    else
        print_error "Infrastructure Stack: Not found"
    fi
    
    if aws cloudformation describe-stacks --stack-name "$MONITORING_STACK_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        print_success "Monitoring Stack: Running"
    else
        print_error "Monitoring Stack: Not found"
    fi
    
    # Check Kubernetes deployments
    if kubectl get deployment iagent-backend -n iagent >/dev/null 2>&1; then
        local ready=$(kubectl get deployment iagent-backend -n iagent -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment iagent-backend -n iagent -o jsonpath='{.spec.replicas}')
        if [ "$ready" = "$desired" ]; then
            print_success "Backend Deployment: Ready ($ready/$desired)"
        else
            print_warning "Backend Deployment: Not ready ($ready/$desired)"
        fi
    else
        print_error "Backend Deployment: Not found"
    fi
    
    echo ""
    echo "=== Useful Commands ==="
    echo "View cluster info: aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME"
    echo "View pods: kubectl get pods -n iagent"
    echo "View logs: kubectl logs -f deployment/iagent-backend -n iagent"
    echo "Access dashboard: kubectl proxy"
    echo ""
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure..."
    
    # Destroy monitoring stack first
    print_status "Destroying monitoring stack..."
    npx nx run monitoring:destroy --yes || print_warning "Failed to destroy monitoring stack"
    
    # Destroy main infrastructure stack
    print_status "Destroying main infrastructure stack..."
    npx nx run infrastructure:destroy --yes || print_warning "Failed to destroy infrastructure stack"
    
    print_success "Infrastructure destruction completed"
}

# Function to clean up all resources
clean_all() {
    print_status "Cleaning up all resources..."
    
    local account_id=$(check_aws_credentials)
    
    # Delete ECR repositories
    print_status "Deleting ECR repositories..."
    aws ecr delete-repository --repository-name iagent-backend --force --region "$AWS_REGION" && print_success "Backend ECR repository deleted" || print_warning "Failed to delete backend ECR repository"
    aws ecr delete-repository --repository-name iagent-frontend --force --region "$AWS_REGION" && print_success "Frontend ECR repository deleted" || print_warning "Failed to delete frontend ECR repository"
    
    # Delete EKS cluster
    print_status "Deleting EKS cluster..."
    aws eks delete-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" && print_success "EKS cluster deletion initiated" || print_warning "Failed to delete EKS cluster"
    
    # Delete CloudFormation stacks
    print_status "Deleting CloudFormation stacks..."
    aws cloudformation delete-stack --stack-name "$MONITORING_STACK_NAME" --region "$AWS_REGION" && print_success "Monitoring stack deletion initiated" || print_warning "Failed to delete monitoring stack"
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION" && print_success "Infrastructure stack deletion initiated" || print_warning "Failed to delete infrastructure stack"
    
    print_success "Cleanup completed. Note: Some resources may take time to fully delete."
}

# Function to show help
show_help() {
    echo "iAgent DevOps Project Setup Script (Bash)"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start             Start complete infrastructure (infrastructure + monitoring + apps)"
    echo "  stop              Stop and destroy all infrastructure"
    echo "  status            Show current deployment status"
    echo "  deploy            Deploy applications only (infrastructure must be running)"
    echo "  clean             Force cleanup all AWS resources"
    echo "  help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION          AWS region (default: us-east-1)"
    echo "  CLUSTER_NAME        EKS cluster name (default: iagent-cluster)"
    echo ""
    echo "Examples:"
    echo "  $0 start    # Start complete infrastructure"
    echo "  $0 status   # Check current status"
    echo "  $0 stop     # Stop and destroy everything"
    echo ""
}

# Main deployment function
main() {
    case "${1:-}" in
        start)
            print_status "Starting complete iAgent infrastructure..."
            check_prerequisites
            install_dependencies
            bootstrap_cdk
            deploy_infrastructure
            deploy_monitoring
            configure_kubectl
            deploy_k8s_manifests
            build_and_push_images
            run_tests
            build_applications
            show_status
            print_success "Complete infrastructure started successfully!"
            echo ""
            echo "🎉 Your iAgent DevOps project is now running!"
            echo "📊 Monitor your application at the URLs provided above"
            echo "🔄 Push to GitHub to trigger automatic deployments"
            echo "🛑 Run '$0 stop' to stop everything"
            ;;
        stop)
            print_status "Stopping iAgent infrastructure..."
            destroy_infrastructure
            print_success "Infrastructure stopped successfully!"
            ;;
        status)
            show_status
            ;;
        deploy)
            print_status "Deploying applications only..."
            check_prerequisites
            configure_kubectl
            deploy_k8s_manifests
            build_and_push_images
            run_tests
            build_applications
            show_status
            print_success "Applications deployed successfully!"
            ;;
        clean)
            print_warning "This will permanently delete ALL AWS resources!"
            read -p "Are you sure you want to continue? (yes/no): " confirmation
            if [ "$confirmation" = "yes" ]; then
                clean_all
            else
                print_status "Cleanup cancelled"
            fi
            ;;
        help|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@" 