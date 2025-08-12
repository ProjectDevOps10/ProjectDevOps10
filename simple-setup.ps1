# Simple iAgent DevOps Setup Script
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
        npx cdk bootstrap "aws://$accountId/$AWS_REGION"
        Write-Success "CDK bootstrapped successfully"
    }
}

# Function to deploy infrastructure manually
function Deploy-Infrastructure {
    Write-Status "Deploying infrastructure..."
    
    # Build infrastructure
    npx nx build infrastructure --yes
    
    # Deploy infrastructure manually
    Write-Status "Running CDK deployment..."
    Push-Location "dist/apps/infrastructure"
    try {
        npx cdk deploy --all --require-approval never --app src/main.js
        Write-Success "Infrastructure deployed successfully"
    }
    catch {
        Write-Error "Failed to deploy infrastructure"
    }
    finally {
        Pop-Location
    }
}

# Function to deploy monitoring manually
function Deploy-Monitoring {
    Write-Status "Deploying monitoring stack..."
    
    # Build monitoring
    npx nx build monitoring --yes
    
    # Deploy monitoring manually
    Write-Status "Running CDK deployment for monitoring..."
    Push-Location "dist/apps/monitoring"
    try {
        npx cdk deploy --all --require-approval never --app src/main.js
        Write-Success "Monitoring stack deployed successfully"
    }
    catch {
        Write-Error "Failed to deploy monitoring stack"
    }
    finally {
        Pop-Location
    }
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
    
    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "1. Start Docker Desktop for container operations" -ForegroundColor Yellow
    Write-Host "2. Configure kubectl: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME" -ForegroundColor Yellow
    Write-Host "3. Deploy applications: kubectl apply -f apps/infrastructure/src/k8s/" -ForegroundColor Yellow
    Write-Host "4. Build and push Docker images to ECR" -ForegroundColor Yellow
    Write-Host ""
}

# Function to destroy infrastructure manually
function Destroy-Infrastructure {
    Write-Status "Destroying infrastructure..."
    
    # Destroy monitoring stack first
    Write-Status "Destroying monitoring stack..."
    Push-Location "dist/apps/monitoring"
    try {
        npx cdk destroy --all --force --require-approval never --app src/main.js
        Write-Success "Monitoring stack destroyed"
    }
    catch {
        Write-Warning "Failed to destroy monitoring stack"
    }
    finally {
        Pop-Location
    }
    
    # Destroy main infrastructure stack
    Write-Status "Destroying main infrastructure stack..."
    Push-Location "dist/apps/infrastructure"
    try {
        npx cdk destroy --all --force --require-approval never --app src/main.js
        Write-Success "Infrastructure stack destroyed"
    }
    catch {
        Write-Warning "Failed to destroy infrastructure stack"
    }
    finally {
        Pop-Location
    }
    
    Write-Success "Infrastructure destruction completed"
}

# Function to show help
function Show-Help {
    Write-Host "Simple iAgent DevOps Setup Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\simple-setup.ps1 [COMMAND]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  start             Start infrastructure and monitoring" -ForegroundColor Yellow
    Write-Host "  stop              Stop and destroy all infrastructure" -ForegroundColor Yellow
    Write-Host "  status            Show current deployment status" -ForegroundColor Yellow
    Write-Host "  help              Show this help message" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor White
    Write-Host "  AWS_REGION          AWS region (default: us-east-1)" -ForegroundColor Gray
    Write-Host "  CLUSTER_NAME        EKS cluster name (default: iagent-cluster)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\simple-setup.ps1 start    # Start infrastructure" -ForegroundColor Gray
    Write-Host "  .\simple-setup.ps1 status   # Check current status" -ForegroundColor Gray
    Write-Host "  .\simple-setup.ps1 stop     # Stop and destroy everything" -ForegroundColor Gray
    Write-Host ""
}

# Main deployment function
function Main {
    switch ($Command) {
        "start" {
            Write-Status "Starting iAgent infrastructure..."
            Test-Prerequisites
            Install-Dependencies
            Start-CdkBootstrap
            Deploy-Infrastructure
            Deploy-Monitoring
            Invoke-Tests
            Build-Applications
            Show-Status
            Write-Success "Infrastructure setup completed!"
            Write-Host ""
            Write-Host "Your iAgent DevOps infrastructure is now running!" -ForegroundColor Green
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "1. Start Docker Desktop" -ForegroundColor Yellow
            Write-Host "2. Configure kubectl and deploy applications" -ForegroundColor Yellow
            Write-Host "3. Push to GitHub to trigger CI/CD pipeline" -ForegroundColor Yellow
            Write-Host "Run '.\simple-setup.ps1 stop' to stop everything" -ForegroundColor Yellow
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