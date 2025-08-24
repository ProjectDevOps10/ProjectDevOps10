# 🤖 iAgent - AI Chat Application

[![Made with Nx](https://img.shields.io/badge/Made%20with-Nx-blue)](https://nx.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)

[![React](https://img.shields.io/badge/React-20232A?logo=react&logoColor=61DAFB)](https://reactjs.org/)
[![Material-UI](https://img.shields.io/badge/Material--UI-0081CB?logo=material-ui&logoColor=white)](https://mui.com/)

[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)

[![NestJS](https://img.shields.io/badge/NestJS-E0234E?logo=nestjs&logoColor=white)](https://nestjs.com/)

A modern, full-stack AI chat application built with React, NestJS, and TypeScript in an Nx monorepo. Features real-time streaming, multi-language support, and a beautiful Material-UI interface.

## 🎯 **Main Project Goal - Study DevOps Workflow**

This project demonstrates a **complete DevOps workflow** for learning purposes with a **3-step process**:

1. **🚀 SETUP & DEPLOY** - Deploy infrastructure and applications to AWS
2. **🔄 DEVELOP & TRIGGER** - Make changes and let CI/CD automatically deploy
3. **🧹 DESTROY & CLEANUP** - Remove all AWS resources to avoid charges

**Perfect for:** Learning AWS, Kubernetes, CI/CD, and infrastructure-as-code without ongoing costs.

**Key Benefits:**
- ✅ **Zero ongoing charges** - Everything gets destroyed when done
- ✅ **Complete DevOps experience** - From local development to production deployment
- ✅ **Real AWS services** - EKS, ECR, VPC, GitHub Actions, GitHub Pages
- ✅ **Automated cleanup** - Scripts to remove all resources
- ✅ **Study project ready** - Clean slate for next learning session

## ✨ Features

- 🔄 **Real-time Streaming** - Live AI response streaming with Server-Sent Events
- 🌍 **Multi-language Support** - English, Hebrew, Arabic with RTL/LTR support
- 🎨 **Modern UI** - Beautiful Material-UI components with dark/light themes
- 📱 **Mobile Responsive** - Optimized for all screen sizes
- 🛡️ **Type Safe** - Full TypeScript implementation
- 📚 **API Documentation** - Comprehensive Swagger/OpenAPI docs
- 🎯 **Mock Mode** - Built-in mock responses for development
- 💾 **Persistent Storage** - Conversation history and preferences

## 🏗️ Architecture

```
iAgent/
├── apps/
│   ├── frontend/          # React application with Material-UI
│   └── backend/           # NestJS API server
├── libs/                  # Shared libraries (future)
├── docs/                  # Documentation
└── scripts/               # Build and deployment scripts
```

## 🚀 Quick Start

### Prerequisites

- Node.js >= 18.0.0
- npm >= 8.0.0
- Docker (for containerized development)
- AWS CLI (for infrastructure deployment)

### Installation & Development

```bash
# Clone the repository
git clone https://github.com/your-username/iAgent.git
cd iAgent

# Install dependencies
npm install

# Start the frontend (React app with Vite)
npx nx serve @iagent/frontend
# The app will be available at: http://localhost:4200/iAgent/

# Start the backend (NestJS API)
npx nx serve @iagent/backend
# The API will be available at: http://localhost:3000

# Or use npm scripts if available
npm run dev:frontend  # Alternative command
npm run dev:backend   # Alternative command
```

### Available Scripts

```bash
# Development (using Nx)
npx nx serve @iagent/frontend   # Start React app at http://localhost:4200/iAgent/
npx nx serve @iagent/backend    # Start NestJS API at http://localhost:3000

# Building (using Nx)
npx nx build @iagent/frontend   # Build React app
npx nx build @iagent/backend    # Build NestJS API
npx nx run-many -t build        # Build all projects

# Testing (using Nx)
npx nx test @iagent/frontend    # Test React app
npx nx test @iagent/backend     # Test NestJS API
npx nx run-many -t test         # Test all projects

# Linting (using Nx)
npx nx lint @iagent/frontend    # Lint React app
npx nx lint @iagent/backend     # Lint NestJS API
npx nx run-many -t lint         # Lint all projects

# Utilities
npx nx graph                    # View dependency graph
npx nx reset                    # Reset Nx cache
npx nx affected:build           # Build affected projects
npx nx affected:test            # Test affected projects

# Legacy npm scripts (if configured)
npm run dev:frontend     # Alternative to npx nx serve @iagent/frontend
npm run dev:backend      # Alternative to npx nx serve @iagent/backend
```

## 🐳 Development Container Setup

### Option 1: VS Code Dev Container (Recommended)
```bash
# 1. Open in VS Code
# 2. Install "Dev Containers" extension
# 3. When prompted, click "Reopen in Container"
# 4. Wait for container to build (includes all tools)
```

### Option 2: Manual Setup
```bash
# Install required tools
npm install -g aws-cdk
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Setup GitHub Actions local testing
./.devcontainer/setup-github-actions.sh
```

## 📋 **GitHub Actions Workflows**

| Workflow | Purpose |
|----------|---------|
| `master.yml` | **Main orchestrator** - Runs on main branch, quick tests and build checks |
| `development.yml` | **Development workflow** - Runs on develop/feature branches, full testing and linting |
| `simple-cicd.yml` | **Complete CI/CD pipeline** - Full deployment pipeline for the entire project |
| `frontend-deploy.yml` | **Frontend deployment** - Deploys frontend to GitHub Pages |
| `infrastructure.yml` | **Infrastructure management** - AWS infrastructure deployment and management |
| `cleanup.yml` | **Cleanup workflow** - Removes AWS resources when done |

**Note:** These are the original working workflows that have been running successfully for weeks. They're designed for study purposes and can be disabled when you're done learning.

## 🔄 **Complete DevOps Workflow (Study Project Setup)**

### 🎯 **Your 3-Phase CI/CD Workflow:**

**Phase 1: 🚀 Setup AWS Infrastructure (IaC)**
- Deploy AWS hosting support: ECR (Docker registry), EKS (Kubernetes), VPC (networking)
- Configure IAM roles and permissions for CI/CD access
- **Result**: AWS environment ready to host your applications

**Phase 2: 🔄 Development & CI/CD**
- Make code changes and push to GitHub
- GitHub Actions automatically:
  - Build Docker images and push to ECR
  - Deploy frontend to GitHub Pages
  - Deploy backend to EKS cluster
- **Result**: Applications running on AWS infrastructure

**Phase 3: 🧹 Complete Cleanup**
- Disable all GitHub Actions workflows
- Delete all AWS infrastructure with CDK
- Remove GitHub Pages deployment
- **Result**: Zero charges, clean slate

### 🚀 **Complete CI/CD Workflow (3 Steps):**

#### **Step 1: Deploy AWS Infrastructure**
```bash
# 1. Deploy AWS hosting support
cd apps/infrastructure
export $(cat ../../.secrets | grep -v '^#' | xargs)
cdk deploy --all --require-approval never

# What gets created:
# ✅ ECR repositories (Docker registry)
# ✅ EKS cluster (Kubernetes for backend)
# ✅ VPC with networking
# ✅ IAM roles for CI/CD access
```

#### **Step 2: Configure GitHub Actions & Deploy**
```bash
# 1. Add GitHub repository secrets:
#    Go to: Settings → Secrets and variables → Actions
#    Add: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

# 2. Push changes to trigger CI/CD
git add .
git commit -m "Trigger CI/CD pipeline"
git push origin main

# What happens automatically:
# ✅ Frontend builds and deploys to GitHub Pages
# ✅ Backend builds, pushes to ECR, deploys to EKS
# ✅ All using the AWS infrastructure created in Step 1
```

#### **Step 3: Cleanup When Done**
```bash
# 1. Disable GitHub Actions workflows
#    Comment out all .github/workflows/*.yml files

# 2. Delete AWS infrastructure
./cleanup-aws.sh

# 3. Remove GitHub Pages deployment
#    Go to: Settings → Pages → Source → None

# 4. Result: Zero charges, clean slate
```

### 🔧 **What Gets Deployed**

### **AWS Infrastructure (CDK) - Hosting Support Only**
- **VPC**: Simple networking with public/private subnets and NAT gateway
- **ECR Repositories**: Docker registry for backend and frontend images
- **EKS Cluster**: Minimal Kubernetes cluster for backend hosting
- **IAM Roles**: Proper permissions for CI/CD to access AWS services

### **Applications (GitHub Actions)**
- **Frontend**: Deployed to GitHub Pages via GitHub Actions
- **Backend**: Built, pushed to ECR, deployed to EKS via GitHub Actions
- **CI/CD**: Uses the AWS infrastructure created by CDK

### 🔧 **Quick Commands Reference:**

#### **Setup & Deploy:**
```bash
# 1. Deploy AWS infrastructure
cd apps/infrastructure
export $(cat ../../.secrets | grep -v '^#' | xargs)
cdk deploy --all --require-approval never

# 2. Trigger CI/CD (after adding GitHub secrets)
git push origin main

# Result: Applications running on AWS infrastructure
```

#### **Cleanup & Teardown:**
```bash
# Complete cleanup (when done testing)
./cleanup-aws.sh                              # Delete AWS resources
# Comment out all .github/workflows/*.yml files
# Disable GitHub Pages in repository settings
# Result: Zero charges, clean slate
```

### 📊 **Monitor Your Deployment:**
- **GitHub Actions:** Check workflow progress in Actions tab
- **Frontend:** Available at your GitHub Pages URL
- **Backend:** Available at your EKS cluster endpoint
- **AWS Console:** Monitor resources in AWS console

### Required GitHub Secrets
| Secret | Description | How to get |
|--------|-------------|------------|
| `AWS_ACCOUNT_ID` | Your AWS account ID | `aws sts get-caller-identity --query Account --output text` |
| `AWS_ACCESS_KEY_ID` | AWS access key | `aws configure get aws_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `aws configure get aws_secret_access_key` |

## 🛠️ Tech Stack

### Frontend
- **React 19** - Latest React with concurrent features
- **TypeScript** - Type-safe development
- **Material-UI v7** - Modern Material Design components
- **Vite** - Fast build tool and dev server
- **React Markdown** - Markdown rendering with syntax highlighting

### Backend
- **NestJS 11** - Progressive Node.js framework
- **TypeScript** - Type-safe server development
- **Express** - Fast, unopinionated web framework
- **Swagger/OpenAPI** - API documentation and testing
- **Server-Sent Events** - Real-time streaming

### Development Tools
- **Nx** - Monorepo management and build system
- **ESLint** - Code linting and formatting
- **Jest** - Testing framework
- **Prettier** - Code formatting

## 📱 Applications

### [Frontend](./apps/frontend/README.md)
React-based chat interface with Material-UI components, real-time streaming, and multi-language support.

**Key Features:**
- Real-time message streaming
- Dark/light theme switching
- Mobile-responsive design
- Conversation management
- Message actions (copy, edit, regenerate)

### [Backend](./apps/backend/README.md)
NestJS API server providing chat functionality with comprehensive documentation and streaming support.

**Key Features:**
- RESTful API with Swagger docs
- Server-Sent Events streaming
- Request validation and error handling
- Mock responses for development
- CORS and security configuration

## 🌐 API Documentation

When running the backend, comprehensive API documentation is available at:
- **Swagger UI**: http://localhost:3000/api/docs
- **API Base**: http://localhost:3000/api

## 🔧 Configuration

### Environment Variables

Create `.env` files in the respective app directories:

**Frontend** (`apps/frontend/.env`):
```bash
VITE_API_BASE_URL=http://localhost:3000
VITE_MOCK_MODE=false
```

**Backend** (`apps/backend/.env`):
```bash
PORT=3000
NODE_ENV=development
CORS_ORIGIN=http://localhost:4200
```

## 🚀 Deployment

### Production Build
```bash
# Build both applications
npm run build

# Files will be in:
# - dist/apps/frontend/  (Static files for hosting)
# - dist/apps/backend/   (Node.js server files)
```

### Docker Support
```bash
# Build Docker images (when Dockerfiles are added)
docker build -t iAgent-frontend ./apps/frontend
docker build -t iAgent-backend ./apps/backend
```

## 🧪 Testing

```bash
# Run all tests
npm run test

# Run tests with coverage
npm run test -- --coverage

# Run e2e tests
npm run e2e
```

## 📊 Nx Workspace

This project uses Nx for monorepo management:

```bash
# View project graph
npm run graph

# Run affected tests only
npx nx affected:test

# Build affected projects only
npx nx affected:build

# Generate new library
npx nx g @nx/react:lib my-lib

# Generate new application
npx nx g @nx/react:app my-app
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** following the existing code style
4. **Add tests** for new functionality
5. **Run tests**: `npm run test`
6. **Commit changes**: `git commit -m 'Add amazing feature'`
7. **Push to branch**: `git push origin feature/amazing-feature`
8. **Open a Pull Request**

### Development Guidelines

- Follow TypeScript strict mode
- Add tests for new features
- Update documentation as needed
- Use conventional commit messages
- Ensure all linting passes

## 📄 License

MIT License - see the [LICENSE](LICENSE) file for details.

## 🧹 **Cleanup & Teardown Scripts**

### **Complete Cleanup Process:**

When you're done testing your CI/CD pipeline, use these scripts to clean up everything:

```bash
# 1. Delete all AWS infrastructure (prevents charges)
./cleanup-aws.sh

# 2. Disable GitHub Actions workflows
#    Comment out all workflow files in .github/workflows/

# 3. Remove GitHub Pages deployment
#    Go to: Settings → Pages → Source → None

# 4. Verify cleanup
aws sts get-caller-identity  # Should still work
aws eks list-clusters        # Should show no clusters
aws ecr describe-repositories  # Should show no repos
```

### **What Gets Cleaned Up:**
- ✅ **EKS Cluster** - Kubernetes cluster
- ✅ **ECR Repositories** - Docker image storage
- ✅ **VPC & Subnets** - Network infrastructure
- ✅ **Security Groups** - Firewall rules
- ✅ **IAM Roles** - AWS permissions
- ✅ **CloudWatch Logs** - Application logs
- ✅ **GitHub Pages** - Frontend hosting
- ✅ **GitHub Actions** - CI/CD workflows

### **Result:**
🎯 **Zero AWS charges, clean GitHub repository, ready for next project!**

## 🔗 Links

- [Frontend Documentation](./apps/frontend/README.md)
- [Backend Documentation](./apps/backend/README.md)
- [API Documentation](http://localhost:3000/api/docs) (when running)
- [Nx Documentation](https://nx.dev)

---

**Built with ❤️ using React, NestJS, and Nx**

> **Remember**: Always clean up AWS resources when you're done to avoid unexpected charges!
# Deploy backend to EKS
