# `fill(rate, channels, format, sample, n)` is the clip of `n` frames
# whose every sample, on every channel, is `sample`: `n * channels` samples
# for every `n` and `channels`
import Base
import ../main.bend as Au

# LAW: fill repeats one sample across the frames
law fill_mono:
  {Au.fill(8000, 1, Au.s16(), 7, 3) == Au.clip(8000, 1, Au.s16(), [7, 7, 7]) : Au.Clip}

# LAW: fill interleaves the sample once per channel
law fill_stereo:
  {Au.fill(8000, 2, Au.f32(), 4, 2) == Au.clip(8000, 2, Au.f32(), [4, 4, 4, 4]) : Au.Clip}

# LAW: fill makes nframes * channels samples, for every count, counted as
# natural numbers, so a product past 2^32 does not wrap to a short clip
law fill_count:
  for +rate: U32
  for +nch: U32
  for fmt: Au.Format
  for +sample: U32
  for +nframes: U32
  {List.length(&2, U32, Au.frames(Au.fill(rate, nch, fmt, sample, nframes)))
    == Nat.mul(U32.to_nat(nframes), U32.to_nat(nch)) : Nat}
