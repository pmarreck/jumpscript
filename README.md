# JumpScript - Nix-Backed Compiled Script Runner

JumpScript turns compiled languages into fast-launching scripts. It builds on first run (or when modified), caches the binary, and skips straight to execution thereafter. Nix provides reproducible toolchains for each language.

## Installation

1. Make sure you have [Nix](https://nixos.org/download.html) installed.
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/jumpscript.git
   ```
3. Add the `jumpscript` script to your PATH. If you use [direnv](https://direnv.net/), allow the bundled `.envrc` to prepend the repository path automatically:
   ```bash
   cd jumpscript
   direnv allow   # optional; keeps PATH scoped to this repo
   ```
   Otherwise, symlink the script anywhere on your PATH:
   ```bash
   chmod +x jumpscript
   ln -s "$(pwd)/jumpscript" ~/.local/bin/jumpscript
   ```

## Usage

Create a script with a shebang line specifying the language:

```c
#!/usr/bin/env -S jumpscript C
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

On the first run JumpScript compiles the script, stores the binary in the cache, and executes it. Subsequent runs skip straight to execution until the script or any tracked dependency changes.

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
jumpscript run <Language[-Version]> <script> [args...]
jumpscript --help
jumpscript --about
```

- `--about` prints a one-line description of JumpScript’s purpose.
- `--help` shows the currently effective cache root, plugin search paths, and the environment variables that override them (`JUMPSCRIPT_CACHE`, `JUMPSCRIPT_PLUGINS_DIR`, `JUMPSCRIPT_USER_PLUGINS`, plus the relevant XDG defaults).

All scripts should use the shebang form `#!/usr/bin/env -S jumpscript <Language>`. The optional `-Version` suffix selects a non-default plugin if one is present.

## Direnv Support

The repository includes a `.envrc` that prepends the project directory to `PATH` so the local `jumpscript` executable is discovered automatically. If you use direnv, run `direnv allow` once per clone; otherwise the file has no effect.

## Adding New Languages

Each language is packaged as a plugin under `plugins/<Language>/<version>/plugin`. Plugins emit metadata describing their build command, dependencies, and runtime requirements. See existing plugins for concrete examples.

## License

MIT
