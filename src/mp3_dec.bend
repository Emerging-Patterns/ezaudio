# MPEG-1 Layer III decoder: side info, Huffman big values and count1 quadruples,
# requantization, and one frame into the synthesis filterbank. Long blocks with no
# scale-factor bits and no bit reservoir. Layer I and II never reach here.
import Base
import ./mp3_tab.bend as Tab
import ./mp3_enc.bend as Enc
import ./mp3_syn.bend as Syn

def u.nth(xs: List<&2, U32>, +ii: U32) -> U32:
  Enc.u.nth(xs, ii)

def f.word(x: F32) -> U32:
  Enc.f32.word(x)

def se.or(neg: Bool, +w: U32) -> U32:
  match neg:
    case True{}:
      (w .|. 4294901760 : U32)
    case False{}:
      w

def se.u16(+w: U32) -> U32:
  se.or(U32.is_ne((w .&. 32768 : U32), 0), (w .&. 65535 : U32))

def asr.fill(neg: Bool, +v: U32) -> U32:
  match neg:
    case True{}:
      (v .|. 3758096384 : U32)
    case False{}:
      v

def asr.u3(+w: U32) -> U32:
  asr.fill(U32.is_ne((w .&. 2147483648 : U32), 0), (w >> 3n : U32))

# value plus the bits not consumed
type Tk is Data:
  Tk{v: U32, xs: List<&2, U32>}

# read hop bits, most significant first. Past the end the bits read as zero.
def tk.go(hop: Nat, xs: List<&2, U32>, +acc: U32) -> Tk:
  match hop xs:
    case 0n ys:
      Tk{acc, ys}
    case 1n+p Nil{}:
      tk.go(p, [], (acc << 1n : U32))
    case 1n+p +hd <> tl:
      tk.go(p, tl, ((acc << 1n : U32) .|. hd : U32))

