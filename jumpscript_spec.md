
# `jumpscript` – Nix-Backed Compiled Script Runner

## Purpose
Turn compiled languages into fast-launching scripts. Build on first run (or when modified), cache binary, and skip straight to execution thereafter. Uses Nix for reproducible builds and dependency management.

---

## 1. Script Usage

### Example

```nix
#!/usr/bin/env jumpscript -S C
# nix: {
#   buildInputs = [ pkgs.zlib ];
#   pkgsBranch = "unstable";
#   preferStatic = true;
# }
```

- `jumpscript` reads the `# nix:` header block as a Nix attrset.
- Used to inject `buildInputs`, `nativeBuildInputs`, and pin `nixpkgs`.

---

## 2. Behavior

- On run:
  - If cached binary (`~/.cache/jumpscript/<name>-<arch>-<mtime>`) exists, `exec` it.
  - Else:
    - Strip shebang line
    - Save remainder to `temp.<ext>`
    - Read plugin for `<Lang>`
    - Parse Nix header or use plugin defaults
    - Launch `nix develop` with pinned pkgs
    - Run `compileCommand` (from plugin) inside shell
    - Optionally: prefix runner hashbang if plugin specifies a runner
    - Cache and mark binary executable

---

## 3. Plugin Format (Nix)

```nix
{
  lang = "yuescript";
  fileExt = "yue";
  preferStatic = false;
  defaultBuildInputs = [ pkgs.yuescript pkgs.luajit ];
  compileCommand = [
    "yue" sourcePath "--output" binaryPath
  ];
  runner = "#!/usr/bin/env luajit";
}
```

- `compileCommand` is run inside a Nix shell.
- `runner` can be:
  - A path to an interpreter
  - A hashbang to prepend (`#!/usr/bin/env <...>`)
  - Omitted for native executables

---

## 4. Default Behavior

- Always compile in release mode.
- Always prefer static linking (unless plugin opts out).
- No runtime dependency checking.
- stdin and args passed through transparently.

---

## 5. Supported Platforms

- Linux (x86_64)
- macOS (arm64)

Platform is detected with `uname -m` and used in cached binary naming.

---

## 6. Initial Language Targets

- C, C++, Rust, Zig, D, Nim, Crystal, Idris, Julia
- Scheme, Racket, Go
- Scripting-to-bytecode like YueScript, handled via runner

---

## 7. Optional Future Features

- `--force-rebuild` flag
- Debug builds via `// nix: debug = true`
- Plugin chaining/composition
- LSP integration
