#!/usr/bin/env bash

zig build-obj \
    graphics.zig \
    -lc \
    -target mos-freestanding \
    -cflags \
    -mlto-zp=224 \
    -D__NEO6502__ \
    -- \
    -mcpu=mosw65c02 \
    -O ReleaseSafe \
    -femit-bin=graphics.obj

mos-neo6502-clang \
    -O3 graphics.obj \
    -o graphics.neo

rm *.o*