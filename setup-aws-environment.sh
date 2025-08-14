#!/bin/bash

# iAgent DevOps Setup Script - Cost Optimized
# This script sets up AWS CLI and Docker for the iAgent project

set -e

echo "🚀 Setting up iAgent DevOps Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if required tools are installed
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first:"
        echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    print_status "AWS CLI found: $(aws --version)"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install it first:"
        echo "https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_status "Docker found: $(docker --version)"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not found. Installing..."
        # Install kubectl based on OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install kubectl
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi
    fi
    print_status "kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'kubectl installed')"
    
    # Check CDK
    if ! command -v cdk &> /dev/null; then
        print_warning "AWS CDK not found. Installing..."
        npm install -g aws-cdk
    fi
    print_status "AWS CDK found: $(cdk --version)"
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found. Please install Node.js 18+ first"
        exit 1
    fi
    print_status "Node.js found: $(node --version)"
}

# Configure AWS CLI
configure_aws() {
    print_header "Configuring AWS CLI"
    
    if [ ! -f ~/.aws/credentials ]; then
        print_warning "AWS credentials not configured. Please configure them now:"
        aws configure
    else
        print_status "AWS credentials already configured"
        aws sts get-caller-identity || {
            print_error "AWS credentials are invalid. Please reconfigure:"
            aws configure
        }
    fi
    
    # Set default region to eu-central-1 (Frankfurt - closest to Israel)
    aws configure set default.region eu-central-1
    print_status "Default region set to eu-central-1 (Frankfurt)"
    
    # Get account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    print_status "AWS Account ID: $ACCOUNT_ID"
    print_status "AWS Region: $AWS_REGION"
    
    # Save to environment file
    cat > .env.aws << EOF
AWS_ACCOUNT_ID=$ACCOUNT_ID
AWS_REGION=$AWS_REGION
AWS_DEFAULT_REGION=$AWS_REGION
EOF
    print_status "AWS configuration saved to .env.aws"
}

# Configure Docker for AWS ECR
configure_docker_ecr() {
    print_header "Configuring Docker for AWS ECR"
    
    # Source AWS config
    source .env.aws
    
    # Login to ECR
    print_status "Logging into AWS ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    print_status "Docker configured for AWS ECR"
}

# Install project dependencies
install_dependencies() {
    print_header "Installing Project Dependencies"
    
    print_status "Installing npm dependencies..."
    npm install
    
    print_status "Dependencies installed successfully"
}

# Bootstrap AWS CDK
bootstrap_cdk() {
    print_header "Bootstrapping AWS CDK"
    
    source .env.aws
    
    print_status "Bootstrapping CDK for account $AWS_ACCOUNT_ID in region $AWS_REGION..."
    cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_REGION
    
    print_status "CDK bootstrapped successfully"
}

# Create cost monitoring setup
create_cost_monitoring() {
    print_header "Setting up Cost Monitoring"
    
    cat > cost-monitor.json << EOF
{
  "BudgetLimit": {
    "Amount": "10.0",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "TimePeriod": {
    "Start": "$(date '+%Y-%m-01')",
    "End": "$(date -d '+1 month' '+%Y-%m-01')"
  },
  "BudgetName": "iAgent-DevOps-Budget",
  "BudgetType": "COST",
  "CostFilters": {
    "Service": ["Amazon Elastic Kubernetes Service", "Amazon Elastic Container Registry", "Amazon CloudWatch"]
  }
}
EOF
    
    print_warning "Consider setting up AWS Budget alerts for cost monitoring"
    print_warning "Budget template created in cost-monitor.json"
}

# Main execution
main() {
    print_header "iAgent DevOps Environment Setup"
    
    check_prerequisites
    configure_aws
    configure_docker_ecr
    install_dependencies
    bootstrap_cdk
    create_cost_monitoring
    
    print_header "Setup Complete!"
    print_status "✅ AWS CLI configured"
    print_status "✅ Docker configured for ECR"
    print_status "✅ Dependencies installed"
    print_status "✅ CDK bootstrapped"
    print_status "✅ Cost monitoring template created"
    
    echo ""
    print_warning "Next Steps:"
    echo "1. Run './deploy-infrastructure.sh' to deploy the infrastructure"
    echo "2. Run './setup-github-actions.sh' to configure CI/CD"
    echo "3. Run './teardown-infrastructure.sh' when you want to stop everything"
    
    echo ""
    print_warning "💰 Cost Optimization Tips:"
    echo "- Always run teardown script when not using the infrastructure"
    echo "- Monitor your AWS costs in the console"
    echo "- The infrastructure uses spot instances to minimize costs"
}

# Run main function
main "$@"