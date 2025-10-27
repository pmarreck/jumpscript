{pkgs ? import <nixpkgs> {}}:

{
  lang = "Idris";
  fileExt = "idr";
  preferStatic = false; # Idris doesn't fully support static linking
  defaultBuildInputs = with pkgs; [
    idris2
    gmp
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "idris2"
    "--output-dir"
    "$TMPDIR"
    "--exec"
    "main"
    "sourcePath"
    "&&"
    "cp"
    "$TMPDIR/exec/main"
    "binaryPath"
  ];
  # No runner needed as Idris2 produces executables
}
