# 🤖 iAgent - AI Chat Application

[![Made with Nx](https://img.shields.io/badge/Made%20with-Nx-blue)](https://nx.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![React](https://img.shields.io/badge/React-20232A?logo=react&logoColor=61DAFB)](https://reactjs.org/)
[![Material-UI](https://img.shields.io/badge/Material--UI-0081CB?logo=material-ui&logoColor=white)](https://mui.com/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![NestJS](https://img.shields.io/badge/NestJS-E0234E?logo=nestjs&logoColor=white)](https://nestjs.com/)

A modern, full-stack AI chat application built with React, NestJS, and TypeScript in an Nx monorepo. Features real-time streaming, multi-language support, and a beautiful Material-UI interface.

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

## 🔄 CI/CD Pipeline - Temporary Setup (Build → Deploy → Clean Up)

### 🎯 **Your 3-Phase CI/CD Workflow:**

**Phase 1: 🚀 Setup & Deploy**
- Setup AWS environment and roles
- Deploy infrastructure to AWS
- Enable CI/CD workflows
- Frontend deploys to GitHub Pages
- Backend deploys to EKS

**Phase 2: 🔄 Development & CI/CD**
- Make changes and push to main
- GitHub Actions automatically:
  - Build and test your code
  - Deploy frontend to GitHub Pages
  - Deploy backend to EKS
  - Update infrastructure if needed

**Phase 3: 🧹 Complete Cleanup**
- Disable all GitHub Actions workflows
- Delete all AWS services and infrastructure
- Remove GitHub Pages deployment
- **Result: Zero charges, clean slate**

### Workflow Overview
- **ACTIVE Workflows** (for your temporary deployment):
  - `ci-cd.yml` - Main build and deployment pipeline
  - `frontend-ci-cd.yml` - Frontend build and GitHub Pages deployment
  - `backend-ci-cd.yml` - Backend build and EKS deployment
  - `infrastructure-ci-cd.yml` - AWS infrastructure deployment

- **DISABLED Workflows** (commented out to simplify setup):
  - `master-ci-cd.yml` - Orchestrates all workflows (disabled)
  - `monitoring-ci-cd.yml` - Monitoring and observability services (disabled)

### 🚀 **Complete CI/CD Workflow (3 Steps):**

#### **Step 1: Environment Setup & AWS Configuration**
```bash
# 1. Setup AWS environment
./setup-aws-environment.sh

# 2. Add GitHub repository secrets:
#    Go to: Settings → Secrets and variables → Actions
#    Add: AWS_ACCOUNT_ID, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

# 3. Verify setup
aws sts get-caller-identity
```

#### **Step 2: Trigger CI/CD Pipeline**
```bash
# Push changes to trigger all workflows
git add .
git commit -m "Trigger CI/CD pipeline"
git push origin main

# What happens automatically:
# ✅ Infrastructure deploys to AWS (EKS, ECR, VPC, etc.)
# ✅ Backend builds and deploys to EKS
# ✅ Frontend builds and deploys to GitHub Pages
# ✅ All services become available online
```

#### **Step 3: Cleanup & Teardown (When Done)**
```bash
# 1. Disable all GitHub Actions workflows
#    Comment out all workflow files in .github/workflows/

# 2. Delete AWS infrastructure
./teardown-infrastructure.sh

# 3. Remove GitHub Pages deployment
#    Go to: Settings → Pages → Source → None

# 4. Result: Zero charges, clean slate
```

### Local Testing
```bash
# Test workflows locally before pushing
act -W .github/workflows/frontend-ci-cd.yml --job build-and-test --dryrun --bind
act -W .github/workflows/backend-ci-cd.yml --job build-and-test --dryrun --bind
act -W .github/workflows/infrastructure-ci-cd.yml --job build-and-test --dryrun --bind
```

### Re-enabling Optional Workflows
If you need the master orchestration or monitoring workflows:
1. Uncomment the desired workflow file in `.github/workflows/`
2. Remove the `# DISABLED:` comments
3. The workflow will automatically become active again

### 🔧 **Quick Commands Reference:**

#### **Setup & Deploy:**
```bash
# Complete setup and deployment
./setup-aws-environment.sh                    # Setup AWS
git push origin main                          # Trigger CI/CD
# Wait for completion, then access your deployed services
```

#### **Cleanup & Teardown:**
```bash
# Complete cleanup (when done testing)
./teardown-infrastructure.sh                  # Delete AWS resources
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
./teardown-infrastructure.sh

# 2. Disable GitHub Actions workflows
#    Comment out all files in .github/workflows/

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
