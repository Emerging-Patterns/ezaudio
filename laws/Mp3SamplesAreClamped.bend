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

# LAW: NaN reads as 0
law mp3_nan:
  {Enc.samp.sat(2143289344) == 0 : U32}

# LAW: negative infinity reads as -1
law mp3_neg_inf:
  {Enc.samp.sat(4286578688) == 3212836864 : U32}

# LAW: 64.0 reads as 1
law mp3_loud:
  {Enc.samp.sat(1115684864) == 1065353216 : U32}

# LAW: 0.5 is kept
law mp3_half:
  {Enc.samp.sat(1056964608) == 1056964608 : U32}
