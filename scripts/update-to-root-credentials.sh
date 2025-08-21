#!/bin/bash

# Update AWS credentials to root access for EKS operations
# This is a temporary solution - in production, use proper IAM roles

echo "🔐 Updating AWS credentials to root access..."
echo ""
echo "⚠️  WARNING: This will use root AWS credentials for EKS access."
echo "   This is NOT recommended for production environments."
echo "   Consider using the setup-eks-permissions.sh script instead."
echo ""

# Check if .secrets file exists
if [ ! -f ".secrets" ]; then
    echo "❌ Error: .secrets file not found"
    exit 1
fi

echo "📝 Current .secrets file:"
cat .secrets
echo ""

echo "🔄 To fix the EKS access issue, you have two options:"
echo ""
echo "Option 1: Update .secrets with root credentials (quick fix)"
echo "   - Replace AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY with root credentials"
echo "   - This will give full access to AWS services"
echo ""
echo "Option 2: Fix IAM permissions (recommended)"
echo "   - Run: ./scripts/setup-eks-permissions.sh"
echo "   - This will add only the necessary EKS permissions to iagent-cicd user"
echo ""

echo "🔧 To update to root credentials manually:"
echo "   1. Go to AWS Console → IAM → Users"
echo "   2. Create a new access key for your root user (or use existing)"
echo "   3. Update the .secrets file with the new credentials"
echo "   4. Update GitHub repository secrets with the same values"
echo ""

echo "📋 Required GitHub secrets to update:"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY"
echo "   - AWS_ACCOUNT_ID (should remain the same)"
echo ""

echo "🔄 After updating credentials, the EKS access should work."
echo "   Run: aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster"
