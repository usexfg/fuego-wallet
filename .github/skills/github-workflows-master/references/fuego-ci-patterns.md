# Fuego CI/CD Patterns & Gotchas

This reference provides deterministic patterns for handling Fuego's unique build requirements in GitHub Actions.

## 1. Submodule Handling
Fuego relies heavily on submodules (`fuego`, `secp256k1`). 
**Incorrect:** `actions/checkout@v4` (default)
**Correct:**
```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
    fetch-depth: 0 # Required for certain version checks and git-describe
```
*Common Failure:* "File not found" in `fuego/src/...` usually means submodules weren't initialized.

## 2. The C++/Rust Hybrid Build
Fuego requires both a C++ toolchain and a Rust toolchain.
- **C++ Dependencies (Ubuntu):** 
  `sudo apt-get update && sudo apt-get install -y build-essential cmake libicu-dev libboost-all-dev`
- **Rust Toolchain:**
  Use `dtolnay/rust-toolchain` to ensure a specific version of Rust and the `nightly` channel if needed for SP1.
- **Ordering:** Always install system dependencies $\rightarrow$ Rust toolchain $\rightarrow$ C++ build $\rightarrow$ Rust build.

## 3. SP1 Prover Integration
The prover requires the SP1 RISC-V ELF.
- **ELF Management:** Do not commit the ELF to Git. Use a release download or a dedicated GitHub Action to fetch the ELF from a trusted source.
- **Environment Variables:** Ensure `CIRCUIT_ELF_PATH` is set in the workflow environment.

## 4. Cross-Platform Caveats
- **macOS:** Use `brew install icu4c boost`. Note that `icu4c` is keg-only; you must set `LDFLAGS` and `CPPFLAGS` so CMake can find it.
- **Windows:** Use `choco install` or `vcpkg`. Ensure the MSVC compiler is in the path.

## 5. Caching Strategies
- **Cargo Cache:** Use `Swatinem/rust-cache` for faster Rust builds.
- **CMake Cache:** Use `actions/cache` on the `build/` directory, but be careful to invalidate the cache when `CMakeLists.txt` changes.
