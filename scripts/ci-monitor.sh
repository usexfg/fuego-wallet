#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CI Self-Healing Monitor — iterative edit → push → monitor → fix → repeat
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ./scripts/ci-monitor.sh [MAX_ITERATIONS] [WORKFLOW_FILE]
#
# Defaults: 10 iterations, desktop-build.yml
#
# Requirements: gh CLI authenticated, git push access
# ═══════════════════════════════════════════════════════════════════════════════

REPO="usexfg/fuego-wallet"
BRANCH="azorahai"
MAX_ITERS="${1:-10}"
WORKFLOW="${2:-desktop-build.yml}"
SLEEP_BETWEEN=90  # seconds between status polls

log() { echo "[ci-monitor] $(date '+%H:%M:%S')  $*"; }
err() { echo "[ci-monitor] ❌ $*" >&2; }
ok()  { echo "[ci-monitor] ✅ $*"; }

# ── Check prerequisites ──────────────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || { echo "gh CLI required: brew install gh && gh auth login"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git required"; exit 1; }

# ── Fetch latest run ID for a workflow ───────────────────────────────────────
get_latest_run_id() {
    gh run list --repo "$REPO" --branch "$BRANCH" --workflow "$WORKFLOW" \
        --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null
}

# ── Wait for run to complete, return conclusion ──────────────────────────────
wait_for_run() {
    local run_id="$1"
    local elapsed=0
    local timeout=3600  # 60 min max

    log "Waiting for run $run_id to finish..."
    while [ $elapsed -lt $timeout ]; do
        local status
        status=$(gh run view "$run_id" --repo "$REPO" --json status --jq '.status' 2>/dev/null || echo "unknown")
        local conclusion
        conclusion=$(gh run view "$run_id" --repo "$REPO" --json conclusion --jq '.conclusion' 2>/dev/null || echo "")

        if [ "$status" = "completed" ]; then
            echo "$conclusion"
            return 0
        fi
        sleep "$SLEEP_BETWEEN"
        elapsed=$((elapsed + SLEEP_BETWEEN))
        log "  still ${status}... (${elapsed}s elapsed)"
    done
    log "TIMEOUT after ${timeout}s"
    echo "timeout"
    return 1
}

# ── Fetch raw logs for the failed job ────────────────────────────────────────
fetch_failure_logs() {
    local run_id="$1"
    local failed_job_ids
    failed_job_ids=$(gh run view "$run_id" --repo "$REPO" --json jobs \
        --jq '.jobs[] | select(.conclusion == "failure") | .databaseId' 2>/dev/null)

    for jid in $failed_job_ids; do
        local outfile="/tmp/ci-failure-${run_id}-${jid}.log"
        gh run view --job "$jid" --repo "$REPO" --log > "$outfile" 2>/dev/null || true
        log "  pulled failure log → $outfile"
        echo "$outfile"
    done
}

# ── Run the dart healer on collected logs ────────────────────────────────────
heal_dart() {
    local logfile="$1"
    log "  analyzing log: $logfile"
    python3 scripts/dart-healer.py "$logfile" 2>&1 | while read -r line; do
        log "  healer: $line"
    done
}

# ── Commit and push if there are changes ─────────────────────────────────────
commit_and_push() {
    if git diff --quiet && git diff --cached --quiet; then
        log "No changes to commit"
        return 1
    fi

    git add lib/ pubspec.yaml scripts/ 2>/dev/null || true
    git commit -m "fix(ci-heal): auto-fix build errors detected in CI log" --allow-empty || true
    git push origin "$BRANCH" 2>&1 | tail -1
    log "Pushed auto-fix commit"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

PREV_RUN=""
SUCCESS_RUN=false

for ((i=1; i<=MAX_ITERS; i++)); do
    echo ""
    log "══════ ITERATION $i/$MAX_ITERS ══════"

    # Step 1: Get latest run ID
    RUN_ID=$(get_latest_run_id)
    if [ -z "$RUN_ID" ]; then
        log "No runs found — pushing to trigger one"
        git commit --allow-empty -m "ci: trigger build [auto]" 2>/dev/null || true
        git push origin "$BRANCH"
        sleep 30
        RUN_ID=$(get_latest_run_id)
    fi

    if [ "$RUN_ID" = "$PREV_RUN" ] && [ "$i" -gt 1 ]; then
        log "Run $RUN_ID hasn't changed — waiting for new push to create a fresh run"
        sleep 60
        continue
    fi
    PREV_RUN="$RUN_ID"
    log "Monitoring run: $RUN_ID"
    log "  URL: https://github.com/$REPO/actions/runs/$RUN_ID"

    # Step 2: Wait for conclusion
    CONCLUSION=$(wait_for_run "$RUN_ID")

    # Step 3: Handle result
    case "$CONCLUSION" in
        success)
            ok "BUILD IS GREEN! 🟢  Run $RUN_ID passed."
            SUCCESS_RUN=true
            break
            ;;
        failure)
            err "Build FAILED.  Gathering logs..."
            LOGFILES=($(fetch_failure_logs "$RUN_ID"))
            if [ ${#LOGFILES[@]} -eq 0 ]; then
                err "No failure logs found — waiting and retrying"
                sleep 120
                continue
            fi

            for lf in "${LOGFILES[@]}"; do
                heal_dart "$lf"
            done

            # Step 4: If fixes were applied, commit+push to trigger new build
            if commit_and_push; then
                log "Auto-fix committed.  New build will trigger automatically."
                sleep 30  # let GHA pick up the push
            else
                err "No automatic fix found.  Manual intervention needed."
                log "See $(for lf in "${LOGFILES[@]}"; do echo "  $lf"; done)"
                break
            fi
            ;;
        timeout|cancelled|skipped)
            err "Run ended with: $CONCLUSION"
            sleep 120
            ;;
        *)
            err "Unknown conclusion: $CONCLUSION"
            sleep 60
            ;;
    esac
done

# ── Final Report ─────────────────────────────────────────────────────────────
echo ""
if [ "$SUCCESS_RUN" = true ]; then
    ok "Self-healing CI complete.  Build is green."
    exit 0
else
    err "Self-healing CI reached max iterations ($MAX_ITERS) without a green build."
    exit 1
fi
