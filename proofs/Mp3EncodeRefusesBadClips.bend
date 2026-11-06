# proofs of laws/Mp3EncodeRefusesBadClips.bend
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../laws/Mp3EncodeRefusesBadClips.bend as Laws
import ./lemmas/Mp3Encode.bend as M2

def Laws.mp3_encodes_iff(hz, nch, fmt, pcm):
  M2.pick_is(Mp3.enc.fit(hz, nch), hz, nch, Au.kind.of(fmt), pcm)

def Laws.mp3_empty():
  {==}

def Laws.mp3_rate():
  {==}

def Laws.mp3_three():
  {==}
