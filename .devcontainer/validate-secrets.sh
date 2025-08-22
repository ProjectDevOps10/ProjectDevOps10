#!/bin/bash

# AWS Credentials Validation Script for iAgent DevContainer
# This script validates that all required AWS credentials are present in .secrets file

set -e

echo "🔍 Validating AWS credentials in .secrets file..."

# Check if .secrets file exists
if [ ! -f "/workspaces/iAgent/.secrets" ]; then
    echo "❌ ERROR: .secrets file not found!"
    echo "   Please create .secrets file with the following variables:"
    echo "   - AWS_ACCESS_KEY_ID"
    echo "   - AWS_SECRET_ACCESS_KEY"
    echo "   - AWS_ACCOUNT_ID"
    exit 1
fi

# Load credentials from .secrets file
export $(cat /workspaces/iAgent/.secrets | grep -v '^#' | xargs)

# Validate required variables
REQUIRED_VARS=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_ACCOUNT_ID")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ ERROR: Missing or empty required AWS credentials:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "   Please ensure all required variables are set in .secrets file"
    exit 1
fi

# Validate credential format (basic checks)
if [[ ! "$AWS_ACCESS_KEY_ID" =~ ^AKIA[0-9A-Z]{16}$ ]]; then
    echo "❌ ERROR: Invalid AWS_ACCESS_KEY_ID format"
    echo "   Expected format: AKIA followed by 16 alphanumeric characters"
    exit 1
fi

if [ ${#AWS_SECRET_ACCESS_KEY} -lt 40 ]; then
    echo "❌ ERROR: AWS_SECRET_ACCESS_KEY seems too short"
    echo "   Expected length: 40+ characters"
    exit 1
fi

if [[ ! "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "❌ ERROR: Invalid AWS_ACCOUNT_ID format"
    echo "   Expected format: 12 digits"
    exit 1
fi

echo "✅ AWS credentials validation passed!"
echo "   Account ID: $AWS_ACCOUNT_ID"
echo "   Access Key: ${AWS_ACCESS_KEY_ID:0:8}..."
echo "   Region: ${AWS_DEFAULT_REGION:-eu-central-1}"
echo ""
echo "🚀 Container is ready to start with AWS access!"
