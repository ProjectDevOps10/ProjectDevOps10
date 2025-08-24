# 🚀 DevOps Setup Guide

This guide explains the complete DevOps workflow for the iAgent chatbot application.

## 📋 Overview

The DevOps setup consists of **3 main phases**:

1. **🏗️ SETUP & DEPLOY**: Manual infrastructure deployment via AWS CDK
2. **🔄 DEVELOP & TRIGGER**: Automatic CI/CD via GitHub Actions when code is pushed
3. **💥 DESTROY & CLEANUP**: Manual infrastructure cleanup to avoid charges

## 🏗️ Phase 1: SETUP & DEPLOY (Manual)

### Infrastructure Components Created by CDK:
- **AWS ECR**: Docker registry for backend images
- **AWS EKS**: Kubernetes cluster (1 node, t3.small instance)
- **AWS VPC**: Simple networking setup
- **AWS IAM**: Roles and permissions

### Deploy Infrastructure:
```bash
# Deploy all AWS infrastructure
cd apps/infrastructure
npx cdk deploy --all --require-approval never
```

### Or Use GitHub Actions (Manual Trigger):
1. Go to **Actions** → **🏗️ Infrastructure Management**
2. Click **Run workflow**
3. Select action: **deploy**
4. Click **Run workflow**

## 🔄 Phase 2: DEVELOP & TRIGGER (Automatic)

When you push code to the `main` branch, GitHub Actions automatically:

### Frontend Deployment (GitHub Pages):
- **Trigger**: Push to `main` or manual dispatch
- **Workflow**: `.github/workflows/frontend-deploy.yml`
- **Process**:
  1. Build React frontend with `npx nx build frontend --configuration=production`
  2. Upload build artifacts to GitHub Pages
  3. Deploy to `https://<username>.github.io/<repo-name>`

### Backend Deployment (AWS EKS):
- **Trigger**: Push to `main`
- **Workflow**: `.github/workflows/simple-cicd.yml`
- **Process**:
  1. Build and push Docker image to ECR
  2. Update Kubernetes deployment in EKS
  3. Trigger frontend deployment via repository dispatch

### Complete CI/CD Flow:
```
Push to main
     ↓
Build & Test
     ↓
Build & Push Backend to ECR
     ↓
Deploy Backend to EKS
     ↓
Trigger Frontend to GitHub Pages
```

## 💥 Phase 3: DESTROY & CLEANUP (Manual)

### Destroy Infrastructure:
```bash
# Destroy all AWS infrastructure
cd apps/infrastructure
npx cdk destroy --all --force --require-approval never
```

### Or Use GitHub Actions (Manual Trigger):
1. Go to **Actions** → **🏗️ Infrastructure Management**
2. Click **Run workflow**
3. Select action: **destroy**
4. Click **Run workflow**

## 🌐 GitHub Pages Setup

### Enable GitHub Pages:
1. Go to repository **Settings** → **Pages**
2. Set **Source** to **GitHub Actions**
3. Your frontend will be available at: `https://<username>.github.io/<repo-name>`

### Frontend URL Examples:
- `https://yourusername.github.io/iAgent`
- `https://yourorg.github.io/iAgent`

## 🔧 Required Secrets

Add these to your repository **Settings** → **Secrets and variables** → **Actions**:

```
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
AWS_ACCOUNT_ID=<your-aws-account-id>
```

## 📁 Key Files

### Infrastructure:
- `apps/infrastructure/src/main.ts` - CDK app entry point
- `apps/infrastructure/src/lib/cost-optimized-infrastructure-stack.ts` - Main infrastructure

### GitHub Actions:
- `.github/workflows/simple-cicd.yml` - Main CI/CD pipeline
- `.github/workflows/frontend-deploy.yml` - Frontend GitHub Pages deployment
- `.github/workflows/infrastructure.yml` - Infrastructure management

### Kubernetes:
- `apps/infrastructure/src/k8s/namespace.yaml` - Kubernetes namespace
- `apps/infrastructure/src/k8s/deployment.yaml` - Backend deployment

## 🎯 Usage Examples

### Deploy Everything:
1. Run: `npx cdk deploy --all` (infrastructure)
2. Push code to `main` (triggers automatic deployment)
3. Frontend available on GitHub Pages
4. Backend available on EKS

### Daily Development:
1. Make changes to frontend/backend
2. Push to `main` branch
3. GitHub Actions automatically builds and deploys both
4. Check deployments at:
   - Frontend: `https://<username>.github.io/<repo-name>`
   - Backend: EKS cluster endpoint

### Cleanup:
1. Run: `npx cdk destroy --all` (removes all AWS resources)
2. GitHub Pages continues to serve last deployed frontend

## ⚠️ Important Notes

1. **Frontend**: Deployed to **GitHub Pages** (free, fast)
2. **Backend**: Deployed to **AWS EKS** (pay per use)
3. **Manual Steps**: Infrastructure deploy/destroy only
4. **Automatic Steps**: Code builds and deployments
5. **Cost Control**: Remember to destroy AWS resources when not needed

## 🔍 Monitoring

### Check Status:
- **Frontend**: Visit your GitHub Pages URL
- **Backend**: `kubectl get pods -n iagent`
- **Infrastructure**: `aws cloudformation list-stacks`
- **Node Group**: `aws eks describe-nodegroup --cluster-name iagent-cluster --nodegroup-name simple-nodegroup --region eu-central-1 --query "nodegroup.status"`

### Logs:
- **GitHub Actions**: Repository → Actions tab
- **EKS**: `kubectl logs -n iagent deployment/iagent-backend`
- **CloudFormation**: AWS Console → CloudFormation

## 🔧 Troubleshooting

### If GitHub Actions Gets Stuck on Node Group:
The EKS node group can take 15-20 minutes to provision. If GitHub Actions times out:

1. **Cancel the stuck workflow**:
   - Go to Actions → Running workflow → Cancel

2. **Check node group status**:
   ```bash
   aws eks describe-nodegroup --cluster-name iagent-cluster --nodegroup-name simple-nodegroup --region eu-central-1
   ```

3. **If node group is still CREATING**, you can either:
   - **Wait**: Node groups can take up to 20 minutes
   - **Manual deploy**: Deploy manually once it's ACTIVE
   - **Restart workflow**: The updated workflow has better timeout handling

4. **Manual deployment once node group is ACTIVE**:
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster
   
   # Apply Kubernetes resources
   kubectl apply -f apps/infrastructure/src/k8s/namespace.yaml
   kubectl apply -f apps/infrastructure/src/k8s/deployment.yaml
   
   # Check status
   kubectl get pods -n iagent
   ```

### Common Issues:
- **Node group stuck CREATING**: Normal, can take 15-20 minutes
- **ECR permission denied**: Check AWS credentials in repository secrets
- **kubectl access denied**: Node group may not be ready yet

## 🎉 Success Indicators

✅ **Infrastructure Ready**: CDK deploy completes successfully  
✅ **Backend Running**: EKS pods are in "Running" state  
✅ **Frontend Live**: GitHub Pages shows your React app  
✅ **CI/CD Working**: Green checkmarks in GitHub Actions  

Your DevOps setup is now complete! 🚀
