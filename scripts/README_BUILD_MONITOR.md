# GitHub Actions Build Monitor & Auto-Fixer

This directory contains scripts to automatically monitor and fix GitHub Actions build issues for the `colinritman/fuego-desktop` repository.

## Overview

The build monitoring system consists of three main components:

1. **`monitor_builds.sh`** - Bash script for monitoring build status and suggesting fixes
2. **`auto_fix_builds.py`** - Python script for automatically applying fixes
3. **`run_build_monitor.sh`** - Runner script that provides an easy interface

## Prerequisites

### Required Tools

- **GitHub CLI** (`gh`) - For accessing GitHub API
- **jq** - For JSON parsing
- **git** - For version control
- **Python 3** - For the auto-fixer script

### Installation

#### macOS
```bash
brew install gh jq python3
gh auth login
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install gh jq python3 python3-pip git
gh auth login
```

#### Windows (WSL or Git Bash)
```bash
# Install via package manager or download from official sites
gh auth login
```

## Usage

### Quick Start

Run the interactive monitor:

```bash
cd fuego-wallet/scripts
./run_build_monitor.sh
```

### Manual Usage

#### Monitor Only (Suggest Fixes)
```bash
./monitor_builds.sh
```

#### Auto-Fix Mode
```bash
python3 auto_fix_builds.py --max-iterations 5
```

#### Quick Status Check
```bash
gh api repos/colinritman/fuego-desktop/actions/runs \
  --jq '.workflow_runs[] | select(.head_branch == "master") | {
      name: .name,
      status: .status,
      conclusion: .conclusion,
      created_at: .created_at
  }' | jq -s 'sort_by(.created_at) | reverse | .[0:5]'
```

## Features

### Build Monitoring

- **Real-time Status**: Monitors all workflow runs for the master branch
- **Failure Detection**: Identifies failed builds and analyzes error logs
- **Status Summary**: Provides overview of successful, failed, running, and queued builds

### Automatic Issue Detection

The system automatically detects and can fix these common issues:

#### Visual Studio Issues
- **Problem**: `Visual Studio 16 2019 could not find any instance`
- **Fix**: Updates CMake generator to `Visual Studio 17 2022`
- **Files**: All `.yml` workflow files

#### Boost Configuration Issues
- **Problem**: `boost_systemConfig.cmake not found`
- **Fix**: Updates Boost configuration for macOS 1.89.0+ package structure
- **Files**: `CryptoNoteWallet.cmake`

#### QRencode Linker Issues
- **Problem**: `Cannot determine link language for target "qrencode"`
- **Fix**: Switches from source build to system package via pkg-config
- **Files**: `QREncode.cmake`

#### CMake Cache Issues
- **Problem**: `CMakeCache.txt directory is different`
- **Fix**: Adds CMakeCache.txt to .gitignore
- **Files**: `.gitignore`

#### Qt Tools Issues
- **Problem**: `qttools5 not found`
- **Fix**: Removes qttools5 from Windows Qt installation
- **Files**: Workflow files

### Manual Fixes Required

Some issues require manual intervention:

- **Cryptonote Library Duplicates**: `add_library cannot create target "cryptonote" because another target with the same name already exists`
- **STARK CLI Issues**: Missing or incorrect STARK CLI binary downloads

## Configuration

### Environment Variables

- `REPO`: GitHub repository (default: `colinritman/fuego-desktop`)
- `BRANCH`: Branch to monitor (default: `master`)
- `MAX_ATTEMPTS`: Maximum monitoring attempts (default: 10)
- `SLEEP_INTERVAL`: Seconds between checks (default: 60)

### Customization

You can modify the scripts to:

- Monitor different repositories or branches
- Add new issue detection patterns
- Implement additional automatic fixes
- Change monitoring intervals and limits

## Workflow Integration

### GitHub Actions Integration

The monitoring system can be integrated into GitHub Actions workflows:

```yaml
name: Build Monitor
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: |
          sudo apt-get install jq
          gh auth login --with-token ${{ secrets.GITHUB_TOKEN }}
      - name: Run build monitor
        run: |
          cd scripts
          python3 auto_fix_builds.py --max-iterations 3
```

## Troubleshooting

### Common Issues

#### Authentication Errors
```bash
gh auth login
# Follow the prompts to authenticate
```

#### Permission Errors
```bash
chmod +x scripts/*.sh
chmod +x scripts/*.py
```

#### Missing Dependencies
```bash
# Check if tools are installed
which gh jq python3 git
```

### Debug Mode

Enable verbose logging by modifying the scripts:

```bash
# Add to monitor_builds.sh
set -x  # Enable debug mode
```

```python
# Add to auto_fix_builds.py
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Safety Features

### Backup and Rollback

- All changes are committed with descriptive messages
- Git history is preserved for easy rollback
- Fixes are applied incrementally with verification

### Rate Limiting

- Built-in delays between API calls
- Respects GitHub API rate limits
- Configurable sleep intervals

### Validation

- Verifies fixes before committing
- Checks file existence and permissions
- Validates Git operations

## Contributing

To add new issue detection or fixes:

1. **Add Detection Pattern**: Update the regex patterns in `analyze_logs()`
2. **Implement Fix**: Add a new `fix_*_issue()` method
3. **Update Router**: Add the new issue type to `apply_fixes()`
4. **Test**: Run the monitor on a test repository

## License

This monitoring system is part of the fuego-desktop project and follows the same license terms.

## Support

For issues with the build monitoring system:

1. Check the logs in `build_monitor.log`
2. Verify all dependencies are installed
3. Ensure GitHub CLI is authenticated
4. Check repository permissions

For build-specific issues, the monitor will provide specific guidance and suggested fixes.
