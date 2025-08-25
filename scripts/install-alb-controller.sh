#!/bin/bash
# Install AWS Load Balancer Controller for ALB Ingress support

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🎯 Installing AWS Load Balancer Controller for cluster: $CLUSTER_NAME"

# Check if role already exists
if aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole >/dev/null 2>&1; then
    echo "✅ IAM role already exists"
else
    echo "📋 Creating IAM role for AWS Load Balancer Controller..."
    
    # Create trust policy
    cat > /tmp/trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/oidc.eks.$REGION.amazonaws.com/id/DB27746AA5D434218936184AB68D7F5E"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.$REGION.amazonaws.com/id/DB27746AA5D434218936184AB68D7F5E:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "oidc.eks.$REGION.amazonaws.com/id/DB27746AA5D434218936184AB68D7F5E:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

    # Create role
    aws iam create-role \
        --role-name AmazonEKSLoadBalancerControllerRole \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --tags Key=Project,Value=iAgent
fi

# Check if policy exists
if aws iam get-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy >/dev/null 2>&1; then
    echo "✅ IAM policy already exists"
else
    echo "📋 Creating IAM policy..."
    
    # Download and create policy
    curl -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
    
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file:///tmp/iam_policy.json \
        --tags Key=Project,Value=iAgent
fi

# Attach policy to role
aws iam attach-role-policy \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy

echo "✅ IAM setup complete"

# Install AWS Load Balancer Controller via Helm
echo "🎯 Installing AWS Load Balancer Controller via Helm..."

# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update

# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Install/upgrade AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set region=$REGION \
  --set vpcId=$VPC_ID \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::$ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole" \
  --wait \
  --timeout=10m

echo "✅ AWS Load Balancer Controller installed successfully!"

# Verify installation
echo "🔍 Verifying installation..."
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo "🎉 AWS Load Balancer Controller is ready to create ALBs!"
