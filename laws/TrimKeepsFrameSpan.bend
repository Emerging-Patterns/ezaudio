# `trim(clip, start, n)` keeps the `n` whole frames from frame `start`,
# including the whole clip, and is none when the span runs past the end. For
# every clip and span, counted as natural numbers so `start + n` and the
# sample offsets do not wrap a U32: a span whose `(start + n) * channels`
# samples are more than the clip holds is none, and one that fits keeps
# exactly `n * channels` samples.
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1

# the sample count of a trimmed clip, when there is one
def trim.len(mm: Maybe<&2, Au.Clip>) -> Maybe<&2, Nat>:
  match mm:
    case None{}:
      None{}
    case Some{clip}:
      Some{List.length(&2, U32, Au.frames(clip))}

# LAW: trim keeps the frame span inside the clip
law trim_span:
  {Au.trim(Au.clip(8000, 1, Au.s16(), [0, 1, 2, 3]), 1, 2)
    == Some{Au.clip(8000, 1, Au.s16(), [1, 2])} : Maybe<&2, Au.Clip>}

# LAW: trim of the whole clip is the clip
law trim_all:
  {Au.trim(D1.fix.mono(), 0, 2) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: trim past the end is none
law trim_past:
  {Au.trim(D1.fix.mono(), 1, 2) == None{} : Maybe<&2, Au.Clip>}

# LAW: trim of stereo drops whole frames
law trim_stereo:
  {Au.trim(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3]), 1, 1)
    == Some{Au.clip(8000, 2, Au.s16(), [2, 3])} : Maybe<&2, Au.Clip>}

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
