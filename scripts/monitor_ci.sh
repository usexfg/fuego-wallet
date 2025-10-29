#!/bin/bash

# GitHub Actions CI Monitor Script for XFG Wallet
# Monitors workflows, shows status, and downloads logs for troubleshooting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO="usexfg/xfg-wallet"
WORKFLOWS=(
  "xfg-wallet-desktop.yml"
  "android-release.yml"
  "ios-release.yml"
)

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
  echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
  echo "Install it with: brew install gh"
  exit 1
fi

# Function to check authentication
check_auth() {
  if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Not authenticated with GitHub. Please run: gh auth login${NC}"
    echo "Attempting to authenticate..."
    gh auth login
  fi
}

# Function to list recent workflow runs
list_runs() {
  echo -e "${BLUE}Recent workflow runs for ${REPO}:${NC}\n"
  
  for workflow in "${WORKFLOWS[@]}"; do
    echo -e "${BLUE}Workflow: ${workflow}${NC}"
    gh run list --repo "$REPO" --workflow "$workflow" --limit 5
    echo ""
  done
}

# Function to show details of a specific run
show_run_details() {
  local run_id=$1
  if [ -z "$run_id" ]; then
    echo -e "${RED}Error: Run ID required${NC}"
    echo "Usage: $0 details <run_id>"
    exit 1
  fi
  
  echo -e "${BLUE}Details for run ${run_id}:${NC}\n"
  gh run view "$run_id" --repo "$REPO"
}

# Function to watch a running workflow
watch_run() {
  local run_id=$1
  if [ -z "$run_id" ]; then
    echo -e "${RED}Error: Run ID required${NC}"
    echo "Usage: $0 watch <run_id>"
    exit 1
  fi
  
  echo -e "${BLUE}Watching run ${run_id}...${NC}"
  gh run watch "$run_id" --repo "$REPO"
}

# Function to download logs for failed jobs
download_failed_logs() {
  local run_id=$1
  local output_dir=${2:-"ci_logs"}
  
  if [ -z "$run_id" ]; then
    echo -e "${RED}Error: Run ID required${NC}"
    echo "Usage: $0 logs <run_id> [output_dir]"
    exit 1
  fi
  
  echo -e "${BLUE}Downloading logs for run ${run_id} to ${output_dir}...${NC}"
  mkdir -p "$output_dir"
  
  gh run view "$run_id" --repo "$REPO" --log > "$output_dir/run_${run_id}.log"
  gh run view "$run_id" --repo "$REPO" --log-failed > "$output_dir/run_${run_id}_failed.log"
  
  echo -e "${GREEN}Logs saved to ${output_dir}/${NC}"
}

# Function to show running workflows
show_running() {
  echo -e "${BLUE}Currently running workflows:${NC}\n"
  
  for workflow in "${WORKFLOWS[@]}"; do
    gh run list --repo "$REPO" --workflow "$workflow" --status in_progress --limit 3
  done
}

# Function to restart a failed workflow
restart_workflow() {
  local run_id=$1
  if [ -z "$run_id" ]; then
    echo -e "${RED}Error: Run ID required${NC}"
    echo "Usage: $0 restart <run_id>"
    exit 1
  fi
  
  echo -e "${YELLOW}Restarting workflow run ${run_id}...${NC}"
  gh run rerun "$run_id" --repo "$REPO"
  echo -e "${GREEN}Workflow restarted${NC}"
}

# Function to show workflow summary
show_summary() {
  echo -e "${BLUE}=== GitHub Actions CI Summary ===${NC}\n"
  
  for workflow in "${WORKFLOWS[@]}"; do
    echo -e "${BLUE}${workflow}:${NC}"
    gh run list --repo "$REPO" --workflow "$workflow" --limit 1 --json status,conclusion,createdAt \
      | jq -r '.[0] | "  Status: \(.status) | Conclusion: \(.conclusion // "N/A") | Created: \(.createdAt)"'
    echo ""
  done
}

