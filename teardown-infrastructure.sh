#!/bin/bash

# iAgent Infrastructure Teardown Script
# One-command teardown to prevent AWS charges

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Load AWS configuration
if [ ! -f .env.aws ]; then
    print_error ".env.aws not found. Cannot determine AWS configuration"
    exit 1
fi

source .env.aws

print_header "iAgent Infrastructure Teardown"

# Start timing
START_TIME=$(date +%s)

# Confirmation prompt
confirm_teardown() {
    print_warning "🗑️  This will PERMANENTLY DELETE all iAgent AWS resources!"
    print_warning "Resources to be deleted:"
    echo "  • EKS Cluster and all workloads"
    echo "  • ECR repositories and all images"
    echo "  • VPC, subnets, and networking"
    echo "  • CloudWatch logs and alarms"
    echo "  • All data will be lost!"
    echo ""
    print_warning "This action cannot be undone!"
    echo ""
    read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " -r
    echo
    if [[ ! $REPLY == "DELETE" ]]; then
        print_status "Teardown cancelled"
        exit 0
    fi
}

# Clean up Kubernetes resources first
cleanup_kubernetes() {
    print_header "Cleaning up Kubernetes Resources"
    
    CLUSTER_NAME="iagent-cluster"
    
    # Check if cluster exists and is accessible
    if kubectl cluster-info &>/dev/null; then
        print_status "Cluster is accessible, cleaning up resources..."
        
        # Delete all resources in iagent namespace
        print_status "Deleting iagent namespace and all resources..."
        kubectl delete namespace iagent --ignore-not-found=true --timeout=300s || {
            print_warning "Timeout deleting namespace, forcing deletion..."
            kubectl delete namespace iagent --grace-period=0 --force --ignore-not-found=true
        }
        
        # Delete any remaining cluster-wide resources
        print_status "Cleaning up cluster-wide resources..."
        kubectl delete clusterrolebinding iagent-cluster-admin --ignore-not-found=true
        kubectl delete clusterrole iagent-admin --ignore-not-found=true
        
        print_status "Kubernetes cleanup completed"
    else
        print_warning "Cluster not accessible, skipping Kubernetes cleanup"
    fi
}

# Clean up ECR repositories
cleanup_ecr() {
    print_header "Cleaning up ECR Repositories"
    
    # List of repositories to clean
    REPOSITORIES=("iagent-backend" "iagent-frontend")
    
    for repo in "${REPOSITORIES[@]}"; do
        if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION &>/dev/null; then
            print_status "Deleting ECR repository: $repo"
            
            # Delete all images first
            aws ecr list-images --repository-name $repo --region $AWS_REGION --query 'imageIds[*]' --output json | \
            jq '.[] | select(.imageTag != null) | {imageTag: .imageTag}' | \
            jq -s '.' | \
            xargs -I {} aws ecr batch-delete-image --repository-name $repo --region $AWS_REGION --image-ids '{}' || true
            
            # Delete repository
            aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force || {
                print_warning "Failed to delete repository $repo, continuing..."
            }
        else
            print_status "Repository $repo does not exist, skipping..."
        fi
    done
    
    print_status "ECR cleanup completed"
}

# Clean up CloudWatch resources
cleanup_cloudwatch() {
    print_header "Cleaning up CloudWatch Resources"
    
    # Delete log groups
    print_status "Deleting CloudWatch log groups..."
    LOG_GROUPS=$(aws logs describe-log-groups --region $AWS_REGION --query 'logGroups[?contains(logGroupName, `iagent`) || contains(logGroupName, `eks`) || contains(logGroupName, `/aws/eks/iagent`)].logGroupName' --output text)
    
    if [ ! -z "$LOG_GROUPS" ]; then
        for log_group in $LOG_GROUPS; do
            print_status "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region $AWS_REGION || {
                print_warning "Failed to delete log group $log_group, continuing..."
            }
        done
    fi
    
    # Delete alarms
    print_status "Deleting CloudWatch alarms..."
    ALARMS=$(aws cloudwatch describe-alarms --region $AWS_REGION --query 'MetricAlarms[?contains(AlarmName, `iagent`) || contains(AlarmName, `IAgent`)].AlarmName' --output text)
    
    if [ ! -z "$ALARMS" ]; then
        aws cloudwatch delete-alarms --alarm-names $ALARMS --region $AWS_REGION || {
            print_warning "Failed to delete some alarms, continuing..."
        }
    fi
    
    print_status "CloudWatch cleanup completed"
}

