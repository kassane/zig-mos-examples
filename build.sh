#!/usr/bin/env bash

ROOTPATH=$(pwd)

# Apple ][ examples
cd apple2/hello
bash build.sh
ls -lh
cd $ROOTPATH

# C64 examples
cd c64/hello
bash build.sh
ls -lh
cd $ROOTPATH
cd c64/fibonacci
bash build.sh
ls -lh
cd $ROOTPATH

# Mega65 examples
cd mega65/hello
bash build.sh
ls -lh
cd $ROOTPATH

# NESDOUG examples
cd nesdoug/hello1
bash build.sh
ls -lh
cd $ROOTPATH
cd nesdoug/hello2
bash build.sh
ls -lh
cd $ROOTPATH
cd nesdoug/hello3
bash build.sh
ls -lh
cd $ROOTPATH