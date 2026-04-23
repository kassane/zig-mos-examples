# zig-mos-examples

<div align="center">
<img width="480" alt="Image" src="https://github.com/user-attachments/assets/fb6a11de-fd07-45c8-be6b-d3d7f5629c34" />
</div>

Zig examples targeting MOS 6502 platforms via zig-mos-bootstrap and llvm-mos-sdk.

## Requirements

- [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap/releases) — Zig toolchain with LLVM-MOS backend
- [llvm-mos-sdk](https://github.com/llvm-mos/llvm-mos-sdk/releases) — platform libraries and linker scripts

## Build

```sh
git clone https://github.com/kassane/zig-mos-examples.git
cd zig-mos-examples
zig build -Dsdk=/path/to/llvm-mos-sdk
```

Named steps (build one at a time):

```sh
zig build nes-hello1 -Dsdk=/path/to/llvm-mos-sdk
zig build nes-hello2 -Dsdk=/path/to/llvm-mos-sdk
zig build nes-hello3 -Dsdk=/path/to/llvm-mos-sdk
zig build nes-zig-logo -Dsdk=/path/to/llvm-mos-sdk
zig build nes-fade -Dsdk=/path/to/llvm-mos-sdk
zig build nes-sprites -Dsdk=/path/to/llvm-mos-sdk
zig build nes-pads -Dsdk=/path/to/llvm-mos-sdk
zig build nes-color-cycle -Dsdk=/path/to/llvm-mos-sdk
zig build c64-hello -Dsdk=/path/to/llvm-mos-sdk
zig build c64-fibonacci -Dsdk=/path/to/llvm-mos-sdk
zig build c64-plasma -Dsdk=/path/to/llvm-mos-sdk
zig build neo6502-graphics -Dsdk=/path/to/llvm-mos-sdk
```

Optional platforms:

```sh
# MEGA65 — mega65-libc fetched automatically via build.zig.zon
zig build mega65-hello  -Dsdk=/path/to/llvm-mos-sdk
zig build mega65-plasma -Dsdk=/path/to/llvm-mos-sdk

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
