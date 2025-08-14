#!/bin/bash

# GitHub Actions CI/CD Setup Script for iAgent
# Configures GitHub Actions for automated deployment

set -e

# Colors for output
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Load AWS configuration
if [ ! -f .env.aws ]; then
    print_error ".env.aws not found. Please run setup-aws-environment.sh first"
    exit 1
fi

source .env.aws

print_header "Setting up GitHub Actions CI/CD"

# Get GitHub repository info
get_github_info() {
    print_header "Getting GitHub Repository Information"
    
    # Try to get repo info from git
    if git remote -v &>/dev/null; then
        REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $REPO_URL =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
            GITHUB_OWNER=${BASH_REMATCH[1]}
            GITHUB_REPO=${BASH_REMATCH[2]}
            print_status "Detected GitHub repository: $GITHUB_OWNER/$GITHUB_REPO"
        else
            print_error "Could not detect GitHub repository from git remote"
            read -p "Enter GitHub username/organization: " GITHUB_OWNER
            read -p "Enter repository name: " GITHUB_REPO
        fi
    else
        print_error "Git repository not found"
        read -p "Enter GitHub username/organization: " GITHUB_OWNER
        read -p "Enter repository name: " GITHUB_REPO
    fi
    
    print_status "GitHub Repository: $GITHUB_OWNER/$GITHUB_REPO"
}

# Create optimized GitHub Actions workflow
create_github_workflow() {
    print_header "Creating GitHub Actions Workflow"
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/iagent-devops-pipeline.yml << 'EOF'
name: 🚀 iAgent DevOps Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      deploy_infrastructure:
        description: 'Deploy infrastructure'
        required: false
        default: 'false'
        type: choice
        options:
          - 'true'
          - 'false'
      teardown_infrastructure:
        description: 'Teardown infrastructure (DANGER)'
        required: false
        default: 'false'
        type: choice
        options:
          - 'true'
          - 'false'

env:
  AWS_REGION: eu-central-1
  EKS_CLUSTER_NAME: iagent-cluster
  ECR_BACKEND_REPO: iagent-backend
  ECR_FRONTEND_REPO: iagent-frontend
  NODE_VERSION: '18'

jobs:
  # Job 1: Build and Test
  build-and-test:
    name: 🧪 Build & Test
    runs-on: ubuntu-latest
    if: github.event.inputs.teardown_infrastructure != 'true'
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: 📦 Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: 📦 Install dependencies
      run: npm ci
      
    - name: 🧪 Run tests
      run: npm test
      
    - name: 🔍 Run linting
      run: npm run lint
      
    - name: 🏗️ Build applications
      run: npm run build

  # Job 2: Security Scan
  security-scan:
    name: 🔒 Security Scan
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.event.inputs.teardown_infrastructure != 'true'
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: 🔍 Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'table'
        exit-code: '0' # Don't fail on vulnerabilities for now

  # Job 3: Build and Push Docker Images
  build-images:
    name: 🐳 Build Docker Images
    runs-on: ubuntu-latest
    needs: [build-and-test, security-scan]
    if: github.ref == 'refs/heads/main' && github.event.inputs.teardown_infrastructure != 'true'
    
    outputs:
      backend-image: ${{ steps.backend-image.outputs.image }}
      frontend-image: ${{ steps.frontend-image.outputs.image }}
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: ⚙️ Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
        
    - name: 🔐 Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2
      
    - name: 🏗️ Build backend image
      id: backend-image
      run: |
        IMAGE_TAG=${GITHUB_SHA::8}
        IMAGE_URI=${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_BACKEND_REPO }}:$IMAGE_TAG
        docker build -t $IMAGE_URI apps/backend/
        docker push $IMAGE_URI
        echo "image=$IMAGE_URI" >> $GITHUB_OUTPUT
        
    - name: 🏗️ Build frontend image
      id: frontend-image
      run: |
        IMAGE_TAG=${GITHUB_SHA::8}
        IMAGE_URI=${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_FRONTEND_REPO }}:$IMAGE_TAG
        docker build -t $IMAGE_URI apps/frontend/
        docker push $IMAGE_URI
        echo "image=$IMAGE_URI" >> $GITHUB_OUTPUT

  # Job 4: Deploy to GitHub Pages
  deploy-frontend:
    name: 📄 Deploy Frontend to GitHub Pages
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/main' && github.event.inputs.teardown_infrastructure != 'true'
    
    permissions:
      contents: read
      pages: write
      id-token: write
    
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: 📦 Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: 📦 Install dependencies
      run: npm ci
      
    - name: 🏗️ Build frontend
      run: npm run build:frontend
      env:
        VITE_API_BASE_URL: https://api.your-domain.com
        VITE_MOCK_MODE: false
        
    - name: 📄 Setup Pages
      uses: actions/configure-pages@v4
      
    - name: 📦 Upload artifact
      uses: actions/upload-pages-artifact@v3
      with:
        path: 'dist/apps/frontend'
        
    - name: 🚀 Deploy to GitHub Pages
      id: deployment
      uses: actions/deploy-pages@v4

  # Job 5: Deploy Infrastructure (Manual Trigger)
  deploy-infrastructure:
    name: 🏗️ Deploy Infrastructure
    runs-on: ubuntu-latest
    if: github.event.inputs.deploy_infrastructure == 'true'
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: 📦 Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: ⚙️ Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
        
    - name: 📦 Install dependencies
      run: npm ci
      
    - name: 🏗️ Deploy infrastructure
      run: |
        cd apps/infrastructure
        npm install
        npm run build
        npx cdk deploy --require-approval never

  # Job 6: Deploy to EKS
  deploy-backend:
    name: ☸️ Deploy Backend to EKS
    runs-on: ubuntu-latest
    needs: [build-images]
    if: github.ref == 'refs/heads/main' && github.event.inputs.teardown_infrastructure != 'true'
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: ⚙️ Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
        
    - name: ⚙️ Setup kubectl
      run: |
        aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER_NAME }}
        
    - name: 🚀 Deploy to EKS
      run: |
        # Update deployment with new image
        sed -i "s|IMAGE_PLACEHOLDER|${{ needs.build-images.outputs.backend-image }}|g" apps/infrastructure/src/k8s/backend-deployment.yaml
        kubectl apply -f apps/infrastructure/src/k8s/ -n iagent
        kubectl rollout status deployment/backend -n iagent --timeout=300s

  # Job 7: Teardown Infrastructure (DANGER)
  teardown-infrastructure:
    name: 🗑️ Teardown Infrastructure
    runs-on: ubuntu-latest
    if: github.event.inputs.teardown_infrastructure == 'true'
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      
    - name: ⚠️ Confirmation
      run: |
        echo "🚨 WARNING: This will delete ALL infrastructure!"
        echo "This action will:"
        echo "  - Delete EKS cluster"
        echo "  - Delete ECR repositories"
        echo "  - Delete VPC and networking"
        echo "  - Delete CloudWatch resources"
        echo "💰 This will stop all AWS charges for this project"
        
    - name: 📦 Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: ⚙️ Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
        
    - name: 📦 Install dependencies
      run: npm ci
      
    - name: 🗑️ Destroy infrastructure
      run: |
        cd apps/infrastructure
        npm install
        npm run build
        npx cdk destroy --force
