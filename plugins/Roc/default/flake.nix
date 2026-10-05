{
  description = "Jumpscript Roc plugin: Roc with the LuaJIT backend, its WASI basic-cli platform, and the LuaJIT and wasmtime runtimes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # Roc with the LuaJIT backend and the WASI copy of basic-cli, pinned by flake.lock.
  inputs.roc_luajit.url = "github:pmarreck/roc_luajit";

  outputs = { self, nixpkgs, roc_luajit }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      roc = roc_luajit.packages.${system} or { };
    in {
      luajit = pkgs.luajit;
      wasmtime = pkgs.wasmtime;
    } // nixpkgs.lib.optionalAttrs (roc ? roc) {
      roc = roc.roc;
      wasi-basic-cli = roc.wasi-basic-cli;
    });
  };
}
