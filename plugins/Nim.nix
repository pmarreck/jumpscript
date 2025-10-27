{pkgs ? import <nixpkgs> {}}:

{
  lang = "Nim";
  fileExt = "nim";
  preferStatic = true;
  defaultBuildInputs = with pkgs; [
    nim
    pcre
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "nim"
    "compile"
    "--opt:speed"
    "--passL:-static"
    "--out:binaryPath"
    "sourcePath"
  ];
  # No runner needed for native executables
}
