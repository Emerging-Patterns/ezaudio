# ISO/IEC 11172-3 error_check: a protection_bit of 0 puts a 16-bit CRC after the
# header, so the side info and the main data start 2 bytes later. The CRC is
# skipped, not checked, as ffmpeg and minimp3 do by default. The fixture
# frame with a CRC, the same side info and main data, reads the same lines
# and decodes to a whole frame.
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../src/mp3_dec.bend as Dec
import ./defs/Mp3Frames.bend as D1

# LAW: ISO/IEC 11172-3 error_check — with a CRC the frame reads the lines it reads without one
law mp3_crc_lines:
  {Mp3.mp3.lines(D1.fix.crc()) == Mp3.mp3.lines(D1.fix.frame()) : Maybe<&2, List<&2, Dec.Gl>>}

# LAW: ISO/IEC 11172-3 error_check — a frame with a CRC decodes to 1152 samples, mono, 48000 Hz
law mp3_crc_decodes:
  {D1.clip.shape(Au.decode_mp3(D1.fix.crc())) == [48000, 1, 1152] : List<&2, U32>}
