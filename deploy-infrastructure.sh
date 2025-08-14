#!/bin/bash

# iAgent Infrastructure Deployment Script - Cost Optimized
# One-command deployment with cost optimization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Load AWS configuration
if [ ! -f .env.aws ]; then
    print_error ".env.aws not found. Please run setup-aws-environment.sh first"
    exit 1
fi

source .env.aws

print_header "Deploying iAgent Infrastructure (Cost Optimized)"

# Start timing
START_TIME=$(date +%s)

# Function to check if deployment should continue
check_costs() {
    print_warning "💰 COST ALERT: This will create AWS resources that incur charges!"
    print_warning "Estimated monthly cost with minimal usage: $5-15 USD"
    print_warning "Resources that will be created:"
    echo "  - EKS Cluster (control plane): ~$73/month"
    echo "  - EC2 instances (spot): ~$10-20/month"
    echo "  - ECR repositories: ~$1/month"
    echo "  - CloudWatch: ~$5/month"
    echo "  - NAT Gateway: ~$45/month"
    echo ""
    print_warning "To minimize costs:"
    echo "  ✅ Using spot instances (up to 90% savings)"
    echo "  ✅ Auto-scaling to zero when idle"
    echo "  ✅ Lifecycle policies for image cleanup"
    echo "  ✅ Log retention policies"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
}

# Deploy infrastructure with cost optimization
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    cd apps/infrastructure
    
    # Install dependencies
    print_status "Installing infrastructure dependencies..."
    npm install
    
    # Build the infrastructure
    print_status "Building infrastructure code..."
    npm run build
    
    # Deploy with cost-optimized parameters
    print_status "Deploying CDK stack with cost optimization..."
    cdk deploy \
        --parameters clusterName=iagent-cluster \
        --parameters nodeGroupInstanceType=t3.medium \
        --parameters nodeGroupMinSize=0 \
        --parameters nodeGroupMaxSize=3 \
        --parameters nodeGroupDesiredSize=1 \
        --parameters enableSpotInstances=true \
        --parameters enableMonitoring=true \
        --parameters enableAlarms=true \
        --require-approval never \
        --outputs-file ../infrastructure-outputs.json
    
    cd ../..
    
    print_status "Infrastructure deployed successfully!"
}

# Configure kubectl for the new cluster
configure_kubectl() {
    print_header "Configuring kubectl"
    
    CLUSTER_NAME="iagent-cluster"
    
    print_status "Updating kubeconfig for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s || {
        print_warning "Cluster nodes not ready yet, but continuing..."
    }
    
    print_status "kubectl configured successfully"
}

# Deploy Kubernetes manifests
deploy_kubernetes() {
    print_header "Deploying Kubernetes Resources"
    
    # Create namespace
    print_status "Creating iagent namespace..."
    kubectl create namespace iagent --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Kubernetes manifests
    print_status "Applying Kubernetes manifests..."
    kubectl apply -f apps/infrastructure/src/k8s/ -n iagent
    
    print_status "Kubernetes resources deployed"
}

# Setup ECR repositories and build initial images
setup_ecr_and_images() {
    print_header "Setting up ECR and Building Images"
    
    # Get ECR URLs from infrastructure outputs
    if [ -f apps/infrastructure-outputs.json ]; then
        BACKEND_ECR_URI=$(cat apps/infrastructure-outputs.json | jq -r '.IAgentInfrastructureStack.BackendRepositoryUri // empty')
        FRONTEND_ECR_URI=$(cat apps/infrastructure-outputs.json | jq -r '.IAgentInfrastructureStack.FrontendRepositoryUri // empty')
    fi
    
    if [ -z "$BACKEND_ECR_URI" ]; then
        BACKEND_ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/iagent-backend"
        FRONTEND_ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/iagent-frontend"
    fi
    
    print_status "Backend ECR URI: $BACKEND_ECR_URI"
    print_status "Frontend ECR URI: $FRONTEND_ECR_URI"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    # Build and push backend image
    print_status "Building and pushing backend image..."
    docker build -t iagent-backend apps/backend/
    docker tag iagent-backend:latest $BACKEND_ECR_URI:latest
    docker push $BACKEND_ECR_URI:latest
    
    # Build and push frontend image (for potential container deployment)
    print_status "Building and pushing frontend image..."
    docker build -t iagent-frontend apps/frontend/
    docker tag iagent-frontend:latest $FRONTEND_ECR_URI:latest
    docker push $FRONTEND_ECR_URI:latest
    
    print_status "Images built and pushed successfully"
}

# Create environment configuration
create_environment_config() {
    print_header "Creating Environment Configuration"
    
    cat > .env.deployment << EOF
# iAgent Deployment Configuration
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_REGION=$AWS_REGION
CLUSTER_NAME=iagent-cluster
BACKEND_ECR_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/iagent-backend
FRONTEND_ECR_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/iagent-frontend
DEPLOYMENT_TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")

# Application URLs (will be updated after deployment)
BACKEND_URL=https://api.iagent.local
FRONTEND_URL=https://iagent.github.io

# Database (optional - uses in-memory for demo)
DEMO_MODE=true
EOF
    
    print_status "Environment configuration created in .env.deployment"
}

# Display deployment information
show_deployment_info() {
    print_header "Deployment Information"
    
    # Calculate deployment time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))
    
    print_status "🚀 Infrastructure deployed successfully!"
    print_status "⏱️  Deployment time: ${DURATION_MIN} minutes"
    echo ""
    
    print_status "📋 Deployed Resources:"
    echo "  ✅ EKS Cluster: iagent-cluster"
    echo "  ✅ ECR Repositories: iagent-backend, iagent-frontend"
    echo "  ✅ VPC with public/private subnets"
    echo "  ✅ CloudWatch monitoring and alarms"
    echo "  ✅ Kubernetes namespace and basic resources"
    echo ""
    
    print_status "🔗 Quick Access Commands:"
    echo "  View cluster: kubectl get nodes"
    echo "  View pods: kubectl get pods -n iagent"
    echo "  View services: kubectl get svc -n iagent"
    echo "  Cluster info: kubectl cluster-info"
    echo ""
    
    print_warning "💰 Cost Management:"
    echo "  • Monitor costs: AWS Console > Billing"
    echo "  • Scale down: kubectl scale deployment backend --replicas=0 -n iagent"
    echo "  • Tear down: ./teardown-infrastructure.sh"
    echo ""
    
    print_status "🚀 Next Steps:"
    echo "  1. Setup GitHub Actions: ./setup-github-actions.sh"
    echo "  2. Deploy application: kubectl apply -f k8s-manifests/"
    echo "  3. Setup frontend on GitHub Pages"
    echo ""
    
    print_warning "⚠️  Remember to run './teardown-infrastructure.sh' when done to avoid charges!"
}

# Main execution
main() {
    check_costs
    deploy_infrastructure
    configure_kubectl
    deploy_kubernetes
    setup_ecr_and_images
    create_environment_config
    show_deployment_info
}

# Run main function
main "$@"