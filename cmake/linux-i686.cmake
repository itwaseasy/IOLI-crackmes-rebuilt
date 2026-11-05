# 32-bit x86 Linux executables on an x86_64 Linux host (needs gcc-multilib):
#   cmake -S . -B build-x32 -DCMAKE_TOOLCHAIN_FILE=cmake/linux-i686.cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR i686)
set(CMAKE_C_COMPILER gcc)
set(CMAKE_C_FLAGS_INIT -m32)
