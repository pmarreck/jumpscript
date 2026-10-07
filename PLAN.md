# PLAN
Open work for jumpscript, highest priority first. Managed with the planning-work routine: completed items retire to docs/PLAN_LOG.md, background lives in docs/plan_context/ (start with project_overview.md).

## Now
- [x] End-to-end proof: dotfiles mandelbash ported to Roc as mandelroc (original unchanged; its name already says Bash); byte-identical output, warm run 7 ms vs 325 ms (done 2026-10-06 23:20 EDT)
- [ ] Commit mandelroc and its test in dotfiles once that suite is green on Linux (b3sum and expect missing make repo-maintenance-cli_test and timed_test fail)
- [ ] Cold Roc builds print the compiler's "0 errors and 0 warnings ... successfully building" chatter to stderr; show it only on failure
- [x] Cached artifacts survive Nix garbage collection: after each build the runner scans the artifact for store paths and roots them in its cache entry (`nix build --offline --out-link .gcroot`); tests/test_gc_roots.sh checks registered roots, passes on Linux x86_64 and macOS aarch64 (done 2026-10-06 14:30 EDT)
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

## Next
- [ ] Dependency tracking for the remaining languages (WAT module graphs, language package managers); C headers, Nim includes, Rust modules, Crystal requires, Idris imports, Lean modules, Zig imports and D modules are tracked
- [ ] Lean, Zig and Idris flakes: confirm minimal toolchains (Lean: lake, lean and a C toolchain; Idris: Node; Zig flags still produce native binaries)
- [ ] Flakes: common dependencies and documented override patterns; explore plugin-configurable dependency injection
- [ ] tests/test_runner_absolute_path.sh: cover more languages
- [ ] CLI flag regression coverage: --no-* flags across representative languages (C, Nim, MoonScript), run from outside the repo root
- [ ] Host tool availability: warn when --no-* is set but required host binaries are missing; document in README and plugin help
- [ ] Host-runtime metadata: let every plugin record resolved runtime binaries in its cache entry, as Wat does
- [ ] Nix environment delta caching for warm rebuilds (context: docs/plan_context/nix_env_delta.md)
- [ ] Cache management CLI: cache ls and clean, rebuild triggers for toolchain version updates; clean must drop stale entries, whose .gcroot links otherwise keep old closures alive
- [ ] Silence the cc-wrapper `--target arm64-apple-macos14.0` and missing clang lib dir `ld` warnings in macOS suite output
- [ ] Plugin management CLI: plugins list, structured errors, doctor integration
- [ ] Configuration and security hardening: environment overrides, telemetry hooks, permission enforcement, diagnostics polish

## Later
- [ ] Elixir daemon: lifecycle (jumpscript elixir start|stop|status), socket permissions, key-based caching, IO streaming

## Earlier completions
