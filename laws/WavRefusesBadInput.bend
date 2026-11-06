# a byte list that is not RIFF decodes as none. A clip whose samples are not
# whole frames does not encode, for every clip: a writer that laid them out
# would leave readers such as Python's wave and ffmpeg to drop the last
# samples. Neither does a zero sample rate, an s16 sample that does not fit
# 16 bits, or a rate whose byte rate does not fit a U32. An empty clip does
# encode, as a file of no frames.
import Base
import ../main.bend as Au

# LAW: a byte list that is not RIFF decodes as none
law wav_bad:
  {Au.decode_wav([0]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a clip whose sample count is not a multiple of its channels does not encode
law wav_part_frame:
  for +hz: U32
  for +nch: U32
  for fmt: Au.Format
  for +pcm: List<&2, U32>
  for h_part: {Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n) == False{} : Bool}
  {Au.encode_wav(Au.clip(hz, nch, fmt, pcm)) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a zero sample rate does not encode
law wav_rate0:
  {Au.encode_wav(Au.clip(0, 1, Au.s16(), [1])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: an s16 sample of 2^16 or more does not encode
law wav_wide_s16:
  {Au.encode_wav(Au.clip(8000, 1, Au.s16(), [65536])) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a rate whose byte rate wraps a U32 does not encode
law wav_rate_wraps:
  {Au.encode_wav(Au.clip(1073741825, 2, Au.s16(), [0, 0])) == None{} : Maybe<&2, List<&2, U32>>}
