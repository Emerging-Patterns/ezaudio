# proofs of laws/Mp3SamplesAreClamped.bend
import Base
import ../src/mp3_enc.bend as Enc
import ../laws/Mp3SamplesAreClamped.bend as Laws
import ./lemmas/NatAndLists.bend as M1

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

def Laws.mp3_kept(ww, h_ok):
  Equal.cong(Bool, U32, ok => Enc.samp.pick(ok, ww), U32.is_le((ww .&. 2147483647 : U32), 1065353216), True{}, h_ok)

# a word past 1.0's magnitude bits is replaced by what samp.big says of it
def big.of(
  +ww: U32,
  h_big: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == False{} : Bool}
) -> {Enc.samp.sat(ww)
  == Enc.samp.big(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0)) : U32}:
  Equal.cong(Bool, U32, ok => Enc.samp.pick(ok, ww), U32.is_le((ww .&. 2147483647 : U32), 1065353216), False{}, h_big)

# samp.big of a NaN is 0
def big.nan(nan: Bool, neg: Bool, h_nan: {nan == True{} : Bool}) -> {Enc.samp.big(nan, neg) == 0 : U32}:
  match nan:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({Enc.samp.big(False{}, neg) == 0 : U32}, M1.false_true(h_nan))

# samp.big of a word that is not NaN is 1 with its sign
def big.sign(
  nan: Bool,
  neg: Bool,
  h_nan: {nan == False{} : Bool}
) -> {Enc.samp.big(nan, neg) == Enc.samp.sign(neg) : U32}:
  match nan:
    case False{}:
      {==}
    case True{}:
      Empty.absurd({Enc.samp.big(True{}, neg) == Enc.samp.sign(neg) : U32},
        M1.false_true(Equal.sym(Bool, True{}, False{}, h_nan)))

def Laws.mp3_nan(ww, h_big, h_nan):
  Equal.trans(U32, Enc.samp.sat(ww),
    Enc.samp.big(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0)), 0,
    big.of(ww, h_big),
    big.nan(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0), h_nan))

# a big word that is not NaN is 1 with the sign its sign bit gives
def big.signed(
  +ww: U32,
  h_big: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == False{} : Bool},
  h_nan: {U32.is_lt(2139095040, (ww .&. 2147483647 : U32)) == False{} : Bool}
) -> {Enc.samp.sat(ww) == Enc.samp.sign(U32.is_ne((ww .&. 2147483648 : U32), 0)) : U32}:
  Equal.trans(U32, Enc.samp.sat(ww),
    Enc.samp.big(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0)),
    Enc.samp.sign(U32.is_ne((ww .&. 2147483648 : U32), 0)),
    big.of(ww, h_big),
    big.sign(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0), h_nan))

def Laws.mp3_neg_big(ww, h_big, h_nan, h_neg):
  Equal.trans(U32, Enc.samp.sat(ww), Enc.samp.sign(U32.is_ne((ww .&. 2147483648 : U32), 0)), 3212836864,
    big.signed(ww, h_big, h_nan),
    Equal.cong(Bool, U32, nn => Enc.samp.sign(nn), U32.is_ne((ww .&. 2147483648 : U32), 0), True{}, h_neg))

def Laws.mp3_pos_big(ww, h_big, h_nan, h_neg):
  Equal.trans(U32, Enc.samp.sat(ww), Enc.samp.sign(U32.is_ne((ww .&. 2147483648 : U32), 0)), 1065353216,
    big.signed(ww, h_big, h_nan),
    Equal.cong(Bool, U32, nn => Enc.samp.sign(nn), U32.is_ne((ww .&. 2147483648 : U32), 0), False{}, h_neg))
