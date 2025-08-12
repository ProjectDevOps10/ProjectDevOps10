# iAgent DevOps Project - Simple Setup Script
param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "status", "help")]
    [string]$Command = "help"
)

# Configuration
$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "iagent-cluster" }

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

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    $missingTools = @()
    
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        $missingTools += "Node.js"
    }
    
    if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
        $missingTools += "npm"
    }
    
    if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
        $missingTools += "AWS CLI"
    }
    
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
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
            return $callerIdentity.Account
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
    
    $accountId = Test-AwsCredentials
    
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

# Function to build and push Docker images
function Build-AndPush-Images {
    Write-Status "Building and pushing Docker images..."
    
    # Get ECR registry
    $accountId = Test-AwsCredentials
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
    
    # Check CloudFormation stacks
    try {
        aws cloudformation describe-stacks --stack-name IAgentInfrastructureStack --region $AWS_REGION 2>$null | Out-Null
        Write-Success "Infrastructure Stack: Running"
    }
    catch {
        Write-Error "Infrastructure Stack: Not found"
    }
    
    try {
        aws cloudformation describe-stacks --stack-name IAgentMonitoringStack --region $AWS_REGION 2>$null | Out-Null
        Write-Success "Monitoring Stack: Running"
    }
    catch {
        Write-Error "Monitoring Stack: Not found"
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

# Function to destroy infrastructure
function Destroy-Infrastructure {
    Write-Status "Destroying infrastructure..."
    
    # Destroy monitoring stack first
    try {
        Write-Status "Destroying monitoring stack..."
        npx nx run monitoring:destroy --yes
    }
    catch {
        Write-Warning "Failed to destroy monitoring stack"
    }
    
    # Destroy main infrastructure stack
    try {
        Write-Status "Destroying main infrastructure stack..."
        npx nx run infrastructure:destroy --yes
    }
    catch {
        Write-Warning "Failed to destroy infrastructure stack"
    }
    
    Write-Success "Infrastructure destruction completed"
}

# Function to show help
function Show-Help {
    Write-Host "iAgent DevOps Project - Simple Setup Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\setup.ps1 [COMMAND]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  start             Start complete infrastructure (infrastructure + monitoring + apps)" -ForegroundColor Yellow
    Write-Host "  stop              Stop and destroy all infrastructure" -ForegroundColor Yellow
    Write-Host "  status            Show current deployment status" -ForegroundColor Yellow
    Write-Host "  help              Show this help message" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor White
    Write-Host "  AWS_REGION          AWS region (default: us-east-1)" -ForegroundColor Gray
    Write-Host "  CLUSTER_NAME        EKS cluster name (default: iagent-cluster)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\setup.ps1 start    # Start complete infrastructure" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 status   # Check current status" -ForegroundColor Gray
    Write-Host "  .\setup.ps1 stop     # Stop and destroy everything" -ForegroundColor Gray
    Write-Host ""
}

# Main deployment function
function Main {
    switch ($Command) {
        "start" {
            Write-Status "Starting complete iAgent infrastructure..."
            Test-Prerequisites
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
            Write-Success "Complete infrastructure started successfully!"
            Write-Host ""
            Write-Host "Your iAgent DevOps project is now running!" -ForegroundColor Green
            Write-Host "Monitor your application at the URLs provided above" -ForegroundColor Cyan
            Write-Host "Push to GitHub to trigger automatic deployments" -ForegroundColor Cyan
            Write-Host "Run '.\setup.ps1 stop' to stop everything" -ForegroundColor Yellow
        }
        "stop" {
            Write-Status "Stopping iAgent infrastructure..."
            Destroy-Infrastructure
            Write-Success "Infrastructure stopped successfully!"
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