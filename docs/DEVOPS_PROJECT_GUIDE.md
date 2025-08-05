# iAgent DevOps Project Guide

## Overview

This is a comprehensive DevOps project for the iAgent AI Chat Application, designed as a final project for a one-year DevOps program. The project demonstrates modern DevOps practices including Infrastructure as Code, CI/CD, containerization, and cloud-native deployment.

## Architecture

### Infrastructure Components

1. **AWS EKS Cluster** - Kubernetes cluster for running the backend API
2. **AWS ECR** - Container registry for Docker images
3. **GitHub Pages** - Static hosting for the frontend application
4. **CloudWatch** - Monitoring and observability
5. **Route53** - DNS management (optional)
6. **ACM** - SSL certificate management

### Application Components

1. **Frontend** - React application deployed to GitHub Pages
2. **Backend** - NestJS API deployed to EKS
3. **Infrastructure** - AWS CDK for infrastructure management
4. **CI/CD** - GitHub Actions for automated deployment
5. **Monitoring** - CloudWatch dashboards and alarms

## Prerequisites

### Required Tools

- Node.js 18+
- AWS CLI
- kubectl
- Docker
- Git

### AWS Setup

1. **Create AWS Account**
   ```bash
   aws configure
   ```

2. **Install AWS CDK**
   ```bash
   npm install -g aws-cdk
   ```

3. **Bootstrap CDK**
   ```bash
   cdk bootstrap aws://ACCOUNT-NUMBER/eu-central-1
   ```

### ⚠️ Important: AWS Region Selection

**Note**: This project is configured to use AWS region `eu-central-1` (Frankfurt, Germany) as it's the closest available region to Israel. AWS does not currently have a region located in Israel.

**Available regions near Israel:**
- `eu-central-1` (Frankfurt, Germany) - **Recommended** - Lowest latency to Israel
- `eu-west-1` (Ireland)
- `eu-west-2` (London, UK)
- `me-south-1` (Bahrain) - Middle East region

All AWS services used in this project (EKS, ECR, Route53, ACM, CloudWatch, SNS) are available in the European regions.

### GitHub Setup

1. **Repository Secrets**
   Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_ACCOUNT_ID`

2. **Enable GitHub Pages**
   - Go to repository settings
   - Enable GitHub Pages
   - Set source to GitHub Actions

## Project Structure

```
iAgent/
├── apps/
│   ├── frontend/           # React application
│   ├── backend/            # NestJS API
│   ├── infrastructure/     # AWS CDK infrastructure
│   ├── cicd/              # CI/CD automation
│   └── monitoring/        # Monitoring infrastructure
├── libs/                  # Shared libraries
├── .github/
│   └── workflows/         # GitHub Actions
├── docs/                  # Documentation
└── scripts/              # Deployment scripts
```

## Getting Started

### 1. Clone and Setup

```bash
git clone <repository-url>
cd iAgent
npm install
```

### 2. Deploy Infrastructure

```bash
# Deploy the main infrastructure
npx nx run infrastructure:deploy

# Deploy monitoring stack
npx nx run monitoring:deploy
```

### 3. Configure Kubernetes

```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name iagent-cluster

# Apply Kubernetes manifests
kubectl apply -f apps/infrastructure/src/k8s/namespace.yaml
kubectl apply -f apps/infrastructure/src/k8s/secrets.yaml
kubectl apply -f apps/infrastructure/src/k8s/backend-deployment.yaml
```

### 4. Deploy Applications

The applications will be automatically deployed via GitHub Actions when you push to the main branch.

## CI/CD Pipeline

### Pipeline Stages

1. **Build and Test**
   - Lint code
   - Run tests
   - Build applications

2. **Build Docker Images**
   - Build backend image
   - Build frontend image
   - Push to ECR

3. **Deploy to EKS**
   - Update Kubernetes manifests
   - Deploy backend to EKS

4. **Deploy to GitHub Pages**
   - Build frontend
   - Deploy to GitHub Pages

5. **Infrastructure Deployment**
   - Deploy/update AWS infrastructure

6. **Security Scan**
   - Run Trivy vulnerability scanner

### Manual Deployment

```bash
# Deploy infrastructure manually
npx nx run infrastructure:deploy

