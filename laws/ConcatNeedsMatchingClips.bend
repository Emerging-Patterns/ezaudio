# `concat` appends the frames of two clips that share rate, channels and
# format, and is none when any of the three differ
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1

# LAW: concat appends frames when the clips agree
law concat_match:
  {Au.concat(D1.fix.mono(), Au.clip(8000, 1, Au.s16(), [2]))
    == Some{Au.clip(8000, 1, Au.s16(), [0, 1, 2])} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the rates differ
law concat_rate:
  {Au.concat(D1.fix.mono(), Au.clip(16000, 1, Au.s16(), [2])) == None{} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the channel counts differ
law concat_channels:
  {Au.concat(D1.fix.mono(), Au.clip(8000, 2, Au.s16(), [2, 3])) == None{} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the formats differ
law concat_format:
  {Au.concat(D1.fix.mono(), Au.clip(8000, 1, Au.f32(), [0])) == None{} : Maybe<&2, Au.Clip>}
