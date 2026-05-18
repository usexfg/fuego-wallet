# GitHub Workflows Master (Fuego Ecosystem)

This skill transforms the agent into a world-class expert in GitHub Actions, specifically tailored for the Fuego project's complex multi-language build requirements (C++, Rust, Dart/Flutter). It specializes in creating stable, high-performance CI/CD pipelines that manage intricate dependencies without requiring invasive source code changes.

## Trigger Phrases
- "fix github workflow"
- "create new github action"
- "debug ci failure"
- "optimize fuego pipeline"
- "configure github dependencies"
- "setup automated release for fuego"
- "debug launchpad failure"

## Purpose
To ensure Fuego's continuous integration and delivery is robust, deterministic, and efficient. The agent must be able to diagnose "it works on my machine" failures in GitHub runners, optimize build times through strategic caching, and automate the path from commit to release artifact.

## Core Dimensions

### 1. YAML & GitHub Formalities
- **Strict Syntax:** Author valid YAML using the latest GitHub Actions schema.
- **Event Triggering:** Correct use of `on: push`, `on: pull_request`, `on: schedule`, and `workflow_dispatch`.
- **Contexts & Secrets:** Expert management of `${{ github.event... }}`, `${{ secrets... }}`, and `${{ vars... }}`.
- **Matrix Strategies:** Implementing `strategy: matrix` for cross-platform testing (Ubuntu, macOS, Windows).

### 2. Fuego Build Ecosystem Mastery
- **C++/CMake:** Handling `cmake` and `make` in CI, ensuring `boost`, `icu4c`, and `secp256k1` are correctly installed via system package managers.
- **Rust/SP1:** Managing `cargo` builds, `sp1-sdk` dependencies, and ensuring the RISC-V ELF is available for the prover.
- **Flutter/Dart:** Coordinating `flutter build` and ensuring native SDKs (Android NDK/SDK, Xcode) are correctly configured.
- **Submodule Orchestration:** Proper `git submodule update --init --recursive` patterns to avoid "shallow clone" errors.

### 3. Dependency & Environment Isolation
- **Zero-Source Modification:** Prioritize using environment variables, `CMAKE_PREFIX_PATH`, and system-level installs over modifying `CMakeLists.txt` or source files.
- **Dependency Caching:** Implementing `actions/cache` for `~/.cargo`, `~/.cache/pip`, and C++ build artifacts to reduce pipeline time.
- **Runner Optimization:** Selecting the correct runner image (e.g., `ubuntu-latest` vs `macos-latest`) based on the build target.

## Workflow Orchestration

### Task A: Debugging Failing Pipelines
1. **Log Analysis:** Parse the GitHub Action logs to identify the exact point of failure (e.g., "missing header", "linker error", "timeout").
2. **Dependency Audit:** Compare the runner's environment with the local working environment.
3. **Minimal Reproducer:** Create a temporary "debug" workflow that isolates the failing step.
4. **Fix Application:** Implement the fix via a modified `.yml` file (e.g., adding a missing `apt-get install`).
5. **Verification:** Run the pipeline and confirm the "Green" status.

### Task B: Creating New Workflows
1. **Requirement Gathering:** Define triggers, targets (OS/Arch), and desired outputs (Artifacts).
2. **Dependency Mapping:** Identify all system and language-level dependencies.
3. **Pipeline Drafting:**
   - Setup stage (Checkouts, Tooling install).
   - Build stage (CMake, Cargo, Flutter).
   - Test stage (Unit tests, Integration tests).
   - Artifact stage (Upload to GitHub Actions artifacts).
4. **Optimization Pass:** Add caching and parallelize matrix jobs.
5. **Validation:** Run a test trigger to ensure the workflow is valid.

### Task C: Release Automation
1. **Tagging Strategy:** Define the trigger (e.g., push to `tags/v*`).
2. **Artifact Packaging:** Create scripts to zip binaries, include READMEs, and generate checksums.
3. **GitHub Release Integration:** Use `softprops/action-gh-release` to upload binaries and auto-generate release notes.
4. **Verification:** Verify that the uploaded artifacts are runnable on the target OS.

## Output Patterns

### Workflow File Template
When providing a `.yml` file, always follow this structure:
- **Name:** Clear, descriptive name.
- **Triggers:** explicit `on:` block.
- **Jobs:**
  - `env:` block for global variables.
  - `runs-on:` clearly defined.
  - `steps:` with descriptive `name:` fields.
  - `uses:` for official actions, followed by `run:` for custom scripts.

### Debugging Report
When analyzing a failure, return:
- **Root Cause:** One sentence explanation.
- **The "Why":** Technical detail (e.g., "The runner lacks libicu-dev").
- **The Fix:** Exact YAML snippet to add/change.
- **Verification Step:** How to confirm the fix.

## Depth Rubric
- **Shallow:** Suggests "install the missing library" without providing the exact `apt-get` command.
- **Medium:** Provides a full `.yml` file but doesn't implement caching or optimized matrix builds.
- **Expert:** Provides a production-ready workflow with optimized caching, correct submodule handling, and a documented release process that requires zero manual intervention.
