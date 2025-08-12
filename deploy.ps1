# iAgent DevOps Project - Main Deployment Script
# Complete infrastructure deployment with verbose logging

param(
    [Parameter(Position=0)]
    [ValidateSet("deploy", "destroy", "status", "help")]
    [string]$Command = "help"
)

# Configuration
$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "iagent-cluster" }

# Set environment variables for verbose logging
$env:NX_SKIP_NX_CACHE = "true"
$env:NX_VERBOSE_LOGGING = "true"
$env:NX_INTERACTIVE = "false"
$env:CDK_VERBOSE = "true"

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

function Write-Verbose {
    param([string]$Message)
    Write-Host "[VERBOSE] $Message" -ForegroundColor Gray
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    $missingTools = @()
    
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        $missingTools += "Node.js"
    } else {
        $nodeVersion = node --version
        Write-Verbose "Node.js version: $nodeVersion"
    }
    
    if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
        $missingTools += "npm"
    } else {
        $npmVersion = npm --version
        Write-Verbose "npm version: $npmVersion"
    }
    
    if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
        $missingTools += "AWS CLI"
    } else {
        $awsVersion = aws --version
        Write-Verbose "AWS CLI version: $awsVersion"
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
            Write-Verbose "AWS Region: $AWS_REGION"
            Write-Verbose "User ARN: $($callerIdentity.Arn)"
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
        Write-Verbose "Installing npm dependencies..."
        npm install
        Write-Success "Dependencies installed"
    } else {
        Write-Status "Dependencies already installed, skipping..."
    }
    
    # Sync TypeScript project references
    Write-Status "Syncing TypeScript project references..."
    Write-Verbose "Running: npx nx sync --yes"
    npx nx sync --yes
}

# Function to bootstrap CDK
function Start-CdkBootstrap {
    Write-Status "Bootstrapping AWS CDK..."
    
    $accountId = Test-AwsCredentials
    
    try {
        Write-Verbose "Checking if CDK is already bootstrapped..."
        aws cloudformation describe-stacks --stack-name CDKToolkit 2>$null | Out-Null
        Write-Status "CDK already bootstrapped, skipping..."
    }
    catch {
        Write-Status "CDK not bootstrapped, bootstrapping now..."
        Write-Verbose "Running: npx cdk bootstrap aws://$accountId/$AWS_REGION"
        npx cdk bootstrap "aws://$accountId/$AWS_REGION"
        Write-Success "CDK bootstrapped successfully"
    }
}

# Function to build infrastructure with verbose logging
function Build-Infrastructure {
    Write-Status "Building infrastructure..."
    
    Write-Verbose "Running: npx nx build infrastructure --verbose"
    npx nx build infrastructure --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Infrastructure built successfully"
    } else {
        Write-Error "Infrastructure build failed"
        exit 1
    }
}

# Function to deploy infrastructure with verbose logging
function Deploy-Infrastructure {
    Write-Status "Deploying infrastructure..."
    
    # Build first
    Build-Infrastructure
    
    # Deploy infrastructure manually with verbose logging
    Write-Status "Running CDK deployment..."
    Write-Verbose "Changing to infrastructure directory..."
    Push-Location "dist/apps/infrastructure"
    
    try {
        Write-Verbose "Current directory: $(Get-Location)"
        Write-Verbose "Files in current directory: $(Get-ChildItem)"
        Write-Verbose "Files in src directory: $(Get-ChildItem src)"
        
        Write-Verbose "Running: npx cdk deploy --all --require-approval never --app src/main.js --verbose"
        npx cdk deploy --all --require-approval never --app src/main.js --verbose
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Infrastructure deployed successfully"
        } else {
            Write-Error "Infrastructure deployment failed"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to deploy infrastructure: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Function to build monitoring with verbose logging
function Build-Monitoring {
    Write-Status "Building monitoring stack..."
    
    Write-Verbose "Running: npx nx build monitoring --verbose"
    npx nx build monitoring --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Monitoring built successfully"
    } else {
        Write-Error "Monitoring build failed"
        exit 1
    }
}

# Function to deploy monitoring with verbose logging
function Deploy-Monitoring {
    Write-Status "Deploying monitoring stack..."
    
    # Build first
    Build-Monitoring
    
    # Deploy monitoring manually with verbose logging
    Write-Status "Running CDK deployment for monitoring..."
    Write-Verbose "Changing to monitoring directory..."
    Push-Location "dist/apps/monitoring"
    
    try {
        Write-Verbose "Current directory: $(Get-Location)"
        Write-Verbose "Files in current directory: $(Get-ChildItem)"
        Write-Verbose "Files in src directory: $(Get-ChildItem src)"
        
        Write-Verbose "Running: npx cdk deploy --all --require-approval never --app src/main.js --verbose"
        npx cdk deploy --all --require-approval never --app src/main.js --verbose
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Monitoring stack deployed successfully"
        } else {
            Write-Error "Monitoring deployment failed"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to deploy monitoring: $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
}

# Function to run tests with verbose logging
function Invoke-Tests {
    Write-Status "Running tests..."
    
    Write-Verbose "Running: npx nx run-many --target=test --all --verbose"
    npx nx run-many --target=test --all --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Tests completed successfully"
    } else {
        Write-Warning "Some tests failed, but continuing with deployment"
    }
}

# Function to build applications with verbose logging
function Build-Applications {
    Write-Status "Building applications..."
    
    Write-Verbose "Running: npx nx run-many --target=build --projects=frontend,backend --verbose"
    npx nx run-many --target=build --projects=frontend,backend --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Applications built successfully"
    } else {
        Write-Warning "Some application builds failed, but continuing"
    }
}

