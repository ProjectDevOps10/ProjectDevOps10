#!/bin/bash

# 🚀 iAgent Complete Project Deployment Script
# This script deploys the entire project: infrastructure, backend, and frontend

set -e

echo "🚀 Starting iAgent Complete Project Deployment..."
echo "================================================"

# Check if AWS credentials are available
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "❌ AWS credentials not found. Please source your .secrets file first:"
    echo "   source .secrets"
    exit 1
fi

# Step 1: Deploy Infrastructure
echo ""
echo "🏗️  Step 1: Deploying AWS Infrastructure..."
echo "--------------------------------------------"
cd apps/infrastructure

# Build the infrastructure
echo "📦 Building infrastructure..."
npx nx build infrastructure

# Deploy using CDK
echo "🚀 Deploying infrastructure..."
npx cdk deploy --all --require-approval never

# Get the outputs
echo "📋 Infrastructure deployed successfully!"
npx cdk list

cd ../..

# Step 2: Build and Push Backend to ECR
echo ""
echo "🐳 Step 2: Building and Pushing Backend to ECR..."
echo "------------------------------------------------"

# Build backend
echo "📦 Building backend..."
npx nx build backend

# Get ECR repository URI from CDK output
ECR_URI=$(aws cloudformation describe-stacks \
    --stack-name IAgentInfrastructureStack \
    --region eu-central-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`BackendRepositoryUri`].OutputValue' \
    --output text)

echo "🔍 ECR Repository: $ECR_URI"

# Build and push Docker image
echo "🐳 Building Docker image..."
docker build -t iagent-backend:latest -f apps/backend/Dockerfile .

# Tag and push to ECR
echo "🚀 Pushing to ECR..."
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $ECR_URI
docker tag iagent-backend:latest $ECR_URI:latest
docker push $ECR_URI:latest

# Step 3: Deploy Backend to EKS
echo ""
echo "🚀 Step 3: Deploying Backend to EKS..."
echo "---------------------------------------"

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster

# Apply Kubernetes manifests
echo "📋 Applying Kubernetes manifests..."
kubectl apply -f apps/backend/k8s/

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/iagent-backend

# Step 4: Build and Deploy Frontend
echo ""
echo "📱 Step 4: Building Frontend..."
echo "--------------------------------"

# Build frontend
echo "📦 Building frontend..."
npx nx build frontend

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo "🏗️  Infrastructure: Deployed to AWS"
echo "🐳 Backend: Deployed to EKS"
echo "📱 Frontend: Built and ready for GitHub Pages deployment"
echo ""
echo "📋 Next Steps:"
echo "1. Push to GitHub to trigger GitHub Actions for frontend deployment"
echo "2. Your backend API will be available at the EKS cluster endpoint"
echo "3. Monitor your deployment with: kubectl get pods"
echo ""
echo "💰 To save money when done, run: ./scripts/destroy-all.sh"
