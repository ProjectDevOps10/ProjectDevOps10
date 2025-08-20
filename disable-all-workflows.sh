#!/bin/bash

# Disable All GitHub Actions Workflows Script
# This script comments out all workflow files to stop CI/CD triggers

set -e

echo "🚫 Disabling all GitHub Actions workflows..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if we're in the right directory
if [ ! -d ".github/workflows" ]; then
    print_error "This script must be run from the project root directory"
    exit 1
fi

# Backup original workflows
BACKUP_DIR=".github/workflows/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
print_status "Creating backup in $BACKUP_DIR"

# Copy all workflow files to backup
cp .github/workflows/*.yml "$BACKUP_DIR/"
print_status "Backed up all workflow files"

# Function to comment out a workflow file
comment_out_workflow() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    print_status "Disabling workflow: $(basename "$file")"
    
    # Add comment header
    echo "# DISABLED: This workflow has been automatically disabled" > "$temp_file"
    echo "# Disabled on: $(date)" >> "$temp_file"
    echo "# To re-enable: Remove the 'DISABLED:' comments and uncomment the workflow" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Comment out the entire file content
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*$ ]]; then
            # Empty line
            echo "$line" >> "$temp_file"
        else
            # Comment out non-empty lines
            echo "# $line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace original with commented version
    mv "$temp_file" "$file"
}

# Disable all workflow files
for workflow_file in .github/workflows/*.yml; do
    if [ -f "$workflow_file" ]; then
        comment_out_workflow "$workflow_file"
    fi
done

print_status "✅ All workflows have been disabled!"

echo ""
echo "📋 Summary of changes:"
echo "   • All .github/workflows/*.yml files have been commented out"
echo "   • Original files backed up to: $BACKUP_DIR"
echo "   • CI/CD will no longer trigger on pushes"
echo ""
echo "🔄 To re-enable workflows:"
echo "   1. Remove the 'DISABLED:' comments from workflow files"
echo "   2. Or restore from backup: cp $BACKUP_DIR/* .github/workflows/"
echo ""
echo "🧹 Next steps for complete cleanup:"
echo "   1. Run: ./teardown-infrastructure.sh (to delete AWS resources)"
echo "   2. Disable GitHub Pages in repository settings"
echo "   3. Result: Zero charges, clean slate!"

echo ""
print_status "🎯 All GitHub Actions workflows are now disabled!"
