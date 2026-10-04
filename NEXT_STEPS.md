# Next Steps

## Completed
- **Lean 4 Native Build** (2025-10-29)
	- Lake-based scaffold generates native binaries under `bin/<script>` and passes `tests/test_integration_lean.sh`.
- **User Plugin Search Path** (2025-10-29)
	- Runner honours `${JUMPSCRIPT_USER_PLUGINS}` (default `${XDG_DATA_HOME:-$HOME/.local/share}/jumpscript/plugins`) ahead of bundled plugins.
- **Shebang Roundtrip Coverage** (2025-11-04)
	- `tests/test_shebang_roundtrip.sh` executes fixtures through their shebang, exercising the primary CLI surface along with the new `--about/--help` commands.
- **Shebang Opt-out Flags** (2025-11-04)
	- `--no-build-deps`, `--no-runtime-deps`, and `--no-deps` supported end-to-end, allowing shebangs to bypass Nix shells when host tooling is present.
- **Wat Host Runtime Shortcut** (2025-11-04)
	- Wat plugin caches resolved `wat2wasm`/`wazero` paths and skips Nix once binaries are warm; integration test verifies cached and shortcut execution paths.
- **Lean Module Cache Invalidation** (2025-11-05)
	- Lean plugin now reports `.lean` dependencies and injects matching `lean_lib` stanzas; integration test confirms helper edits force rebuilds.
- **Zig Import Dependency Tracking** (2025-11-05)
- **Zig Import Dependency Tracking** (2025-11-05)
	- Zig plugin parses local `@import` paths, tracks helper modules, and rebuilds when helpers change.
- **D Module Dependency Tracking** (2025-11-05)
	- D plugin maps `import` directives to local `.d`/`package.d` files and compiles them alongside the primary script; integration test asserts rebuilds on helper edits.
- **Direct Compile Pipeline** (2025-11-05)
	- C, C++, Crystal, D, Nim, Rust, Zig, Idris, Moon, and Wat plugins now stream originals (or transient sanitized copies) without persistent staging; matching tests assert metadata no longer references `source.*` intermediates.

## TODO
000. **macOS (aarch64-darwin) plugin suites (found 2026-10-04)**
	- On a Nix-equipped macOS aarch64 machine the runner builds and passes its own suites (core, core runner, meta cache, concurrency, CLI help, repo clean, user plugin precedence, direnv), but the language integration suites fail there with the old Bash runner too: tests restrict PATH to directories that lack `dirname` on macOS, and the C/C++ builds abort (exit 134). Roc needs a compiler on that machine.
00. **Remove runner races (BDFN 2026-10-04; races done)**; then build and run the suite on macOS aarch64 (a Nix-equipped Mac)
	- Concurrent runs of one script: one build per cache entry (an exclusive lock around check, build and stamp, with a re-check after acquiring it), cache directories created at mode 700 atomically instead of mkdir-then-chmod, and meta.env written atomically. A shell test starts several cold runs at once and asserts one build, correct output from all, and no permission errors.
0. **Zig runner (done 2026-10-04)**
	- Replace the Bash `bin/jumpscript` with a Zig binary: a pure core (argument parsing, meta parsing and validation, cache keys, staleness, runtime command expansion, meta-cache keying) plus a Zig I/O adapter (stat, mkdir, spawn, exec). Same CLI, plugin contract, cache layout and error messages; the existing shell suite is the behavioral oracle.
	- Cache plugin `meta` output so a warm run starts only the program. The key covers the plugin directory's files (names, mtimes, sizes), the script path, mtime and size, the `--no-*` flags, `PATH` and every `JUMPSCRIPT_*` variable. A cached entry is also invalid when a declared dependency's mtime changed or an absolute runtime path no longer exists.
	- Rebuild staleness compares nanosecond mtimes (the Bash runner compared whole seconds, so two edits within one second could reuse a stale build).
	- Measured before: a warm run takes 180 ms (the program 0.5 ms, the plugin's meta 18 ms, the rest about 50 process launches in the Bash runner). After: 1.1 ms, with the program 0.5 ms of it (54 syscalls; `main` takes `Init.Minimal` because building Zig's environment map cost more than the rest of the run).
1. **Include/Multi-file Coverage**
	- C headers, Nim includes, Rust modules, Crystal requires, Idris imports, Lean modules, and Zig imports now tracked; replicate the pattern for remaining languages (e.g., WAT module graphs, language-specific package managers) to validate cache keying across the board.

2. **Lean / Zig / Idris Flake Polishing**
	- Confirm flakes contain the minimal toolchains (e.g., ensure Lean’s flake provides `lake`, `lean`, and necessary C toolchain; Idris gets Node; Zig’s build flags still produce native binaries).

3. **Absolute-path Regression**
	- Expand `tests/test_runner_absolute_path.sh` to cover additional languages once plugins stabilize.

4. **Elixir Daemon (Future)**
	- Capture design requirements for BEAM daemon lifecycle (`jumpscript elixir start|stop|status`), sockets, caching.

5. **Nix Env Delta Caching**
	- Use `nix print-dev-env` (or equivalent diff) to record only the environment variables the devshell modifies during the initial build, store them alongside each cache entry, and replay them on subsequent runs to avoid spawning `nix develop` when artifacts are warm. Handle invalidation gracefully if the cached runner path disappears or the environment changes.

6. **Host-runtime Metadata**
	- Generalize the Wat optimization so every plugin can embed resolved runtime binaries (or their absolute paths) into the cache entry, eliminating fresh Nix shells for hot executions.

7. **CLI Flag Regression Coverage**
	- Add fixture-driven tests for the new `--no-*` flags across representative languages (e.g., C, Nim, MoonScript) and ensure each path exercises execution from outside the repo root.

8. **Host Tool Availability UX**
	- Emit actionable warnings when `--no-*` flags are set but required host binaries are absent; document the behavior in `README.md` and plugin help output.