def tk.drop(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop xs:
    case 0n ys:
      ys
    case _ Nil{}:
      []
    case 1n+p _hd <> tl:
      tk.drop(p, tl)

def tk.v(t: Tk) -> U32:
  match t:
    case Tk{v, _xs}:
      v

def peek.at(+bits: List<&2, U32>, +n: U32) -> U32:
  tk.v(tk.go(U32.to_nat(n), bits, 0))

def bits.pref(hop: Nat, +w: U32, rest: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      rest
    case 1n++p:
      ((w >> p : U32) .&. 1 : U32) <> bits.pref(p, w, rest)

def bits.of(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      bits.pref(8n, hd, bits.of(tl))

def rd.u(t: Tk) -> U32:
  tk.v(t)

def rd.xs(t: Tk) -> List<&2, U32>:
  match t:
    case Tk{_v, xs}:
      xs

def rd.n(bits: List<&2, U32>, +n: U32) -> Tk:
  tk.go(U32.to_nat(n), bits, 0)

def side.skip(bits: List<&2, U32>, +n: U32) -> List<&2, U32>:
  tk.drop(U32.to_nat(n), bits)

# a read-only table as a balanced binary tree, so a lookup walks its depth, not the list
type Tb is Data:
  TbL{v: U32}
  TbN{lo: Tb, hi: Tb}

def tb.leaves(xs: List<&2, U32>) -> List<&2, Tb>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      TbL{hd} <> tb.leaves(tl)

# join neighbours. An odd last subtree pairs with a zero leaf.
def tb.pairs(xs: List<&2, Tb>) -> List<&2, Tb>:
  match xs:
    case Nil{}:
      []
    case lo <> Nil{}:
      [TbN{lo, TbL{0}}]
    case lo <> hi <> tl:
      TbN{lo, hi} <> tb.pairs(tl)

def tb.up(hop: Nat, xs: List<&2, Tb>) -> List<&2, Tb>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      tb.up(p, tb.pairs(xs))

def tb.root(xs: List<&2, Tb>) -> Tb:
  match xs:
    case Nil{}:
      TbL{0}
    case hd <> _tl:
      hd

# a table of at most 2^depth words, word i at the leaf its depth low bits of i name
def tb.of(+depth: Nat, xs: List<&2, U32>) -> Tb:
  tb.root(tb.up(depth, tb.leaves(xs)))

def tb.pick(up: Bool, lo: Tb, hi: Tb) -> Tb:
  match up:
    case True{}:
      hi
    case False{}:
      lo

def tb.val(node: Tb) -> U32:
  match node:
    case TbL{v}:
      v
    case TbN{_lo, _hi}:
      0

# word ii of a depth-hop table. Past its words a lookup is 0.
def tb.at(hop: Nat, node: Tb, +ii: U32) -> U32:
  match hop:
    case 0n:
      tb.val(node)
    case 1n++p:
      match node:
        case TbL{v}:
          v
        case TbN{lo, hi}:
          tb.at(p, tb.pick(U32.is_eq(((ii >> p : U32) .&. 1 : U32), 1), lo, hi), ii)

# tables shared by every frame: the Huffman codebooks, 4/3 powers, codebook offsets and
# linbits, the two count1 codebooks, and the scale-factor band widths of one rate
type Lib is Data:
  Lib{
    huff: Tb, pow: Tb, ix: List<&2, U32>, lin: List<&2, U32>, c32: List<&2, U32>, c33: List<&2, U32>,
    scf: List<&2, U32>
  }

# drop a prefix of a byte list
def bd.drop(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop xs:
    case 0n ys:
      ys
    case _ Nil{}:
      []
    case 1n+p _hd <> tl:
      bd.drop(p, tl)

# take a prefix of a byte list
def bd.take(hop: Nat, xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match hop xs:
    case 0n _:
      List.reverse(&2, U32, acc)
    case _ Nil{}:
      List.reverse(&2, U32, acc)
    case 1n+p +hd <> tl:
      bd.take(p, tl, hd <> acc)

# scale-factor band row. 44100 is 0, 48000 is 22, 32000 is 44.
def scf.off(+hz: U32) -> U32:
  match hz:
    case 48000:
      22
    case 32000:
      44
    case _:
      0

# the 22 long-block scale-factor band widths, in lines, at one sampling frequency
def scf.row(+hz: U32) -> List<&2, U32>:
  bd.take(22n, bd.drop(U32.to_nat(scf.off(hz)), Tab.tab.scf()), [])

# the tables for one sampling frequency
def lib.of(+hz: U32) -> Lib:
  Lib{tb.of(12n, Tab.tab.huff()), tb.of(8n, Tab.tab.pow()), Tab.tab.ix(), Tab.tab.lin(), Tab.tab.c32(),
    Tab.tab.c33(), scf.row(hz)}

# one granule channel, long blocks only. block 0 is long.
type Gd is Data:
  Gd{
    part: U32, big: U32, gain: U32, comp: U32, t0: U32, t1: U32, t2: U32, r0: U32, r1: U32,
    pre: U32, scale: U32, c1: U32, block: U32
  }

def side.tail(
  +part: U32,
  +big: U32,
  +gain: U32,
  +comp: U32,
  +t0: U32,
  +t1: U32,
  +t2: U32,
  +r0: U32,
  +r1: U32,
  tail: Tk
) -> Gd & List<&2, U32>:
  match tail:
    case Tk{+v, xs}:
      (Gd{part, big, gain, comp, t0, t1, t2, r0, r1, (v >> 2n : U32), ((v >> 1n : U32) .&. 1 : U32),
        (v .&. 1 : U32), 0}, xs)

def side.r1(
  +part: U32,
  +big: U32,
  +gain: U32,
  +comp: U32,
  +tabs: U32,
  +r0: U32,
  +r1: Tk
) -> Gd & List<&2, U32>:
  side.tail(part, big, gain, comp, (tabs >> 10n : U32), ((tabs >> 5n : U32) .&. 31 : U32),
    (tabs .&. 31 : U32), r0, rd.u(r1), rd.n(rd.xs(r1), 3))

def side.r0(
  +part: U32,
  +big: U32,
  +gain: U32,
  +comp: U32,
  +tabs: U32,
  +r0: Tk
) -> Gd & List<&2, U32>:
  side.r1(part, big, gain, comp, tabs, rd.u(r0), rd.n(rd.xs(r0), 3))

def side.long(+part: U32, +big: U32, +gain: U32, +comp: U32, +tabs: Tk) -> Gd & List<&2, U32>:
  side.r0(part, big, gain, comp, rd.u(tabs), rd.n(rd.xs(tabs), 4))

def side.sw(
  longb: Bool,
  +part: U32,
  +big: U32,
  +gain: U32,
  +comp: U32,
  bits: List<&2, U32>
) -> Gd & List<&2, U32>:
  match longb:
    case True{}:
      side.long(part, big, gain, comp, rd.n(bits, 15))
    case False{}:
      (Gd{part, big, gain, comp, 0, 0, 0, 0, 0, 0, 0, 0, 2}, side.skip(bits, 25))

def side.bit(+part: U32, +big: U32, +gain: U32, +comp: U32, +win: Tk) -> Gd & List<&2, U32>:
  side.sw(U32.is_eq(rd.u(win), 0), part, big, gain, comp, rd.xs(win))

def side.comp(+part: U32, +big: U32, +gain: U32, +comp: Tk) -> Gd & List<&2, U32>:
  side.bit(part, big, gain, rd.u(comp), rd.n(rd.xs(comp), 1))

def side.gain(+part: U32, +big: U32, +gain: Tk) -> Gd & List<&2, U32>:
  side.comp(part, big, rd.u(gain), rd.n(rd.xs(gain), 4))

def side.win(part: Tk, +big: Tk) -> Gd & List<&2, U32>:
  side.gain(rd.u(part), rd.u(big), rd.n(rd.xs(big), 8))

# side info for one granule channel. Window switching sets block to 2.
def side.ch(+bits: List<&2, U32>) -> Gd & List<&2, U32>:
  side.win(rd.n(bits, 12), rd.n(tk.drop(12n, bits), 9))

# part2_3_length of one granule channel
def g.part(g: Gd) -> U32:
  match g:
    case Gd{part, _b, _g, _c, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      part

def gd.both(aa: Bool, bb: Bool) -> Bool:
  match aa:
    case False{}:
      False{}
    case True{}:
      bb

def gd.u4(ok: Bool, +big: U32) -> Bool:
  match ok:
    case False{}:
      False{}
    case True{}:
      U32.is_lt(big, 289)

# long block, no scale-factor bits, no preflag or scale, big_values inside the 576 lines
def gd.use(g: Gd) -> Bool:
  match g:
    case Gd{_p, +big, _g, +comp, _t0, _t1, _t2, _r0, _r1, +pre, +sc, _c1, +block}:
      gd.u4(gd.both(gd.both(U32.is_eq(block, 0), U32.is_eq(comp, 0)),
        gd.both(U32.is_eq(pre, 0), U32.is_eq(sc, 0))), big)

# every granule channel is one this decoder reads
def gs.ok(gs: List<&2, Gd>, ok: Bool) -> Bool:
  match gs:
    case Nil{}:
      ok
    case +hd <> tl:
      gs.ok(tl, gd.both(ok, gd.use(hd)))

# the main-data bits every granule channel claims
def gs.bits(gs: List<&2, Gd>, +acc: U32) -> U32:
  match gs:
    case Nil{}:
      acc
    case +hd <> tl:
      gs.bits(tl, (acc + g.part(hd) : U32))

# main_data_begin and the bits after the side-info preamble
type Op is Data:
  Op{begin: U32, bits: List<&2, U32>}

# private bits plus scfsi. mono is 5+4, stereo is 3+8.
def side.priv(+nch: U32) -> U32:
  match nch:
    case 1:
      9
    case _:
      11

def side.op(t: Tk, +nch: U32) -> Op:
  match t:
    case Tk{+v, xs}:
      Op{v, side.skip(xs, side.priv(nch))}

# 9-bit main_data_begin, then the private bits and scfsi
def side.open(bits: List<&2, U32>, +nch: U32) -> Op:
  side.op(rd.n(bits, 9), nch)

# channels read so far
type Sd is Data:
  Sd{bits: List<&2, U32>, acc: List<&2, Gd>}

def side.step2(got: Gd & List<&2, U32>, acc: List<&2, Gd>) -> Sd:
  match got:
    case (g, bits):
      Sd{bits, g <> acc}

def side.step(st: Sd) -> Sd:
  match st:
    case Sd{bits, acc}:
      side.step2(side.ch(bits), acc)

def side.nch(hop: Nat, st: Sd) -> Sd:
  match hop:
    case 0n:
      st
    case 1n+p:
      side.nch(p, side.step(st))

# granule channels, in order, and the main-data bits
type Gs is Data:
  Gs{gs: List<&2, Gd>, bits: List<&2, U32>}

def gs.of(st: Sd) -> Gs:
  match st:
    case Sd{bits, acc}:
      Gs{List.reverse(&2, Gd, acc), bits}

# how many granule channels a frame carries
def fr.n(+nch: U32) -> Nat:
  match nch:
    case 1:
      2n
    case _:
      4n

# side-info bytes. MPEG-1 mono is 17, stereo is 32.
def side.bytes(+nch: U32) -> U32:
  match nch:
    case 1:
      17
    case _:
      32

# Huffman leaf search: more while the leaf still points into the tree, the leaf, how wide
# the next peek is, the bits, and the bits used so far in this granule channel
type Nd is Data:
  Nd{more: Bool, leaf: U32, w: U32, bits: List<&2, U32>, used: U32}

def nd.mk(+leaf: U32, +w: U32, bits: List<&2, U32>, +used: U32) -> Nd:
  Nd{U32.is_ne((leaf .&. 32768 : U32), 0), leaf, w, bits, used}

# the peeked bits are flushed. Index the codebook with the next (leaf & 7) bits.
def hf.down(+leaf: U32, +bits: List<&2, U32>, +used: U32, +base: U32, +huff: Tb) -> Nd:
  nd.mk(tb.at(12n, huff, ((base + peek.at(bits, (leaf .&. 7 : U32)) : U32) - asr.u3(se.u16(leaf)) : U32)),
    (leaf .&. 7 : U32), bits, used)

def hf.go(hop: Nat, st: Nd, +base: U32, +huff: Tb) -> Nd:
  match hop:
    case 0n:
      st
    case 1n+p:
      match st:
        case Nd{more, +leaf, +w, bits, +used}:
          match more:
            case False{}:
              Nd{False{}, leaf, w, bits, used}
            case True{}:
              hf.go(p, hf.down(leaf, side.skip(bits, w), (used + w : U32), base, huff), base, huff)

# one line read: its signed value as a U32, the bits after it, the bits used
type Vr is Data:
  Vr{v: U32, bits: List<&2, U32>, used: U32}

# a line from its magnitude and sign bit, two's complement
def ln.signed(+mag: U32, +sign: U32) -> U32:
  match sign:
    case 0:
      mag
    case _:
      (0 - mag : U32)

def vr.sign(+mag: U32, t: Tk, +used: U32) -> Vr:
  match t:
    case Tk{+sign, xs}:
      Vr{ln.signed(mag, sign), xs, (used + 1 : U32)}

# a zero magnitude has no sign bit
def vr.mag(zero: Bool, +mag: U32, bits: List<&2, U32>, +used: U32) -> Vr:
  match zero:
    case True{}:
      Vr{0, bits, used}
    case False{}:
      vr.sign(mag, rd.n(bits, 1), used)

def vr.esc(+lsb: U32, t: Tk, +lin: U32, +used: U32) -> Vr:
  match t:
    case Tk{+ext, xs}:
      vr.mag(False{}, (lsb + ext : U32), xs, (used + lin : U32))

def vr.read(esc: Bool, +lsb: U32, bits: List<&2, U32>, +lin: U32, +used: U32) -> Vr:
  match esc:
    case True{}:
      vr.esc(lsb, rd.n(bits, lin), lin, used)
    case False{}:
      vr.mag(U32.is_eq(lsb, 0), lsb, bits, used)

# a 15 in a table with linbits is followed by linbits more magnitude bits
def vr.of(+lsb: U32, bits: List<&2, U32>, +lin: U32, +used: U32) -> Vr:
  vr.read(U32.is_ne(lin, 0) && U32.is_eq(lsb, 15), lsb, bits, lin, used)

# two lines from one big-values code
type Pq is Data:
  Pq{x: U32, y: U32, bits: List<&2, U32>, used: U32}

def pq.both(+xv: U32, got: Vr) -> Pq:
  match got:
    case Vr{yv, bits, used}:
      Pq{xv, yv, bits, used}

def pq.y(+leaf: U32, got: Vr, +lin: U32) -> Pq:
  match got:
    case Vr{+x, bits, +used}:
      pq.both(x, vr.of(((leaf >> 4n : U32) .&. 15 : U32), bits, lin, used))

# a terminal leaf: code length in bits 8..14, x in bits 0..3, y in bits 4..7
def pq.leaf(nd: Nd, +lin: U32) -> Pq:
  match nd:
    case Nd{_more, +leaf, _w, bits, +used}:
      pq.y(leaf, vr.of((leaf .&. 15 : U32), side.skip(bits, (leaf >> 8n : U32)), lin,
        (used + (leaf >> 8n : U32) : U32)), lin)

# one big-values pair. base is the codebook's offset in the Huffman table.
def hf.pair(+bits: List<&2, U32>, +used: U32, +base: U32, +lin: U32, +huff: Tb) -> Pq:
  pq.leaf(hf.go(16n, nd.mk(tb.at(12n, huff, (base + peek.at(bits, 5) : U32)), 5, bits, used), base, huff), lin)

# a granule channel's walk: more while count1 may go on, the bits, bits used, the next
# line, and the lines so far, newest first
type Bv is Data:
  Bv{more: Bool, bits: List<&2, U32>, used: U32, at: U32, acc: List<&2, U32>}

# where regions 1 and 2 start, in lines, and each region's codebook offset and linbits
type Rg is Data:
  Rg{b1: U32, b2: U32, o0: U32, l0: U32, o1: U32, l1: U32, o2: U32, l2: U32}

# the widths of the first hop bands, summed
def wd.sum(hop: Nat, xs: List<&2, U32>, +acc: U32) -> U32:
  match hop xs:
    case 0n _:
      acc
    case _ Nil{}:
      acc
    case 1n+p +hd <> tl:
      wd.sum(p, tl, (acc + hd : U32))

# region 0 is r0 + 1 bands, region 1 is r1 + 1 more, region 2 the rest
def rg.of(+t0: U32, +t1: U32, +t2: U32, +r0: U32, +r1: U32, +lib: Lib) -> Rg:
  match lib:
    case Lib{_huff, _pow, +ix, +lin, _c32, _c33, +scf}:
      Rg{wd.sum(U32.to_nat((r0 + 1 : U32)), scf, 0), wd.sum(U32.to_nat(((r0 + r1 : U32) + 2 : U32)), scf, 0),
        u.nth(ix, t0), u.nth(lin, t0), u.nth(ix, t1), u.nth(lin, t1), u.nth(ix, t2), u.nth(lin, t2)}

def rg.reg(lt1: Bool, lt2: Bool) -> U32:
  match lt1:
    case True{}:
      0
    case False{}:
      match lt2:
        case True{}:
          1
        case False{}:
          2

def rg.base(rg: Rg, +reg: U32) -> U32:
  match rg:
    case Rg{_b1, _b2, o0, _l0, o1, _l1, o2, _l2}:
      match reg:
        case 0:
          o0
        case 1:
          o1
        case _:
          o2

def rg.lin(rg: Rg, +reg: U32) -> U32:
  match rg:
    case Rg{_b1, _b2, _o0, l0, _o1, l1, _o2, l2}:
      match reg:
        case 0:
          l0
        case 1:
          l1
        case _:
          l2

def rg.b1(rg: Rg) -> U32:
  match rg:
    case Rg{b1, _b2, _o0, _l0, _o1, _l1, _o2, _l2}:
      b1

def rg.b2(rg: Rg) -> U32:
  match rg:
    case Rg{_b1, b2, _o0, _l0, _o1, _l1, _o2, _l2}:
      b2

def bv.put(got: Pq, +at: U32, acc: List<&2, U32>) -> Bv:
  match got:
    case Pq{x, y, bits, used}:
      Bv{True{}, bits, used, (at + 2 : U32), y <> x <> acc}

def bv.pair(
  +reg: U32,
  bits: List<&2, U32>,
  +used: U32,
  +at: U32,
  acc: List<&2, U32>,
  +rg: Rg,
  +huff: Tb
) -> Bv:
  bv.put(hf.pair(bits, used, rg.base(rg, reg), rg.lin(rg, reg), huff), at, acc)

def bv.step(st: Bv, +rg: Rg, +huff: Tb) -> Bv:
  match st:
    case Bv{_more, bits, +used, +at, acc}:
      bv.pair(rg.reg(U32.is_lt(at, rg.b1(rg)), U32.is_lt(at, rg.b2(rg))), bits, used, at, acc, rg, huff)

def bv.go(hop: Nat, st: Bv, +rg: Rg, +huff: Tb) -> Bv:
  match hop:
    case 0n:
      st
    case 1n+p:
      bv.go(p, bv.step(st, rg, huff), rg, huff)

# four count1 lines: v, w, x, y, then the bits and bits used
type Qd is Data:
  Qd{a: U32, b: U32, c: U32, d: U32, bits: List<&2, U32>, used: U32}

# a count1 value is 0, or 1 with a sign bit
def c1.val(on: Bool, bits: List<&2, U32>, +used: U32) -> Vr:
  match on:
    case False{}:
      Vr{0, bits, used}
    case True{}:
      vr.sign(1, rd.n(bits, 1), used)

def qd.d(+va: U32, +vb: U32, +vc: U32, got: Vr) -> Qd:
  match got:
    case Vr{vd, bits, used}:
      Qd{va, vb, vc, vd, bits, used}

def qd.c(+leaf: U32, +va: U32, +vb: U32, got: Vr) -> Qd:
  match got:
    case Vr{+vc, bits, +used}:
      qd.d(va, vb, vc, c1.val(U32.is_ne((leaf .&. 16 : U32), 0), bits, used))

def qd.b(+leaf: U32, +va: U32, got: Vr) -> Qd:
  match got:
    case Vr{+vb, bits, +used}:
      qd.c(leaf, va, vb, c1.val(U32.is_ne((leaf .&. 32 : U32), 0), bits, used))

def qd.a(+leaf: U32, got: Vr) -> Qd:
  match got:
    case Vr{+va, bits, +used}:
      qd.b(leaf, va, c1.val(U32.is_ne((leaf .&. 64 : U32), 0), bits, used))

# a count1 leaf: code length in bits 0..2, which of v w x y are 1 in bits 7..4
def qd.of(+leaf: U32, bits: List<&2, U32>, +used: U32) -> Qd:
  qd.a(leaf, c1.val(U32.is_ne((leaf .&. 128 : U32), 0), side.skip(bits, (leaf .&. 7 : U32)),
    (used + (leaf .&. 7 : U32) : U32)))

# a leaf without bit 3 points to a second level indexed by (leaf & 3) more bits
def c1.second(done: Bool, +leaf: U32, +bits: List<&2, U32>, +tab: List<&2, U32>) -> U32:
  match done:
    case True{}:
      leaf
    case False{}:
      u.nth(tab, ((leaf >> 3n : U32) + peek.at(tk.drop(4n, bits), (leaf .&. 3 : U32)) : U32))

def c1.leaf(+leaf: U32, +bits: List<&2, U32>, +tab: List<&2, U32>) -> U32:
  c1.second(U32.is_ne((leaf .&. 8 : U32), 0), leaf, bits, tab)

# one count1 quadruple, Huffman table A (minimp3 tab32) or B (tab33)
def qd.read(+bits: List<&2, U32>, +used: U32, +tab: List<&2, U32>) -> Qd:
  qd.of(c1.leaf(u.nth(tab, peek.at(bits, 4)), bits, tab), bits, used)

def c1.more(+used: U32, +part: U32, +at: U32) -> Bool:
  U32.is_lt(used, part) && U32.is_le(at, 572)

# a quadruple that runs past part2_3_length is discarded and ends the region
def c1.keep(over: Bool, got: Qd, bits: List<&2, U32>, +used: U32, +at: U32, acc: List<&2, U32>, +part: U32) -> Bv:
  match over:
    case True{}:
      Bv{False{}, bits, used, at, acc}
    case False{}:
      match got:
        case Qd{a, b, c, d, qbits, +qused}:
          Bv{c1.more(qused, part, (at + 4 : U32)), qbits, qused, (at + 4 : U32), d <> c <> b <> a <> acc}

def c1.used(got: Qd) -> U32:
  match got:
    case Qd{_a, _b, _c, _d, _bits, used}:
      used

def c1.step(+got: Qd, bits: List<&2, U32>, +used: U32, +at: U32, acc: List<&2, U32>, +part: U32) -> Bv:
  c1.keep(U32.is_lt(part, c1.used(got)), got, bits, used, at, acc, part)

def c1.go(hop: Nat, st: Bv, +part: U32, +tab: List<&2, U32>) -> Bv:
  match hop:
    case 0n:
      st
    case 1n+p:
      match st:
        case Bv{more, +bits, +used, +at, acc}:
          match more:
            case False{}:
              Bv{False{}, bits, used, at, acc}
            case True{}:
              c1.go(p, c1.step(qd.read(bits, used, tab), bits, used, at, acc, part), part, tab)

# a granule channel's quantized lines and its global_gain
type Gl is Data:
  Gl{gain: U32, lines: List<&2, U32>}

# reverse the lines read onto the zeros that fill the granule to 576
def ln.onto(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case +hd <> tl:
      ln.onto(tl, hd <> acc)

def gc.lines(st: Bv) -> List<&2, U32>:
  match st:
    case Bv{_more, _bits, _used, +at, acc}:
      ln.onto(acc, List.replicate(U32, U32.to_nat((576 - at : U32)), 0))

def gc.tab(+lib: Lib, +c1: U32) -> List<&2, U32>:
  match lib:
    case Lib{_huff, _pow, _ix, _lin, c32, c33, _scf}:
      match c1:
        case 0:
          c32
        case _:
          c33

def gc.out(over: Bool, +gain: U32, st: Bv) -> Maybe<&2, Gl>:
  match over:
    case True{}:
      None{}
    case False{}:
      Some{Gl{gain, gc.lines(st)}}

# count1 runs from the end of big values while bits are left and line 572 is not passed
def gc.c1(st: Bv, +gain: U32, +part: U32, +tab: List<&2, U32>) -> Maybe<&2, Gl>:
  match st:
    case Bv{_more, bits, +used, +at, acc}:
      gc.out(U32.is_lt(part, used), gain,
        c1.go(144n, Bv{c1.more(used, part, at), bits, used, at, acc}, part, tab))

def lib.huff(lib: Lib) -> Tb:
  match lib:
    case Lib{huff, _pow, _ix, _lin, _c32, _c33, _scf}:
      huff

def lib.pow(lib: Lib) -> Tb:
  match lib:
    case Lib{_huff, pow, _ix, _lin, _c32, _c33, _scf}:
      pow

# one granule channel: big values, then count1. none when big values read past part2_3_length.
def gc.read(g: Gd, bits: List<&2, U32>, +lib: Lib) -> Maybe<&2, Gl>:
  match g:
    case Gd{+part, +big, +gain, _comp, +t0, +t1, +t2, +r0, +r1, _pre, _sc, +c1, _block}:
      gc.c1(bv.go(U32.to_nat(big), Bv{True{}, bits, 0, 0, []}, rg.of(t0, t1, t2, r0, r1, lib), lib.huff(lib)),
        gain, part, gc.tab(lib, c1))

def gl.add(acc: Maybe<&2, List<&2, Gl>>, got: Maybe<&2, Gl>) -> Maybe<&2, List<&2, Gl>>:
  match acc:
    case None{}:
      None{}
    case Some{xs}:
      match got:
        case None{}:
          None{}
        case Some{gl}:
          Some{gl <> xs}

def gl.rev(got: Maybe<&2, List<&2, Gl>>) -> Maybe<&2, List<&2, Gl>>:
  match got:
    case None{}:
      None{}
    case Some{xs}:
      Some{List.reverse(&2, Gl, xs)}

# each granule channel starts part2_3_length bits after the one before
def gl.go(gs: List<&2, Gd>, +bits: List<&2, U32>, +lib: Lib, acc: Maybe<&2, List<&2, Gl>>) -> Maybe<&2, List<&2, Gl>>:
  match gs:
    case Nil{}:
      gl.rev(acc)
    case +hd <> tl:
      gl.go(tl, side.skip(bits, g.part(hd)), lib, gl.add(acc, gc.read(hd, bits, lib)))

def gl.when(ok: Bool, +gs: List<&2, Gd>, bits: List<&2, U32>, +lib: Lib) -> Maybe<&2, List<&2, Gl>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      gl.go(gs, bits, lib, Some{[]})

def gl.side(gg: Gs, +begin: U32, +avail: U32, +lib: Lib) -> Maybe<&2, List<&2, Gl>>:
  match gg:
    case Gs{+gs, bits}:
      gl.when(gd.both(gd.both(U32.is_eq(begin, 0), gs.ok(gs, True{})), U32.is_le(gs.bits(gs, 0), avail)), gs, bits,
        lib)

def gl.open(op: Op, +nch: U32, +avail: U32, +lib: Lib) -> Maybe<&2, List<&2, Gl>>:
  match op:
    case Op{+begin, bits}:
      gl.side(gs.of(side.nch(fr.n(nch), Sd{bits, []})), begin, avail, lib)

# main-data bits after the header, the CRC, and the side info
def gl.avail(+size: U32, +nch: U32, +crc: U32) -> U32:
  ((((size - 4 : U32) - (2 * crc : U32) : U32) - side.bytes(nch) : U32) * 8 : U32)

# every granule channel's lines, in bitstream order, or none when the frame holds what this
# decoder does not read: a bit reservoir, window switching, scale-factor bits, preflag,
# scale-factor scale, more than 288 big values, main data past the frame, or big values
# past part2_3_length. crc 1 means 16 CRC bits follow the header.
def dec.gls(+frame: List<&2, U32>, +nch: U32, +crc: U32, +lib: Lib) -> Maybe<&2, List<&2, Gl>>:
  gl.open(side.open(side.skip(bits.of(frame), (32 + (16 * crc : U32) : U32)), nch), nch,
    gl.avail(U32.from_nat(List.length(&2, U32, frame)), nch, crc), lib)

def pw.f(+low: U32, +sign: U32, +x: U32) -> F32:
  ((U32.to_f32(low) - U32.to_f32(sign) : F32) /
    (U32.to_f32((x .&. 4294967232 : U32)) + U32.to_f32(sign) : F32) : F32)

def pw.poly(+low: U32, +sign: U32, +x: U32) -> F32:
  (1.0 + (pw.f(low, sign, x) * ((4.0 / 3.0 : F32) + (pw.f(low, sign, x) * (2.0 / 9.0 : F32) : F32) : F32) : F32) : F32)

def pw.at(+pows: Tb, +ii: U32) -> F32:
  Enc.f32.bits(tb.at(8n, pows, ii))

def pw.out(+x: U32, +low: U32, +idx: U32, +sign: U32, +pows: Tb, +mult: F32) -> F32:
  ((pw.at(pows, (16 + idx : U32)) * pw.poly(low, sign, x) : F32) * mult : F32)

def pw.apply(+x: U32, +pows: Tb, +mult: F32) -> F32:
  pw.out(x, (x .&. 63 : U32), (((x + ((2 * x : U32) .&. 64 : U32) : U32) >> 6n : U32)),
    ((2 * x : U32) .&. 64 : U32), pows, mult)

def pw.shift(mid: Bool, +x: U32) -> U32:
  match mid:
    case True{}:
      (x << 3n : U32)
    case False{}:
      x

def pw.mult(mid: Bool) -> F32:
  match mid:
    case True{}:
      16.0
    case False{}:
      256.0

def pw.mul(+mid: Bool, +x: U32, +pows: Tb) -> F32:
  pw.apply(pw.shift(mid, x), pows, pw.mult(mid))

def pw.pick(small: Bool, +x: U32, +pows: Tb) -> F32:
  match small:
    case True{}:
      pw.at(pows, (16 + x : U32))
    case False{}:
      pw.mul(U32.is_lt(x, 1024), x, pows)

# |x| ^ (4/3), minimp3's table below 129 and its polynomial above
def pw.of(+x: U32, +pows: Tb) -> F32:
  pw.pick(U32.is_lt(x, 129), x, pows)

def rq.neg(neg: Bool, +line: U32, +gain: F32, +pows: Tb) -> F32:
  match neg:
    case True{}:
      F32.neg((pw.of((0 - line : U32), pows) * gain : F32))
    case False{}:
      (pw.of(line, pows) * gain : F32)

def rq.zero(zero: Bool, +line: U32, +gain: F32, +pows: Tb) -> F32:
  match zero:
    case True{}:
      0.0
    case False{}:
      rq.neg(U32.is_ne((line .&. 2147483648 : U32), 0), line, gain, pows)

# requantize lines with one gain, pushed onto acc, newest first
def rq.push(xs: List<&2, U32>, +gain: F32, +pows: Tb, acc: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      acc
    case +hd <> tl:
      rq.push(tl, gain, pows, rq.zero(U32.is_eq(hd, 0), hd, gain, pows) <> acc)

# a granule's spectrum, channel after channel, and the granule channels after it
type Gp is Data:
  Gp{spec: List<&2, F32>, rest: List<&2, Gl>}

def gl.push(gl: Gl, +pows: Tb, acc: List<&2, F32>) -> List<&2, F32>:
  match gl:
    case Gl{+gain, lines}:
      rq.push(lines, Enc.gain.of(gain), pows, acc)

def gp.go(hop: Nat, gls: List<&2, Gl>, +pows: Tb, acc: List<&2, F32>) -> Gp:
  match hop gls:
    case 0n ys:
      Gp{List.reverse(&2, F32, acc), ys}
    case _ Nil{}:
      Gp{List.reverse(&2, F32, acc), []}
    case 1n+p hd <> tl:
      gp.go(p, tl, pows, gl.push(hd, pows, acc))

def ls.hd(xs: List<&2, F32>) -> F32:
  match xs:
    case Nil{}:
      0.0
    case hd <> _tl:
      hd

def ls.tl(xs: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      []
    case _hd <> tl:
      tl

# push exactly hop PCM words, newest first. The count, not the list, sets the length.
def pcm.push(hop: Nat, +xs: List<&2, F32>, acc: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      acc
    case 1n+p:
      pcm.push(p, ls.tl(xs), f.word(ls.hd(xs)) <> acc)

# decoder state: rate, channels, overlap, polyphase delay, 1 while both are still zero,
# the tables, and the PCM words so far, newest first
type St is Data:
  St{
    hz: U32, ch: U32, ov: List<&2, F32>, qmf: List<&2, F32>, fresh: U32, lib: Lib,
    acc: List<&2, U32>
  }

# zero overlap for one or two channels
def dec.ov(+nch: U32) -> List<&2, F32>:
  match nch:
    case 1:
      Syn.syn.zov()
    case _:
      List.append(&2, F32, Syn.syn.zov(), Syn.syn.zov())

# a decoder before its first frame
def st.fresh(+hz: U32, +nch: U32) -> St:
  St{hz, nch, dec.ov(nch), Syn.syn.zqmf(), 1, lib.of(hz), []}

def pc.pcm(pc: Syn.Pc) -> List<&2, F32>:
  match pc:
    case Syn.Pc{pcm, _ov, _qmf}:
      pcm

def pc.ov(pc: Syn.Pc) -> List<&2, F32>:
  match pc:
    case Syn.Pc{_pcm, ov, _qmf}:
      ov

def pc.qmf(pc: Syn.Pc) -> List<&2, F32>:
  match pc:
    case Syn.Pc{_pcm, _ov, qmf}:
      qmf

# the granule's PCM is read through projections, so its count never waits on the filterbank
def st.gran(
  +pc: Syn.Pc,
  +hz: U32,
  +nch: U32,
  +lib: Lib,
  acc: List<&2, U32>
) -> St:
  St{hz, nch, pc.ov(pc), pc.qmf(pc), 0, lib, pcm.push(U32.to_nat((576 * nch : U32)), pc.pcm(pc), acc)}

# one granule through the filterbank: the granule channels it takes, then synthesis
def st.syn(gp: Gp, st: St) -> St & List<&2, Gl>:
  match gp:
    case Gp{+spec, rest}:
      match st:
        case St{+hz, +nch, +ov, +qmf, _fresh, +lib, acc}:
          (st.gran(Syn.syn.gran(spec, ov, qmf, nch), hz, nch, lib, acc), rest)

def st.lib(st: St) -> Lib:
  match st:
    case St{_hz, _nch, _ov, _qmf, _fresh, lib, _acc}:
      lib

def st.nch(st: St) -> U32:
  match st:
    case St{_hz, nch, _ov, _qmf, _fresh, _lib, _acc}:
      nch

def st.one(+st: St, gls: List<&2, Gl>) -> St & List<&2, Gl>:
  st.syn(gp.go(U32.to_nat(st.nch(st)), gls, lib.pow(st.lib(st)), []), st)

def st.first(got: St & List<&2, Gl>) -> St:
  match got:
    case (st, _rest):
      st

# granule 1 after granule 0
def st.two(got: St & List<&2, Gl>) -> St:
  match got:
    case (+st, gls):
      st.first(st.one(st, gls))

def st.live(got: Maybe<&2, List<&2, Gl>>, +st: St) -> Maybe<&2, St>:
  match got:
    case None{}:
      None{}
    case Some{gls}:
      Some{st.two(st.one(st, gls))}

# payload after the 4-byte header is entirely zero
def pay.z(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case 0 <> tl:
      pay.z(tl)
    case _ <> _tl:
      False{}

def zz.push(hop: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      acc
    case 1n+p:
      zz.push(p, 0 <> acc)

# a silent frame on a decoder whose overlap and delay are still zero is 1152 zeros a channel
def st.quiet(st: St) -> St:
  match st:
    case St{hz, +nch, ov, qmf, fresh, lib, acc}:
      St{hz, nch, ov, qmf, fresh, lib, zz.push(U32.to_nat((1152 * nch : U32)), acc)}

def st.fr(st: St) -> U32:
  match st:
    case St{_hz, _nch, _ov, _qmf, fresh, _lib, _acc}:
      fresh

def dec.alt(silent: Bool, +frame: List<&2, U32>, +crc: U32, +st: St) -> Maybe<&2, St>:
  match silent:
    case True{}:
      Some{st.quiet(st)}
    case False{}:
      st.live(dec.gls(frame, st.nch(st), crc, st.lib(st)), st)

# one MPEG-1 Layer III frame whose header the caller has checked. A silent frame on a fresh
# decoder skips the filterbank: zero spectra on zero state synthesize to zeros.
def dec.frame(ok: Bool, +frame: List<&2, U32>, +crc: U32, +st: St) -> Maybe<&2, St>:
  match ok:
    case False{}:
      None{}
    case True{}:
      dec.alt(gd.both(U32.is_eq(st.fr(st), 1), pay.z(bd.drop(4n, frame))), frame, crc, st)
