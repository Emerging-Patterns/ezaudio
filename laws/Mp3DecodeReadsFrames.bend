# `decode_mp3` reads a stream only through the whole frames `mp3.frames`
# finds, for every input: two byte strings with the same frames decode the
# same. mp3.frames skips a leading ID3v2 tag by its size (and its footer),
# steps over bytes that do not start an MPEG-1 Layer III header (a Layer I
# or II header, an MPEG-2.5 sync as in an APEv2 tag, a JPEG start), skips a
# Xing or Info frame when it comes first, and drops a frame the bytes end
# inside, as minimp3 and dr_mp3 do. A frame with a valid MPEG-1 Layer III
# header is never stepped over: if the decoder cannot read it, the whole
# decode is none (Mp3DecodeRefusesUnsupported). The fixture laws below are
# decode_mp3 equalities over the frame of laws/defs/Mp3Frames.bend; the
# frame decodes (Mp3DecodeRefusesUnsupported) and two of it are two frames.
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ./defs/Mp3Frames.bend as D1

# LAW: decode_mp3 depends on the bytes only through the frames mp3.frames finds
law mp3_reads_frames:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for h_frames: {Mp3.mp3.frames(xs) == Mp3.mp3.frames(ys) : List<&2, List<&2, U32>>}
  {Au.decode_mp3(xs) == Au.decode_mp3(ys) : Maybe<&2, Au.Clip>}

# LAW: two fixture frames decode to 2304 samples, mono, 48000 Hz
law mp3_two_frames:
  {D1.clip.shape(Au.decode_mp3(D1.fx.cat(D1.fix.frame(), D1.fix.frame()))) == [48000, 1, 2304] : List<&2, U32>}

# LAW: ID3v2 — a leading tag is skipped by its size, even when its data holds a frame header
law mp3_id3_skipped:
  {Au.decode_mp3(D1.fx.cat(D1.fix.id3(), D1.fix.frame())) == Au.decode_mp3(D1.fix.frame())
    : Maybe<&2, Au.Clip>}

# LAW: ID3v2.4 — a leading tag with the footer flag is skipped with its 10-byte footer
law mp3_id3_footer_skipped:
  {Au.decode_mp3(D1.fx.cat(D1.fix.id3foot(), D1.fix.frame())) == Au.decode_mp3(D1.fix.frame())
    : Maybe<&2, Au.Clip>}

# LAW: junk before and between frames is stepped over, and both frames are kept
law mp3_junk_skipped:
  {Au.decode_mp3(D1.fx.cat(D1.fix.junk(), D1.fx.cat(D1.fix.frame(), D1.fx.cat(D1.fix.junk(), D1.fix.frame()))))
    == Au.decode_mp3(D1.fx.cat(D1.fix.frame(), D1.fix.frame())) : Maybe<&2, Au.Clip>}

# LAW: a last frame the bytes end inside is dropped; the whole frames before it decode
law mp3_partial_dropped:
  {Au.decode_mp3(D1.fx.cat(D1.fix.frame(), D1.fx.take(50, D1.fix.frame()))) == Au.decode_mp3(D1.fix.frame())
    : Maybe<&2, Au.Clip>}

# LAW: a lone partial frame is no frame, so none
law mp3_partial_alone:
  {Au.decode_mp3(D1.fx.take(95, D1.fix.frame())) == None{} : Maybe<&2, Au.Clip>}

# LAW: a first Info frame is skipped
law mp3_info_skipped:
  {Au.decode_mp3(D1.fx.cat(D1.fix.info(), D1.fix.frame())) == Au.decode_mp3(D1.fix.frame()) : Maybe<&2, Au.Clip>}

# LAW: a first Xing frame is skipped
law mp3_xing_skipped:
  {Au.decode_mp3(D1.fx.cat(D1.fix.xing(), D1.fix.frame())) == Au.decode_mp3(D1.fix.frame()) : Maybe<&2, Au.Clip>}

# LAW: an Info frame after the first frame is a frame: two frames, 2304 samples
law mp3_info_later_kept:
  {D1.clip.shape(Au.decode_mp3(D1.fx.cat(D1.fix.frame(), D1.fix.info()))) == [48000, 1, 2304] : List<&2, U32>}
