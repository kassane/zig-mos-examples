## How to work

- Download [neo6502-firmware (+emulator)](https://github.com/paulscottrobson/neo6502-firmware)
- Build the firmware only or firmware and emulator
- Build zig example and move/copy&paste the binaries to the `neo6502-firmware/storage` folder
- Run the emulator

```bash
$ cd neo6502-firmware
$ ./bin/neo
# or
$ cd neo6502-firmware/storage
$ ../bin/neo graphics.neo@0x800 cold
```

## Preview

![image](https://gist.github.com/assets/6756180/f2808c89-3da2-46d9-b670-bfe28bad9fbd)
