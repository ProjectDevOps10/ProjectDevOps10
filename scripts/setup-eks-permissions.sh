#!/bin/bash

# Setup EKS permissions for iagent-cicd user
# Run this script with root AWS credentials to fix EKS access

set -e

echo "🔐 Setting up EKS permissions for iagent-cicd user..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Get current AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📊 AWS Account ID: $ACCOUNT_ID"

# Create EKS policy for the user
echo "📝 Creating EKS policy..."
aws iam create-policy \
    --policy-name EKSAccessPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "eks:DescribeCluster",
                    "eks:ListClusters",
                    "eks:AccessKubernetesApi",
                    "eks:DescribeNodegroup",
                    "eks:ListNodegroups"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeInstances",
                    "ec2:DescribeRegions"
                ],
                "Resource": "*"
            }
        ]
    }' || echo "Policy already exists or failed to create"

# Get the policy ARN
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`EKSAccessPolicy`].Arn' --output text)

if [ -z "$POLICY_ARN" ]; then
    echo "❌ Error: Could not find EKSAccessPolicy"
    exit 1
fi

echo "📋 Policy ARN: $POLICY_ARN"

# Attach the policy to the iagent-cicd user
echo "🔗 Attaching EKS policy to iagent-cicd user..."
aws iam attach-user-policy \
    --user-name iagent-cicd \
    --policy-arn "$POLICY_ARN"

echo "✅ EKS permissions configured successfully!"
echo ""
echo "📋 Summary of permissions added:"
echo "   - eks:DescribeCluster"
echo "   - eks:ListClusters"
echo "   - eks:AccessKubernetesApi"
echo "   - eks:DescribeNodegroup"
echo "   - eks:ListNodegroups"
echo "   - ec2:DescribeInstances"
echo "   - ec2:DescribeRegions"
echo ""
echo "🔄 The iagent-cicd user should now be able to access EKS clusters."
