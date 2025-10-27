# JumpScript - Nix-Backed Compiled Script Runner

JumpScript turns compiled languages into fast-launching scripts. It builds on first run (or when modified), caches the binary, and skips straight to execution thereafter. It uses Nix for reproducible builds and dependency management.

## Installation

1. Make sure you have [Nix](https://nixos.org/download.html) installed.
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/jumpscript.git
   ```
3. Add the `jumpscript` script to your PATH:
   ```bash
   cd jumpscript
   chmod +x jumpscript
   ln -s $(pwd)/jumpscript ~/.local/bin/jumpscript  # or another directory in your PATH
   ```

## Usage

Create a script with a shebang line specifying the language:

```c
#!/usr/bin/env jumpscript -S C
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

On first run, JumpScript will:
1. Compile the script using the appropriate plugin
2. Cache the binary in `~/.cache/jumpscript/`
3. Execute the binary

On subsequent runs, JumpScript will:
1. Check if the script has been modified
2. If not, execute the cached binary directly

## Nix Header

The `# nix:` header block is parsed as a Nix attrset and can contain:

- `buildInputs`: List of dependencies to include in the build environment
- `nativeBuildInputs`: List of build-time dependencies
- `pkgsBranch`: Which nixpkgs branch to use (default: "nixpkgs-unstable")
- `preferStatic`: Whether to prefer static linking (default: true)

## Supported Languages

`jumpscript` currently supports the following languages:

- C
- C++
- D
- Crystal
- Rust
- Idris 2
- Lean 4
- Zig
- Nim
- Elixir (with daemon support for fast script launching)

## Adding New Languages

To add support for a new language, create a plugin file in the `plugins/` directory:

```nix
{pkgs ? import <nixpkgs> {}}:

{
  lang = "YourLanguage";
  fileExt = "ext";
  preferStatic = true;
  defaultBuildInputs = with pkgs; [
    # List required packages here
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "compiler"
    "sourcePath"
    "-o"
    "binaryPath"
  ];
  # Optional: runner = "#!/usr/bin/env interpreter";
}
```

## License

MIT
