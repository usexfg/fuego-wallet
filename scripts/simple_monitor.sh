#!/bin/bash

# Simple build monitor - checks builds every 2 minutes
echo "🔍 Starting build monitor..."
echo "⏰ Checking builds every 2 minutes"
echo "=================================================="

while true; do
    echo ""
    echo "📊 $(date): Checking build status..."
    
    # Get the latest 3 runs
    LATEST_RUNS=$(gh run list --limit 3 --json databaseId,status,conclusion,title --jq '.[] | "\(.databaseId) \(.status) \(.conclusion) \(.title)"')
    
    if [ -z "$LATEST_RUNS" ]; then
        echo "❌ No builds found"
        sleep 120
        continue
    fi
    
    echo "🔍 Latest builds:"
    echo "$LATEST_RUNS"
    
    # Check if any builds have completed
    COMPLETED_BUILDS=$(echo "$LATEST_RUNS" | grep "completed")
    if [ -n "$COMPLETED_BUILDS" ]; then
        echo ""
        echo "✅ Completed builds found:"
        echo "$COMPLETED_BUILDS"
        
        # Check if any are successful
        SUCCESS_BUILDS=$(echo "$COMPLETED_BUILDS" | grep "success")
        if [ -n "$SUCCESS_BUILDS" ]; then
            echo ""
            echo "🎉 SUCCESS! Some builds are GREEN!"
            echo "$SUCCESS_BUILDS"
        else
            echo ""
            echo "❌ All completed builds failed - need to fix errors"
        fi
    else
        echo "⏳ All builds still in progress..."
    fi
    
    echo "⏰ Waiting 2 minutes before next check..."
    sleep 120
done
