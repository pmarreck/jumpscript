# jumpscript intent

## Purpose

Write one-off scripts in any supported language and run them directly, without first installing that language's compiler or runtime. In BDFN's (Benevolent Dictator For Now) words, the point was partly to "write one-off scripts in any language without worrying about whether I already had the compilers etc. installed", with jumpscript expected "to lean on Nix to procure anything necessary on-the-fly".

## Users

People who write small scripts in compiled or transpiled languages on a machine with Nix, starting with BDFN.

## Desired outcomes

- A script with a `#!/usr/bin/env -S jumpscript <Language>` shebang runs on a machine that has Nix and jumpscript but none of the language's tools; the plugin's flake procures the compiler and runtime on first use.
- Editing a script (or a file it depends on) rebuilds it on the next run; an unchanged script runs from its cached build at close to the program's own speed.
- Where the host already has the tools, `--no-build-deps`, `--no-runtime-deps` and `--no-deps` use them instead of Nix.
- Scripts can be extensionless executables; the shebang names the language and, where a language has several backends, the backend.
- A script can pin its own toolchain version for reproducibility; without a pin, the plugin's flake lock decides (BDFN, 2026-10-04).
- After a script's first run has fetched its toolchain, later runs and rebuilds work without network access (BDFN, 2026-10-04).

## Scope and non-goals

- In scope: languages that need a build step (compiled or transpiled), each as a plugin under `plugins/<Language>/<variant>/` with its own flake.
- Platforms: Linux and macOS with Nix installed. Native Windows is out of scope (the workflow is shebang-based).
- Nix itself is a prerequisite jumpscript does not install.

## Constraints

- A plugin must not depend on host tools before Nix supplies them, apart from what the shebang workflow already needs (`env`, `bash`, `nix`) (confirmed by BDFN, 2026-10-04).
- The cache is private to the user (directories at mode 700) and safe under concurrent runs of the same script.

## How success is verified

- `./test` is the complete entry point. Integration suites run each language's fixtures through the runner, several with `PATH` reduced to the Nix binary's directory and a few basic ones, so a plugin that relies on host tools fails.
- The suites are run on Linux (x86_64) and macOS (aarch64).
- Offline behavior is verified by running warm scripts with networking disabled (planned; see PLAN.md).

## Open questions

- How a script declares its toolchain pin (syntax and granularity: a nixpkgs revision, a language version, or both).

## See also

- `PLAN.md` for current work; `docs/plan_context/project_overview.md` for architecture, constraints and roadmap history.
