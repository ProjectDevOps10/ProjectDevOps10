#!/bin/bash

# iAgent Container Workflow Test Script
# Tests the complete DevOps workflow inside the container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo -e "${BLUE}${BOLD}=== $1 ===${NC}"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    print_test "$test_name"
    
    if eval "$test_command" &>/dev/null; then
        print_status "$test_name: PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$test_name: FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to run a test with warning on failure
run_test_warning() {
    local test_name="$1"
    local test_command="$2"
    
    print_test "$test_name"
    
    if eval "$test_command" &>/dev/null; then
        print_status "$test_name: PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_warning "$test_name: WARNING (not critical)"
        TESTS_WARNINGS=$((TESTS_WARNINGS + 1))
        return 1
    fi
}

print_header "iAgent Container Workflow Test"

# Test 1: Container Environment
print_header "Testing Container Environment"

run_test "Node.js availability" "command -v node"
run_test "npm availability" "command -v npm"
run_test "AWS CLI availability" "command -v aws"
run_test "kubectl availability" "command -v kubectl"
run_test "Docker CLI availability" "command -v docker"
run_test "CDK availability" "command -v cdk"
run_test "GitHub CLI availability" "command -v gh"
run_test "Trivy availability" "command -v trivy"

# Test 2: Project Structure
print_header "Testing Project Structure"

run_test "Project package.json" "test -f package.json"
run_test "Frontend app" "test -d apps/frontend"
run_test "Backend app" "test -d apps/backend"
run_test "Infrastructure app" "test -d apps/infrastructure"
run_test "Setup scripts" "test -x quick-devops-setup.sh"
run_test "Container setup script" "test -x container-setup.sh"
run_test "Teardown script" "test -x teardown-infrastructure.sh"

# Test 3: AWS Configuration
print_header "Testing AWS Configuration"

if aws sts get-caller-identity &>/dev/null; then
    run_test "AWS credentials configured" "aws sts get-caller-identity"
    
    # Get AWS info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
    AWS_REGION=$(aws configure get region 2>/dev/null || echo "unknown")
    
    print_status "AWS Account ID: $ACCOUNT_ID"
    print_status "AWS Region: $AWS_REGION"
    
    run_test "AWS region configured" "test '$AWS_REGION' != 'unknown'"
else
    print_warning "AWS credentials not configured (run ./container-setup.sh)"
    TESTS_WARNINGS=$((TESTS_WARNINGS + 1))
fi

# Test 4: Docker Integration
print_header "Testing Docker Integration"

run_test_warning "Docker daemon accessible" "docker info"
run_test_warning "Docker socket mounted" "test -S /var/run/docker.sock"

# Test 5: Project Dependencies
print_header "Testing Project Dependencies"

run_test_warning "Node modules installed" "test -d node_modules"
run_test "Package-lock exists" "test -f package-lock.json"

# Test 6: Development Scripts
print_header "Testing Development Scripts"

if [ -d "node_modules" ]; then
    run_test "Build script works" "npm run build --silent"
    run_test_warning "Test script works" "npm test --silent"
    run_test_warning "Lint script works" "npm run lint --silent"
else
    print_warning "Skipping npm tests - dependencies not installed"
    TESTS_WARNINGS=$((TESTS_WARNINGS + 3))
fi

# Test 7: Infrastructure Validation
print_header "Testing Infrastructure Configuration"

run_test "Cost-optimized stack exists" "test -f apps/infrastructure/src/lib/cost-optimized-infrastructure-stack.ts"
run_test "Infrastructure package.json" "test -f apps/infrastructure/package.json"
run_test "Kubernetes manifests directory" "test -d apps/infrastructure/src/k8s"

# Test 8: GitHub Actions Configuration
print_header "Testing GitHub Actions Setup"

run_test_warning "GitHub Actions workflow" "test -f .github/workflows/iagent-devops-pipeline.yml"
run_test_warning "Git repository" "git rev-parse --git-dir"
run_test_warning "GitHub remote" "git remote get-url origin"

# Test 9: Container-specific Tests
print_header "Testing Container-specific Features"

run_test "Container user is devuser" "test '$(whoami)' = 'devuser'"
run_test "Workspace directory" "test -d /workspace"
run_test "Home directory writable" "test -w /home/devuser"
run_test_warning "AWS directory exists" "test -d /home/devuser/.aws"

# Test 10: Network Connectivity
print_header "Testing Network Connectivity"

run_test_warning "Internet connectivity" "ping -c 1 google.com"
run_test_warning "AWS API connectivity" "curl -s https://sts.amazonaws.com --max-time 5"
run_test_warning "GitHub connectivity" "curl -s https://api.github.com --max-time 5"

# Test Summary
print_header "Test Summary"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNINGS))

echo "📊 Test Results:"
echo "  ✅ Passed: $TESTS_PASSED"
echo "  ⚠️  Warnings: $TESTS_WARNINGS"
echo "  ❌ Failed: $TESTS_FAILED"
echo "  📝 Total: $TOTAL_TESTS"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    if [ $TESTS_WARNINGS -eq 0 ]; then
        print_status "🎉 All tests passed! Container is ready for DevOps workflow."
        echo ""
        print_status "✅ You can now run:"
        echo "  ./container-setup.sh    - Configure AWS and deploy"
        echo "  ./quick-devops-setup.sh - Interactive setup menu"
        echo ""
    else
        print_warning "⚠️ Tests passed with warnings. Most functionality should work."
        echo ""
        print_warning "Common fixes for warnings:"
        echo "  • Run ./container-setup.sh to configure AWS"
        echo "  • Install dependencies: npm install"
        echo "  • Configure git remote for GitHub integration"
        echo ""
    fi
    
    print_header "Next Steps"
    echo "1. 🔧 Configure AWS: ./container-setup.sh"
    echo "2. 🚀 Deploy infrastructure: Choose option 1 in container setup"
    echo "3. 🧪 Test CI/CD: Setup GitHub Actions"
    echo "4. 🗑️ Teardown when done: ./teardown-infrastructure.sh"
    echo ""
    
    print_header "Cost Management Reminder"
    print_warning "💰 Always run ./teardown-infrastructure.sh when finished!"
    print_warning "This prevents unnecessary AWS charges."
    
else
    print_error "❌ Some tests failed. Please fix the issues before proceeding."
    echo ""
    print_error "Common fixes:"
    echo "  • Ensure Docker Desktop is running"
    echo "  • Check internet connectivity"
    echo "  • Verify project files are present"
    echo "  • Run npm install to install dependencies"
    echo ""
    exit 1
fi

# Show resource estimates
print_header "Resource Usage Estimates"
echo "💾 Container Resources:"
echo "  • CPU: Light usage (1-2 cores)"
echo "  • Memory: ~2-4 GB"
echo "  • Disk: ~5-10 GB"
echo ""
echo "💰 AWS Resources (when deployed):"
echo "  • Monthly cost: $15-50 USD"
echo "  • Hourly cost: ~$0.20/hour"
echo "  • Cost when idle: ~$0.17/hour"
echo ""
print_status "Container testing completed successfully!"