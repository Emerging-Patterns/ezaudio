# proofs of laws/FillRepeatsSample.bend
import Base
import ../laws/FillRepeatsSample.bend as Laws
import ./lemmas/NatAndLists.bend as M1

def Laws.fill_mono():
  {==}

def Laws.fill_stereo():
  {==}

def Laws.fill_count(_rate, nch, _fmt, sample, nframes):
  M1.len_rep(Nat.mul(U32.to_nat(nframes), U32.to_nat(nch)), sample)
