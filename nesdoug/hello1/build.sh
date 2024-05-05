#!/usr/bin/env bash

ROOTDIR=$HOME/zig-bootstrap/out
ZIG_DIR=$ROOTDIR/zig-mos-x86_64-linux-musl-baseline
LLVMMOS_SDK=$ROOTDIR/llvm-mos

# Zig code
$ZIG_DIR/zig build-obj \
    -fno-compiler-rt \
    hello.zig \
    -target mos-freestanding \
    -O ReleaseSmall \
    -femit-bin=hello.zig.obj

# C code
# $LLVMMOS_SDK/bin/mos-nes-nrom-clang \
#     -O3 -DNDEBUG -MD -MT hello.c.obj \
#     -MF hello.c.obj.d \
#     -o hello.c.obj \
#     -c hello.c

# Assemble
$LLVMMOS_SDK/bin/mos-nes-nrom-clang \
    -O3 -DNDEBUG -o chr-rom.s.obj \
    -c chr-rom.s

# Object files
$LLVMMOS_SDK/bin/mos-nes-nrom-clang \
    -O3 -DNDEBUG hello.zig.obj chr-rom.s.obj \
    -o hello.nes  -lneslib
