#!/usr/bin/env bash

ROOTDIR=$HOME/zig-bootstrap/out
ZIG_DIR=$ROOTDIR/zig-mos-x86_64-linux-musl-baseline
LLVMMOS_SDK=$ROOTDIR/llvm-mos

# Zig code
$ZIG_DIR/zig build-obj \
    hello3.zig \
    chr-rom.s \
    -target mos-freestanding \
    -O ReleaseSafe \
    -femit-bin=hello.zig.obj

$LLVMMOS_SDK/bin/mos-nes-nrom-clang \
    -O3 hello.zig.obj \
    -o hello.nes -lneslib -lnesdoug
