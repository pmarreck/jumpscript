{
  description = "Jumpscript Crystal plugin toolchain";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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
            # Crystal 1.19.1 aborts at startup with an arithmetic overflow in
            # default_workers_count on machines with 128 or more CPUs (127
            # works); 1.18 does not. Return to the default once fixed upstream.
            crystal_1_18
            llvmPackages_latest.clang
            pkg-config
            coreutils
          ];
        };
      });
  };
}
