{
  description = "Jumpscript Roc plugin runtimes (LuaJIT for .lua.roc, wasmtime for .wasm.roc)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      luajit = pkgs.luajit;
      wasmtime = pkgs.wasmtime;
    });
  };
}
