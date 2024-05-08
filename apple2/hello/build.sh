#!/usr/bin/env bash

git clone https://github.com/TheHans255/apple-ii-port-work

zig build-obj \
    hello.zig \
    -lc \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie-prodos \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie-prodos-cli \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie-prodos-hires \
    -I$PWD/apple-ii-port-work/src/lib/apple-ii \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie \
    -I$PWD/apple-ii-port-work/src/lib/apple-ii-bare \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie-bare \
    -I$PWD/apple-ii-port-work/src/lib/apple-ii-autostart-rom \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie-autostart-rom \
    -I$PWD/apple-ii-port-work/src/lib/apple-iie-prodos-stdlib \
    $PWD/apple-ii-port-work/src/lib/apple-iie-prodos/prodos-syscall.c \
    $PWD/apple-ii-port-work/src/lib/apple-iie-prodos-stdlib/prodos-char-io.c \
    $PWD/apple-ii-port-work/src/lib/apple-iie-prodos-stdlib/prodos-exit.c \
    -target mos-freestanding \
    -O ReleaseFast \
    -femit-bin=hello.obj

mos-common-clang \
    -Os \
    -flto \
    -T $PWD/apple-ii-port-work/src/lib/apple-ii-bare/link.ld \
    -static \
    hello.obj \
    -o hello.sys

rm *.o*
rm -fr apple-ii-port-work/