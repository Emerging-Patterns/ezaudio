# ISO/IEC 11172-3 MPEG-1 Layer III: each header field is read from its own
# bits, whatever the other bytes hold, so `FF FB 90 C0` reads as Layer III,
# MPEG-1, 128 kbit/s, 44100 Hz, single channel
import Base
import ../src/mp3.bend as Mp3

# LAW: ISO/IEC 11172-3 — the second byte FB is Layer III, whatever the other bytes
law mp3_layer:
  for +b0: U32
  for +b2: U32
  for +b3: U32
  for +rest: List<&2, U32>
  {Mp3.hdr.layer(b0 <> 251 <> b2 <> b3 <> rest) == 1 : U32}

# LAW: ISO/IEC 11172-3 — the second byte FB is MPEG-1, whatever the other bytes
law mp3_mpeg1:
  for +b0: U32
  for +b2: U32
  for +b3: U32
  for +rest: List<&2, U32>
  {Mp3.hdr.mpeg1(b0 <> 251 <> b2 <> b3 <> rest) == 1 : U32}

# LAW: ISO/IEC 11172-3 — the third byte 90 is 128 kbit/s, whatever the other bytes
law mp3_kbps:
  for +b0: U32
  for +b1: U32
  for +b3: U32
  for +rest: List<&2, U32>
  {Mp3.hdr.kbps(b0 <> b1 <> 144 <> b3 <> rest) == 128 : U32}

# LAW: ISO/IEC 11172-3 — the third byte 90 is 44100 Hz, whatever the other bytes
law mp3_hz:
  for +b0: U32
  for +b1: U32
  for +b3: U32
  for +rest: List<&2, U32>
  {Mp3.hdr.hz(b0 <> b1 <> 144 <> b3 <> rest) == 44100 : U32}

# LAW: ISO/IEC 11172-3 — the fourth byte C0 is single channel, whatever the other bytes
law mp3_mode:
  for +b0: U32
  for +b1: U32
  for +b2: U32
  for +rest: List<&2, U32>
  {Mp3.hdr.mode(b0 <> b1 <> b2 <> 192 <> rest) == 3 : U32}
