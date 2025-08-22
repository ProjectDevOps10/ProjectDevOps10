# iAgent Infrastructure as Code (IaC) Guide

## 🏗️ Overview

This project uses **AWS CDK (Cloud Development Kit)** to manage ALL AWS infrastructure as code. Every AWS resource is defined, created, and managed through CDK, ensuring complete control and the ability to destroy everything when needed.

## 📋 What Gets Created

### Core Infrastructure
- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **NAT Gateway**: Single NAT gateway for cost optimization
- **Security Groups**: Properly configured security groups for EKS

### Container Infrastructure
- **ECR Repositories**: 
  - `iagent-backend` - Backend container images
  - `iagent-frontend` - Frontend container images
- **EKS Cluster**: `iagent-cluster` with cost-optimized node groups
- **Node Groups**: Spot instances for cost savings

### Monitoring & Security
- **IAM Roles**: Proper permissions for EKS and EC2
- **CloudWatch**: Dashboards, alarms, and log groups
- **SNS Topics**: Notifications for alarms

## 🚀 How to Deploy

### 1. Build the Infrastructure
```bash
# From project root
npm run build infrastructure
```

### 2. Deploy Everything
```bash
cd apps/infrastructure
cdk deploy --all --require-approval never
```

### 3. Verify Deployment
```bash
# Check EKS cluster
aws eks list-clusters --region eu-central-1

# Check ECR repositories
aws ecr describe-repositories --region eu-central-1

# Check CDK stacks
cdk list
```

## 🗑️ How to Destroy Everything

### Option 1: CDK Destroy (Recommended)
```bash
cd apps/infrastructure
cdk destroy --all --force
```

### Option 2: Complete Cleanup Script
```bash
# From project root
./cleanup-aws.sh
```

## ⚠️ Important Notes

### Removal Policies
- **ECR Repositories**: Set to `DESTROY` - will delete ALL images
- **EKS Cluster**: Will delete cluster and all workloads
- **VPC**: Will delete all subnets, NAT gateways, and security groups
- **IAM Roles**: Will be cleaned up automatically

### What Gets Destroyed
When you run `cdk destroy` or `./cleanup-aws.sh`:
1. ✅ **EKS Cluster** - All Kubernetes workloads lost
2. ✅ **ECR Repositories** - All container images deleted
3. ✅ **VPC** - All networking resources removed
4. ✅ **IAM Roles** - All permissions removed
5. ✅ **CloudWatch** - All monitoring data lost
6. ✅ **SNS Topics** - All notifications removed

## 🔧 Infrastructure Management

### Adding New Resources
1. Add the resource to the CDK stack
2. Set appropriate `removalPolicy: cdk.RemovalPolicy.DESTROY`
3. Rebuild and deploy

### Modifying Existing Resources
1. Update the CDK code
2. Rebuild: `npm run build infrastructure`
3. Deploy: `cdk deploy --all`

### Cost Optimization Features
- **Spot Instances**: EKS nodes use spot instances (70% cost savings)
- **Limited AZs**: VPC limited to 2 availability zones
- **Single NAT Gateway**: Reduced from 2 to 1 NAT gateway
- **Short Log Retention**: CloudWatch logs kept for minimal time

## 🚨 Emergency Cleanup

If you need to completely remove everything from AWS:

```bash
# Run the complete cleanup script
./cleanup-aws.sh

# Or manually destroy CDK stacks
cd apps/infrastructure
cdk destroy --all --force

# Then manually delete any remaining resources
aws ecr delete-repository --repository-name iagent-backend --force
aws ecr delete-repository --repository-name iagent-frontend --force
aws eks delete-cluster --name iagent-cluster
```

## 📊 Cost Estimation

**Monthly Costs (approximate):**
- EKS Control Plane: $73
- NAT Gateway: $45
- EC2 Instances: $8-66 (depending on type)
- ECR Storage: $2
- CloudWatch: $5
- **Total**: $133-191/month

**With Spot Instances**: 30-40% cost reduction

## 🔍 Troubleshooting

### Common Issues
1. **ECR Repository Already Exists**: Run cleanup script first
2. **IAM Permissions**: Ensure AWS credentials have full permissions
3. **VPC Conflicts**: Destroy existing stacks before redeploying

### Verification Commands
```bash
# Check AWS resources
aws eks list-clusters --region eu-central-1
aws ecr describe-repositories --region eu-central-1
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*iagent*"

# Check CDK status
cdk list
cdk diff
```

## 📚 Best Practices

1. **Always use CDK**: Never create resources manually in AWS Console
2. **Test locally**: Use `cdk synth` to validate before deploying
3. **Version control**: All infrastructure changes are tracked in git
4. **Cleanup regularly**: Use cleanup script to avoid orphaned resources
5. **Monitor costs**: Check CloudWatch dashboards regularly

---

**Remember**: This is a COMPLETE Infrastructure as Code setup. Everything created by CDK can and will be destroyed by CDK. There are no manual resources that CDK can't manage.
