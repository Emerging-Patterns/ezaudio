# proofs of laws/Mp3SamplesAreClamped.bend
import Base
import ../src/mp3_enc.bend as Enc
import ../laws/Mp3SamplesAreClamped.bend as Laws

# 0, -1 and 1 have magnitude bits at most 1.0's
def big.le(
  nan: Bool,
  neg: Bool
) -> {U32.is_le((Enc.samp.big(nan, neg) .&. 2147483647 : U32), 1065353216) == True{} : Bool}:
  match nan neg:
    case True{} _neg:
      {==}
    case False{} True{}:
      {==}
    case False{} False{}:
      {==}

# a kept word passed the check; a replaced one is 0, -1 or 1
def pick.le(
  ok: Bool,
  +ww: U32,
  hh: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == ok : Bool}
) -> {U32.is_le((Enc.samp.pick(ok, ww) .&. 2147483647 : U32), 1065353216) == True{} : Bool}:
  match ok:
    case True{}:
      hh
    case False{}:
      big.le(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0))

def Laws.mp3_clamped(ww):
  pick.le(U32.is_le((ww .&. 2147483647 : U32), 1065353216), ww, {==})

def Laws.mp3_reads_sat(_ww):
  {==}

def Laws.mp3_nan():
  {==}

def Laws.mp3_neg_inf():
  {==}

def Laws.mp3_loud():
  {==}

def Laws.mp3_half():
  {==}
