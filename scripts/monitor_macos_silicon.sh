#!/bin/bash

# macOS Apple Silicon Build Monitor
echo "🍎 Starting macOS Apple Silicon Build Monitor..."
echo "⏰ Checking macOS Silicon builds every 2 minutes"
echo "=================================================="

while true; do
    echo ""
    echo "📊 $(date): Checking macOS Apple Silicon build status..."
    
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
            echo "✅ macOS Apple Silicon build is GREEN! 🎉"
            echo "🎯 Mission accomplished!"
            break
        else
            echo "❌ macOS Apple Silicon build failed with conclusion: $RUN_CONCLUSION"
            echo "🔧 Analyzing macOS Apple Silicon failure..."
            
            # Get macOS Apple Silicon job
            MACOS_JOB=$(gh run view $LATEST_RUN --json jobs --jq '.jobs[] | select(.name == "macOS Apple Silicon") | .databaseId')
            
            if [ -n "$MACOS_JOB" ]; then
                echo "📋 macOS Apple Silicon Job ID: $MACOS_JOB"
                
                # Get failed step logs
                echo "📄 Getting logs for macOS Apple Silicon..."
                gh run view --log-failed --job=$MACOS_JOB | tail -100
                
                echo ""
                echo "🔍 Analyzing macOS Apple Silicon error patterns..."
                
                # Check for Qt5 errors
                if gh run view --log-failed --job=$MACOS_JOB | grep -q "Qt5Gui"; then
                    echo "🎯 Detected Qt5Gui error on macOS Apple Silicon"
                    echo "💡 Need to fix Qt5 configuration for macOS Apple Silicon"
                fi
                
                # Check for linking errors
                if gh run view --log-failed --job=$MACOS_JOB | grep -q "undefined reference"; then
                    echo "🎯 Detected linking error on macOS Apple Silicon"
                    echo "💡 Need to add missing library to CMakeLists.txt"
                fi
                
                # Check for CMake errors
                if gh run view --log-failed --job=$MACOS_JOB | grep -q "CMake Error"; then
                    echo "🎯 Detected CMake configuration error on macOS Apple Silicon"
                    echo "💡 Need to fix CMake configuration"
                fi
                
                # Check for Homebrew errors
                if gh run view --log-failed --job=$MACOS_JOB | grep -q "brew"; then
                    echo "🎯 Detected Homebrew error on macOS Apple Silicon"
                    echo "💡 Need to fix Homebrew package installation"
                fi
            fi
            
            echo ""
            echo "🛠️  Ready to fix macOS Apple Silicon errors. Press Ctrl+C to stop monitoring and fix manually."
            echo "⏰ Will continue monitoring in 2 minutes..."
        fi
    else
        echo "⏳ macOS Apple Silicon build still in progress..."
    fi
    
    echo "⏰ Waiting 2 minutes before next check..."
    sleep 120
done

echo "🏁 macOS Apple Silicon build monitoring complete!"