# Deploy applications manually
npx nx run cicd:deploy
```

## Monitoring and Observability

### CloudWatch Dashboard

Access the CloudWatch dashboard to monitor:
- EKS cluster metrics (CPU, Memory)
- Application metrics (Request count, Response time, Error rate)
- Application logs

### Alarms

The following alarms are configured:
- High CPU utilization (>80%)
- High memory utilization (>85%)
- High error rate (>5%)

### Logs

Application logs are stored in CloudWatch Log Groups:
- `/aws/eks/iagent/application`
- `/aws/eks/iagent/access`
- `/aws/eks/iagent/errors`

## Security

### Container Security

- Multi-stage Docker builds
- Non-root user execution
- Health checks
- Image scanning with Trivy

### Infrastructure Security

- VPC with private subnets
- Security groups
- IAM roles with least privilege
- SSL/TLS encryption

### Application Security

- JWT authentication
- Input validation
- CORS configuration
- Security headers

## Cost Optimization

### Recommendations

1. **Use Spot Instances** for EKS node groups
2. **Enable Cluster Autoscaler** for automatic scaling
3. **Set up cost alerts** in AWS Billing
4. **Use S3 lifecycle policies** for log retention
5. **Monitor resource usage** regularly

### Estimated Costs

- EKS Cluster: ~$50-100/month
- ECR Storage: ~$5-10/month
- CloudWatch: ~$10-20/month
- Route53: ~$1/month (if using custom domain)

## Troubleshooting

### Common Issues

1. **CDK Bootstrap Error**
   ```bash
   cdk bootstrap aws://ACCOUNT-NUMBER/REGION
   ```

2. **EKS Access Denied**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name iagent-cluster
   ```

3. **Docker Build Failures**
   - Check Dockerfile syntax
   - Verify build context
   - Check ECR permissions

4. **Kubernetes Deployment Issues**
   ```bash
   kubectl describe pod <pod-name> -n iagent
   kubectl logs <pod-name> -n iagent
   ```

### Debug Commands

```bash
# Check EKS cluster status
aws eks describe-cluster --name iagent-cluster --region eu-central-1

# Check ECR repositories
aws ecr describe-repositories --region eu-central-1

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/iagent

# Check EKS node groups
aws eks list-nodegroups --cluster-name iagent-cluster --region eu-central-1
```

## Best Practices

### Infrastructure

1. **Use Infrastructure as Code** (CDK)
2. **Implement proper tagging** for cost tracking
3. **Use separate environments** (dev, staging, prod)
4. **Implement backup strategies**
5. **Monitor resource limits**

### CI/CD

1. **Use semantic versioning**
2. **Implement proper testing** at each stage
3. **Use feature branches** and pull requests
4. **Implement rollback strategies**
5. **Monitor deployment metrics**

### Security

1. **Regular security updates**
2. **Implement least privilege access**
3. **Use secrets management**
4. **Regular security scans**
5. **Monitor access logs**

## Future Enhancements

### Planned Features

1. **Multi-region deployment**
2. **Blue-green deployments**
3. **Advanced monitoring** (Prometheus, Grafana)
4. **Service mesh** (Istio)
5. **Database migration** strategies
6. **Performance testing** automation
7. **Disaster recovery** procedures

### Scalability Improvements

1. **Horizontal Pod Autoscaling**
2. **Vertical Pod Autoscaling**
3. **Database scaling** strategies
4. **CDN integration**
5. **Load balancing** optimization

## Support and Resources

### Documentation

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [EKS Best Practices](https://aws.amazon.com/eks/resources/best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Tools

- [AWS CLI](https://aws.amazon.com/cli/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/)
- [Trivy](https://aquasecurity.github.io/trivy/)

## Conclusion

This DevOps project demonstrates modern cloud-native practices and provides a solid foundation for scalable, maintainable applications. The infrastructure is designed to be secure, cost-effective, and easily manageable through Infrastructure as Code principles.

For questions or issues, please refer to the troubleshooting section or create an issue in the repository. 