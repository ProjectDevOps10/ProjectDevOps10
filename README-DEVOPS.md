# iAgent DevOps Project 🚀

A comprehensive DevOps project demonstrating modern cloud infrastructure, CI/CD pipelines, and best practices using AWS, Kubernetes, and GitHub Actions.

## 🎯 **Project Overview**

This project showcases a complete DevOps implementation with:
- **Infrastructure as Code** using AWS CDK
- **Containerized Applications** (React frontend + NestJS backend)
- **Kubernetes Orchestration** on AWS EKS
- **Automated CI/CD** with GitHub Actions
- **Monitoring & Observability** with CloudWatch
- **Security Best Practices** and vulnerability scanning

## 🏗️ **Architecture**

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

## 🛠️ **Technology Stack**

### **Infrastructure**
- **AWS CDK** - Infrastructure as Code
- **AWS EKS** - Managed Kubernetes
- **AWS ECR** - Container Registry
- **AWS VPC** - Networking
- **AWS CloudWatch** - Monitoring & Logging
- **AWS SNS** - Notifications
- **AWS Route53** - DNS (optional)
- **AWS ACM** - SSL Certificates (optional)

### **Applications**
- **Frontend**: React + TypeScript + Vite
- **Backend**: NestJS + TypeScript
- **Containerization**: Docker + Multi-stage builds
- **Orchestration**: Kubernetes manifests

### **CI/CD**
- **GitHub Actions** - Automation pipelines
- **Nx** - Monorepo management
- **Trivy** - Security scanning
- **Helm** - Kubernetes package management

## 📁 **Project Structure**

```
iAgent/
├── apps/
│   ├── frontend/           # React application
│   ├── backend/            # NestJS API
│   ├── infrastructure/     # AWS CDK infrastructure (MANAGES ALL AWS SERVICES)
│   ├── monitoring/         # CloudWatch monitoring stack
│   └── cicd/              # CI/CD automation tools
├── libs/                   # Shared libraries
├── .github/workflows/      # GitHub Actions pipelines
├── scripts/               # Deployment scripts
└── docs/                  # Documentation
```

## 🚀 **Quick Start**

### **Prerequisites**
- Node.js 18+
- AWS CLI configured
- Docker
- kubectl

### **1. Deploy Infrastructure (All AWS Services)**
```bash
# Deploy all AWS services through infrastructure app
npx nx run infrastructure:deploy

# Check deployment status
npx nx run infrastructure:status
```

### **2. Deploy Applications**
```bash
# Deploy backend to EKS
npx nx run backend:deploy

# Deploy frontend to GitHub Pages
npx nx run frontend:deploy
```

### **3. Access Applications**
- **Frontend**: https://your-username.github.io/iAgent
- **Backend**: Available through EKS Load Balancer
- **Monitoring**: CloudWatch Dashboard

## 💰 **Cost Management**

### **Monthly Estimated Costs**
- **EKS Cluster**: $50-100
- **EC2 Instances**: $30-50
- **NAT Gateway**: $45
- **ECR Storage**: $5-10
- **CloudWatch**: $10-20
- **Load Balancer**: $20-30
- **SNS**: $1-5
- **Total**: ~$117-216/month

### **Stop All Billing**
```bash
# Destroy all AWS resources (stops all billing)
npx nx run infrastructure:destroy
```

### **⚠️ AWS Region Information**

**Important**: This project uses AWS region `eu-central-1` (Frankfurt, Germany) as it's the closest available region to Israel. AWS does not currently have a region located in Israel.

**Available regions near Israel:**
- `eu-central-1` (Frankfurt, Germany) - **Recommended** - Lowest latency to Israel
- `eu-west-1` (Ireland)
- `eu-west-2` (London, UK)
- `me-south-1` (Bahrain) - Middle East region

All AWS services used in this project are available in the European regions.

## 🏗️ **Infrastructure Management**

### **Centralized AWS Management**
All AWS services are managed through the **infrastructure app only**:

```bash
# Deploy all services
npx nx run infrastructure:deploy

# Destroy all services (stop billing)
npx nx run infrastructure:destroy

# Check status
npx nx run infrastructure:status

# See costs
npx nx run infrastructure:cost
```

### **Configuration Options**
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

## 📈 **CI/CD Pipeline**

### **Separated CI/CD Workflows**

The project uses **separated CI/CD workflows** for each application component:

#### 1. **Frontend CI/CD** (`frontend-ci-cd.yml`)
- **Trigger**: Changes to `apps/frontend/` or shared libraries
- **Stages**:
  - Build and test frontend
  - Deploy to GitHub Pages
  - Security scan

