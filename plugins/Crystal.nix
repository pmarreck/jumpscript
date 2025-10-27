{pkgs ? import <nixpkgs> {}}:

{
  lang = "Crystal";
  fileExt = "cr";
  preferStatic = false; # Crystal doesn't fully support static linking
  defaultBuildInputs = with pkgs; [
    crystal
    libevent
    pcre
    openssl
  ];
  defaultNativeBuildInputs = with pkgs; [
    pkg-config
  ];
  compileCommand = [
    "crystal"
    "build"
    "--release"
    "--no-debug"
    "sourcePath"
    "-o"
    "binaryPath"
  ];
  # No runner needed for native executables
}
