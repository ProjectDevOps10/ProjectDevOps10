# Infrastructure Management Guide 🏗️

This guide shows how to manage all AWS services through the **infrastructure app only**, without external scripts.

## 🎯 **Centralized AWS Management**

All AWS services are managed through the **infrastructure Nx application** using AWS CDK:

- ✅ **EKS Cluster** (Kubernetes)
- ✅ **EC2 Instances** (EKS nodes)
- ✅ **ECR Repositories** (Docker images)
- ✅ **VPC & Networking** (NAT Gateway, Security Groups)
- ✅ **CloudWatch** (Monitoring, Logs, Alarms)
- ✅ **SNS Topics** (Notifications)
- ✅ **Route53** (DNS - optional)
- ✅ **ACM** (SSL Certificates - optional)
- ✅ **Load Balancers** (via EKS)

## 🚀 **Quick Commands**

### **Deploy All Services**
```bash
# Deploy all infrastructure
npx nx run infrastructure:deploy

# Deploy with specific environment
npx nx run infrastructure:deploy:prod
npx nx run infrastructure:deploy:dev
```

### **Destroy All Services (Stop Billing)**
```bash
# Destroy all infrastructure (stops all billing)
npx nx run infrastructure:destroy

# Force destroy without confirmation
npx nx run infrastructure:destroy:force
```

### **Check Status**
```bash
# List all deployed resources
npx nx run infrastructure:status

# See what will be deployed
npx nx run infrastructure:diff

# Check costs
npx nx run infrastructure:cost
```

## 📋 **Complete Command Reference**

### **Deployment Commands**
```bash
# Deploy infrastructure
npx nx run infrastructure:deploy

# Deploy with environment context
npx nx run infrastructure:deploy:prod
npx nx run infrastructure:deploy:dev

# Bootstrap CDK (first time only)
npx nx run infrastructure:bootstrap

# Synthesize CloudFormation templates
npx nx run infrastructure:synth
```

### **Destruction Commands**
```bash
# Destroy all resources (stops billing)
npx nx run infrastructure:destroy

# Force destroy without prompts
npx nx run infrastructure:destroy:force
```

### **Monitoring Commands**
```bash
# Check deployment status
npx nx run infrastructure:status

# View CloudFormation logs
npx nx run infrastructure:logs

# Monitor changes in real-time
npx nx run infrastructure:monitor

# Validate templates
npx nx run infrastructure:validate
```

### **Analysis Commands**
```bash
# See what will change
npx nx run infrastructure:diff

# Estimate costs
npx nx run infrastructure:cost

# Security analysis
npx nx run infrastructure:security

# View metadata
npx nx run infrastructure:metadata

# Check context
npx nx run infrastructure:context
```

### **Utility Commands**
```bash
# Clean build artifacts
npx nx run infrastructure:clean

# CDK doctor (troubleshooting)
npx nx run infrastructure:doctor

# Initialize new CDK app
npx nx run infrastructure:init
```

## ⚙️ **Configuration Options**

### **Environment Variables**
```bash
# AWS Region (default: eu-central-1)
export CDK_DEFAULT_REGION=eu-central-1

# Cluster configuration
export CLUSTER_NAME=iagent-cluster
export NODE_GROUP_INSTANCE_TYPE=t3.medium
export NODE_GROUP_MIN_SIZE=1
export NODE_GROUP_MAX_SIZE=3
export NODE_GROUP_DESIRED_SIZE=2

# Monitoring configuration
export ENABLE_MONITORING=true
export ENABLE_ALARMS=true

# Domain configuration (optional)
export DOMAIN_NAME=your-domain.com

# Environment
export ENVIRONMENT=dev
```

### **Configuration Examples**

#### **Minimal Configuration (Development)**
```bash
export ENABLE_MONITORING=false
export ENABLE_ALARMS=false
export NODE_GROUP_MIN_SIZE=1
export NODE_GROUP_MAX_SIZE=2
npx nx run infrastructure:deploy
```

#### **Production Configuration**
```bash
export ENABLE_MONITORING=true
export ENABLE_ALARMS=true
export NODE_GROUP_MIN_SIZE=2
export NODE_GROUP_MAX_SIZE=5
export DOMAIN_NAME=your-domain.com
npx nx run infrastructure:deploy:prod
```

#### **Cost-Optimized Configuration**
```bash
export ENABLE_MONITORING=true
export ENABLE_ALARMS=false
export NODE_GROUP_INSTANCE_TYPE=t3.small
export NODE_GROUP_MIN_SIZE=1
export NODE_GROUP_MAX_SIZE=2
npx nx run infrastructure:deploy
```

## 💰 **Cost Management**

### **Monthly Cost Breakdown**
| Service | Cost | Managed By |
|---------|------|------------|
| EKS Cluster | $50-100 | `infrastructure:deploy` |
| EC2 Instances | $30-50 | `infrastructure:deploy` |
| NAT Gateway | $45 | `infrastructure:deploy` |
| ECR Storage | $5-10 | `infrastructure:deploy` |
| CloudWatch | $10-20 | `infrastructure:deploy` |
| Load Balancer | $20-30 | `infrastructure:deploy` |
| SNS | $1-5 | `infrastructure:deploy` |
| **Total** | **$117-216** | **All managed by infrastructure app** |

