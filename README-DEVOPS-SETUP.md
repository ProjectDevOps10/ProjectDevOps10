# 🚀 iAgent DevOps Setup - One Command Deployment

A cost-optimized AWS DevOps environment that you can deploy with one command and teardown with one command to avoid unnecessary charges.

## ⚡ Quick Start

### One Command Setup

```bash
./quick-devops-setup.sh
```

Choose option 1 for full setup, or select individual components.

### One Command Teardown

```bash
./teardown-infrastructure.sh
```

This will **completely remove all AWS resources** and stop all charges.

## 💰 Cost Optimization Features

- **Spot Instances**: Up to 90% savings on EC2 costs
- **Auto-scaling**: Scale to zero when idle
- **Single NAT Gateway**: Reduced networking costs  
- **Image Lifecycle**: Automatic cleanup of old images
- **Log Retention**: Short retention periods to reduce costs
- **Easy Teardown**: Remove everything with one command

**Estimated Monthly Cost**: $15-50 USD (vs $150+ without optimizations)

## 📋 What Gets Deployed

### AWS Infrastructure
- **EKS Cluster**: Kubernetes cluster with auto-scaling
- **ECR Repositories**: Container registry for Docker images
- **VPC**: Custom networking with public/private subnets
- **CloudWatch**: Monitoring and logging
- **IAM Roles**: Proper security permissions

### CI/CD Pipeline
- **GitHub Actions**: Automated build, test, and deployment
- **Security Scanning**: Vulnerability scanning with Trivy
- **Docker Images**: Automated building and pushing
- **Frontend**: Deployed to GitHub Pages
- **Backend**: Deployed to Kubernetes

## 🛠️ Prerequisites

- AWS Account with programmatic access
- GitHub repository
- Node.js 18+
- Docker Desktop
- Git

## 📁 Script Overview

| Script | Purpose | Time |
|--------|---------|------|
| `quick-devops-setup.sh` | **Main script** - Interactive setup menu | 5 min |
| `setup-aws-environment.sh` | Configure AWS CLI, Docker, CDK | 3 min |
| `deploy-infrastructure.sh` | Deploy AWS infrastructure | 10-15 min |
| `teardown-infrastructure.sh` | **Remove all AWS resources** | 5-10 min |
| `setup-github-actions.sh` | Configure CI/CD pipeline | 2 min |

## 🚀 Step-by-Step Setup

### Step 1: Initial Setup
```bash
# Clone the repository
git clone <your-repo>
cd <your-repo>

# Run the main setup script
./quick-devops-setup.sh
```

### Step 2: AWS Configuration
When prompted, configure your AWS credentials:
```bash
AWS Access Key ID: YOUR_ACCESS_KEY
AWS Secret Access Key: YOUR_SECRET_KEY
Default region: eu-central-1
```

### Step 3: Infrastructure Deployment
The script will:
- Create EKS cluster with spot instances
- Set up ECR repositories
- Configure networking and security
- Deploy Kubernetes manifests

### Step 4: CI/CD Setup
- Create GitHub Actions workflows
- Generate secrets setup instructions
- Configure automated deployments

### Step 5: GitHub Configuration
Follow the instructions in `github-secrets-setup.md`:
1. Add AWS credentials to GitHub secrets
2. Enable GitHub Pages
3. Push code to trigger CI/CD

## 💻 Local Development

### Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env

# Install dependencies
npm install

# Start development servers
npm run dev
```

### Useful Commands
```bash
# View cluster status
kubectl get nodes

# View application pods
kubectl get pods -n iagent

# View logs
kubectl logs -f deployment/backend -n iagent

# Scale down to save costs
kubectl scale deployment backend --replicas=0 -n iagent

# Scale back up
kubectl scale deployment backend --replicas=1 -n iagent
```

## 🔒 Security Features

- **IAM Roles**: Least privilege access
- **VPC**: Private networking for workloads
- **Security Scanning**: Automated vulnerability checks
- **Secrets Management**: Kubernetes secrets for sensitive data
- **Network Policies**: Controlled traffic flow

## 📊 Monitoring & Observability

- **CloudWatch Dashboard**: Application metrics
- **Cost Monitoring**: Budget alerts and tracking
- **Health Checks**: Kubernetes liveness/readiness probes
- **Log Aggregation**: Centralized logging

## 🔄 CI/CD Pipeline Features

### Automated Workflows
- **Build & Test**: Lint, test, and build applications
- **Security Scan**: Vulnerability scanning
- **Docker Build**: Multi-stage optimized images
- **Deploy Frontend**: Automatic GitHub Pages deployment
- **Deploy Backend**: Kubernetes rolling updates
- **Infrastructure**: Manual deployment trigger

### Manual Controls
- **Deploy Infrastructure**: Manual trigger for cost control
- **Teardown Infrastructure**: Emergency stop for all resources

## ⚠️ Important Notes

### Cost Management
- **Always teardown** when not using the infrastructure
- Monitor AWS costs in the billing console
- Use spot instances for maximum savings
- Set up billing alerts

### Data Persistence
- Database runs in demo mode (in-memory) by default
- For production, enable MongoDB persistence
- Conversations are stored locally in the frontend

### Scaling
- Cluster auto-scales based on demand
- Can scale to zero to eliminate costs
- Supports burst scaling for high traffic

## 🆘 Troubleshooting

### Common Issues

#### Script Permission Denied
```bash
chmod +x *.sh
```

#### AWS CLI Not Configured
```bash
aws configure
# Enter your credentials
```

#### Cluster Not Accessible
```bash
aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster
```

#### High Costs
```bash
# Scale down immediately
kubectl scale deployment backend --replicas=0 -n iagent

# Or teardown everything
./teardown-infrastructure.sh
```

#### Docker Issues
```bash
# Re-login to ECR
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.eu-central-1.amazonaws.com
```

### Getting Help

1. Check AWS CloudFormation console for stack status
2. View logs: `kubectl logs -f deployment/backend -n iagent`
3. Check AWS costs in billing dashboard
4. Review GitHub Actions logs for CI/CD issues

## 🎯 Production Readiness

### For Production Use
1. Enable MongoDB persistence
2. Set up proper SSL certificates
3. Configure custom domain names
4. Implement backup strategies
5. Set up monitoring alerts
6. Review security settings

### Cost Optimization for Production
1. Use Reserved Instances for predictable workloads
2. Implement CloudFront CDN
3. Optimize image sizes
4. Set up proper auto-scaling policies
5. Use data transfer optimization

## 📚 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Cost Optimization](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/#cost-optimization)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Cost Management](https://aws.amazon.com/aws-cost-management/)

---

## 🎉 Success!

Once setup is complete, you'll have:
- ✅ Production-ready Kubernetes cluster
- ✅ Automated CI/CD pipeline
- ✅ Cost-optimized infrastructure
- ✅ Monitoring and observability
- ✅ One-command teardown capability

**Remember**: Always run `./teardown-infrastructure.sh` when you're done to avoid AWS charges!

---

*Built with ❤️ for cost-conscious DevOps*