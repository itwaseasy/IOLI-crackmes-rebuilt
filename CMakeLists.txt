cmake_minimum_required(VERSION 3.18)
project(IOLI-crackme C)

# ---------------------------------------------------------------------------
# Output directory: bin/<os>-<arch>, e.g. bin/linux-x64, bin/windows-x32,
# bin/macos-arm64.
# CMAKE_SYSTEM_PROCESSOR reports the *host* CPU in several cases (e.g. MSVC
# with -A Win32, or -m32 on Linux), so pointer size decides the bitness and
# the processor only decides the family (x86 vs ARM).
# ---------------------------------------------------------------------------
string(TOLOWER "${CMAKE_SYSTEM_NAME}" TARGET_OS)
if(TARGET_OS STREQUAL "darwin")
    set(TARGET_OS "macos")
endif()

if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    set(_proc "${CMAKE_OSX_ARCHITECTURES}")
elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID)  # set by MSVC
    set(_proc "${CMAKE_C_COMPILER_ARCHITECTURE_ID}")
else()
    set(_proc "${CMAKE_SYSTEM_PROCESSOR}")
endif()
string(TOLOWER "${_proc}" _proc)

if(_proc MATCHES "arm|aarch64")
    set(_family "arm")
else()
    set(_family "x")
endif()
math(EXPR _bits "${CMAKE_SIZEOF_VOID_P} * 8")

set(OUTPUT_DIR "${PROJECT_SOURCE_DIR}/bin/${TARGET_OS}-${_family}${_bits}")
message(STATUS "Output directory: ${OUTPUT_DIR}")

# ---------------------------------------------------------------------------
# Match the original IOLI crackme binaries (GCC 3.4 / MinGW 3.4, 2007):
#   - unoptimized (-O0), no stack canaries, no FORTIFY_SOURCE
#   - Linux:   no PIE, but NX stack and partial RELRO (lazy binding)
#   - Windows: no ASLR, no DEP, no SafeSEH, no CFG, no relocations
# Hardening invented later (CET, PAC/BTI, stack-clash probing) is also off.
# ---------------------------------------------------------------------------

# Always build unoptimized, whatever CMAKE_BUILD_TYPE is: drop the -O / /O
# flags (and MSVC's /RTC runtime checks) from CMake's per-config defaults.
foreach(_flags CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
               CMAKE_C_FLAGS_RELWITHDEBINFO CMAKE_C_FLAGS_MINSIZEREL)
    string(REGEX REPLACE "(^| )[-/]O[0-9a-z]*" " " ${_flags} "${${_flags}}")
    string(REGEX REPLACE "/RTC[1csu]*" "" ${_flags} "${${_flags}}")
endforeach()

if(MSVC)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    add_compile_options(
        /Od         # no optimization
        /GS-        # stack canaries (buffer security check)
        /sdl-       # extra SDL checks
        /guard:cf-  # Control Flow Guard
        /JMC-       # Just My Code debugging stubs
    )
    add_link_options(
        /GUARD:NO        # Control Flow Guard
        /INCREMENTAL:NO  # incremental-linking jump thunks
    )
    # ARM64 Windows requires ASLR and DEP, so only x86 can turn them off.
    if(_family STREQUAL "x")
        add_link_options(
            /DYNAMICBASE:NO  # ASLR
            /FIXED           # no .reloc section
            /NXCOMPAT:NO     # DEP
            /CETCOMPAT:NO    # Intel CET shadow stack
        )
        if(_bits EQUAL 64)
            add_link_options(/HIGHENTROPYVA:NO)  # 64-bit ASLR
        else()
            add_link_options(/SAFESEH:NO)        # safe exception handlers
        endif()
    endif()
