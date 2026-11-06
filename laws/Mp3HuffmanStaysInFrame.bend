# ISO/IEC 11172-3 §2.4.2.7: a granule channel's Huffman bits are its
# part2_3_length bits of main data, and the main data ends with the frame.
# Big values that read past part2_3_length, or granule channels that claim
# more bits than the frame holds, are none rather than lines read from the
# next granule or past the frame. The fixture frame itself reads its lines
# (Mp3Count1Decoded) and decodes (Mp3DecodeRefusesUnsupported).
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../src/mp3_dec.bend as Dec
import ./defs/Mp3Frames.bend as D1

# LAW: ISO/IEC 11172-3 §2.4.2.7 — big values one bit longer than part2_3_length are none
law mp3_overrun_lines:
  {Mp3.mp3.lines(D1.fix.overrun()) == None{} : Maybe<&2, List<&2, Dec.Gl>>}

# LAW: ISO/IEC 11172-3 §2.4.2.7 — a frame whose big values overrun decodes as none
law mp3_overrun:
  {Au.decode_mp3(D1.fix.overrun()) == None{} : Maybe<&2, Au.Clip>}

# LAW: ISO/IEC 11172-3 §2.4.2.7 — a part2_3_length past the frame's main data is none
law mp3_past_end_lines:
  {Mp3.mp3.lines(D1.fix.past()) == None{} : Maybe<&2, List<&2, Dec.Gl>>}

# LAW: ISO/IEC 11172-3 §2.4.2.7 — a frame claiming bits past its end decodes as none
law mp3_past_end:
  {Au.decode_mp3(D1.fix.past()) == None{} : Maybe<&2, Au.Clip>}
