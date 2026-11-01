# ISO/IEC 11172-3: `decode_mp3` is none for Layer I and Layer II, for
# joint stereo, for a header with a CRC, and for a header with no frame
# behind it. Decode accepts long blocks only; short blocks, a non-zero
# scale-factor compress, a bit reservoir, the count1 region, preflag and
# scale-factor scale are also none, but no law covers those yet
import Base
import ../main.bend as Au
import ./defs/Mp3Header.bend as D1

# LAW: ISO/IEC 11172-3 — Layer I decodes as none
law mp3_layer1:
  {Au.decode_mp3([255, 255, 144, 192]) == None{} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 — Layer II decodes as none
law mp3_layer2:
  {Au.decode_mp3([255, 253, 144, 192]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a joint-stereo header decodes as none
law mp3_joint:
  {Au.decode_mp3([255, 251, 144, 64]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a header with a CRC decodes as none
law mp3_crc:
  {Au.decode_mp3([255, 250, 144, 192]) == None{} : Maybe<&2, Au.Clip>}

# LAW: a header without its frame decodes as none
law mp3_short:
  {Au.decode_mp3(D1.fix.hdr()) == None{} : Maybe<&2, Au.Clip>}
