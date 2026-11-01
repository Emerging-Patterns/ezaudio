# `trim(clip, start, n)` keeps the `n` whole frames from frame `start`,
# including the whole clip, and is none when the span runs past the end
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1

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
