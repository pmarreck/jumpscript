# File Registry

| Path | Purpose | Created By |
| --- | --- | --- |
| `PROJECT_PLAN.md` | High-level roadmap and constraints for Jumpscript rebuild. | Codex (2025-10-27) |
| `test` | Unified entrypoint to run all unit tests. | Codex (2025-10-27) |
| `tests/test_core_runner.sh` | Validates core runner plugin discovery error handling. | Codex (2025-10-27) |
| `jumpscript` | Bootstrap CLI handling plugin version resolution. | Codex (2025-10-27) |
| `tests/test_integration_c.sh` | Integration test for the C plugin through the runner. | Codex (2025-10-28) |
| `tests/fixtures/hello_with_header.c` | C fixture exercising quoted include dependencies. | Codex (2025-10-29) |
| `tests/fixtures/hello_header.h` | Header fixture paired with `hello_with_header.c`. | Codex (2025-10-29) |
| `tests/fixtures/hello_with_include.nim` | Nim fixture covering `include` dependency tracking. | Codex (2025-10-29) |
| `tests/fixtures/hello_include_helper.nim` | Helper module consumed by Nim include fixture. | Codex (2025-10-29) |
| `tests/fixtures/hello_with_module.rs` | Rust fixture exercising `mod` dependency rebuilds. | Codex (2025-10-29) |
| `tests/fixtures/hello_helper.rs` | Rust helper module paired with `hello_with_module.rs`. | Codex (2025-10-29) |
| `tests/fixtures/hello_helper.idr` | Idris helper module consumed by import fixture. | Codex (2025-11-04) |
| `tests/fixtures/hello_with_import.idr` | Idris fixture covering import dependency rebuilds. | Codex (2025-11-04) |
| `tests/fixtures/hello_with_import.zig` | Zig fixture verifying module import dependency tracking. | Codex (2025-11-05) |
| `tests/fixtures/hello_helper.zig` | Zig helper module paired with `hello_with_import.zig`. | Codex (2025-11-05) |
| `tests/fixtures/hello_with_import.d` | D fixture exercising module import cache invalidation. | Codex (2025-11-05) |
| `tests/fixtures/hello_helper.d` | D helper module consumed by the D import fixture. | Codex (2025-11-05) |
| `tests/test_integration_moon.sh` | Integration test for the MoonScript plugin. | Codex (2025-10-28) |
| `tests/test_integration_wat.sh` | Integration test for the WAT plugin. | Codex (2025-10-28) |
| `tests/test_integration_cpp.sh` | Integration test for the C++ plugin. | Codex (2025-10-28) |
| `tests/test_integration_crystal.sh` | Integration test for the Crystal plugin. | Codex (2025-10-28) |
| `tests/test_integration_d.sh` | Integration test for the D plugin. | Codex (2025-10-28) |
| `tests/test_integration_nim.sh` | Integration test for the Nim plugin. | Codex (2025-10-28) |
| `tests/test_integration_rust.sh` | Integration test for the Rust plugin. | Codex (2025-10-28) |
| `tests/test_integration_zig.sh` | Integration test for the Zig plugin. | Codex (2025-10-28) |
| `tests/test_integration_idris.sh` | Integration test for the Idris plugin. | Codex (2025-10-28) |
| `tests/test_integration_lean.sh` | Integration test for the Lean 4 plugin. | Codex (2025-10-28) |
| `.envrc` | direnv script exporting repo root onto PATH for jumpscript CLI. | Codex (2025-11-04) |
| `tests/test_shebang_roundtrip.sh` | Ensures fixtures execute through shebang-driven CLI roundtrip. | Codex (2025-11-04) |
| `tests/test_cli_help.sh` | Verifies CLI about/help output lists cache and plugin locations. | Codex (2025-11-04) |
| `tests/test_repo_clean.sh` | Guards against stray build artifacts in the repo root. | Codex (2025-10-29) |
| `tests/test_user_plugin_precedence.sh` | Validates that user-provided plugins override bundled plugins. | Codex (2025-10-29) |
| `plugins/C/default/plugin` | Default C language plugin executable for runner contract. | Codex (2025-10-28) |
| `plugins/C/default/flake.nix` | Toolchain flake for the C plugin devshell. | Codex (2025-10-28) |
| `plugins/C/default/flake.lock` | Locked nixpkgs input for the C plugin devshell. | Codex (2025-10-28) |
| `plugins/Moon/default/plugin` | MoonScript plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Moon/default/flake.nix` | Toolchain flake for MoonScript plugin devshell. | Codex (2025-10-28) |
| `plugins/Moon/default/flake.lock` | Locked nixpkgs input for MoonScript devshell. | Codex (2025-10-28) |
| `plugins/Wat/default/plugin` | WAT plugin executable using nix flake toolchain and wazero runtime. | Codex (2025-10-28) |
| `plugins/Wat/default/flake.nix` | Toolchain flake for WAT plugin devshell. | Codex (2025-10-28) |
| `plugins/Wat/default/flake.lock` | Locked nixpkgs input for WAT devshell. | Codex (2025-10-28) |
| `plugins/C++/default/plugin` | C++ plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/C++/default/flake.nix` | Toolchain flake for C++ plugin devshell. | Codex (2025-10-28) |
| `plugins/C++/default/flake.lock` | Locked nixpkgs input for C++ devshell. | Codex (2025-10-28) |
| `plugins/Crystal/default/plugin` | Crystal plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Crystal/default/flake.nix` | Toolchain flake for Crystal plugin devshell. | Codex (2025-10-28) |
| `plugins/Crystal/default/flake.lock` | Locked nixpkgs input for Crystal devshell. | Codex (2025-10-28) |
| `plugins/D/default/plugin` | D plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/D/default/flake.nix` | Toolchain flake for D plugin devshell. | Codex (2025-10-28) |
| `plugins/D/default/flake.lock` | Locked nixpkgs input for D devshell. | Codex (2025-10-28) |
| `plugins/Nim/default/plugin` | Nim plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Nim/default/flake.nix` | Toolchain flake for Nim plugin devshell. | Codex (2025-10-28) |
| `plugins/Nim/default/flake.lock` | Locked nixpkgs input for Nim devshell. | Codex (2025-10-28) |
| `plugins/Rust/default/plugin` | Rust plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Rust/default/flake.nix` | Toolchain flake for Rust plugin devshell. | Codex (2025-10-28) |
| `plugins/Rust/default/flake.lock` | Locked nixpkgs input for Rust devshell. | Codex (2025-10-28) |
| `plugins/Zig/default/plugin` | Zig plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Zig/default/flake.nix` | Toolchain flake for Zig plugin devshell. | Codex (2025-10-28) |
| `plugins/Zig/default/flake.lock` | Locked nixpkgs input for Zig devshell. | Codex (2025-10-28) |
| `plugins/Idris/default/plugin` | Idris plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Idris/default/flake.nix` | Toolchain flake for Idris plugin devshell. | Codex (2025-10-28) |
| `plugins/Idris/default/flake.lock` | Locked nixpkgs input for Idris devshell. | Codex (2025-10-28) |
| `plugins/Lean/default/plugin` | Lean 4 plugin executable using nix flake toolchain. | Codex (2025-10-28) |
| `plugins/Lean/default/flake.nix` | Toolchain flake for Lean 4 plugin devshell. | Codex (2025-10-28) |
| `plugins/Lean/default/flake.lock` | Locked nixpkgs input for Lean 4 devshell. | Codex (2025-10-28) |
| `tests/test_runner_absolute_path.sh` | Ensures runner works from non-repo directories. | Codex (2025-10-28) |
