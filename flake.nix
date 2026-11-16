{
  description = "ezaudio: audio for Bend 2";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # bendlang/bend's flake at the commit that packages 2.0.40 (the v2.0.40 tag
  # may still package 2.0.39)
  inputs.bend = {
    url = "github:bendlang/bend/222de9901d4e3551c2b347da02e02a10098a28b2";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # ez's bend follows this flake's bend:
  # ez, `ez prove` and bolt all build on 2.0.40.
  inputs.ez = {
    url = "github:Emerging-Patterns/ez";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.bend.follows = "bend";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forEach = nixpkgs.lib.genAttrs systems;
      outputsFor = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          version = "0.6.0"; # x-release-please-version
          ez = inputs.ez.lib.${system};
          ezBin = inputs.ez.packages.${system}.default;
          bend = inputs.bend.packages.${system}.default;
          bolt = ez.toolPackage { name = "bolt"; src = self; inherit bend; wrapFlags = ez.rtsFlags bend [ "--gpu" "off" ]; };
          bend-cc = ez.bend-cc;

          bench = import ./bench {
            inherit pkgs bend bend-cc self;
            lib = pkgs.lib;
          };

          # tests/fixtures.bend: single-input checks that are not laws; its run
          # must print exactly the lines its `#|` trailer states
          fixtures = pkgs.runCommand "ezaudio-fixtures" { nativeBuildInputs = [ bend ]; } ''
            cp -r ${self}/main.bend ${self}/src ${self}/laws ${self}/fixtures ${self}/tests .
            export BEND_NO_TELEMETRY=1 HOME=$TMPDIR
            bend tests/fixtures.bend > got.txt
            grep '^#|' tests/fixtures.bend | sed 's/^#|//' > want.txt
            diff want.txt got.txt
            touch $out
          '';
        in {
          packages = {
            inherit bend bend-cc;
            ez = ezBin;
            inherit bolt;
          } // bench.packages;

          apps = bench.apps;

          checks = {
            proofs = ez.mkProofs { ez = ezBin; src = self; };
            lint = ez.mkLint { src = self; };
            inherit fixtures;
          } // bench.checks;

          devShells.default = ez.mkShell {
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
      perSystem = forEach outputsFor;
      each = name: forEach (system: perSystem.${system}.${name});
    in {
      packages = each "packages";
      checks = each "checks";
      apps = each "apps";
      devShells = each "devShells";
    };
}
