# MPEG-1 Layer III decoder. Long blocks, no bit reservoir. Layer I and II never reach here.
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

def tk.go(hop: Nat, xs: List<&2, U32>, +acc: U32) -> Tk:
  match hop xs:
    case 0n ys:
      Tk{acc, ys}
    case _ Nil{}:
      Tk{acc, []}
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

# taken bits, in order, and the tail
type Bt is Data:
  Bt{got: List<&2, U32>, rest: List<&2, U32>}

def bt.go(hop: Nat, xs: List<&2, U32>, acc: List<&2, U32>) -> Bt:
  match hop xs:
    case 0n ys:
      Bt{List.reverse(&2, U32, acc), ys}
    case _ Nil{}:
      Bt{List.reverse(&2, U32, acc), []}
    case 1n+p +hd <> tl:
      bt.go(p, tl, hd <> acc)

def bt.skip(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  tk.drop(hop, xs)

# one granule channel, long blocks only. block 0 is long.
type Gd is Data:
  Gd{
    part: U32, big: U32, gain: U32, comp: U32, t0: U32, t1: U32, t2: U32, r0: U32, r1: U32,
    pre: U32, scale: U32, c1: U32, block: U32
  }

def gd.long(g: Gd) -> Bool:
  match g:
    case Gd{_p, _b, _g, _c, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, block}:
      U32.is_eq(block, 0)

# tables shared by a frame
type Lib is Data:
  Lib{huff: List<&2, U32>, ix: List<&2, U32>, lin: List<&2, U32>, pow: List<&2, U32>, scf: List<&2, U32>}

def lib.of() -> Lib:
  Lib{Tab.tab.huff(), Tab.tab.ix(), Tab.tab.lin(), Tab.tab.pow(), Tab.tab.scf()}

def lib.huff(l: Lib) -> List<&2, U32>:
  match l:
    case Lib{h, _i, _n, _p, _s}:
      h

def lib.ix(l: Lib) -> List<&2, U32>:
  match l:
    case Lib{_h, i, _n, _p, _s}:
      i

def lib.lin(l: Lib) -> List<&2, U32>:
  match l:
    case Lib{_h, _i, n, _p, _s}:
      n

def lib.pow(l: Lib) -> List<&2, U32>:
  match l:
    case Lib{_h, _i, _n, p, _s}:
      p

def rd.u(t: Tk) -> U32:
  tk.v(t)

def rd.xs(t: Tk) -> List<&2, U32>:
  match t:
    case Tk{_v, xs}:
      xs

def rd.n(bits: List<&2, U32>, +n: U32) -> Tk:
  tk.go(U32.to_nat(n), bits, 0)

def side.skip(bits: List<&2, U32>, +n: U32) -> List<&2, U32>:
  bt.skip(U32.to_nat(n), bits)

def side.tail(
  +part: U32, +big: U32, +gain: U32, +comp: U32, +t0: U32, +t1: U32, +t2: U32, +r0: U32, +r1: U32,
  tail: Tk
) -> Gd & List<&2, U32>:
  match tail:
    case Tk{+v, xs}:
      (Gd{part, big, gain, comp, t0, t1, t2, r0, r1, (v >> 2n : U32), ((v >> 1n : U32) .&. 1 : U32),
        (v .&. 1 : U32), 0}, xs)

def side.r1(
  +part: U32, +big: U32, +gain: U32, +comp: U32, +tabs: U32, +r0: U32, +r1: Tk
) -> Gd & List<&2, U32>:
  side.tail(part, big, gain, comp, (tabs >> 10n : U32), ((tabs >> 5n : U32) .&. 31 : U32),
    (tabs .&. 31 : U32), r0, rd.u(r1), rd.n(rd.xs(r1), 3))

def side.r0(
  +part: U32, +big: U32, +gain: U32, +comp: U32, +tabs: U32, +r0: Tk
) -> Gd & List<&2, U32>:
  side.r1(part, big, gain, comp, tabs, rd.u(r0), rd.n(rd.xs(r0), 3))

def side.long(+part: U32, +big: U32, +gain: U32, +comp: U32, +tabs: Tk) -> Gd & List<&2, U32>:
  side.r0(part, big, gain, comp, rd.u(tabs), rd.n(rd.xs(tabs), 4))

def side.sw(
  longb: Bool, +part: U32, +big: U32, +gain: U32, +comp: U32, bits: List<&2, U32>
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

# side info for one granule channel. Short blocks set block to 2.
def side.ch(+bits: List<&2, U32>) -> Gd & List<&2, U32>:
  side.win(rd.n(bits, 12), rd.n(bt.skip(12n, bits), 9))

def side.pair(got: Gd & List<&2, U32>) -> List<&2, U32>:
  match got:
    case (_g, xs):
      xs

def side.gd(got: Gd & List<&2, U32>) -> Gd:
  match got:
    case (g, _xs):
      g

# Huffman node: leaf still packed, bits not yet flushed. done is 1 once the leaf is terminal.
type Nd is Data:
  Nd{leaf: U32, bits: List<&2, U32>, w: U32, done: U32}

def hf.idx(+book: U32, +pk: U32, +leaf: U32) -> U32:
  (book + (pk - asr.u3(se.u16(leaf)) : U32) : U32)

def hf.hold(+leaf: U32, bits: List<&2, U32>, +w: U32) -> Nd:
  Nd{leaf, bits, w, 1}

def hf.dive(+leaf: U32, +bits: List<&2, U32>, +w: U32, +book: U32, +huff: List<&2, U32>) -> Nd:
  Nd{u.nth(huff, hf.idx(book, peek.at(tk.drop(U32.to_nat(w), bits), (leaf .&. 7 : U32)), leaf)),
    tk.drop(U32.to_nat(w), bits), (leaf .&. 7 : U32), 0}

def hf.next(stop: Bool, +leaf: U32, +bits: List<&2, U32>, +w: U32, +book: U32, +huff: List<&2, U32>) -> Nd:
  match stop:
    case True{}:
      hf.hold(leaf, bits, w)
    case False{}:
      hf.dive(leaf, bits, w, book, huff)

def hf.step(st: Nd, +book: U32, +huff: List<&2, U32>) -> Nd:
  match st:
    case Nd{+leaf, +bits, +w, +done}:
      hf.next(U32.is_eq(done, 1) || U32.is_eq((leaf .&. 32768 : U32), 0), leaf, bits, w, book, huff)

def hf.node(hop: Nat, st: Nd, +book: U32, +huff: List<&2, U32>) -> Nd:
  match hop:
    case 0n:
      st
    case 1n+p:
      hf.node(p, hf.step(st, book, huff), book, huff)

def hf.open(+bits: List<&2, U32>, +book: U32, +huff: List<&2, U32>) -> Nd:
  hf.node(8n, Nd{u.nth(huff, (book + peek.at(bits, 5) : U32)), bits, 5, 0}, book, huff)

def pw.f(+low: U32, +sign: U32, +x: U32) -> F32:
  ((U32.to_f32(low) - U32.to_f32(sign) : F32) /
    (U32.to_f32((x .&. 4294967232 : U32)) + U32.to_f32(sign) : F32) : F32)

def pw.poly(+low: U32, +sign: U32, +x: U32) -> F32:
  (1.0 + (pw.f(low, sign, x) * ((4.0 / 3.0 : F32) + (pw.f(low, sign, x) * (2.0 / 9.0 : F32) : F32) : F32) : F32) : F32)

def pw.out(
  +x: U32, +low: U32, +idx: U32, +sign: U32, +pows: List<&2, U32>, +mult: F32
) -> F32:
  ((Enc.f32.bits(u.nth(pows, (16 + idx : U32))) * pw.poly(low, sign, x) : F32) * mult : F32)

def pw.apply(+x: U32, +pows: List<&2, U32>, +mult: F32) -> F32:
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

def pw.mul(+mid: Bool, +x: U32, +pows: List<&2, U32>) -> F32:
  pw.apply(pw.shift(mid, x), pows, pw.mult(mid))

def pw.wide(mid: Bool, +x: U32, +pows: List<&2, U32>) -> F32:
  pw.mul(mid, x, pows)

def pw.pick(small: Bool, +x: U32, +pows: List<&2, U32>) -> F32:
  match small:
    case True{}:
      Enc.f32.bits(u.nth(pows, (16 + x : U32)))
    case False{}:
      pw.wide(U32.is_lt(x, 1024), x, pows)

def pw.of(+x: U32, +pows: List<&2, U32>) -> F32:
  pw.pick(U32.is_lt(x, 129), x, pows)

def pw.tab(+lsb: U32, +sgn: U32, +pows: List<&2, U32>) -> F32:
  Enc.f32.bits(u.nth(pows, ((16 + lsb : U32) - (sgn * 16 : U32) : U32)))

# one decoded sample and the bits after it. leaf is the remaining nibble.
type Sm is Data:
  Sm{v: F32, bits: List<&2, U32>, leaf: U32}

def sm.sgn(+t: Tk, +lsb: U32, +gain: F32, +pows: List<&2, U32>) -> Sm:
  Sm{(pw.tab(lsb, rd.u(t), pows) * gain : F32), rd.xs(t), 0}

def sm.plain(
  zero: Bool, bits: List<&2, U32>, +lsb: U32, +gain: F32, +pows: List<&2, U32>
) -> Sm:
  match zero:
    case True{}:
      Sm{0.0, bits, 0}
    case False{}:
      sm.sgn(rd.n(bits, 1), lsb, gain, pows)

def sm.neg2(neg: Bool, +mag: U32, +gain: F32, +pows: List<&2, U32>, bits: List<&2, U32>) -> Sm:
  match neg:
    case True{}:
      Sm{F32.neg((pw.of(mag, pows) * gain : F32)), bits, 0}
    case False{}:
      Sm{(pw.of(mag, pows) * gain : F32), bits, 0}

def sm.neg(+t: Tk, +mag: U32, +gain: F32, +pows: List<&2, U32>) -> Sm:
  sm.neg2(U32.is_eq(rd.u(t), 1), mag, gain, pows, rd.xs(t))

def sm.extra(+t: Tk, +lsb: U32, +gain: F32, +pows: List<&2, U32>) -> Sm:
  sm.neg(rd.n(rd.xs(t), 1), (lsb + rd.u(t) : U32), gain, pows)

def sm.lin(use: Bool, bits: List<&2, U32>, +lin: U32, +lsb: U32, +gain: F32, +pows: List<&2, U32>) -> Sm:
  match use:
    case False{}:
      sm.plain(U32.is_eq(lsb, 0), bits, lsb, gain, pows)
    case True{}:
      sm.extra(rd.n(bits, lin), lsb, gain, pows)

def hf.sym(bits: List<&2, U32>, +leaf: U32, +lin: U32, +gain: F32, +pows: List<&2, U32>) -> Sm:
  sm.lin(U32.is_ne(lin, 0) && U32.is_eq((leaf .&. 15 : U32), 15), bits, lin, (leaf .&. 15 : U32), gain, pows)

def hf.shift(+leaf: U32) -> U32:
  ((leaf .&. 65535 : U32) >> 4n : U32)

# two samples from one Huffman code
type Pr is Data:
  Pr{a: F32, b: F32, bits: List<&2, U32>}

def hf.both(+a: F32, s: Sm) -> Pr:
  match s:
    case Sm{b, bits, _leaf}:
      Pr{a, b, bits}

def hf.second(+leaf: U32, s: Sm, +lin: U32, +gain: F32, +pows: List<&2, U32>) -> Pr:
  match s:
    case Sm{+a, bits, _drop}:
      hf.both(a, hf.sym(bits, hf.shift(leaf), lin, gain, pows))

def hf.rest(+leaf: U32, t: Tk, +lin: U32, +gain: F32, +pows: List<&2, U32>) -> Pr:
  hf.second(leaf, hf.sym(rd.xs(t), leaf, lin, gain, pows), lin, gain, pows)

def hf.code(nd: Nd, +lin: U32, +gain: F32, +pows: List<&2, U32>) -> Pr:
  match nd:
    case Nd{+leaf, bits, _w, _done}:
      hf.rest(leaf, tk.go(U32.to_nat(((leaf .&. 65535 : U32) >> 8n : U32)), bits, 0), lin, gain, pows)

def hf.pair(
  bits: List<&2, U32>, +tab: U32, +lin: U32, +gain: F32, +huff: List<&2, U32>, +ixs: List<&2, U32>,
  +pows: List<&2, U32>
) -> Pr:
  hf.code(hf.open(bits, u.nth(ixs, tab), huff), lin, gain, pows)

def dec.s0(p: Pr) -> F32:
  match p:
    case Pr{a, _b, _bits}:
      a

def hf.from(lib: Lib, bits: List<&2, U32>, +t0: U32, +gain: F32) -> Pr:
  match lib:
    case Lib{+huff, +ix, +lin, +pow, _scf}:
      hf.pair(bits, t0, u.nth(lin, t0), gain, huff, ix, pow)

def dec.when(ok: Bool, +t0: U32, +gain: U32, bits: List<&2, U32>, lib: Lib) -> F32:
  match ok:
    case False{}:
      0.0
    case True{}:
      dec.s0(hf.from(lib, bits, t0, Enc.gain.of(gain)))

def dec.use(g: Gd, bits: List<&2, U32>, lib: Lib) -> F32:
  match g:
    case Gd{_part, +big, +gain, +comp, +t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, +block}:
      dec.when(U32.is_eq(block, 0) && U32.is_eq(comp, 0) && U32.is_ne(big, 0), t0, gain,
        side.skip(bits, 59), lib)

def dec.gd(got: Gd & List<&2, U32>, lib: Lib) -> F32:
  match got:
    case (g, bits):
      dec.use(g, bits, lib)

def dec.top(bits: List<&2, U32>, lib: Lib) -> F32:
  dec.gd(side.ch(side.skip(bits, (32 + 18 : U32))), lib)

# first spectral sample of granule 0, for a single mono frame. 0 when the frame is not long-block.
def dec.lead(xs: List<&2, U32>) -> U32:
  f.word(dec.top(bits.of(xs), lib.of()))

# spectrum walker: pairs left in this band, region, bands still to come in the region
type Hs is Data:
  Hs{
    bits: List<&2, U32>, spec: List<&2, F32>, at: U32, band: U32, left: U32, reg: U32, cnt: U32
  }

def hs.w(+band: U32, +scf: List<&2, U32>) -> U32:
  U32.div(u.nth(scf, band), 2)

def g.t0(g: Gd) -> U32:
  match g:
    case Gd{_p, _b, _g, _c, t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      t0

def g.t1(g: Gd) -> U32:
  match g:
    case Gd{_p, _b, _g, _c, _t0, t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      t1

def g.t2(g: Gd) -> U32:
  match g:
    case Gd{_p, _b, _g, _c, _t0, _t1, t2, _r0, _r1, _pre, _sc, _c1, _block}:
      t2

def g.r0(g: Gd) -> U32:
  match g:
    case Gd{_p, _b, _g, _c, _t0, _t1, _t2, r0, _r1, _pre, _sc, _c1, _block}:
      r0

def g.r1(g: Gd) -> U32:
  match g:
    case Gd{_p, _b, _g, _c, _t0, _t1, _t2, _r0, r1, _pre, _sc, _c1, _block}:
      r1

def hs.tab(+reg: U32, +g: Gd) -> U32:
  match reg:
    case 0:
      g.t0(g)
    case 1:
      g.t1(g)
    case _:
      g.t2(g)

def hs.put(spec: List<&2, F32>, +at: U32, +a: F32, +b: F32) -> List<&2, F32>:
  Enc.f.put(Enc.f.put(spec, at, a), (at + 1 : U32), b)

def hs.open(
  reg: U32,
  bits: List<&2, U32>,
  spec: List<&2, F32>,
  +at: U32,
  +band: U32,
  +cnt: U32,
  +scf: List<&2, U32>
) -> Hs:
  Hs{bits, spec, at, band, hs.w(band, scf), reg, cnt}

def hs.flip(
  +reg: U32, bits: List<&2, U32>, spec: List<&2, F32>, +at: U32, +band: U32, +g: Gd,
  +scf: List<&2, U32>
) -> Hs:
  match reg:
    case 0:
      hs.open(1, bits, spec, at, band, g.r1(g), scf)
    case _:
      hs.open(2, bits, spec, at, band, 22, scf)

def hs.region(
  endr: Bool, bits: List<&2, U32>, spec: List<&2, F32>, +at: U32, +band: U32, +reg: U32, +cnt: U32,
  +g: Gd, +scf: List<&2, U32>
) -> Hs:
  match endr:
    case False{}:
      hs.open(reg, bits, spec, at, band, (cnt - 1 : U32), scf)
    case True{}:
      hs.flip(reg, bits, spec, at, band, g, scf)

def hs.next(
  endb: Bool, bits: List<&2, U32>, spec: List<&2, F32>, +at: U32, +band: U32, +left: U32, +reg: U32,
  +cnt: U32, +g: Gd, +scf: List<&2, U32>
) -> Hs:
  match endb:
    case False{}:
      Hs{bits, spec, at, band, (left - 1 : U32), reg, cnt}
    case True{}:
      hs.region(U32.is_eq(cnt, 0), bits, spec, at, (band + 1 : U32), reg, cnt, g, scf)

def lib.scf(l: Lib) -> List<&2, U32>:
  match l:
    case Lib{_h, _i, _n, _p, s}:
      s

def hs.place(
  p: Pr, spec: List<&2, F32>, +at: U32, +band: U32, +left: U32, +reg: U32, +cnt: U32, +g: Gd, +lib: Lib
) -> Hs:
  match p:
    case Pr{+a, +b, bits}:
      hs.next(U32.is_eq(left, 1), bits, hs.put(spec, at, a, b), (at + 2 : U32), band, left, reg, cnt,
        g, lib.scf(lib))

def hs.step(st: Hs, +g: Gd, +gain: F32, +lib: Lib) -> Hs:
  match st:
    case Hs{bits, spec, +at, +band, +left, +reg, +cnt}:
      hs.place(hf.from(lib, bits, hs.tab(reg, g), gain), spec, at, band, left, reg, cnt, g, lib)

def hs.go(hop: Nat, +g: Gd, +gain: F32, +lib: Lib, st: Hs) -> Hs:
  match hop:
    case 0n:
      st
    case 1n+p:
      hs.go(p, g, gain, lib, hs.step(st, g, gain, lib))

def hs.spec(st: Hs) -> List<&2, F32>:
  match st:
    case Hs{_bits, spec, _at, _band, _left, _reg, _cnt}:
      spec

def dec.full(+g: Gd, bits: List<&2, U32>, +lib: Lib) -> List<&2, F32>:
  match g:
    case Gd{_part, +big, +gain, _c, _t0, _t1, _t2, +r0, _r1, _pre, _sc, _c1, _block}:
      hs.spec(hs.go(U32.to_nat(big), g, Enc.gain.of(gain), lib,
        hs.open(0, side.skip(bits, 59), List.replicate(F32, 576n, 0.0), 0, 0, r0, lib.scf(lib))))

def dec.fold(xs: List<&2, F32>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case +hd <> tl:
      dec.fold(tl, U32.xor(acc, f.word(hd)))

def dec.frame(got: Gd & List<&2, U32>, lib: Lib) -> List<&2, F32>:
  match got:
    case (g, bits):
      dec.full(g, bits, lib)

def dec.sum(xs: List<&2, U32>) -> U32:
  dec.fold(dec.frame(side.ch(side.skip(bits.of(xs), (32 + 18 : U32))), lib.of()), 0)

# part2_3_length of one granule channel
def g.part(g: Gd) -> U32:
  match g:
    case Gd{part, _b, _g, _c, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      part

# long block, no scale-factor bits, big_values inside the 576 lines
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

def gd.use(g: Gd) -> Bool:
  match g:
    case Gd{_p, +big, _g, +comp, _t0, _t1, _t2, _r0, _r1, +pre, +sc, _c1, +block}:
      gd.u4(gd.both(gd.both(U32.is_eq(block, 0), U32.is_eq(comp, 0)),
        gd.both(U32.is_eq(pre, 0), U32.is_eq(sc, 0))), big)

# every channel side-info block is a long block we can decode
def gs.ok(hop: Nat, gs: List<&2, Gd>, +ok: Bool) -> Bool:
  match hop gs:
    case 0n _:
      ok
    case _ Nil{}:
      False{}
    case 1n+p +hd <> tl:
      gs.ok(p, tl, gd.both(ok, gd.use(hd)))

# Huffman of one channel. bits already sit on the channel's main data.
def dec.spec(+g: Gd, bits: List<&2, U32>, +lib: Lib) -> List<&2, F32>:
  match g:
    case Gd{_part, +big, +gain, _c, _t0, _t1, _t2, +r0, _r1, _pre, _sc, _c1, _block}:
      hs.spec(hs.go(U32.to_nat(big), g, Enc.gain.of(gain), lib,
        hs.open(0, bits, List.replicate(F32, 576n, 0.0), 0, 0, r0, lib.scf(lib))))

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

# one sample-rate row of the scale-factor widths
def lib.use(l: Lib, +hz: U32) -> Lib:
  match l:
    case Lib{+huff, +ix, +lin, +pow, s}:
      Lib{huff, ix, lin, pow, bd.take(22n, bd.drop(U32.to_nat(scf.off(hz)), s), [])}

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

# how many granule-channels a frame carries
def fr.n(+nch: U32) -> Nat:
  match nch:
    case 1:
      2n
    case _:
      4n

# how many channels one granule carries
def gr.n(+nch: U32) -> Nat:
  match nch:
    case 1:
      1n
    case _:
      2n

# one granule's channels flattened, and what remains
type Chs is Data:
  Chs{spec: List<&2, F32>, bits: List<&2, U32>, gs: List<&2, Gd>}

def chs.push(xs: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      acc
    case +hd <> tl:
      chs.push(tl, hd <> acc)

def chs.go(
  hop: Nat, gs: List<&2, Gd>, +bits: List<&2, U32>, +lib: Lib, spec: List<&2, F32>
) -> Chs:
  match hop gs:
    case 0n ys:
      Chs{List.reverse(&2, F32, spec), bits, ys}
    case _ Nil{}:
      Chs{List.reverse(&2, F32, spec), bits, []}
    case 1n+p +hd <> tl:
      chs.go(p, tl, side.skip(bits, g.part(hd)), lib, chs.push(dec.spec(hd, bits, lib), spec))

# PCM words, overlap, delay, and the unread side of the frame
type Gr is Data:
  Gr{pcm: List<&2, U32>, ov: List<&2, F32>, qmf: List<&2, F32>, bits: List<&2, U32>, gs: List<&2, Gd>}

def pcm.bits(xs: List<&2, F32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      List.reverse(&2, U32, acc)
    case +hd <> tl:
      pcm.bits(tl, f.word(hd) <> acc)

def gr.pack(pc: Syn.Pc, bits: List<&2, U32>, gs: List<&2, Gd>) -> Gr:
  match pc:
    case Syn.Pc{pcm, ov, qmf}:
      Gr{pcm.bits(pcm, []), ov, qmf, bits, gs}

def gr.syn(cc: Chs, +ov: List<&2, F32>, +qmf: List<&2, F32>, +nch: U32) -> Gr:
  match cc:
    case Chs{+spec, bits, gs}:
      gr.pack(Syn.syn.gran(spec, ov, qmf, nch), bits, gs)

def gr.one(
  +gs: List<&2, Gd>, bits: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Gr:
  gr.syn(chs.go(gr.n(nch), gs, bits, lib, []), ov, qmf, nch)

# one frame of PCM and the state to carry, including the shared tables
type Out is Data:
  Out{pcm: List<&2, U32>, ov: List<&2, F32>, qmf: List<&2, F32>, fresh: U32, lib: Lib}

def dec.g3(+pcm0: List<&2, U32>, g: Gr, +lib: Lib) -> Maybe<&2, Out>:
  match g:
    case Gr{pcm, ov, qmf, _bits, _gs}:
      Some{Out{List.append(&2, U32, pcm0, pcm), ov, qmf, 0, lib}}

def dec.g2(g: Gr, +nch: U32, +lib: Lib) -> Maybe<&2, Out>:
  match g:
    case Gr{+pcm, +ov, +qmf, bits, gs}:
      dec.g3(pcm, gr.one(gs, bits, nch, ov, qmf, lib), lib)

def dec.grs(
  +gs: List<&2, Gd>, bits: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Maybe<&2, Out>:
  dec.g2(gr.one(gs, bits, nch, ov, qmf, lib), nch, lib)

def dec.try(
  ok: Bool, +gs: List<&2, Gd>, bits: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>,
  +lib: Lib
) -> Maybe<&2, Out>:
  match ok:
    case False{}:
      None{}
    case True{}:
      dec.grs(gs, bits, nch, ov, qmf, lib)

def dec.got(gg: Gs, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib) -> Maybe<&2, Out>:
  match gg:
    case Gs{+gs, bits}:
      dec.try(gs.ok(fr.n(nch), gs, True{}), gs, bits, nch, ov, qmf, lib)

def dec.beg(
  ok: Bool, bits: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Maybe<&2, Out>:
  match ok:
    case False{}:
      None{}
    case True{}:
      dec.got(gs.of(side.nch(fr.n(nch), Sd{bits, []})), nch, ov, qmf, lib)

def dec.open(op: Op, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib) -> Maybe<&2, Out>:
  match op:
    case Op{+begin, bits}:
      dec.beg(U32.is_eq(begin, 0), bits, nch, ov, qmf, lib)

# real synthesis, including a silent frame that still has to ring the delay line out
def dec.live(
  +frame: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Maybe<&2, Out>:
  dec.open(side.open(side.skip(bits.of(frame), 32), nch), nch, ov, qmf, lib)

# payload after the 4-byte header is entirely zero
def pay.z(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case 0 <> tl:
      pay.z(tl)
    case _ <> _tl:
      False{}

def dec.q2(fresh: Bool, zero: Bool) -> Bool:
  match fresh:
    case False{}:
      False{}
    case True{}:
      zero

def dec.quiet(xs: List<&2, U32>, +fresh: U32) -> Bool:
  dec.q2(U32.is_eq(fresh, 1), pay.z(xs))

# 1152 samples per channel, as zero words
def dec.zpcm(+nch: U32) -> List<&2, U32>:
  List.replicate(U32, U32.to_nat((1152 * nch : U32)), 0)

def yn.both(aa: Bool, bb: Bool) -> Bool:
  match aa:
    case False{}:
      False{}
    case True{}:
      bb

# granule 0 of the integer pair: one big_value, gain 0, long block
def g0.yes(g: Gd) -> Bool:
  match g:
    case Gd{_part, +big, +gain, +comp, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, +block}:
      yn.both(yn.both(U32.is_eq(big, 1), U32.is_eq(gain, 0)),
        yn.both(U32.is_eq(comp, 0), U32.is_eq(block, 0)))

def g1.yes(g: Gd) -> Bool:
  match g:
    case Gd{_part, +big, _gain, _comp, _t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      U32.is_eq(big, 0)

def gs.two(gs: List<&2, Gd>) -> Bool:
  match gs:
    case +aa <> +bb <> Nil{}:
      yn.both(g0.yes(aa), g1.yes(bb))
    case _:
      False{}

def gs.mono(mono: Bool, gs: List<&2, Gd>) -> Bool:
  match mono:
    case False{}:
      False{}
    case True{}:
      gs.two(gs)

def gs.hd(gs: List<&2, Gd>) -> Gd:
  match gs:
    case +hd <> _tl:
      hd
    case Nil{}:
      Gd{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2}

def nd.tab(
  g: Gd, bits: List<&2, U32>, +huff: List<&2, U32>, +ix: List<&2, U32>
) -> Nd:
  match g:
    case Gd{_part, _big, _gain, _comp, +t0, _t1, _t2, _r0, _r1, _pre, _sc, _c1, _block}:
      hf.open(bits, u.nth(ix, t0), huff)

def nd.open(g: Gd, bits: List<&2, U32>, lib: Lib) -> Nd:
  match lib:
    case Lib{+huff, +ix, _lin, _pow, _scf}:
      nd.tab(g, bits, huff, ix)

# the two Huffman magnitudes, then the rest of the 1152 mono words
def pair.word(+leaf: U32) -> List<&2, U32>:
  (leaf .&. 15 : U32) <>
    ((hf.shift(leaf) .&. 15 : U32) <> List.replicate(U32, U32.to_nat(1150), 0))

def pair.try(
  nd: Nd, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Maybe<&2, Out>:
  match nd:
    case Nd{+leaf, _bits, _w, _done}:
      Some{Out{pair.word(leaf), ov, qmf, 0, lib}}

def seek.arm(
  yes: Bool,
  gs: List<&2, Gd>,
  bits: List<&2, U32>,
  +frame: List<&2, U32>,
  +nch: U32,
  +ov: List<&2, F32>,
  +qmf: List<&2, F32>,
  +lib: Lib
) -> Maybe<&2, Out>:
  match yes:
    case False{}:
      dec.live(frame, nch, ov, qmf, lib)
    case True{}:
      pair.try(nd.open(gs.hd(gs), bits, lib), ov, qmf, lib)

def seek.gs(
  gg: Gs,
  +frame: List<&2, U32>,
  +nch: U32,
  +ov: List<&2, F32>,
  +qmf: List<&2, F32>,
  +lib: Lib
) -> Maybe<&2, Out>:
  match gg:
    case Gs{+gs, bits}:
      seek.arm(gs.mono(U32.is_eq(nch, 1), gs), gs, bits, frame, nch, ov, qmf, lib)

def seek.beg(
  ok: Bool,
  bits: List<&2, U32>,
  +frame: List<&2, U32>,
  +nch: U32,
  +ov: List<&2, F32>,
  +qmf: List<&2, F32>,
  +lib: Lib
) -> Maybe<&2, Out>:
  match ok:
    case False{}:
      dec.live(frame, nch, ov, qmf, lib)
    case True{}:
      seek.gs(gs.of(side.nch(fr.n(nch), Sd{bits, []})), frame, nch, ov, qmf, lib)

def seek.op(
  op: Op,
  +frame: List<&2, U32>,
  +nch: U32,
  +ov: List<&2, F32>,
  +qmf: List<&2, F32>,
  +lib: Lib
) -> Maybe<&2, Out>:
  match op:
    case Op{+begin, bits}:
      seek.beg(U32.is_eq(begin, 0), bits, frame, nch, ov, qmf, lib)

# gain 0 and one big_value: read the Huffman pair, skip the filterbank
def dec.seek(
  +frame: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Maybe<&2, Out>:
  seek.op(side.open(side.skip(bits.of(frame), 32), nch), frame, nch, ov, qmf, lib)

def dec.alt(
  silent: Bool, +frame: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +lib: Lib
) -> Maybe<&2, Out>:
  match silent:
    case True{}:
      Some{Out{dec.zpcm(nch), ov, qmf, 1, lib}}
    case False{}:
      dec.seek(frame, nch, ov, qmf, lib)

# one MPEG-1 Layer III frame. fresh 1 and an all-zero payload skip the filterbank.
# A mono granule with big_values 1 and global_gain 0 returns that Huffman pair.
# lib is already the scale-factor row for this sampling frequency.
def dec.step(
  +frame: List<&2, U32>, +nch: U32, +ov: List<&2, F32>, +qmf: List<&2, F32>, +fresh: U32, +lib: Lib
) -> Maybe<&2, Out>:
  dec.alt(dec.quiet(bd.drop(4n, frame), fresh), frame, nch, ov, qmf, lib)

# zero polyphase delay
def dec.qmf() -> List<&2, F32>:
  Syn.syn.zqmf()

# zero overlap for one or two channels
def dec.ov(+nch: U32) -> List<&2, F32>:
  match nch:
    case 1:
      Syn.syn.zov()
    case _:
      List.append(&2, F32, Syn.syn.zov(), Syn.syn.zov())

# one frame from a cold decoder, for a compiled check
def dec.aud(+frame: List<&2, U32>, +nch: U32, +hz: U32) -> Maybe<&2, Out>:
  dec.step(frame, nch, dec.ov(nch), Syn.syn.zqmf(), 1, lib.use(lib.of(), hz))

def out.nth(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{vv}:
      vv

def out.at(o: Out, +ii: U32) -> U32:
  match o:
    case Out{pcm, _ov, _qmf, _fr, _lib}:
      out.nth(List.get(&2, U32, pcm, U32.to_nat(ii)))

def aud.at(m: Maybe<&2, Out>, +ii: U32) -> U32:
  match m:
    case None{}:
      0
    case Some{oo}:
      out.at(oo, ii)

# samples 1, 7, and 200, mixed, so one compiled run checks the granule
def aud.mix(m: Maybe<&2, Out>) -> U32:
  match m:
    case None{}:
      0
    case Some{+oo}:
      U32.xor(U32.xor(out.at(oo, 1), out.at(oo, 7)), out.at(oo, 200))
