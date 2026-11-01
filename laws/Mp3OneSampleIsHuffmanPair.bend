# ISO/IEC 11172-3: one mono signed-16 sample of magnitude 1 encodes as
# `FF FB E0 C4` and 1044 bytes. Its first granule is a long block,
# `big_values` 1, `global_gain` 0, `part2_3_length` 4, Huffman table 13; the
# second granule's `big_values` is 0. Decoding that frame returns the
# Huffman pair as the first two words (1, then 0) and 1150 zeros. That is
# the pair, not the synthesis filterbank
import Base
import ../main.bend as Au
import ../src/mp3_dec.bend as Dec
import ./defs/ByteLists.bend as D1

# Huffman magnitudes of the one-sample pair, then the rest of the granule pair
def pcm.pair() -> List<&2, U32>:
  List.append(&2, U32, [1, 0], D1.pcm.z(1150))

def bytes.main(xs: List<&2, U32>) -> List<&2, U32>:
  Dec.side.skip(Dec.bits.of(xs), ((32 + 18 : U32)))

def gran.g0(xs: List<&2, U32>) -> Dec.Gd:
  Dec.side.gd(Dec.side.ch(bytes.main(xs)))

def gran.g1(xs: List<&2, U32>) -> Dec.Gd:
  Dec.side.gd(Dec.side.ch(Dec.side.pair(Dec.side.ch(bytes.main(xs)))))

def pair.bytes() -> List<&2, U32>:
  D1.bytes.of(Au.encode_mp3(Au.clip(44100, 1, Au.s16(), [1])))

def gd.big(g: Dec.Gd) -> U32:
  match g:
    case Dec.Gd{_part, big, _gain, _comp, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      big

def gd.gain(g: Dec.Gd) -> U32:
  match g:
    case Dec.Gd{_part, _big, gain, _comp, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      gain

def gd.part(g: Dec.Gd) -> U32:
  match g:
    case Dec.Gd{part, _big, _gain, _comp, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      part

def gd.block(g: Dec.Gd) -> U32:
  match g:
    case Dec.Gd{_part, _big, _gain, _comp, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, block}:
      block

def gd.tab(g: Dec.Gd) -> U32:
  match g:
    case Dec.Gd{_part, _big, _gain, _comp, t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      t0

# One Enc.enc.run for the Huffman-pair fixture: header, length, side info, decode.
# Separate laws each re-normalized pair.bytes() and dominated `ez test` wall time.
def pair.probe() -> List<&2, U32> & U32 & U32 & U32 & U32 & U32 & U32 & U32 & Maybe<&2, Au.Clip>:
  +xs = pair.bytes()
  +g0 = gran.g0(xs)
  +g1 = gran.g1(xs)
  (List.take(&2, U32, xs, 4n), U32.from_nat(List.length(&2, U32, xs)), gd.big(g0),
    gd.gain(g0), gd.part(g0), gd.block(g0), gd.tab(g0), gd.big(g1), Au.decode_mp3(xs))

# LAW: ISO/IEC 11172-3 — one s16 sample of magnitude 1: FF FB E0 C4, 1044 bytes,
# granule0 big_values=1 global_gain=0 part2_3_length=4 long block table 13,
# granule1 big_values=0, decode yields the Huffman pair then zeros.
law mp3_pair:
  {pair.probe()
    == ([255, 251, 224, 196], 1044, 1, 0, 4, 0, 13, 0,
      Some{Au.clip(44100, 1, Au.f32(), pcm.pair())})
    : List<&2, U32> & U32 & U32 & U32 & U32 & U32 & U32 & U32 & Maybe<&2, Au.Clip>}
