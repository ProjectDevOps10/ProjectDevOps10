#!/bin/bash

# iAgent DevOps Container Startup Script
# Runs when the container starts

echo "🐳 Starting iAgent DevOps Container..."

# Source bashrc to get all aliases and environment
source /home/devuser/.bashrc

# Check if we're in the correct directory
if [ ! -f "/workspace/package.json" ]; then
    echo "⚠️ Warning: Not in iAgent project directory"
    echo "Expected to find package.json in /workspace"
fi

# Display container information
/home/devuser/show-versions.sh

echo ""
echo "📁 Workspace: /workspace"
echo "🏠 Home: /home/devuser"
echo ""
echo "🚀 Next steps:"
echo "  1. Run: ./container-setup.sh to configure AWS"
echo "  2. Run: ./quick-devops-setup.sh for full deployment"
echo "  3. Run: ./teardown-infrastructure.sh when done"
echo ""