# IOLI crackmes, rebuilt

If you've read a beginner writeup on reverse engineering in the last decade or so, chances are it used one of the IOLI crackmes. Ten tiny exercises by Pau Oliva Fora (pof) from 2007, each adding a small new twist, none taking more than an evening. I know them from the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html), and they're still surprisingly good.

The binaries, though, haven't aged well. They're 32-bit only: Linux x86, Windows x86, and Windows CE on ARM, which is a fun museum piece by now. There's no x64 version at all. [IOLI64](https://github.com/BinaryResearch/IOLI64) did port them to x86-64, but it's archived, Linux-only, and built from approximately reconstructed sources.

So I rebuilt them: C sources that compile to code as close to the originals as a modern compiler allows (the same flags, the same functions in the same order, the same branches and strings), pre-compiled for Linux, Windows, and macOS on x32, x64, and arm64. There's a `CMakeLists.txt` too, if you want to try other architectures, operating systems, or compilers.

## What's inside

```
src/                  crackme0x00.c ... crackme0x09.c
bin/<os>-<arch>/      pre-compiled binaries
CMakeLists.txt        the build
cmake/                toolchain files for 32-bit and ARM64 Linux and for Windows
build-all.sh          rebuilds everything in bin/
Dockerfile            the Linux and Windows build environment for build-all.sh
```

| OS      | x32               | x64               | arm64               |
|---------|-------------------|-------------------|---------------------|
| Linux   | `bin/linux-x32`   | `bin/linux-x64`   | `bin/linux-arm64`   |
| Windows | `bin/windows-x32` | `bin/windows-x64` | `bin/windows-arm64` |
| macOS   | —                 | `bin/macos-x64`   | `bin/macos-arm64`   |

No 32-bit macOS, for obvious reasons.

No passwords or hints here either, that's the whole point. If you get stuck, the `README.txt` from the original archive has hints, and the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html) walks through every level.

## How close to the original is it?

Pretty close. I checked every level against the original Linux and Windows x86 binaries, function by function: the same functions in the same order, the same calls, the same conditions, and the same strings (on Linux, `.rodata` is byte-for-byte identical). Then I ran the original Linux binaries and the rebuilt ones side by side on the same inputs, with and without the environment variable the later levels look for, and got the same output and exit codes, with a couple of exceptions I'll get to below.

A few things that sound like details turned out to matter:

- The branches are in the original order. Several levels check for the *wrong* password first, and you can see that in the disassembly, so the sources do the same.
- Dead code is kept. From 0x07 on, there's a block after a call that never returns. The original compiler kept it (along with its `wtf?` string), so it's here too.
- Function and global variable names come from the originals that have symbols, and 0x07 and 0x09 are stripped, just like the originals.
- On Linux, 0x09 is compiled as position-independent code but linked at a fixed address. Yes, the original was built like that.
- From 0x04 on, `sscanf` parses a single `char` that isn't NUL-terminated, so it happily reads the byte after it. In the original, that byte belongs to the loop counter, so the local variables are declared in the order that puts it there again. Otherwise the result depends on whatever is left on the stack, which is not what you want from a crackme.

### Compilation flags

The originals came from GCC 3.4.6 (Gentoo) and MinGW GCC 3.4.5, long before most of today's security features were on by default. So the build turns them off:

- No optimization (`-O0` or `/Od`), whatever build type you pick
- No stack canaries, no `_FORTIFY_SOURCE`, no Intel CET, ARM PAC/BTI, or stack clash protection
- Linux: no PIE, but a non-executable stack and partial RELRO, exactly like the originals
- Windows: no ASLR, DEP, SafeSEH, CFG, or relocations, and `printf`, `scanf`, and friends come from `msvcrt.dll`, like in the originals

Some platforms don't let you switch everything off: macOS on arm64 only runs PIE executables, macOS never lets you make the stack executable, and Windows on ARM64 requires ASLR and DEP.

### What still doesn't match

A modern GCC simply generates different code than GCC 3.4, and no amount of C rewriting changes that:

- Loops are checked at the bottom, not at the top
- On Linux x86, arguments are pushed instead of stored with `mov [esp], ...`
- `main` sets up its stack differently: on Linux it realigns the stack before the frame is set up, not after, and the 16 bytes of padding GCC 3.4 added after realigning (with a `__chkstk` call on Windows) are gone
- Stack frames are laid out a bit differently

Then there's glibc: today's headers turn `scanf` and `sscanf` into `__isoc99_scanf` and `__isoc99_sscanf`, so those are the names you'll see in the imports and the disassembly on Linux.

And on 64-bit Linux and macOS, input that only works by accident in the original can behave differently. A number too big for an `int` gets truncated to its low 32 bits instead of being capped at `INT_MAX`, so a few extra passwords pass. Input that isn't a number at all leaves variables uninitialized, so the result depends on the stack, just like in the original. The real passwords work the same on every target I could run.

