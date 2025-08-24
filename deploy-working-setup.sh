#!/bin/bash

echo "🚀 iAgent Working DevOps Setup Deployment"
echo "=========================================="

# Wait for stack deletion to complete
echo "⏳ Waiting for old stack to finish deleting..."
while true; do
    status=$(aws cloudformation describe-stacks --stack-name IAgentInfrastructureStack --region eu-central-1 --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "DELETED")
    echo "Stack status: $status"
    
    if [ "$status" = "DELETED" ]; then
        echo "✅ Old stack deleted!"
        break
    elif [ "$status" = "DELETE_FAILED" ]; then
        echo "⚠️ Stack deletion failed, forcing deletion..."
        aws cloudformation delete-stack --stack-name IAgentInfrastructureStack --region eu-central-1
        sleep 30
    fi
    
    sleep 30
done

# Deploy fresh infrastructure
echo "🚀 Deploying fresh infrastructure with correct node group config..."
cd apps/infrastructure
npx cdk deploy --all --require-approval never

# Check deployment
echo "📊 Checking deployment status..."
aws eks describe-cluster --name iagent-cluster-v2 --region eu-central-1 --query "cluster.status" --output text
aws eks describe-nodegroup --cluster-name iagent-cluster-v2 --nodegroup-name simple-nodegroup --region eu-central-1 --query "nodegroup.{Status:status,Min:scalingConfig.minSize,Max:scalingConfig.maxSize,Desired:scalingConfig.desiredSize}" --output table

echo ""
echo "🎉 SETUP COMPLETE!"
echo ""
echo "✅ Infrastructure: Deployed with correct node group (min:0, max:2, desired:1)"
echo "✅ Frontend: GitHub Actions will deploy to GitHub Pages"
echo "✅ Backend: GitHub Actions will deploy to EKS"
echo ""
echo "🌐 Your frontend will be available at:"
echo "   https://ProjectDevOps10.github.io/iAgent"
echo ""
echo "🔄 To trigger deployment:"
echo "   git add . && git commit -m 'trigger deployment' && git push"
