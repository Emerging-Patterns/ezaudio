# IBM/Microsoft RIFF WAVE form: decoding what `encode_wav` writes gives
# back the clip, for mono and stereo signed-16 and for mono and stereo IEEE
# 754 binary32 (format tag 3), including the bits of 1.0
import Base
import ../main.bend as Au
import ./defs/MonoClip.bend as D1
import ./defs/ByteLists.bend as D2

# LAW: IBM/Microsoft RIFF — decoding that encoding is the clip
law wav_s16_round:
  {Au.decode_wav(D2.bytes.of(Au.encode_wav(D1.fix.mono()))) == Some{D1.fix.mono()} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — stereo s16 round-trips
law wav_s16_stereo:
  {Au.decode_wav(D2.bytes.of(Au.encode_wav(Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3]))))
    == Some{Au.clip(8000, 2, Au.s16(), [0, 1, 2, 3])} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — binary32 mono round-trips, including 1.0
law wav_f32_mono:
  {Au.decode_wav(D2.bytes.of(Au.encode_wav(Au.clip(8000, 1, Au.f32(), [0, 1065353216]))))
    == Some{Au.clip(8000, 1, Au.f32(), [0, 1065353216])} : Maybe<&2, Au.Clip>}

# LAW: IBM/Microsoft RIFF — binary32 stereo round-trips
law wav_f32_stereo:
  {Au.decode_wav(D2.bytes.of(Au.encode_wav(Au.clip(8000, 2, Au.f32(), [0, 1065353216]))))
    == Some{Au.clip(8000, 2, Au.f32(), [0, 1065353216])} : Maybe<&2, Au.Clip>}