So if you follow a writeup made with the originals on x86, expect different addresses and stack offsets, but the same logic, conditions, and calls. On Windows x86 the match is even closer, since MinGW still passes arguments the old way. On x64 and arm64 the instructions are a different story anyway, but the program underneath is the same.

## Running them

- **Linux:** you need glibc 2.34 or newer (Ubuntu 22.04, Debian 12, RHEL 9, or anything newer). The x32 binaries also need the 32-bit C library, which most 64-bit systems don't install by default. Without it, they fail with a confusing `No such file or directory` (or `not found`, depending on your shell), since what's missing is the 32-bit loader, not the binary itself:
  ```sh
  # Debian, Ubuntu
  sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install libc6:i386
  # RHEL, Fedora, and friends
  sudo dnf install glibc.i686
  ```
- **macOS:** 10.13+ on Intel and 11+ on Apple Silicon, and the x64 binaries also run on Apple Silicon through Rosetta 2. They aren't notarized, so if you download them with a browser, macOS quarantines them. Run `xattr -dr com.apple.quarantine bin/macos-*` once, or allow each one in System Settings → Privacy & Security after the first failed attempt.
- **Windows:** plain console programs, run them from `cmd` or PowerShell.

## Building

```sh
cmake -S . -B build
cmake --build build
```

This builds for the machine you're on: Linux x64 or arm64, or macOS on its native architecture. The binaries land in `bin/<os>-<arch>` in the source tree, so keep in mind that they replace the pre-compiled ones. For everything else, there are toolchain files in `cmake/`:

```sh
cmake -S . -B build-x32      -DCMAKE_TOOLCHAIN_FILE=cmake/linux-i686.cmake     # 32-bit Linux (gcc-multilib)
cmake -S . -B build-arm64    -DCMAKE_TOOLCHAIN_FILE=cmake/linux-aarch64.cmake  # ARM64 Linux (gcc-aarch64-linux-gnu)
cmake -S . -B build-win32    -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-i686.cmake     # Windows x32 (MinGW-w64)
cmake -S . -B build-win64    -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-x86_64.cmake   # Windows x64 (MinGW-w64)
cmake -S . -B build-winarm64 -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-aarch64.cmake  # Windows ARM64 (llvm-mingw, msvcrt flavor)
cmake -S . -B build-x64      -DCMAKE_OSX_ARCHITECTURES=x86_64                  # the other macOS architecture
```

The toolchain files expect the compilers on your `PATH`: `aarch64-linux-gnu-gcc`, `i686-w64-mingw32-gcc`, `x86_64-w64-mingw32-gcc`, and [llvm-mingw](https://github.com/mstorsjo/llvm-mingw)'s `aarch64-w64-mingw32-clang`.

For anything else, write a toolchain file of your own, or use Visual Studio directly (`-A Win32`, `-A x64`, or `-A ARM64`). I've built everything with GCC, Clang (llvm-mingw), Apple Clang, and MinGW, all from Linux and macOS. MSVC should work too, but I haven't tried it, and it links against its own runtime instead of `msvcrt.dll`. Flags that only exist for some targets or compiler versions are checked first and skipped if the compiler doesn't know them.

### Rebuilding the pre-compiled binaries

Everything in `bin/` comes from `build-all.sh`. It builds the Linux and Windows targets in Docker (Ubuntu 24.04 with GCC 13, MinGW-w64, and llvm-mingw, see the `Dockerfile`), so you don't need any of those compilers, and the macOS targets natively:

```sh
./build-all.sh                          # all targets
./build-all.sh linux-x64 windows-x32    # just these
```

The targets are `linux-x32`, `linux-x64`, `linux-arm64`, `windows-x32`, `windows-x64`, `windows-arm64`, `macos-x64`, and `macos-arm64`. Each one is configured from scratch in `build/<target>`, and `bin/<target>` is emptied first, so nothing stale survives.

You'll need Docker. The image is `linux/amd64`, so it runs natively on x64 and emulated on Apple Silicon (Docker Desktop takes care of that; on ARM64 Linux, set up QEMU with `binfmt` first). The first run builds the image, which takes a few minutes, and after that a full build takes seconds. The macOS targets need a Mac with the Xcode command-line tools, and anywhere else they're skipped.

The Linux and Windows builds are reproducible: the same image gives you the same binaries, byte for byte, wherever it runs. The base image and llvm-mingw are pinned, but the Ubuntu packages come from the live archive, so a GCC or MinGW update can change the result. If you want exactly the packages of a given day, take them from Ubuntu's snapshot archive (it's slower, and only as reliable as `snapshot.ubuntu.com`):

```sh
APT_SNAPSHOT=20261106T000000Z ./build-all.sh
```

The macOS binaries depend on the Xcode version: a different one gives you the same code, but a few header fields differ.

## Credits

All the credit goes to Pau Oliva Fora for the original crackmes, to the [radare2 book](https://book.rada.re/crackmes/ioli/intro.html) for keeping them alive, and to [IOLI64](https://github.com/BinaryResearch/IOLI64) for the first x64 port.

Happy hacking!
