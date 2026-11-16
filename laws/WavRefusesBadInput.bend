# a byte list that does not start with RIFF decodes as none, for every
# byte list. A clip whose samples are not whole frames does not encode, for
# every clip: a writer that laid them out would leave readers such as
# Python's wave and ffmpeg to drop the last samples. Neither does a zero
# sample rate, an s16 sample that does not fit 16 bits, or a byte rate, data
# size or RIFF size that does not fit a U32, for every clip.
import Base
import ../main.bend as Au
import ../src/wav.bend as Wav

# LAW: bytes whose first four are not RIFF (52 49 46 46) decode as none, for every byte after them
law wav_bad:
  for +a: U32
  for +b: U32
  for +c: U32
  for +d: U32
  for +rest: List<&2, U32>
  for h_riff: {U32.is_eq(Wav.be.u32(a, b, c, d), 1380533830) == False{} : Bool}
  {Au.decode_wav(a <> b <> c <> d <> rest) == None{} : Maybe<&2, Au.Clip>}

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
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  {Au.encode_wav(Au.clip(0, nch, fmt, pcm)) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: an s16 sample of 2^16 or more does not encode
law wav_wide_s16:
  for +hz: U32
  for +nch: U32
  for +pcm: List<&2, U32>
  for h_wide: {Wav.enc.low16(pcm, True{}) == False{} : Bool}
  {Au.encode_wav(Au.clip(hz, nch, Au.s16(), pcm)) == None{} : Maybe<&2, List<&2, U32>>}

# LAW: a rate whose byte rate, or a clip whose data or RIFF size, does not fit a U32 does not encode
law wav_too_big:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  for h_size: {Wav.enc.sized(hz, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm))) == False{} : Bool}
  {Au.encode_wav(Au.clip(hz, nch, fmt, pcm)) == None{} : Maybe<&2, List<&2, U32>>}
