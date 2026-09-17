# Linux arm64/amd64 test image: Flutter pinned to the host version, Linux
# desktop toolchain, xvfb. Built once by scripts/linux_container_test.sh.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates unzip xz-utils zip rsync \
      clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev xvfb \
    && rm -rf /var/lib/apt/lists/*
ARG FLUTTER_VERSION=3.47.3
RUN git clone --depth 1 -b "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:/root/.pub-cache/bin:$PATH
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-linux-desktop \
    && flutter precache --linux \
    && flutter --version