EOF

    print_status "GitHub Actions workflow created: .github/workflows/iagent-devops-pipeline.yml"
}

# Update CDK app to use cost-optimized stack
update_cdk_app() {
    print_header "Updating CDK App for Cost Optimization"
    
    cat > apps/infrastructure/src/main.ts << 'EOF'
#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CostOptimizedInfrastructureStack } from './lib/cost-optimized-infrastructure-stack';

const app = new cdk.App();

// Get parameters from context or environment
const clusterName = app.node.tryGetContext('clusterName') || 'iagent-cluster';
const instanceType = app.node.tryGetContext('nodeGroupInstanceType') || 't3.medium';
const enableSpotInstances = app.node.tryGetContext('enableSpotInstances') !== 'false';
const maxMonthlyCost = parseInt(app.node.tryGetContext('maxMonthlyCostUSD') || '50');

new CostOptimizedInfrastructureStack(app, 'IAgentInfrastructureStack', {
  clusterName,
  nodeGroupInstanceType: instanceType,
  nodeGroupMinSize: 0,
  nodeGroupMaxSize: 3,
  nodeGroupDesiredSize: 1,
  enableSpotInstances,
  enableMonitoring: true,
  enableAlarms: true,
  maxMonthlyCostUSD: maxMonthlyCost,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1',
  },
});
EOF

    print_status "CDK app updated to use cost-optimized stack"
}