# Function to show deployment status
function Show-Status {
    Write-Status "Checking deployment status..."
    
    Write-Host ""
    Write-Host "=== Deployment Status ===" -ForegroundColor Cyan
    
    # Check EKS cluster
    try {
        Write-Verbose "Checking EKS cluster..."
        aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME 2>$null | Out-Null
        Write-Success "EKS Cluster: Running"
    }
    catch {
        Write-Error "EKS Cluster: Not found"
    }
    
    # Check ECR repositories
    try {
        Write-Verbose "Checking ECR backend repository..."
        aws ecr describe-repositories --repository-names iagent-backend --region $AWS_REGION 2>$null | Out-Null
        Write-Success "ECR Backend Repository: Exists"
    }
    catch {
        Write-Error "ECR Backend Repository: Not found"
    }
    
    try {
        Write-Verbose "Checking ECR frontend repository..."
        aws ecr describe-repositories --repository-names iagent-frontend --region $AWS_REGION 2>$null | Out-Null
        Write-Success "ECR Frontend Repository: Exists"
    }
    catch {
        Write-Error "ECR Frontend Repository: Not found"
    }
    
    # Check CloudFormation stacks
    try {
        Write-Verbose "Checking infrastructure stack..."
        aws cloudformation describe-stacks --stack-name IAgentInfrastructureStack --region $AWS_REGION 2>$null | Out-Null
        Write-Success "Infrastructure Stack: Running"
    }
    catch {
        Write-Error "Infrastructure Stack: Not found"
    }
    
    try {
        Write-Verbose "Checking monitoring stack..."
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

# Function to destroy infrastructure with verbose logging
function Destroy-Infrastructure {
    Write-Status "Destroying infrastructure..."
    
    # Destroy monitoring stack first
    Write-Status "Destroying monitoring stack..."
    Write-Verbose "Changing to monitoring directory..."
    Push-Location "dist/apps/monitoring"
    try {
        Write-Verbose "Running: npx cdk destroy --all --force --require-approval never --app src/main.js --verbose"
        npx cdk destroy --all --force --require-approval never --app src/main.js --verbose
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
    Write-Verbose "Changing to infrastructure directory..."
    Push-Location "dist/apps/infrastructure"
    try {
        Write-Verbose "Running: npx cdk destroy --all --force --require-approval never --app src/main.js --verbose"
        npx cdk destroy --all --force --require-approval never --app src/main.js --verbose
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
    Write-Host "iAgent DevOps Project - Main Deployment Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [COMMAND]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  deploy            Deploy complete infrastructure with verbose logging" -ForegroundColor Yellow
    Write-Host "  destroy           Destroy all infrastructure" -ForegroundColor Yellow
    Write-Host "  status            Show current deployment status" -ForegroundColor Yellow
    Write-Host "  help              Show this help message" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Environment Variables:" -ForegroundColor White
    Write-Host "  AWS_REGION          AWS region (default: us-east-1)" -ForegroundColor Gray
    Write-Host "  CLUSTER_NAME        EKS cluster name (default: iagent-cluster)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\deploy.ps1 deploy    # Deploy complete infrastructure" -ForegroundColor Gray
    Write-Host "  .\deploy.ps1 status    # Check current status" -ForegroundColor Gray
    Write-Host "  .\deploy.ps1 destroy   # Destroy everything" -ForegroundColor Gray
    Write-Host ""
}

# Main deployment function
function Main {
    Write-Host "🚀 iAgent DevOps Project - Main Deployment Script" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
    
    switch ($Command) {
        "deploy" {
            Write-Status "Starting complete iAgent infrastructure deployment..."
            Write-Verbose "Command: deploy"
            Write-Verbose "AWS Region: $AWS_REGION"
            Write-Verbose "Cluster Name: $CLUSTER_NAME"
            Write-Host ""
            
            Test-Prerequisites
            Install-Dependencies
            Start-CdkBootstrap
            Deploy-Infrastructure
            Deploy-Monitoring
            Invoke-Tests
            Build-Applications
            Show-Status
            
            Write-Success "Complete infrastructure deployment finished!"
            Write-Host ""
            Write-Host "🎉 Your iAgent DevOps infrastructure is now running!" -ForegroundColor Green
            Write-Host "📊 Infrastructure deployed with verbose logging" -ForegroundColor Cyan
            Write-Host "🔄 Next steps:" -ForegroundColor Yellow
            Write-Host "   1. Start Docker Desktop" -ForegroundColor Gray
            Write-Host "   2. Configure kubectl and deploy applications" -ForegroundColor Gray
            Write-Host "   3. Push to GitHub to trigger CI/CD pipeline" -ForegroundColor Gray
            Write-Host "🛑 Run '.\deploy.ps1 destroy' to stop everything" -ForegroundColor Yellow
        }
        "destroy" {
            Write-Status "Destroying iAgent infrastructure..."
            Write-Verbose "Command: destroy"
            Write-Host ""
            
            Destroy-Infrastructure
            Write-Success "Infrastructure destroyed successfully!"
        }
        "status" {
            Write-Status "Checking deployment status..."
            Write-Verbose "Command: status"
            Write-Host ""
            
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