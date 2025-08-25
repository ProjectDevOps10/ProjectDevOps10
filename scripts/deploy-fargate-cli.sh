#!/bin/bash
# CLI-based Fargate deployment (fallback without CDK)

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 Deploying Fargate to EKS cluster: $CLUSTER_NAME in $REGION"

# 1. Create Pod Execution Role for Fargate
echo "📋 Creating Pod Execution Role..."

ROLE_NAME="EKSFargatePodExecutionRole"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Check if role exists
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "🔧 Creating Pod Execution Role..."
    
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "pods.eks.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' \
        --tags Key=Project,Value=iAgent Key=Purpose,Value=FargateExecution

    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy
        
    echo "✅ Pod Execution Role created: $ROLE_ARN"
else
    echo "✅ Pod Execution Role already exists: $ROLE_ARN"
fi

# 2. Get private subnets for Fargate profiles
echo "🔍 Getting private subnets..."
SUBNETS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query "cluster.resourcesVpcConfig.subnetIds" --output text)

# Filter for private subnets only
PRIVATE_SUBNETS=""
for subnet in $SUBNETS; do
    IS_PUBLIC=$(aws ec2 describe-subnets --subnet-ids "$subnet" \
        --query "Subnets[0].MapPublicIpOnLaunch" --output text)
    if [ "$IS_PUBLIC" = "False" ]; then
        PRIVATE_SUBNETS="$PRIVATE_SUBNETS $subnet"
    fi
done

PRIVATE_SUBNETS=$(echo $PRIVATE_SUBNETS | tr ' ' '\n' | head -2 | tr '\n' ' ')
echo "🏗️  Using private subnets: $PRIVATE_SUBNETS"

# 3. Create Fargate profiles for namespaces
NAMESPACES=("default" "prod" "staging")

for NAMESPACE in "${NAMESPACES[@]}"; do
    PROFILE_NAME="fp-${NAMESPACE}"
    
    echo "🚀 Creating Fargate profile for namespace: $NAMESPACE"
    
    # Check if profile already exists
    if aws eks describe-fargate-profile \
        --cluster-name "$CLUSTER_NAME" \
        --fargate-profile-name "$PROFILE_NAME" \
        --region "$REGION" >/dev/null 2>&1; then
        echo "✅ Fargate profile $PROFILE_NAME already exists"
    else
        echo "🔧 Creating Fargate profile: $PROFILE_NAME"
        
        aws eks create-fargate-profile \
            --cluster-name "$CLUSTER_NAME" \
            --fargate-profile-name "$PROFILE_NAME" \
            --pod-execution-role-arn "$ROLE_ARN" \
            --subnets $PRIVATE_SUBNETS \
            --selectors namespace="$NAMESPACE" \
            --region "$REGION" \
            --tags Project=iAgent,Environment="$NAMESPACE",Purpose=FargateProfile
            
        echo "✅ Fargate profile $PROFILE_NAME created"
    fi
done

# 4. Wait for profiles to be active
echo "⏳ Waiting for Fargate profiles to be active..."
./scripts/wait-for-fargate.sh "$CLUSTER_NAME" "$REGION"

# 5. Switch CoreDNS to run on Fargate
echo "🔧 Switching CoreDNS to Fargate..."

aws eks update-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name coredns \
    --resolve-conflicts OVERWRITE \
    --configuration-values '{"computeType":"Fargate"}' \
    --region "$REGION" || true

echo "✅ CoreDNS migration to Fargate initiated"

# 6. Install AWS Load Balancer Controller (requires Helm)
echo "🎯 Installing AWS Load Balancer Controller..."

# Create IRSA service account
eksctl create iamserviceaccount \
    --cluster="$CLUSTER_NAME" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region="$REGION" \
    --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
    --approve \
    --override-existing-serviceaccounts || true

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName="$CLUSTER_NAME" \
    --set region="$REGION" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --wait

echo "✅ AWS Load Balancer Controller installed"

echo "🎉 Fargate deployment complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Run 'make smoke' to deploy and test sample app"
echo "  2. Run 'make status' to check Fargate status"
echo "  3. Deploy your applications to namespaces: default, prod, staging"
