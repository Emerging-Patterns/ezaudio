# ISO/IEC 11172-3 2.4.1.7, 2.4.3.4: every granule the encoder codes, for
# every spectrum, rate and bit budget, has a part2_3_length that is the
# length of its Huffman bits, at most the budget, and those bits are its
# first big_values pairs coded in its table, so the big_values pairs end
# where part2_3_length does. The budget is at most 4095 bits, the largest
# 12-bit part2_3_length, for every rate and channel count, and at each rate
# a frame holds its header, side information and every granule's budget.
import Base
import ../src/mp3.bend as Mp3
import ../src/mp3_enc.bend as Enc
import ./defs/Mp3Stream.bend as D1

# LAW: part2_3_length is the number of Huffman bits the granule writes
law mp3_gr_part:
  for +ht: Enc.Ht
  for +spec: List<&2, F32>
  for +hz: U32
  for +bud: U32
  {Enc.gr.part(Enc.gr.of(ht, spec, hz, bud))
    == U32.from_nat(List.length(&2, U32, Enc.gr.bits(Enc.gr.of(ht, spec, hz, bud)))) : U32}

# LAW: part2_3_length is at most the bit budget
law mp3_gr_fit:
  for +ht: Enc.Ht
  for +spec: List<&2, F32>
  for +hz: U32
  for +bud: U32
  {U32.is_le(Enc.gr.part(Enc.gr.of(ht, spec, hz, bud)), bud) == True{} : Bool}

# LAW: the bits are the granule's first big_values pairs, coded in its table
law mp3_gr_code:
  for +ht: Enc.Ht
  for +spec: List<&2, F32>
  for +hz: U32
  for +bud: U32
  {Enc.hf.code(ht, Enc.take.u(U32.to_nat((Enc.gr.big(Enc.gr.of(ht, spec, hz, bud)) * 2 : U32)),
    Enc.gr.ix(Enc.gr.of(ht, spec, hz, bud)), []), Enc.gr.tab(Enc.gr.of(ht, spec, hz, bud)))
    == Some{Enc.gr.bits(Enc.gr.of(ht, spec, hz, bud))} : Maybe<&2, List<&2, U32>>}

# LAW: the budget fits the 12-bit part2_3_length field for every rate and channel count
law mp3_bud:
  for +hz: U32
  for +ch: U32
  {U32.is_le(Mp3.enc.bud(hz, ch), 4095) == True{} : Bool}

# LAW: at 32000, 44100 and 48000 Hz, mono and stereo, an unpadded frame holds its header,
# its side information (17 or 32 bytes) and two granules per channel at the budget
law mp3_room:
  {D1.room.all() == True{} : Bool}
