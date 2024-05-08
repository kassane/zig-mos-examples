#!/usr/bin/env bash

zig build-obj \
    hello.zig \
    -lc \
    -target mos-freestanding \
    -O ReleaseSafe \
    -femit-bin=hello.obj

mos-c64-clang \
    -O3 hello.obj \
    -o hello.prg

rm *.o*