#!/bin/bash

# iAgent Simple Container Setup Script
# Optimized for the simple devcontainer environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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
    echo -e "${BLUE}${BOLD}=== $1 ===${NC}"
}

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "🐳 iAgent Simple Container Setup"
    echo "Using Microsoft's DevContainer with AWS tools"
    echo "========================================"
    echo -e "${NC}"
}

# Check container environment
check_environment() {
    print_header "Checking Container Environment"
    
    # Check tools
    if command -v node &> /dev/null; then
        print_status "Node.js: $(node --version)"
    else
        print_error "Node.js not found"
        return 1
    fi
    
    if command -v aws &> /dev/null; then
        print_status "AWS CLI: $(aws --version 2>&1 | cut -d' ' -f1)"
    else
        print_error "AWS CLI not found"
        return 1
    fi
    
    if command -v kubectl &> /dev/null; then
        print_status "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    else
        print_error "kubectl not found"
        return 1
    fi
    
    if command -v docker &> /dev/null; then
        print_status "Docker CLI: $(docker --version 2>/dev/null || echo 'Docker CLI available')"
    else
        print_warning "Docker CLI not found (may be added later)"
    fi
    
    if command -v cdk &> /dev/null; then
        print_status "AWS CDK: $(cdk --version)"
    else
        print_warning "AWS CDK not found (installing...)"
        npm install -g aws-cdk
        print_status "AWS CDK: $(cdk --version)"
    fi
}

# Configure AWS credentials
configure_aws() {
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

# Bootstrap CDK
bootstrap_cdk() {
    print_header "Bootstrapping AWS CDK"
    
    source .env.aws
    
    print_status "Bootstrapping CDK for account $AWS_ACCOUNT_ID in region $AWS_REGION..."
    cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_REGION
    
    print_status "✅ CDK bootstrapped successfully"
}

# Show deployment options
show_deployment_options() {
    print_header "Deployment Options"
    
    echo "What would you like to do?"
    echo ""
    echo "  1) 🚀 Deploy full infrastructure (creates AWS resources)"
    echo "  2) 🧪 Run validation checks"
    echo "  3) 🔄 Setup GitHub Actions CI/CD"
    echo "  4) 📋 Show cost estimates"
    echo "  5) 🗑️ Teardown infrastructure (removes all AWS resources)"
    echo "  6) 🚪 Exit (manual commands)"
    echo ""
    read -p "Enter your choice (1-6): " -n 1 -r
    echo
    CHOICE=$REPLY
}

# Handle user choice
handle_choice() {
    case $CHOICE in
        1)
            print_header "Deploying Infrastructure"
            print_warning "💰 This will create AWS resources that incur charges!"
            print_warning "Estimated monthly cost: $15-50 USD with optimizations"
            echo ""
            read -p "Continue with deployment? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ./deploy-infrastructure.sh
            else
                print_status "Deployment cancelled"
            fi
            ;;
        2)
            print_header "Running Validation"
            ./validate-setup.sh
            ;;
        3)
            print_header "Setting up GitHub Actions"
            ./setup-github-actions.sh
            ;;
        4)
            print_header "Cost Estimates"
            echo "💰 Monthly cost breakdown with optimizations:"
            echo ""
            echo "  Core Services:"
            echo "    • EKS Control Plane: ~$73/month"
            echo "    • NAT Gateway (1): ~$45/month"
            echo "    • ECR Storage: ~$2/month"
            echo "    • CloudWatch: ~$5/month"
            echo ""
            echo "  Compute (optimized):"
            echo "    • t3.medium spot: ~$10/month ✅"
            echo "    • Auto-scale to 0: ~$0/month ✅"
            echo ""
            echo "  Total: ~$135/month (idle: ~$125/month)"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        5)
            print_header "Tearing Down Infrastructure"
            ./teardown-infrastructure.sh
            ;;
        6)
            print_header "Manual Mode"
            print_status "Available commands:"
            echo "  ./deploy-infrastructure.sh   - Deploy AWS infrastructure"
            echo "  ./teardown-infrastructure.sh - Remove all AWS resources"
            echo "  ./setup-github-actions.sh    - Configure CI/CD"
            echo "  ./validate-setup.sh          - Validate setup"
            echo ""
            return 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-6."
            show_deployment_options
            handle_choice
            ;;
    esac
    
    # After completing an action, show options again
    echo ""
    show_deployment_options
    handle_choice
}

# Show setup summary
show_setup_summary() {
    print_header "Container Setup Complete!"
    
    print_status "✅ Container environment verified"
    print_status "✅ AWS credentials configured"
    print_status "✅ Project dependencies installed"
    print_status "✅ CDK bootstrapped"
    echo ""
    
    print_status "🚀 Ready for DevOps workflow!"
    echo ""
}

# Main execution
main() {
    print_banner
    check_environment
    echo ""
    configure_aws
    echo ""
    install_dependencies
    echo ""
    bootstrap_cdk
    echo ""
    show_setup_summary
    show_deployment_options
    handle_choice
}

# Run main function
main "$@"