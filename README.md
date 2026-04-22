# zig-mos-examples

<img width="634" height="563" alt="Image" src="https://github.com/user-attachments/assets/fb6a11de-fd07-45c8-be6b-d3d7f5629c34" />

Zig examples targeting MOS 6502 platforms via zig-mos-bootstrap (Zig 0.17-mos-dev, LLVM 21) and llvm-mos-sdk.

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
zig build c64-hello  -Dsdk=/path/to/llvm-mos-sdk
zig build c64-fibonacci -Dsdk=/path/to/llvm-mos-sdk
zig build neo6502-graphics -Dsdk=/path/to/llvm-mos-sdk
```

Optional platforms (require extra paths):

```sh
# MEGA65 — needs mega65-libc checkout
zig build mega65-hello -Dsdk=... -Dmega65-libc=/path/to/mega65-libc

# Apple II — needs apple-ii-port-work checkout
zig build apple2-hello -Dsdk=... -Dapple2-sdk=/path/to/apple-ii-port-work
```

Output files land in `zig-out/bin/`.

## Platforms

| Step | Platform | CPU | Output |
|------|----------|-----|--------|
| `nes-hello1..3` | NES NROM | mosw65c02 | `.nes` |
| `c64-hello`, `c64-fibonacci` | Commodore 64 | mos6502 | `.prg` |
| `neo6502-graphics` | Neo6502 | mosw65c02 | `.neo` |
| `mega65-hello`, `mega65-plasma` | MEGA65 | mos45gs02 | `.prg` |
| `apple2-hello` | Apple IIe ProDOS | mos6502 | `.sys` |

## References

- [Nesdoug LLVM-MOS tutorial](https://github.com/mysterymath/nesdoug-llvm)
- [llvm-mos-sdk examples](https://github.com/llvm-mos/llvm-mos-sdk/tree/main/examples)
- [rust-mos-hello-world](https://github.com/mrk-its/rust-mos-hello-world)

## License

Apache 2.0 — see LICENSE.
