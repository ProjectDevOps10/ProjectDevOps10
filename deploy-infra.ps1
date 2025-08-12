# Simple Infrastructure Deployment Script
Write-Host "🚀 iAgent Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Checking prerequisites..." -ForegroundColor Blue

# Check Node.js
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Node.js not found" -ForegroundColor Red
    exit 1
} else {
    $nodeVersion = node --version
    Write-Host "[VERBOSE] Node.js version: $nodeVersion" -ForegroundColor Gray
}

# Check npm
if (-not (Get-Command "npm" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] npm not found" -ForegroundColor Red
    exit 1
} else {
    $npmVersion = npm --version
    Write-Host "[VERBOSE] npm version: $npmVersion" -ForegroundColor Gray
}

# Check AWS CLI
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] AWS CLI not found" -ForegroundColor Red
    exit 1
} else {
    $awsVersion = aws --version
    Write-Host "[VERBOSE] AWS CLI version: $awsVersion" -ForegroundColor Gray
}

Write-Host "[SUCCESS] All prerequisites are installed" -ForegroundColor Green

# Check AWS credentials
Write-Host "[INFO] Checking AWS credentials..." -ForegroundColor Blue
try {
    $callerIdentity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($callerIdentity) {
        Write-Host "[SUCCESS] AWS credentials configured for account: $($callerIdentity.Account)" -ForegroundColor Green
        Write-Host "[VERBOSE] AWS Region: us-east-1" -ForegroundColor Gray
        Write-Host "[VERBOSE] User ARN: $($callerIdentity.Arn)" -ForegroundColor Gray
    } else {
        throw "No caller identity"
    }
}
catch {
    Write-Host "[ERROR] AWS credentials not configured or invalid" -ForegroundColor Red
    Write-Host "[INFO] Please run 'aws configure' and try again." -ForegroundColor Blue
    exit 1
}

# Install dependencies if needed
Write-Host "[INFO] Installing dependencies..." -ForegroundColor Blue
if (-not (Test-Path "node_modules")) {
    Write-Host "[VERBOSE] Installing npm dependencies..." -ForegroundColor Gray
    npm install
    Write-Host "[SUCCESS] Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "[INFO] Dependencies already installed, skipping..." -ForegroundColor Blue
}

# Sync TypeScript project references
Write-Host "[INFO] Syncing TypeScript project references..." -ForegroundColor Blue
Write-Host "[VERBOSE] Running: npx nx sync --yes" -ForegroundColor Gray
npx nx sync --yes

# Bootstrap CDK
Write-Host "[INFO] Bootstrapping AWS CDK..." -ForegroundColor Blue
$accountId = $callerIdentity.Account
try {
    Write-Host "[VERBOSE] Checking if CDK is already bootstrapped..." -ForegroundColor Gray
    aws cloudformation describe-stacks --stack-name CDKToolkit 2>$null | Out-Null
    Write-Host "[INFO] CDK already bootstrapped, skipping..." -ForegroundColor Blue
}
catch {
    Write-Host "[INFO] CDK not bootstrapped, bootstrapping now..." -ForegroundColor Blue
    Write-Host "[VERBOSE] Running: npx cdk bootstrap aws://$accountId/us-east-1" -ForegroundColor Gray
    npx cdk bootstrap "aws://$accountId/us-east-1"
    Write-Host "[SUCCESS] CDK bootstrapped successfully" -ForegroundColor Green
}

# Build infrastructure
Write-Host "[INFO] Building infrastructure..." -ForegroundColor Blue
Write-Host "[VERBOSE] Running: npx nx build infrastructure --verbose" -ForegroundColor Gray
npx nx build infrastructure --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Infrastructure built successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Infrastructure build failed" -ForegroundColor Red
    exit 1
}

# Deploy infrastructure
Write-Host "[INFO] Deploying infrastructure..." -ForegroundColor Blue
Write-Host "[VERBOSE] Changing to infrastructure directory..." -ForegroundColor Gray
Push-Location "dist/apps/infrastructure"

try {
    Write-Host "[VERBOSE] Current directory: $(Get-Location)" -ForegroundColor Gray
    Write-Host "[VERBOSE] Files in current directory: $(Get-ChildItem)" -ForegroundColor Gray
    Write-Host "[VERBOSE] Files in src directory: $(Get-ChildItem src)" -ForegroundColor Gray
    
    Write-Host "[VERBOSE] Running: npx cdk deploy --all --require-approval never --app src/main.js --verbose" -ForegroundColor Gray
    npx cdk deploy --all --require-approval never --app src/main.js --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Infrastructure deployed successfully" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Infrastructure deployment failed" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "[ERROR] Failed to deploy infrastructure: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "🎉 Infrastructure deployment completed!" -ForegroundColor Green
Write-Host "📊 Infrastructure deployed with verbose logging" -ForegroundColor Cyan
Write-Host "🔄 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Deploy monitoring stack" -ForegroundColor Gray
Write-Host "   2. Configure kubectl and deploy applications" -ForegroundColor Gray
Write-Host "   3. Build and push Docker images to ECR" -ForegroundColor Gray
Write-Host "" 