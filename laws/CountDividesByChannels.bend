# `count` is the number of frames: the samples divided by the channels,
# and 0 when the clip has no channels
import Base
import ../main.bend as Au

# LAW: the frame count is samples divided by channels
law count_frames:
  {Au.count(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3])) == 2 : U32}

# LAW: zero channels count as no frames
law count_zero_channels:
  {Au.count(Au.clip(8000, 0, Au.s16(), [1])) == 0 : U32}
