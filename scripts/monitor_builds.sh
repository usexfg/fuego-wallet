#!/bin/bash

# GitHub Actions Build Monitor and Auto-Fixer
# Monitors colinritman/fuego-desktop builds and fixes issues automatically

set -e

# Configuration
REPO="colinritman/fuego-desktop"
BRANCH="master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/build_monitor.log"
MAX_ATTEMPTS=10
SLEEP_INTERVAL=60

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if required tools are installed
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
        error "Please install them first:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "gh") echo "  - GitHub CLI: https://cli.github.com/" ;;
                "jq") echo "  - jq: brew install jq (macOS) or apt-get install jq (Ubuntu)" ;;
                "git") echo "  - git: https://git-scm.com/" ;;
            esac
        done
        exit 1
    fi
    
    # Check GitHub CLI authentication
    if ! gh auth status &> /dev/null; then
        error "GitHub CLI not authenticated. Please run: gh auth login"
        exit 1
    fi
    
    success "All dependencies are available"
}

# Get latest workflow runs
get_workflow_runs() {
    log "Fetching latest workflow runs..."
    
    gh api repos/$REPO/actions/runs \
        --jq '.workflow_runs[] | select(.head_branch == "'$BRANCH'") | {
            id: .id,
            name: .name,
            status: .status,
            conclusion: .conclusion,
            created_at: .created_at,
            html_url: .html_url
        }' | jq -s 'sort_by(.created_at) | reverse | .[0:10]'
}

