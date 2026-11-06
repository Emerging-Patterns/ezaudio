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

def y.pull(hop: Nat, got: Ya, +ii: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match hop got:
    case 0n Ya{_acc, +cur}:
      f.rev(cur <> acc)
    case 1n+p Ya{tab, +cur}:
      y.pull(p, ya.of(Array.get(F32, tab, (ii + 1 : U32))), (ii + 1 : U32), (cur <> acc))

def y.list(acc: Array<F32>) -> List<&2, F32>:
  y.pull(63n, ya.of(Array.get(F32, acc, 0)), 0, [])

# delay sample handed back beside the ring Array.get just read
type Xs is Type:
  Xs{x: Array<F32>, samp: F32}

def xs.of(got: Array<F32> & F32) -> Xs:
  (x, samp) = got
  Xs{x, samp}

# ring delay beside the 64 partial bins while windowing
type Yr is Type:
  Yr{x: Array<F32>, bins: Array<F32>}

def y.step(got: Xs, bins: Array<F32>, +w: F32, +ii: U32) -> Yr:
  match got:
    case Xs{x2, +samp}:
      Yr{x2, y.add(bins, ii, (samp * w : F32))}

# window the 512-slot ring in place: multiply by win and fold into 64 bins
def y.ring(
  win: List<&2, F32>, got: Yr, +head: U32, +k: U32, +ii: U32
) -> Yr:
  match win got:
    case Nil{} yr:
      yr
    case +w <> tl Yr{x, bins}:
      y.ring(tl, y.step(xs.of(Array.get(F32, x, ((head + k : U32) .&. 511 : U32))), bins, w, ii),
        head, (k + 1 : U32), y.wrap(U32.is_eq(ii, 63), ii))

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

# subband result: ring delay returned beside the cosine table and 32 bands
type As is Type:
  As{x: Array<F32>, cos: Array<F32>, sb: List<&2, F32>}

def as.of(x: Array<F32>, got: Array<F32> & List<&2, F32>) -> As:
  (cos, sb) = got
  As{x, cos, sb}

def an.sb1(got: Yr, cos: Array<F32>) -> As:
  match got:
    case Yr{x2, bins}:
      as.of(x2, sb.rows(32n, cos, y.list(bins), 0, []))

# subband samples of one ring state. head indexes the oldest of 512 samples.
def an.sb(
  x: Array<F32>, +head: U32, +win: List<&2, F32>, cos: Array<F32>
) -> As:
  an.sb1(y.ring(win, Yr{x, Array.new(F32, 6n, 0.0)}, head, 0, 0), cos)

# analysis delay ring (2^9 slots) and finished subband blocks, newest block first
type An is Type:
  An{x: Array<F32>, head: U32, out: List<&2, List<&2, F32>>}

def an.done(+head: U32, out: List<&2, List<&2, F32>>, got: As) -> An & Array<F32>:
  match got:
    case As{x, cos, sb}:
      (An{x, head, sb <> out}, cos)

# overwrite the oldest 32 ring slots, then advance head
def an.write(hop: Nat, x: Array<F32>, +at: U32, blk: List<&2, F32>) -> Array<F32>:
  match hop blk:
    case 0n _:
      x
    case _ Nil{}:
      x
    case 1n+p +hd <> tl:
      an.write(p, Array.set(F32, x, at, hd), ((at + 1 : U32) .&. 511 : U32), tl)

def an.push(st: An, blk: List<&2, F32>, +win: List<&2, F32>, cos: Array<F32>) -> An & Array<F32>:
  match st:
    case An{x, +head, out}:
      an.done(((head + 32 : U32) .&. 511 : U32), out,
        an.sb(an.write(32n, x, head, blk), ((head + 32 : U32) .&. 511 : U32), win, cos))

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

# 2^9 slots: 512-sample analysis delay, zero-filled, head at the oldest sample.
def an.zero() -> An:
  An{Array.new(F32, 9n, 0.0), 0, []}

# subband frames, newest block first. each block is 32 bands.
def f.revs(xs: List<&2, List<&2, F32>>) -> List<&2, List<&2, F32>>:
  List.reverse(&2, List<&2, F32>, xs)

def an.out(st: An) -> List<&2, List<&2, F32>>:
  match st:
    case An{_x, _head, out}:
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

def q.sign(neg: Bool, +mag: U32) -> U32:
  match neg:
    case False{}:
      mag
    case True{}:
      (0 - mag : U32)

def q.pws(neg: Bool, +pp: F32) -> F32:
  match neg:
    case True{}:
      F32.neg(pp)
    case False{}:
      pp

# |xr| ^ 0.75 with the sign of xr, once per granule rather than once per gain tried
def q.pw(+xr: F32) -> F32:
  q.pws(F32.is_lt(xr, 0.0), F32.pow(F32.abs(xr), 0.75))

def pw.all(xs: List<&2, F32>) -> List<&2, F32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      q.pw(hd) <> pw.all(tl)

# 8206 = 15 + 8191, the largest value table 31 holds
def q.big(fit: Bool, +vv: F32) -> U32:
  match fit:
    case True{}:
      F32.to_u32(F32.round(vv))
    case False{}:
      8206

def q.amp(+vv: F32) -> U32:
  q.big(F32.is_lt(vv, 8206.0), vv)

# ix = round((|xr| / gain) ^ 0.75), from |xr| ^ 0.75 and gain ^ -0.75
def q.one(+pp: F32, +ginv: F32) -> U32:
  q.sign(F32.is_lt(pp, 0.0), q.amp((F32.abs(pp) * ginv : F32)))

def q.all(xs: List<&2, F32>, +ginv: F32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      q.one(hd, ginv) <> q.all(tl, ginv)

def gain.inv(+gg: U32) -> F32:
  (1.0 / F32.pow(gain.of(gg), 0.75) : F32)

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

def ix.p(zz: Bool, +mm: U32, +aa: U32) -> U32:
  match zz:
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

def b.u(bb: Bool) -> U32:
  match bb:
    case True{}:
      1
    case False{}:
      0

# Huffman words of tables 13, 15, 16 and 24 (16-23 and 24-31 share codes), 2^10 leaves
type Ht is Data:
  Hleaf{w: U32}
  Hnode{lo: Ht, hi: Ht}

def ht.leaves(xs: List<&2, U32>) -> List<&2, Ht>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      Hleaf{hd} <> ht.leaves(tl)

def ht.pair(xs: List<&2, Ht>) -> List<&2, Ht>:
  match xs:
    case aa <> bb <> tl:
      Hnode{aa, bb} <> ht.pair(tl)
    case _:
      []

def ht.up(hop: Nat, xs: List<&2, Ht>) -> List<&2, Ht>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      ht.up(p, ht.pair(xs))

def ht.root(xs: List<&2, Ht>) -> Ht:
  match xs:
    case Nil{}:
      Hleaf{0}
    case hd <> _tl:
      hd

def ht.cat(
  aa: List<&2, U32>,
  bb: List<&2, U32>,
  cc: List<&2, U32>,
  dd: List<&2, U32>
) -> List<&2, U32>:
  List.append(&2, U32, aa, List.append(&2, U32, bb, List.append(&2, U32, cc, dd)))

# built once per clip and shared by every granule
def ht.of() -> Ht:
  ht.root(ht.up(10n, ht.leaves(ht.cat(Tab.tab.code.p13(), Tab.tab.code.p15(), Tab.tab.code.p16(),
    Tab.tab.code.p24()))))

def ht.sel(bit: Bool, lo: Ht, hi: Ht) -> Ht:
  match bit:
    case True{}:
      hi
    case False{}:
      lo

# the leaf at ix, its high bit first
def ht.get(hop: Nat, tt: Ht, +ix: U32) -> U32:
  match hop tt:
    case _ Hleaf{w}:
      w
    case 1n+(+p) Hnode{lo, hi}:
      ht.get(p, ht.sel(U32.is_ne(((ix >> p : U32) .&. 1 : U32), 0), lo, hi), ix)
    case 0n Hnode{_lo, _hi}:
      0

# the subtree of a table: 13, 15, 16-23, 24-31
def ht.hi(big: Bool) -> U32:
  match big:
    case True{}:
      3
    case False{}:
      2

def ht.slot(+tab: U32) -> U32:
  match tab:
    case 13:
      0
    case 15:
      1
    case _:
      ht.hi(U32.is_ge(tab, 24))

# a code word: its length in the high half, the code in the low half
def ht.word(+ht: Ht, +slot: U32, +ca: U32, +cb: U32) -> U32:
  ht.get(10n, ht, (((slot * 256 : U32) + (ca * 16 : U32) : U32) + cb : U32))

def lin.of(+tab: U32) -> U32:
  u.nth(Tab.tab.lin(), tab)

# values that fit a table: 0-15 without linbits, below 15 + 2^linbits with them
def lim.p(zz: Bool, +lin: U32) -> U32:
  match zz:
    case True{}:
      16
    case False{}:
      (15 + ((1 << U32.to_nat(lin) : U32)) : U32)

def lim.of(+lin: U32) -> U32:
  lim.p(U32.is_eq(lin, 0), lin)

# a value of 15 and up is the escape 15 plus linbits
def esc.of(+lin: U32, +aa: U32) -> Bool:
  Bool.and(U32.is_ne(lin, 0), U32.is_ge(aa, 15))

def cap.p(big: Bool, +aa: U32) -> U32:
  match big:
    case True{}:
      15
    case False{}:
      aa

def cap.of(+lin: U32, +aa: U32) -> U32:
  cap.p(esc.of(lin, aa), aa)

# bits newest first: a field pushed from its high bit
def hb.field(hop: Nat, bs: List<&2, U32>, +val: U32) -> List<&2, U32>:
  match hop:
    case 0n:
      bs
    case 1n+(+p):
      hb.field(p, ((val >> p : U32) .&. 1 : U32) <> bs, val)

def hb.lin(zz: Bool, bs: List<&2, U32>, +lin: U32, +ext: U32) -> List<&2, U32>:
  match zz:
    case True{}:
      hb.field(U32.to_nat(lin), bs, ext)
    case False{}:
      bs

def hb.sgn(zz: Bool, bs: List<&2, U32>, +vv: U32) -> List<&2, U32>:
  match zz:
    case True{}:
      b.u(i.neg(vv)) <> bs
    case False{}:
      bs

# ISO/IEC 11172-3 2.4.2.7: the pair's code word, then x's linbits and sign, then y's
def hb.pair(
  bs: List<&2, U32>,
  +ww: U32,
  +av: U32,
  +bv: U32,
  +aa: U32,
  +bb: U32,
  +lin: U32
) -> List<&2, U32>:
  hb.sgn(U32.is_ne(bb, 0), hb.lin(esc.of(lin, bb), hb.sgn(U32.is_ne(aa, 0), hb.lin(esc.of(lin, aa),
    hb.field(U32.to_nat((ww >> 16n : U32)), bs, (ww .&. 65535 : U32)), lin, (aa - 15 : U32)), av), lin,
    (bb - 15 : U32)), bv)

# Huffman bits of a granule so far, newest first, and whether every pair fit
type Hk is Data:
  Hk{bits: List<&2, U32>, ok: Bool}

def hk.put(ok: Bool, bits: List<&2, U32>) -> Hk:
  match ok:
    case True{}:
      Hk{bits, True{}}
    case False{}:
      Hk{[], False{}}

def hk.fits(+ww: U32, +aa: U32, +bb: U32, +lin: U32) -> Bool:
  Bool.and(U32.is_ne((ww >> 16n : U32), 0), Bool.and(U32.is_lt(aa, lim.of(lin)), U32.is_lt(bb, lim.of(lin))))

def hk.word(st: Hk, +ww: U32, +av: U32, +bv: U32, +aa: U32, +bb: U32, +lin: U32) -> Hk:
  match st:
    case Hk{bs, ok}:
      hk.put(Bool.and(ok, hk.fits(ww, aa, bb, lin)), hb.pair(bs, ww, av, bv, aa, bb, lin))

def hk.abs(st: Hk, +ht: Ht, +tab: U32, +lin: U32, +av: U32, +bv: U32, +aa: U32, +bb: U32) -> Hk:
  hk.word(st, ht.word(ht, ht.slot(tab), cap.of(lin, aa), cap.of(lin, bb)), av, bv, aa, bb, lin)

def hk.go(xs: List<&2, U32>, +ht: Ht, +tab: U32, +lin: U32, st: Hk) -> Hk:
  match xs:
    case Nil{}:
      st
    case +av <> +bv <> tl:
      hk.go(tl, ht, tab, lin, hk.abs(st, ht, tab, lin, av, bv, i.abs(av), i.abs(bv)))
    case _:
      Hk{[], False{}}

def hk.fin(st: Hk) -> Maybe<&2, List<&2, U32>>:
  match st:
    case Hk{bs, True{}}:
      Some{List.reverse(&2, U32, bs)}
    case Hk{_bs, False{}}:
      None{}

# the big_values pairs in table tab, in stream order; none when a value or pair does not fit it
def hf.code(+ht: Ht, xs: List<&2, U32>, +tab: U32) -> Maybe<&2, List<&2, U32>>:
  hk.fin(hk.go(xs, ht, tab, lin.of(tab), Hk{[], True{}}))

# a count of one table's bits before linbits: code lengths and signs, and the escapes
type Hcnt is Data:
  Hcnt{nn: U32, esc: U32, ok: Bool}

def hc.esc(grp: Bool, +aa: U32) -> U32:
  match grp:
    case True{}:
      b.u(U32.is_ge(aa, 15))
    case False{}:
      0

def hc.cap(grp: Bool, +aa: U32) -> U32:
  match grp:
    case True{}:
      cap.p(U32.is_ge(aa, 15), aa)
    case False{}:
      aa

def hc.fit(grp: Bool, +aa: U32, +bb: U32) -> Bool:
  match grp:
    case True{}:
      True{}
    case False{}:
      Bool.and(U32.is_le(aa, 15), U32.is_le(bb, 15))

def hc.add(st: Hcnt, +ww: U32, +aa: U32, +bb: U32, +ea: U32, +eb: U32, fit: Bool) -> Hcnt:
  match st:
    case Hcnt{+nn, +esc, ok}:
      Hcnt{(((nn + (ww >> 16n : U32) : U32) + b.u(U32.is_ne(aa, 0)) : U32) + b.u(U32.is_ne(bb, 0)) : U32),
        ((esc + ea : U32) + eb : U32), Bool.and(ok, Bool.and(fit, U32.is_ne((ww >> 16n : U32), 0)))}

def hc.pair(st: Hcnt, +ht: Ht, +slot: U32, +grp: Bool, +aa: U32, +bb: U32) -> Hcnt:
  hc.add(st, ht.word(ht, slot, hc.cap(grp, aa), hc.cap(grp, bb)), aa, bb, hc.esc(grp, aa), hc.esc(grp, bb),
    hc.fit(grp, aa, bb))

# grp: the table has linbits, so 15 and up count as an escape
def hc.go(xs: List<&2, U32>, +ht: Ht, +slot: U32, +grp: Bool, st: Hcnt) -> Hcnt:
  match xs:
    case Nil{}:
      st
    case +av <> +bv <> tl:
      hc.go(tl, ht, slot, grp, hc.pair(st, ht, slot, grp, i.abs(av), i.abs(bv)))
    case _:
      Hcnt{0, 0, False{}}

# a candidate table and its bit count
type Cand is Data:
  Cand{tab: U32, nn: U32, ok: Bool}

def cd.of(+tab: U32, +lin: U32, st: Hcnt) -> Cand:
  match st:
    case Hcnt{+nn, +esc, ok}:
      Cand{tab, (nn + (lin * esc : U32) : U32), ok}

def cd.take(bok: Bool, bb: Bool) -> Bool:
  match bok:
    case False{}:
      False{}
    case True{}:
      bb

def cd.keep(take: Bool, aa: Cand, bb: Cand) -> Cand:
  match take:
    case True{}:
      bb
    case False{}:
      aa

def cd.cmp(+an: U32, aok: Bool, bok: Bool, +bn: U32) -> Bool:
  match aok:
    case False{}:
      bok
    case True{}:
      cd.take(bok, U32.is_lt(bn, an))

# the first candidate unless the second fits and is strictly shorter
def cd.min(aa: Cand, bb: Cand) -> Cand:
  match aa bb:
    case Cand{+at, +an, +aok} Cand{+bt, +bn, +bok}:
      cd.keep(cd.cmp(an, aok, bok, bn), Cand{at, an, aok}, Cand{bt, bn, bok})

# tables 15 then 13: no linbits, values up to 15
def cd.plain(small: Bool, +ht: Ht, +xs: List<&2, U32>) -> Cand:
  match small:
    case True{}:
      cd.min(cd.of(15, 0, hc.go(xs, ht, 1, False{}, Hcnt{0, 0, True{}})),
        cd.of(13, 0, hc.go(xs, ht, 0, False{}, Hcnt{0, 0, True{}})))
    case False{}:
      Cand{0, 0, False{}}

def grp.keep(+got: U32, fit: Bool, +tab: U32) -> U32:
  match fit:
    case True{}:
      ix.p(U32.is_eq(got, 0), got, tab)
    case False{}:
      got

# the first table of a group whose linbits hold the largest value, or 0
def grp.tab(hop: Nat, +tab: U32, +mx: U32, +got: U32) -> U32:
  match hop:
    case 0n:
      got
    case 1n+p:
      grp.tab(p, (tab + 1 : U32), mx, grp.keep(got, U32.is_lt(mx, lim.of(lin.of(tab))), tab))

def cd.at(none: Bool, +tab: U32, +ht: Ht, +xs: List<&2, U32>, +slot: U32) -> Cand:
  match none:
    case True{}:
      Cand{0, 0, False{}}
    case False{}:
      cd.of(tab, lin.of(tab), hc.go(xs, ht, slot, True{}, Hcnt{0, 0, True{}}))

# tables sharing one code differ by linbits: the fewest that hold mx cost the least
def cd.grp(+tab: U32, +ht: Ht, +xs: List<&2, U32>, +slot: U32) -> Cand:
  cd.at(U32.is_eq(tab, 0), tab, ht, xs, slot)

# ISO/IEC 11172-3 tables 13, 15, 16-23, 24-31: the cheapest that codes the pairs
def cd.best(+ht: Ht, +xs: List<&2, U32>, +mx: U32) -> Cand:
  cd.min(cd.min(cd.plain(U32.is_le(mx, 15), ht, xs), cd.grp(grp.tab(8n, 16, mx, 0), ht, xs, 2)),
    cd.grp(grp.tab(8n, 24, mx, 0), ht, xs, 3))

# binary search for the finest global_gain that fits the bit budget, with its table and values
type Sr is Data:
  Sr{lo: U32, hi: U32, gg: U32, tab: U32, ix: List<&2, U32>, ok: Bool}

def sr.fit(
  good: Bool,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +tab: U32,
  ix: List<&2, U32>,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  match good:
    case True{}:
      Sr{lo, (mid - 1 : U32), mid, tab, ix, True{}}
    case False{}:
      Sr{(mid + 1 : U32), hi, ogg, otab, oix, ook}

def sr.good(ok: Bool, +nn: U32, +bud: U32, +mx: U32) -> Bool:
  Bool.and(ok, Bool.and(U32.is_le(nn, bud), U32.is_lt(mx, 8000)))

def sr.cd(
  cd: Cand,
  +mx: U32,
  +bud: U32,
  ix: List<&2, U32>,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  match cd:
    case Cand{+tab, +nn, ok}:
      sr.fit(sr.good(ok, nn, bud, mx), lo, hi, mid, tab, ix, ogg, otab, oix, ook)

def sr.mx(
  +mx: U32,
  +xs: List<&2, U32>,
  +ht: Ht,
  +bud: U32,
  ix: List<&2, U32>,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  sr.cd(cd.best(ht, xs, mx), mx, bud, ix, lo, hi, mid, ogg, otab, oix, ook)

def sr.pairs(
  +xs: List<&2, U32>,
  ix: List<&2, U32>,
  +ht: Ht,
  +bud: U32,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  sr.mx(ix.max(xs, 0), xs, ht, bud, ix, lo, hi, mid, ogg, otab, oix, ook)

def sr.zero(
  zz: Bool,
  +big: U32,
  +ix: List<&2, U32>,
  +ht: Ht,
  +bud: U32,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  match zz:
    case True{}:
      sr.fit(True{}, lo, hi, mid, 0, ix, ogg, otab, oix, ook)
    case False{}:
      sr.pairs(take.u(U32.to_nat((big * 2 : U32)), ix, []), ix, ht, bud, lo, hi, mid, ogg, otab, oix, ook)

def sr.big(
  +big: U32,
  +ix: List<&2, U32>,
  +ht: Ht,
  +bud: U32,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  sr.zero(U32.is_eq(big, 0), big, ix, ht, bud, lo, hi, mid, ogg, otab, oix, ook)

def sr.q(
  +ix: List<&2, U32>,
  +hz: U32,
  +bud: U32,
  +ht: Ht,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +ogg: U32,
  +otab: U32,
  oix: List<&2, U32>,
  ook: Bool
) -> Sr:
  sr.big(bv.of(ix, hz), ix, ht, bud, lo, hi, mid, ogg, otab, oix, ook)

def sr.try(
  +spec: List<&2, F32>,
  +hz: U32,
  +bud: U32,
  +ht: Ht,
  +lo: U32,
  +hi: U32,
  +mid: U32,
  +gg: U32,
  +tab: U32,
  ix: List<&2, U32>,
  ok: Bool
) -> Sr:
  sr.q(q.all(spec, gain.inv(mid)), hz, bud, ht, lo, hi, mid, gg, tab, ix, ok)

def sr.live(
  go: Bool,
  +spec: List<&2, F32>,
  +hz: U32,
  +bud: U32,
  +ht: Ht,
  +lo: U32,
  +hi: U32,
  +gg: U32,
  +tab: U32,
  ix: List<&2, U32>,
  ok: Bool
) -> Sr:
  match go:
    case False{}:
      Sr{lo, hi, gg, tab, ix, ok}
    case True{}:
      sr.try(spec, hz, bud, ht, lo, hi, U32.div((lo + hi : U32), 2), gg, tab, ix, ok)

def sr.step(+spec: List<&2, F32>, +hz: U32, +bud: U32, +ht: Ht, st: Sr) -> Sr:
  match st:
    case Sr{+lo, +hi, +gg, +tab, ix, ok}:
      sr.live(U32.is_le(lo, hi), spec, hz, bud, ht, lo, hi, gg, tab, ix, ok)

# 8 halvings settle a global_gain in 0..255; spec holds |xr| ^ 0.75
def sr.go(hop: Nat, +spec: List<&2, F32>, +hz: U32, +bud: U32, +ht: Ht, st: Sr) -> Sr:
  match hop:
    case 0n:
      st
    case 1n+p:
      sr.go(p, spec, hz, bud, ht, sr.step(spec, hz, bud, ht, st))

def sr.run(+spec: List<&2, F32>, +hz: U32, +bud: U32, +ht: Ht) -> Sr:
  sr.go(8n, pw.all(spec), hz, bud, ht, Sr{0, 255, 0, 0, [], False{}})

def pk.p(zz: Bool, +mm: F32, +aa: F32) -> F32:
  match zz:
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

def dz.one(zz: Bool, +vv: F32) -> F32:
  match zz:
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
  done: Bool,
  st: Sr,
  +spec: List<&2, F32>,
  +pk: F32,
  +thr: U32,
  +hz: U32,
  +bud: U32,
  +ht: Ht
) -> Sr:
  match done:
    case True{}:
      st
    case False{}:
      sr.run(dz.apply(spec, (pk * f32.bits(thr) : F32)), hz, bud, ht)

def dz.try(st: Sr, +spec: List<&2, F32>, +pk: F32, +thr: U32, +hz: U32, +bud: U32, +ht: Ht) -> Sr:
  match st:
    case Sr{+lo, +hi, +gg, +tab, ix, +ok}:
      dz.on(ok, Sr{lo, hi, gg, tab, ix, ok}, spec, pk, thr, hz, bud, ht)

# a dead zone below thr * peak, wider until a gain fits
def dz.go(
  thrs: List<&2, U32>,
  +spec: List<&2, F32>,
  +pk: F32,
  +hz: U32,
  +bud: U32,
  +ht: Ht,
  st: Sr
) -> Sr:
  match thrs:
    case Nil{}:
      st
    case +hd <> tl:
      dz.go(tl, spec, pk, hz, bud, ht, dz.try(st, spec, pk, hd, hz, bud, ht))

def dz.thrs() -> List<&2, U32>:
  [953267991, 981668463, 994352038, 1008981770, 1022739087, 1036831949, 1045220557, 1053609165]

# one coded granule: part2_3_length, big_values, global_gain, table, the quantized values, the bits
type Gr is Data:
  Gr{part: U32, big: U32, gain: U32, tab: U32, ix: List<&2, U32>, bits: List<&2, U32>}

def gr.part(gg: Gr) -> U32:
  match gg:
    case Gr{part, _big, _gain, _tab, _ix, _bits}:
      part

def gr.big(gg: Gr) -> U32:
  match gg:
    case Gr{_part, big, _gain, _tab, _ix, _bits}:
      big

def gr.tab(gg: Gr) -> U32:
  match gg:
    case Gr{_part, _big, _gain, tab, _ix, _bits}:
      tab

def gr.ix(gg: Gr) -> List<&2, U32>:
  match gg:
    case Gr{_part, _big, _gain, _tab, ix, _bits}:
      ix

def gr.bits(gg: Gr) -> List<&2, U32>:
  match gg:
    case Gr{_part, _big, _gain, _tab, _ix, bits}:
      bits

# a granule of zeros: no bits, no big_values
def gr.zero() -> Gr:
  Gr{0, 0, 0, 0, [], []}

def gr.fit(ok: Bool, +bits: List<&2, U32>, +big: U32, ix: List<&2, U32>, +gg: U32, +tab: U32) -> Gr:
  match ok:
    case True{}:
      Gr{U32.from_nat(List.length(&2, U32, bits)), big, gg, tab, ix, bits}
    case False{}:
      gr.zero()

def gr.code(
  got: Maybe<&2, List<&2, U32>>,
  +big: U32,
  ix: List<&2, U32>,
  +gg: U32,
  +tab: U32,
  +bud: U32
) -> Gr:
  match got:
    case None{}:
      gr.zero()
    case Some{+bits}:
      gr.fit(U32.is_le(U32.from_nat(List.length(&2, U32, bits)), bud), bits, big, ix, gg, tab)

def gr.big.of(+big: U32, +ht: Ht, +ix: List<&2, U32>, +gg: U32, +tab: U32, +bud: U32) -> Gr:
  gr.code(hf.code(ht, take.u(U32.to_nat((big * 2 : U32)), ix, []), tab), big, ix, gg, tab, bud)

# big_values and the bits both come from ix: part2_3_length is the length of those bits
def gr.make(+ht: Ht, +ix: List<&2, U32>, +gg: U32, +tab: U32, +hz: U32, +bud: U32) -> Gr:
  gr.big.of(bv.of(ix, hz), ht, ix, gg, tab, bud)

def gr.ok(ok: Bool, +ht: Ht, ix: List<&2, U32>, +gg: U32, +tab: U32, +hz: U32, +bud: U32) -> Gr:
  match ok:
    case True{}:
      gr.make(ht, ix, gg, tab, hz, bud)
    case False{}:
      gr.zero()

def gr.pack(+ht: Ht, st: Sr, +hz: U32, +bud: U32) -> Gr:
  match st:
    case Sr{_lo, _hi, +gg, +tab, ix, ok}:
      gr.ok(ok, ht, ix, gg, tab, hz, bud)

def gr.tiny(zz: Bool, +pk: F32, +ht: Ht, +spec: List<&2, F32>, +hz: U32, +bud: U32) -> Gr:
  match zz:
    case True{}:
      gr.zero()
    case False{}:
      gr.pack(ht, dz.go(dz.thrs(), spec, pk, hz, bud, ht, Sr{0, 255, 0, 0, [], False{}}), hz, bud)

def gr.pk(+pk: F32, +ht: Ht, +spec: List<&2, F32>, +hz: U32, +bud: U32) -> Gr:
  gr.tiny(F32.is_lt(pk, f32.bits(730643660)), pk, ht, spec, hz, bud)

# one granule of 576 MDCT lines at most bud bits
def gr.of(+ht: Ht, +spec: List<&2, F32>, +hz: U32, +bud: U32) -> Gr:
  gr.pk(pk.go(spec, 0.0), ht, spec, hz, bud)

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

# ISO/IEC 11172-3 Annex C: the first granule's MDCT window starts on a granule of zeros
def ch.prime() -> List<&2, List<&2, F32>>:
  List.replicate(List<&2, F32>, 18n, List.replicate(F32, 32n, 0.0))

def ch.specs(xs: List<&2, F32>) -> List<&2, List<&2, F32>>:
  gran.all(List.append(&2, List<&2, F32>, ch.prime(), flip.all(an.run(xs), 0, [])))

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

# three table_select fields, region0_count 15 and region1_count 5; all zero without big_values
def side.tabs(none: Bool, st: Bw, +tab: U32) -> Bw:
  match none:
    case True{}:
      bw.field(22n, st, 0)
    case False{}:
      bw.field(3n, bw.field(4n, bw.field(5n, bw.field(5n, bw.field(5n, st, tab), tab), tab), 15), 5)

def side.end(st: Bw) -> Bw:
  bw.field(1n, bw.field(1n, bw.field(1n, st, 0), 0), 0)

def side.gr(st: Bw, g: Gr) -> Bw:
  match g:
    case Gr{+part, +big, +gain, +tab, _ix, _bits}:
      side.end(side.tabs(U32.is_eq(big, 0), side.mid(st, part, big, gain), tab))

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
    case Gr{_part, _big, _gain, _tab, _ix, bits}:
      body.bits(bits, st)

def body.grs(gs: List<&2, Gr>, st: Bw) -> Bw:
  match gs:
    case Nil{}:
      st
    case +hd <> tl:
      body.grs(tl, body.one(hd, st))

def gr.take(hop: Nat, gs: List<&2, Gr>, acc: List<&2, Gr>) -> List<&2, Gr>:
  match hop gs:
    case 0n _:
      List.reverse(&2, Gr, acc)
    case _ Nil{}:
      List.reverse(&2, Gr, acc)
    case 1n+p +hd <> tl:
      gr.take(p, tl, hd <> acc)

def gr.drop(hop: Nat, gs: List<&2, Gr>) -> List<&2, Gr>:
  match hop gs:
    case 0n ys:
      ys
    case _ Nil{}:
      []
    case 1n+p _hd <> tl:
      gr.drop(p, tl)

# one frame after its header: side information, then the granules' main data
def fr.data(+gs: List<&2, Gr>, +ch: U32) -> List<&2, U32>:
  List.append(&2, U32, side.bytes(gs, ch), bw.bytes(body.grs(gs, bw.empty())))

def pk.chan(
  specs: List<&2, List<&2, F32>>,
  +hz: U32,
  +bud: U32,
  +ht: Ht,
  acc: List<&2, Gr>
) -> List<&2, Gr>:
  match specs:
    case Nil{}:
      List.reverse(&2, Gr, acc)
    case +hd <> tl:
      pk.chan(tl, hz, bud, ht, gr.of(ht, hd, hz, bud) <> acc)

def pk.zip(ls: List<&2, Gr>, rs: List<&2, Gr>, acc: List<&2, Gr>) -> List<&2, Gr>:
  match ls rs:
    case +l <> lt +r <> rt:
      pk.zip(lt, rt, r <> l <> acc)
    case _ _:
      List.reverse(&2, Gr, acc)

# exactly hop samples: the list, then zeros
def f.fix(hop: Nat, xs: List<&2, F32>) -> List<&2, F32>:
  match hop:
    case 0n:
      []
    case 1n+p:
      match xs:
        case Nil{}:
          0.0 <> f.fix(p, [])
        case +hd <> tl:
          hd <> f.fix(p, tl)

# a channel of nf frames: nf * 1152 samples, zero-padded, two granules a frame
def enc.chgr(xs: List<&2, F32>, +hz: U32, +nf: U32, +bud: U32, +ht: Ht) -> List<&2, Gr>:
  pk.chan(ch.specs(f.fix(U32.to_nat((nf * 1152 : U32)), xs)), hz, bud, ht, [])

def s16.f(neg: Bool, +ww: U32) -> F32:
  match neg:
    case False{}:
      (U32.to_f32((ww .&. 65535 : U32)) / 32768.0 : F32)
    case True{}:
      F32.neg((U32.to_f32((65536 - (ww .&. 65535 : U32) : U32)) / 32768.0 : F32))

def samp.sign(neg: Bool) -> U32:
  match neg:
    case True{}:
      3212836864
    case False{}:
      1065353216

# NaN is 0; infinities and magnitudes past 1 are -1 or 1
def samp.big(nan: Bool, neg: Bool) -> U32:
  match nan:
    case True{}:
      0
    case False{}:
      samp.sign(neg)

def samp.pick(ok: Bool, +ww: U32) -> U32:
  match ok:
    case True{}:
      ww
    case False{}:
      samp.big(U32.is_lt(2139095040, (ww .&. 2147483647 : U32)), U32.is_ne((ww .&. 2147483648 : U32), 0))

# a binary32 word kept when finite with magnitude at most 1, its magnitude bits at most 1.0's
def samp.sat(+ww: U32) -> U32:
  samp.pick(U32.is_le((ww .&. 2147483647 : U32), 1065353216), ww)

def samp.of(+kind: U32, +ww: U32) -> F32:
  match kind:
    case 1:
      s16.f(U32.is_ne((ww .&. 32768 : U32), 0), ww)
    case _:
      f32.bits(samp.sat(ww))

# a zero sample: s16 0, or a binary32 word whose sanitized magnitude is 0
def samp.zero(+kind: U32, +ww: U32) -> Bool:
  match kind:
    case 1:
      U32.is_eq((ww .&. 65535 : U32), 0)
    case _:
      U32.is_eq((samp.sat(ww) .&. 2147483647 : U32), 0)

def q.both(aa: Bool, bb: Bool) -> Bool:
  match aa:
    case False{}:
      False{}
    case True{}:
      bb

def pcm.quiet(xs: List<&2, U32>, +kind: U32, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case +hd <> tl:
      pcm.quiet(tl, kind, q.both(acc, samp.zero(kind, hd)))

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

def enc.chs(
  mono: Bool,
  +hz: U32,
  left: List<&2, F32>,
  right: List<&2, F32>,
  +nf: U32,
  +bud: U32,
  +ht: Ht
) -> List<&2, Gr>:
  match mono:
    case True{}:
      enc.chgr(left, hz, nf, bud, ht)
    case False{}:
      pk.zip(enc.chgr(left, hz, nf, bud, ht), enc.chgr(right, hz, nf, bud, ht), [])

def enc.from(cc: Chs, +hz: U32, +ch: U32, +nf: U32, +bud: U32) -> List<&2, Gr>:
  match cc:
    case Chs{l, r}:
      enc.chs(U32.is_eq(ch, 1), hz, l, r, nf, bud, ht.of())

def enc.live(
  +hz: U32,
  +ch: U32,
  +kind: U32,
  frames: List<&2, U32>,
  +nf: U32,
  +bud: U32
) -> List<&2, Gr>:
  enc.from(split.go(pcm.go(kind, frames, []), ch, Chs{[], []}, 0), hz, ch, nf, bud)

# silence skips the filterbank: zero samples make zero lines, and zero lines a zero granule
def enc.quiet(
  quiet: Bool,
  +hz: U32,
  +ch: U32,
  +kind: U32,
  frames: List<&2, U32>,
  +nf: U32,
  +bud: U32
) -> List<&2, Gr>:
  match quiet:
    case True{}:
      List.replicate(Gr, U32.to_nat(((nf * 2 : U32) * ch : U32)), gr.zero())
    case False{}:
      enc.live(hz, ch, kind, frames, nf, bud)

# nf frames of granules in stream order: per frame granule 0 then 1, each channel 0 then 1
def enc.grans(
  +hz: U32,
  +ch: U32,
  +kind: U32,
  +frames: List<&2, U32>,
  +nf: U32,
  +bud: U32
) -> List<&2, Gr>:
  enc.quiet(pcm.quiet(frames, kind, True{}), hz, ch, kind, frames, nf, bud)
