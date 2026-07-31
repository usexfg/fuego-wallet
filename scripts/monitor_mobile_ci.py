#!/usr/bin/env python3
import os
import sys
import time
import json
import urllib.request
import urllib.error
from datetime import datetime

# ANSI colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"

REPO = "usexfg/fuego-wallet"
WORKFLOW_FILENAME = "fuego-wallet-mobile-ci.yml"

def get_headers(token=None):
    headers = {
        "User-Agent": "Fuego-Mobile-CI-Monitor/1.0"
    }
    if token:
        headers["Authorization"] = f"token {token}"
    return headers

def fetch_json(url, token=None):
    req = urllib.request.Request(url, headers=get_headers(token))
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode()), response.info()
    except urllib.error.HTTPError as e:
        if e.code == 403:
            reset_time = e.headers.get("X-RateLimit-Reset")
            if reset_time:
                reset_dt = datetime.fromtimestamp(int(reset_time))
                print(f"{RED}{BOLD}GitHub API Rate Limit Exceeded.{NC}")
                print(f"Rate limit resets at: {reset_dt.strftime('%Y-%m-%d %H:%M:%S')}")
                if not token:
                    print(f"{YELLOW}Pro-Tip: Pass your GitHub token using the GITHUB_TOKEN environment variable or --token argument to get 5000 requests/hour.{NC}")
            else:
                print(f"{RED}HTTP 403 Forbidden: {e.reason}{NC}")
        else:
            print(f"{RED}HTTP Error {e.code}: {e.reason}{NC}")
        return None, None
    except Exception as e:
        print(f"{RED}Network error: {e}{NC}")
        return None, None

def monitor(token=None, poll_interval=30):
    print(f"{BLUE}{BOLD}==================================================={NC}")
    print(f"{BLUE}{BOLD}          FUEGO WALLET MOBILE CI MONITOR           {NC}")
    print(f"{BLUE}{BOLD}==================================================={NC}")
    print(f"Repository: {BOLD}{REPO}{NC}")
    print(f"Workflow:   {BOLD}{WORKFLOW_FILENAME}{NC}")
    print(f"Polling:    Every {poll_interval} seconds")
    if token:
        print(f"Auth:       {GREEN}Authenticated (Token Provided){NC}")
    else:
        print(f"Auth:       {YELLOW}Unauthenticated (Rate Limits Apply){NC}")
    print(f"{BLUE}==================================================={NC}\n")

    # Get workflow ID
    workflow_url = f"https://api.github.com/repos/{REPO}/actions/workflows/{WORKFLOW_FILENAME}"
    wf_data, _ = fetch_json(workflow_url, token)
    if not wf_data:
        print(f"{YELLOW}Warning: Could not fetch workflow details directly. Fetching all runs instead...{NC}")
        runs_url = f"https://api.github.com/repos/{REPO}/actions/runs"
    else:
        wf_id = wf_data.get("id")
        runs_url = f"https://api.github.com/repos/{REPO}/actions/workflows/{wf_id}/runs"

    last_run_id = None

    while True:
        data, info = fetch_json(f"{runs_url}?per_page=5", token)
        if not data:
            print(f"{YELLOW}Waiting 60 seconds before next retry...{NC}")
            time.sleep(60)
            continue

        runs = data.get("workflow_runs", [])
        if not runs:
            print(f"{CYAN}No runs found for this workflow yet.{NC}")
            time.sleep(poll_interval)
            continue

        # Filter for the relevant branch/runs if possible, or just the first run matching workflow
        matching_runs = [r for r in runs if r.get("path", "").endswith(WORKFLOW_FILENAME)]
        if not matching_runs:
            # Fallback to first run if path filter didn't match (API sometimes doesn't return path in generic list)
            matching_runs = runs

        latest = matching_runs[0]
        run_id = latest.get("id")
        status = latest.get("status")
        conclusion = latest.get("conclusion")
        commit_msg = latest.get("head_commit", {}).get("message", "N/A").split('\n')[0]
        author = latest.get("head_commit", {}).get("author", {}).get("name", "N/A")
        branch = latest.get("head_branch")
        html_url = latest.get("html_url")

        status_color = YELLOW
        if status == "completed":
            status_color = GREEN if conclusion == "success" else RED
        elif status == "in_progress":
            status_color = CYAN
        elif status == "queued":
            status_color = MAGENTA

        print(f"\n{BOLD}Latest Build Status [{datetime.now().strftime('%H:%M:%S')}]:{NC}")
        print(f"  {BOLD}Run ID:{NC}     {run_id}")
        print(f"  {BOLD}Branch:{NC}     {CYAN}{branch}{NC}")
        print(f"  {BOLD}Commit:{NC}     \"{commit_msg}\" by {author}")
        print(f"  {BOLD}Status:{NC}     {status_color}{status.upper()}{NC}")
        if conclusion:
            print(f"  {BOLD}Result:{NC}     {status_color}{conclusion.upper()}{NC}")
        print(f"  {BOLD}URL:{NC}        {html_url}")

        # If status is in_progress or completed, fetch job info if authenticated
        if token and status in ["in_progress", "completed"]:
            jobs_url = latest.get("jobs_url")
            jobs_data, _ = fetch_json(jobs_url, token)
            if jobs_data:
                print(f"  {BOLD}Jobs Detail:{NC}")
                for job in jobs_data.get("jobs", []):
                    job_name = job.get("name")
                    job_status = job.get("status")
                    job_conclusion = job.get("conclusion") or "RUNNING"

                    job_color = YELLOW
                    if job_status == "completed":
                        job_color = GREEN if job_conclusion == "success" else RED
                    elif job_status == "in_progress":
                        job_color = CYAN

                    print(f"    - {job_name}: {job_color}{job_status.upper()} ({job_conclusion.upper()}){NC}")

        if status == "completed":
            if conclusion == "success":
                print(f"\n{GREEN}{BOLD}🎉 SUCCESS! Fuego Wallet Mobile CI build is GREEN! 🎉{NC}")
                break
            else:
                print(f"\n{RED}{BOLD}❌ BUILD FAILED. Check the URL above to view build logs. ❌{NC}")
                break
        else:
            print(f"\n{CYAN}Building in progress... Polling again in {poll_interval}s...{NC}")
            time.sleep(poll_interval)

if __name__ == "__main__":
    token = os.environ.get("GITHUB_TOKEN")
    poll = 30

    # Simple CLI argument parsing
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg == "--token" and i + 1 < len(args):
            token = args[i + 1]
        elif arg == "--poll" and i + 1 < len(args):
            poll = int(args[i + 1])
        elif arg == "--help" or arg == "-h":
            print("Usage: monitor_mobile_ci.py [--token YOUR_GITHUB_TOKEN] [--poll SECONDS]")
            sys.exit(0)

    monitor(token, poll)
