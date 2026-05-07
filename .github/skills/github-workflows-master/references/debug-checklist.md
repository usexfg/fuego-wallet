# CI/CD Debugging Checklist

When a workflow fails, follow this structured path to find the root cause.

## Phase 1: Log Triage
- [ ] **Identify the failing step.** Is it `checkout`, `build`, or `test`?
- [ ] **Search for "Error" or "Fatal".** Look for missing headers (`.h`), missing libraries (`.so`/`.dylib`), or syntax errors.
- [ ] **Check the Exit Code.** `1` is generic; `127` means command not found; `137` usually means Out Of Memory (OOM).

## Phase 2: Dependency Analysis
- [ ] **System Packages:** Does the runner have all required `apt` or `brew` packages?
- [ ] **Version Mismatch:** Is the `cmake` version too old? Is the `rustc` version incompatible with the SP1 SDK?
- [ ] **Pathing:** Are the binaries being built in the expected directory? Check `pwd` in the logs.

## Phase 3: Environment Verification
- [ ] **Secrets:** Are all required `secrets.XXXX` defined in the repository settings?
- [ ] **Permissions:** Does the `GITHUB_TOKEN` have `contents: write` permissions for releases?
- [ ] **Disk Space:** Is the runner running out of space during a large C++ build?

## Phase 4: Local Reproduction
- [ ] **Docker:** Try to reproduce the failure in a Docker container matching the runner's OS.
- [ ] **Clean Build:** Delete the `build/` directory and start from scratch to rule out cache corruption.
- [ ] **Verbose Mode:** Add `-v` or `--verbose` to `cmake` or `cargo` to see exact command execution.

## Phase 5: Resolution & Prevention
- [ ] **Apply Fix:** Update the `.yml` file.
- [ ] **Generalize:** If the fix was "install a package", ensure it's added to the main build script for all users.
- [ ] **Verify:** Trigger the workflow and confirm the a "Green" build.
