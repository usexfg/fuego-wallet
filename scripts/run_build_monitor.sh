#!/bin/bash

# Build Monitor Runner Script
# Runs the build monitoring and auto-fixing process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Fuego Desktop Build Monitor ===${NC}"
echo "Repository: colinritman/fuego-desktop"
echo "Branch: master"
echo ""

# Check if we're in the right directory
if [ ! -f "$PROJECT_DIR/CMakeLists.txt" ]; then
    echo "Error: Not in fuego-wallet project directory"
    echo "Please run this script from the fuego-wallet directory"
    exit 1
fi

# Make scripts executable
chmod +x "$SCRIPT_DIR/monitor_builds.sh"
chmod +x "$SCRIPT_DIR/auto_fix_builds.py"

echo -e "${YELLOW}Choose monitoring mode:${NC}"
echo "1) Monitor only (check status, suggest fixes)"
echo "2) Auto-fix mode (monitor + automatically apply fixes)"
echo "3) Quick check (one-time status check)"
echo ""

read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo -e "${GREEN}Starting monitor-only mode...${NC}"
        "$SCRIPT_DIR/monitor_builds.sh"
        ;;
    2)
        echo -e "${GREEN}Starting auto-fix mode...${NC}"
        echo "This will automatically fix common build issues and push changes."
        read -p "Continue? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            python3 "$SCRIPT_DIR/auto_fix_builds.py" --max-iterations 3
        else
            echo "Cancelled."
            exit 0
        fi
        ;;
    3)
        echo -e "${GREEN}Running quick status check...${NC}"
        # Quick status check
        gh api repos/colinritman/fuego-desktop/actions/runs \
            --jq '.workflow_runs[] | select(.head_branch == "master") | {
                name: .name,
                status: .status,
                conclusion: .conclusion,
                created_at: .created_at
            }' | jq -s 'sort_by(.created_at) | reverse | .[0:5]' | \
            jq -r '.[] | "\(.name): \(.status) (\(.conclusion // "N/A")) - \(.created_at)"'
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo -e "${GREEN}Build monitor finished.${NC}"
