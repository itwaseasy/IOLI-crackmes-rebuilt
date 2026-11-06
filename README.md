# IOLI crackmes, rebuilt

The IOLI crackmes are ten tiny reverse engineering exercises by Pau Oliva Fora (pof), from 2007. I know them from the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html), and if you've read a beginner writeup on reversing in the last decade or so, chances are it used one of them. They're old and outdated, but still surprisingly good: each level adds a small new twist, and none of them takes more than an evening.

The problem is the binaries. The originals are 32-bit only (Linux x86, Windows x86, and Windows CE on ARM, which is a fun museum piece by now), and there's no x64 version at all. There's [IOLI64](https://github.com/BinaryResearch/IOLI64), a port to x86-64, but it's archived, Linux-only, and built from approximately reconstructed sources.

So this is my attempt to do it properly: C sources that compile to code as close to the original binaries as a modern compiler allows (same compilation flags, same functions in the same order, same branch layout, same strings), pre-compiled for Linux, Windows, and macOS on x32, x64, and arm64. The `CMakeLists.txt` is included, so you can build them for any other OS, architecture, or compiler you like.

## What's inside

```
src/                  crackme0x00.c ... crackme0x09.c
bin/<os>-<arch>/      pre-compiled binaries
CMakeLists.txt        build for whatever else you have
cmake/                toolchain files for 32-bit and ARM64 Linux and for Windows
build-all.sh          rebuild everything in bin/
Dockerfile            the Linux and Windows build environment used by build-all.sh
```

| OS      | x32                 | x64               | arm64               |
|---------|---------------------|-------------------|---------------------|
| Linux   | `bin/linux-x32`     | `bin/linux-x64`   | `bin/linux-arm64`   |
| Windows | `bin/windows-x32`   | `bin/windows-x64` | `bin/windows-arm64` |
| macOS   | —                   | `bin/macos-x64`   | `bin/macos-arm64`   |

No 32-bit macOS, for obvious reasons.

No passwords or hints here either: that's the whole point. If you get stuck, the `README.txt` from the original archive has hints, and the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html) walks through every level.

## How close to the original is it?

Pretty close. I checked every level against the original Linux and Windows x86 binaries, function by function: the same functions in the same order, the same calls, the same conditions, and the same strings (on Linux, the whole string table is byte-for-byte identical). Then I ran the original Linux binaries and the rebuilt ones side by side on the same inputs, environment variables included, and got the same output and exit codes on every platform I could run them on. A few things that sound like details turned out to matter:

- The branches are in the original order. In several levels the original checks for the *wrong* password first, and that's visible in the disassembly, so the sources do the same.
- Dead code is kept. From 0x07 on, there's a block after a call that never returns; the original compiler kept it (along with its `wtf?` string), so it's here too.
- Function and global variable names come from the originals that have symbols, and 0x07 and 0x09 are stripped, just like the originals.
- On Linux, 0x09 is compiled as position-independent code but linked at a fixed address. Yes, the original was built like that.

### Compilation flags

The originals came from GCC 3.4.6 (Gentoo) and MinGW GCC 3.4.5, long before most of today's security features were on by default. So the build turns them off:

- No optimization (`-O0` or `/Od`), whatever build type you pick
- No stack canaries, no `_FORTIFY_SOURCE`
- No Intel CET, ARM PAC/BTI, or stack clash protection
- Linux: no PIE, but a non-executable stack and partial RELRO, exactly like the originals
- Windows: no ASLR, DEP, SafeSEH, CFG, or relocations, and the pre-compiled binaries link against `msvcrt.dll`, like the originals

Some platforms don't let you switch everything off:

- macOS on arm64 only runs PIE executables, and macOS never lets you make the stack executable
- Windows on ARM64 requires ASLR and DEP

### What still doesn't match

A modern GCC simply generates code differently from GCC 3.4, and no amount of C rewriting changes that:

- Loops are checked at the bottom, not at the top
- On Linux x86, arguments are pushed instead of stored with `mov [esp], ...`
- `main` sets up its stack differently: on Linux it realigns the stack before the frame is set up, not after, and the 16 bytes of padding GCC 3.4 added after realigning (with a `__chkstk` call on Windows) are gone
- Stack frames are laid out a bit differently

One more difference comes from glibc, not the compiler: on Linux, today's headers turn `scanf` and `sscanf` into `__isoc99_scanf` and `__isoc99_sscanf`, so those are the names you'll see in the imports and the disassembly. They're the same functions, just following the C99 rules.

If you follow a writeup made with the originals on x86, expect different addresses and stack offsets, but the same logic, conditions, and calls. On Windows x86 the match is even closer, since MinGW still passes arguments the old way. On x64 and arm64 the instructions are a different story anyway, but the program underneath is the same.

## Running them

- **Linux:** you need glibc 2.34 or newer (Ubuntu 22.04, Debian 12, RHEL 9, or anything newer). The x32 binaries also need the 32-bit C library, which most 64-bit systems don't install by default. Without it, they fail with a confusing `No such file or directory`, since what's missing is the 32-bit loader, not the binary itself:
  ```sh
  # Debian, Ubuntu
  sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install libc6:i386
  # RHEL, Fedora, and friends
  sudo dnf install glibc.i686
  ```
- **macOS:** 10.13+ on Intel and 11+ on Apple Silicon. The x64 binaries also run on Apple Silicon through Rosetta 2. They aren't notarized, so if you download them with a browser, macOS quarantines them. Run `xattr -dr com.apple.quarantine bin/macos-*` once, or allow each one in System Settings → Privacy & Security after the first failed attempt.
- **Windows:** plain console programs, run them from `cmd` or PowerShell.

## Building

```sh
cmake -S . -B build
cmake --build build
```

This builds for the machine you're on, and the binaries land in `bin/<os>-<arch>`, named after the target. That covers Linux x64 and arm64 and macOS on its native architecture. For the rest, there are toolchain files in `cmake/`:

```sh
# 32-bit Linux on x64 Linux (needs gcc-multilib)
cmake -S . -B build-x32 -DCMAKE_TOOLCHAIN_FILE=cmake/linux-i686.cmake

# ARM64 Linux on x64 Linux (needs gcc-aarch64-linux-gnu)
cmake -S . -B build-arm64 -DCMAKE_TOOLCHAIN_FILE=cmake/linux-aarch64.cmake

# Windows x32 and x64 (needs MinGW-w64)
cmake -S . -B build-win32 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-i686.cmake
cmake -S . -B build-win64 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-x86_64.cmake

# Windows on ARM64 (needs llvm-mingw, the msvcrt flavor to match the others)
cmake -S . -B build-winarm64 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-aarch64.cmake

# macOS for the other architecture, no toolchain file needed
cmake -S . -B build-x64 -DCMAKE_OSX_ARCHITECTURES=x86_64
```

Then `cmake --build <dir>` as usual. The toolchain files expect the compilers on your `PATH`: `aarch64-linux-gnu-gcc`, `i686-w64-mingw32-gcc`, `x86_64-w64-mingw32-gcc`, and [llvm-mingw](https://github.com/mstorsjo/llvm-mingw)'s `aarch64-w64-mingw32-clang`.

For anything else, write a toolchain file of your own, or use Visual Studio directly (`-A Win32`, `-A x64`, or `-A ARM64`). I've built everything with GCC, Clang (llvm-mingw), Apple Clang, and MinGW, all from Linux and macOS. MSVC should work too, but I haven't tried it, and it links against its own runtime instead of `msvcrt.dll`. Flags that only exist for some targets or compiler versions are checked first and skipped if the compiler doesn't know them.

### Rebuilding the pre-compiled binaries

The binaries in `bin/` come from `build-all.sh`. It builds the Linux and Windows targets in Docker, using the image from the `Dockerfile` (Ubuntu 24.04 with GCC 13, MinGW-w64, and llvm-mingw), so you don't need any of those compilers installed, and the macOS targets natively:

```sh
./build-all.sh                          # all 8 targets
./build-all.sh linux-x64 windows-x32    # just these
```

The targets are `linux-x32`, `linux-x64`, `linux-arm64`, `macos-x64`, `macos-arm64`, `windows-x32`, `windows-x64`, and `windows-arm64`. Each one is configured from scratch in `build/<target>`, and `bin/<target>` is emptied first, so nothing stale survives.

What you need:

- Docker (Docker Desktop or Docker Engine). The image is `linux/amd64`, so it runs natively on x64 and emulated on Apple Silicon (Docker Desktop does that out of the box; on an ARM64 Linux host, set up QEMU with `binfmt` first). The first run builds the image, which takes a few minutes; after that, a full build takes seconds.
- For the macOS targets, a Mac with the Xcode command-line tools. On Linux, they're skipped.

The Linux and Windows builds are reproducible: the same image gives byte-for-byte the same binaries, wherever it runs. The base image and llvm-mingw are pinned, but the Ubuntu packages come from the live archive, so a GCC or MinGW update can change the result. To get exactly the packages of a given day, take them from Ubuntu's snapshot archive (slower, and only as reliable as `snapshot.ubuntu.com`):

```sh
APT_SNAPSHOT=20261106T000000Z ./build-all.sh
```

The macOS binaries depend on the Xcode version: another version gives the same code, but a few header fields differ.

## Credits

All the credit goes to Pau Oliva Fora for the original crackmes, to the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html) for keeping them alive, and to [IOLI64](https://github.com/BinaryResearch/IOLI64) for the first x64 port.

Happy hacking!
