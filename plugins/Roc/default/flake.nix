{
  description = "Jumpscript Roc plugin runtime (LuaJIT for .lua.roc scripts)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    packages = forAllSystems (system: {
      luajit = (import nixpkgs { inherit system; }).luajit;
    });
  };
}
