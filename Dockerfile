# Linux and Windows build environment for build-all.sh. Packages come from the
# live archive; APT_SNAPSHOT=20261106T000000Z pins them to snapshot.ubuntu.com.
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_SNAPSHOT=
RUN set -e; \
    echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80retries; \
    apt-get update; \
    if [ -n "$APT_SNAPSHOT" ]; then \
        # snapshot.ubuntu.com is HTTPS-only.
        apt-get install -y --no-install-recommends ca-certificates; \
        apt-get update --snapshot "$APT_SNAPSHOT"; \
        snap="--snapshot $APT_SNAPSHOT"; \
    fi; \
    # Not gcc-multilib: it conflicts with gcc-aarch64-linux-gnu.
    apt-get install -y --no-install-recommends $snap \
        cmake make gcc libc6-dev \
        gcc-13-multilib \
        gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
        mingw-w64 \
        ca-certificates curl xz-utils; \
    rm -rf /var/lib/apt/lists/*

# GNU MinGW has no ARM64 target. The msvcrt variant matches the originals' CRT.
ARG LLVM_MINGW=20251118
ARG LLVM_MINGW_SHA256=308a716d9655a4b068e27483d1fb762240e172931113a5aeb60632af75dc7638
RUN set -e; \
    curl -fsSL -o /tmp/llvm-mingw.tar.xz \
        "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW/llvm-mingw-$LLVM_MINGW-msvcrt-ubuntu-22.04-x86_64.tar.xz"; \
    echo "$LLVM_MINGW_SHA256  /tmp/llvm-mingw.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/llvm-mingw.tar.xz -C /opt; \
    mv /opt/llvm-mingw-* /opt/llvm-mingw; \
    rm /tmp/llvm-mingw.tar.xz
ENV PATH=$PATH:/opt/llvm-mingw/bin
