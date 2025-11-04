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
