# IBM/Microsoft RIFF WAVE form: a mono signed-16 clip at 8000 Hz encodes
# as PCM (format tag 1), one channel, 16 bits, little-endian samples
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1

# the RIFF bytes of fix.mono: PCM, one channel, 16 bits
def fix.s16() -> List<&2, U32>:
  [
    82, 73, 70, 70, 40, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0, 1, 0,
    64, 31, 0, 0, 128, 62, 0, 0, 2, 0, 16, 0, 100, 97, 116, 97, 4, 0, 0, 0, 0, 0, 1, 0
  ]

# LAW: IBM/Microsoft RIFF — s16 mono encodes as PCM, 8000 Hz, 16-bit little-endian
law wav_s16_bytes:
  {Au.encode_wav(D1.fix.mono()) == Some{fix.s16()} : Maybe<&2, List<&2, U32>>}
