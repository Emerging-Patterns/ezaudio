# a clip is well formed: one or two channels, and whole frames, its sample
# count a multiple of its channels, counted as natural numbers
import Base
import ../../main.bend as Au

# is the clip well formed
def wf(c: Au.Clip) -> Bool:
  match c:
    case Au.Clip{_hz, +nch, _fmt, +pcm}:
      Bool.and(Bool.or(U32.is_eq(nch, 1), U32.is_eq(nch, 2)),
        Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n))
