# wave/ffmpeg vs ezaudio bench: native Bend driver + Nix-embedded compare script.
# No checked-in *.py files — compare text lives in compare.nix and is written
# with pkgs.writeText at eval time.
#
# Fairness: WAV speed is in-memory vs in-memory (BytesIO / struct). MP3 speed is
# ezaudio absolute ms/op on non-silent real-world clips; ffmpeg is correctness
# only (never a timed reference). Timing is not part of the flake check.
{
  pkgs,
  lib,
  bend,
  bend-cc,
  # Flake `self` (repo root). Used only to copy ezaudio/ + bench/main.bend.
  self,
}:

let
  llvm = pkgs.llvmPackages_19;

  # Sandbox-safe CC: nixpkgs clang (native ELF). Local `nix develop` still
  # exports CC=bend-cc for host-ld native builds; both are non-JS.
  drv = pkgs.stdenv.mkDerivation {
    pname = "ezaudio-bench-drv";
    version = "0.1.0";
    dontUnpack = true;
    nativeBuildInputs = [ bend llvm.clang ];
    buildPhase = ''
      cp -r ${self}/ezaudio ./ezaudio
      mkdir -p bench
      cp ${./main.bend} bench/main.bend
      cd bench
      export CC=${llvm.clang}/bin/clang
      export BEND_NO_TELEMETRY=1
      bend main.bend -o ezaudio-bench
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp ezaudio-bench $out/bin/ezaudio-bench
    '';
    meta = {
      description = "Native ELF driver for ezaudio wave/ffmpeg comparison benches";
      mainProgram = "ezaudio-bench";
    };
  };

  compareText = import ./compare.nix { drvBin = "ezaudio-bench"; };
  comparePy = pkgs.writeText "ezaudio-wave-compare.py" compareText;

  # stdlib wave only needs python3; ffmpeg provides MPEG-1 Layer III reference.
  py = pkgs.python3;
  ffmpeg = pkgs.ffmpeg-headless;

  makeRunner = mode: pkgs.writeShellApplication {
    name = if mode == "correctness" then "ezaudio-wave-check" else "ezaudio-wave-bench";
    runtimeInputs = [ drv py ffmpeg ];
    text = ''
      set -euo pipefail
      export EZAUDIO_BENCH_DRV=${drv}/bin/ezaudio-bench
      export EZAUDIO_BENCH_WORK="''${EZAUDIO_BENCH_WORK:-$(mktemp -d)}"
      export EZAUDIO_BENCH_MODE=${mode}
      export EZAUDIO_BENCH_FFMPEG=${ffmpeg}/bin/ffmpeg
      mkdir -p "$EZAUDIO_BENCH_WORK"
      exec ${py}/bin/python ${comparePy} "$@"
    '';
  };

  checkBin = makeRunner "correctness";
  benchBin = makeRunner "all";

  # Flake check: correctness must pass. Timing is not part of this derivation.
  waveCheck = pkgs.runCommand "ezaudio-wave-compare" {
    nativeBuildInputs = [ checkBin ];
  } ''
    export EZAUDIO_BENCH_WORK="$PWD/work"
    mkdir -p "$EZAUDIO_BENCH_WORK"
    ezaudio-wave-check | tee $out
  '';
in
{
  inherit drv waveCheck;
  packages = {
    ezaudio-bench-drv = drv;
    ezaudio-wave-check = checkBin;
    ezaudio-wave-bench = benchBin;
  };
  apps = {
    wave-check = {
      type = "app";
      program = "${checkBin}/bin/ezaudio-wave-check";
    };
    wave-bench = {
      type = "app";
      program = "${benchBin}/bin/ezaudio-wave-bench";
    };
  };
  checks = {
    wave = waveCheck;
  };
}
