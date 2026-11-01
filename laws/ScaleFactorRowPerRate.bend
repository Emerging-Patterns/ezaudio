# the decoder's scale-factor band table has one row of 22 bands per
# sample rate: 44100 Hz first, then 48000 Hz, then 32000 Hz
import Base
import ../src/mp3_dec.bend as Dec

# LAW: the 44100 Hz scale-factor row is the first row
law scf_44100:
  {Dec.scf.off(44100) == 0 : U32}

# LAW: the 48000 Hz scale-factor row starts at band 22
law scf_48000:
  {Dec.scf.off(48000) == 22 : U32}

# LAW: the 32000 Hz scale-factor row starts at band 44
law scf_32000:
  {Dec.scf.off(32000) == 44 : U32}
