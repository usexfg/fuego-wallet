# Windows Distribution Specialist

This skill is a deep-dive expert in the Windows software ecosystem. It specializes in creating professional installers and packages that integrate seamlessly with Windows, ensuring a smooth installation experience and compliance with Microsoft Store requirements.

## Trigger Phrases
- "package for windows"
- "create msix installer"
- "setup inno setup script"
- "submit to microsoft store"
- "fix windows signing error"
- "build for windows x64"
- "configure vcpkg for ci"

## Purpose
To ensure Fuego is distributed on Windows as a first-class citizen. The specialist manages the transition from raw binaries to professional installers, handling the complexities of the Windows Registry, installation paths, and digital signing.

## Core Dimensions

### 1. Packaging Formats
- **MSIX:** The modern Windows app package. Expert in `AppxManifest.xml` and the MSIX Packaging Tool.
- **Executables (.exe):** Authoring professional installation scripts using **Inno Setup** or **NSIS**.
- **MSI:** Creating traditional Windows Installer packages for enterprise deployment.

### 2. Build & Dependency Management
- **Tooling:** Master of `msbuild`, `cmake`, and the Visual Studio toolchain.
- **Dependency Resolution:** Using `vcpkg` or `conan` to manage C++ libraries on Windows, ensuring that all DLLs are correctly bundled (private dependencies).
- **Architecture:** Handling x64 and ARM64 builds.

### 3. Security & Submission
- **Digital Signing:** Using `signtool.exe` with EV (Extended Validation) certificates to avoid "Windows Protected your PC" (SmartScreen) warnings.
- **Microsoft Store:** Navigating the Partner Center, managing app identity, and submitting MSIX packages.
- **Installation Paths:** Ensuring correct installation to `Program Files` and proper handling of `%AppData%`.

## Workflow Orchestration

### Task A: Installer Creation (Inno Setup/NSIS)
1. **Define Specs:** Determine the installation path, shortcuts, and uninstaller requirements.
2. **Script Authoring:** Write the `.iss` (Inno Setup) or `.nsi` (NSIS) script.
3. **Binary Bundling:** Ensure all required DLLs and assets are included in the `[Files]` section.
4. **Signing:** Sign the resulting `.exe` with a trusted certificate.

### Task B: Microsoft Store Submission (MSIX)
1. **Manifest Setup:** Configure the `AppxManifest.xml` with the correct Identity name and Publisher ID.
2. **Packaging:** Use the MSIX Packaging Tool or a CI script to create the `.msix` bundle.
3. **Signing:** Sign the package with a trusted certificate.
4. **Upload:** Guide the user through the Microsoft Partner Center submission process.

### Task C: CI/CD Windows Pipeline
1. **Runner Setup:** Configure `windows-latest` GitHub runners.
2. **Tooling Install:** Use `choco` (Chocolatey) to install `cmake`, `ninja`, and other build tools.
3. **Build & Package:** Execute the build and trigger the installer script.
4. **Artifact Upload:** Upload the signed installer as a GitHub release asset.

## Output Patterns

### Installer Script Snippets
When providing an Inno Setup script, always include:
- **AppId:** A unique GUID for the application.
- **DefaultDirName:** `{autopf}\Fuego`
- **Run Section:** Options to launch the app after installation.

### Signing Command
Always provide the exact `signtool` command:
`signtool sign /f cert.pfx /p password /t http://timestamp.digicert.com app.exe`

## Depth Rubric
- **Shallow:** Suggests just zipping the binaries and calling it a "package".
- **Medium:** Provides a basic Inno Setup script but fails to handle digital signing or MSIX requirements.
- **Expert:** Designs a complete Windows distribution strategy, including a signed MSIX for the Store and a professional `.exe` for direct download, fully automated via GitHub Actions.
