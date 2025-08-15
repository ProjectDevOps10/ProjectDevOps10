# 🐳 iAgent DevOps Development Container

A complete containerized development environment with all tools pre-installed for AWS DevOps workflow.

## 🚀 Quick Start

### Prerequisites
- **VS Code** with Dev Containers extension
- **Docker Desktop** running on your machine
- **AWS Account** with programmatic access

### Step 1: Open in Dev Container
```bash
# In VS Code
1. Open this project folder
2. Press F1 → "Dev Containers: Reopen in Container"
3. Wait for container to build (first time: ~5-10 minutes)
```

### Step 2: Configure AWS and Deploy
```bash
# Inside the container terminal
./container-setup.sh
# Follow the interactive prompts
```

### Step 3: Teardown When Done
```bash
./teardown-infrastructure.sh
# Removes ALL AWS resources and stops charges
```

## 🛠️ What's Included in the Container

### Pre-installed Tools
- **Node.js 18** - Latest LTS version
- **AWS CLI v2** - Latest AWS command line
- **kubectl** - Kubernetes command line
- **Docker CLI** - Container management
- **AWS CDK** - Infrastructure as Code
- **GitHub CLI** - GitHub integration
- **Act** - Local GitHub Actions testing
- **Helm** - Kubernetes package manager
- **Trivy** - Security vulnerability scanner

### VS Code Extensions
- AWS Toolkit
- Kubernetes Tools
- Docker Extension
- GitHub Actions
- TypeScript/ESLint/Prettier
- And more...

### Container Features
- **Non-root user** for security
- **Docker-in-Docker** support
- **AWS credentials** mounting
- **SSH keys** mounting for Git
- **Port forwarding** (3000, 4200)

## 📁 Container Structure

```
/workspace/          # Your project files (mounted)
/home/devuser/       # Container user home
  ├── .aws/          # AWS configuration
  ├── .kube/         # Kubernetes configuration
  └── .ssh/          # SSH keys (mounted from host)
```

## 🔄 Complete Workflow Inside Container

### 1. Initial Setup
```bash
# Run the container setup script
./container-setup.sh

# It will:
# ✅ Check container environment
# ✅ Configure AWS credentials
# ✅ Install project dependencies
# ✅ Configure Docker for ECR
# ✅ Bootstrap AWS CDK
```

### 2. Choose Your Workflow
The container setup script provides options:
1. **Deploy Infrastructure** - Create AWS resources
2. **Run Validation** - Check configuration
3. **Setup GitHub Actions** - Configure CI/CD
4. **Show Cost Estimates** - See pricing
5. **Teardown Infrastructure** - Remove all resources
6. **Show Help** - Command reference

### 3. Development Commands
```bash
# Development
npm run dev              # Start dev servers
npm run build           # Build applications
npm test               # Run tests

# AWS Operations
aws sts get-caller-identity  # Check AWS connection
aws eks list-clusters       # List EKS clusters

# Kubernetes Operations  
kubectl get nodes          # Check cluster nodes
kubectl get pods -n iagent # Check application pods
kubectl logs -f deployment/backend -n iagent  # View logs

# Cost Management
kubectl scale deployment backend --replicas=0 -n iagent  # Scale down
kubectl scale deployment backend --replicas=1 -n iagent  # Scale up
```

## 💰 Cost Management in Container

### Monitor Costs
```bash
# Check AWS costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost

# Scale applications
kubectl scale deployment backend --replicas=0 -n iagent  # Stop compute charges
```

### Teardown Everything
```bash
./teardown-infrastructure.sh
# This removes:
# ✅ EKS cluster and nodes
# ✅ ECR repositories
# ✅ VPC and networking
# ✅ CloudWatch resources
# ✅ All billable components
```

## 🧪 Testing CI/CD Pipeline

### 1. Setup GitHub Secrets
```bash
# Inside container
./setup-github-actions.sh
# Follow instructions in github-secrets-setup.md
```

