#!/bin/bash
# Deploy backend to Fargate using AWS CLI only (no kubectl needed)

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}
IMAGE_TAG=${3:-latest}
ECR_REGISTRY=${4:-045498639212.dkr.ecr.eu-central-1.amazonaws.com}

echo "🚀 Deploying backend to Fargate using AWS CLI..."

# Check AWS access
echo "🔍 Checking AWS access..."
aws sts get-caller-identity

# Check Fargate profile status
echo "🔍 Checking Fargate profile status..."
FARGATE_STATUS=$(aws eks describe-fargate-profile --cluster-name $CLUSTER_NAME --fargate-profile-name fp-default --region $REGION --query 'fargateProfile.status' --output text)
echo "📊 Fargate profile status: $FARGATE_STATUS"

if [ "$FARGATE_STATUS" != "ACTIVE" ]; then
    echo "❌ Fargate profile not active, cannot deploy"
    exit 1
fi

# Create deployment manifest with current image
echo "📝 Creating deployment manifest..."
cat > /tmp/backend-deployment-fargate.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iagent-backend
  namespace: default
  labels:
    app: iagent-backend
    version: v1
    deployment: fargate
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iagent-backend
  template:
    metadata:
      labels:
        app: iagent-backend
        version: v1
        deployment: fargate
    spec:
      containers:
      - name: backend
        image: $ECR_REGISTRY/iagent-backend:$IMAGE_TAG
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: iagent-backend-service
  namespace: default
  labels:
    app: iagent-backend
spec:
  selector:
    app: iagent-backend
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP
EOF

echo "✅ Deployment manifest created"

# For now, we'll save this and wait for kubectl access to be fixed
echo "📋 Deployment manifest saved to /tmp/backend-deployment-fargate.yaml"
echo "🔍 This can be applied once kubectl access is restored"

# Alternative: Try to use ECS instead of EKS for now
echo "💡 Alternative: Consider deploying to ECS Fargate if EKS access remains blocked"

echo "📊 Summary:"
echo "- ✅ AWS CLI access: Working"
echo "- ✅ Fargate profile: $FARGATE_STATUS"
echo "- ✅ ECR image: $ECR_REGISTRY/iagent-backend:$IMAGE_TAG"
echo "- ❌ kubectl access: Blocked"
echo ""
echo "🎯 Next: Fix kubectl access or use alternative deployment method"
