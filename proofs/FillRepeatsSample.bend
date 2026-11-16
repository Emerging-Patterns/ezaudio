# proofs of laws/FillRepeatsSample.bend
import Base
import ../laws/FillRepeatsSample.bend as Laws
import ./lemmas/NatAndLists.bend as M1

def Laws.fill_repeats(_rate, _nch, _fmt, _sample, _nframes):
  {==}

def Laws.fill_count(_rate, nch, _fmt, sample, nframes):
  M1.len_rep(Nat.mul(U32.to_nat(nframes), U32.to_nat(nch)), sample)
