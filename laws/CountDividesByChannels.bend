# `count` is the number of frames, for every clip: the samples divided by
# the channels, and 0 when the clip has no channels
import Base
import ../main.bend as Au

# LAW: the frame count is samples divided by channels
law count_frames:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for +pcm: List<&2, U32>
  for h_nch: {U32.is_eq(nch, 0) == False{} : Bool}
  {Au.count(Au.clip(hz, nch, fmt, pcm)) == U32.div(U32.from_nat(List.length(&2, U32, pcm)), nch) : U32}

# LAW: zero channels count as no frames
law count_zero_channels:
  for +hz: U32
  for fmt: Au.Format
  for +pcm: List<&2, U32>
  {Au.count(Au.clip(hz, 0, fmt, pcm)) == 0 : U32}
