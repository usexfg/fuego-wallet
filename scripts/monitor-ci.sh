#!/bin/bash
# CI monitor for fuego-wallet desktop builds
# Usage: ./scripts/monitor-ci.sh [--watch] [--timeout 3600]

REPO="usexfg/fuego-wallet"
BRANCH="azorahai"
WORKFLOW="desktop-build.yml"
TIMEOUT=3600  # 1 hour default
WATCH=false
INTERVAL=60

while [[ $# -gt 0 ]]; do
  case $1 in
    --watch) WATCH=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Usage: $0 [--watch] [--timeout SECONDS]"; exit 1 ;;
  esac
done

START=$(date +%s)
echo "🔍 Monitoring $REPO @ $BRANCH :: $WORKFLOW"
echo "   Timeout: ${TIMEOUT}s  |  Poll interval: ${INTERVAL}s"
echo ""

check() {
  local RUN_ID
  RUN_ID=$(gh run list --branch "$BRANCH" -R "$REPO" --workflow "$WORKFLOW" --limit 1 --json databaseId,status,conclusion -q '.[0] | "\(.databaseId)|\(.status)|\(.conclusion)"')
  local ID STATUS CONCL
  ID=$(echo "$RUN_ID" | cut -d'|' -f1)
  STATUS=$(echo "$RUN_ID" | cut -d'|' -f2)
  CONCL=$(echo "$RUN_ID" | cut -d'|' -f3)

  echo "$(date '+%H:%M:%S')  Run $ID  status=$STATUS  conclusion=${CONCL:-pending}"

  if [[ "$STATUS" == "completed" ]]; then
    if [[ "$CONCL" == "success" ]]; then
      echo ""
      echo "✅ BUILD GREEN — https://github.com/$REPO/actions/runs/$ID"
      return 0
    else
      # Show failed step
      echo "❌ FAILED:"
      gh run view "$ID" -R "$REPO" --log-failed 2>&1 | grep -E "error:|Error:|fatal|ERROR:|Process completed" | head -5
      echo "   Full log: https://github.com/$REPO/actions/runs/$ID"
      return 1
    fi
  fi
  return 2  # still running
}

# First check: trigger a new build if requested
if $WATCH; then
  echo "🚀 Triggering new build..."
  gh workflow run "$WORKFLOW" --ref "$BRANCH" -R "$REPO"
  echo ""
  sleep 10
fi

while true; do
  check
  RET=$?
  if [[ $RET -eq 0 ]]; then
    exit 0  # green
  fi
  # If not watching and not green, exit with failure
  if ! $WATCH; then
    if [[ $RET -eq 1 ]]; then
      exit 1
    fi
  fi

  # Check timeout
  NOW=$(date +%s)
  if [[ $((NOW - START)) -gt $TIMEOUT ]]; then
    echo "⏰ Timeout reached after ${TIMEOUT}s"
    exit 1
  fi

  sleep "$INTERVAL"
done