#### 2. **Backend CI/CD** (`backend-ci-cd.yml`)
- **Trigger**: Changes to `apps/backend/` or shared libraries
- **Stages**:
  - Build and test backend
  - Build and push Docker image to ECR
  - Deploy to EKS
  - Security scan

#### 3. **Infrastructure CI/CD** (`infrastructure-ci-cd.yml`)
- **Trigger**: Changes to `apps/infrastructure/` or shared libraries
- **Stages**:
  - Build and test infrastructure code
  - Deploy AWS CDK infrastructure
  - Security scan

#### 4. **Monitoring CI/CD** (`monitoring-ci-cd.yml`)
- **Trigger**: Changes to `apps/monitoring/` or shared libraries
- **Stages**:
  - Build and test monitoring code
  - Deploy CloudWatch monitoring
  - Security scan

#### 5. **Master CI/CD** (`master-ci-cd.yml`)
- **Trigger**: Changes to root configuration or manual dispatch
- **Stages**:
  - Master build and test (all applications)
  - Trigger individual workflows
  - Master security scan

### **Manual Deployment**
```bash
# Deploy infrastructure
npx nx run infrastructure:deploy

# Deploy applications
npx nx run backend:deploy
npx nx run frontend:deploy

# Deploy monitoring
npx nx run monitoring:deploy
```

## 🔒 **Security Features**

### **Infrastructure Security**
- VPC with private subnets
- Security groups with least privilege
- IAM roles with minimal permissions
- SSL/TLS encryption in transit
- Container image scanning

### **Application Security**
- JWT authentication
- Input validation
- CORS configuration
- Security headers
- Vulnerability scanning with Trivy

## 📊 **Monitoring & Observability**

### **Built-in Monitoring**
- **CloudWatch Dashboard** - Real-time metrics
- **Application Logs** - Centralized logging
- **EKS Cluster Metrics** - Performance monitoring
- **Custom Application Metrics** - Business metrics
- **SNS Notifications** - Alerting

### **Access Monitoring**
```bash
# Dashboard URL (output after deployment)
# https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=iAgent-Application-Dashboard

# View logs
npx nx run infrastructure:logs

# Monitor changes
npx nx run infrastructure:monitor
```

## 🎯 **Learning Objectives**

This project demonstrates:

### **DevOps Practices**
- Infrastructure as Code (IaC)
- Continuous Integration/Deployment (CI/CD)
- Containerization and orchestration
- Monitoring and observability
- Security best practices

### **AWS Services**
- EKS (Kubernetes)
- ECR (Container Registry)
- CloudWatch (Monitoring)
- VPC (Networking)
- IAM (Security)
- Route53 (DNS)
- ACM (Certificates)

### **Tools & Technologies**
- AWS CDK
- Kubernetes
- Docker
- GitHub Actions
- Nx monorepo
- TypeScript
- React & NestJS

## 🔄 **Future Enhancements**

### **Planned Features**
- [ ] Multi-region deployment
- [ ] Blue-green deployments
- [ ] Advanced monitoring (Prometheus/Grafana)
- [ ] Database integration (RDS/Aurora)
- [ ] CDN integration (CloudFront)
- [ ] Advanced security (WAF, GuardDuty)
- [ ] Cost optimization (Spot instances)
- [ ] Disaster recovery

### **Scalability Improvements**
- [ ] Auto-scaling policies
- [ ] Load balancing optimization
- [ ] Performance tuning
- [ ] Resource optimization

## 📚 **Resources**

### **Documentation**
- [Infrastructure Management Guide](docs/INFRASTRUCTURE_MANAGEMENT.md)
- [AWS Services Overview](docs/AWS_SERVICES_OVERVIEW.md)
- [DevOps Project Guide](docs/DEVOPS_PROJECT_GUIDE.md)
- [Project Summary](PROJECT_SUMMARY.md)

### **AWS Documentation**
- [AWS CDK](https://docs.aws.amazon.com/cdk/)
- [AWS EKS](https://docs.aws.amazon.com/eks/)
- [AWS ECR](https://docs.aws.amazon.com/ecr/)
- [AWS CloudWatch](https://docs.aws.amazon.com/cloudwatch/)

### **Tools Documentation**
- [Nx](https://nx.dev/)
- [Kubernetes](https://kubernetes.io/docs/)
- [Docker](https://docs.docker.com/)
- [GitHub Actions](https://docs.github.com/en/actions)

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `npx nx run-many -t test`
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This project is designed for educational purposes and demonstrates modern DevOps practices. All AWS services are managed through the infrastructure app for simplicity and consistency. 