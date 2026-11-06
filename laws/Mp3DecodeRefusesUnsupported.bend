# ISO/IEC 11172-3: `decode_mp3` decodes the fixture frame to 1152 mono
# samples at 48000 Hz, and is none for that frame with only its layer bits
# changed (Layer I, Layer II: not Layer III, so junk, and no frame is left),
# only its mode bits changed (joint stereo with mid/side; joint stereo with
# neither mid/side nor intensity decodes as stereo), or one side-info
# field set that the decoder does not read: a bit reservoir (main_data_begin
# 1), scale-factor bits (scalefac_compress 1), or window switching (short
# blocks). A header with no frame behind it is none too. Preflag,
# scalefac_scale and intensity stereo are also none; no law covers those yet.
import Base
import ../main.bend as Au
import ./defs/Mp3Header.bend as D1
import ./defs/Mp3Frames.bend as D2

# LAW: ISO/IEC 11172-3 — the fixture frame decodes to 1152 samples, mono, 48000 Hz
law mp3_frame_decodes:
  {D2.clip.shape(Au.decode_mp3(D2.fix.frame())) == [48000, 1, 1152] : List<&2, U32>}

# LAW: ISO/IEC 11172-3 — that frame with the Layer I layer bits decodes as none
law mp3_layer1:
  {Au.decode_mp3(D2.fix.layer1()) == None{} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — that frame with the Layer II layer bits decodes as none
law mp3_layer2:
  {Au.decode_mp3(D2.fix.layer2()) == None{} : Maybe<&2, Au.Clip>}

# LAW: that frame in joint stereo with mid/side decodes as none
law mp3_joint:
  {Au.decode_mp3(D2.fix.joint()) == None{} : Maybe<&2, Au.Clip>}

# LAW: a silent joint-stereo frame whose mode extension sets neither mid/side nor intensity decodes as stereo
law mp3_joint_plain:
  {D2.clip.shape(Au.decode_mp3(D2.fx.frame([255, 251, 20, 68], [], []))) == [48000, 2, 2304] : List<&2, U32>}

# LAW: the same silent frame with mid/side set decodes as none
law mp3_joint_ms_silent:
  {Au.decode_mp3(D2.fx.frame([255, 251, 20, 100], [], [])) == None{} : Maybe<&2, Au.Clip>}

# LAW: that frame with main_data_begin 1, a bit reservoir, decodes as none
law mp3_reservoir:
  {Au.decode_mp3(D2.fix.reservoir()) == None{} : Maybe<&2, Au.Clip>}

# LAW: that frame with scalefac_compress 1 in granule 0 decodes as none
law mp3_scfc:
  {Au.decode_mp3(D2.fix.scfc()) == None{} : Maybe<&2, Au.Clip>}

# LAW: that frame with short blocks in granule 0 decodes as none
law mp3_window:
  {Au.decode_mp3(D2.fix.window()) == None{} : Maybe<&2, Au.Clip>}

# LAW: a header without its frame decodes as none
law mp3_short:
  {Au.decode_mp3(D1.fix.hdr()) == None{} : Maybe<&2, Au.Clip>}
