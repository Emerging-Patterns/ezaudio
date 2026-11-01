# `encode_mp3` is none for an empty sample list and for a rate other
# than 32000, 44100 or 48000
import Base
import ../main.bend as Au

# LAW: an empty sample list does not encode
law mp3_empty:
  {Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a rate outside 32000, 44100, and 48000 does not encode
law mp3_rate:
  {Au.encode_mp3(Au.clip(22050, 1, Au.s16(), [0])) == None{} : Maybe<&2, List<&2, U32>>}
