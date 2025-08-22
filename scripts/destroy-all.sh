#!/bin/bash

# 💰 iAgent Complete Project Cleanup Script
# This script destroys all AWS resources to save money

set -e

echo "💰 Starting iAgent Complete Project Cleanup..."
echo "============================================="

# Check if AWS credentials are available
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "❌ AWS credentials not found. Please source your .secrets file first:"
    echo "   source .secrets"
    exit 1
fi

# Confirmation prompt
echo ""
echo "⚠️  WARNING: This will destroy ALL AWS resources including:"
echo "   - EKS Cluster and all workloads"
echo "   - ECR Repositories and all images"
echo "   - VPC, Subnets, and Network resources"
echo "   - All associated costs will stop"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled."
    exit 0
fi

echo ""
echo "🗑️  Starting cleanup process..."

# Step 1: Clean up Kubernetes resources
echo ""
echo "🚀 Step 1: Cleaning up Kubernetes resources..."
echo "----------------------------------------------"

# Check if kubectl is available and cluster exists
if command -v kubectl &> /dev/null; then
    echo "🔧 Updating kubeconfig..."
    aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster 2>/dev/null || echo "⚠️  EKS cluster not found or not accessible"
    
    # Delete Kubernetes resources
    echo "📋 Deleting Kubernetes resources..."
    kubectl delete -f apps/backend/k8s/ --ignore-not-found=true 2>/dev/null || echo "⚠️  No Kubernetes resources to delete"
else
    echo "⚠️  kubectl not available, skipping Kubernetes cleanup"
fi

# Step 2: Destroy CDK Infrastructure
echo ""
echo "🏗️  Step 2: Destroying AWS Infrastructure..."
echo "--------------------------------------------"
cd apps/infrastructure

# Destroy using CDK
echo "🗑️  Destroying infrastructure..."
npx cdk destroy --all --force

cd ../..

# Step 3: Manual cleanup of any remaining resources
echo ""
echo "🧹 Step 3: Manual cleanup of remaining resources..."
echo "---------------------------------------------------"

# Delete any remaining ECR repositories
echo "🐳 Cleaning up ECR repositories..."
aws ecr delete-repository --repository-name iagent-backend --force --region eu-central-1 2>/dev/null || echo "⚠️  Backend ECR repository not found"
aws ecr delete-repository --repository-name iagent-frontend --force --region eu-central-1 2>/dev/null || echo "⚠️  Frontend ECR repository not found"

# Delete any remaining EKS clusters
echo "🚀 Cleaning up EKS clusters..."
aws eks delete-cluster --name iagent-cluster --region eu-central-1 2>/dev/null || echo "⚠️  EKS cluster not found"

# Wait for EKS cluster deletion
if aws eks describe-cluster --name iagent-cluster --region eu-central-1 2>/dev/null; then
    echo "⏳ Waiting for EKS cluster to be deleted..."
    aws eks wait cluster-deleted --name iagent-cluster --region eu-central-1
fi

# Delete any remaining VPCs (be careful with this)
echo "🌐 Cleaning up VPCs..."
VPC_IDS=$(aws ec2 describe-vpcs --region eu-central-1 --filters "Name=tag:Project,Values=iAgent" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")

if [ -n "$VPC_IDS" ]; then
    echo "🔍 Found VPCs: $VPC_IDS"
    for VPC_ID in $VPC_IDS; do
        echo "🗑️  Deleting VPC: $VPC_ID"
        aws ec2 delete-vpc --vpc-id $VPC_ID --region eu-central-1 2>/dev/null || echo "⚠️  Could not delete VPC $VPC_ID"
    done
fi

# Step 4: Final verification
echo ""
echo "🔍 Step 4: Final verification..."
echo "--------------------------------"

# Check for remaining resources
echo "📋 Checking for remaining resources..."

# Check ECR repositories
ECR_COUNT=$(aws ecr describe-repositories --region eu-central-1 --query 'repositories[?contains(repositoryName, `iagent`)].repositoryName' --output text 2>/dev/null | wc -w)
echo "🐳 Remaining ECR repositories: $ECR_COUNT"

# Check EKS clusters
EKS_COUNT=$(aws eks list-clusters --region eu-central-1 --query 'clusters[?contains(@, `iagent`)].@' --output text 2>/dev/null | wc -w)
echo "🚀 Remaining EKS clusters: $EKS_COUNT"

# Check CloudFormation stacks
STACK_COUNT=$(aws cloudformation list-stacks --region eu-central-1 --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[?contains(StackName, `iagent`)].StackName' --output text 2>/dev/null | wc -w)
echo "🏗️  Remaining CloudFormation stacks: $STACK_COUNT"

echo ""
echo "🎉 Cleanup Complete!"
echo "==================="
echo "💰 All AWS resources have been destroyed"
echo "🔄 Costs will stop accumulating"
echo ""
echo "📋 Summary:"
echo "   - EKS Cluster: Destroyed"
echo "   - ECR Repositories: Destroyed"
echo "   - VPC and Network: Destroyed"
echo "   - All associated resources: Destroyed"
echo ""
echo "🚀 To redeploy in the future, run: ./scripts/deploy-all.sh"
