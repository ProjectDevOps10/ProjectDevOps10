#!/bin/bash
# Check the status of the Fargate deployment

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}

echo "🔍 Checking deployment status for cluster: $CLUSTER_NAME"
echo "═══════════════════════════════════════════════════════"

# Update kubeconfig if needed
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME >/dev/null 2>&1 || echo "⚠️ Could not update kubeconfig"

echo ""
echo "📊 FARGATE STATUS:"
echo "─────────────────"

# Check Fargate profiles
echo "🚀 Fargate Profiles:"
aws eks list-fargate-profiles --cluster-name $CLUSTER_NAME --region $REGION --query 'fargateProfileNames' --output table

# Check default profile status
DEFAULT_STATUS=$(aws eks describe-fargate-profile --cluster-name $CLUSTER_NAME --fargate-profile-name fp-default --region $REGION --query 'fargateProfile.status' --output text)
echo "✅ fp-default status: $DEFAULT_STATUS"

echo ""
echo "🐳 BACKEND DEPLOYMENT:"
echo "─────────────────────"

# Check if we can access kubectl
if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ kubectl access: Working"
    
    # Check pods
    echo ""
    echo "📋 Backend Pods:"
    kubectl get pods -n default -l app=iagent-backend -o wide 2>/dev/null || echo "❌ No backend pods found"
    
    # Check service
    echo ""
    echo "🌐 Backend Service:"
    kubectl get svc -n default -l app=iagent-backend 2>/dev/null || echo "❌ No backend service found"
    
    # Check deployment
    echo ""
    echo "📈 Deployment Status:"
    kubectl get deployment iagent-backend -n default 2>/dev/null || echo "❌ No backend deployment found"
    
    # Check ingress
    echo ""
    echo "🔗 Ingress Status:"
    kubectl get ingress -n default 2>/dev/null || echo "❌ No ingress found"
    
    # Check Load Balancer Controller
    echo ""
    echo "🎯 AWS Load Balancer Controller:"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller 2>/dev/null || echo "❌ ALB Controller not found"
    
    # Try to get ALB URL
    echo ""
    echo "🌐 API URL:"
    ALB_URL=$(kubectl get ingress iagent-backend-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$ALB_URL" ] && [ "$ALB_URL" != "" ]; then
        echo "✅ ALB URL: http://$ALB_URL"
        
        # Test connectivity
        echo ""
        echo "🧪 Testing API connectivity..."
        if curl -s --max-time 10 http://$ALB_URL >/dev/null 2>&1; then
            echo "✅ API is responding!"
        else
            echo "⏳ API not yet responding (may still be starting up)"
        fi
    else
        echo "⏳ ALB URL not yet available (still provisioning)"
    fi
    
else
    echo "❌ kubectl access: Failed"
    echo "ℹ️  This is expected while GitHub Actions is running"
fi

echo ""
echo "📦 ECR IMAGES:"
echo "─────────────"

# Check recent ECR images
echo "🐳 Recent backend images:"
aws ecr describe-images --repository-name iagent-backend --region $REGION --query 'imageDetails[0:3].{Pushed:imagePushedAt,Tags:imageTags}' --output table 2>/dev/null || echo "❌ Cannot access ECR"

echo ""
echo "🚀 NEXT STEPS:"
echo "─────────────"
echo "1. GitHub Actions should be deploying the backend to Fargate"
echo "2. ALB will be created automatically when backend is ready"
echo "3. API will be available at the ALB URL once deployment completes"
echo "4. Expected deployment time: 5-10 minutes total"

echo ""
echo "🔄 Run this script again in a few minutes to check progress"
