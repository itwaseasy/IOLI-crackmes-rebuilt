# IOLI crackmes, rebuilt

The IOLI crackmes are ten tiny reverse engineering exercises by Pau Oliva Fora (pof), from 2007. I know them from the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html), and if you've read a beginner writeup on reversing in the last decade or so, chances are it used one of them. They're old and outdated, but still surprisingly good: each level adds exactly one new idea, and none of them takes more than an evening.

The problem is the binaries. The originals are 32-bit only (Linux x86, Windows x86, and Windows CE on ARM, which is a fun museum piece by now), and there's no x64 version at all. There's [IOLI64](https://github.com/BinaryResearch/IOLI64), a port to x86-64, but it's archived, Linux-only, and built from approximately reconstructed sources.

So this is my attempt to do it properly: C sources that compile to code as close to the original binaries as a modern compiler allows (same compilation flags, same functions in the same order, same branch layout, same strings), pre-compiled for Linux, Windows, and macOS on x32, x64, and arm64. The `CMakeLists.txt` is included, so you can build them for any other OS, architecture, or compiler you like.

## What's inside

```
src/                  crackme0x00.c ... crackme0x09.c
bin/<os>-<arch>/      pre-compiled binaries
CMakeLists.txt        build for whatever else you have
cmake/                toolchain files for 32-bit Linux and cross-compiling to Windows
```

| OS      | x32                 | x64               | arm64               |
|---------|---------------------|-------------------|---------------------|
| Linux   | `bin/linux-x32`     | `bin/linux-x64`   | `bin/linux-arm64`   |
| Windows | `bin/windows-x32`   | `bin/windows-x64` | `bin/windows-arm64` |
| macOS   | —                   | `bin/macos-x64`   | `bin/macos-arm64`   |

No 32-bit macOS, for obvious reasons.

No passwords or hints here either: that's the whole point. If you get stuck, the `README.txt` from the original archive has hints, and the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html) walks through every level.

## How close to the original is it?

Pretty close. I checked every level against the original binaries, function by function: the same functions in the same order, the same calls, the same branch structure, and byte-for-byte identical string tables. Then I ran the original Linux binaries and the rebuilt ones side by side on the same inputs, environment variables included, and got the same output and exit codes on every platform I could run them on. A few things that sound like details turned out to matter:

- The branches are in the original order. In several levels the original checks for the *wrong* password first, and that's visible in the disassembly, so the sources do the same.
- Dead code is kept. From 0x07 on, there's a block after a call that never returns; the original compiler kept it (along with its `wtf?` string), so it's here too.
- Function and variable names come from the originals where they have symbols, and 0x07 and 0x09 are stripped, just like the originals.
- On Linux, 0x09 is compiled as position-independent code but linked at a fixed address. Yes, the original was built like that.

### Compilation flags

The originals came from GCC 3.4.6 (Gentoo) and MinGW GCC 3.4.5, with none of the security features you'd get from a compiler today. So the build turns them off:

- No optimization (`-O0` or `/Od`), whatever build type you pick
- No stack canaries, no `_FORTIFY_SOURCE`
- No Intel CET, ARM PAC/BTI, or stack clash protection
- Linux: no PIE, but a non-executable stack and partial RELRO, exactly like the originals
- Windows: no ASLR, DEP, SafeSEH, CFG, or relocations, and linked against `msvcrt.dll`

Some platforms don't let you switch everything off:

- macOS on arm64 only runs PIE executables, and macOS never lets you make the stack executable
- Windows on ARM64 requires ASLR and DEP

### What still doesn't match

A modern GCC simply generates code differently from GCC 3.4, and no amount of C rewriting changes that:

- Loops are checked at the bottom, not at the top
- On Linux x86, arguments are pushed instead of stored with `mov [esp], ...`
- `main` realigns the stack in its prologue
- Stack frames are laid out a bit differently

If you follow a writeup made with the originals, expect different addresses and stack offsets, but the same logic, branches, and calls everywhere. On Windows x86 the match is even closer, since MinGW still passes arguments the old way.

## Running them

- **Linux:** you need glibc 2.34 or newer (Ubuntu 22.04, Debian 12, RHEL 9, or anything newer).
- **macOS:** 10.13+ on Intel and 11+ on Apple Silicon. The binaries aren't notarized, so macOS quarantines them after download. Run `xattr -d com.apple.quarantine <file>` on each one, or right-click it and pick Open.
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

# Windows x32 and x64 from Linux or macOS (needs MinGW-w64)
cmake -S . -B build-win32 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-i686.cmake
cmake -S . -B build-win64 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-x86_64.cmake

# Windows on ARM64 (needs llvm-mingw, the msvcrt flavor to match the others)
cmake -S . -B build-winarm64 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-aarch64.cmake

# macOS for the other architecture, no toolchain file needed
cmake -S . -B build-x64 -DCMAKE_OSX_ARCHITECTURES=x86_64
```

Then `cmake --build <dir>` as usual. The toolchain files expect the compilers on your `PATH`: `i686-w64-mingw32-gcc`, `x86_64-w64-mingw32-gcc`, and [llvm-mingw](https://github.com/mstorsjo/llvm-mingw)'s `aarch64-w64-mingw32-clang`.

For anything else, write a toolchain file of your own, or use Visual Studio directly (`-A Win32`, `-A x64`, or `-A ARM64`). I've built everything with GCC, Clang (llvm-mingw), Apple Clang, and MinGW. MSVC should work too, but I haven't tried it. Flags that only exist for some targets or compiler versions are checked first and skipped if the compiler doesn't know them.

## Credits

All the credit goes to Pau Oliva Fora for the original crackmes, to the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html) for keeping them alive, and to [IOLI64](https://github.com/BinaryResearch/IOLI64) for the first x64 port.

Happy hacking!
