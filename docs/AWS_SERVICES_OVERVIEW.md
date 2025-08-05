# AWS Services Overview - iAgent DevOps Project 🚀

This document provides a comprehensive overview of all AWS services deployed and managed by the iAgent DevOps project.

## 📊 **Complete AWS Services Inventory**

### 🏗️ **Infrastructure Services**

#### 1. **EC2 (Elastic Compute Cloud)**
- **Purpose**: Virtual Private Cloud and networking infrastructure
- **Components**:
  - VPC with public/private subnets across 2 AZs
  - NAT Gateway for private subnet internet access
  - Security Groups with least privilege access
  - Network ACLs for additional security
- **Cost**: ~$30-50/month (NAT Gateway + data transfer)
- **Region**: `eu-central-1` (Frankfurt)

#### 2. **EKS (Elastic Kubernetes Service)**
- **Purpose**: Managed Kubernetes cluster for backend deployment
- **Components**:
  - Kubernetes cluster (v1.28)
  - Node groups with t3.medium instances
  - Cluster logging enabled (API, Audit, Authenticator, Controller Manager, Scheduler)
  - Auto-scaling capabilities
- **Cost**: ~$50-100/month (cluster + node instances)
- **Region**: `eu-central-1` (Frankfurt)

#### 3. **ECR (Elastic Container Registry)**
- **Purpose**: Container image storage and management
- **Components**:
  - `iagent-backend` repository
  - `iagent-frontend` repository
  - Image scanning on push
  - Lifecycle rules (max 10 images per repository)
- **Cost**: ~$5-10/month (storage + data transfer)
- **Region**: `eu-central-1` (Frankfurt)

#### 4. **IAM (Identity and Access Management)**
- **Purpose**: Security and access control
- **Components**:
  - Service accounts for Kubernetes components
  - Policies for Cluster Autoscaler
  - Policies for Load Balancer Controller
  - Policies for External DNS
  - Least privilege access principles
- **Cost**: Free
- **Region**: Global

#### 5. **Route53 (DNS Service)**
- **Purpose**: Domain name management (optional)
- **Components**:
  - Hosted zone (if domain provided)
  - DNS records management
  - Health checks
- **Cost**: ~$1/month (if using custom domain)
- **Region**: Global

#### 6. **ACM (AWS Certificate Manager)**
- **Purpose**: SSL/TLS certificate management (optional)
- **Components**:
  - SSL/TLS certificates for custom domain
  - Automatic renewal
  - DNS validation
- **Cost**: Free (for public certificates)
- **Region**: Global

#### 7. **ELB (Elastic Load Balancer)**
- **Purpose**: Load balancing for Kubernetes services
- **Components**:
  - Network Load Balancer (via NGINX Ingress)
  - Health checks
  - SSL termination
- **Cost**: ~$20-30/month
- **Region**: `eu-central-1` (Frankfurt)

### 📊 **Monitoring & Observability Services**

#### 8. **CloudWatch**
- **Purpose**: Monitoring, logging, and observability
- **Components**:
  - Custom dashboard for application metrics
  - EKS cluster metrics (CPU, Memory)
  - Application metrics (Request count, Response time, Error rate)
  - Log groups for application logs
  - Custom metrics and alarms
- **Cost**: ~$10-20/month
- **Region**: `eu-central-1` (Frankfurt)

#### 9. **SNS (Simple Notification Service)**
- **Purpose**: Alerting and notifications
- **Components**:
  - Alarm topic for CloudWatch alarms
  - Email/SMS notifications (configurable)
  - Integration with monitoring stack
- **Cost**: ~$1-5/month
- **Region**: `eu-central-1` (Frankfurt)

#### 10. **CloudWatch Alarms**
- **Purpose**: Automated alerting based on metrics
- **Components**:
  - High CPU utilization alarm (>80%)
  - High memory utilization alarm (>85%)
  - High error rate alarm (>5%)
  - SNS integration for notifications
- **Cost**: Included with CloudWatch
- **Region**: `eu-central-1` (Frankfurt)

### 🔧 **Kubernetes Add-ons (via Helm)**

#### 11. **Cluster Autoscaler**
- **Purpose**: Automatic scaling of EKS node groups
- **Cost**: Free (runs on EKS)
- **Region**: `eu-central-1` (Frankfurt)

#### 12. **AWS Load Balancer Controller**
- **Purpose**: Automatic AWS Load Balancer provisioning
- **Cost**: Free (runs on EKS)
- **Region**: `eu-central-1` (Frankfurt)

