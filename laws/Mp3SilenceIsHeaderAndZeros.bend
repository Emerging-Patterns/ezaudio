# ISO/IEC 11172-3: a silent frame at 320 kbit/s is the header and then
# zeros for the rest of `1152 * 320 * 125 / hz` bytes: `FF FB E0 C4` and
# 1044 bytes at 44100 Hz mono, `FF FB E0 04` and 1044 bytes for stereo,
# `FF FB E4 C4` and 960 bytes at 48000 Hz, `FF FB E8 C4` and 1440 bytes at
# 32000 Hz. Binary32 silence encodes as the signed-16 frame
import Base
import ../main.bend as Au
import ./defs/ByteLists.bend as D1

# LAW: ISO/IEC 11172-3 — silent 44100 Hz mono is FF FB E0 C4 and then zeros
# (header + length; weaker head/len/encode-then-decode laws omitted — same Enc.enc.run)
law mp3_silence_frame:
  {Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [0])) == Some{D1.frame.z([255, 251, 224, 196], 1044)}
    : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — silent stereo is FF FB E0 04 and then zeros
law mp3_stereo_frame:
  {Au.encode_mp3(Au.clip(44100, 2, Au.s16(), [0, 0])) == Some{D1.frame.z([255, 251, 224, 4], 1044)}
    : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — a silent 48000 Hz frame is FF FB E4 C4 and then zeros
law mp3_hz48_frame:
  {Au.encode_mp3(Au.clip(48000, 1, Au.s16(), [0])) == Some{D1.frame.z([255, 251, 228, 196], 960)}
    : Maybe<&2, List<&2, U32>>}

# LAW: ISO/IEC 11172-3 — a silent 32000 Hz frame is FF FB E8 C4 and then zeros
law mp3_hz32_frame:
  {Au.encode_mp3(Au.clip(32000, 1, Au.s16(), [0])) == Some{D1.frame.z([255, 251, 232, 196], 1440)}
    : Maybe<&2, List<&2, U32>>}

# LAW: binary32 silence is the same frame as signed-16 silence
law mp3_f32_frame:
  {Au.encode_mp3(Au.clip(44100, 1, Au.f32(), [0])) == Some{D1.frame.z([255, 251, 224, 196], 1044)}
    : Maybe<&2, List<&2, U32>>}
