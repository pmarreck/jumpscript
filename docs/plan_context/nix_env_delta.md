# Nix environment delta caching

Use `nix print-dev-env` (or an equivalent diff) to record only the environment variables a plugin's devshell changes during the first build, store them with the cache entry, and replay them on later runs so a warm rebuild does not spawn `nix develop`. Invalidate cleanly when the recorded runner path disappears or the environment changes.

Related: the runner now caches plugin `meta` answers (see `zig_runner.md`), which already removes the plugin process from warm runs; this item is about builds.
