# the encoder's `u.nth` reads the sample at an index of a sample list
import Base
import ../src/mp3_enc.bend as Enc

# LAW: a sample list reads the sample at an index
law enc_nth:
  {Enc.u.nth([4, 5], 1) == 5 : U32}
