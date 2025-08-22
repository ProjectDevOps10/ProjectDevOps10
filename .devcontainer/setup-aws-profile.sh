#!/bin/bash

# Setup AWS Profile Script for iAgent DevContainer
# This script sets up AWS credentials globally so they're available in every shell

set -e

echo "🔧 Setting up global AWS profile..."

# Create global profile directory if it doesn't exist
sudo mkdir -p /etc/profile.d

# Create a profile script that loads AWS credentials
cat > /tmp/aws-profile.sh << 'EOF'
# AWS Profile for iAgent DevContainer
# This file is automatically sourced by all shells

# Load AWS credentials from .secrets file
if [ -f "/workspaces/iAgent/.secrets" ]; then
    export $(cat /workspaces/iAgent/.secrets | grep -v '^#' | xargs)
    
    # Set default region if not already set
    if [ -z "$AWS_DEFAULT_REGION" ]; then
        export AWS_DEFAULT_REGION="eu-central-1"
    fi
    
    # Verify credentials are loaded
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "✅ AWS credentials loaded from .secrets file"
    fi
else
    echo "⚠️  Warning: .secrets file not found. AWS credentials not loaded."
fi
EOF

# Move to global profile directory
sudo mv /tmp/aws-profile.sh /etc/profile.d/aws-profile.sh

# Make it executable
sudo chmod +x /etc/profile.d/aws-profile.sh

# Also add to .bashrc for the current user
echo "" >> /home/node/.bashrc
echo "# AWS Profile for iAgent" >> /home/node/.bashrc
echo "source /etc/profile.d/aws-profile.sh" >> /home/node/.bashrc

echo "✅ AWS profile setup complete!"
echo "   Credentials will be automatically loaded in all new shell sessions"
