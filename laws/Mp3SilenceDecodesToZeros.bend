# ISO/IEC 11172-3: each silent frame decodes to 1152 zero binary32
# samples per channel. These frames are all zero after the header, on a
# decoder that has decoded no sound yet: zero spectra on a zero overlap and
# delay synthesize to zeros, and the decoder takes that path without the
# filterbank. The checker does not evaluate binary32 arithmetic, so the
# filterbank's own output is not checked here; bench/compare.nix checks it
# against ffmpeg.
import Base
import ../main.bend as Au
import ./defs/ByteLists.bend as D1

# LAW: ISO/IEC 11172-3 — that byte string decodes to 1152 zero binary32 samples
law mp3_silence_fix:
  {Au.decode_mp3(D1.frame.z([255, 251, 224, 196], 1044))
    == Some{Au.clip(44100, 1, Au.f32(), D1.pcm.z(1152))} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — that byte string decodes to 1152 zero samples on each channel
law mp3_stereo_fix:
  {Au.decode_mp3(D1.frame.z([255, 251, 224, 4], 1044))
    == Some{Au.clip(44100, 2, Au.f32(), D1.pcm.z(2304))} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — those 960 bytes decode to 1152 zero samples
law mp3_hz48_fix:
  {Au.decode_mp3(D1.frame.z([255, 251, 228, 196], 960))
    == Some{Au.clip(48000, 1, Au.f32(), D1.pcm.z(1152))} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — those 1440 bytes decode to 1152 zero samples
law mp3_hz32_fix:
  {Au.decode_mp3(D1.frame.z([255, 251, 232, 196], 1440))
    == Some{Au.clip(32000, 1, Au.f32(), D1.pcm.z(1152))} : Maybe<&2, Au.Clip>}
