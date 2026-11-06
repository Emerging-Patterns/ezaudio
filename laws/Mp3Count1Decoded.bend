# ISO/IEC 11172-3 §2.4.2.7: a granule channel's Huffman bits are its
# big_values pairs, then count1 quadruples (tables A and B, each value -1, 0
# or 1) until part2_3_length bits are read or line 576 is reached, then
# zeros. A quadruple that runs past part2_3_length is discarded, as ffmpeg
# discards it. These are the quantized lines, before requantization, that the
# decoder reads from the fixture frame: granule 0 has two table-1 pairs, three
# table-A quadruples and a fourth cut off in its sign bits; granule 1 has a
# table-16 pair whose 15 takes one linbit, then one table-B quadruple.
import Base
import ../src/mp3.bend as Mp3
import ../src/mp3_dec.bend as Dec
import ./defs/Mp3Frames.bend as D1

# LAW: ISO/IEC 11172-3 §2.4.2.7 — big values, then count1, then zeros, in both granules
law mp3_count1_lines:
  {Mp3.mp3.lines(D1.fix.frame()) == Some{[
    Dec.Gl{210, D1.ln.of([1, 0, D1.ln.neg(1), 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, D1.ln.neg(1), 1])},
    Dec.Gl{200, D1.ln.of([16, 0, 0, 1, 0, D1.ln.neg(1)])}
  ]} : Maybe<&2, List<&2, Dec.Gl>>}
