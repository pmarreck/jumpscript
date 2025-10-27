{
  description = "Jumpscript Nim plugin toolchain";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    devShells = forAllSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        build = pkgs.mkShell {
          packages = with pkgs; [
            nim
            coreutils
          ];
        };
      });
  };
}
