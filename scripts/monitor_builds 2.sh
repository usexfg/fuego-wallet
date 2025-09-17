#!/bin/bash

# Monitor GitHub Actions builds and fix errors
# Runs every 2 minutes until all builds are green

echo "🔍 Starting GitHub Actions build monitor..."
echo "⏰ Checking builds every 2 minutes until all are green"
echo "=================================================="

while true; do
    echo ""
    echo "📊 $(date): Checking build status..."
    
    # Get the latest run
    LATEST_RUN=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
    
    if [ "$LATEST_RUN" = "null" ] || [ -z "$LATEST_RUN" ]; then
        echo "❌ No builds found"
        sleep 120
        continue
    fi
    
    echo "🔍 Checking run ID: $LATEST_RUN"
    
    # Get run status
    RUN_STATUS=$(gh run view $LATEST_RUN --json status --jq '.status')
    RUN_CONCLUSION=$(gh run view $LATEST_RUN --json conclusion --jq '.conclusion')
    
    echo "📈 Run Status: $RUN_STATUS"
    echo "📈 Run Conclusion: $RUN_CONCLUSION"
    
    if [ "$RUN_STATUS" = "completed" ]; then
        if [ "$RUN_CONCLUSION" = "success" ]; then
            echo "✅ All builds are GREEN! 🎉"
            echo "🎯 Mission accomplished!"
            break
        else
            echo "❌ Build failed with conclusion: $RUN_CONCLUSION"
            echo "🔧 Analyzing failures..."
            
            # Get failed jobs
            FAILED_JOBS=$(gh run view $LATEST_RUN --json jobs --jq '.jobs[] | select(.conclusion == "failure") | .name')
            
            echo "💥 Failed jobs:"
            echo "$FAILED_JOBS"
            
            # Check specific job logs for errors
            for job_name in $FAILED_JOBS; do
                echo ""
                echo "🔍 Analyzing job: $job_name"
                
                # Get job ID
                JOB_ID=$(gh run view $LATEST_RUN --json jobs --jq ".jobs[] | select(.name == \"$job_name\") | .databaseId")
                
                if [ -n "$JOB_ID" ]; then
                    echo "📋 Job ID: $JOB_ID"
                    
                    # Get failed step logs
                    echo "📄 Getting logs for failed steps..."
                    gh run view --log-failed --job=$JOB_ID | tail -50
                    
                    # Analyze common error patterns
                    echo ""
                    echo "🔍 Analyzing error patterns..."
                    
                    # Check for Qt5 errors
                    if gh run view --log-failed --job=$JOB_ID | grep -q "Qt5Gui"; then
                        echo "🎯 Detected Qt5Gui error - this is our known issue"
                        echo "💡 Need to fix Qt5 configuration"
                    fi
                    
                    # Check for linking errors
                    if gh run view --log-failed --job=$JOB_ID | grep -q "undefined reference"; then
                        echo "🎯 Detected linking error - missing library"
                        echo "💡 Need to add missing library to CMakeLists.txt"
                    fi
                    
                    # Check for CMake errors
                    if gh run view --log-failed --job=$JOB_ID | grep -q "CMake Error"; then
                        echo "🎯 Detected CMake configuration error"
                        echo "💡 Need to fix CMake configuration"
                    fi
                fi
            done
            
            echo ""
            echo "🛠️  Ready to fix errors. Press Ctrl+C to stop monitoring and fix manually."
            echo "⏰ Will continue monitoring in 2 minutes..."
        fi
    else
        echo "⏳ Build still in progress..."
    fi
    
    echo "⏰ Waiting 2 minutes before next check..."
    sleep 120
done

echo "🏁 Build monitoring complete!"