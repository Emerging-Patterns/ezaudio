# proofs of laws/Mp3DecodeReadsFrames.bend
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../laws/Mp3DecodeReadsFrames.bend as Laws
import ../laws/defs/Mp3Frames.bend as D1

# decode_mp3 is mp3.play of mp3.frames, then the whole-frames check: equal frames, equal decodes
def same.frames(
  +xs: List<&2, U32>,
  +ys: List<&2, U32>,
  h_frames: {Mp3.mp3.frames(xs) == Mp3.mp3.frames(ys) : List<&2, List<&2, U32>>}
) -> {Au.decode_mp3(xs) == Au.decode_mp3(ys) : Maybe<&2, Au.Clip>}:
  Equal.cong(List<&2, List<&2, U32>>, Maybe<&2, Au.Clip>, fs => Au.mp3.parsed(Mp3.mp3.play(fs)),
    Mp3.mp3.frames(xs), Mp3.mp3.frames(ys), h_frames)

def Laws.mp3_reads_frames(xs, ys, h_frames):
  same.frames(xs, ys, h_frames)

def Laws.mp3_two_frames():
  {==}

def Laws.mp3_id3_skipped():
  same.frames(D1.fx.cat(D1.fix.id3(), D1.fix.frame()), D1.fix.frame(), {==})

def Laws.mp3_id3_footer_skipped():
  same.frames(D1.fx.cat(D1.fix.id3foot(), D1.fix.frame()), D1.fix.frame(), {==})

def Laws.mp3_junk_skipped():
  same.frames(D1.fx.cat(D1.fix.junk(), D1.fx.cat(D1.fix.frame(), D1.fx.cat(D1.fix.junk(), D1.fix.frame()))),
    D1.fx.cat(D1.fix.frame(), D1.fix.frame()), {==})

def Laws.mp3_partial_dropped():
  same.frames(D1.fx.cat(D1.fix.frame(), D1.fx.take(50, D1.fix.frame())), D1.fix.frame(), {==})

def Laws.mp3_partial_alone():
  {==}

def Laws.mp3_info_skipped():
  same.frames(D1.fx.cat(D1.fix.info(), D1.fix.frame()), D1.fix.frame(), {==})

def Laws.mp3_xing_skipped():
  same.frames(D1.fx.cat(D1.fix.xing(), D1.fix.frame()), D1.fix.frame(), {==})

def Laws.mp3_info_later_kept():
  {==}
