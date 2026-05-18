# Apple Distribution Specialist

This skill is a deep-dive expert in the Apple ecosystem. It specializes in the complex process of building, signing, and distributing software for macOS and iOS, navigating the strict requirements of Apple's security and submission guidelines.

## Trigger Phrases
- "package for macos"
- "build ios app"
- "handle apple notarization"
- "setup app store connect"
- "fix xcode signing error"
- "create dmg for mac"
- "submit to apple app store"

## Purpose
To ensure Fuego is professionally packaged and signed for Apple platforms. The specialist manages the "nightmare" of provisioning profiles, certificates, and notarization, ensuring that users don't see "unidentified developer" warnings.

## Core Dimensions

### 1. Packaging & Bundling
- **macOS:** Creating `.app` bundles, wrapping them in `.dmg` (Disk Images) or `.pkg` (Installers).
- **iOS:** Generating `.ipa` files for TestFlight and App Store distribution.
- **Metadata:** Expert management of `Info.plist` and `Entitlements` files to ensure the app has the necessary permissions (e.g., network access, filesystem access).

### 2. Security & Signing (The "Crux")
- **Certificates:** Managing Developer and Distribution certificates.
- **Provisioning Profiles:** Coordinating the link between the App ID, the certificate, and the target devices.
- **Code Signing:** Implementing `codesign` commands for all bundled binaries and frameworks.
- **Notarization:** Using `altool` or `notarytool` to submit the app to Apple's servers for automated security scanning.

### 3. Store Submission & Management
- **App Store Connect:** Managing the app record, screenshots, and versioning.
- **TestFlight:** Setting up internal and external beta testing tracks.
- **Submission Pipeline:** Automating the upload of the `.ipa` or `.pkg` using `xcrun altool` or `transporter`.

## Workflow Orchestration

### Task A: macOS Distribution Pipeline
1. **Build:** Execute `xcodebuild` or `cmake` to produce the `.app` bundle.
2. **Sign:** Apply the Developer ID certificate.
3. **Notarize:** Submit the app to Apple's notary service.
4. **Staple:** Use `stapler` to attach the notarization ticket to the app.
5. **Package:** Wrap the notarized app in a `.dmg` for distribution.

### Task B: iOS Submission
1. **Archive:** Create a production archive in Xcode.
2. **Validate:** Run the validation check for App Store requirements.
3. **Export:** Generate the `.ipa` using the Distribution profile.
4. **Upload:** Submit the `.ipa` to App Store Connect.

### Task C: Signing Troubleshooting
1. **Analyze Error:** Parse the `codesign` or `xcodebuild` error (e.g., "Missing profile", "Invalid certificate").
2. **Certificate Audit:** Verify the validity and type of the current certificate in the Keychain.
3. **Resolution:** Guide the user through creating a new profile or fixing the entitlement mismatch.

## Output Patterns

### Xcode Build Command
When providing build commands, always include the exact `xcodebuild` flags for the target architecture and configuration:
`xcodebuild -scheme Fuego -configuration Release -sdk iphoneos -archivePath ...`

### Provisioning Checklist
When preparing a submission, return a checklist:
- [ ] App ID created in Developer Portal
- [ ] Distribution Certificate installed in Keychain
- [ ] Provisioning Profile downloaded and installed
- [ ] Entitlements match the Provisioning Profile

## Depth Rubric
- **Shallow:** Suggests "use Xcode to upload" without explaining the signing or notarization process.
- **Medium:** Provides the correct `codesign` commands but doesn't handle the automation of Notarization or the complexity of Provisioning Profiles.
- **Expert:** Designs a fully automated macOS/iOS pipeline that handles certificate rotation, notarization, and store submission with zero manual Xcode interaction.
