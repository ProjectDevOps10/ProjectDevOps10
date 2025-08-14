#!/bin/bash

# iAgent Quick DevOps Setup - One Command Deployment
# This script sets up the entire DevOps environment in one command

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
    echo "██╗      █████╗  ██████╗ ███████╗███╗   ██╗████████╗"
    echo "██║     ██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝"
    echo "██║     ███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   "
    echo "██║     ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   "
    echo "██║     ██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   "
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   "
    echo ""
    echo "🚀 iAgent DevOps Quick Setup - Cost Optimized"
    echo "One command deployment with AWS cost controls"
    echo -e "${NC}"
}

# Show setup options
show_setup_options() {
    print_header "Setup Options"
    echo "Choose your setup option:"
    echo "  1) 🚀 Full setup (Environment + Infrastructure + CI/CD)"
    echo "  2) ⚙️  Environment setup only (AWS CLI, Docker, CDK)"
    echo "  3) 🏗️  Infrastructure deployment only"
    echo "  4) 🔄 CI/CD setup only (GitHub Actions)"
    echo "  5) 🗑️  Teardown everything (Stop all AWS charges)"
    echo "  6) ❓ Help and information"
    echo ""
    read -p "Enter your choice (1-6): " -n 1 -r
    echo
    SETUP_CHOICE=$REPLY
}

# Full setup option
full_setup() {
    print_header "Full DevOps Setup Started"
    print_warning "This will set up the complete DevOps environment with AWS resources"
    print_warning "Estimated time: 15-20 minutes"
    print_warning "Estimated monthly cost: $15-50 USD (with cost optimizations)"
    echo ""
    read -p "Continue with full setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi
    
    # Step 1: Environment setup
    print_header "Step 1/4: Environment Setup"
    ./setup-aws-environment.sh
    
    # Step 2: Infrastructure deployment
    print_header "Step 2/4: Infrastructure Deployment"
    ./deploy-infrastructure.sh
    
    # Step 3: CI/CD setup
    print_header "Step 3/4: CI/CD Setup"
    ./setup-github-actions.sh
    
    # Step 4: Summary
    print_header "Step 4/4: Setup Complete!"
    show_success_summary
}

# Environment setup only
environment_setup() {
    print_header "Environment Setup Only"
    ./setup-aws-environment.sh
    print_status "Environment setup completed. Run option 3 to deploy infrastructure."
}

# Infrastructure deployment only
infrastructure_deployment() {
    print_header "Infrastructure Deployment Only"
    if [ ! -f .env.aws ]; then
        print_error "Environment not configured. Run option 2 first or use option 1 for full setup."
        exit 1
    fi
    ./deploy-infrastructure.sh
    print_status "Infrastructure deployment completed. Run option 4 to setup CI/CD."
}

# CI/CD setup only
cicd_setup() {
    print_header "CI/CD Setup Only"
    ./setup-github-actions.sh
    print_status "CI/CD setup completed. Check github-secrets-setup.md for next steps."
}

# Teardown everything
teardown_everything() {
    print_header "Teardown Infrastructure"
    print_warning "🚨 This will DELETE all AWS resources and STOP all charges!"
    print_warning "Make sure you have backed up any important data."
    echo ""
    ./teardown-infrastructure.sh
}

