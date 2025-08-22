#!/bin/bash

# iAgent Complete AWS Cleanup Script
# This script will completely destroy ALL AWS resources created by the CDK stack

set -e

echo "🚨 iAgent AWS Complete Cleanup Script"
echo "====================================="
echo ""
echo "⚠️  WARNING: This will permanently delete ALL AWS resources including:"
echo "   - ECR repositories (iagent-backend, iagent-frontend)"
echo "   - EKS cluster (iagent-cluster)"
echo "   - VPC and all subnets"
echo "   - IAM roles and policies"
echo "   - CloudWatch dashboards and alarms"
echo "   - SNS topics"
echo "   - All associated resources"
echo ""
echo "🔍 This action cannot be undone!"
echo ""

read -p "Are you sure you want to continue? Type 'YES' to confirm: " confirmation

if [ "$confirmation" != "YES" ]; then
    echo "❌ Cleanup cancelled by user"
    exit 1
fi

echo ""
echo "🧹 Starting complete AWS cleanup..."

# Check if we're in the right directory
if [ ! -f "apps/infrastructure/cdk.json" ]; then
    echo "❌ Error: Please run this script from the iAgent project root directory"
    exit 1
fi

# Load AWS credentials
if [ -f ".secrets" ]; then
    echo "🔐 Loading AWS credentials from .secrets..."
    export $(cat .secrets | grep -v '^#' | xargs)
else
    echo "❌ Error: .secrets file not found. Please ensure AWS credentials are configured."
    exit 1
fi

# Navigate to infrastructure directory
cd apps/infrastructure

echo "🔍 Checking current CDK stack status..."

# List current stacks
if cdk list > /dev/null 2>&1; then
    echo "📋 Current stacks:"
    cdk list
    
    echo ""
    echo "🗑️  Destroying all CDK stacks..."
    
    # Force destroy all stacks
    cdk destroy --all --force --require-approval never
    
    echo "✅ CDK stacks destroyed successfully"
else
    echo "ℹ️  No CDK stacks found or CDK not accessible"
fi

echo ""
echo "🧹 Additional cleanup steps..."

# Check if ECR repositories still exist
echo "🔍 Checking ECR repositories..."
if aws ecr describe-repositories --repository-names iagent-backend --region eu-central-1 > /dev/null 2>&1; then
    echo "🗑️  Deleting iagent-backend repository..."
    aws ecr delete-repository --repository-name iagent-backend --force --region eu-central-1
    echo "✅ iagent-backend repository deleted"
else
    echo "ℹ️  iagent-backend repository not found"
fi

if aws ecr describe-repositories --repository-names iagent-frontend --region eu-central-1 > /dev/null 2>&1; then
    echo "🗑️  Deleting iagent-frontend repository..."
    aws ecr delete-repository --repository-name iagent-frontend --force --region eu-central-1
    echo "✅ iagent-frontend repository deleted"
else
    echo "ℹ️  iagent-frontend repository not found"
fi

# Check if EKS clusters exist
echo "🔍 Checking EKS clusters..."
if aws eks list-clusters --region eu-central-1 --query 'clusters[?contains(@, `iagent`)]' --output text | grep -q iagent; then
    echo "🗑️  Deleting iagent EKS clusters..."
    for cluster in $(aws eks list-clusters --region eu-central-1 --query 'clusters[?contains(@, `iagent`)]' --output text); do
        echo "   Deleting cluster: $cluster"
        aws eks delete-cluster --name $cluster --region eu-central-1
    done
    echo "✅ EKS clusters deleted"
else
    echo "ℹ️  No iagent EKS clusters found"
fi

echo ""
echo "🎉 AWS cleanup completed!"
echo ""
echo "📋 Summary of what was destroyed:"
echo "   ✅ CDK stacks"
echo "   ✅ ECR repositories"
echo "   ✅ EKS clusters"
echo "   ✅ VPC and networking"
echo "   ✅ IAM roles and policies"
echo "   ✅ CloudWatch resources"
echo "   ✅ SNS topics"
echo ""
echo "🔍 To verify cleanup, check the AWS Console or run:"
echo "   aws ecr describe-repositories --region eu-central-1"
echo "   aws eks list-clusters --region eu-central-1"
echo ""

cd ../..
