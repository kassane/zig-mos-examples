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

![](https://github-production-user-asset-6210df.s3.amazonaws.com/6756180/340118823-f2808c89-3da2-46d9-b670-bfe28bad9fbd.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20240616%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20240616T165536Z&X-Amz-Expires=300&X-Amz-Signature=5628d895f1b3ff4b4f2c2d372a1e05e9c3cad11a137567030a85444f47c0b5e2&X-Amz-SignedHeaders=host&actor_id=0&key_id=0&repo_id=0)
