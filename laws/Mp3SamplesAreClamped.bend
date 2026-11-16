# a binary32 sample the encoder reads is finite with magnitude at most 1,
# for every 32-bit word: NaN is 0, an infinity or a magnitude past 1 is -1
# or 1 with its sign, and any other word is kept. As IEEE 754 orders the
# magnitude bits of non-negative binary32 words, magnitude bits at most
# 1.0's (3F800000) are a finite value of magnitude at most 1.
import Base
import ../src/mp3_enc.bend as Enc

# LAW: every sanitized word's magnitude bits are at most 1.0's
law mp3_clamped:
  for +ww: U32
  {U32.is_le((Enc.samp.sat(ww) .&. 2147483647 : U32), 1065353216) == True{} : Bool}

# LAW: the encoder reads every binary32 word through the sanitizer
law mp3_reads_sat:
  for +ww: U32
  {Enc.samp.of(3, ww) == Enc.f32.bits(Enc.samp.sat(ww)) : F32}

# LAW: a word whose magnitude bits are at most 1.0's is kept
law mp3_kept:
  for +ww: U32
  for h_ok: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == True{} : Bool}
  {Enc.samp.sat(ww) == ww : U32}

# LAW: a NaN, its magnitude bits past infinity's (7F800000), reads as 0
law mp3_nan:
  for +ww: U32
  for h_big: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == False{} : Bool}
  for h_nan: {U32.is_lt(2139095040, (ww .&. 2147483647 : U32)) == True{} : Bool}
  {Enc.samp.sat(ww) == 0 : U32}

# LAW: a negative infinity or magnitude past 1 reads as -1
law mp3_neg_big:
  for +ww: U32
  for h_big: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == False{} : Bool}
  for h_nan: {U32.is_lt(2139095040, (ww .&. 2147483647 : U32)) == False{} : Bool}
  for h_neg: {U32.is_ne((ww .&. 2147483648 : U32), 0) == True{} : Bool}
  {Enc.samp.sat(ww) == 3212836864 : U32}

# LAW: a positive infinity or magnitude past 1 reads as 1
law mp3_pos_big:
  for +ww: U32
  for h_big: {U32.is_le((ww .&. 2147483647 : U32), 1065353216) == False{} : Bool}
  for h_nan: {U32.is_lt(2139095040, (ww .&. 2147483647 : U32)) == False{} : Bool}
  for h_neg: {U32.is_ne((ww .&. 2147483648 : U32), 0) == False{} : Bool}
  {Enc.samp.sat(ww) == 1065353216 : U32}