### 2. Required GitHub Secrets
Add these to your GitHub repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ACCOUNT_ID`

### 3. Trigger Deployments
```bash
# Manual triggers via GitHub Actions:
# 1. Go to Actions tab in GitHub
# 2. Select "iAgent DevOps Pipeline"
# 3. Click "Run workflow"
# 4. Choose deployment options
```

## 🔧 Container Configuration

### Environment Variables
```bash
# Automatically set in container:
AWS_DEFAULT_REGION=eu-central-1
NODE_ENV=development
DOCKER_BUILDKIT=1
```

### Port Forwarding
- **Port 3000**: Backend API server
- **Port 4200**: Frontend development server

### Volume Mounts
- **Docker socket**: For Docker-in-Docker
- **AWS credentials**: From host ~/.aws
- **SSH keys**: From host ~/.ssh

## 🛠️ Customizing the Container

### Modify Dockerfile
```dockerfile
# Add additional tools to .devcontainer/Dockerfile
RUN apt-get update && apt-get install -y \
    your-additional-tool \
    && rm -rf /var/lib/apt/lists/*
```

### Add VS Code Extensions
```json
// In .devcontainer/devcontainer.json
"extensions": [
  "existing.extensions",
  "your.new.extension"
]
```

### Environment Variables
```json
// In .devcontainer/devcontainer.json
"containerEnv": {
  "YOUR_VARIABLE": "your-value"
}
```

## 🆘 Troubleshooting

### Container Issues

#### Container Won't Start
```bash
# Rebuild container
1. F1 → "Dev Containers: Rebuild Container"
2. Check Docker Desktop is running
3. Check available disk space
```

#### AWS Credentials Issues
```bash
# Inside container
aws configure
# Re-enter your credentials

# Or check mounted credentials
ls -la ~/.aws/
cat ~/.aws/credentials
```

#### Docker Issues
```bash
# Check Docker daemon
docker info

# If not working, Docker-in-Docker might not be available
# Deploy scripts will handle this automatically
```

#### Kubernetes Connection Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster

# Check connection
kubectl cluster-info
```

### High AWS Costs
```bash
# Immediate cost reduction
kubectl scale deployment backend --replicas=0 -n iagent

# Complete teardown
./teardown-infrastructure.sh
```

### Port Conflicts
```bash
# Change ports in devcontainer.json if needed
"forwardPorts": [3001, 4201]  # Use different ports
```

## 📊 Container Performance

### Resource Usage
- **CPU**: 2-4 cores recommended
- **Memory**: 4-8 GB recommended
- **Disk**: 10-20 GB for container and dependencies

### Optimization Tips
```bash
# Clear npm cache
npm cache clean --force

# Clear Docker cache
docker system prune -f

# Clean node_modules
rm -rf node_modules && npm install
```

## 🎯 Production Deployment from Container

### 1. Infrastructure Deployment
```bash
# Deploy production-ready infrastructure
./deploy-infrastructure.sh

# Configure production settings
# - Enable MongoDB persistence
# - Configure SSL certificates
# - Set up monitoring alerts
```

### 2. CI/CD Pipeline
```bash
# Setup automated deployments
./setup-github-actions.sh

# Push to trigger pipeline
git add .
git commit -m "Deploy to production"
git push origin main
```

### 3. Monitoring
```bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# View logs
kubectl logs -f deployment/backend -n iagent

# Check costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

## 🔐 Security Best Practices

### Container Security
- **Non-root user**: Container runs as `devuser`
- **Minimal attack surface**: Only necessary tools installed
- **Read-only filesystem**: Where possible
- **Security scanning**: Trivy included for vulnerability checks

### AWS Security
- **IAM roles**: Least privilege access
- **VPC**: Private networking for workloads
- **Secrets**: Kubernetes secrets for sensitive data
- **Encryption**: EBS volumes encrypted

### Development Security
```bash
# Scan for vulnerabilities
trivy fs .

# Check AWS security
aws iam get-account-summary

# Review permissions
aws sts get-caller-identity
```

## 📚 Additional Resources

- [VS Code Dev Containers](https://code.visualstudio.com/docs/remote/containers)
- [Docker Documentation](https://docs.docker.com/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## 🎉 Success!

Your dev container is now ready for the complete iAgent DevOps workflow:

✅ **All tools pre-installed**  
✅ **AWS integration ready**  
✅ **One-command deployment**  
✅ **Complete CI/CD pipeline**  
✅ **Cost optimization built-in**  
✅ **Easy teardown process**  

**Start with**: `./container-setup.sh` inside the container! 🚀

---

*Built with ❤️ for containerized DevOps*