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
    inputs.bend.follows = "bend";
  };
  inputs.bolt = {
    url = "github:Emerging-Patterns/bolt";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.bend.follows = "bend";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      version = "0.1.0"; # x-release-please-version
      ez = inputs.ez.lib.${system};
      ezBin = inputs.ez.packages.${system}.default;
      bend = inputs.bend.packages.${system}.default;
      bolt = inputs.bolt.packages.${system}.default;
      bend-cc = ez.bend-cc;
    in {
      packages.${system} = { inherit bend bend-cc; ez = ezBin; inherit bolt; };
      checks.${system} = {
        proofs = ez.mkProofs { ez = ezBin; src = self; };
        lint = ez.mkLint { inherit bolt; src = self; };
      };
      devShells.${system}.default = ez.mkShell {
        packages = [ bend bend-cc ezBin bolt ];
      };
    };
}
