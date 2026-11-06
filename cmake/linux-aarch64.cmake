# Cross-compile ARM64 Linux executables on an x86_64 Linux host
# (needs gcc-aarch64-linux-gnu):
#   cmake -S . -B build-arm64 -DCMAKE_TOOLCHAIN_FILE=cmake/linux-aarch64.cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
