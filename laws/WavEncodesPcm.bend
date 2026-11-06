# IBM/Microsoft RIFF WAVE form: a mono signed-16 clip at 8000 Hz encodes
# as PCM (format tag 1), one channel, 16 bits, little-endian samples, in a
# 16-byte fmt chunk. A binary32 clip encodes as format tag 3 in an 18-byte fmt
# chunk whose cbSize is 0, followed by a fact chunk holding the frame count, as
# the 1994 RIFF update asks of every format that is not PCM.
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1
import ./defs/WavFiles.bend as D2

# LAW: IBM/Microsoft RIFF — s16 mono encodes as PCM, 8000 Hz, 16-bit little-endian
law wav_s16_bytes:
  {Au.encode_wav(D1.fix.mono()) == Some{D2.wav.canonical()} : Maybe<&2, List<&2, U32>>}

# LAW: IBM/Microsoft RIFF — binary32 encodes as format tag 3 with cbSize and a fact chunk
law wav_f32_bytes:
  {Au.encode_wav(Au.clip(8000, 1, Au.f32(), [1065353216])) == Some{D2.wav.float()} : Maybe<&2, List<&2, U32>>}
