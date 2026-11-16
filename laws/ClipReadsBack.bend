# `rate`, `channels`, `format` and `frames` read back the rate, channel
# count, sample format and interleaved frames a clip was built with, for
# every clip; `s16` is signed 16-bit PCM and `f32` is IEEE 754 binary32,
# stored as its bits
import Base
import ../main.bend as Au

# LAW: a clip keeps the rate it was built with
law rate_reads:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for pcm: List<&2, U32>
  {Au.rate(Au.clip(hz, nch, fmt, pcm)) == hz : U32}

# LAW: a clip keeps the channel count it was built with
law channels_read:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for pcm: List<&2, U32>
  {Au.channels(Au.clip(hz, nch, fmt, pcm)) == nch : U32}

# LAW: a clip built as s16 is s16
law format_s16:
  for +hz: U32
  for +nch: U32
  for pcm: List<&2, U32>
  {Au.format(Au.clip(hz, nch, Au.s16(), pcm)) == Au.s16() : Au.Format}

# LAW: a clip built as f32 is f32
law format_f32:
  for +hz: U32
  for +nch: U32
  for pcm: List<&2, U32>
  {Au.format(Au.clip(hz, nch, Au.f32(), pcm)) == Au.f32() : Au.Format}

# LAW: frames reads the samples a clip was built with
law frames_read:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for +pcm: List<&2, U32>
  {Au.frames(Au.clip(hz, nch, fmt, pcm)) == pcm : List<&2, U32>}
