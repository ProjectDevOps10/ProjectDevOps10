#!/bin/bash

# Simple Infrastructure Deployment Script
echo "🚀 iAgent Infrastructure Deployment"
echo "==================================="
echo ""

echo "[INFO] Checking prerequisites..."

# Check Node.js
NODE_PATH="/mnt/c/Program Files/nodejs/node.exe"
if [ -f "$NODE_PATH" ]; then
    NODE_VERSION=$("$NODE_PATH" --version)
    echo "[VERBOSE] Node.js version: $NODE_VERSION"
else
    echo "[ERROR] Node.js not found at $NODE_PATH"
    exit 1
fi

# Check npm
NPM_PATH="/mnt/c/Program Files/nodejs/npm.cmd"
if [ -f "$NPM_PATH" ]; then
    NPM_VERSION=$("$NPM_PATH" --version)
    echo "[VERBOSE] npm version: $NPM_VERSION"
else
    echo "[ERROR] npm not found at $NPM_PATH"
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "[ERROR] AWS CLI not found"
    exit 1
else
    AWS_VERSION=$(aws --version)
    echo "[VERBOSE] AWS CLI version: $AWS_VERSION"
fi

echo "[SUCCESS] All prerequisites are installed"

# Check AWS credentials
echo "[INFO] Checking AWS credentials..."
CALLER_IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
if [ $? -eq 0 ]; then
    ACCOUNT_ID=$(echo $CALLER_IDENTITY | jq -r '.Account')
    USER_ARN=$(echo $CALLER_IDENTITY | jq -r '.Arn')
    echo "[SUCCESS] AWS credentials configured for account: $ACCOUNT_ID"
    echo "[VERBOSE] AWS Region: us-east-1"
    echo "[VERBOSE] User ARN: $USER_ARN"
else
    echo "[ERROR] AWS credentials not configured or invalid"
    echo "[INFO] Please run 'aws configure' and try again."
    exit 1
fi

# Install dependencies if needed
echo "[INFO] Installing dependencies..."
if [ ! -d "node_modules" ]; then
    echo "[VERBOSE] Installing npm dependencies..."
    "$NPM_PATH" install
    echo "[SUCCESS] Dependencies installed"
else
    echo "[INFO] Dependencies already installed, skipping..."
fi

# Sync TypeScript project references
echo "[INFO] Syncing TypeScript project references..."
echo "[VERBOSE] Running: npx nx sync --yes"
"$NODE_PATH" "$(which npx)" nx sync --yes

# Bootstrap CDK
echo "[INFO] Bootstrapping AWS CDK..."
if aws cloudformation describe-stacks --stack-name CDKToolkit 2>/dev/null; then
    echo "[INFO] CDK already bootstrapped, skipping..."
else
    echo "[INFO] CDK not bootstrapped, bootstrapping now..."
    echo "[VERBOSE] Running: npx cdk bootstrap aws://$ACCOUNT_ID/us-east-1"
    "$NODE_PATH" "$(which npx)" cdk bootstrap "aws://$ACCOUNT_ID/us-east-1"
    echo "[SUCCESS] CDK bootstrapped successfully"
fi

# Build infrastructure
echo "[INFO] Building infrastructure..."
echo "[VERBOSE] Running: npx nx build infrastructure --verbose"
"$NODE_PATH" "$(which npx)" nx build infrastructure --verbose

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Infrastructure built successfully"
else
    echo "[ERROR] Infrastructure build failed"
    exit 1
fi

# Deploy infrastructure
echo "[INFO] Deploying infrastructure..."
echo "[VERBOSE] Changing to infrastructure directory..."
cd dist/apps/infrastructure

echo "[VERBOSE] Current directory: $(pwd)"
echo "[VERBOSE] Files in current directory: $(ls -la)"
echo "[VERBOSE] Files in src directory: $(ls -la src)"

echo "[VERBOSE] Running: npx cdk deploy --all --require-approval never --app src/main.js --verbose"
"$NODE_PATH" "$(which npx)" cdk deploy --all --require-approval never --app src/main.js --verbose

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Infrastructure deployed successfully"
else
    echo "[ERROR] Infrastructure deployment failed"
    exit 1
fi

cd ../..

echo ""
echo "🎉 Infrastructure deployment completed!"
echo "📊 Infrastructure deployed with verbose logging"
echo "🔄 Next steps:"
echo "   1. Deploy monitoring stack"
echo "   2. Configure kubectl and deploy applications"
echo "   3. Build and push Docker images to ECR"
echo "" 