# nesdoug NES examples

Zig ports of Doug Fraker's [nesdoug](https://nesdoug.com) NES tutorial series,
originally written in C for the llvm-mos toolchain.

## Reference

- **Original C source**: [nesdoug-llvm](https://github.com/nesdoug/nesdoug-llvm) by Doug Fraker
- **License**: MIT — Copyright (c) 2018 Doug Fraker, [www.nesdoug.com](https://nesdoug.com)

## Examples

| Directory   | Chapter    | Description                                                  |
|-------------|------------|--------------------------------------------------------------|
| `hello1/`   | 01_Hello   | Background text, basic palette setup                         |
| `hello2/`   | 02_Hello2  | Second hello variant                                         |
| `hello3/`   | 03_Hello3  | Third hello variant                                          |
| `fullbg/`   | 04_FullBG  | Full background with metatiles                               |
| `fade/`     | 05_Fade    | Palette fade in/out effect                                   |
| `color-cycle/` | 06_Color | Palette colour-cycle animation                              |
| `sprites/`  | 07_Sprites | OAM sprite display                                           |
| `pads/`     | 08_Pads    | Controller input with two 16×16 metasprites and collision    |
| `zig-logo/` | —          | Zig-mark logo with shimmer palette animation                 |
| `random/`   | 23_Random  | 64 sprites at random positions, three fall speeds            |
| `mappers/`  | 24_Mappers | CNROM 4-bank CHR demo — press Start to cycle banks           |
| `bat-ball/` | CH05*      | Bat-and-ball from ProgrammingGamesForTheNES CH05             |
| `megablast/` | CH06*     | Title screen + game screen from ProgrammingGamesForTheNES CH06 |

\* `bat-ball` and `megablast` are ported from
[tony-cruise/ProgrammingGamesForTheNES](https://github.com/tony-cruise/ProgrammingGamesForTheNES),
also MIT licensed.