#### 13. **External DNS**
- **Purpose**: Automatic DNS record management
- **Cost**: Free (runs on EKS)
- **Region**: `eu-central-1` (Frankfurt)

#### 14. **Metrics Server**
- **Purpose**: Kubernetes metrics collection
- **Cost**: Free (runs on EKS)
- **Region**: `eu-central-1` (Frankfurt)

#### 15. **NGINX Ingress Controller**
- **Purpose**: HTTP routing and load balancing
- **Cost**: Free (runs on EKS)
- **Region**: `eu-central-1` (Frankfurt)

## 💰 **Cost Breakdown**

### Monthly Estimated Costs:
- **EKS Cluster**: $50-100
- **EC2 (VPC + NAT)**: $30-50
- **ECR Storage**: $5-10
- **CloudWatch**: $10-20
- **ELB**: $20-30
- **SNS**: $1-5
- **Route53**: $1 (if using custom domain)
- **Total**: ~$117-216/month

### Cost Optimization Tips:
1. **Use Spot Instances** for EKS node groups (50-70% savings)
2. **Enable Cluster Autoscaler** to scale down during low usage
3. **Set up CloudWatch retention policies** for logs
4. **Use S3 lifecycle policies** for log archiving
5. **Monitor resource usage** regularly

## 🔒 **Security Features**

### Infrastructure Security:
- VPC with private subnets
- Security groups with least privilege
- IAM roles with minimal permissions
- SSL/TLS encryption in transit
- Container image scanning

### Application Security:
- JWT authentication
- Input validation
- CORS configuration
- Security headers
- Vulnerability scanning with Trivy

## 📈 **Scalability Features**

### Auto-scaling:
- EKS Cluster Autoscaler
- Horizontal Pod Autoscaling (HPA)
- Load balancer auto-scaling
- CloudWatch-based scaling policies

### High Availability:
- Multi-AZ deployment
- Auto-recovery capabilities
- Health checks and monitoring
- Backup and disaster recovery

## 🚀 **Deployment Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Pages  │    │   AWS EKS       │    │   AWS ECR       │
│   (Frontend)    │    │   (Backend)     │    │   (Images)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
          │                       │                       │
          └───────────────────────┼───────────────────────┘
                                  │
                     ┌─────────────────┐
                     │  GitHub Actions │
                     │   (CI/CD)       │
                     └─────────────────┘
                                  │
                     ┌─────────────────┐
                     │   AWS CDK       │
                     │ (Infrastructure)│
                     └─────────────────┘
                                  │
                     ┌─────────────────┐
                     │  CloudWatch     │
                     │ (Monitoring)    │
                     └─────────────────┘
```

## 🔧 **Management & Operations**

### Infrastructure as Code:
- All infrastructure defined in AWS CDK
- Version controlled in Git
- Automated deployment via GitHub Actions
- Environment-specific configurations

### Monitoring & Alerting:
- Real-time metrics and logs
- Automated alerting via SNS
- Custom dashboards
- Performance optimization insights

### Backup & Recovery:
- ECR image versioning
- CloudWatch log retention
- Infrastructure state in CDK
- Disaster recovery procedures

## 📋 **Service Dependencies**

### Critical Dependencies:
1. **EKS** depends on **EC2** (VPC, subnets)
2. **ECR** depends on **IAM** (permissions)
3. **CloudWatch** depends on **IAM** (service roles)
4. **Load Balancer** depends on **EKS** and **EC2**
5. **Route53** depends on **ACM** (for SSL)

### Deployment Order:
1. VPC and networking (EC2)
2. IAM roles and policies
3. ECR repositories
4. EKS cluster
5. Kubernetes add-ons
6. Monitoring stack (CloudWatch, SNS)
7. Application deployment

## 🎯 **Best Practices**

### Security:
- Use least privilege access
- Enable CloudTrail for audit logs
- Regular security updates
- Container image scanning
- Network segmentation

### Performance:
- Use appropriate instance types
- Enable auto-scaling
- Monitor resource usage
- Optimize container images
- Use CDN for static assets

### Cost:
- Use Spot instances where possible
- Set up billing alerts
- Regular cost reviews
- Resource tagging
- Clean up unused resources

---

**Note**: All services are deployed in the `eu-central-1` (Frankfurt) region as it's the closest AWS region to Israel. AWS does not currently have a region located in Israel. 