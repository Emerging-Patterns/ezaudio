# `trim(clip, start, n)` keeps the `n` whole frames from frame `start`, and
# is none when the span runs past the end. For every clip and span, counted
# as natural numbers so `start + n` and the sample offsets do not wrap a
# U32: a span whose `(start + n) * channels` samples are more than the clip
# holds is none, and one that fits keeps exactly `n * channels` samples.
import Base
import ../main.bend as Au

# the sample count of a trimmed clip, when there is one
def trim.len(mm: Maybe<&2, Au.Clip>) -> Maybe<&2, Nat>:
  match mm:
    case None{}:
      None{}
    case Some{clip}:
      Some{List.length(&2, U32, Au.frames(clip))}

# LAW: a span whose samples are more than the clip holds is none, whatever
# start and n are, including ones whose U32 sum wraps
law trim_past_end:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for +pcm: List<&2, U32>
  for +start: U32
  for +nframes: U32
  for h_past: {Nat.is_le(Nat.mul(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), U32.to_nat(nch)),
    List.length(&2, U32, pcm)) == False{} : Bool}
  {Au.trim(Au.clip(hz, nch, fmt, pcm), start, nframes) == None{} : Maybe<&2, Au.Clip>}

# LAW: a span that fits keeps exactly n * channels samples
law trim_fits:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for +pcm: List<&2, U32>
  for +start: U32
  for +nframes: U32
  for +h_fit: {Nat.is_le(Nat.mul(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), U32.to_nat(nch)),
    List.length(&2, U32, pcm)) == True{} : Bool}
  for h_nch: {Nat.is_ne(U32.to_nat(nch), 0n) == True{} : Bool}
  {trim.len(Au.trim(Au.clip(hz, nch, fmt, pcm), start, nframes))
    == Some{Nat.mul(U32.to_nat(nframes), U32.to_nat(nch))} : Maybe<&2, Nat>}
