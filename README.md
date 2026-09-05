# C++ Kubernetes Demo

An end-to-end C++ microservice delivery demonstration covering local compilation, static analysis, Debian packaging, Docker image creation, local Kubernetes deployment, and GitHub Actions automation.

The application is intentionally small: it prints a startup banner and emits a heartbeat every five seconds. The small runtime makes the engineering lifecycle visible without hiding it behind application complexity.

## Summary

We built an end-to-end, production-grade C++ microservice software engineering lifecycle. We started with host compilation on WSL 2, moved through quality checks and dual-packaging, deployed locally to a Kubernetes cluster, and automated the entire chain via GitHub Actions CI/CD.

The repository demonstrates these boundaries:

- **Source:** `src/main.cpp`
- **Native build:** CMake and Ninja
- **Quality checks:** Cppcheck and Clang-Tidy
- **Debian packaging:** metadata in `packaging/debian/`, copied to `debian/` by CI before `dpkg-buildpackage`
- **Container packaging:** multi-stage Docker build
- **Kubernetes deployment:** `k8s/deployment.yaml`
- **Automation:** `.github/workflows/ci.yml`

## Step-by-Step Learning Journey

### Step 1: Environment & Toolchain Setup

#### Environment

The original development environment was WSL 2 running Ubuntu 24.04. Install the core native toolchain with:

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build
```

The project expects a C++17-capable compiler. The build uses CMake to generate Ninja files and produces the `cpp_app` executable.

#### Build Architecture

The source and build configuration are intentionally separated:

```text
cpp-k8s-demo/
├── CMakeLists.txt
├── src/
│   └── main.cpp
├── packaging/
│   └── debian/
├── k8s/
│   └── deployment.yaml
├── Dockerfile
└── .github/
    └── workflows/
        └── ci.yml
```

Configure and compile locally:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/cpp_app
```

The program runs continuously and prints a heartbeat every five seconds. Stop it with `Ctrl+C`.

### Step 2: Static Analysis & Quality Control

#### Cppcheck

Cppcheck scans the source for common memory, correctness, and portability problems:

```bash
cppcheck \
  --enable=all \
  --suppress=missingIncludeSystem \
  --error-exitcode=1 \
  src/
```

The `missingIncludeSystem` suppression avoids treating unavailable system-header metadata as a project failure in the CI environment. Cppcheck still returns a nonzero status for findings that matter to the build.

#### Clang-Tidy

`.clang-tidy` enables checks across:

- `bugprone-*`
- `clang-analyzer-*`
- `performance-*`
- `readability-*`
- `modernize-*`

Warnings are treated as errors. After configuring CMake with compile commands enabled, run:

```bash
clang-tidy src/main.cpp -p build/
```

#### VS Code Integration

`.vscode/tasks.json` provides tasks for:

- **CMake: Build**
- **Static Analysis: Cppcheck**
- **Static Analysis: Clang-Tidy**

The build task is the default VS Code build task and can be launched with `Ctrl+Shift+B`.

### Step 3: Dual Packaging: Debian and Docker

The project produces both a native Debian package and a container image. These formats serve different delivery needs: the Debian package integrates with a Linux host, while the container packages the runtime for repeatable deployment.

#### Debian Package

The Debian metadata is kept under version control in `packaging/debian/`:

- `control` declares package metadata and build dependencies.
- `rules` delegates the package build to debhelper and CMake.
- `changelog` records the package version and release history.

Build the package locally:

```bash
sudo apt-get install -y debhelper debhelper-compat
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
cp -r packaging/debian debian
dpkg-buildpackage -us -uc -b
```

`dpkg-buildpackage` writes the resulting `.deb` file to the parent directory. The GitHub Actions workflow copies that package into `artifacts/` before uploading it, because `actions/upload-artifact@v4` does not accept paths outside the workspace.

The generated root-level `debian/` directory and `.deb` files are ignored by Git. The source metadata under `packaging/debian/` remains tracked.

#### Docker Multi-Stage Build

The `Dockerfile` has two stages:

1. **Builder:** `ubuntu:24.04` with CMake, Ninja, and g++, which compiles the application.
2. **Runner:** a clean `ubuntu:24.04` image containing only the runtime library and compiled executable.

Build and run the image:

```bash
docker build -t cpp-k8s-demo:ci .
docker run --rm cpp-k8s-demo:ci
```

The application is designed to run continuously. Stop the local container with `Ctrl+C`, or use a bounded smoke test:

```bash
docker run -d --name cpp-k8s-demo-ci cpp-k8s-demo:ci
timeout 10s docker logs -f cpp-k8s-demo-ci || test $? -eq 124
docker rm -f cpp-k8s-demo-ci
```

