# Neo6502

Build:

```sh
zig build neo6502-graphics -Dsdk=/path/to/llvm-mos-sdk
```

Run with the [neo6502-firmware](https://github.com/paulscottrobson/neo6502-firmware) emulator:

```sh
# copy output to firmware storage
cp zig-out/bin/graphics.neo neo6502-firmware/storage/

# run
cd neo6502-firmware
./bin/neo storage/graphics.neo@0x800 cold
```
