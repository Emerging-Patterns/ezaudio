# `rate`, `channels`, `format` and `frames` read back the rate, channel
# count, sample format and interleaved frames a clip was built with; `s16`
# is signed 16-bit PCM and `f32` is IEEE 754 binary32, stored as its bits
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1

# LAW: a clip keeps the rate it was built with
law rate_reads:
  {Au.rate(D1.fix.mono()) == 8000 : U32}

# LAW: a clip keeps the channel count it was built with
law channels_read:
  {Au.channels(D1.fix.mono()) == 1 : U32}

# LAW: s16 is the signed 16-bit format
law format_s16:
  {Au.format(Au.clip(8000, 1, Au.s16(), [])) == Au.s16() : Au.Format}

# LAW: f32 is the binary32 format
law format_f32:
  {Au.format(Au.clip(8000, 1, Au.f32(), [])) == Au.f32() : Au.Format}

# LAW: frames reads the samples a clip was built with
law frames_read:
  {Au.frames(D1.fix.mono()) == [0, 1] : List<&2, U32>}
