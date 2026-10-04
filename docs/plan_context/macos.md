# macOS (aarch64-darwin) suites

Found 2026-10-04 on a Nix-equipped macOS aarch64 machine. The Zig runner builds natively and passes its own suites (core, core runner, meta cache, concurrency, CLI help, repo clean, user plugin precedence, direnv). Every language integration suite fails there, and failed the same way with the old Bash runner:

- Tests restrict `PATH` on purpose, to prove a plugin needs nothing from the host before its flake supplies tools (INTENT.md). On macOS `dirname` lives in /usr/bin, outside that PATH, and plugins call it first, so they fail at `dirname: command not found`. The fix belongs in the plugins (Bash builtins such as `${BASH_SOURCE%/*}`), not in a wider test PATH. The Wat `--no-deps` test fix on Linux (adding coreutils' directory) is the exception: with --no-deps the host tools are the point.
- The C and C++ builds abort with exit 134 (seen in the C, C++, shebang roundtrip and absolute-path suites).
- The Roc suite needs a Roc compiler on that machine (`JUMPSCRIPT_ROC`).