# Help and information
show_help() {
    print_header "iAgent DevOps Setup Help"
    
    echo "📋 What this setup includes:"
    echo "  ✅ AWS CLI and Docker configuration"
    echo "  ✅ Cost-optimized AWS infrastructure (EKS, ECR, VPC)"
    echo "  ✅ Kubernetes cluster with auto-scaling"
    echo "  ✅ Container registry for Docker images"
    echo "  ✅ GitHub Actions CI/CD pipeline"
    echo "  ✅ Frontend deployment to GitHub Pages"
    echo "  ✅ Backend deployment to Kubernetes"
    echo "  ✅ Cost monitoring and optimization"
    echo ""
    
    echo "💰 Cost optimization features:"
    echo "  ✅ Spot instances (up to 90% savings)"
    echo "  ✅ Auto-scaling to zero when idle"
    echo "  ✅ Single NAT gateway"
    echo "  ✅ ECR image lifecycle policies"
    echo "  ✅ CloudWatch log retention policies"
    echo "  ✅ Easy teardown to stop all charges"
    echo ""
    
    echo "🛠️ Prerequisites:"
    echo "  • AWS Account with programmatic access"
    echo "  • GitHub repository"
    echo "  • Node.js 18+"
    echo "  • Docker installed"
    echo ""
    
    echo "📁 Files created:"
    echo "  • setup-aws-environment.sh - AWS and Docker setup"
    echo "  • deploy-infrastructure.sh - Infrastructure deployment"
    echo "  • teardown-infrastructure.sh - Complete cleanup"
    echo "  • setup-github-actions.sh - CI/CD configuration"
    echo "  • .env.aws - AWS configuration"
    echo "  • github-secrets-setup.md - GitHub setup instructions"
    echo ""
    
    echo "🚀 Quick commands after setup:"
    echo "  Deploy: ./deploy-infrastructure.sh"
    echo "  Teardown: ./teardown-infrastructure.sh"
    echo "  Monitor: kubectl get pods -n iagent"
    echo ""
    
    read -p "Press Enter to return to main menu..."
    show_setup_options
    handle_choice
}

# Show success summary
show_success_summary() {
    print_header "🎉 Setup Complete!"
    
    print_status "✅ AWS environment configured"
    print_status "✅ Infrastructure deployed to AWS"
    print_status "✅ CI/CD pipeline configured"
    print_status "✅ Cost optimizations enabled"
    echo ""
    
    print_status "🔗 Your services:"
    if [ -f .env.deployment ]; then
        source .env.deployment
        echo "  • EKS Cluster: $CLUSTER_NAME"
        echo "  • Backend ECR: $BACKEND_ECR_URI"
        echo "  • Frontend ECR: $FRONTEND_ECR_URI"
    fi
    echo "  • GitHub Pages: Will be available after first deployment"
    echo ""
    
    print_status "📋 Next steps:"
    echo "  1. Follow instructions in github-secrets-setup.md"
    echo "  2. Add AWS secrets to GitHub repository"
    echo "  3. Push code to trigger CI/CD pipeline"
    echo "  4. Deploy infrastructure via GitHub Actions"
    echo ""
    
    print_warning "💰 Cost management:"
    echo "  • Current estimated monthly cost: $15-50"
    echo "  • Monitor costs in AWS Billing Console"
    echo "  • Run './teardown-infrastructure.sh' to stop all charges"
    echo "  • Scale down: kubectl scale deployment backend --replicas=0 -n iagent"
    echo ""
    
    print_status "📚 Useful commands:"
    echo "  • View cluster: kubectl get nodes"
    echo "  • View pods: kubectl get pods -n iagent"
    echo "  • View logs: kubectl logs -f deployment/backend -n iagent"
    echo "  • Scale down: kubectl scale deployment backend --replicas=0 -n iagent"
    echo "  • Teardown: ./teardown-infrastructure.sh"
}

# Handle user choice
handle_choice() {
    case $SETUP_CHOICE in
        1)
            full_setup
            ;;
        2)
            environment_setup
            ;;
        3)
            infrastructure_deployment
            ;;
        4)
            cicd_setup
            ;;
        5)
            teardown_everything
            ;;
        6)
            show_help
            ;;
        *)
            print_error "Invalid choice. Please select 1-6."
            show_setup_options
            handle_choice
            ;;
    esac
}

# Make scripts executable
make_scripts_executable() {
    chmod +x setup-aws-environment.sh
    chmod +x deploy-infrastructure.sh
    chmod +x teardown-infrastructure.sh
    chmod +x setup-github-actions.sh
    chmod +x quick-devops-setup.sh
}

# Main execution
main() {
    print_banner
    make_scripts_executable
    show_setup_options
    handle_choice
}

# Handle script errors
trap 'print_error "Setup failed! Check the error above."' ERR

# Run main function
main "$@"