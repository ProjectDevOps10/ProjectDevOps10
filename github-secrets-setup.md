# GitHub Secrets Setup for iAgent DevOps

## Required Secrets

Add these secrets to your GitHub repository:

### AWS Credentials
1. Go to GitHub repository → Settings → Secrets and variables → Actions
2. Add the following repository secrets:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ACCOUNT_ID
```

### How to get AWS credentials:

1. **AWS Access Keys** (for CI/CD user):
   ```bash
   # Create IAM user for CI/CD
   aws iam create-user --user-name iagent-cicd
   
   # Attach necessary policies
   aws iam attach-user-policy --user-name iagent-cicd --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
   aws iam attach-user-policy --user-name iagent-cicd --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
   aws iam attach-user-policy --user-name iagent-cicd --policy-arn arn:aws:iam::aws:policy/CloudFormationFullAccess
   
   # Create access keys
   aws iam create-access-key --user-name iagent-cicd
   ```

2. **Account ID**:
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

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
- Estimated monthly cost: $15-50 with spot instances

## Workflow Features

✅ Automated testing and linting  
✅ Security scanning with Trivy  
✅ Docker image building and pushing to ECR  
✅ Frontend deployment to GitHub Pages  
✅ Backend deployment to EKS  
✅ Manual infrastructure deployment/teardown  
✅ Cost optimization with spot instances  
