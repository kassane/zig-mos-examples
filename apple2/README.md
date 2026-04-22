# Apple II

Based on [apple-ii-port-work](https://github.com/TheHans255/apple-ii-port-work).

Requires the SDK checkout passed as a build option:

```sh
zig build apple2-hello \
  -Dsdk=/path/to/llvm-mos-sdk \
  -Dapple2-sdk=/path/to/apple-ii-port-work
```
