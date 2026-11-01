# the synthesis filterbank's `u.add` is the sum of two counts
import Base
import ../src/mp3_syn.bend as Syn

# LAW: adding two counts yields their sum
law syn_add:
  {Syn.u.add(2, 3) == 5 : U32}
