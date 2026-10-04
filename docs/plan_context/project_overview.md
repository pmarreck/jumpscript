# Project overview, constraints and working rules

Migrated from the retired PROJECT_PLAN.md (2026-10-04).

## Overview

Jumpscript enables edit-run workflows for compiled and transpiled languages by caching build artifacts behind a small CLI. It began as a Bash prototype and is developed with strict TDD, a hexagonal architecture (pure core, I/O adapters) and Nix-provisioned tooling.

## Constraints

- Targets Linux and macOS with Nix installed.
- The runner is a Zig binary (`src/core.zig` pure decisions, `src/main.zig` I/O), built by `./build` into `bin/jumpscript` or packaged by the root flake. It replaced the original Bash runner on 2026-10-04; the shell suite still pins that runner's behavior.
- Rebuild policy is mtime-only; hashing modes are deferred until needed.
- Plugin layout: `plugins/<Language>/<variant>/` with `default/` as the fallback; the CLI accepts `<Language>-<variant>` tokens.

## Roadmap status at migration

- Core runner: command parsing, plugin discovery (including user plugin precedence), secure cache initialization, plugin-supplied dependency mtimes, meta persistence and binary execution are covered by shell tests.
- Nix environment orchestration: every plugin builds through its own flake with `bash --noprofile --norc`; host toolchains may be absent.
- Execution handoff: binaries are exec'd directly; text runtimes (Lua, Idris and others) go through `runtime_cmd` template substitution.
- Built-in plugins: Moon, WAT, C, C++, Crystal, D, Nim, Rust, Zig, Idris, Lean 4 and Roc, each with fixtures, a flake and an integration test.

## TDD notes

- Every behavior enters through a failing test under `tests/`.
- Unit tests stay deterministic and side-effect free; integration tests gate milestones.
- Update PLAN.md and `FILES.md` when new artifacts are introduced.
