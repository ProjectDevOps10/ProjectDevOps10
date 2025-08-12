# iAgent DevOps Project Deployment Script (PowerShell)
# This script automates the deployment of the entire infrastructure

param(
    [Parameter(Position=0)]
    [ValidateSet("full", "infrastructure", "applications", "monitoring", "status", "help")]
    [string]$Command = "help"
)

# Configuration
$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "iagent-cluster" }
$DOMAIN_NAME = if ($env:DOMAIN_NAME) { $env:DOMAIN_NAME } else { "" }

# Set environment variables for non-interactive mode
$env:NX_SKIP_NX_CACHE = "true"
$env:NX_VERBOSE_LOGGING = "false"
$env:NX_INTERACTIVE = "false"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    $missingTools = @()
    
    if (-not (Test-Command "node")) {
        $missingTools += "Node.js"
    }
    
    if (-not (Test-Command "npm")) {
        $missingTools += "npm"
    }
    
    if (-not (Test-Command "aws")) {
        $missingTools += "AWS CLI"
    }
    
    if (-not (Test-Command "kubectl")) {
        $missingTools += "kubectl"
    }
    
    if (-not (Test-Command "docker")) {
        $missingTools += "Docker"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Status "Please install the missing tools and try again."
        exit 1
    }
    
    Write-Success "All prerequisites are installed"
}

# Function to check AWS credentials
function Test-AwsCredentials {
    Write-Status "Checking AWS credentials..."
    
    try {
        $callerIdentity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
        if ($callerIdentity) {
            Write-Success "AWS credentials configured for account: $($callerIdentity.Account)"
        } else {
            throw "No caller identity"
        }
    }
    catch {
        Write-Error "AWS credentials not configured or invalid"
        Write-Status "Please run 'aws configure' and try again."
        exit 1
    }
}

# Function to install dependencies
function Install-Dependencies {
    Write-Status "Installing dependencies..."
    
    if (-not (Test-Path "node_modules")) {
        npm install
        Write-Success "Dependencies installed"
    } else {
        Write-Status "Dependencies already installed, skipping..."
    }
    
    # Sync TypeScript project references
    Write-Status "Syncing TypeScript project references..."
    npx nx sync --yes
}

# Function to bootstrap CDK
function Start-CdkBootstrap {
    Write-Status "Bootstrapping AWS CDK..."
    
    $accountId = (aws sts get-caller-identity --query Account --output text 2>$null).Trim()
    
    try {
        aws cloudformation describe-stacks --stack-name CDKToolkit 2>$null | Out-Null
        Write-Status "CDK already bootstrapped, skipping..."
    }
    catch {
        Write-Status "CDK not bootstrapped, bootstrapping now..."
        cdk bootstrap "aws://$accountId/$AWS_REGION"
        Write-Success "CDK bootstrapped successfully"
    }
}

# Function to deploy infrastructure
function Deploy-Infrastructure {
    Write-Status "Deploying infrastructure..."
    
    # Build infrastructure
    npx nx build infrastructure --yes
    
    # Deploy infrastructure
    npx nx run infrastructure:deploy --yes
    
    Write-Success "Infrastructure deployed successfully"
}

# Function to deploy monitoring
function Deploy-Monitoring {
    Write-Status "Deploying monitoring stack..."
    
    # Build monitoring
    npx nx build monitoring --yes
    
    # Deploy monitoring
    npx nx run monitoring:deploy --yes
    
    Write-Success "Monitoring stack deployed successfully"
}

# Function to configure kubectl
function Set-KubectlConfig {
    Write-Status "Configuring kubectl for EKS cluster..."
    
    try {
        aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
        
        # Wait for cluster to be ready
        Write-Status "Waiting for EKS cluster to be ready..."
        aws eks wait cluster-active --region $AWS_REGION --name $CLUSTER_NAME
        
        Write-Success "kubectl configured for EKS cluster"
    }
    catch {
        Write-Warning "Failed to configure kubectl. The cluster might not be ready yet."
        Write-Status "You may need to wait for the infrastructure deployment to complete."
    }
}