# Function to check for new runs
check_new_runs() {
  echo -e "${BLUE}Checking for new workflow runs...${NC}\n"
  
  for workflow in "${WORKFLOWS[@]}"; do
    local latest=$(gh run list --repo "$REPO" --workflow "$workflow" --limit 1 --json databaseId,status,conclusion,createdAt \
      | jq -r '.[0] | "\(.databaseId)|\(.status)|\(.conclusion // "N/A")|\(.createdAt)"')
    
    local run_id=$(echo "$latest" | cut -d'|' -f1)
    local status=$(echo "$latest" | cut -d'|' -f2)
    local conclusion=$(echo "$latest" | cut -d'|' -f3)
    local created=$(echo "$latest" | cut -d'|' -f4)
    
    if [ "$status" == "completed" ]; then
      if [ "$conclusion" == "success" ]; then
        echo -e "${GREEN}${workflow}: ${conclusion}${NC}"
      else
        echo -e "${RED}${workflow}: ${conclusion}${NC}"
      fi
    elif [ "$status" == "in_progress" ] || [ "$status" == "queued" ]; then
      echo -e "${YELLOW}${workflow}: ${status}${NC}"
    fi
  done
}

# Function to open workflows in browser
open_browser() {
  local workflow=${1:-""}
  if [ -z "$workflow" ]; then
    gh repo view "$REPO" --web
  else
    # Open specific workflow
    gh run list --repo "$REPO" --workflow "$workflow" --limit 1 --json url \
      | jq -r '.[0].url' \
      | xargs open
  fi
}

# Function to show build times
show_build_times() {
  echo -e "${BLUE}Average build times:${NC}\n"
  
  for workflow in "${WORKFLOWS[@]}"; do
    gh run list --repo "$REPO" --workflow "$workflow" --limit 5 --json workflowName,status,conclusion,createdAt,updatedAt \
      | jq -r '.[] | select(.conclusion == "success") | "\(.createdAt)|\(.updatedAt)"' \
      | while IFS='|' read -r start end; do
          if [ ! -z "$start" ] && [ ! -z "$end" ]; then
            start_t=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S+00:00" "$start" +%s)
            end_t=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S+00:00" "$end" +%s)
            if [ ! -z "$start_t" ] && [ ! -z "$end_t" ]; then
              duration=$((end_t - start_t))
              echo "$workflow: $duration seconds"
            fi
          fi
        done
  done
}

# Main menu
show_help() {
  cat << EOF
${BLUE}GitHub Actions CI Monitor for XFG Wallet${NC}

Usage: $0 <command> [options]

Commands:
  list              List recent workflow runs
  running           Show currently running workflows
  summary           Show workflow status summary
  check             Check for new runs and their status
  details <id>      Show details for a specific run
  watch <id>        Watch a running workflow in real-time
  logs <id> [dir]   Download logs from a failed run
  restart <id>      Restart a failed workflow
  browser [workflow] Open workflows in browser
  times             Show average build times
  help              Show this help message

Examples:
  $0 list                           # List all recent runs
  $0 check                          # Check current status
  $0 details 123456789              # Show details for run ID
  $0 watch 123456789                # Watch running workflow
  $0 logs 123456789 ./logs          # Download logs to ./logs
  $0 restart 123456789               # Restart failed workflow

EOF
}

# Main script logic
main() {
  check_auth
  
  case "$1" in
    list)
      list_runs
      ;;
    running)
      show_running
      ;;
    summary)
      show_summary
      ;;
    check)
      check_new_runs
      ;;
    details)
      show_run_details "$2"
      ;;
    watch)
      watch_run "$2"
      ;;
    logs)
      download_failed_logs "$2" "$3"
      ;;
    restart)
      restart_workflow "$2"
      ;;
    browser)
      open_browser "$2"
      ;;
    times)
      show_build_times
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      if [ -z "$1" ]; then
        check_new_runs
      else
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
      fi
      ;;
  esac
}

main "$@"

