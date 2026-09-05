# --- Stage 1: Build & Compile ---
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Configure and compile static release binary
RUN cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build

# --- Stage 2: Minimal Runtime Image ---
FROM ubuntu:24.04 AS runner

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/build/cpp_app /usr/local/bin/cpp_app

ENTRYPOINT ["/usr/local/bin/cpp_app"]