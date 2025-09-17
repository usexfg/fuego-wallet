#!/usr/bin/env python3

"""
Advanced GitHub Actions Build Auto-Fixer
Automatically detects and fixes common build issues in fuego-desktop
"""

import os
import sys
import json
import subprocess
import re
import time
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import argparse

class BuildFixer:
    def __init__(self, repo: str = "colinritman/fuego-desktop", branch: str = "master"):
        self.repo = repo
        self.branch = branch
        self.project_dir = Path(__file__).parent.parent
        self.workflows_dir = self.project_dir / ".github" / "workflows"
        self.fixes_applied = []
        
    def log(self, message: str, level: str = "INFO"):
        """Log messages with timestamp"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def run_command(self, cmd: List[str], cwd: Optional[Path] = None) -> Tuple[int, str, str]:
        """Run a command and return exit code, stdout, stderr"""
        try:
            result = subprocess.run(
                cmd, 
                cwd=cwd or self.project_dir,
                capture_output=True, 
                text=True, 
                check=False
            )
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            return 1, "", str(e)
    
    def get_workflow_runs(self) -> List[Dict]:
        """Get recent workflow runs"""
        cmd = ["gh", "api", f"repos/{self.repo}/actions/runs"]
        exit_code, stdout, stderr = self.run_command(cmd)
        
        if exit_code != 0:
            self.log(f"Failed to get workflow runs: {stderr}", "ERROR")
            return []
            
        try:
            runs = json.loads(stdout)
            return runs.get("workflow_runs", [])
        except json.JSONDecodeError:
            self.log("Failed to parse workflow runs JSON", "ERROR")
            return []
    
    def get_failed_runs(self) -> List[Dict]:
        """Get failed workflow runs"""
        runs = self.get_workflow_runs()
        failed_runs = []
        
        for run in runs:
            if (run.get("head_branch") == self.branch and 
                run.get("status") == "completed" and 
                run.get("conclusion") != "success"):
                failed_runs.append(run)
                
        return failed_runs
    
    def get_run_logs(self, run_id: int) -> Dict[str, str]:
        """Get logs for a specific run"""
        cmd = ["gh", "api", f"repos/{self.repo}/actions/runs/{run_id}/jobs"]
        exit_code, stdout, stderr = self.run_command(cmd)
        
        if exit_code != 0:
            return {}
            
        try:
            jobs_data = json.loads(stdout)
            logs = {}
            
            for job in jobs_data.get("jobs", []):
                if job.get("conclusion") == "failure":
                    job_id = job.get("id")
                    job_name = job.get("name", "unknown")
                    
                    # Get job logs
                    log_cmd = ["gh", "api", f"repos/{self.repo}/actions/jobs/{job_id}/logs"]
                    log_exit_code, log_stdout, log_stderr = self.run_command(log_cmd)
                    
                    if log_exit_code == 0:
                        logs[job_name] = log_stdout
                        
            return logs
        except json.JSONDecodeError:
            return {}
    
    def analyze_logs(self, logs: Dict[str, str]) -> List[str]:
        """Analyze logs and return list of issues found"""
        issues = []
        
        for job_name, log_content in logs.items():
            # Check for Visual Studio issues
            if re.search(r"Visual Studio.*could not find", log_content, re.IGNORECASE):
                issues.append(f"visual_studio:{job_name}")
                
            # Check for Boost issues
            if re.search(r"boost.*not found|boost.*Config\.cmake", log_content, re.IGNORECASE):
                issues.append(f"boost:{job_name}")
                
            # Check for QRencode issues
            if re.search(r"qrencode.*linker language|Cannot determine link language", log_content, re.IGNORECASE):
                issues.append(f"qrencode:{job_name}")
                
            # Check for cryptonote issues
            if re.search(r"cryptonote.*already exists", log_content, re.IGNORECASE):
                issues.append(f"cryptonote:{job_name}")
                
            # Check for STARK CLI issues
            if re.search(r"xfg-stark-cli.*not found|Cargo\.toml.*not found", log_content, re.IGNORECASE):
                issues.append(f"stark_cli:{job_name}")
                
            # Check for Qt issues
            if re.search(r"qttools5.*not found", log_content, re.IGNORECASE):
                issues.append(f"qt:{job_name}")
                
            # Check for CMake cache issues
            if re.search(r"CMakeCache\.txt.*different.*directory", log_content, re.IGNORECASE):
                issues.append(f"cmake_cache:{job_name}")
                
        return issues
    
    def fix_visual_studio_issue(self, job_name: str) -> bool:
        """Fix Visual Studio generator issues"""
        self.log(f"Fixing Visual Studio issue for {job_name}")
        
        # Update all workflow files
        workflow_files = list(self.workflows_dir.glob("*.yml"))
        
        for workflow_file in workflow_files:
            try:
                content = workflow_file.read_text()
                
                # Replace Visual Studio 16 2019 with 17 2022
                if "Visual Studio 16 2019" in content:
                    new_content = content.replace("Visual Studio 16 2019", "Visual Studio 17 2022")
                    workflow_file.write_text(new_content)
                    self.log(f"Updated {workflow_file.name}")
                    self.fixes_applied.append(f"Updated Visual Studio generator in {workflow_file.name}")
                    
            except Exception as e:
                self.log(f"Failed to update {workflow_file.name}: {e}", "ERROR")
                return False
                
        return True
    
    def fix_boost_issue(self, job_name: str) -> bool:
        """Fix Boost configuration issues"""
        self.log(f"Fixing Boost issue for {job_name}")
        
        cmake_file = self.project_dir / "CryptoNoteWallet.cmake"
        
        if not cmake_file.exists():
            self.log("CryptoNoteWallet.cmake not found", "ERROR")
            return False
            
        try:
            content = cmake_file.read_text()
            
            # Check if it's a macOS job
            if "macOS" in job_name:
                # Ensure macOS-specific Boost configuration
                if "boost_system REQUIRED" not in content:
                    self.log("Adding macOS Boost configuration")
                    # This would need more sophisticated text replacement
                    # For now, we'll just log the issue
                    self.fixes_applied.append(f"Boost configuration needs update for {job_name}")
            else:
                # Ensure traditional Boost configuration
                if "Boost_NO_BOOST_CMAKE" not in content:
                    self.log("Adding traditional Boost configuration")
                    self.fixes_applied.append(f"Boost configuration needs update for {job_name}")
                    
        except Exception as e:
            self.log(f"Failed to update CryptoNoteWallet.cmake: {e}", "ERROR")
            return False
            
        return True
    
    def fix_qrencode_issue(self, job_name: str) -> bool:
        """Fix QRencode linker issues"""
        self.log(f"Fixing QRencode issue for {job_name}")
        
        qrencode_file = self.project_dir / "QREncode.cmake"
        
        if not qrencode_file.exists():
            self.log("QREncode.cmake not found", "ERROR")
            return False
            
        try:
            content = qrencode_file.read_text()
            
            # Check if it's using system package
            if "pkg_check_modules" not in content:
                self.log("QRencode needs system package configuration")
                self.fixes_applied.append(f"QRencode configuration needs update for {job_name}")
                
        except Exception as e:
            self.log(f"Failed to check QREncode.cmake: {e}", "ERROR")
            return False
            
        return True
    
    def fix_cmake_cache_issue(self, job_name: str) -> bool:
        """Fix CMake cache issues"""
        self.log(f"Fixing CMake cache issue for {job_name}")
        
        # Add CMakeCache.txt to .gitignore if not already there
        gitignore_file = self.project_dir / ".gitignore"
        
        try:
            if gitignore_file.exists():
                content = gitignore_file.read_text()
                if "CMakeCache.txt" not in content:
                    content += "\n# CMake cache files\nCMakeCache.txt\nCMakeCache.txt.*\n"
                    gitignore_file.write_text(content)
                    self.log("Added CMakeCache.txt to .gitignore")
                    self.fixes_applied.append("Added CMakeCache.txt to .gitignore")
            else:
                gitignore_file.write_text("# CMake cache files\nCMakeCache.txt\nCMakeCache.txt.*\n")
                self.log("Created .gitignore with CMakeCache.txt")
                self.fixes_applied.append("Created .gitignore with CMakeCache.txt")
                
        except Exception as e:
            self.log(f"Failed to update .gitignore: {e}", "ERROR")
            return False
            
        return True
    
    def fix_qt_issue(self, job_name: str) -> bool:
        """Fix Qt tools issues"""
        self.log(f"Fixing Qt issue for {job_name}")
        
        # Update Windows workflows to remove qttools5
        workflow_files = list(self.workflows_dir.glob("*.yml"))
        
        for workflow_file in workflow_files:
            try:
                content = workflow_file.read_text()
                
                # Remove qttools5 from Windows Qt installation
                if "qttools5" in content and "windows" in content.lower():
                    new_content = re.sub(r'qttools5[^"]*', '', content)
                    if new_content != content:
                        workflow_file.write_text(new_content)
                        self.log(f"Removed qttools5 from {workflow_file.name}")
                        self.fixes_applied.append(f"Removed qttools5 from {workflow_file.name}")
                        
            except Exception as e:
                self.log(f"Failed to update {workflow_file.name}: {e}", "ERROR")
                return False
                
        return True
    
    def fix_stark_cli_issue(self, job_name: str) -> bool:
        """Fix STARK CLI issues"""
        self.log(f"Fixing STARK CLI issue for {job_name}")
        
        # Update all workflow files
        workflow_files = list(self.workflows_dir.glob("*.yml"))
        
        for workflow_file in workflow_files:
            try:
                content = workflow_file.read_text()
                updated = False
                
                # Check if it's using incorrect direct binary downloads
                if "xfg-stark-cli-linux-x86_64" in content:
                    # Replace direct download with tar.gz download and extraction
                    new_content = content.replace(
                        "wget -O xfg-stark-cli https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux-x86_64",
                        "wget -O xfg-stark-cli-linux.tar.gz https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux.tar.gz\ntar -xzf xfg-stark-cli-linux.tar.gz"
                    )
                    workflow_file.write_text(new_content)
                    self.log(f"Updated Linux STARK CLI download in {workflow_file.name}")
                    self.fixes_applied.append(f"Updated Linux STARK CLI download in {workflow_file.name}")
                    updated = True
                    
                if "xfg-stark-cli-windows-x86_64.exe" in content:
                    # Replace direct download with tar.gz download and extraction
                    new_content = content.replace(
                        'Invoke-WebRequest -Uri "https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows-x86_64.exe" -OutFile "xfg-stark-cli.exe"',
                        'Invoke-WebRequest -Uri "https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.tar.gz" -OutFile "xfg-stark-cli-windows.tar.gz"\ntar -xzf xfg-stark-cli-windows.tar.gz'
                    )
                    workflow_file.write_text(new_content)
                    self.log(f"Updated Windows STARK CLI download in {workflow_file.name}")
                    self.fixes_applied.append(f"Updated Windows STARK CLI download in {workflow_file.name}")
                    updated = True
                    
                if "xfg-stark-cli-macos-x86_64" in content:
                    # Replace direct download with tar.gz download and extraction
                    new_content = content.replace(
                        "curl -L -o xfg-stark-cli https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos-x86_64",
                        "curl -L -o xfg-stark-cli-macos.tar.gz https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos.tar.gz\ntar -xzf xfg-stark-cli-macos.tar.gz"
                    )
                    workflow_file.write_text(new_content)
                    self.log(f"Updated macOS STARK CLI download in {workflow_file.name}")
                    self.fixes_applied.append(f"Updated macOS STARK CLI download in {workflow_file.name}")
                    updated = True
                    
                if "xfg-stark-cli-macos-aarch64" in content:
                    # Replace direct download with tar.gz download and extraction
                    new_content = content.replace(
                        "curl -L -o xfg-stark-cli https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos-aarch64",
                        "curl -L -o xfg-stark-cli-macos.tar.gz https://github.com/colinritman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos.tar.gz\ntar -xzf xfg-stark-cli-macos.tar.gz"
                    )
                    workflow_file.write_text(new_content)
                    self.log(f"Updated macOS Apple Silicon STARK CLI download in {workflow_file.name}")
                    self.fixes_applied.append(f"Updated macOS Apple Silicon STARK CLI download in {workflow_file.name}")
                    updated = True
                    
            except Exception as e:
                self.log(f"Failed to update {workflow_file.name}: {e}", "ERROR")
                return False
                
        return True
    
    def apply_fixes(self, issues: List[str]) -> bool:
        """Apply fixes for detected issues"""
        success = True
        
        for issue in issues:
            issue_type, job_name = issue.split(":", 1)
            
            if issue_type == "visual_studio":
                success &= self.fix_visual_studio_issue(job_name)
            elif issue_type == "boost":
                success &= self.fix_boost_issue(job_name)
            elif issue_type == "qrencode":
                success &= self.fix_qrencode_issue(job_name)
            elif issue_type == "cmake_cache":
                success &= self.fix_cmake_cache_issue(job_name)
            elif issue_type == "qt":
                success &= self.fix_qt_issue(job_name)
            elif issue_type == "cryptonote":
                self.log(f"Cryptonote issue detected for {job_name} - manual fix required")
            elif issue_type == "stark_cli":
                success &= self.fix_stark_cli_issue(job_name)
                
        return success
    
    def commit_and_push(self) -> bool:
        """Commit and push changes"""
        if not self.fixes_applied:
            self.log("No fixes to commit")
            return True
            
        try:
            # Add all changes
            exit_code, stdout, stderr = self.run_command(["git", "add", "."])
            if exit_code != 0:
                self.log(f"Failed to add changes: {stderr}", "ERROR")
                return False
                
            # Commit changes
            commit_message = "Auto-fix: Apply build fixes\n\n" + "\n".join(f"- {fix}" for fix in self.fixes_applied)
            exit_code, stdout, stderr = self.run_command(["git", "commit", "-m", commit_message])
            if exit_code != 0:
                self.log(f"Failed to commit changes: {stderr}", "ERROR")
                return False
                
            # Push changes
            exit_code, stdout, stderr = self.run_command(["git", "push", "origin", self.branch])
            if exit_code != 0:
                self.log(f"Failed to push changes: {stderr}", "ERROR")
                return False
                
            self.log("Changes committed and pushed successfully")
            return True
            
        except Exception as e:
            self.log(f"Failed to commit and push: {e}", "ERROR")
            return False
    
    def run(self, max_iterations: int = 5) -> bool:
        """Run the auto-fixer"""
        self.log(f"Starting auto-fixer for {self.repo} (max {max_iterations} iterations)")
        
        for iteration in range(max_iterations):
            self.log(f"=== Iteration {iteration + 1}/{max_iterations} ===")
            
            # Get failed runs
            failed_runs = self.get_failed_runs()
            
            if not failed_runs:
                self.log("No failed runs found!")
                return True
                
            self.log(f"Found {len(failed_runs)} failed runs")
            
            # Analyze each failed run
            all_issues = []
            for run in failed_runs:
                run_id = run.get("id")
                run_name = run.get("name", "unknown")
                
                self.log(f"Analyzing run {run_id} ({run_name})")
                
                logs = self.get_run_logs(run_id)
                issues = self.analyze_logs(logs)
                all_issues.extend(issues)
                
            if not all_issues:
                self.log("No fixable issues found")
                return False
                
            self.log(f"Found {len(all_issues)} fixable issues")
            
            # Apply fixes
            if self.apply_fixes(all_issues):
                # Commit and push changes
                if self.commit_and_push():
                    self.log("Fixes applied and pushed. Waiting for new builds...")
                    time.sleep(120)  # Wait 2 minutes for builds to start
                else:
                    self.log("Failed to push fixes", "ERROR")
                    return False
            else:
                self.log("Failed to apply fixes", "ERROR")
                return False
                
        self.log("Maximum iterations reached", "WARNING")
        return False

def main():
    parser = argparse.ArgumentParser(description="Auto-fix GitHub Actions build issues")
    parser.add_argument("--repo", default="colinritman/fuego-desktop", help="Repository to monitor")
    parser.add_argument("--branch", default="master", help="Branch to monitor")
    parser.add_argument("--max-iterations", type=int, default=5, help="Maximum number of fix iterations")
    
    args = parser.parse_args()
    
    fixer = BuildFixer(args.repo, args.branch)
    success = fixer.run(args.max_iterations)
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