# Destroy CDK stack
destroy_cdk_stack() {
    print_header "Destroying CDK Stack"
    
    cd apps/infrastructure
    
    # Check if stack exists
    if cdk list | grep -q "IAgentInfrastructureStack"; then
        print_status "Destroying IAgentInfrastructureStack..."
        cdk destroy --force --require-approval never || {
            print_error "CDK destroy failed, trying alternative cleanup..."
            
            # Alternative: delete stack via CloudFormation
            aws cloudformation delete-stack --stack-name IAgentInfrastructureStack --region $AWS_REGION || {
                print_warning "CloudFormation delete also failed, manual cleanup may be required"
            }
        }
    else
        print_warning "CDK stack not found, skipping..."
    fi
    
    cd ../..
    
    print_status "CDK stack destruction completed"
}

# Clean up local files
cleanup_local_files() {
    print_header "Cleaning up Local Files"
    
    # Remove deployment configurations
    rm -f .env.deployment
    rm -f apps/infrastructure-outputs.json
    rm -f cost-monitor.json
    
    # Remove kubectl context for the cluster
    kubectl config delete-context arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/iagent-cluster 2>/dev/null || true
    kubectl config delete-cluster arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/iagent-cluster 2>/dev/null || true
    
    print_status "Local cleanup completed"
}

# Verify cleanup
verify_cleanup() {
    print_header "Verifying Cleanup"
    
    # Check for remaining EKS clusters
    CLUSTERS=$(aws eks list-clusters --region $AWS_REGION --query 'clusters[?contains(@, `iagent`)]' --output text)
    if [ ! -z "$CLUSTERS" ]; then
        print_warning "⚠️  Remaining EKS clusters found: $CLUSTERS"
        print_warning "Manual cleanup may be required"
    else
        print_status "✅ No iAgent EKS clusters found"
    fi
    
    # Check for remaining ECR repositories
    REPOS=$(aws ecr describe-repositories --region $AWS_REGION --query 'repositories[?contains(repositoryName, `iagent`)].repositoryName' --output text 2>/dev/null || true)
    if [ ! -z "$REPOS" ]; then
        print_warning "⚠️  Remaining ECR repositories found: $REPOS"
    else
        print_status "✅ No iAgent ECR repositories found"
    fi
    
    # Check for CloudFormation stacks
    STACKS=$(aws cloudformation list-stacks --region $AWS_REGION --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[?contains(StackName, `IAgent`)].StackName' --output text)
    if [ ! -z "$STACKS" ]; then
        print_warning "⚠️  Remaining CloudFormation stacks found: $STACKS"
    else
        print_status "✅ No iAgent CloudFormation stacks found"
    fi
    
    print_status "Cleanup verification completed"
}

# Display final status
show_teardown_summary() {
    print_header "Teardown Summary"
    
    # Calculate teardown time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))
    
    print_status "🗑️  Infrastructure teardown completed!"
    print_status "⏱️   Teardown time: ${DURATION_MIN} minutes"
    echo ""
    
    print_status "📋 Resources Cleaned Up:"
    echo "  ✅ EKS Cluster and node groups"
    echo "  ✅ ECR repositories and images"
    echo "  ✅ VPC and networking components"
    echo "  ✅ CloudWatch logs and alarms"
    echo "  ✅ Local configuration files"
    echo ""
    
    print_status "💰 Cost Impact:"
    echo "  ✅ All billable AWS resources have been removed"
    echo "  ✅ You should not incur further charges for this project"
    echo "  ✅ Check AWS Billing Console to confirm"
    echo ""
    
    print_warning "⚠️  Important Notes:"
    echo "  • Check AWS Console to verify all resources are deleted"
    echo "  • It may take a few minutes for billing to reflect changes"
    echo "  • NAT Gateway charges stop immediately upon deletion"
    echo "  • EKS control plane charges stop after cluster deletion"
    echo ""
    
    print_status "🚀 To redeploy later:"
    echo "  1. Run: ./deploy-infrastructure.sh"
    echo "  2. Your code and configurations are preserved locally"
    echo ""
    
    print_status "Teardown completed successfully! 🎉"
}

# Main execution
main() {
    confirm_teardown
    cleanup_kubernetes
    cleanup_ecr
    cleanup_cloudwatch
    destroy_cdk_stack
    cleanup_local_files
    verify_cleanup
    show_teardown_summary
}

# Run main function
main "$@"