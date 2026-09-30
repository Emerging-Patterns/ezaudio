{
  description = "ezaudio: audio for Bend 2";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # bendlang/bend's flake at the commit that packages 2.0.34 (the v2.0.34 tag
  # still packages 2.0.33)
  inputs.bend = {
    url = "github:bendlang/bend/777ee0b55c485afdd7e68bd917b3d23a88d77371";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # ez and its bolt stay on the bend ez's own flake.lock records until ez
  # releases on 2.0.34, so ez's inputs.bend is pinned, not followed. The
  # package's own builds and its proofs (checks.proofs) run on 2.0.34.
  inputs.ez = {
    url = "github:Emerging-Patterns/ez";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.bend.url = "github:bendlang/bend/af569d4826913b2ce3557e9829ccad31fcf86f94";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      version = "0.3.0"; # x-release-please-version
      ez = inputs.ez.lib.${system};
      ezBin = inputs.ez.packages.${system}.default;
      bend = inputs.bend.packages.${system}.default;
      bolt = ez.toolPackage { name = "bolt"; src = self; wrapFlags = [ "--gpu" "off" ]; };
      bend-cc = ez.bend-cc;

      bench = import ./bench {
        inherit pkgs bend bend-cc self;
        lib = pkgs.lib;
      };
    in {
      packages.${system} = {
        inherit bend bend-cc;
        ez = ezBin;
        inherit bolt;
      } // bench.packages;

      apps.${system} = bench.apps;

      checks.${system} = {
        # every PROOF.bend on this flake's bend: its first line must be
        # ALL PROOFS CHECK. ez.mkProofs comes back when ez runs on 2.0.34.
        proofs = pkgs.runCommand "ezaudio-proofs" {
          nativeBuildInputs = [ bend ];
          BEND_LIB = ez.bendLib ./ez.lock.toml;
        } ''
          export HOME=$TMPDIR
          cp -r ${self} src && chmod -R u+w src && cd src
          for p in $(find . -name PROOF.bend -not -path './.ez/*' | sort); do
            first=$(cd "$(dirname "$p")" && bend "$(basename "$p")" | head -n 1)
            echo "$p: $first"
            [ "$first" = "ALL PROOFS CHECK" ] || exit 1
          done
          touch $out
        '';
        lint = ez.mkLint { src = self; };
      } // bench.checks;

      devShells.${system}.default = ez.mkShell {
        src = self;
        packages = [
          bend
          bend-cc
          ezBin
          pkgs.python3
          pkgs.ffmpeg-headless
          bench.packages.ezaudio-bench-drv
          bench.packages.ezaudio-wave-check
          bench.packages.ezaudio-wave-bench
        ];
      };
    };
}