# Create GitHub secrets setup instructions
create_secrets_instructions() {
    print_header "Creating GitHub Secrets Setup Instructions"
    
    cat > github-secrets-setup.md << EOF
# GitHub Secrets Setup for iAgent DevOps

## Required Secrets

Add these secrets to your GitHub repository:

### AWS Credentials
1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Add the following repository secrets:

\`\`\`
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ACCOUNT_ID
\`\`\`

### How to get AWS credentials:

1. **AWS Access Keys** (for CI/CD user):
   \`\`\`bash
   # Create IAM user for CI/CD
   aws iam create-user --user-name iagent-cicd
   
   # Attach necessary policies
   aws iam attach-user-policy --user-name iagent-cicd --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
   aws iam attach-user-policy --user-name iagent-cicd --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
   aws iam attach-user-policy --user-name iagent-cicd --policy-arn arn:aws:iam::aws:policy/CloudFormationFullAccess
   
   # Create access keys
   aws iam create-access-key --user-name iagent-cicd
   \`\`\`

2. **Account ID**:
   \`\`\`bash
   aws sts get-caller-identity --query Account --output text
   \`\`\`

## GitHub Pages Setup

1. Go to repository Settings → Pages
2. Set Source to "GitHub Actions"
3. The workflow will automatically deploy to GitHub Pages

## Manual Deployment Triggers

### Deploy Infrastructure:
- Go to Actions tab
- Select "iAgent DevOps Pipeline"
- Click "Run workflow"
- Set "Deploy infrastructure" to "true"

### Teardown Infrastructure:
- Go to Actions tab  
- Select "iAgent DevOps Pipeline"
- Click "Run workflow"
- Set "Teardown infrastructure" to "true"
- ⚠️ **WARNING**: This will delete all AWS resources!

## Cost Management

- Infrastructure deployment is manual to prevent accidental costs
- Teardown is available to quickly stop all charges
- Monitor costs in AWS Billing Dashboard
- Estimated monthly cost: \$15-50 with spot instances

## Workflow Features

✅ Automated testing and linting  
✅ Security scanning with Trivy  
✅ Docker image building and pushing to ECR  
✅ Frontend deployment to GitHub Pages  
✅ Backend deployment to EKS  
✅ Manual infrastructure deployment/teardown  
✅ Cost optimization with spot instances  
EOF

    print_status "GitHub secrets setup instructions created: github-secrets-setup.md"
}

# Create local development environment file
create_local_env() {
    print_header "Creating Local Development Environment"
    
    cat > .env.example << EOF
# iAgent Local Development Environment
# Copy this file to .env and update with your values

# AWS Configuration
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_REGION=$AWS_REGION
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key

# Application Configuration
NODE_ENV=development
PORT=3000

# Frontend Configuration
VITE_API_BASE_URL=http://localhost:3000
VITE_MOCK_MODE=true

# Backend Configuration
JWT_SECRET=your-jwt-secret-for-development
CORS_ORIGIN=http://localhost:4200

# Database (Optional - uses in-memory by default)
DEMO_MODE=true
MONGODB_URI=mongodb://localhost:27017/iagent

# GitHub Configuration (for CI/CD)
GITHUB_OWNER=$GITHUB_OWNER
GITHUB_REPO=$GITHUB_REPO
EOF

    print_status "Local environment template created: .env.example"
}

# Display setup summary
show_setup_summary() {
    print_header "GitHub Actions Setup Complete!"
    
    print_status "📋 Created Files:"
    echo "  ✅ .github/workflows/iagent-devops-pipeline.yml"
    echo "  ✅ github-secrets-setup.md"
    echo "  ✅ .env.example"
    echo "  ✅ Updated apps/infrastructure/src/main.ts"
    echo ""
    
    print_status "🚀 Next Steps:"
    echo "  1. Read github-secrets-setup.md for GitHub secrets configuration"
    echo "  2. Add AWS credentials to GitHub repository secrets"
    echo "  3. Enable GitHub Pages in repository settings"
    echo "  4. Push code to trigger the CI/CD pipeline"
    echo "  5. Manually trigger infrastructure deployment when ready"
    echo ""
    
    print_warning "💰 Cost Management:"
    echo "  • Infrastructure deployment is MANUAL to prevent accidental costs"
    echo "  • Use GitHub Actions to deploy/teardown infrastructure"
    echo "  • Always teardown when done to avoid charges"
    echo "  • Monitor AWS costs in the billing dashboard"
    echo ""
    
    print_status "🔗 GitHub Repository: https://github.com/$GITHUB_OWNER/$GITHUB_REPO"
    print_status "📄 GitHub Pages will be available at: https://$GITHUB_OWNER.github.io/$GITHUB_REPO"
}

# Main execution
main() {
    get_github_info
    create_github_workflow
    update_cdk_app
    create_secrets_instructions
    create_local_env
    show_setup_summary
}

# Run main function
main "$@"