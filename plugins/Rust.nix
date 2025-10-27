{pkgs ? import <nixpkgs> {}}:

{
  lang = "Rust";
  fileExt = "rs";
  preferStatic = true;
  defaultBuildInputs = with pkgs; [
    rustc
    cargo
    rustfmt
    libiconv
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "rustc"
    "-C"
    "opt-level=3"
    "-C"
    "prefer-dynamic=no"
    "sourcePath"
    "-o"
    "binaryPath"
  ];
  # No runner needed for native executables
}
