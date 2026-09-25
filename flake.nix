{
  description = "ezaudio: audio for Bend 2";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.bend = {
    url = "github:bendlang/bend";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.ez = {
    url = "github:Emerging-Patterns/ez";
    inputs.nixpkgs.follows = "nixpkgs";
    # not `inputs.bend.follows = "bend"`: ez 1.2.0 does not build on bend
    # 2.0.28, so ez (and `ez prove`, and bolt through mkLint) keep the bend
    # ez 1.2.0 locks, 2.0.27
    inputs.bend.url = "github:bendlang/bend/d37909174ebd664338ae3194799a9e0899dedd51";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      version = "0.2.9"; # x-release-please-version
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
        proofs = ez.mkProofs { ez = ezBin; src = self; };
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
