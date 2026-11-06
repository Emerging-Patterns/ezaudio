# ISO/IEC 11172-3: silence encodes as whole 320 kbit/s frames of the header
# and then zeros, as many as any clip of its length: one zero sample is two
# frames. `FF FB E0 C4` and 1044 bytes, then `FF FB E2 C4` and 1045 (the
# pad bit) at 44100 Hz mono, `04` for stereo, `FF FB E4 C4` and 960 bytes
# at 48000 Hz, `FF FB E8 C4` and 1440 bytes at 32000 Hz. Binary32 zeros of
# either sign encode as the signed-16 frames. A silent clip skips the
# filterbank, whose zero lines would quantize to these zero granules.
import Base
import ../main.bend as Au
import ./defs/ByteLists.bend as D1

# LAW: ISO/IEC 11172-3 — silent 44100 Hz mono is two frames of header and zeros, the second padded
law mp3_silence_frame:
  {Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [0]))
    == Some{List.append(&2, U32, D1.frame.z([255, 251, 224, 196], 1044), D1.frame.z([255, 251, 226, 196], 1045))}
    : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — silent stereo is FF FB E0 04 and then zeros, twice
law mp3_stereo_frame:
  {Au.encode_mp3(Au.clip(44100, 2, Au.s16(), [0, 0]))
    == Some{List.append(&2, U32, D1.frame.z([255, 251, 224, 4], 1044), D1.frame.z([255, 251, 226, 4], 1045))}
    : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — silent 48000 Hz is FF FB E4 C4 and then zeros, twice
law mp3_hz48_frame:
  {Au.encode_mp3(Au.clip(48000, 1, Au.s16(), [0]))
    == Some{List.append(&2, U32, D1.frame.z([255, 251, 228, 196], 960), D1.frame.z([255, 251, 228, 196], 960))}
    : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — silent 32000 Hz is FF FB E8 C4 and then zeros, twice
law mp3_hz32_frame:
  {Au.encode_mp3(Au.clip(32000, 1, Au.s16(), [0]))
    == Some{List.append(&2, U32, D1.frame.z([255, 251, 232, 196], 1440), D1.frame.z([255, 251, 232, 196], 1440))}
    : Maybe<&2, List<&2, U32>>}

# LAW: binary32 silence is the same frames as signed-16 silence
law mp3_f32_frame:
  {Au.encode_mp3(Au.clip(44100, 1, Au.f32(), [0]))
    == Some{List.append(&2, U32, D1.frame.z([255, 251, 224, 196], 1044), D1.frame.z([255, 251, 226, 196], 1045))}
    : Maybe<&2, List<&2, U32>>}

# LAW: binary32 -0.0 is silence too
law mp3_negzero_frame:
  {Au.encode_mp3(Au.clip(44100, 1, Au.f32(), [2147483648]))
    == Some{List.append(&2, U32, D1.frame.z([255, 251, 224, 196], 1044), D1.frame.z([255, 251, 226, 196], 1045))}
    : Maybe<&2, List<&2, U32>>}
