# Toolchain pins: draft lookup rules

Status: draft for BDFN review (walking brief V3, 2026-10-06). Nothing here is implemented yet.

BDFN chose repository-level configuration with optional per-script overrides, and added: each plugin has its own `flake.nix` and `flake.lock`, the CLI updates them, and a script can override the pin with a nix commit hash in a comment.

## What exists today

Every plugin directory (`plugins/<Lang>/default/`) already has its own `flake.nix` and `flake.lock`. Eleven follow `nixos-26.05`, one follows `nixos-unstable`, and Roc also locks the `roc_luajit` flake. Each plugin's build and run commands enter that flake (`nix develop <plugin_dir>#build`, `nix build <plugin_dir>#roc`), so the lock file already determines every toolchain version. A user plugin directory (`JUMPSCRIPT_USER_PLUGINS`) already takes precedence over a bundled plugin of the same name.

## Proposed rules

The effective pin for one run is decided by the first layer that names one:

1. **Script directive.** A comment line within the script's first 20 lines contains `jumpscript: nixpkgs=<rev>`, where `<rev>` is a full 40-hex-digit commit of NixOS/nixpkgs. The marker is matched as text inside any comment syntax (`#`, `//`, `--`, `;`), so every language uses its own comment form. The runner applies it as `--override-input nixpkgs github:NixOS/nixpkgs/<rev>` to the plugin flake.
2. **Plugin lock.** Otherwise the plugin's `flake.lock` decides, taking the user plugin directory's copy before the bundled one, as plugin lookup already does.

Details:

- Only full commit hashes are accepted. Branch names and short hashes move or collide, so they could not give a reproducible build or a warm offline run.
- A malformed directive (wrong length, non-hex) or two directives naming different revisions is an error, never ignored.
- The effective revision is part of the build and meta cache keys, so one script under two pins keeps two artifacts and never reuses the wrong one.
- The first run under a new pin needs the network to fetch that revision. Warm runs stay offline, as INTENT.md requires.
- Language versions are reached by choosing a nixpkgs revision that carries them. No version-to-revision lookup is planned.

## CLI

- `jumpscript update [PLUGIN...]` runs `nix flake update` in each named plugin directory (all plugins when none are named) and prints the old and new nixpkgs revision for each.
- When the plugin directory is read-only, for example a bundled plugin in the Nix store, `update` fails and names the path. It does not silently copy the plugin.

## Implementation sketch

- The Zig core parses the directive from the script header (pure, unit-tested over valid and invalid sets) and returns the override, or an error.
- The runner passes the override to plugins in one environment variable. `plugins/_lib/plugin_lib.bash` gets a helper that expands it into `--override-input` arguments, and every plugin's `nix develop` or `nix build` call uses that helper.
- Tests: a script pinned to an older nixpkgs reports that revision's compiler version; a malformed directive fails with a clear error; two pins of one script keep separate cache entries.

## Questions for BDFN

1. Should a repository of scripts also be able to carry its own pin, for example a `.jumpscript` file at the git root that every script beneath it inherits? This draft leaves it out, because the plugin lock already gives every script a shared pin.
2. Should the directive cover flake inputs other than nixpkgs, such as `jumpscript: roc_luajit=<rev>` for the Roc compiler? Today it covers only nixpkgs.
3. For a read-only bundled plugin, should `update` offer to copy the plugin into the user plugin directory first?
