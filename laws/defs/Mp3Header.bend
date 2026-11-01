# an MPEG-1 Layer III frame header
import Base

# FF FB 90 C0: MPEG-1 Layer III, 128 kbit/s, 44100 Hz, mono, no CRC
def fix.hdr() -> List<&2, U32>:
  [255, 251, 144, 192]
