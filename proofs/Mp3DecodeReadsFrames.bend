# proofs of laws/Mp3DecodeReadsFrames.bend
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../laws/Mp3DecodeReadsFrames.bend as Laws

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
