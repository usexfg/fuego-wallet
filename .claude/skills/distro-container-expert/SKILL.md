# Container & Edge Distribution Specialist

This skill is a deep-dive expert in deploying software to constrained, virtualized, or non-traditional environments. It specializes in containerization and "edge" platforms like Termux, ensuring that Fuego remains portable and lightweight.

## Trigger Phrases
- "package for docker"
- "build for termux"
- "create alpine image"
- "setup edge deployment"
- "optimize dockerfile"
- "compile for musl"
- "deploy to raspberry pi container"

## Purpose
To enable Fuego to run anywhere—from a massive cloud server to a mobile terminal (Termux) or a lightweight Alpine container. The specialist focuses on minimizing image size, maximizing compatibility, and handling the unique constraints of edge environments.

## Core Dimensions

### 1. Containerization Mastery
- **Docker/OCI:** Authoring high-performance `Dockerfiles` using multi-stage builds to keep production images tiny.
- **Alpine Linux:** Expert in `musl` libc and building static binaries that run across different Linux distros.
- **Orchestration:** Providing basic `docker-compose` or Kubernetes manifests for deployment.

### 2. Edge & Mobile Terminal (Termux)
- **Termux Environment:** Understanding the unique filesystem layout and package manager (`pkg`/`apt`) of Termux on Android.
- **Binary Compatibility:** Handling the difference between standard Linux binaries and those required for Android-based Linux environments.
- **Installation Scripts:** Creating shell scripts that automate the setup of dependencies within Termux.

### 3. Optimization & Footprint
- **Distroless Images:** Using Google's "distroless" or scratch images to eliminate unnecessary shell utilities and reduce attack surface.
- **Binary Stripping:** Using `strip` and `upx` to minimize the size of the final binaries.
- **Resource Constraints:** Optimizing for low-memory and low-CPU environments (e.g., 512MB RAM).

## Workflow Orchestration

### Task A: Docker Image Creation
1. **Base Image Selection:** Choose the smallest viable base (e.g., `alpine` or `scratch`).
2. **Multi-Stage Build:**
   - **Build Stage:** Install all compilers, headers, and toolchains.
   - **Production Stage:** Copy only the final binary and required runtime libs.
3. **Entrypoint Config:** Define a robust `ENTRYPOINT` and `CMD` for the container.
4. **Validation:** Run the container locally to verify that all dependencies are present.

### Task B: Termux Deployment
1. **Dependency Mapping:** Map standard Linux libraries to their Termux equivalents.
2. **Build Script Authoring:** Create a `.sh` script that installs the toolchain and builds the app from source on the device.
3. **Path Configuration:** Ensure the binary is placed in the correct `$PREFIX/bin` directory.

### Task C: Alpine/musl Porting
1. **Toolchain Config:** Configure CMake to target `musl` instead of `glibc`.
2. **Static Linking:** Force static linking of all dependencies to ensure the binary is truly portable.
3. **Verification:** Run the binary in a clean Alpine container to confirm zero dynamic dependencies.

## Output Patterns

### Optimized Dockerfile
Always use the multi-stage pattern:
```dockerfile
# Build stage
FROM rust:latest AS builder
... build app ...

# Production stage
FROM alpine:latest
COPY --from=builder /app/binary /usr/local/bin/fuego
ENTRYPOINT ["fuego"]
```

### Termux Installation Script
Always include dependency checks:
```bash
pkg install -y cmake clang make git
# ... build steps ...
```

## Depth Rubric
- **Shallow:** Suggests a basic `FROM ubuntu:latest` Dockerfile that is 1GB in size.
- **Medium:** Uses multi-stage builds and Alpine Linux but fails to handle `musl` compatibility or Termux specifics.
- **Expert:** Delivers a highly optimized, statically-linked binary that runs on a 100MB Alpine image or a Termux terminal, with a fully automated CI pipeline for all edge targets.
