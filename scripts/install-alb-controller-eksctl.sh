#!/bin/bash
# Install AWS Load Balancer Controller using eksctl instead of direct Helm

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}

echo "🎯 Installing AWS Load Balancer Controller using eksctl method..."

# Check if eksctl is available
if ! command -v eksctl &> /dev/null; then
    echo "📦 Installing eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

# Create IRSA for AWS Load Balancer Controller
echo "🔧 Creating IRSA for AWS Load Balancer Controller..."
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region=$REGION \
    --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
    --approve \
    --override-existing-serviceaccounts

# Install AWS Load Balancer Controller with eksctl
echo "🎯 Installing AWS Load Balancer Controller..."
eksctl create addon \
    --cluster=$CLUSTER_NAME \
    --name=aws-load-balancer-controller \
    --version=latest \
    --region=$REGION \
    --force

echo "✅ AWS Load Balancer Controller installed via eksctl!"

# Verify installation
kubectl get deployment aws-load-balancer-controller -n kube-system || echo "Installation may still be in progress..."

echo "🎉 ALB Controller setup complete!"
