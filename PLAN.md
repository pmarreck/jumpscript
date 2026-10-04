# PLAN
Open work for jumpscript, highest priority first. Managed with the planning-work routine: completed items retire to docs/PLAN_LOG.md, background lives in docs/plan_context/ (start with project_overview.md).

## Now
- [ ] macOS aarch64: plugins must work before Nix supplies tools (no host dirname), and the C/C++ builds abort with exit 134 (context: docs/plan_context/macos.md)
- [ ] Roc plugin procures its compiler through Nix (the roc_luajit flake) and builds the WASI basic-cli platform on demand; JUMPSCRIPT_ROC and JUMPSCRIPT_ROC_WASI_PLATFORM become optional overrides (INTENT.md)
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
- [x] Direct compile pipeline: C, C++, Crystal, D, Nim, Rust, Zig, Idris, Moon and Wat plugins stream originals without persistent staging (done 2025-11-05)
- [x] D module dependency tracking (done 2025-11-05)
- [x] Zig import dependency tracking (done 2025-11-05)
- [x] Lean module cache invalidation via reported .lean dependencies (done 2025-11-05)
