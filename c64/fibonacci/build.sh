#!/usr/bin/env bash

zig build-obj \
    fibonacci.zig \
    -lc \
    -target mos-freestanding \
    -O ReleaseSafe \
    -femit-bin=fib.obj

mos-c64-clang \
    -O3 fib.obj \
    -lprintf_flt \
    -o fib.prg

rm *.o*