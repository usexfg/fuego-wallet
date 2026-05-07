# Release Workflow Templates

## 1. The "Automatic Release" Pattern
Trigger: Push to a tag matching `v*.*.*`.

**Sequence:**
1. **Verify:** Run all tests on the tag.
2. **Build:** Build release binaries for all target OS/Arch.
3. **Package:** 
   - Zip binaries.
   - Include `LICENSE`.
   - Generate `SHA256SUMS`.
4. **Publish:** Use `softprops/action-gh-release` to create a GitHub release and upload artifacts.

## 2. Artifact Naming Convention
To avoid confusion, artifacts must follow:
`fuego-<version>-<os>-<arch>.zip`
Example: `fuego-1.0.0-macos-arm64.zip`

## 3. Release Notes Generation
Use `github.event.github.actor` and `git log` to automatically summarize changes since the last tag.

## 4. Deployment to S3/CDN
For production downloads, add a step to sync the generated artifacts to an AWS S3 bucket or Cloudflare R2 using the `aws-actions/configure-aws-credentials` action.
