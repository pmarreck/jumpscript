{pkgs ? import <nixpkgs> {}}:

{
  lang = "Zig";
  fileExt = "zig";
  preferStatic = true;
  defaultBuildInputs = with pkgs; [
    zig
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "zig"
    "build-exe"
    "-O"
    "ReleaseFast"
    "sourcePath"
    "-femit-bin=binaryPath"
  ];
  # No runner needed for native executables
}
