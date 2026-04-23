# zig-mos-examples

<div align="center">
<img width="480" alt="Image" src="https://github.com/user-attachments/assets/fb6a11de-fd07-45c8-be6b-d3d7f5629c34" />
</div>

Zig examples targeting MOS 6502 platforms via zig-mos-bootstrap and llvm-mos-sdk.

## Requirements

- [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap/releases) — Zig toolchain with LLVM-MOS backend

## Build

```sh
git clone https://github.com/kassane/zig-mos-examples.git
cd zig-mos-examples
zig build --summary all
```

Named steps (build one at a time):

```sh
zig build nes-hello1
zig build nes-hello2
zig build nes-hello3
zig build nes-zig-logo
zig build nes-fade
zig build nes-sprites
zig build nes-pads
zig build nes-color-cycle
zig build c64-hello
zig build c64-fibonacci
zig build c64-plasma
zig build neo6502-graphics
```

Optional platforms:

```sh
# MEGA65 — mega65-libc fetched automatically via build.zig.zon
zig build mega65-hello 
zig build mega65-plasma

# Apple II — needs apple-ii-port-work checkout
zig build apple2-hello -Dsdk=... -Dapple2-sdk=/path/to/apple-ii-port-work
```

Output files land in `zig-out/bin/`.

## Platforms

| Step | Platform | CPU | Output |
|------|----------|-----|--------|
| `nes-hello1`, `nes-hello2`, `nes-hello3` | NES NROM | mosw65c02 | `.nes` |
| `nes-zig-logo` | NES NROM | mosw65c02 | `.nes` |
| `nes-fade` | NES NROM | mosw65c02 | `.nes` |
| `nes-sprites` | NES NROM | mosw65c02 | `.nes` |
| `nes-pads` | NES NROM | mosw65c02 | `.nes` |
| `nes-color-cycle` | NES NROM | mosw65c02 | `.nes` |
| `c64-hello`, `c64-fibonacci` | Commodore 64 | mos6502 | `.prg` |
| `c64-plasma` | Commodore 64 | mos6502 | `.prg` |
| `neo6502-graphics` | Neo6502 | mosw65c02 | `.neo` |
| `mega65-hello`, `mega65-plasma` | MEGA65 | mos45gs02 | `.prg` |
| `apple2-hello` | Apple IIe ProDOS | mos6502 | `.sys` |

## References

- [Nesdoug LLVM-MOS tutorial](https://github.com/mysterymath/nesdoug-llvm)
- [llvm-mos-sdk examples](https://github.com/llvm-mos/llvm-mos-sdk/tree/main/examples)
- [rust-mos-hello-world](https://github.com/mrk-its/rust-mos-hello-world)

## License

Apache 2.0 — see LICENSE.
