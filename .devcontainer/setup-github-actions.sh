#!/bin/bash

# GitHub Actions Local Testing Setup Script
# This script sets up local secrets for GitHub Actions testing with 'act'

set -e

echo "🚀 Setting up GitHub Actions local testing environment..."

# Colors for output
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

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if AWS credentials are configured
check_aws_credentials() {
    print_header "Checking AWS Credentials"
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_warning "AWS credentials not configured. Please run 'aws configure' first."
        return 1
    fi
    
    print_status "AWS credentials are configured"
    return 0
}

# Create local secrets file for GitHub Actions testing
create_local_secrets() {
    print_header "Creating Local Secrets File"
    
    if [ -f .secrets ]; then
        print_warning "Local .secrets file already exists. Backing up..."
        cp .secrets .secrets.backup
    fi
    
    print_status "Creating .secrets file for local GitHub Actions testing..."
    
    cat > .secrets << EOF
# AWS Credentials for local GitHub Actions testing
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

# GitHub Token (optional - add your personal access token for full testing)
# GITHUB_TOKEN=your_github_personal_access_token_here
EOF

    chmod 600 .secrets
    print_status "Local secrets file created and secured"
}

# Display GitHub Actions testing instructions
show_instructions() {
    print_header "GitHub Actions Local Testing Instructions"
    
    echo "🧪 To test workflows locally with 'act':"
    echo ""
    echo "  # List all available workflows"
    echo "  act --list"
    echo ""
    echo "  # Test a specific workflow"
    echo "  act -W .github/workflows/frontend-ci-cd.yml --job build-and-test --secret-file .secrets"
    echo ""
    echo "  # Test with dry run (no execution)"
    echo "  act -W .github/workflows/frontend-ci-cd.yml --job build-and-test --dry-run"
    echo ""
    echo "🔐 For GitHub repository secrets (to fix actual CI/CD):"
    echo "   Go to: https://github.com/Eilon-Cohen/Eilon-s-Repository_1/settings/secrets/actions"
    echo ""
    echo "   Add these secrets:"
    echo "   - AWS_ACCOUNT_ID: $(aws sts get-caller-identity --query Account --output text)"
    echo "   - AWS_ACCESS_KEY_ID: [from 'aws configure get aws_access_key_id']"
    echo "   - AWS_SECRET_ACCESS_KEY: [from 'aws configure get aws_secret_access_key']"
    echo ""
}

# Main execution
main() {
    print_header "GitHub Actions Local Testing Setup"
    
    if check_aws_credentials; then
        create_local_secrets
        show_instructions
        print_status "✅ GitHub Actions local testing setup complete!"
    else
        print_warning "❌ Setup failed. Please configure AWS credentials first."
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi