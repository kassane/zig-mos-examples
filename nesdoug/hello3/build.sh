#!/usr/bin/env bash

zig build-obj \
    hello3.zig \
    chr-rom.s \
    -target mos-freestanding \
    -O ReleaseSafe \
    -femit-bin=hello.zig.obj

mos-nes-nrom-clang \
    -O3 hello.zig.obj \
    -o hello.nes -lneslib -lnesdoug

rm *.o*