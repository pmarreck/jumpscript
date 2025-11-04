# Next Steps

## Completed
- **Lean 4 Native Build** (2025-10-29)
	- Lake-based scaffold generates native binaries under `bin/<script>` and passes `tests/test_integration_lean.sh`.
- **User Plugin Search Path** (2025-10-29)
	- Runner honours `${JUMPSCRIPT_USER_PLUGINS}` (default `${XDG_DATA_HOME:-$HOME/.local/share}/jumpscript/plugins`) ahead of bundled plugins.
- **Shebang Roundtrip Coverage** (2025-11-04)
	- `tests/test_shebang_roundtrip.sh` executes fixtures through their shebang, exercising the primary CLI surface along with the new `--about/--help` commands.

## TODO
1. **Include/Multi-file Coverage**
	- C headers, Nim includes, Rust modules, Crystal requires, and Idris imports now tracked; replicate the pattern for remaining languages (e.g., Lean lake packages, Zig multi-file projects, WAT modules) to validate cache keying across the board.

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