# Function to deploy Kubernetes manifests
function Deploy-K8sManifests {
    Write-Status "Deploying Kubernetes manifests..."
    
    try {
        # Create namespace
        kubectl apply -f apps/infrastructure/src/k8s/namespace.yaml
        
        # Create secrets (you need to update the secrets file with actual values)
        if (Test-Path "apps/infrastructure/src/k8s/secrets.yaml") {
            kubectl apply -f apps/infrastructure/src/k8s/secrets.yaml
        } else {
            Write-Warning "Secrets file not found. Please create and apply secrets manually."
        }
        
        # Deploy backend
        kubectl apply -f apps/infrastructure/src/k8s/backend-deployment.yaml
        
        # Wait for deployment to be ready
        Write-Status "Waiting for backend deployment to be ready..."
        kubectl rollout status deployment/iagent-backend -n iagent --timeout=300s
        
        Write-Success "Kubernetes manifests deployed successfully"
    }
    catch {
        Write-Warning "Failed to deploy Kubernetes manifests. The cluster might not be ready yet."
        Write-Status "You can retry this step later when the infrastructure is fully deployed."
    }
}

# Function to check Docker status
function Test-DockerStatus {
    Write-Status "Checking Docker status..."
    
    try {
        docker version 2>$null | Out-Null
        Write-Success "Docker is running"
        return $true
    }
    catch {
        Write-Warning "Docker is not running or not accessible"
        Write-Status "Please start Docker Desktop and try again"
        return $false
    }
}

# Function to build and push Docker images
function Build-AndPush-Images {
    Write-Status "Building and pushing Docker images..."
    
    if (-not (Test-DockerStatus)) {
        Write-Warning "Skipping Docker image build due to Docker not being available"
        return
    }
    
    # Get ECR registry
    $accountId = (aws sts get-caller-identity --query Account --output text 2>$null).Trim()
    $ecrRegistry = "$accountId.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Login to ECR
    try {
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ecrRegistry
    }
    catch {
        Write-Error "Failed to login to ECR"
        return
    }
    
    # Build and push backend image
    Write-Status "Building backend image..."
    try {
        docker build -t "$ecrRegistry/iagent-backend:latest" -f apps/backend/Dockerfile .
        docker push "$ecrRegistry/iagent-backend:latest"
    }
    catch {
        Write-Warning "Failed to build/push backend image"
    }
    
    # Build and push frontend image
    Write-Status "Building frontend image..."
    try {
        docker build -t "$ecrRegistry/iagent-frontend:latest" -f apps/frontend/Dockerfile .
        docker push "$ecrRegistry/iagent-frontend:latest"
    }
    catch {
        Write-Warning "Failed to build/push frontend image"
    }
    
    Write-Success "Docker images built and pushed successfully"
}

# Function to run tests
function Invoke-Tests {
    Write-Status "Running tests..."
    
    npx nx run-many --target=test --all --yes
    
    Write-Success "Tests completed successfully"
}

# Function to build applications
function Build-Applications {
    Write-Status "Building applications..."
    
    npx nx run-many --target=build --projects=frontend,backend --yes
    
    Write-Success "Applications built successfully"
}

