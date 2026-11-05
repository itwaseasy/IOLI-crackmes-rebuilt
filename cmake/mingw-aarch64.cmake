# Cross-compile Windows on ARM64 executables with llvm-mingw
# (https://github.com/mstorsjo/llvm-mingw):
#   cmake -S . -B build-winarm64 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-aarch64.cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR ARM64)
set(CMAKE_C_COMPILER aarch64-w64-mingw32-clang)
