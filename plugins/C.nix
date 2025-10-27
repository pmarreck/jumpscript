{pkgs ? import <nixpkgs> {}}:

{
  lang = "C";
  fileExt = "c";
  preferStatic = true;
  defaultBuildInputs = with pkgs; [
    gcc
    glibc
    glibc.static
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "gcc"
    "-O3"
    "-Wall"
    "-Wextra"
    "sourcePath"
    "-o"
    "binaryPath"
  ];
  # No runner needed for native executables
}