else()
    # GCC / Clang / Apple Clang / MinGW. Only flags that depend on the
    # target or the toolchain version are checked; the rest are accepted by
    # every GCC and Clang in use.
    include(CheckCCompilerFlag)
    include(CheckLinkerFlag)

    function(add_compile_flag_if_supported flag)
        string(MAKE_C_IDENTIFIER "HAVE_C${flag}" var)
        check_c_compiler_flag("${flag}" ${var})
        if(${var})
            add_compile_options("${flag}")
        endif()
    endfunction()

    function(add_link_flag_if_supported flag)
        string(MAKE_C_IDENTIFIER "HAVE_LD${flag}" var)
        check_linker_flag(C "${flag}" ${var})
        if(${var})
            add_link_options("${flag}")
        endif()
    endfunction()

    add_compile_options(
        -O0                                     # no optimization
        -fno-builtin                            # keep printf, not puts
        -fno-stack-protector                    # stack canaries
        -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0   # checked libc calls
    )
    if(_family STREQUAL "x")
        add_compile_flag_if_supported(-fcf-protection=none)      # Intel CET
    else()
        add_compile_flag_if_supported(-mbranch-protection=none)  # PAC / BTI
    endif()

    if(WIN32)
        # MinGW. Newer binutils add a .reloc section even without ASLR, and
        # MinGW-w64's static runtime brings DWARF debug info; the originals
        # have neither (symbols are kept).
        add_link_options(-Wl,--strip-debug)
        # No build time in the PE header, so rebuilds are byte-for-byte
        # reproducible.
        add_link_options(-Wl,--no-insert-timestamp)
        # ARM64 Windows requires ASLR and DEP, so only x86 can turn them off.
        if(_family STREQUAL "x")
            add_link_flag_if_supported(-Wl,--disable-dynamicbase)   # ASLR
            add_link_flag_if_supported(-Wl,--disable-nxcompat)      # DEP
            add_link_flag_if_supported(-Wl,--disable-reloc-section) # .reloc
            if(_bits EQUAL 64)
                add_link_flag_if_supported(-Wl,--disable-high-entropy-va)
            endif()
        endif()
    elseif(APPLE)
        # Without a deployment target the binaries would only run on the
        # build machine's macOS version or newer. Target the oldest that
        # works: 11.0 is the first for arm64, and ld only accepts -no_pie
        # without a "deprecated" warning up to 10.13. The target has to match
        # at compile and link time.
        if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
            if(_family STREQUAL "x")
                set(_macos_min 10.13)
            else()
                set(_macos_min 11.0)
            endif()
            add_compile_options(-mmacosx-version-min=${_macos_min})
            add_link_options(-mmacosx-version-min=${_macos_min})
        endif()
        # PIE / ASLR can only be turned off for x86_64; arm64 always gets PIE.
        # NX can't be turned off.
        if(_family STREQUAL "x")
            add_link_options(-Wl,-no_pie)
        endif()
    else()
        # Apple Clang accepts this one but ignores it with a warning.
        add_compile_flag_if_supported(-fno-stack-clash-protection)
        add_compile_options(-fno-pie)          # PIE / ASLR
        add_link_options(
            -no-pie
            -Wl,-z,noexecstack                 # NX stack on
            -Wl,-z,relro -Wl,-z,lazy           # partial RELRO, no BIND_NOW
        )
    endif()
endif()

# ---------------------------------------------------------------------------
# One executable per source file in src/
# ---------------------------------------------------------------------------
file(GLOB SOURCES CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/src/*.c")

# The originals of these were shipped stripped (no symbol table). They're
# linked into <build>/unstripped and a stripped copy goes to bin/, so the
# unstripped one is still around for debugging. MSVC has no strip tool, but
# its executables carry no symbol table anyway (symbols go to the .pdb).
set(STRIPPED_TARGETS crackme0x07 crackme0x09)

# The originals of these were compiled as position-independent code (-fPIC:
# strings and globals reached through the GOT) but still linked as a normal
# fixed-address executable. Windows code doesn't use this model, and
# CMake's POSITION_INDEPENDENT_CODE would give -fPIE for an executable.
set(PIC_TARGETS crackme0x09)

foreach(src IN LISTS SOURCES)
    get_filename_component(name "${src}" NAME_WE)
    add_executable(${name} "${src}")

    if(name IN_LIST PIC_TARGETS AND NOT WIN32)
        target_compile_options(${name} PRIVATE -fPIC)
        # Modern x86 ELF linkers turn GOT loads into constants when the
        # executable isn't PIE; keep the GOT loads like the original.
        if(_family STREQUAL "x" AND NOT APPLE)
            target_compile_options(${name} PRIVATE -Wa,-mrelax-relocations=no)
        endif()
    endif()

    # The generator expressions stop multi-config generators (Visual Studio,
    # Xcode) from appending a Debug/Release subfolder.
    if(name IN_LIST STRIPPED_TARGETS AND CMAKE_STRIP)
        set_target_properties(${name} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_BINARY_DIR}/unstripped>"
        )
        # A custom command with a real OUTPUT (not a POST_BUILD step), so a
        # missing stripped copy is rebuilt and "clean" removes it. GNU strip
        # writes the current time into PE headers unless SOURCE_DATE_EPOCH is
        # set; other strip tools ignore it.
        set(stripped "${OUTPUT_DIR}/${name}${CMAKE_EXECUTABLE_SUFFIX}")
        add_custom_command(
            OUTPUT "${stripped}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUTPUT_DIR}"
            COMMAND "${CMAKE_COMMAND}" -E env SOURCE_DATE_EPOCH=0
                    "${CMAKE_STRIP}" -o "${stripped}" "$<TARGET_FILE:${name}>"
            DEPENDS ${name}
            COMMENT "Stripping ${name}"
            VERBATIM
        )
        add_custom_target(${name}-stripped ALL DEPENDS "${stripped}")
    else()
        set_target_properties(${name} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY "$<1:${OUTPUT_DIR}>"
        )
    endif()
endforeach()
