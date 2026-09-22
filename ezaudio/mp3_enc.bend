# MPEG-1 Layer III encoder: analysis filterbank, MDCT, quantiser, Huffman.
import Base
import ./mp3_tab.bend as Tab

def f32.bits(+w: U32) -> F32:
  match w:
    case U32{+bb}:
      F32{bb}

def f32.word(x: F32) -> U32:
  match x:
    case F32{+bb}:
      U32{bb}

def u.nth.m(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{vv}:
      vv

def u.nth(xs: List<&2, U32>, +ii: U32) -> U32:
  u.nth.m(List.get(&2, U32, xs, U32.to_nat(ii)))

def f.nth.m(m: Maybe<&2, F32>) -> F32:
  match m:
    case None{}:
      0.0
    case Some{vv}:
      vv

def f.nth(xs: List<&2, F32>, +ii: U32) -> F32:
  f.nth.m(List.get(&2, F32, xs, U32.to_nat(ii)))

def f.put(xs: List<&2, F32>, +ii: U32, +vv: F32) -> List<&2, F32>:
  List.set(&2, F32, xs, U32.to_nat(ii), vv)

def f.of(xs: List<&2, U32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      f32.bits(hd) <> f.of(tl)

def f.rev(xs: List<&2, F32>) -> List<&2, F32>:
  List.reverse(&2, F32, xs)

def mul.zip(xs: List<&2, F32>, ys: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match xs ys:
    case +xx <> xt +yy <> yt:
      mul.zip(xt, yt, ((xx * yy : F32) <> acc))
    case _ _:
      f.rev(acc)

def y.wrap(last: Bool, +ii: U32) -> U32:
  match last:
    case True{}:
      0
    case False{}:
      (ii + 1 : U32)

# 64 partials. Each windowed sample indexes one bin; a list walks from the head.
type Ya is Type:
  Ya{acc: Array<F32>, cur: F32}

def ya.of(got: Array<F32> & F32) -> Ya:
  (acc, cur) = got
  Ya{acc, cur}

def y.store(got: Ya, +ii: U32, +vv: F32) -> Array<F32>:
  match got:
    case Ya{acc, +cur}:
      Array.set(F32, acc, ii, (cur + vv : F32))

def y.add(acc: Array<F32>, +ii: U32, +vv: F32) -> Array<F32>:
  y.store(ya.of(Array.get(F32, acc, ii)), ii, vv)

def y.fold(xs: List<&2, F32>, acc: Array<F32>, +ii: U32) -> Array<F32>:
  match xs:
    case Nil{}:
      acc
    case +hd <> tl:
      y.fold(tl, y.add(acc, ii, hd), y.wrap(U32.is_eq(ii, 63), ii))

def y.pull(hop: Nat, got: Ya, +ii: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match hop got:
    case 0n Ya{_acc, +cur}:
      f.rev(cur <> acc)
    case 1n+p Ya{tab, +cur}:
      y.pull(p, ya.of(Array.get(F32, tab, (ii + 1 : U32))), (ii + 1 : U32), (cur <> acc))

def y.list(acc: Array<F32>) -> List<&2, F32>:
  y.pull(63n, ya.of(Array.get(F32, acc, 0)), 0, [])

# a cosine table handed back beside the coefficient Array.get just read
type Cf is Type:
  Cf{tab: Array<F32>, co: F32}

def cf.of(got: Array<F32> & F32) -> Cf:
  (tab, co) = got
  Cf{tab, co}

def dot.go(tl: List<&2, F32>, got: Cf, +base: U32, +hd: F32, acc: F32) -> Array<F32> & F32:
  match tl got:
    case Nil{} Cf{tab, co}:
      (tab, (acc + (co * hd : F32) : F32))
    case +hd2 <> rest Cf{tab, co}:
      dot.go(rest, cf.of(Array.get(F32, tab, (base + 1 : U32))), (base + 1 : U32), hd2,
        (acc + (co * hd : F32) : F32))

# tab.cos is 2048 F32s. Each tap reads that table with Array.get.
def dot.row(ys: List<&2, F32>, tab: Array<F32>, +base: U32, acc: F32) -> Array<F32> & F32:
  match ys:
    case Nil{}:
      (tab, acc)
    case +hd <> tl:
      dot.go(tl, cf.of(Array.get(F32, tab, base)), base, hd, acc)

def sb.go(
  hop: Nat, got: Cf, +ys: List<&2, F32>, +row: U32, acc: List<&2, F32>
) -> Array<F32> & List<&2, F32>:
  match hop got:
    case 0n Cf{tab, dd}:
      (tab, f.rev(((dd / 2.0 : F32) <> acc)))
    case 1n+p Cf{tab, dd}:
      sb.go(p, cf.of(dot.row(ys, tab, ((row + 1 : U32) * 64 : U32), 0.0)), ys, (row + 1 : U32),
        ((dd / 2.0 : F32) <> acc))

def sb.rows(
  hop: Nat, tab: Array<F32>, +ys: List<&2, F32>, +row: U32, acc: List<&2, F32>
) -> Array<F32> & List<&2, F32>:
  match hop:
    case 0n:
      (tab, f.rev(acc))
    case 1n+p:
      sb.go(p, cf.of(dot.row(ys, tab, (row * 64 : U32), 0.0)), ys, row, acc)

# subband samples of one shifted block. x holds 512 windowed-ready samples.
def an.sb(+xx: List<&2, F32>, +win: List<&2, F32>, cos: Array<F32>) -> Array<F32> & List<&2, F32>:
  sb.rows(32n, cos, y.list(y.fold(mul.zip(xx, win, []), Array.new(F32, 6n, 0.0), 0)), 0, [])

# analysis delay line and finished subband blocks, newest block first
type An is Data:
  An{x: List<&2, F32>, out: List<&2, List<&2, F32>>}

def an.done(
  +nx: List<&2, F32>, out: List<&2, List<&2, F32>>, got: Array<F32> & List<&2, F32>
) -> An & Array<F32>:
  (cos, sb) = got
  (An{nx, sb <> out}, cos)

def an.pushed(
  +nx: List<&2, F32>, out: List<&2, List<&2, F32>>, +win: List<&2, F32>, cos: Array<F32>
) -> An & Array<F32>:
  an.done(nx, out, an.sb(nx, win, cos))

def an.push(st: An, blk: List<&2, F32>, +win: List<&2, F32>, cos: Array<F32>) -> An & Array<F32>:
  match st:
    case An{+xx, out}:
      an.pushed(List.append(&2, F32, List.drop(&2, F32, xx, 32n), blk), out, win, cos)

def an.blk(
  +s00: F32, +s01: F32, +s02: F32, +s03: F32, +s04: F32, +s05: F32, +s06: F32, +s07: F32,
  +s08: F32, +s09: F32, +s10: F32, +s11: F32, +s12: F32, +s13: F32, +s14: F32, +s15: F32,
  +s16: F32, +s17: F32, +s18: F32, +s19: F32, +s20: F32, +s21: F32, +s22: F32, +s23: F32,
  +s24: F32, +s25: F32, +s26: F32, +s27: F32, +s28: F32, +s29: F32, +s30: F32, +s31: F32
) -> List<&2, F32>:
  [s00, s01, s02, s03, s04, s05, s06, s07, s08, s09, s10, s11, s12, s13, s14, s15,
   s16, s17, s18, s19, s20, s21, s22, s23, s24, s25, s26, s27, s28, s29, s30, s31]

# the delay line paired with the cosine table, which has one owner
type Aw is Type:
  Aw{st: An, cos: Array<F32>}

def aw.of(got: An & Array<F32>) -> Aw:
  (st, cos) = got
  Aw{st, cos}

def an.go(xs: List<&2, F32>, got: Aw, +win: List<&2, F32>) -> An & Array<F32>:
  match xs got:
    case +s00 <> +s01 <> +s02 <> +s03 <> +s04 <> +s05 <> +s06 <> +s07 <> +s08 <> +s09 <> +s10
      <> +s11 <> +s12 <> +s13 <> +s14 <> +s15 <> +s16 <> +s17 <> +s18 <> +s19 <> +s20 <> +s21
      <> +s22 <> +s23 <> +s24 <> +s25 <> +s26 <> +s27 <> +s28 <> +s29 <> +s30 <> +s31 <> rest Aw{st, cos}:
      an.go(rest, aw.of(an.push(st, an.blk(s00, s01, s02, s03, s04, s05, s06, s07, s08, s09,
        s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, s23, s24, s25, s26,
        s27, s28, s29, s30, s31), win, cos)), win)
    case _ Aw{st, cos}:
      (st, cos)

def an.walk(xs: List<&2, F32>, st: An, +win: List<&2, F32>, cos: Array<F32>) -> An & Array<F32>:
  an.go(xs, Aw{st, cos}, win)

def an.zero() -> An:
  An{List.replicate(F32, 512n, 0.0), []}

# subband frames, newest block first. each block is 32 bands.
def f.revs(xs: List<&2, List<&2, F32>>) -> List<&2, List<&2, F32>>:
  List.reverse(&2, List<&2, F32>, xs)

def an.out(st: An) -> List<&2, List<&2, F32>>:
  match st:
    case An{_xx, out}:
      f.revs(out)

def cos.put(xs: List<&2, F32>, a: Array<F32>, +ii: U32) -> Array<F32>:
  match xs:
    case Nil{}:
      a
    case +hd <> tl:
      cos.put(tl, Array.set(F32, a, ii, hd), (ii + 1 : U32))

# 2^11 slots: tab.cos is 2048 coefficients, filled in list order.
def cos.of() -> Array<F32>:
  cos.put(f.of(Tab.tab.cos()), Array.new(F32, 11n, 0.0), 0)

def an.fin(got: An & Array<F32>) -> List<&2, List<&2, F32>>:
  (st, _cos) = got
  an.out(st)

def an.run(xs: List<&2, F32>) -> List<&2, List<&2, F32>>:
  an.fin(an.walk(xs, an.zero(), f.of(Tab.tab.win()), cos.of()))

# ldexp_q2 residual: mantissa and the exponent still to apply
type Ld is Data:
  Ld{yy: F32, ee: U32}

def ex.of(+ee: U32) -> F32:
  match ee:
    case 0:
      f32.bits(813694976)
    case 1:
      f32.bits(811025661)
    case 2:
      f32.bits(808781043)
    case _:
      f32.bits(806893552)

def ld.scale(+ee: U32) -> F32:
  U32.to_f32(((1073741824 >> U32.to_nat((ee >> 2n : U32)) : U32)))

def ld.once(+yy: F32, +ee: U32) -> F32:
  ((yy * ex.of((ee .&. 3 : U32)) : F32) * ld.scale(ee) : F32)

def ld.minp(small: Bool, +ee: U32) -> U32:
  match small:
    case True{}:
      ee
    case False{}:
      120

def ld.cut(+yy: F32, +ee: U32, +cut: U32) -> Ld:
  Ld{ld.once(yy, cut), (ee - cut : U32)}

def ld.step(st: Ld) -> Ld:
  match st:
    case Ld{yy, 0}:
      Ld{yy, 0}
    case Ld{yy, +ee}:
      ld.cut(yy, ee, ld.minp(U32.is_le(ee, 120), ee))

def ld.go(hop: Nat, st: Ld) -> Ld:
  match hop:
    case 0n:
      st
    case 1n+p:
      ld.go(p, ld.step(st))

def ld.y(st: Ld) -> F32:
  match st:
    case Ld{yy, _ee}:
      yy

# minimp3 dequant gain for a global_gain. ix = round((|xr| / gain) ^ 0.75).
def gain.of(+gg: U32) -> F32:
  ld.y(ld.go(8n, Ld{2048.0, (258 - gg : U32)}))

def q.cp(ok: Bool, +nn: U32) -> U32:
  match ok:
    case True{}:
      nn
    case False{}:
      8206

def q.clip(+nn: U32) -> U32:
  q.cp(U32.is_le(nn, 8206), nn)

def q.mag(+xr: F32, +gain: F32) -> U32:
  q.clip(F32.to_u32(F32.round(F32.pow((F32.abs(xr) / gain : F32), 0.75))))

def q.sign(neg: Bool, +mag: U32) -> U32:
  match neg:
    case False{}:
      mag
    case True{}:
      (0 - mag : U32)

def q.one(+xr: F32, +gain: F32) -> U32:
  q.sign(F32.is_lt(xr, 0.0), q.mag(xr, gain))

def q.all(xs: List<&2, F32>, +gain: F32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      q.one(hd, gain) <> q.all(tl, gain)

def i.neg(+vv: U32) -> Bool:
  U32.is_ne((vv .&. 2147483648 : U32), 0)

def i.ab(neg: Bool, +vv: U32) -> U32:
  match neg:
    case False{}:
      vv
    case True{}:
      (0 - vv : U32)

def i.abs(+vv: U32) -> U32:
  i.ab(i.neg(vv), vv)

def scf.row(+hz: U32) -> U32:
  match hz:
    case 48000:
      1
    case 32000:
      2
    case _:
      0

def scf.at(+hz: U32, +band: U32) -> U32:
  u.nth(Tab.tab.scf(), ((scf.row(hz) * 22 : U32) + band : U32))

def nz.n(hop: Nat, xs: List<&2, U32>) -> Bool:
  match hop xs:
    case 0n _:
      False{}
    case _ Nil{}:
      False{}
    case 1n+p 0 <> t:
      nz.n(p, t)
    case _ _:
      True{}

def drop.u(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop xs:
    case 0n ys:
      ys
    case _ Nil{}:
      []
    case 1n+p _hd <> tl:
      drop.u(p, tl)

def take.u(hop: Nat, xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match hop xs:
    case 0n _:
      List.reverse(&2, U32, acc)
    case _ Nil{}:
      List.reverse(&2, U32, acc)
    case 1n+p +hd <> tl:
      take.u(p, tl, hd <> acc)

# big_values scan across the 22 long scalefactor bands
type Bv is Data:
  Bv{ix: List<&2, U32>, last: U32, acc: U32}

def bv.put(ix: List<&2, U32>, +last: U32, +acc: U32, hit: Bool) -> Bv:
  match hit:
    case True{}:
      Bv{ix, acc, acc}
    case False{}:
      Bv{ix, last, acc}

def bv.got(ix: List<&2, U32>, +last: U32, +acc: U32, +width: U32, hit: Bool) -> Bv:
  bv.put(drop.u(U32.to_nat(width), ix), last, (acc + U32.div(width, 2) : U32), hit)

def bv.band(+ix: List<&2, U32>, +last: U32, +acc: U32, +width: U32) -> Bv:
  bv.got(ix, last, acc, width, nz.n(U32.to_nat(width), ix))

def bv.at(st: Bv, +hz: U32, +band: U32) -> Bv:
  match st:
    case Bv{+ix, last, +acc}:
      bv.band(ix, last, acc, scf.at(hz, band))

def bv.go(hop: Nat, st: Bv, +hz: U32, +band: U32) -> Bv:
  match hop:
    case 0n:
      st
    case 1n+p:
      bv.go(p, bv.at(st, hz, band), hz, (band + 1 : U32))

def bv.last(st: Bv) -> U32:
  match st:
    case Bv{_ix, last, _acc}:
      last

def bv.of(ix: List<&2, U32>, +hz: U32) -> U32:
  bv.last(bv.go(22n, Bv{ix, 0, 0}, hz, 0))

# Huffman bits for one granule, newest bit first, running length, and whether the table fit
type Hp is Data:
  Hp{bits: List<&2, U32>, n: U32, ok: U32}

def hp.bit(hp: Hp, +bit: U32) -> Hp:
  match hp:
    case Hp{_bs, _n, 0}:
      Hp{[], 0, 0}
    case Hp{bs, +n, _ok}:
      Hp{bit <> bs, (n + 1 : U32), 1}

def hp.field(hop: Nat, hp: Hp, +code: U32, +left: U32) -> Hp:
  match hop:
    case 0n:
      hp
    case 1n+p:
      hp.field(p, hp.bit(hp, ((code >> U32.to_nat((left - 1 : U32)) : U32) .&. 1 : U32)), code,
        (left - 1 : U32))

def lim.p(z: Bool, +lin: U32) -> U32:
  match z:
    case True{}:
      15
    case False{}:
      (15 + ((1 << U32.to_nat(lin) : U32)) : U32)

def lim.of(+lin: U32) -> U32:
  lim.p(U32.is_eq(lin, 0), lin)

def ca.p(big: Bool, +aa: U32) -> U32:
  match big:
    case True{}:
      15
    case False{}:
      aa

def ca.of(+lin: U32, +aa: U32) -> U32:
  ca.p(U32.is_ne(lin, 0) && U32.is_ge(aa, 15), aa)

def hp.sgn(neg: Bool) -> U32:
  match neg:
    case True{}:
      1
    case False{}:
      0

def hp.sp(z: Bool, hp: Hp, +vv: U32) -> Hp:
  match z:
    case True{}:
      hp
    case False{}:
      hp.bit(hp, hp.sgn(i.neg(vv)))

def hp.sign(hp: Hp, +vv: U32, +aa: U32) -> Hp:
  hp.sp(U32.is_eq(aa, 0), hp, vv)

def hp.lp(z: Bool, hp: Hp, +lin: U32, +extra: U32) -> Hp:
  match z:
    case True{}:
      hp.field(U32.to_nat(lin), hp, extra, lin)
    case False{}:
      hp

def hp.lin(hp: Hp, +lin: U32, +aa: U32) -> Hp:
  hp.lp(U32.is_ne(lin, 0) && U32.is_ge(aa, 15), hp, lin, (aa - 15 : U32))

def hp.over(aa: U32, bb: U32, +lin: U32) -> Bool:
  U32.is_ge(aa, lim.of(lin)) || U32.is_ge(bb, lim.of(lin))

def hp.bad(z: Bool, hp: Hp) -> Hp:
  match z:
    case True{}:
      Hp{[], 0, 0}
    case False{}:
      hp

# a Huffman word handed back beside the Array.get just read
type Wd is Type:
  Wd{tab: Array<U32>, w: U32}

def wd.of(got: Array<U32> & U32) -> Wd:
  (tab, w) = got
  Wd{tab, w}

# tab.code is 8192 words. Each pair reads that table with Array.get.
def word.of(codes: Array<U32>, +tab: U32, +ca: U32, +cb: U32) -> Array<U32> & U32:
  Array.get(U32, codes, (((tab * 256 : U32) + (ca * 16 : U32) : U32) + cb : U32))

def hp.use(z: Bool, hp: Hp, +w: U32, +av: U32, +bv: U32, +aa: U32, +bb: U32, +lin: U32) -> Hp:
  match z:
    case True{}:
      Hp{[], 0, 0}
    case False{}:
      hp.sign(hp.lin(hp.sign(hp.lin(hp.field(U32.to_nat((w >> 16n : U32)), hp, (w .&. 65535 : U32),
        (w >> 16n : U32)), lin, aa), av, aa), lin, bb), bv, bb)

def hp.word(hp: Hp, +av: U32, +bv: U32, +aa: U32, +bb: U32, +lin: U32, +w: U32) -> Hp:
  hp.bad(hp.over(aa, bb, lin), hp.use(U32.is_eq((w >> 16n : U32), 0), hp, w, av, bv, aa, bb, lin))

def hp.from(
  got: Wd, hp: Hp, +av: U32, +bv: U32, +aa: U32, +bb: U32, +lin: U32
) -> Array<U32> & Hp:
  match got:
    case Wd{tab, +w}:
      (tab, hp.word(hp, av, bv, aa, bb, lin, w))

def hp.ready(
  hp: Hp, +tab: U32, +av: U32, +bv: U32, +aa: U32, +bb: U32, +lin: U32, codes: Array<U32>
) -> Array<U32> & Hp:
  hp.from(wd.of(word.of(codes, tab, ca.of(lin, aa), ca.of(lin, bb))), hp, av, bv, aa, bb, lin)

def hp.pair(
  hp: Hp, +tab: U32, +av: U32, +bv: U32, codes: Array<U32>, +lins: List<&2, U32>
) -> Array<U32> & Hp:
  hp.ready(hp, tab, av, bv, i.abs(av), i.abs(bv), u.nth(lins, tab), codes)

# the code table beside the bits just produced for one pair
type Hs is Type:
  Hs{tab: Array<U32>, hp: Hp}

def hs.of(got: Array<U32> & Hp) -> Hs:
  (tab, hp) = got
  Hs{tab, hp}

def hp.pairs(
  xs: List<&2, U32>, got: Hs, +tab: U32, +lins: List<&2, U32>
) -> Array<U32> & Hp:
  match xs got:
    case Nil{} Hs{codes, hp}:
      (codes, hp)
    case +aa <> +bb <> tl Hs{codes, hp}:
      hp.pairs(tl, hs.of(hp.pair(hp, tab, aa, bb, codes, lins)), tab, lins)
    case _ Hs{codes, _hp}:
      (codes, Hp{[], 0, 0})

def hp.cands() -> List<&2, U32>:
  [15, 13, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]

# shortest Huffman table that encoded the granule
type Best is Data:
  Best{tab: U32, nn: U32, bits: List<&2, U32>, ok: U32}

def best.or(a: Bool, b: Bool) -> Bool:
  match a:
    case True{}:
      True{}
    case False{}:
      b

def best.and(a: Bool, b: Bool) -> Bool:
  match a:
    case False{}:
      False{}
    case True{}:
      b

def best.better(+bok: U32, +bn: U32, +ok: U32, +nn: U32) -> Bool:
  best.and(U32.is_eq(ok, 1), best.or(U32.is_eq(bok, 0), U32.is_lt(nn, bn)))

def best.keep(
  take: Bool, +tab: U32, +nn: U32, bits: List<&2, U32>, +bt: U32, +bn: U32,
  bb: List<&2, U32>, +bok: U32
) -> Best:
  match take:
    case True{}:
      Best{tab, nn, bits, 1}
    case False{}:
      Best{bt, bn, bb, bok}

def best.from(b: Best, +tab: U32, +ok: U32, +nn: U32, bits: List<&2, U32>) -> Best:
  match b:
    case Best{+bt, +bn, bb, +bok}:
      best.keep(best.better(bok, bn, ok, nn), tab, nn, bits, bt, bn, bb, bok)

def best.got(b: Best, +tab: U32, hp: Hp) -> Best:
  match hp:
    case Hp{+bits, +n, ok}:
      best.from(b, tab, ok, n, bits)

def best.pull(b: Best, +tab: U32, got: Hs) -> Array<U32> & Best:
  match got:
    case Hs{codes, hp}:
      (codes, best.got(b, tab, hp))

def best.one(
  b: Best, +tab: U32, ix: List<&2, U32>, codes: Array<U32>, +lins: List<&2, U32>
) -> Array<U32> & Best:
  best.pull(b, tab, hs.of(hp.pairs(ix, Hs{codes, Hp{[], 0, 1}}, tab, lins)))

def best.step(
  b: Best, +tab: U32, +ix: List<&2, U32>, codes: Array<U32>, +lins: List<&2, U32>
) -> Array<U32> & Best:
  best.one(b, tab, ix, codes, lins)

# the code table beside the shortest table so far
type Bs is Type:
  Bs{tab: Array<U32>, best: Best}

def bs.of(got: Array<U32> & Best) -> Bs:
  (tab, best) = got
  Bs{tab, best}

def best.go(
  cs: List<&2, U32>, +ix: List<&2, U32>, got: Bs, +lins: List<&2, U32>
) -> Array<U32> & Best:
  match cs got:
    case Nil{} Bs{codes, won}:
      (codes, won)
    case +hd <> tl Bs{codes, won}:
      best.go(tl, ix, bs.of(best.step(won, hd, ix, codes, lins)), lins)

def code.put(xs: List<&2, U32>, a: Array<U32>, +ii: U32) -> Array<U32>:
  match xs:
    case Nil{}:
      a
    case +hd <> tl:
      code.put(tl, Array.set(U32, a, ii, hd), (ii + 1 : U32))

# 2^13 slots: tab.code is 8192 words, filled in list order.
def code.of() -> Array<U32>:
  code.put(Tab.tab.code(), Array.new(U32, 13n, 0), 0)

def best.fin(got: Bs) -> Best:
  match got:
    case Bs{_tab, best}:
      best

def best.of(ix: List<&2, U32>) -> Best:
  best.fin(bs.of(best.go(hp.cands(), ix, Bs{code.of(), Best{0, 0, [], 0}}, Tab.tab.lin())))

def ix.p(z: Bool, +mm: U32, +aa: U32) -> U32:
  match z:
    case True{}:
      aa
    case False{}:
      mm

def ix.up(+mm: U32, +aa: U32) -> U32:
  ix.p(U32.is_lt(mm, aa), mm, aa)

def ix.max(xs: List<&2, U32>, +mm: U32) -> U32:
  match xs:
    case Nil{}:
      mm
    case +hd <> tl:
      ix.max(tl, ix.up(mm, i.abs(hd)))

# binary search for the finest global_gain that fits the bit budget
type Sr is Data:
  Sr{lo: U32, hi: U32, gg: U32, tab: U32, bits: List<&2, U32>, ok: U32}

def sr.g1(z: Bool, +mx: U32) -> Bool:
  match z:
    case False{}:
      False{}
    case True{}:
      U32.is_lt(mx, 8000)

def sr.good(+bk: U32, +nn: U32, +bud: U32, +mx: U32) -> Bool:
  sr.g1(U32.is_eq(bk, 1) && U32.is_le(nn, bud), mx)

def sr.fit(
  okb: Bool, +lo: U32, +hi: U32, +mid: U32, +tt: U32, bits: List<&2, U32>, +ogg: U32, +ot: U32,
  obits: List<&2, U32>, +ook: U32
) -> Sr:
  match okb:
    case True{}:
      Sr{lo, (mid - 1 : U32), mid, tt, bits, 1}
    case False{}:
      Sr{(mid + 1 : U32), hi, ogg, ot, obits, ook}

def sr.best(
  b: Best, +mx: U32, +bud: U32, +lo: U32, +hi: U32, +mid: U32, +ogg: U32, +ot: U32,
  obits: List<&2, U32>, +ook: U32
) -> Sr:
  match b:
    case Best{tt, nn, bb, bk}:
      sr.fit(sr.good(bk, nn, bud, mx), lo, hi, mid, tt, bb, ogg, ot, obits, ook)

def sr.zero(
  z: Bool, +ix: List<&2, U32>, +mx: U32, +big: U32, +bud: U32, +lo: U32, +hi: U32, +mid: U32,
  +ogg: U32, +ot: U32, obits: List<&2, U32>, +ook: U32
) -> Sr:
  match z:
    case True{}:
      sr.fit(True{}, lo, hi, mid, 0, [], ogg, ot, obits, ook)
    case False{}:
      sr.best(best.of(take.u(U32.to_nat((big * 2 : U32)), ix, [])), mx, bud, lo, hi, mid, ogg, ot,
        obits, ook)

def sr.ix(
  +ix: List<&2, U32>, +hz: U32, +bud: U32, +lo: U32, +hi: U32, +mid: U32, +ogg: U32, +ot: U32,
  obits: List<&2, U32>, +ook: U32
) -> Sr:
  sr.zero(U32.is_eq(bv.of(ix, hz), 0), ix, ix.max(ix, 0), bv.of(ix, hz), bud, lo, hi, mid, ogg, ot,
    obits, ook)

def sr.try(
  +spec: List<&2, F32>, +hz: U32, +bud: U32, +lo: U32, +hi: U32, +mid: U32, +ogg: U32, +ot: U32,
  obits: List<&2, U32>, +ook: U32
) -> Sr:
  sr.ix(q.all(spec, gain.of(mid)), hz, bud, lo, hi, mid, ogg, ot, obits, ook)

def sr.live(
  go: Bool, +spec: List<&2, F32>, +hz: U32, +bud: U32, +lo: U32, +hi: U32, +gg: U32, +tab: U32,
  bits: List<&2, U32>, +ok: U32
) -> Sr:
  match go:
    case False{}:
      Sr{lo, hi, gg, tab, bits, ok}
    case True{}:
      sr.try(spec, hz, bud, lo, hi, U32.div((lo + hi : U32), 2), gg, tab, bits, ok)

def sr.step(spec: List<&2, F32>, +hz: U32, +bud: U32, st: Sr) -> Sr:
  match st:
    case Sr{+lo, +hi, +gg, +tab, bits, +ok}:
      sr.live(U32.is_le(lo, hi), spec, hz, bud, lo, hi, gg, tab, bits, ok)

def sr.go(hop: Nat, +spec: List<&2, F32>, +hz: U32, +bud: U32, st: Sr) -> Sr:
  match hop:
    case 0n:
      st
    case 1n+p:
      sr.go(p, spec, hz, bud, sr.step(spec, hz, bud, st))

def sr.run(spec: List<&2, F32>, +hz: U32, +bud: U32) -> Sr:
  sr.go(8n, spec, hz, bud, Sr{0, 255, 0, 0, [], 0})

def pk.p(z: Bool, +mm: F32, +aa: F32) -> F32:
  match z:
    case True{}:
      aa
    case False{}:
      mm

def pk.up(+mm: F32, +aa: F32) -> F32:
  pk.p(F32.is_lt(mm, aa), mm, aa)

def pk.go(xs: List<&2, F32>, +mm: F32) -> F32:
  match xs:
    case Nil{}:
      mm
    case +hd <> tl:
      pk.go(tl, pk.up(mm, F32.abs(hd)))

def dz.one(z: Bool, +vv: F32) -> F32:
  match z:
    case True{}:
      0.0
    case False{}:
      vv

def dz.apply(xs: List<&2, F32>, +thr: F32) -> List<&2, F32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      dz.one(F32.is_lt(F32.abs(hd), thr), hd) <> dz.apply(tl, thr)

def dz.on(
  done: Bool, st: Sr, +spec: List<&2, F32>, +pk: F32, +thr: U32, +hz: U32, +bud: U32
) -> Sr:
  match done:
    case True{}:
      st
    case False{}:
      sr.run(dz.apply(spec, (pk * f32.bits(thr) : F32)), hz, bud)

def dz.try(st: Sr, +spec: List<&2, F32>, +pk: F32, +thr: U32, +hz: U32, +bud: U32) -> Sr:
  match st:
    case Sr{+lo, +hi, +gg, +tab, bits, +ok}:
      dz.on(U32.is_eq(ok, 1), Sr{lo, hi, gg, tab, bits, ok}, spec, pk, thr, hz, bud)

def dz.go(
  thrs: List<&2, U32>, +spec: List<&2, F32>, +pk: F32, +hz: U32, +bud: U32, st: Sr
) -> Sr:
  match thrs:
    case Nil{}:
      st
    case +hd <> tl:
      dz.go(tl, spec, pk, hz, bud, dz.try(st, spec, pk, hd, hz, bud))

def dz.thrs() -> List<&2, U32>:
  [953267991, 981668463, 994352038, 1008981770, 1022739087, 1036831949, 1045220557, 1053609165]

def dz.maybe(tiny: Bool, +spec: List<&2, F32>, +pk: F32, +hz: U32, +bud: U32) -> Sr:
  match tiny:
    case True{}:
      Sr{0, 0, 0, 0, [], 1}
    case False{}:
      dz.go(dz.thrs(), spec, pk, hz, bud, Sr{0, 255, 0, 0, [], 0})

def dz.run(+spec: List<&2, F32>, +hz: U32, +bud: U32) -> Sr:
  dz.maybe(F32.is_lt(pk.go(spec, 0.0), f32.bits(730643660)), spec, pk.go(spec, 0.0), hz, bud)

# one quantized granule: part2_3_length, big_values, global_gain, table, bits
type Gr is Data:
  Gr{part: U32, big: U32, gain: U32, tab: U32, bits: List<&2, U32>}

# reversed bit list and its length
type Rv is Data:
  Rv{xs: List<&2, U32>, n: U32}

def rv.go(xs: List<&2, U32>, acc: List<&2, U32>, +n: U32) -> Rv:
  match xs:
    case Nil{}:
      Rv{acc, n}
    case +hd <> tl:
      rv.go(tl, hd <> acc, (n + 1 : U32))

def gr.from(r: Rv, +gg: U32, +tab: U32, +big: U32) -> Gr:
  match r:
    case Rv{xs, +n}:
      Gr{n, big, gg, tab, xs}

def gr.u(z: Bool, +gg: U32, +tab: U32, bits: List<&2, U32>, +big: U32) -> Gr:
  match z:
    case False{}:
      Gr{0, 0, 0, 0, []}
    case True{}:
      gr.from(rv.go(bits, [], 0), gg, tab, big)

def gr.use(z: Bool, +gg: U32, +tab: U32, bits: List<&2, U32>, ix: List<&2, U32>, +hz: U32) -> Gr:
  match z:
    case False{}:
      Gr{0, 0, 0, 0, []}
    case True{}:
      gr.u(True{}, gg, tab, bits, bv.of(ix, hz))

def gr.pack(st: Sr, +spec: List<&2, F32>, +hz: U32) -> Gr:
  match st:
    case Sr{_lo, _hi, +gg, +tab, bits, ok}:
      gr.use(U32.is_eq(ok, 1), gg, tab, bits, q.all(spec, gain.of(gg)), hz)

def gr.of(+spec: List<&2, F32>, +hz: U32, +bud: U32) -> Gr:
  gr.pack(dz.run(spec, hz, bud), spec, hz)

# a matrix coefficient handed back beside the Array.get just read
type Bf is Type:
  Bf{tab: Array<F32>, co: F32}

def bf.of(got: Array<F32> & F32) -> Bf:
  (tab, co) = got
  Bf{tab, co}

def bt.go(tl: List<&2, F32>, got: Bf, +base: U32, +hd: F32, acc: F32) -> Array<F32> & F32:
  match tl got:
    case Nil{} Bf{tab, co}:
      (tab, (acc + (co * hd : F32) : F32))
    case +hd2 <> rest Bf{tab, co}:
      bt.go(rest, bf.of(Array.get(F32, tab, (base + 1 : U32))), (base + 1 : U32), hd2,
        (acc + (co * hd : F32) : F32))

# tab.bt is 648 F32s. Each tap reads that table with Array.get.
def bt.dot(vec: List<&2, F32>, tab: Array<F32>, +base: U32, acc: F32) -> Array<F32> & F32:
  match vec:
    case Nil{}:
      (tab, acc)
    case +hd <> tl:
      bt.go(tl, bf.of(Array.get(F32, tab, base)), base, hd, acc)

def col.b(
  hop: Nat, xs: List<&2, List<&2, F32>>, +band: U32, acc: List<&2, F32>
) -> List<&2, F32>:
  match hop xs:
    case 0n _:
      f.rev(acc)
    case _ Nil{}:
      f.rev(acc)
    case 1n+p +blk <> tl:
      col.b(p, tl, band, f.nth(blk, band) <> acc)

def band.step(
  hop: Nat, +vec: List<&2, F32>, got: Bf, +kk: U32, acc: List<&2, F32>
) -> Array<F32> & List<&2, F32>:
  match hop got:
    case 0n Bf{tab, co}:
      (tab, f.rev((co <> acc)))
    case 1n+p Bf{tab, co}:
      band.step(p, vec, bf.of(bt.dot(vec, tab, ((kk + 1 : U32) * 36 : U32), 0.0)), (kk + 1 : U32),
        (co <> acc))

def band.k(
  hop: Nat, +vec: List<&2, F32>, tab: Array<F32>, +kk: U32, acc: List<&2, F32>
) -> Array<F32> & List<&2, F32>:
  match hop:
    case 0n:
      (tab, f.rev(acc))
    case 1n+p:
      band.step(p, vec, bf.of(bt.dot(vec, tab, (kk * 36 : U32), 0.0)), kk, acc)

def band.row(
  +aa: List<&2, List<&2, F32>>, +cc: List<&2, List<&2, F32>>, tab: Array<F32>, +band: U32
) -> Array<F32> & List<&2, F32>:
  band.k(18n, List.append(&2, F32, col.b(18n, aa, band, []), col.b(18n, cc, band, [])), tab, 0, [])

def flat.bands(xs: List<&2, List<&2, F32>>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      List.append(&2, F32, hd, flat.bands(tl))

# one MDCT row handed back beside the matrix
type Br is Type:
  Br{tab: Array<F32>, row: List<&2, F32>}

def br.of(got: Array<F32> & List<&2, F32>) -> Br:
  (tab, row) = got
  Br{tab, row}

def spec.step(
  hop: Nat, +aa: List<&2, List<&2, F32>>, +cc: List<&2, List<&2, F32>>, got: Br, +band: U32,
  acc: List<&2, List<&2, F32>>
) -> Array<F32> & List<&2, F32>:
  match hop got:
    case 0n Br{tab, row}:
      (tab, flat.bands(f.revs(row <> acc)))
    case 1n+p Br{tab, row}:
      spec.step(p, aa, cc, br.of(band.row(aa, cc, tab, (band + 1 : U32))), (band + 1 : U32),
        (row <> acc))

def spec.bands(
  hop: Nat, +aa: List<&2, List<&2, F32>>, +cc: List<&2, List<&2, F32>>, tab: Array<F32>,
  +band: U32, acc: List<&2, List<&2, F32>>
) -> Array<F32> & List<&2, F32>:
  match hop:
    case 0n:
      (tab, flat.bands(f.revs(acc)))
    case 1n+p:
      spec.step(p, aa, cc, br.of(band.row(aa, cc, tab, band)), band, acc)

def drop.b(hop: Nat, xs: List<&2, List<&2, F32>>) -> List<&2, List<&2, F32>>:
  match hop xs:
    case 0n ys:
      ys
    case _ Nil{}:
      []
    case 1n+p _hd <> tl:
      drop.b(p, tl)

def take.b(
  hop: Nat, xs: List<&2, List<&2, F32>>, acc: List<&2, List<&2, F32>>
) -> List<&2, List<&2, F32>>:
  match hop xs:
    case 0n _:
      f.revs(acc)
    case _ Nil{}:
      f.revs(acc)
    case 1n+p +hd <> tl:
      take.b(p, tl, hd <> acc)

def spec.one(+blocks: List<&2, List<&2, F32>>, tab: Array<F32>) -> Array<F32> & List<&2, F32>:
  spec.bands(32n, take.b(18n, blocks, []), take.b(18n, drop.b(18n, blocks), []), tab, 0, [])

# 576 MDCT bins. Each butterfly reads and writes two of them; a list walks from the head.
type Sa is Type:
  Sa{acc: Array<F32>, cur: F32}

def sa.of(got: Array<F32> & F32) -> Sa:
  (acc, cur) = got
  Sa{acc, cur}

def al.fill(xs: List<&2, F32>, a: Array<F32>, +ii: U32) -> Array<F32>:
  match xs:
    case Nil{}:
      a
    case +hd <> tl:
      al.fill(tl, Array.set(F32, a, ii, hd), (ii + 1 : U32))

# 2^10 slots: one granule is 576 coefficients, filled in list order.
def al.arr(xs: List<&2, F32>) -> Array<F32>:
  al.fill(xs, Array.new(F32, 10n, 0.0), 0)

def al.pull(hop: Nat, got: Sa, +ii: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match hop got:
    case 0n Sa{_acc, +cur}:
      f.rev(cur <> acc)
    case 1n+p Sa{tab, +cur}:
      al.pull(p, sa.of(Array.get(F32, tab, (ii + 1 : U32))), (ii + 1 : U32), (cur <> acc))

def al.list(acc: Array<F32>) -> List<&2, F32>:
  al.pull(575n, sa.of(Array.get(F32, acc, 0)), 0, [])

def al.write(
  acc: Array<F32>, +up: F32, +dp: F32, +c0: F32, +c1: F32, +hi: U32, +lo: U32
) -> Array<F32>:
  Array.set(F32, Array.set(F32, acc, hi, ((c0 * up : F32) + (c1 * dp : F32) : F32)), lo,
    ((F32.neg(c1) * up : F32) + (c0 * dp : F32) : F32))

def al.use(got: Sa, +dp: F32, +c0: F32, +c1: F32, +hi: U32, +lo: U32) -> Array<F32>:
  match got:
    case Sa{acc, +up}:
      al.write(acc, up, dp, c0, c1, hi, lo)

def al.both(got: Sa, +c0: F32, +c1: F32, +hi: U32, +lo: U32) -> Array<F32>:
  match got:
    case Sa{acc, +dp}:
      al.use(sa.of(Array.get(F32, acc, hi)), dp, c0, c1, hi, lo)

def al.one(acc: Array<F32>, +aa: List<&2, F32>, +bb: U32, +ii: U32) -> Array<F32>:
  al.both(sa.of(Array.get(F32, acc, ((bb * 18 : U32) + (17 - ii : U32) : U32))), f.nth(aa, ii),
    f.nth(aa, (ii + 8 : U32)), (((bb + 1 : U32) * 18 : U32) + ii : U32),
    ((bb * 18 : U32) + (17 - ii : U32) : U32))

def al.i(hop: Nat, acc: Array<F32>, +aa: List<&2, F32>, +bb: U32, +ii: U32) -> Array<F32>:
  match hop:
    case 0n:
      acc
    case 1n+p:
      al.i(p, al.one(acc, aa, bb, ii), aa, bb, (ii + 1 : U32))

def al.band(acc: Array<F32>, +aa: List<&2, F32>, +bb: U32) -> Array<F32>:
  al.i(8n, acc, aa, bb, 0)

def al.go(hop: Nat, acc: Array<F32>, +aa: List<&2, F32>, +bb: U32) -> Array<F32>:
  match hop:
    case 0n:
      acc
    case 1n+p:
      al.go(p, al.band(acc, aa, bb), aa, (bb - 1 : U32))

def al.fin(acc: Array<F32>) -> List<&2, F32>:
  al.list(al.go(31n, acc, f.of(Tab.tab.aa()), 30))

def al.run(xs: List<&2, F32>) -> List<&2, F32>:
  al.fin(al.arr(xs))

def spec.read(got: Br) -> Array<F32> & List<&2, F32>:
  match got:
    case Br{tab, row}:
      (tab, al.run(row))

def spec.gran(+blocks: List<&2, List<&2, F32>>, tab: Array<F32>) -> Array<F32> & List<&2, F32>:
  spec.read(br.of(spec.one(blocks, tab)))

def grans.step(
  hop: Nat, +blocks: List<&2, List<&2, F32>>, got: Br, acc: List<&2, List<&2, F32>>
) -> Array<F32> & List<&2, List<&2, F32>>:
  match hop got:
    case 0n Br{tab, row}:
      (tab, f.revs(row <> acc))
    case 1n+p Br{tab, row}:
      grans.step(p, drop.b(18n, blocks), br.of(spec.gran(blocks, tab)), (row <> acc))

def grans.go(
  hop: Nat, +blocks: List<&2, List<&2, F32>>, tab: Array<F32>, acc: List<&2, List<&2, F32>>
) -> Array<F32> & List<&2, List<&2, F32>>:
  match hop:
    case 0n:
      (tab, f.revs(acc))
    case 1n+p:
      grans.step(p, drop.b(18n, blocks), br.of(spec.gran(blocks, tab)), acc)

def grans.np(z: Bool, +nb: U32) -> U32:
  match z:
    case True{}:
      0
    case False{}:
      (U32.div(nb, 18) - 1 : U32)

def grans.n(+nb: U32) -> U32:
  grans.np(U32.is_le(nb, 18), nb)

def bt.put(xs: List<&2, F32>, a: Array<F32>, +ii: U32) -> Array<F32>:
  match xs:
    case Nil{}:
      a
    case +hd <> tl:
      bt.put(tl, Array.set(F32, a, ii, hd), (ii + 1 : U32))

# 2^10 slots: tab.bt is 648 coefficients, filled in list order.
def bt.of() -> Array<F32>:
  bt.put(f.of(Tab.tab.bt()), Array.new(F32, 10n, 0.0), 0)

def gran.fin(got: Array<F32> & List<&2, List<&2, F32>>) -> List<&2, List<&2, F32>>:
  (_tab, xs) = got
  xs

def gran.all(+blocks: List<&2, List<&2, F32>>) -> List<&2, List<&2, F32>>:
  gran.fin(grans.go(U32.to_nat(grans.n(U32.from_nat(List.length(&2, List<&2, F32>, blocks)))), blocks,
    bt.of(), []))

def flip.samp(z: Bool, +vv: F32) -> F32:
  match z:
    case True{}:
      F32.neg(vv)
    case False{}:
      vv

def flip.go(xs: List<&2, F32>, +ii: U32, acc: List<&2, F32>, +odd: Bool) -> List<&2, F32>:
  match xs:
    case Nil{}:
      f.rev(acc)
    case +hd <> tl:
      flip.go(tl, (ii + 1 : U32), flip.samp(odd && U32.is_ne((ii .&. 1 : U32), 0), hd) <> acc, odd)

def flip.one(blk: List<&2, F32>, odd: Bool) -> List<&2, F32>:
  flip.go(blk, 0, [], odd)

def flip.all(xs: List<&2, List<&2, F32>>, +ii: U32, acc: List<&2, List<&2, F32>>) -> List<&2, List<&2, F32>>:
  match xs:
    case Nil{}:
      f.revs(acc)
    case +hd <> tl:
      flip.all(tl, (ii + 1 : U32), flip.one(hd, U32.is_ne((ii .&. 1 : U32), 0)) <> acc)

def ch.specs(xs: List<&2, F32>) -> List<&2, List<&2, F32>>:
  gran.all(flip.all(an.run(xs), 0, []))

# bit packer. completed bytes are newest-first until bw.bytes reverses them.
type Bw is Data:
  Bw{acc: U32, n: U32, out: List<&2, U32>}

def bw.empty() -> Bw:
  Bw{0, 0, []}

def bw.put(full: Bool, +acc: U32, +n: U32, out: List<&2, U32>) -> Bw:
  match full:
    case True{}:
      Bw{0, 0, (acc .&. 255 : U32) <> out}
    case False{}:
      Bw{acc, n, out}

def bw.bit(st: Bw, +bit: U32) -> Bw:
  match st:
    case Bw{+acc, +n, out}:
      bw.put(U32.is_eq(n, 7), ((acc << 1n : U32) .|. (bit .&. 1 : U32) : U32), (n + 1 : U32), out)

def bw.field(hop: Nat, st: Bw, +val: U32) -> Bw:
  match hop:
    case 0n:
      st
    case 1n++p:
      bw.field(p, bw.bit(st, ((val >> p : U32) .&. 1 : U32)), val)

def bw.tail(empty: Bool, +acc: U32, +n: U32, out: List<&2, U32>) -> List<&2, U32>:
  match empty:
    case True{}:
      List.reverse(&2, U32, out)
    case False{}:
      List.reverse(&2, U32, (((acc << U32.to_nat((8 - n : U32)) : U32) .&. 255 : U32) <> out))

def bw.bytes(st: Bw) -> List<&2, U32>:
  match st:
    case Bw{+acc, +n, out}:
      bw.tail(U32.is_eq(n, 0), acc, n, out)

def pk.sr(+hz: U32) -> U32:
  match hz:
    case 48000:
      4
    case 32000:
      8
    case _:
      0

def pk.mode(+ch: U32) -> U32:
  match ch:
    case 1:
      196
    case _:
      4

def pk.hdr(+hz: U32, +ch: U32) -> List<&2, U32>:
  [255, 251, (224 .|. pk.sr(hz) : U32), pk.mode(ch)]

def pk.fsz(+hz: U32) -> U32:
  U32.div(((1152 * 320 : U32) * 125 : U32), hz)

def pk.sidebits(+ch: U32) -> U32:
  match ch:
    case 1:
      136
    case _:
      256

def pk.bud(+hz: U32, +ch: U32) -> U32:
  (U32.div((((pk.fsz(hz) * 8 : U32) - 32 : U32) - pk.sidebits(ch) : U32), (ch * 2 : U32)) - 8 : U32)

def blk.up(+n: U32) -> U32:
  U32.div((n + 31 : U32), 32)

def blk.q(+b: U32) -> U32:
  U32.div((b + 17 : U32), 18)

def blk.fix(even: Bool, +q: U32) -> U32:
  match even:
    case True{}:
      ((q + 1 : U32) * 18 : U32)
    case False{}:
      (q * 18 : U32)

def blk.odd(+q: U32) -> U32:
  blk.fix(U32.is_eq((q .&. 1 : U32), 0), q)

def blk.at(small: Bool, +b: U32) -> U32:
  match small:
    case True{}:
      54
    case False{}:
      blk.odd(blk.q(b))

def blk.n(+n: U32) -> U32:
  blk.at(U32.is_lt(blk.up(n), 54), blk.up(n))

def enc.need(+n: U32) -> U32:
  (blk.n(n) * 32 : U32)

def enc.zero(short: Bool, +have: U32, +need: U32) -> U32:
  match short:
    case True{}:
      (need - have : U32)
    case False{}:
      0

def enc.extra(+have: U32, +need: U32) -> U32:
  enc.zero(U32.is_le(have, need), have, need)

def side.priv(+ch: U32) -> U32:
  match ch:
    case 1:
      5
    case _:
      3

def side.head(st: Bw, +ch: U32) -> Bw:
  bw.field(U32.to_nat((ch * 4 : U32)), bw.field(U32.to_nat(side.priv(ch)), bw.field(9n, st, 0), 0), 0)

def side.mid(st: Bw, +part: U32, +big: U32, +gain: U32) -> Bw:
  bw.field(1n, bw.field(4n, bw.field(8n, bw.field(9n, bw.field(12n, st, part), big), gain), 0), 0)

def side.tabs(st: Bw, +tab: U32) -> Bw:
  bw.field(3n, bw.field(4n, bw.field(5n, bw.field(5n, bw.field(5n, st, tab), tab), tab), 15), 5)

def side.end(st: Bw) -> Bw:
  bw.field(1n, bw.field(1n, bw.field(1n, st, 0), 0), 0)

def side.gr(st: Bw, g: Gr) -> Bw:
  match g:
    case Gr{+part, +big, +gain, +tab, _bits}:
      side.end(side.tabs(side.mid(st, part, big, gain), tab))

def side.grs(gs: List<&2, Gr>, st: Bw) -> Bw:
  match gs:
    case Nil{}:
      st
    case +hd <> tl:
      side.grs(tl, side.gr(st, hd))

def side.bytes(gs: List<&2, Gr>, +ch: U32) -> List<&2, U32>:
  bw.bytes(side.grs(gs, side.head(bw.empty(), ch)))

def body.bits(xs: List<&2, U32>, st: Bw) -> Bw:
  match xs:
    case Nil{}:
      st
    case +hd <> tl:
      body.bits(tl, bw.bit(st, hd))

def body.one(g: Gr, st: Bw) -> Bw:
  match g:
    case Gr{_part, _big, _gain, _tab, bits}:
      body.bits(bits, st)

def body.grs(gs: List<&2, Gr>, st: Bw) -> Bw:
  match gs:
    case Nil{}:
      st
    case +hd <> tl:
      body.grs(tl, body.one(hd, st))

def pk.pad(+xs: List<&2, U32>, +fsz: U32) -> List<&2, U32>:
  List.append(&2, U32, xs, List.replicate(U32,
    U32.to_nat(enc.extra(U32.from_nat(List.length(&2, U32, xs)), fsz)), 0))

def pk.fit(head: List<&2, U32>, body: List<&2, U32>, +fsz: U32) -> List<&2, U32>:
  pk.pad(List.append(&2, U32, head, body), fsz)

def pk.one(+gs: List<&2, Gr>, +hz: U32, +ch: U32) -> List<&2, U32>:
  pk.fit(List.append(&2, U32, pk.hdr(hz, ch), side.bytes(gs, ch)), bw.bytes(body.grs(gs, bw.empty())),
    pk.fsz(hz))

# one Huffman pair (mag, 0) in the first granule. global_gain stays 0.
def pulse.gr(b: Best) -> Gr:
  match b:
    case Best{+tab, _nn, bits, +ok}:
      gr.u(U32.is_eq(ok, 1), 0, tab, bits, 1)

def pulse.clamp(small: Bool, +w: U32) -> U32:
  match small:
    case True{}:
      w
    case False{}:
      15

def pulse.mag0(z: Bool, +w: U32) -> U32:
  match z:
    case True{}:
      1
    case False{}:
      pulse.clamp(U32.is_lt(w, 16), w)

def pulse.mag(+w: U32) -> U32:
  pulse.mag0(U32.is_eq(w, 0), w)

def pulse.frame(+hz: U32, +mag: U32) -> List<&2, U32>:
  pk.one([pulse.gr(best.of([mag, 0])), Gr{0, 0, 0, 0, []}], hz, 1)

def pk.chan(
  specs: List<&2, List<&2, F32>>, +hz: U32, +bud: U32, acc: List<&2, Gr>
) -> List<&2, Gr>:
  match specs:
    case Nil{}:
      List.reverse(&2, Gr, acc)
    case +hd <> tl:
      pk.chan(tl, hz, bud, gr.of(hd, hz, bud) <> acc)

def pk.buf(done: Bool, buf: List<&2, Gr>, +g: Gr) -> List<&2, Gr>:
  match done:
    case True{}:
      []
    case False{}:
      g <> buf

def pk.have(done: Bool, +have: U32) -> U32:
  match done:
    case True{}:
      0
    case False{}:
      (have + 1 : U32)

def pk.acc(
  done: Bool, buf: List<&2, Gr>, +g: Gr, +hz: U32, +ch: U32, acc: List<&2, List<&2, U32>>
) -> List<&2, List<&2, U32>>:
  match done:
    case True{}:
      pk.one(List.reverse(&2, Gr, g <> buf), hz, ch) <> acc
    case False{}:
      acc

def pk.step(
  gs: List<&2, Gr>, +buf: List<&2, Gr>, +have: U32, +per: U32, +hz: U32, +ch: U32,
  acc: List<&2, List<&2, U32>>
) -> List<&2, List<&2, U32>>:
  match gs:
    case Nil{}:
      List.reverse(&2, List<&2, U32>, acc)
    case +hd <> tl:
      pk.step(tl, pk.buf(U32.is_eq((have + 1 : U32), per), buf, hd),
        pk.have(U32.is_eq((have + 1 : U32), per), have), per, hz, ch,
        pk.acc(U32.is_eq((have + 1 : U32), per), buf, hd, hz, ch, acc))

def pk.zip(ls: List<&2, Gr>, rs: List<&2, Gr>, acc: List<&2, Gr>) -> List<&2, Gr>:
  match ls rs:
    case +l <> lt +r <> rt:
      pk.zip(lt, rt, r <> l <> acc)
    case _ _:
      List.reverse(&2, Gr, acc)

def enc.grow(+xs: List<&2, F32>) -> List<&2, F32>:
  List.append(&2, F32, xs, List.replicate(F32, U32.to_nat(enc.extra(
    U32.from_nat(List.length(&2, F32, xs)), enc.need(U32.from_nat(List.length(&2, F32, xs))))), 0.0))

def enc.chgr(xs: List<&2, F32>, +hz: U32, +bud: U32) -> List<&2, Gr>:
  pk.chan(ch.specs(enc.grow(xs)), hz, bud, [])

def s16.f(neg: Bool, +w: U32) -> F32:
  match neg:
    case False{}:
      (U32.to_f32((w .&. 65535 : U32)) / 32768.0 : F32)
    case True{}:
      F32.neg((U32.to_f32((65536 - (w .&. 65535 : U32) : U32)) / 32768.0 : F32))

def samp.of(+kind: U32, +w: U32) -> F32:
  match kind:
    case 1:
      s16.f(U32.is_ne((w .&. 32768 : U32), 0), w)
    case _:
      f32.bits(w)

def pcm.go(+kind: U32, xs: List<&2, U32>, acc: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      f.rev(acc)
    case +hd <> tl:
      pcm.go(kind, tl, samp.of(kind, hd) <> acc)

# deinterleaved channels, newest sample first until split.go reverses them
type Chs is Data:
  Chs{l: List<&2, F32>, r: List<&2, F32>}

def split.rev(c: Chs) -> Chs:
  match c:
    case Chs{l, r}:
      Chs{f.rev(l), f.rev(r)}

def split.on(leftb: Bool, +v: F32, l: List<&2, F32>, r: List<&2, F32>) -> Chs:
  match leftb:
    case True{}:
      Chs{v <> l, r}
    case False{}:
      Chs{l, v <> r}

def split.put(c: Chs, +v: F32, +phase: U32) -> Chs:
  match c:
    case Chs{l, r}:
      split.on(U32.is_eq(phase, 0), v, l, r)

def split.flip(z: Bool) -> U32:
  match z:
    case True{}:
      1
    case False{}:
      0

def split.ph(mono: Bool, +phase: U32) -> U32:
  match mono:
    case True{}:
      0
    case False{}:
      split.flip(U32.is_eq(phase, 0))

def split.next(+ch: U32, +phase: U32) -> U32:
  split.ph(U32.is_eq(ch, 1), phase)

def split.go(xs: List<&2, F32>, +ch: U32, c: Chs, +phase: U32) -> Chs:
  match xs:
    case Nil{}:
      split.rev(c)
    case +hd <> tl:
      split.go(tl, ch, split.put(c, hd, phase), split.next(ch, phase))

def enc.flat(xs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      List.append(&2, U32, hd, enc.flat(tl))

def enc.mono(+hz: U32, left: List<&2, F32>) -> List<&2, List<&2, U32>>:
  pk.step(enc.chgr(left, hz, pk.bud(hz, 1)), [], 0, 2, hz, 1, [])

def enc.stereo(+hz: U32, left: List<&2, F32>, right: List<&2, F32>) -> List<&2, List<&2, U32>>:
  pk.step(pk.zip(enc.chgr(left, hz, pk.bud(hz, 2)), enc.chgr(right, hz, pk.bud(hz, 2)), []), [], 0,
    4, hz, 2, [])

def enc.chs(
  mono: Bool, +hz: U32, left: List<&2, F32>, right: List<&2, F32>
) -> List<&2, List<&2, U32>>:
  match mono:
    case True{}:
      enc.mono(hz, left)
    case False{}:
      enc.stereo(hz, left, right)

def enc.some(empty: Bool, +xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match empty:
    case True{}:
      None{}
    case False{}:
      Some{xs}

def enc.packed(+xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  enc.some(U32.is_eq(U32.from_nat(List.length(&2, U32, xs)), 0), xs)

def enc.out(mono: Bool, +hz: U32, l: List<&2, F32>, r: List<&2, F32>) -> Maybe<&2, List<&2, U32>>:
  enc.packed(enc.flat(enc.chs(mono, hz, l, r)))

def enc.from(c: Chs, +hz: U32, +ch: U32) -> Maybe<&2, List<&2, U32>>:
  match c:
    case Chs{l, r}:
      enc.out(U32.is_eq(ch, 1), hz, l, r)

def enc.kind(+k: U32) -> Bool:
  match k:
    case 1:
      True{}
    case 3:
      True{}
    case _:
      False{}

def enc.go(+hz: U32, +ch: U32, +kind: U32, frames: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  enc.from(split.go(pcm.go(kind, frames, []), ch, Chs{[], []}, 0), hz, ch)

def enc.finish(
  ok: Bool, +hz: U32, +ch: U32, +kind: U32, frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      enc.go(hz, ch, kind, frames)

def enc.run(
  +hz: U32, +ch: U32, +kind: U32, frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  enc.finish(enc.kind(kind), hz, ch, kind, frames)
