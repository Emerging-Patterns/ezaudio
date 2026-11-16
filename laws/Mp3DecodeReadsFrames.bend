# `decode_mp3` reads a stream only through the whole frames `mp3.frames`
# finds, for every input: two byte strings with the same frames decode the
# same. What mp3.frames skips (a leading ID3v2 tag, bytes that do not start
# an MPEG-1 Layer III header, a first Xing or Info frame, a last frame the
# bytes end inside) is checked on fixture frames by tests/fixtures.bend; no
# law here proves it.
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3

# LAW: decode_mp3 depends on the bytes only through the frames mp3.frames finds
law mp3_reads_frames:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for h_frames: {Mp3.mp3.frames(xs) == Mp3.mp3.frames(ys) : List<&2, List<&2, U32>>}
  {Au.decode_mp3(xs) == Au.decode_mp3(ys) : Maybe<&2, Au.Clip>}
