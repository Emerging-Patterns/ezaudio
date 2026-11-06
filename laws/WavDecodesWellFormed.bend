# Every clip `decode_wav` returns is well formed, for every input: one or two
# channels, and a sample count that is a multiple of the channel count, so
# every frame is whole. A data chunk that ends in part of a frame keeps only
# its whole frames, as libsndfile and dr_wav read it.
import Base
import ../main.bend as Au
import ./defs/WellFormed.bend as D1

# LAW: every clip decode_wav returns, whatever the bytes, is well formed
law wav_decode_well_formed:
  for +bytes: List<&2, U32>
  for +clip: Au.Clip
  for h_dec: {Au.decode_wav(bytes) == Some{clip} : Maybe<&2, Au.Clip>}
  {D1.wf(clip) == True{} : Bool}
