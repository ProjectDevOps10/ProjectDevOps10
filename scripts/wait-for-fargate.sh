#!/bin/bash
# Wait for Fargate profiles to be active

set -e

CLUSTER_NAME=${1:-iagent-cluster}
REGION=${2:-eu-central-1}

echo "⏳ Waiting for Fargate profiles to be active..."

# Get all Fargate profile names
PROFILES=$(aws eks list-fargate-profiles --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'fargateProfileNames[]' --output text)

if [ -z "$PROFILES" ]; then
    echo "❌ No Fargate profiles found for cluster $CLUSTER_NAME"
    exit 1
fi

echo "🔍 Found profiles: $PROFILES"

# Wait for each profile to be active
for PROFILE in $PROFILES; do
    echo "⏳ Waiting for profile $PROFILE to be active..."
    
    while true; do
        STATUS=$(aws eks describe-fargate-profile \
            --cluster-name "$CLUSTER_NAME" \
            --fargate-profile-name "$PROFILE" \
            --region "$REGION" \
            --query 'fargateProfile.status' \
            --output text)
        
        echo "$(date): Profile $PROFILE status: $STATUS"
        
        case $STATUS in
            "ACTIVE")
                echo "✅ Profile $PROFILE is active!"
                break
                ;;
            "CREATE_FAILED" | "DELETE_FAILED")
                echo "❌ Profile $PROFILE failed with status: $STATUS"
                exit 1
                ;;
            "CREATING")
                echo "⏳ Profile $PROFILE is still creating, waiting..."
                sleep 30
                ;;
            *)
                echo "⚠️  Unknown status for profile $PROFILE: $STATUS"
                sleep 30
                ;;
        esac
    done
done

echo "✅ All Fargate profiles are active!"

# Verify CoreDNS is running on Fargate
echo "🔍 Checking CoreDNS status..."
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

echo "✅ Fargate setup complete!"