#### Key Container Insights

- The builder and runner use the same Ubuntu release, preserving glibc compatibility between compilation and execution.
- Build tools stay out of the final runtime image.
- `.dockerignore` excludes `build/`, `.git/`, `.vscode/`, `debian/`, and generated `.deb` files.
- Excluding host build output prevents stale `CMakeCache.txt` files and host-specific paths from entering the Docker build context.

### Step 4: Local Kubernetes Deployment with Kind

Kind runs Kubernetes nodes in containers and is useful for a fast local development loop.

#### Prerequisites

Install or make available:

- Docker
- `kind`
- `kubectl`

Create a local cluster named `dev-cluster`:

```bash
kind create cluster --name dev-cluster
```

#### Build and Sideload the Image

Build the image using the tag expected by the manifest, then load it directly into the Kind nodes:

```bash
docker build -t cpp-k8s-demo:v1 .
kind load docker-image cpp-k8s-demo:v1 --name dev-cluster
```

This avoids pushing the image to an external registry during local development.

#### Deploy the Application

Apply the deployment manifest:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get deployments
kubectl get pods -l app=cpp-k8s-demo
```

The manifest creates two replicas and uses:

- `imagePullPolicy: Never`, because the image was loaded directly into Kind.
- CPU request: `50m`.
- Memory request: `32Mi`.
- CPU limit: `100m`.
- Memory limit: `64Mi`.

Stream the application heartbeats from both replicas:

```bash
kubectl logs -l app=cpp-k8s-demo -f
```

Inspect a deployment or pod when troubleshooting:

```bash
kubectl describe deployment cpp-k8s-demo
kubectl describe pods -l app=cpp-k8s-demo
```

Remove the local resources when finished:

```bash
kubectl delete -f k8s/deployment.yaml
kind delete cluster --name dev-cluster
```

### Step 5: Automated CI/CD with GitHub Actions

`.github/workflows/ci.yml` runs on pushes and pull requests targeting `main`. The workflow performs the following sequence:

1. Checks out the repository.
2. Installs CMake, Ninja, g++, Cppcheck, debhelper, and Debian build prerequisites.
3. Configures and compiles the C++ application with CMake and Ninja.
4. Runs Cppcheck with the system-header suppression used by the local task.
5. Copies `packaging/debian/` to the root `debian/` path expected by Debian tooling.
6. Builds an unsigned binary Debian package.
7. Copies the package into the in-workspace `artifacts/` directory.
8. Uploads the Debian package with `actions/upload-artifact@v4`.
9. Builds the Docker image and runs a bounded container smoke test.

The smoke test starts the container detached, follows its logs for ten seconds, and force-removes the named container. This is important because the application is intentionally a long-running heartbeat service.

#### CI Debugging and Hardening

The lifecycle required several practical fixes:

- Cppcheck system-header noise was resolved with `--suppress=missingIncludeSystem`.
- The Debian metadata was kept under `packaging/debian/` and copied into the root `debian/` directory during CI.
- `.gitignore` excludes local build output and generated Debian files while allowing the source packaging metadata to remain tracked.
- The artifact upload was changed from `../*.deb` to `artifacts/*.deb`, because artifact actions reject relative paths that leave the workspace.
- The Docker timeout was moved from an argument to the application entrypoint into an explicit detached-container lifecycle, ensuring the runner can clean up the process.

## Repository Workflow

A useful local validation sequence mirrors CI:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
cppcheck --enable=all --suppress=missingIncludeSystem --error-exitcode=1 src/
clang-tidy src/main.cpp -p build/
```

To inspect the working tree before committing:

```bash
git status --short
```

Generated files should remain untracked. The main ignored paths include:

- `build/`
- `obj-*/`
- root-level `debian/`
- `*.deb`
- `*.tar`

## Key Takeaways

1. **Multi-stage Docker builds** keep final runtime container images small while keeping build tools such as g++ and CMake out of production environments.
2. **`kind load docker-image`** bypasses external registries during local rapid-prototyping loops.
3. **Strict pathing and artifact ignore rules** in `.dockerignore` and `.gitignore` prevent build-cache collisions across host, container, and CI-runner boundaries.
4. **Long-running services need explicit test lifecycles** in CI: start them, observe them for a bounded period, and clean them up.
5. **Packaging metadata should be versioned separately from generated output**, so a reproducible CI build can create fresh Debian artifacts on every run.

## License

This project is a demonstration repository. Add the project license here if the repository is distributed beyond its current learning and CI/CD use case.
