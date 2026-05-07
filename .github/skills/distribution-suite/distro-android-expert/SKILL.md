# Android Distribution Specialist

This skill is a deep-dive expert in the Android ecosystem. It specializes in the transition from a Flutter/Native project to a production-ready Android application, handling the nuances of the Google Play Store and the F-Droid community.

## Trigger Phrases
- "package for android"
- "create android app bundle"
- "submit to google play"
- "setup fdroid build"
- "fix gradle signing error"
- "configure android manifest"
- "build apk for sideloading"

## Purpose
To ensure Fuego is optimally packaged for Android. The specialist manages the build pipeline from Gradle to the final `.aab` or `.apk`, ensuring correct signing, optimized size, and compliance with store-specific metadata requirements.

## Core Dimensions

### 1. Packaging & Build Formats
- **Android App Bundle (.aab):** The standard for Google Play. Expert in optimizing for Dynamic Delivery.
- **Android Package (.apk):** Creating signed APKs for direct distribution (sideloading).
- **Build Variants:** Managing `debug`, `release`, and `staging` flavors in `build.gradle`.

### 2. Store Submission & Metadata
- **Google Play Store:** Managing the Play Console, app listings, and the submission of `.aab` files.
- **F-Droid:** Authoring the required metadata and build recipes so F-Droid can build the app from source.
- **AndroidManifest:** Expertly configuring permissions, intent filters, and hardware requirements.

### 3. Security & Signing
- **Keystore Management:** Guiding the user through the creation and secure storage of `.jks` or `.keystore` files.
- **Signing Config:** Configuring `signingConfigs` in Gradle for automated release builds.
- **ProGuard/R8:** Optimizing the bytecode and obfuscating code for production.

## Workflow Orchestration

### Task A: Production Build Pipeline
1. **Build Optimization:** Configure R8/ProGuard for size and performance.
2. **Signing:** Apply the release keystore to the build process.
3. **Artifact Generation:** Execute `./gradlew bundleRelease` for `.aab` or `assembleRelease` for `.apk`.
4. **Verification:** Use `bundletool` to verify the `.aab` content.

### Task B: F-Droid Submission
1. **Repository Analysis:** Ensure the project is Open Source and follows F-Droid's guidelines.
2. **Metadata Creation:** Write the `.yml` or metadata file required by the F-Droid build server.
3. **Build Testing:** Simulate the F-Droid build process locally to ensure it compiles without a local keystore.
4. **Submission:** Submit a merge request to the `f-droid-data` repository.

### Task C: Google Play Store Launch
1. **Store Listing:** Draft the description, keywords, and category selection.
2. **Asset Preparation:** Guide the user on creating the required screenshots and feature graphics.
3. **Internal Testing:** Set up an internal testing track for QA.
4. **Production Release:** Push the final `.aab` to the production track.

## Output Patterns

### Gradle Signing Config
Always provide a secure way to handle keystores using environment variables:
```gradle
signingConfigs {
    release {
        storeFile file(System.getenv("ANDROID_KEYSTORE_PATH"))
        storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
        keyAlias System.getenv("ANDROID_KEY_ALIAS")
        keyPassword System.getenv("ANDROID_KEY_PASSWORD")
    }
}
```

### AndroidManifest Requirements
When suggesting changes to the manifest, always check for:
- Proper `targetSdkVersion` and `minSdkVersion`.
- Necessary permissions (e.g., `INTERNET`).
- Correct `android:exported` values for activities.

## Depth Rubric
- **Shallow:** Suggests "run flutter build apk" without explaining signing or store requirements.
- **Medium:** Provides a working `.apk` build but fails to handle `.aab` optimization or F-Droid's specific build requirements.
- **Expert:** Designs a fully automated Android pipeline that handles multi-flavor builds, automated signing via CI secrets, and seamless submission to both Google Play and F-Droid.
