#!/bin/bash

# Run AWS credentials validation first
echo "🔍 Running AWS credentials validation..."
if ! bash .devcontainer/validate-secrets.sh; then
    echo "❌ AWS credentials validation failed!"
    echo "Container cannot start without valid AWS credentials."
    exit 1
fi

# Setup global AWS profile for all shells
echo "🔧 Setting up global AWS profile..."
bash .devcontainer/setup-aws-profile.sh

# Load environment variables from .secrets file for current session
echo "Loading AWS credentials from .secrets file..."
export $(cat /workspaces/iAgent/.secrets | grep -v '^#' | xargs)
echo "AWS credentials loaded successfully"

# Validate AWS credentials are properly loaded
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "❌ ERROR: AWS credentials are missing or empty!"
    echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
    echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}..."
    echo "Container cannot start without valid AWS credentials."
    exit 1
fi

# Set default region if not already set
if [ -z "$AWS_DEFAULT_REGION" ]; then
    export AWS_DEFAULT_REGION="eu-central-1"
fi

echo "✅ AWS credentials loaded successfully"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_DEFAULT_REGION"

# Test AWS CLI connectivity
echo "🧪 Testing AWS CLI connectivity..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✅ AWS CLI is working correctly!"
    echo "   Identity: $(aws sts get-caller-identity --query 'Arn' --output text)"
else
    echo "❌ AWS CLI test failed!"
    echo "   Please check your AWS credentials and permissions"
    exit 1
fi

# iAgent DevOps Container Startup Script
# Runs when the container starts

echo "🐳 Starting iAgent DevOps Container..."

# Source bashrc to get all aliases and environment
source /home/devuser/.bashrc

# Check if we're in the correct directory
if [ ! -f "/workspace/package.json" ]; then
    echo "⚠️ Warning: Not in iAgent project directory"
    echo "Expected to find package.json in /workspace"
fi

# Display container information
/home/devuser/show-versions.sh

echo ""
echo "📁 Workspace: /workspace"
echo "🏠 Home: /home/devuser"
echo ""
echo "🚀 Next steps:"
echo "  1. Run: ./container-setup.sh to configure AWS"
echo "  2. Run: ./quick-devops-setup.sh for full deployment"
echo "  3. Run: ./teardown-infrastructure.sh when done"
echo ""