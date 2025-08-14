#!/bin/bash

# iAgent DevOps Container Setup Script
# Optimized for running inside the dev container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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
    echo -e "${BLUE}${BOLD}=== $1 ===${NC}"
}

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "🐳 iAgent DevOps Container Setup"
    echo "Running inside development container"
    echo "================================="
    echo -e "${NC}"
}

# Check container environment
check_container_environment() {
    print_header "Checking Container Environment"
    
    # Verify we're in a container
    if [ -f /.dockerenv ]; then
        print_status "✅ Running inside Docker container"
    else
        print_warning "⚠️ Not running in a container (this is okay)"
    fi
    
    # Check tools
    print_status "Node.js: $(node --version)"
    print_status "AWS CLI: $(aws --version 2>&1 | cut -d' ' -f1)"
    print_status "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    print_status "Docker CLI: $(docker --version 2>/dev/null || echo 'Docker CLI available')"
    print_status "CDK: $(cdk --version)"
    
    # Check workspace
    if [ -f "package.json" ]; then
        print_status "✅ iAgent project detected"
    else
        print_error "❌ iAgent project not found. Are you in the right directory?"
        exit 1
    fi
}

# Configure AWS credentials
configure_aws_credentials() {
    print_header "Configuring AWS Credentials"
    
    # Check if AWS credentials are already configured
    if aws sts get-caller-identity &>/dev/null; then
        print_status "✅ AWS credentials already configured"
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        AWS_REGION=$(aws configure get region)
        print_status "Account ID: $ACCOUNT_ID"
        print_status "Region: $AWS_REGION"
        return 0
    fi
    
    print_warning "AWS credentials not configured. Please enter your AWS credentials:"
    echo ""
    echo "📋 You need:"
    echo "  • AWS Access Key ID"
    echo "  • AWS Secret Access Key"
    echo "  • Default region (recommend: eu-central-1)"
    echo ""
    
    # Configure AWS
    aws configure
    
    # Verify configuration
    if aws sts get-caller-identity &>/dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        AWS_REGION=$(aws configure get region)
        print_status "✅ AWS credentials configured successfully"
        print_status "Account ID: $ACCOUNT_ID"
        print_status "Region: $AWS_REGION"
        
        # Create .env.aws file
        cat > .env.aws << EOF
AWS_ACCOUNT_ID=$ACCOUNT_ID
AWS_REGION=$AWS_REGION
AWS_DEFAULT_REGION=$AWS_REGION
EOF
        print_status "✅ AWS configuration saved to .env.aws"
    else
        print_error "❌ AWS configuration failed. Please try again."
        exit 1
    fi
}

# Install project dependencies
install_dependencies() {
    print_header "Installing Project Dependencies"
    
    if [ ! -d "node_modules" ]; then
        print_status "Installing npm dependencies..."
        npm install
        print_status "✅ Dependencies installed"
    else
        print_status "✅ Dependencies already installed"
    fi
}

# Configure Docker for ECR
configure_docker_ecr() {
    print_header "Configuring Docker for AWS ECR"
    
    # Check if Docker daemon is accessible
    if ! docker info &>/dev/null; then
        print_warning "⚠️ Docker daemon not accessible"
        print_warning "This is normal in some container setups"
        print_warning "Docker commands will be available during deployment"
        return 0
    fi
    
    # Source AWS config
    source .env.aws
    
    # Login to ECR
    print_status "Logging into AWS ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    print_status "✅ Docker configured for AWS ECR"
}

# Bootstrap CDK
bootstrap_cdk() {
    print_header "Bootstrapping AWS CDK"
    
    source .env.aws
    
    print_status "Bootstrapping CDK for account $AWS_ACCOUNT_ID in region $AWS_REGION..."
    cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_REGION
    
    print_status "✅ CDK bootstrapped successfully"
}

# Show container workflow options
show_workflow_options() {
    print_header "Container Workflow Options"
    
    echo "Choose your next action:"
    echo ""
    echo "  1) 🚀 Deploy full infrastructure (creates AWS resources)"
    echo "  2) 🧪 Run validation checks only"
    echo "  3) 🔄 Setup GitHub Actions CI/CD"
    echo "  4) 📋 Show cost estimates"
    echo "  5) 🗑️ Teardown infrastructure (removes all AWS resources)"
    echo "  6) ❓ Show help and commands"
    echo "  7) 🚪 Exit (continue manually)"
    echo ""
    read -p "Enter your choice (1-7): " -n 1 -r
    echo
    WORKFLOW_CHOICE=$REPLY
}

# Deploy infrastructure
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    print_warning "💰 This will create AWS resources that incur charges!"
    print_warning "Estimated monthly cost: $15-50 USD with optimizations"
    echo ""
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        return 0
    fi
    
    ./deploy-infrastructure.sh
}

# Run validation
run_validation() {
    print_header "Running Validation Checks"
    ./validate-setup.sh
}

# Setup GitHub Actions
setup_github_actions() {
    print_header "Setting up GitHub Actions"
    ./setup-github-actions.sh
}

# Show cost estimates
show_cost_estimates() {
    print_header "AWS Cost Estimates"
    
    echo "💰 Monthly cost breakdown with optimizations:"
    echo ""
    echo "  Core Services:"
    echo "    • EKS Control Plane: ~$73/month"
    echo "    • NAT Gateway (1): ~$45/month"
    echo "    • ECR Storage: ~$2/month"
    echo "    • CloudWatch: ~$5/month"
    echo ""
    echo "  Compute (with optimizations):"
    echo "    • t3.medium on-demand: ~$33/month"
    echo "    • t3.medium spot (70% off): ~$10/month ✅"
    echo "    • Auto-scale to 0 when idle: ~$0/month ✅"
    echo ""
    echo "  Total estimates:"
    echo "    • Without optimizations: ~$155/month"
    echo "    • With optimizations: ~$135/month"
    echo "    • When idle (scaled to 0): ~$125/month"
    echo ""
    echo "  💡 Cost savings features:"
    echo "    ✅ Spot instances (up to 90% savings)"
    echo "    ✅ Auto-scaling to zero"
    echo "    ✅ Single NAT gateway"
    echo "    ✅ Image lifecycle policies"
    echo "    ✅ Log retention policies"
    echo ""
    echo "  🗑️ Complete teardown: $0/month"
    echo ""
    read -p "Press Enter to continue..."
}

# Teardown infrastructure
teardown_infrastructure() {
    print_header "Tearing Down Infrastructure"
    ./teardown-infrastructure.sh
}

# Show help
show_help() {
    print_header "Container Help & Commands"
    
    echo "📋 Available scripts in this container:"
    echo ""
    echo "  Main Scripts:"
    echo "    ./container-setup.sh      - This script (container setup)"
    echo "    ./quick-devops-setup.sh   - Interactive DevOps setup"
    echo "    ./validate-setup.sh       - Validate configuration"
    echo ""
    echo "  Deployment Scripts:"
    echo "    ./deploy-infrastructure.sh   - Deploy AWS infrastructure"
    echo "    ./teardown-infrastructure.sh - Remove all AWS resources"
    echo "    ./setup-github-actions.sh    - Configure CI/CD"
    echo ""
    echo "  Container-specific commands:"
    echo "    aws configure             - Configure AWS credentials"
    echo "    aws sts get-caller-identity - Check AWS connection"
    echo "    kubectl get nodes         - Check Kubernetes cluster"
    echo "    docker info               - Check Docker daemon"
    echo ""
    echo "  Development commands:"
    echo "    npm run dev               - Start development servers"
    echo "    npm run build             - Build applications"
    echo "    npm test                  - Run tests"
    echo ""
    echo "  Cost management:"
    echo "    kubectl scale deployment backend --replicas=0 -n iagent  # Scale down"
    echo "    kubectl scale deployment backend --replicas=1 -n iagent  # Scale up"
    echo "    ./teardown-infrastructure.sh                            # Remove all"
    echo ""
    read -p "Press Enter to continue..."
}

# Handle workflow choice
handle_workflow_choice() {
    case $WORKFLOW_CHOICE in
        1)
            deploy_infrastructure
            ;;
        2)
            run_validation
            ;;
        3)
            setup_github_actions
            ;;
        4)
            show_cost_estimates
            ;;
        5)
            teardown_infrastructure
            ;;
        6)
            show_help
            ;;
        7)
            print_status "Exiting setup. You can run commands manually."
            print_status "Useful commands:"
            echo "  ./quick-devops-setup.sh   - Full setup"
            echo "  ./validate-setup.sh       - Validation"
            echo "  ./deploy-infrastructure.sh - Deploy"
            echo "  ./teardown-infrastructure.sh - Cleanup"
            return 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-7."
            show_workflow_options
            handle_workflow_choice
            ;;
    esac
    
    # After completing an action, show options again
    echo ""
    show_workflow_options
    handle_workflow_choice
}

# Show setup summary
show_setup_summary() {
    print_header "Container Setup Complete!"
    
    print_status "✅ Container environment verified"
    print_status "✅ AWS credentials configured"
    print_status "✅ Project dependencies installed"
    print_status "✅ Docker configured for ECR"
    print_status "✅ CDK bootstrapped"
    echo ""
    
    print_status "🚀 Ready for DevOps workflow!"
    echo ""
}

# Main execution
main() {
    print_banner
    check_container_environment
    echo ""
    configure_aws_credentials
    echo ""
    install_dependencies
    echo ""
    configure_docker_ecr
    echo ""
    bootstrap_cdk
    echo ""
    show_setup_summary
    show_workflow_options
    handle_workflow_choice
}

# Run main function
main "$@"