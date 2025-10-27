{pkgs ? import <nixpkgs> {}}:

{
  lang = "D";
  fileExt = "d";
  preferStatic = true;
  defaultBuildInputs = with pkgs; [
    ldc
    glibc
    glibc.static
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "ldc2"
    "-O3"
    "-release"
    "-of=binaryPath"
    "sourcePath"
  ];
  # No runner needed for native executables
}
