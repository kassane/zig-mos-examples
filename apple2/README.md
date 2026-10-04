# Apple II

ProDOS 8 SYS program built with the SDK's
[`mos-platform/apple2`](https://github.com/llvm-mos/llvm-mos-sdk/pull/444) platform
(llvm-mos-sdk PR #444), fetched automatically with the `llvm-mos-sdk` dependency.

```sh
zig build apple2-hello
```

Output: `zig-out/bin/hello.sys`, loaded by ProDOS at `$2000`. Prints
"hello, apple ii" through the Monitor COUT wrapper, waits for a keypress,
then exits through ProDOS QUIT.
