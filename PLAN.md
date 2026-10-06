# PLAN
Open work for jumpscript, highest priority first. Managed with the planning-work routine: completed items retire to docs/PLAN_LOG.md, background lives in docs/plan_context/ (start with project_overview.md).

## Now
- [ ] Keep cached artifacts runnable across Nix garbage collection: root each build environment (for example `nix develop --profile <entry>/.gcroot`) so a binary's dynamic loader and libraries stay in the store; test by collecting garbage between a build and a warm run
- [x] Build cache entries carry a toolchain digest (plugin files such as flake.nix/flake.lock, plus the build command), so a new pin rebuilds instead of running a binary whose glibc was garbage-collected; test_shebang_roundtrip uses a private cache (done 2026-10-06 11:20 EDT)
- [x] Plugin pins nixos-24.05 to nixos-26.05 (Zig 0.16, Lean 4.29, GCC 15, Rust 1.95); Zig fixtures ported to 0.16; Crystal held at 1.18; every suite but Roc passes on macOS aarch64 (done 2026-10-04 17:25 EDT) (context: docs/plan_context/macos.md)
- [ ] Toolchain pins (BDFN walking brief V3, 2026-10-06): repository-level pins are each plugin's own flake.nix/flake.lock, a CLI command updates them, a script may override with a nixpkgs commit hash in a comment; draft the lookup rules for BDFN, then implement (INTENT.md) (context: docs/plan_context/toolchain_pins.md)
- [ ] Offline runs: a warm script runs and rebuilds with networking disabled; add a test that runs it in a network namespace, and fix what needs the network (INTENT.md)
- [ ] Crystal: return from crystal_1_18 to the default once Crystal fixes its overflow on machines with 128 or more CPUs (context: docs/plan_context/macos.md)
- [x] Roc plugin procures its compiler and the WASI basic-cli platform from the roc_luajit flake; JUMPSCRIPT_ROC and JUMPSCRIPT_ROC_WASI_PLATFORM are optional overrides; every suite passes on Linux and macOS aarch64 with only nix and bash on PATH (done 2026-10-04 23:35 EDT) (context: docs/plan_context/macos.md)
- [x] Plugins need only nix and bash before their flakes take over: pure-Bash helpers in plugins/_lib, tests run plugins with a PATH of just nix and bash, Moon gets Lua from its flake (done 2026-10-04 17:01 EDT)
- [x] Run the runner's own suites on macOS aarch64; portable mtimes in test_meta_cache (done 2026-10-04 16:13 EDT, b8941ad)
- [x] Remove runner races: one build per cache entry, cache dirs created at mode 700, atomic meta.env and meta-cache writes (done 2026-10-04 16:07 EDT, 7a1f437) (context: docs/plan_context/zig_runner.md)
- [x] --about prints version, purpose, OS and architecture (done 2026-10-04 16:02 EDT, 36a02ec)
- [x] Zig runner replaces the Bash runner, with a plugin meta cache: warm run 180 ms to 1.1 ms (done 2026-10-04 15:45 EDT, 4bb74a5 + 4260ba8) (context: docs/plan_context/zig_runner.md)
- [x] Roc-luajit and Roc-wasm shebang tokens for extensionless Roc scripts (done 2026-10-04 13:30 EDT, 44bfce9)
- [x] Roc .wasm.roc scripts build for wasm32 and run under wasmtime (done 2026-10-03 13:55 EDT, 3b796f1)

## Next
- [ ] Dependency tracking for the remaining languages (WAT module graphs, language package managers); C headers, Nim includes, Rust modules, Crystal requires, Idris imports, Lean modules, Zig imports and D modules are tracked
- [ ] Lean, Zig and Idris flakes: confirm minimal toolchains (Lean: lake, lean and a C toolchain; Idris: Node; Zig flags still produce native binaries)
- [ ] Flakes: common dependencies and documented override patterns; explore plugin-configurable dependency injection
- [ ] tests/test_runner_absolute_path.sh: cover more languages
- [ ] CLI flag regression coverage: --no-* flags across representative languages (C, Nim, MoonScript), run from outside the repo root
- [ ] Host tool availability: warn when --no-* is set but required host binaries are missing; document in README and plugin help
- [ ] Host-runtime metadata: let every plugin record resolved runtime binaries in its cache entry, as Wat does
- [ ] Nix environment delta caching for warm rebuilds (context: docs/plan_context/nix_env_delta.md)
- [ ] Cache management CLI: cache ls and clean, rebuild triggers for toolchain version updates
- [ ] Plugin management CLI: plugins list, structured errors, doctor integration
- [ ] Configuration and security hardening: environment overrides, telemetry hooks, permission enforcement, diagnostics polish

## Later
- [ ] Elixir daemon: lifecycle (jumpscript elixir start|stop|status), socket permissions, key-based caching, IO streaming

## Earlier completions
