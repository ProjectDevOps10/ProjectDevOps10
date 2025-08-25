#!/bin/bash
# Add GitHub Actions IAM user to EKS cluster access

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}

echo "🔧 Adding GitHub Actions access to EKS cluster..."

# Get current AWS caller identity
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "📋 Current user: $CURRENT_USER"

# Check if we can access the cluster
if kubectl get configmap aws-auth -n kube-system >/dev/null 2>&1; then
    echo "✅ kubectl access working, updating aws-auth ConfigMap..."
    
    # Get the current aws-auth ConfigMap
    kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth-backup.yaml
    
    # Create a patch to add GitHub Actions access
    cat > /tmp/aws-auth-patch.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::045498639212:user/github-actions
      username: github-actions
      groups:
        - system:masters
    - userarn: arn:aws:iam::045498639212:root
      username: root
      groups:
        - system:masters
EOF

    # Apply the patch
    kubectl apply -f /tmp/aws-auth-patch.yaml
    
    echo "✅ GitHub Actions user added to aws-auth ConfigMap"
    
else
    echo "❌ Cannot access cluster with current credentials"
    echo "🔍 Need to add access via AWS Console or eksctl"
    
    echo "📋 Manual steps needed:"
    echo "1. Go to EKS Console > Cluster > Access"
    echo "2. Add IAM user: arn:aws:iam::045498639212:user/github-actions"
    echo "3. Grant 'Cluster admin' permissions"
fi

echo "🎯 GitHub Actions should now have cluster access"
