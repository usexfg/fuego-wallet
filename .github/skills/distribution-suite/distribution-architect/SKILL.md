# Distribution Architect (Overseer)

This skill acts as the master orchestrator for cross-platform software distribution. It does not perform the low-level packaging itself; instead, it analyzes the project's target platforms and coordinates a team of specialized Distribution Agents to produce a cohesive, multi-platform release.

## Trigger Phrases
- "package for all platforms"
- "distribute my app"
- "setup cross-platform release"
- "prepare for app store submission"
- "create distribution pipeline"
- "release my project to all stores"

## Purpose
To transform a raw codebase into a professionally distributed set of artifacts across all major OSes and App Stores. The Architect ensures version consistency, manages the order of operations, and generates a master CI/CD pipeline that integrates platform-specific specialists.

## Core Dimensions

### 1. Strategic Planning
- **Platform Mapping:** Analyze the project to determine which platforms are viable (e.g., "This is a Flutter app, so we target Android, iOS, macOS, Windows, Linux").
- **Store Audit:** Identify the requirements for each target store (e.g., "F-Droid requires a Git repository for build recipes; Google Play requires an AAB").
- **Version Orchestration:** Enforce a single source of truth for versioning across all artifacts to prevent "version drift."

### 2. Specialist Coordination
- **Task Delegation:** Break down the distribution goal into specific tasks for the specialists:
    - `distro-linux-expert` $\rightarrow$ "Create Snap and Flatpak manifests."
    - `distro-apple-expert` $\rightarrow$ "Handle Xcode archiving and Notarization."
    - `distro-windows-expert` $\rightarrow$ "Generate MSIX package for Microsoft Store."
    - `distro-android-expert` $\rightarrow$ "Build AAB and configure Play Store metadata."
    - `distro-container-expert` $\rightarrow$ "Build Docker image and Termux script."
- **Data Flow:** Use a standardized "Distribution Manifest" to pass project metadata (Author, Version, Description, Binary Paths) between agents.

### 3. CI/CD Pipeline Synthesis
- **Master Workflow Design:** Generate a GitHub Actions or GitLab CI file that:
    - Parallelizes platform builds using a matrix strategy.
    - Handles complex dependency chains (e.g., build C++ core $\rightarrow$ build SDK $\rightarrow$ build UI).
    - Implements a "Staging $\rightarrow$ Production" release flow.
- **Automated Submission:** Integrate API calls for store uploads (e.g., using `gh release` or specific store CLI tools).

## Workflow Orchestration

### Step 1: Discovery & Audit
1. **Analyze codebase:** Detect the primary language and build system (e.g., CMake, Cargo, Gradle).
2. **Define targets:** Ask the user which stores/platforms are priorities.
3. **Audit requirements:** Identify missing assets (e.g., "You need a 512x512 icon for Google Play").

### Step 2: Distribution Blueprint
1. **Create a "Distribution Map":** A table listing every target platform, the required package format, the target store, and the necessary specialist.
2. **Define the Versioning Strategy:** Establish the tag format (e.g., `v1.0.0`).
3. **Review Blueprint:** Present the plan to the user for approval.

### Step 3: Specialist Execution
1. **Invoke Specialists:** Systematically call the specialists to generate manifests, build scripts, and submission guides.
2. **Verify Artifacts:** Ensure each specialist provides the required output (e.g., "The Linux specialist provided a `snapcraft.yaml`").

### Step 4: Pipeline Integration
1. **Synthesize Master Workflow:** Combine the specialists' requirements into a single `.github/workflows/release.yml`.
2. **Implement Caching:** Add global caching strategies to avoid redundant builds.
3. **Configure Secrets:** Guide the user on which secrets to add to GitHub (e.g., `APPLE_CERT_P12`, `GOOGLE_SERVICE_ACCOUNT_JSON`).

### Step 5: Final Validation & Launch
1. **Dry Run:** Simulate the pipeline to check for syntax errors.
2. **Release Trigger:** Trigger the first official release.
3. **Verification:** Confirm that artifacts appear correctly in the target stores.

## Output Patterns

### The Distribution Blueprint
When planning, always return a table:
| Platform | Format | Store | Specialist | Key Requirement |
|----------|--------|-------|-------------|------------------|
| Linux    | .snap  | Snap Store | linux-expert | snapcraft.yaml |
| Android  | .aab   | Play Store | android-expert | keystore.jks |
| ...      | ...    | ...   | ...         | ...              |

### Master Pipeline Snippet
When providing YAML, always include a high-level "Coordinator" job that manages the flow between the specialist jobs.

## Depth Rubric
- **Shallow:** Suggests using a generic release tool without considering store-specific manifest requirements.
- **Medium:** Provides basic YAML for a few platforms but fails to handle cross-platform versioning or complex signing requirements.
- **Expert:** Designs a fully automated, multi-platform pipeline with a centralized blueprint, coordinating multiple specialized agents to handle the nuances of every target ecosystem from RasPi to App Store.