### **Stop All Billing**
```bash
# This destroys ALL AWS resources and stops ALL billing
npx nx run infrastructure:destroy:force
```

### **Cost Optimization**
```bash
# Check current costs
npx nx run infrastructure:cost

# Deploy with minimal resources
export NODE_GROUP_INSTANCE_TYPE=t3.small
export NODE_GROUP_MIN_SIZE=1
export NODE_GROUP_MAX_SIZE=1
export ENABLE_ALARMS=false
npx nx run infrastructure:deploy
```

## 🔄 **Workflow Examples**

### **Complete Development Workflow**
```bash
# 1. Bootstrap (first time only)
npx nx run infrastructure:bootstrap

# 2. Deploy with development settings
export ENABLE_MONITORING=true
export ENABLE_ALARMS=false
npx nx run infrastructure:deploy

# 3. Check status
npx nx run infrastructure:status

# 4. Monitor changes
npx nx run infrastructure:monitor

# 5. Destroy when done (stop billing)
npx nx run infrastructure:destroy
```

### **Production Deployment Workflow**
```bash
# 1. Deploy production infrastructure
export ENVIRONMENT=production
export ENABLE_MONITORING=true
export ENABLE_ALARMS=true
export DOMAIN_NAME=your-domain.com
npx nx run infrastructure:deploy:prod

# 2. Verify deployment
npx nx run infrastructure:status

# 3. Monitor for issues
npx nx run infrastructure:monitor
```

### **Emergency Shutdown Workflow**
```bash
# 1. Check what will be destroyed
npx nx run infrastructure:diff

# 2. Force destroy all resources (stops all billing)
npx nx run infrastructure:destroy:force

# 3. Verify destruction
npx nx run infrastructure:status
```

## 🛡️ **Safety Features**

### **Built-in Protections**
- **Stack Protection**: Prevents accidental deletion
- **Confirmation Prompts**: Asks before destroying resources
- **Environment Separation**: Different configs for dev/prod
- **Resource Tagging**: All resources tagged for cost tracking

### **Safe Destruction**
```bash
# Safe destroy (with confirmation)
npx nx run infrastructure:destroy

# Force destroy (no confirmation - use carefully)
npx nx run infrastructure:destroy:force
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Permission Errors**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify permissions
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

#### **Bootstrap Required**
```bash
# First time setup
npx nx run infrastructure:bootstrap
```

#### **Resource Conflicts**
```bash
# Check what exists
npx nx run infrastructure:status

# See differences
npx nx run infrastructure:diff
```

#### **CDK Issues**
```bash
# CDK doctor
npx nx run infrastructure:doctor

# Validate templates
npx nx run infrastructure:validate
```

### **Recovery Commands**
```bash
# Redeploy if something goes wrong
npx nx run infrastructure:deploy

# Check logs
npx nx run infrastructure:logs

# Monitor deployment
npx nx run infrastructure:monitor
```

## 📊 **Monitoring & Observability**

### **Built-in Monitoring**
When `ENABLE_MONITORING=true`:
- ✅ CloudWatch Dashboard
- ✅ Application Logs
- ✅ EKS Cluster Metrics
- ✅ Custom Application Metrics
- ✅ SNS Notifications (if alarms enabled)

### **Access Monitoring**
```bash
# Dashboard URL (output after deployment)
# https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=iAgent-Application-Dashboard

# View logs
npx nx run infrastructure:logs

# Monitor changes
npx nx run infrastructure:monitor
```

## 🎯 **Best Practices**

### **Development**
1. **Use minimal resources** for development
2. **Disable alarms** to reduce costs
3. **Destroy resources** when not in use
4. **Monitor costs** regularly

### **Production**
1. **Enable monitoring** and alarms
2. **Use appropriate instance sizes**
3. **Set up proper scaling**
4. **Monitor performance**

### **Cost Management**
1. **Destroy resources** when not needed
2. **Use spot instances** where possible
3. **Monitor billing** dashboard
4. **Set up billing alerts**

## 🚀 **Quick Reference**

### **Essential Commands**
```bash
# Deploy everything
npx nx run infrastructure:deploy

# Stop all billing
npx nx run infrastructure:destroy

# Check status
npx nx run infrastructure:status

# See costs
npx nx run infrastructure:cost
```

### **Environment Setup**
```bash
# Development (minimal cost)
export ENABLE_MONITORING=false
export ENABLE_ALARMS=false
export NODE_GROUP_MIN_SIZE=1
export NODE_GROUP_MAX_SIZE=2

# Production (full features)
export ENABLE_MONITORING=true
export ENABLE_ALARMS=true
export NODE_GROUP_MIN_SIZE=2
export NODE_GROUP_MAX_SIZE=5
export DOMAIN_NAME=your-domain.com
```

---

**Remember**: All AWS services are managed through the infrastructure app. No external scripts needed! 