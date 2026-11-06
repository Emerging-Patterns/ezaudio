# proofs of laws/WavRefusesBadInput.bend
import Base
import ../main.bend as Au
import ../laws/WavRefusesBadInput.bend as Laws

def Laws.wav_bad():
  {==}

def Laws.wav_part_frame(hz, nch, fmt, pcm, h_part):
  Equal.cong(Bool, Maybe<&2, List<&2, U32>>, ok => Au.wav.bytes(ok, hz, nch, Au.kind.of(fmt), pcm),
    Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n), False{}, h_part)

def Laws.wav_rate0():
  {==}

def Laws.wav_wide_s16():
  {==}

def Laws.wav_rate_wraps():
  {==}
