# a byte list that is not RIFF decodes as none; an empty frame list and
# a zero sample rate do not encode
import Base
import ../main.bend as Au

# LAW: a byte list that is not RIFF decodes as none
law wav_bad:
  {Au.decode_wav([0]) == None{} : Maybe<&2, Au.Clip>}

# LAW: an empty frame list does not encode
law wav_empty:
  {Au.encode_wav(Au.clip(8000, 1, Au.s16(), [])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a zero sample rate does not encode
law wav_rate0:
  {Au.encode_wav(Au.clip(0, 1, Au.s16(), [1])) == None{} : Maybe<&2, List<&2, U32>>}
