# a clip is whole MPEG-1 Layer III frames: one or two channels, and a sample
# count that is a multiple of 1152 samples per channel, counted as natural numbers
import Base
import ../../main.bend as Au

# is the clip whole Layer III frames
def whole(c: Au.Clip) -> Bool:
  match c:
    case Au.Clip{_hz, +nch, _fmt, +pcm}:
      Bool.and(Bool.or(U32.is_eq(nch, 1), U32.is_eq(nch, 2)),
        Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat((1152 * nch : U32))), 0n))