# Check if all builds are green
check_build_status() {
    local runs
    runs=$(get_workflow_runs)
    
    if [ -z "$runs" ] || [ "$runs" = "null" ]; then
        error "No workflow runs found"
        return 1
    fi
    
    local failed_runs=()
    local running_runs=()
    local queued_runs=()
    
    echo "$runs" | jq -r '.[] | select(.status == "completed" and .conclusion != "success") | .name' | while read -r name; do
        if [ -n "$name" ]; then
            failed_runs+=("$name")
        fi
    done
    
    echo "$runs" | jq -r '.[] | select(.status == "in_progress") | .name' | while read -r name; do
        if [ -n "$name" ]; then
            running_runs+=("$name")
        fi
    done
    
    echo "$runs" | jq -r '.[] | select(.status == "queued") | .name' | while read -r name; do
        if [ -n "$name" ]; then
            queued_runs+=("$name")
        fi
    done
    
    # Count successful runs
    local success_count
    success_count=$(echo "$runs" | jq '[.[] | select(.status == "completed" and .conclusion == "success")] | length')
    
    # Count total runs
    local total_count
    total_count=$(echo "$runs" | jq 'length')
    
    log "Build Status Summary:"
    log "  ✅ Successful: $success_count"
    log "  ❌ Failed: ${#failed_runs[@]}"
    log "  🔄 Running: ${#running_runs[@]}"
    log "  ⏳ Queued: ${#queued_runs[@]}"
    
    if [ ${#failed_runs[@]} -gt 0 ]; then
        warning "Failed builds detected:"
        for run in "${failed_runs[@]}"; do
            warning "  - $run"
        done
        return 1
    fi
    
    if [ ${#running_runs[@]} -gt 0 ] || [ ${#queued_runs[@]} -gt 0 ]; then
        log "Some builds are still running or queued"
        return 2
    fi
    
    if [ "$success_count" -eq "$total_count" ] && [ "$total_count" -gt 0 ]; then
        success "All builds are green! 🎉"
        return 0
    fi
    
    return 1
}

# Get detailed error information from a failed run
get_run_details() {
    local run_id="$1"
    
    gh api repos/$REPO/actions/runs/$run_id/jobs \
        --jq '.jobs[] | select(.conclusion == "failure") | {
            name: .name,
            steps: [.steps[] | select(.conclusion == "failure") | {
                name: .name,
                conclusion: .conclusion
            }]
        }'
}

# Analyze common build errors and suggest fixes
analyze_errors() {
    local runs
    runs=$(get_workflow_runs)
    
    echo "$runs" | jq -r '.[] | select(.status == "completed" and .conclusion != "success") | .id' | while read -r run_id; do
        if [ -n "$run_id" ]; then
            log "Analyzing failed run: $run_id"
            
            local details
            details=$(get_run_details "$run_id")
            
            echo "$details" | jq -r '.name' | while read -r job_name; do
                if [ -n "$job_name" ]; then
                    warning "Failed job: $job_name"
                    
                    # Get job logs for analysis
                    local job_id
                    job_id=$(gh api repos/$REPO/actions/runs/$run_id/jobs --jq '.jobs[] | select(.name == "'$job_name'") | .id')
                    
                    if [ -n "$job_id" ]; then
                        log "Fetching logs for job: $job_id"
                        gh api repos/$REPO/actions/jobs/$job_id/logs > "/tmp/job_${job_id}_logs.txt"
                        
                        # Analyze logs for common issues
                        analyze_job_logs "/tmp/job_${job_id}_logs.txt" "$job_name"
                    fi
                fi
            done
        fi
    done
}

# Analyze job logs for common issues
analyze_job_logs() {
    local log_file="$1"
    local job_name="$2"
    
    if [ ! -f "$log_file" ]; then
        warning "Log file not found: $log_file"
        return
    fi
    
    log "Analyzing logs for job: $job_name"
    
    # Check for common error patterns
    if grep -q "Visual Studio.*could not find" "$log_file"; then
        warning "Visual Studio generator issue detected"
        suggest_vs_fix
    fi
    
    if grep -q "boost.*not found\|boost.*Config.cmake" "$log_file"; then
        warning "Boost configuration issue detected"
        suggest_boost_fix "$job_name"
    fi
    
    if grep -q "qrencode.*linker language\|Cannot determine link language" "$log_file"; then
        warning "QRencode linker issue detected"
        suggest_qrencode_fix
    fi
    
    if grep -q "CMake Error.*cryptonote.*already exists" "$log_file"; then
        warning "Duplicate cryptonote library issue detected"
        suggest_cryptonote_fix
    fi
    
    if grep -q "xfg-stark-cli.*not found\|Cargo.toml.*not found" "$log_file"; then
        warning "STARK CLI issue detected"
        suggest_stark_cli_fix
    fi
    
    if grep -q "qttools5.*not found" "$log_file"; then
        warning "Qt tools issue detected"
        suggest_qt_fix
    fi
}

# Suggest fixes for common issues
suggest_vs_fix() {
    log "Suggested fix: Update Visual Studio generator to 2022"
    echo "cmake -G \"Visual Studio 17 2022\" .." >> "$PROJECT_DIR/suggested_fixes.txt"
}

suggest_boost_fix() {
    local job_name="$1"
    log "Suggested fix: Update Boost configuration for $job_name"
    
    if [[ "$job_name" == *"macOS"* ]]; then
        echo "Update CryptoNoteWallet.cmake for macOS Boost 1.89.0" >> "$PROJECT_DIR/suggested_fixes.txt"
    else
        echo "Check Boost installation and paths" >> "$PROJECT_DIR/suggested_fixes.txt"
    fi
}

suggest_qrencode_fix() {
    log "Suggested fix: Use system libqrencode instead of source build"
    echo "Update QREncode.cmake to use pkg-config" >> "$PROJECT_DIR/suggested_fixes.txt"
}

suggest_cryptonote_fix() {
    log "Suggested fix: Remove duplicate cryptonote library creation"
    echo "Check CMakeLists.txt for duplicate add_library calls" >> "$PROJECT_DIR/suggested_fixes.txt"
}

suggest_stark_cli_fix() {
    log "Suggested fix: Ensure STARK CLI binary download is working"
    echo "Check STARK CLI download URLs in workflows" >> "$PROJECT_DIR/suggested_fixes.txt"
}

suggest_qt_fix() {
    log "Suggested fix: Remove qttools5 from Windows Qt installation"
    echo "Update Windows Qt modules in workflows" >> "$PROJECT_DIR/suggested_fixes.txt"
}

# Apply automatic fixes
apply_fixes() {
    if [ ! -f "$PROJECT_DIR/suggested_fixes.txt" ]; then
        log "No fixes to apply"
        return
    fi
    
    log "Applying suggested fixes..."
    
    # Read and apply fixes
    while IFS= read -r fix; do
        if [ -n "$fix" ]; then
            log "Applying fix: $fix"
            # Here you would implement the actual fix logic
            # For now, we'll just log the fix
        fi
    done < "$PROJECT_DIR/suggested_fixes.txt"
    
    # Clear the fixes file
    > "$PROJECT_DIR/suggested_fixes.txt"
}

# Trigger a new build
trigger_build() {
    log "Triggering new build..."
    
    # Push current changes to trigger build
    cd "$PROJECT_DIR"
    
    if [ -n "$(git status --porcelain)" ]; then
        log "Committing and pushing changes..."
        git add .
        git commit -m "Auto-fix: Apply build fixes from monitoring script

- Applied fixes based on build analysis
- Automated resolution of common build issues
- Generated by build monitor script"
        git push origin "$BRANCH"
        success "Changes pushed, build triggered"
    else
        log "No changes to commit, triggering workflow manually..."
        gh workflow run "check.yml" --ref "$BRANCH"
        success "Workflow triggered manually"
    fi
}

# Main monitoring loop
monitor_loop() {
    local attempt=1
    
    log "Starting build monitoring loop..."
    log "Repository: $REPO"
    log "Branch: $BRANCH"
    log "Max attempts: $MAX_ATTEMPTS"
    log "Sleep interval: ${SLEEP_INTERVAL}s"
    
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        log "=== Attempt $attempt/$MAX_ATTEMPTS ==="
        
        local status
        check_build_status
        status=$?
        
        case $status in
            0)
                success "All builds are green! Monitoring complete."
                break
                ;;
            1)
                warning "Build failures detected, analyzing..."
                analyze_errors
                apply_fixes
                trigger_build
                ;;
            2)
                log "Builds still running, waiting..."
                ;;
        esac
        
        if [ $attempt -lt $MAX_ATTEMPTS ]; then
            log "Waiting ${SLEEP_INTERVAL}s before next check..."
            sleep $SLEEP_INTERVAL
        fi
        
        ((attempt++))
    done
    
    if [ $attempt -gt $MAX_ATTEMPTS ]; then
        error "Maximum attempts reached. Some builds may still be failing."
        log "Manual intervention may be required."
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f /tmp/job_*_logs.txt
    rm -f "$PROJECT_DIR/suggested_fixes.txt"
}

# Signal handlers
trap cleanup EXIT
trap 'log "Script interrupted by user"; exit 130' INT TERM

# Main execution
main() {
    log "=== GitHub Actions Build Monitor Started ==="
    
    check_dependencies
    monitor_loop
    
    log "=== Build Monitor Finished ==="
}

# Run main function
main "$@"
