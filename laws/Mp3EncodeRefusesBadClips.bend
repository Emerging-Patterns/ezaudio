# `encode_mp3` encodes exactly the clips it can: for every clip, there is
# an encoding when the rate is 32000, 44100 or 48000, there are one or two
# channels, and there is a sample, and none otherwise
import Base
import ../main.bend as Au
import ./defs/Mp3Stream.bend as D1

# LAW: a clip encodes exactly when its rate, channels and samples fit
law mp3_encodes_iff:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  {D1.is.some(Au.encode_mp3(Au.clip(hz, nch, fmt, pcm))) == D1.mp3.ok(hz, nch, pcm) : Bool}

# LAW: an empty sample list does not encode
law mp3_empty:
  {Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a rate outside 32000, 44100, and 48000 does not encode
law mp3_rate:
  {Au.encode_mp3(Au.clip(22050, 1, Au.s16(), [0])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: three channels do not encode
law mp3_three:
  {Au.encode_mp3(Au.clip(44100, 3, Au.s16(), [0, 0, 0])) == None{} : Maybe<&2, List<&2, U32>>}
