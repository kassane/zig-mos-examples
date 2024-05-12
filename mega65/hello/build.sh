#!/usr/bin/env bash

git clone --recursive https://github.com/MEGA65/mega65-libc

mos-mega65-clang -c mega65-libc/src/llvm/memory_asm.s

zig build-obj \
    hello.zig \
    -lc \
    -I$PWD/mega65-libc/include \
    -I$PWD/mega65-libc/include/mega65 \
    -I$HOME/zig-bootstrap/out/llvm-mos/mos-platform/common/include \
    -I$HOME/zig-bootstrap/out/llvm-mos/mos-platform/commodore/include \
    -I$HOME/zig-bootstrap/out/llvm-mos/mos-platform/c64/include \
    -I$HOME/zig-bootstrap/out/llvm-mos/mos-platform/mega65/include \
    memory_asm.o \
    -target mos-freestanding \
    -mcpu=mos65c02 \
    -O ReleaseSafe \
    -femit-bin=hello.obj

mos-mega65-clang \
    -O3 hello.obj \
    -o hello.prg

rm -fr mega65-libc
rm *.o*