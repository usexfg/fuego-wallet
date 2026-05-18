# Linux Distribution Specialist

This skill is a deep-dive expert in the Linux packaging ecosystem. It specializes in transforming binaries into installable packages for a wide variety of distributions and hardware architectures, with a focus on the Fuego project's requirements.

## Trigger Phrases
- "package for linux"
- "create snap package"
- "build flatpak for fuego"
- "generate .deb and .rpm"
- "package for raspberry pi"
- "submit to flathub"
- "configure snapcraft.yaml"

## Purpose
To ensure that Fuego is easily installable and up-to-date across the fragmented Linux landscape. The specialist handles the technical nuances of different package managers, build environments, and hardware architectures (x86 and ARM).

## Core Dimensions

### 1. Package Format Mastery
- **Snaps:** Expert in `snapcraft.yaml`, strict confinement, and the Snap Store submission process.
- **Flatpaks:** Expert in `flatpak-builder` manifests, runtime selection (Freedesktop/GNOME/KDE), and Flathub submission.
- **Native Packages:** Authoring professional `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/CentOS) packages.
- **AppImage:** Creating portable, single-file executables with proper `.desktop` and icon integration.

### 2. Architecture & Hardware (RasPi/ARM)
- **Cross-Compilation:** Setting up toolchains for ARMv7 and ARMv8.
- **Multi-Arch Builds:** Configuring CI to build for both x86_64 and ARM64.
- **Pi-Specifics:** Handling Raspberry Pi OS dependencies and GPU/hardware acceleration requirements.

### 3. Distribution & Store Submission
- **Snap Store:** Managing the `snapcraft` upload process and channel management (stable, candidate, beta, edge).
- **Flathub:** Creating the required metadata and handling the `flatpak-builder` remote process.
- **Ubuntu Software Center:** Ensuring proper metadata for discovery.

## Workflow Orchestration

### Task A: Package Specification
1. **Define Scope:** Determine which formats are needed (e.g., "Only Snap and Flatpak").
2. **Dependency Audit:** List all system-level dependencies (`libicu`, `libboost`, etc.) and map them to the specific package manager of the target distro.
3. **Manifest Authoring:** Create the `snapcraft.yaml` or Flatpak manifest.
4. **Validation:** Run a local build to verify the package installs and runs.

### Task B: Cross-Platform ARM Build (RasPi)
1. **Environment Setup:** Configure a QEMU-based build environment or use a native RasPi build node.
2. **Toolchain Config:** Set `CC`, `CXX`, and `CMAKE_TOOLCHAIN_FILE` for the target architecture.
3. **Build & Package:** Execute the build and wrap the result in the chosen format.
4. **Verification:** Test the package on the target hardware or via emulation.

### Task C: Store Submission
1. **Metadata Generation:** Create the required icons, screenshots, and descriptions.
2. **Submission Execution:** Use the store's CLI tool (e.g., `snapcraft upload`) to submit the artifact.
3. **Review Loop:** Address any rejection reasons from the store reviewers.

## Output Patterns

### Manifest Snippet
When providing a manifest (e.g., `snapcraft.yaml`), always include:
- **Base:** The correct base (e.g., `core22`).
- **Parts:** Explicitly defined build and stage parts.
- **Plugs:** All necessary interfaces (e.g., `network`, `home`).

### Debugging Report
When a Linux build fails, return:
- **Error:** The exact compiler/linker error.
- **Missing Dependency:** The specific system package required (e.g., `libicu-dev`).
- **Fix:** The exact `apt-get` or `dnf` command to resolve it.

## Depth Rubric
- **Shallow:** Suggests a generic "build the binary" without providing the package manifest.
- **Medium:** Provides a working `.deb` package but ignores the complexities of Snap confinement or ARM cross-compilation.
- **Expert:** Delivers a fully automated, multi-arch pipeline that produces verified Snap, Flatpak, and native packages, ensuring seamless installation on everything from a generic Ubuntu desktop to a Raspberry Pi 4.
