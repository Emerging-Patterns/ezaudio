# `fill(rate, channels, format, sample, n)` is the clip of `n` frames
# whose every sample, on every channel, is `sample`
import Base
import ../main.bend as Au

# LAW: fill repeats one sample across the frames
law fill_mono:
  {Au.fill(8000, 1, Au.s16(), 7, 3) == Au.clip(8000, 1, Au.s16(), [7, 7, 7]) : Au.Clip}

# LAW: fill interleaves the sample once per channel
law fill_stereo:
  {Au.fill(8000, 2, Au.f32(), 4, 2) == Au.clip(8000, 2, Au.f32(), [4, 4, 4, 4]) : Au.Clip}
