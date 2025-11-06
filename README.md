# JumpScript - Nix-Backed Compiled Script Runner

JumpScript turns compiled languages into fast-launching scripts. It builds on first run (or when modified), caches the binary, and skips straight to execution thereafter. Nix provides reproducible toolchains for each language.

## Installation

1. Make sure you have [Nix](https://nixos.org/download.html) installed.
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/jumpscript.git
   ```
3. Add the repository `bin/` directory to your PATH so the `jumpscript` launcher and bundled helper tools are discoverable. If you use [direnv](https://direnv.net/), allow the bundled `.envrc` to prepend the path automatically:
   ```bash
   cd jumpscript
   direnv allow   # optional; keeps PATH scoped to this repo
   ```
   Otherwise, update your shell configuration or export the path manually:
   ```bash
   export PATH="$(pwd)/bin:$PATH"
   ```
   To persist the change, add that line to your shell rc (`~/.bashrc`, `~/.zshrc`, …).

## Usage

Create a script with a shebang line specifying the language (and optional dependency hints):

```c
#!/usr/bin/env -S jumpscript --no-runtime-deps C
# nix: {
#   buildInputs = [ pkgs.zlib ];
#   pkgsBranch = "unstable";
#   preferStatic = true;
# }

#include <stdio.h>

int main(int argc, char *argv[]) {
    printf("Hello, world!\n");
    return 0;
}
```

Make it executable and run it:

```bash
chmod +x hello.c
./hello.c
```

### Configuration flags & environment variables

Flags:

- `--no-build-deps` – assume the compiler/toolchain (e.g. `clang`, `wat2wasm`) is already on `PATH` and skip the plugin’s Nix build shell.
- `--no-runtime-deps` – assume the runtime (e.g. `luajit`, `wazero`) is globally available and skip the Nix runtime shell.
- `--no-deps` – shorthand for both of the above.

When no flags are supplied, JumpScript boots the plugin’s flake-provided toolchains so scripts “just work.” Once you’ve installed the dependencies yourself, add the appropriate flags to get the faster, direct-exec path.

On the first run JumpScript compiles the script, stores the binary in the cache, and executes it. Subsequent runs skip straight to execution until the script or any tracked dependency changes.

Environment variables:

- `JUMPSCRIPT_CACHE` – override the cache root (defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/jumpscript-artifacts`).
- `JUMPSCRIPT_PLUGINS_DIR` – point JumpScript at alternate bundled plugins.
- `JUMPSCRIPT_USER_PLUGINS` – add a user plugin search root (defaults to `${XDG_DATA_HOME:-$HOME/.local/share}/jumpscript/plugins`).
- `JUMPSCRIPT_DEBUG=1` – surface verbose diagnostics from the launcher and plugins.

## Nix Header

The `# nix:` header block is parsed as a Nix attrset and can contain:

- `buildInputs`: List of dependencies to include in the build environment
- `nativeBuildInputs`: List of build-time dependencies
- `pkgsBranch`: Which nixpkgs branch to use (default: "nixpkgs-unstable")
- `preferStatic`: Whether to prefer static linking (default: true)

## Supported Languages

`jumpscript` currently ships plugins for:

- C
- C++
- D
- Crystal
- Rust
- Idris 2
- Lean 4
- Zig
- Nim
- Wat (WebAssembly Text)
- MoonScript

## CLI Reference

```
jumpscript run [--no-build-deps|--no-runtime-deps|--no-deps] <Language[-Version]> <script> [args...]
jumpscript --help
jumpscript --about
```

- `--about` prints a one-line description of JumpScript’s purpose.
- `--help` shows the currently effective cache root, plugin search paths, and the environment variables that override them (`JUMPSCRIPT_CACHE`, `JUMPSCRIPT_PLUGINS_DIR`, `JUMPSCRIPT_USER_PLUGINS`, plus the relevant XDG defaults). Use the `--no-*` flags to opt out of the plugin-provided build/runtime shells once you’ve installed the required tools yourself.

All scripts should use the shebang form `#!/usr/bin/env -S jumpscript <Language>`. The optional `-Version` suffix selects a non-default plugin if one is present.

## Direnv Support

The repository includes a `.envrc` that prepends the project directory to `PATH` so the local `jumpscript` executable is discovered automatically. If you use direnv, run `direnv allow` once per clone; otherwise the file has no effect.

## Examples

The `examples/` directory contains ready-to-run scripts that showcase JumpScript in different languages. For instance, `examples/weatherlean` is a Lean 4 version of a simple weather CLI. After setting `OPENWEATHERMAP_APPID`, make it executable and run it directly:

```bash
chmod +x examples/weatherlean
OPENWEATHERMAP_APPID=your-token examples/weatherlean
```

## Adding New Languages

Each language is packaged as a plugin under `plugins/<Language>/<version>/plugin`. Plugins emit metadata describing their build command, dependencies, and runtime requirements. See existing plugins for concrete examples.

## License

MIT
