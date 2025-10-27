{pkgs ? import <nixpkgs> {}}:

{
  lang = "C++";
  fileExt = "cpp";
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
    "g++"
    "-std=c++20"
    "-O3"
    "-Wall"
    "-Wextra"
    "sourcePath"
    "-o"
    "binaryPath"
  ];
  # No runner needed for native executables
}
