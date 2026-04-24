# zig-mos-examples

Zig examples targeting MOS 6502 platforms via [zig-mos-bootstrap](https://github.com/kassane/zig-mos-bootstrap) and [llvm-mos-sdk](https://github.com/llvm-mos/llvm-mos-sdk).

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
# NES
zig build nes-hello1
zig build nes-hello2
zig build nes-hello3
zig build nes-zig-logo
zig build nes-fade
zig build nes-sprites
zig build nes-pads
zig build nes-color-cycle
zig build nes-bat-ball
zig build nes-cnrom-hello
zig build nes-unrom-hello
zig build nes-mmc1-hello

# Commodore 64
zig build c64-hello
zig build c64-fibonacci
zig build c64-plasma

# Commander X16
zig build cx16-hello
zig build cx16-k-console-test

# Atari Lynx
zig build lynx-hello

# Atari 2600
zig build atari2600-colorbar
zig build atari2600-3e-colorbar

# Atari 8-bit
zig build atari8dos-hello
zig build atari8-cart-hello

# PC Engine
zig build pce-color-cycle
zig build pce-color-cycle-banked

# Neo6502
zig build neo6502-graphics

# mos-sim (6502 simulator)
zig build sim-hello
```

Optional platforms:

```sh
# MEGA65 — mega65-libc fetched automatically via build.zig.zon
zig build mega65-hello
zig build mega65-plasma
zig build mega65-viciv

# Apple II — needs apple-ii-port-work checkout
zig build apple2-hello -Dapple2-sdk=/path/to/apple-ii-port-work
```

Output files land in `zig-out/bin/`.

## Gallery

### NES

| Example | Preview |
|---------|---------|
| `nes-zig-logo` — Zig mark logo with shimmer palette animation | ![](.github/zig-logo.gif) |
| `nes-hello1` / `nes-hello2` / `nes-hello3` — text hello-world variants | ![](.github/hello.gif) |
| `nes-fade` — full-screen palette fade in/out | ![](.github/fade.gif) |
| `nes-sprites` — OAM sprite rendering | ![](.github/sprites.gif) |
| `nes-bat-ball` — simple ball-and-bat game loop | ![](.github/bat-ball.gif) |
| `nes-color-cycle` — background colour cycling | ![](.github/color-cycle.gif) |
| `nes-pads` — controller input display | ![](.github/pads.gif) |
| `nes-cnrom-hello` — CNROM banked CHR ROM | ![](.github/cnrom-hello.gif) |
| `nes-unrom-hello` — UNROM banked PRG ROM | ![](.github/unrom-hello.gif) |
| `nes-mmc1-hello` — MMC1 mapper | ![](.github/mmc1-hello.gif) |

### Other platforms

| Example | Preview |
|---------|---------|
| `c64-plasma` — Commodore 64 plasma effect | ![](.github/c64-plasma.gif) |
| `pce-color-cycle-banked` — PC Engine banked colour cycle | ![](.github/pce-color-cycle-banked.gif) |
| `atari2600-colorbar` — Atari 2600 colour bars | ![](.github/atari2600-colorbar.gif) |

## Platforms

| Step | Platform | CPU | Output |
|------|----------|-----|--------|
| `nes-hello1`, `nes-hello2`, `nes-hello3` | NES NROM | mos6502 | `.nes` |
| `nes-zig-logo` | NES NROM | mos6502 | `.nes` |
| `nes-fade` | NES NROM | mos6502 | `.nes` |
| `nes-sprites` | NES NROM | mos6502 | `.nes` |
| `nes-pads` | NES NROM | mos6502 | `.nes` |
| `nes-color-cycle` | NES NROM | mos6502 | `.nes` |
| `nes-bat-ball` | NES NROM | mos6502 | `.nes` |
| `nes-cnrom-hello` | NES CNROM | mos6502 | `.nes` |
| `nes-unrom-hello` | NES UNROM | mos6502 | `.nes` |
| `nes-mmc1-hello` | NES MMC1 | mos6502 | `.nes` |
| `c64-hello`, `c64-fibonacci` | Commodore 64 | mos6502 | `.prg` |
| `c64-plasma` | Commodore 64 | mos6502 | `.prg` |
| `cx16-hello` | Commander X16 | mosw65c02 | `.prg` |
| `cx16-k-console-test` | Commander X16 | mosw65c02 | `.prg` |
| `lynx-hello` | Atari Lynx | mos6502 | `.bll` |
| `atari2600-colorbar` | Atari 2600 | mos6502 | `.a26` |
| `atari2600-3e-colorbar` | Atari 2600 (3E) | mos6502 | `.a26` |
| `atari8dos-hello` | Atari 8-bit DOS | mos6502 | `.xex` |
| `atari8-cart-hello` | Atari 8-bit cart | mos6502 | `.rom` |
| `pce-color-cycle` | PC Engine | mosw65c02 | `.pce` |
| `pce-color-cycle-banked` | PC Engine banked | mosw65c02 | `.pce` |
| `neo6502-graphics` | Neo6502 | mosw65c02 | `.neo` |
| `sim-hello` | mos-sim (6502 simulator) | mos6502 | binary |
| `mega65-hello`, `mega65-plasma` | MEGA65 | mos45gs02 | `.prg` |
| `mega65-viciv` | MEGA65 VICIV | mos45gs02 | `.prg` |
| `apple2-hello` | Apple IIe ProDOS | mos6502 | `.sys` |

## sim-hello benchmark

Build and run in one step (no prebuilt `mos-sim` binary required):

```sh
zig build run-sim-hello
```

Or build the simulator separately first:

```sh
zig build build-mos-sim   # compiles mos-sim from llvm-mos-sdk source
zig build sim-hello
zig-out/bin/mos-sim zig-out/bin/sim-hello
```

```
mos-sim benchmarks
==================
fib(10) =     55  ( 439 cycles)
fib(20) =   6765  ( 857 cycles)
sieve<127>: 31 primes  (6552 cycles)
```

## Platform notes

- **NES CNROM hello** — uses translated `mapper.h` via `b.addTranslateC`; calls `set_chr_bank(0)` to initialise the CNROM CHR bank. ROM: 32 KB PRG + 8 KB CHR ROM.
- **NES UNROM hello** — uses translated `mapper.h`; calls `set_prg_bank(0)` to initialise the UNROM PRG bank. ROM: 256 KB PRG + 8 KB CHR RAM.
- **NES MMC1 hello** — uses translated `mapper.h`; calls `set_prg_bank(0)` and `set_mirroring(MIRROR_VERTICAL)` to initialise MMC1 registers. ROM: 256 KB PRG + 8 KB CHR RAM.
- **C64 hello** — uses translated `c64.h` (VIC-II typed struct) via `b.addTranslateC`; cycles VIC-II border colour register.
- **CX16 hello** — uses CBM KERNAL `cbm_k_chrout` to print "HELLO X16!", then cycles the border colour register.
- **Lynx hello** — uses translated `_mikey.h` (MIKEY typed struct) via `b.addTranslateC`; animates all 32 palette entries.
- **Atari 8-bit DOS hello** — uses `std.c.printf` via CIO-backed libc (E: screen editor device).
- **Atari 8-bit cart hello** — uses translated `_gtia.h` (GTIA write struct) via `b.addTranslateC`; cycles COLBK background colour, synced to ANTIC VCOUNT.
- **sim-hello** — uses translated `sim-io.h` (typed MMIO struct) via `b.addTranslateC`; benchmarks fib(10), fib(20), and sieve of Eratosthenes for primes < 128.

## References

- [Nesdoug LLVM-MOS tutorial](https://github.com/mysterymath/nesdoug-llvm)
- [llvm-mos-sdk examples](https://github.com/llvm-mos/llvm-mos-sdk/tree/main/examples)
- [rust-mos-hello-world](https://github.com/mrk-its/rust-mos-hello-world)

## License

Apache 2.0 — see LICENSE.
