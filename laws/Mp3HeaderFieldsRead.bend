# ISO/IEC 11172-3 MPEG-1 Layer III: the header `FF FB 90 C0` reads as
# Layer III, MPEG-1, 128 kbit/s, 44100 Hz, single channel
import Base
import ../src/mp3.bend as Mp3
import ./defs/Mp3Header.bend as D1

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is Layer III
law mp3_layer:
  {Mp3.hdr.layer(D1.fix.hdr()) == 1 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is MPEG-1
law mp3_mpeg1:
  {Mp3.hdr.mpeg1(D1.fix.hdr()) == 1 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is 128 kbit/s
law mp3_kbps:
  {Mp3.hdr.kbps(D1.fix.hdr()) == 128 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is 44100 Hz
law mp3_hz:
  {Mp3.hdr.hz(D1.fix.hdr()) == 44100 : U32}

# LAW: ISO/IEC 11172-3 — FF FB 90 C0 is single channel
law mp3_mode:
  {Mp3.hdr.mode(D1.fix.hdr()) == 3 : U32}