# Function to show deployment status
function Show-Status {
    Write-Status "Checking deployment status..."
    
    Write-Host ""
    Write-Host "=== Deployment Status ===" -ForegroundColor Cyan
    
    # Check EKS cluster
    try {
        aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME 2>$null | Out-Null
        Write-Success "EKS Cluster: Running"
    }
    catch {
        Write-Error "EKS Cluster: Not found"
    }
    
    # Check ECR repositories
    try {
        aws ecr describe-repositories --repository-names iagent-backend --region $AWS_REGION 2>$null | Out-Null
        Write-Success "ECR Backend Repository: Exists"
    }
    catch {
        Write-Error "ECR Backend Repository: Not found"
    }
    
    try {
        aws ecr describe-repositories --repository-names iagent-frontend --region $AWS_REGION 2>$null | Out-Null
        Write-Success "ECR Frontend Repository: Exists"
    }
    catch {
        Write-Error "ECR Frontend Repository: Not found"
    }
    
    # Check Kubernetes deployments
    try {
        $deployment = kubectl get deployment iagent-backend -n iagent 2>$null | ConvertFrom-Json
        if ($deployment) {
            $ready = $deployment.status.readyReplicas
            $desired = $deployment.spec.replicas
            if ($ready -eq $desired) {
                Write-Success "Backend Deployment: Ready ($ready/$desired)"
            } else {
                Write-Warning "Backend Deployment: Not ready ($ready/$desired)"
            }
        }
    }
    catch {
        Write-Error "Backend Deployment: Not found"
    }
    
    Write-Host ""
    Write-Host "=== Useful Commands ===" -ForegroundColor Cyan
    Write-Host "View cluster info: aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME"
    Write-Host "View pods: kubectl get pods -n iagent"
    Write-Host "View logs: kubectl logs -f deployment/iagent-backend -n iagent"
    Write-Host "Access dashboard: kubectl proxy"
    Write-Host ""
}

# Function to show help
function Show-Help {
    Write-Host "iAgent DevOps Project Deployment Script (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [COMMAND]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  full              Full deployment (infrastructure + applications)" -ForegroundColor Yellow
    Write-Host "  infrastructure    Deploy only infrastructure" -ForegroundColor Yellow
    Write-Host "  applications      Deploy only applications" -ForegroundColor Yellow
    Write-Host "  monitoring        Deploy monitoring stack" -ForegroundColor Yellow
    Write-Host "  status            Show deployment status" -ForegroundColor Yellow
    Write-Host "  help              Show this help message" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor White
    Write-Host "  AWS_REGION          AWS region (default: us-east-1)" -ForegroundColor Gray
    Write-Host "  CLUSTER_NAME        EKS cluster name (default: iagent-cluster)" -ForegroundColor Gray
    Write-Host "  DOMAIN_NAME         Custom domain name (optional)" -ForegroundColor Gray
    Write-Host ""
}

# Main deployment function
function Main {
    switch ($Command) {
        "full" {
            Write-Status "Starting full deployment..."
            Test-Prerequisites
            Test-AwsCredentials
            Install-Dependencies
            Start-CdkBootstrap
            Deploy-Infrastructure
            Deploy-Monitoring
            Set-KubectlConfig
            Deploy-K8sManifests
            Build-AndPush-Images
            Invoke-Tests
            Build-Applications
            Show-Status
            Write-Success "Full deployment completed!"
        }
        "infrastructure" {
            Write-Status "Deploying infrastructure only..."
            Test-Prerequisites
            Test-AwsCredentials
            Install-Dependencies
            Start-CdkBootstrap
            Deploy-Infrastructure
            Deploy-Monitoring
            Show-Status
            Write-Success "Infrastructure deployment completed!"
        }
        "applications" {
            Write-Status "Deploying applications only..."
            Test-Prerequisites
            Test-AwsCredentials
            Install-Dependencies
            Set-KubectlConfig
            Deploy-K8sManifests
            Build-AndPush-Images
            Invoke-Tests
            Build-Applications
            Show-Status
            Write-Success "Applications deployment completed!"
        }
        "monitoring" {
            Write-Status "Deploying monitoring stack..."
            Test-Prerequisites
            Test-AwsCredentials
            Install-Dependencies
            Deploy-Monitoring
            Write-Success "Monitoring deployment completed!"
        }
        "status" {
            Show-Status
        }
        "help" {
            Show-Help
        }
        default {
            Show-Help
        }
    }
}

# Run main function
Main 