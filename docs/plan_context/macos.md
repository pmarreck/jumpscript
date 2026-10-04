# macOS (aarch64-darwin) suites

Found 2026-10-04 on a Nix-equipped macOS aarch64 machine. The Zig runner builds natively and passes its own suites (core, core runner, meta cache, concurrency, CLI help, repo clean, user plugin precedence, direnv). Every language integration suite fails there, and failed the same way with the old Bash runner:

- Tests restrict `PATH` to directories that lack `dirname` (and other coreutils) on macOS, so plugins fail at `dirname: command not found`. The same shape was fixed for the Wat `--no-deps` test on Linux by adding coreutils' directory.
- The C and C++ builds abort with exit 134 (seen in the C, C++, shebang roundtrip and absolute-path suites).
- The Roc suite needs a Roc compiler on that machine (`JUMPSCRIPT_ROC`).
