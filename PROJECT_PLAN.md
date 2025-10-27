# Jumpscript Project Plan

## Overview
Jumpscript enables edit-run workflows for compiled/transpiled languages by caching build artifacts behind a simple CLI. The current codebase is a Bash prototype; we will evolve it using strict TDD, hexagonal architecture, and Nix-provisioned tooling.

## Constraints
- MVP targets Linux/macOS with Nix installed.
- Core runner stays in Bash for bootstrapping; feature-complete `jumpscript` binary will ultimately be produced via a Zig-based build.
- Rebuild policy is mtime-only for now; hashing modes deferred until needed.
- Plugin layout: `plugins/<Language>/<version>/` with `default/` fallback. CLI accepts `<Language>-<version>` tokens.
- WAT support via wazero is a required new plugin.

## Feature Roadmap
1. **Core Runner Skeleton**  
   - Command parsing for `run`, plugin discovery via directory layout, secure cache init, and mtime-based rebuild checks.  
   - Status: command parsing, plugin discovery failure modes (including user plugin precedence), cache scaffolding, plugin-supplied dependency mtimes, meta persistence, and binary artifact execution verified by shell tests.
2. **Nix Environment Orchestrator**  
   - Resolve plugin flakes, execute build commands in ephemeral shells, persist `artifact` + `meta.json`.  
   - Status: all current plugins shell through their own flake with `bash --noprofile --norc`; host toolchains may be absent without impact.
3. **Execution Handoff Layer**  
   - Honor `exec_kind` / `runtime_cmd`, forward argv/stdin, capture exit status.  
   - Status: binary handoff uses `exec`; text runtimes (Lua/Idris) supported via template substitution.
4. **Cache Management CLI**  
   - Implement `cache ls|clean`, per-entry locking, rebuild triggers for version updates.
5. **Plugin Management CLI**  
   - `plugins list`, structured errors, and doctor scaffolding integrating plugin `doctor`.
6. **Elixir Daemon Lifecycle & IPC**  
   - Start/stop/status commands, socket permissions, key-based caching, IO streaming. (Not started.)
7. **Built-in Plugins**  
   - Provide contract-compliant plugins (with flakes + tests) for Moon, WAT, C, C++, Crystal, D, Nim, Rust, Zig, Idris, Lean 4.  
   - Status: all languages above wired with minimal fixtures and nix-backed builds; Lean 4 plugin now emits native binaries via Lake scaffolding.
8. **Configuration & Security Hardening**  
   - Environment overrides, telemetry hooks, permission enforcement, diagnostics polish.

### Upcoming Tasks
- Finalize Lean 4 plugin quoting and Lake scaffolding for stable native binaries.
- Extend include/multi-file coverage beyond C, Nim, and Rust to remaining languages (headers/modules) to exercise cache keying.
- Enhance flakes with common dependencies and document override patterns; explore plugin-configurable dependency injection.
- Design and implement the Elixir daemon lifecycle (`jumpscript elixir start|stop|status`).
- Expand absolute-path test to multiple languages to ensure non-repo invocations work universally.

## TDD Notes
- Every behavior enters via a failing test under `tests/`.
- Maintain deterministic, side-effect-free unit tests; integration tests gate major milestones.
- Update this plan and `FILES.md` as new artifacts are introduced.
