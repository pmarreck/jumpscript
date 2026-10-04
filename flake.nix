{
  description = "jumpscript: cached edit-run harness for compiled languages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    # The runner plus the bundled plugins beside it ($out/bin, $out/plugins),
    # which is where the binary looks for them.
    runnerFor = pkgs: pkgs.stdenv.mkDerivation {
      pname = "jumpscript";
      version = "0.2.0";
      src = ./.;
      nativeBuildInputs = [ pkgs.zig_0_16 ];
      dontConfigure = true;
      buildPhase = ''
        runHook preBuild
        export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local
        zig build install -Doptimize=ReleaseFast --prefix $out
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        cp -r plugins $out/plugins
        runHook postInstall
      '';
    };
  in {
    packages = forAllSystems (pkgs: { default = runnerFor pkgs; });

    checks = forAllSystems (pkgs: {
      build = runnerFor pkgs;
      core-tests = pkgs.stdenv.mkDerivation {
        pname = "jumpscript-core-tests";
        version = "0.2.0";
        src = ./.;
        nativeBuildInputs = [ pkgs.zig_0_16 ];
        dontConfigure = true;
        buildPhase = ''
          export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-local
          zig build test -Doptimize=ReleaseFast
          zig build test -Doptimize=Debug
        '';
        installPhase = "mkdir -p $out && echo passed > $out/result";
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell { packages = [ pkgs.zig_0_16 ]; };
    });
  };
}
