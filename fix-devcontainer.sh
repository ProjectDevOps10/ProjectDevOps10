#!/bin/bash

# iAgent DevContainer Troubleshooting Script
# Helps fix common devcontainer issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_header "iAgent DevContainer Troubleshooting"

# Check Docker
check_docker() {
    print_header "Checking Docker"
    
    if command -v docker &> /dev/null; then
        print_status "Docker CLI found"
        
        if docker info &> /dev/null; then
            print_status "Docker daemon is running"
        else
            print_error "Docker daemon is not running"
            echo "Please start Docker Desktop and try again"
            return 1
        fi
    else
        print_error "Docker not found"
        echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/"
        return 1
    fi
}

# Check VS Code extensions
check_vscode_extensions() {
    print_header "Checking VS Code Extensions"
    
    if command -v code &> /dev/null; then
        print_status "VS Code CLI found"
        
        # Check if dev containers extension is installed
        if code --list-extensions | grep -q "ms-vscode-remote.remote-containers"; then
            print_status "Dev Containers extension installed"
        else
            print_warning "Dev Containers extension not found"
            echo "Installing Dev Containers extension..."
            code --install-extension ms-vscode-remote.remote-containers
        fi
    else
        print_warning "VS Code CLI not found (this is normal if using GUI)"
    fi
}

# Check devcontainer files
check_devcontainer_files() {
    print_header "Checking DevContainer Files"
    
    if [ -f ".devcontainer/devcontainer.json" ]; then
        print_status "devcontainer.json found"
        
        # Validate JSON
        if cat .devcontainer/devcontainer.json | jq . > /dev/null 2>&1; then
            print_status "devcontainer.json is valid JSON"
        else
            print_error "devcontainer.json has invalid JSON syntax"
            echo "Please check the JSON syntax in .devcontainer/devcontainer.json"
            return 1
        fi
    else
        print_error "devcontainer.json not found"
        return 1
    fi
    
    if [ -f ".devcontainer/Dockerfile" ]; then
        print_status "Dockerfile found"
    else
        print_error "Dockerfile not found"
        return 1
    fi
}

# Clean up old containers
cleanup_old_containers() {
    print_header "Cleaning Up Old Containers"
    
    print_status "Removing old iAgent containers..."
    docker ps -a --filter "name=*iagent*" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | grep -v CONTAINER || echo "No iAgent containers found"
    
    # Remove old containers
    OLD_CONTAINERS=$(docker ps -a --filter "name=*iagent*" -q)
    if [ ! -z "$OLD_CONTAINERS" ]; then
        docker rm -f $OLD_CONTAINERS 2>/dev/null || true
        print_status "Old containers removed"
    fi
    
    # Clean up unused images
    print_status "Cleaning up unused Docker images..."
    docker image prune -f > /dev/null 2>&1 || true
}

# Create minimal devcontainer
create_minimal_devcontainer() {
    print_header "Creating Minimal DevContainer Config"
    
    cat > .devcontainer/devcontainer-minimal.json << 'EOF'
{
  "name": "iAgent DevOps (Minimal)",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:18",
  
  "features": {
    "ghcr.io/devcontainers/features/aws-cli:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {}
  },
  
  "forwardPorts": [3000, 4200],
  
  "postCreateCommand": "npm install",
  
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.vscode-typescript-next",
        "amazonwebservices.aws-toolkit-vscode",
        "ms-kubernetes-tools.vscode-kubernetes-tools"
      ]
    }
  }
}
EOF

    print_status "Minimal devcontainer config created as devcontainer-minimal.json"
    print_status "You can rename this to devcontainer.json if the main config fails"
}

# Show troubleshooting steps
show_troubleshooting_steps() {
    print_header "Troubleshooting Steps"
    
    echo "If you're still having issues, try these steps:"
    echo ""
    echo "1. 🔄 Restart Docker Desktop"
    echo "   - Quit Docker Desktop completely"
    echo "   - Wait 10 seconds"
    echo "   - Start Docker Desktop again"
    echo ""
    echo "2. 🧹 Clean VS Code cache"
    echo "   - Close VS Code"
    echo "   - Delete: ~/Library/Application Support/Code/User/globalStorage/ms-vscode-remote.remote-containers/"
    echo "   - Restart VS Code"
    echo ""
    echo "3. 🔨 Rebuild container"
    echo "   - F1 → 'Dev Containers: Rebuild Container'"
    echo "   - This forces a complete rebuild"
    echo ""
    echo "4. 📦 Try minimal container"
    echo "   - Rename devcontainer.json to devcontainer-full.json"
    echo "   - Rename devcontainer-minimal.json to devcontainer.json"
    echo "   - Try opening in container again"
    echo ""
    echo "5. 🐳 Manual Docker build"
    echo "   - cd .devcontainer"
    echo "   - docker build -t iagent-dev ."
    echo "   - docker run -it iagent-dev bash"
    echo ""
}

# Main execution
main() {
    check_docker || exit 1
    echo ""
    
    check_vscode_extensions
    echo ""
    
    check_devcontainer_files || exit 1
    echo ""
    
    cleanup_old_containers
    echo ""
    
    create_minimal_devcontainer
    echo ""
    
    show_troubleshooting_steps
    
    print_header "Quick Fix Complete!"
    print_status "Try opening the devcontainer again"
    print_status "If it still fails, use the troubleshooting steps above"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON validation..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq 2>/dev/null || echo "Please install jq manually: brew install jq"
    else
        echo "Please install jq to validate JSON files"
    fi
fi

main "$@"