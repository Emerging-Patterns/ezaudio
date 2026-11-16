# proofs of laws/CountDividesByChannels.bend
import Base
import ../main.bend as Au
import ../laws/CountDividesByChannels.bend as Laws

def Laws.count_frames(_hz, nch, _fmt, pcm, h_nch):
  Equal.cong(Bool, U32, zz => Au.count.at(zz, nch, U32.from_nat(List.length(&2, U32, pcm))), U32.is_eq(nch, 0),
    False{}, h_nch)

def Laws.count_zero_channels(_hz, _fmt, _pcm):
  {==}
