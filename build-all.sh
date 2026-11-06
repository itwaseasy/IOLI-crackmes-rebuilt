#!/bin/sh
# Build release targets into bin/<os>-<arch>:
#   ./build-all.sh                        all targets
#   ./build-all.sh linux-x64 macos-arm64  just these
# Linux and Windows build in Docker, macOS natively.
# shellcheck disable=SC2046,SC2086  # target lists are split on purpose
set -e
cd "$(dirname "$0")"

cmake_options() {
    case $1 in
        linux-x32)     echo -DCMAKE_TOOLCHAIN_FILE=cmake/linux-i686.cmake ;;
        linux-x64)     ;;
        linux-arm64)   echo -DCMAKE_TOOLCHAIN_FILE=cmake/linux-aarch64.cmake ;;
        windows-x32)   echo -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-i686.cmake ;;
        windows-x64)   echo -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-x86_64.cmake ;;
        windows-arm64) echo -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-aarch64.cmake ;;
        macos-x64)     echo -DCMAKE_OSX_ARCHITECTURES=x86_64 ;;
        macos-arm64)   echo -DCMAKE_OSX_ARCHITECTURES=arm64 ;;
        *)             return 1 ;;
    esac
}

build() {
    for target in "$@"; do
        echo "==> $target"
        rm -rf "build/$target" "bin/$target"
        cmake -S . -B "build/$target" $(cmake_options "$target") >/dev/null
        cmake --build "build/$target" --parallel
    done
}

# The Docker part runs this script again, inside the container.
if [ "$1" = --in-docker ]; then
    shift
    build "$@"
    exit
fi

if [ $# -eq 0 ]; then
    set -- linux-x32 linux-x64 linux-arm64 windows-x32 windows-x64 windows-arm64 \
           macos-x64 macos-arm64
fi

docker_targets=''
macos_targets=''
for target in "$@"; do
    if ! cmake_options "$target" >/dev/null; then
        echo "unknown target: $target" >&2
        exit 1
    fi
    case $target in
        macos-*) macos_targets="$macos_targets $target" ;;
        *)       docker_targets="$docker_targets $target" ;;
    esac
done

if [ -n "$docker_targets" ]; then
    # A valueless --build-arg forwards APT_SNAPSHOT from the environment.
    docker build -q --platform linux/amd64 --build-arg APT_SNAPSHOT \
        -t ioli-build . >/dev/null
    docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" \
        -v "$PWD":/w -w /w ioli-build sh build-all.sh --in-docker $docker_targets
fi

if [ -n "$macos_targets" ]; then
    if [ "$(uname -s)" = Darwin ]; then
        build $macos_targets
    else
        echo "==> skipping$macos_targets (needs macOS)"
    fi
fi
