# macOS (aarch64-darwin) suites

Found 2026-10-04 on a Nix-equipped macOS aarch64 machine. The Zig runner builds natively and passes its own suites (core, core runner, meta cache, concurrency, CLI help, repo clean, user plugin precedence, direnv). Every language integration suite fails there, and failed the same way with the old Bash runner:

- Tests restrict `PATH` on purpose, to prove a plugin needs nothing from the host before its flake supplies tools (INTENT.md). On macOS `dirname` lives in /usr/bin, outside that PATH, and plugins call it first, so they fail at `dirname: command not found`. The fix belongs in the plugins (Bash builtins such as `${BASH_SOURCE%/*}`), not in a wider test PATH. The Wat `--no-deps` test fix on Linux (adding coreutils' directory) is the exception: with --no-deps the host tools are the point.
- The C and C++ builds abort with exit 134 (seen in the C, C++, shebang roundtrip and absolute-path suites).
- The Roc suite needs a Roc compiler on that machine (`JUMPSCRIPT_ROC`).

## Resolved 2026-10-04

- Host tools: plugins use only nix and bash before their flakes take over (plugins/_lib/plugin_lib.bash), and the integration suites now enforce that on Linux too (tests/lib/host.bash).
- The C/C++ aborts (exit 134) came from GCC 13.2 in the nixos-24.05 pin: its binary carries a duplicate LC_RPATH, which current macOS dyld refuses to load. The nixos-26.05 pin (GCC 15.3) fixes it, and the D segfault (exit 139) went with it.
- Dependency-rebuild cases used GNU `touch -d @N`; they now use `set_mtime` (POSIX `touch -t`, with GNU or BSD `date` formatting the time).
- Crystal 1.19.1 (nixos-26.05's default) aborts at startup with an arithmetic overflow in `default_workers_count` when it sees 128 or more CPUs; 127 works (checked with taskset on a 128-CPU Linux machine). The plugin uses crystal_1_18 (1.18.2) until upstream fixes it.
- Roc on macOS: the plugin gets roc from the roc_luajit flake. Its Darwin package needed two fixes there: Zig in the Nix sandbox finds the SDK only through `-iframework DIR` and a joined `-LDIR` in NIX_CFLAGS_COMPILE/NIX_LDFLAGS, and roc needs its libSystem stub installed as `bin/darwin` beside the executable for native links. Every suite now passes on macOS aarch64.
