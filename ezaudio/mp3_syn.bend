# MPEG-1 Layer III synthesis: antialias, IMDCT-36, sign flip, DCT-II, polyphase.
import Base
import ./mp3_tab.bend as Tab
import ./mp3_enc.bend as Enc

# add two binary32 values
def f.add(+aa: F32, +bb: F32) -> F32:
  (aa + bb : F32)

# subtract two binary32 values
def f.sub(+aa: F32, +bb: F32) -> F32:
  (aa - bb : F32)

# multiply two binary32 values
def f.mul(+aa: F32, +bb: F32) -> F32:
  (aa * bb : F32)

# sample at an index, or 0 past the end
def f.at(+xs: List<&2, F32>, +ii: U32) -> F32:
  Enc.f.nth(xs, ii)

# replace one sample
def f.set(xs: List<&2, F32>, +ii: U32, +vv: F32) -> List<&2, F32>:
  Enc.f.put(xs, ii, vv)

# unsigned add
def u.add(+aa: U32, +bb: U32) -> U32:
  (aa + bb : U32)

# unsigned subtract
def u.sub(+aa: U32, +bb: U32) -> U32:
  (aa - bb : U32)

# unsigned multiply
def u.mul(+aa: U32, +bb: U32) -> U32:
  (aa * bb : U32)

# low bit
def u.and(+kk: U32) -> U32:
  (kk .&. 1 : U32)

# 0.5
def c.half() -> F32:
  Enc.f32.bits(1056964608)

# 0.93969262
def c.c939() -> F32:
  Enc.f32.bits(1064341426)

# 0.76604444
def c.c766() -> F32:
  Enc.f32.bits(1061428093)

# 0.17364818
def c.c173() -> F32:
  Enc.f32.bits(1043452116)

# 0.86602540
def c.c866() -> F32:
  Enc.f32.bits(1063105495)

# 0.98480775
def c.c984() -> F32:
  Enc.f32.bits(1065098332)

# 0.34202014
def c.c342() -> F32:
  Enc.f32.bits(1051663684)

# 0.64278761
def c.c642() -> F32:
  Enc.f32.bits(1059360187)

# 0.70710677
def c.c707() -> F32:
  Enc.f32.bits(1060439283)

# 0.198912367
def c.c198() -> F32:
  Enc.f32.bits(1045147567)

# 0.382683432
def c.c382() -> F32:
  Enc.f32.bits(1053028117)

# 0.50979561
def c.c509() -> F32:
  Enc.f32.bits(1057128951)

# 0.54119611
def c.c541() -> F32:
  Enc.f32.bits(1057655764)

# 0.60134488
def c.c601() -> F32:
  Enc.f32.bits(1058664893)

# 0.89997619
def c.c899() -> F32:
  Enc.f32.bits(1063675095)

# 1.30656302
def c.c130() -> F32:
  Enc.f32.bits(1067924853)

# 2.56291556
def c.c256() -> F32:
  Enc.f32.bits(1076102863)

# 1/32768, the polyphase scale
def c.inv() -> F32:
  Enc.f32.bits(939524096)

# drop a prefix
def ls.drop(hop: Nat, xs: List<&2, F32>) -> List<&2, F32>:
  match hop xs:
    case 0n ys:
      ys
    case _ Nil{}:
      []
    case 1n+p _hd <> tl:
      ls.drop(p, tl)

# take a prefix, reversed into acc
def ls.take(hop: Nat, xs: List<&2, F32>, acc: List<&2, F32>) -> List<&2, F32>:
  match hop xs:
    case 0n _:
      List.reverse(&2, F32, acc)
    case _ Nil{}:
      List.reverse(&2, F32, acc)
    case 1n+p +hd <> tl:
      ls.take(p, tl, hd <> acc)

# a slice of length hop starting at an index
def ls.slice(+xs: List<&2, F32>, +at: U32, hop: Nat) -> List<&2, F32>:
  ls.take(hop, ls.drop(U32.to_nat(at), xs), [])

# write a short list over a destination starting at an index
def ls.poke(hop: Nat, dst: List<&2, F32>, src: List<&2, F32>, +at: U32) -> List<&2, F32>:
  match hop src:
    case 0n _:
      dst
    case _ Nil{}:
      dst
    case 1n+p +hd <> tl:
      ls.poke(p, f.set(dst, at, hd), tl, u.add(at, 1))

# nine samples, index 0 first
def cs.pack(
  +v0: F32, +v1: F32, +v2: F32, +v3: F32, +v4: F32, +v5: F32, +v6: F32, +v7: F32, +v8: F32
) -> List<&2, F32>:
  v0 <> (v1 <> (v2 <> (v3 <> (v4 <> (v5 <> (v6 <> (v7 <> (v8 <> []))))))))

# cosine half of one IMDCT-36 band
def cs.co(+gg: List<&2, F32>) -> List<&2, F32>:
  cs.pack(F32.neg(f.at(gg, 0)), f.add(f.at(gg, 1), f.at(gg, 2)),
    F32.neg(f.add(f.at(gg, 3), f.at(gg, 4))), f.add(f.at(gg, 5), f.at(gg, 6)),
    F32.neg(f.add(f.at(gg, 7), f.at(gg, 8))), f.add(f.at(gg, 9), f.at(gg, 10)),
    F32.neg(f.add(f.at(gg, 11), f.at(gg, 12))), f.add(f.at(gg, 13), f.at(gg, 14)),
    F32.neg(f.add(f.at(gg, 15), f.at(gg, 16))))

# sine half of one IMDCT-36 band
def cs.si(+gg: List<&2, F32>) -> List<&2, F32>:
  cs.pack(f.at(gg, 17), f.sub(f.at(gg, 16), f.at(gg, 15)), f.sub(f.at(gg, 13), f.at(gg, 14)),
    f.sub(f.at(gg, 12), f.at(gg, 11)), f.sub(f.at(gg, 9), f.at(gg, 10)),
    f.sub(f.at(gg, 8), f.at(gg, 7)), f.sub(f.at(gg, 5), f.at(gg, 6)),
    f.sub(f.at(gg, 4), f.at(gg, 3)), f.sub(f.at(gg, 1), f.at(gg, 2)))

# even-part sum used by the 9-point DCT
def d9.t0(+y0: F32, +y6: F32) -> F32:
  f.add(y0, f.mul(y6, c.half()))

# even-part difference
def d9.s0(+y0: F32, +y6: F32) -> F32:
  f.sub(y0, y6)

# twiddle on bins 4 and 2
def d9.t4(+y4: F32, +y2: F32) -> F32:
  f.mul(f.add(y4, y2), c.c939())

# twiddle on bins 8 and 2
def d9.t2(+y8: F32, +y2: F32) -> F32:
  f.mul(f.add(y8, y2), c.c766())

# twiddle on bins 4 and 8
def d9.s6(+y4: F32, +y8: F32) -> F32:
  f.mul(f.sub(y4, y8), c.c173())

# even residual
def d9.s4(+y4: F32, +y8: F32, +y2: F32) -> F32:
  f.sub(f.add(y4, y8), y2)

# scaled residual
def d9.s2(+s0: F32, +s4: F32) -> F32:
  f.sub(s0, f.mul(s4, c.half()))

# centre bin of the even DCT
def d9.y4(+s4: F32, +s0: F32) -> F32:
  f.add(s4, s0)

# high even output
def d9.s8c(+t0: F32, +t2: F32, +s6: F32) -> F32:
  f.add(f.sub(t0, t2), s6)

# low even output
def d9.s0c(+t0: F32, +t4: F32, +t2: F32) -> F32:
  f.add(f.sub(t0, t4), t2)

# mid even output
def d9.s4c(+t0: F32, +t4: F32, +s6: F32) -> F32:
  f.sub(f.add(t0, t4), s6)

# odd centre
def d9.s3(+y3: F32) -> F32:
  f.mul(y3, c.c866())

# odd low twiddle
def d9.tb0(+y5: F32, +y1: F32) -> F32:
  f.mul(f.add(y5, y1), c.c984())

# odd high twiddle
def d9.tb4(+y5: F32, +y7: F32) -> F32:
  f.mul(f.sub(y5, y7), c.c342())

# odd mid twiddle
def d9.tb2(+y1: F32, +y7: F32) -> F32:
  f.mul(f.add(y1, y7), c.c642())

# odd residual
def d9.s1(+y1: F32, +y5: F32, +y7: F32) -> F32:
  f.mul(f.sub(f.sub(y1, y5), y7), c.c866())

# odd combination
def d9.s5c(+t0: F32, +s3: F32, +t2: F32) -> F32:
  f.sub(f.sub(t0, s3), t2)

# odd combination
def d9.s7c(+t4: F32, +s3: F32, +t0: F32) -> F32:
  f.sub(f.sub(t4, s3), t0)

# odd combination
def d9.s3c(+t4: F32, +s3: F32, +t2: F32) -> F32:
  f.sub(f.add(t4, s3), t2)

# even and odd 9-point DCT results, ready to interleave
type D9 is Data:
  D9{
    s2b: F32, y4o: F32, s8c: F32, s0c: F32, s4c: F32, s1b: F32, s5c: F32, s7c: F32, s3c: F32
  }

# assemble the nine DCT outputs from the even and odd parts
def d9.from(
  +t0: F32, +s0: F32, +t4: F32, +t2: F32, +s6: F32, +s4: F32, +s3: F32, +u0: F32, +u4: F32,
  +u2: F32, +s1: F32
) -> D9:
  D9{d9.s2(s0, s4), d9.y4(s4, s0), d9.s8c(t0, t2, s6), d9.s0c(t0, t4, t2), d9.s4c(t0, t4, s6), s1,
    d9.s5c(u0, s3, u2), d9.s7c(u4, s3, u0), d9.s3c(u4, s3, u2)}

# 9-point DCT of one half
def d9.build(
  +y0: F32, +y1: F32, +y2: F32, +y3: F32, +y4: F32, +y5: F32, +y6: F32, +y7: F32, +y8: F32
) -> D9:
  d9.from(d9.t0(y0, y6), d9.s0(y0, y6), d9.t4(y4, y2), d9.t2(y8, y2), d9.s6(y4, y8),
    d9.s4(y4, y8, y2), d9.s3(y3), d9.tb0(y5, y1), d9.tb4(y5, y7), d9.tb2(y1, y7), d9.s1(y1, y5, y7))

# nine DCT outputs in bin order
def d9.list(dd: D9) -> List<&2, F32>:
  match dd:
    case D9{+s2b, +y4o, +s8c, +s0c, +s4c, +s1b, +s5c, +s7c, +s3c}:
      cs.pack(f.sub(s4c, s7c), f.add(s2b, s1b), f.sub(s0c, s3c), f.add(s8c, s5c), y4o,
        f.sub(s8c, s5c), f.add(s0c, s3c), f.sub(s2b, s1b), f.add(s4c, s7c))

# 9-point DCT
def d9.run(+ys: List<&2, F32>) -> List<&2, F32>:
  d9.list(d9.build(f.at(ys, 0), f.at(ys, 1), f.at(ys, 2), f.at(ys, 3), f.at(ys, 4), f.at(ys, 5),
    f.at(ys, 6), f.at(ys, 7), f.at(ys, 8)))

# negate the odd bins of a sine DCT
def d9.neg(+ys: List<&2, F32>) -> List<&2, F32>:
  f.set(f.set(f.set(f.set(ys, 1, F32.neg(f.at(ys, 1))), 3, F32.neg(f.at(ys, 3))), 5,
    F32.neg(f.at(ys, 5))), 7, F32.neg(f.at(ys, 7)))

# one windowed band: 18 time samples and 9 new overlap samples
type Wn is Data:
  Wn{out: List<&2, F32>, nov: List<&2, F32>}

# window product and the overlap it saves
type Ws is Data:
  Ws{sm: F32, nv: F32}

# aliasing pair for one window index
def wn.pair(+co: List<&2, F32>, +si: List<&2, F32>, +tw: List<&2, F32>, +ii: U32) -> Ws:
  Ws{f.add(f.mul(f.at(co, ii), f.at(tw, u.add(ii, 9))), f.mul(f.at(si, ii), f.at(tw, ii))),
    f.sub(f.mul(f.at(co, ii), f.at(tw, ii)), f.mul(f.at(si, ii), f.at(tw, u.add(ii, 9))))}

# write one window index into the band
def wn.put(st: Wn, +ov: List<&2, F32>, +win: List<&2, F32>, +ii: U32, ws: Ws) -> Wn:
  match st ws:
    case Wn{out, nov} Ws{+sm, +nv}:
      Wn{f.set(f.set(out, ii, f.sub(f.mul(f.at(ov, ii), f.at(win, ii)), f.mul(sm, f.at(win, u.add(ii, 9))))),
        u.sub(17, ii), f.add(f.mul(f.at(ov, ii), f.at(win, u.add(ii, 9))), f.mul(sm, f.at(win, ii)))),
        f.set(nov, ii, nv)}

# one of the nine window steps
def wn.one(
  st: Wn, +co: List<&2, F32>, +si: List<&2, F32>, +ov: List<&2, F32>, +tw: List<&2, F32>,
  +win: List<&2, F32>, +ii: U32
) -> Wn:
  wn.put(st, ov, win, ii, wn.pair(co, si, tw, ii))

# window all nine indices
def wn.go(
  hop: Nat, st: Wn, +co: List<&2, F32>, +si: List<&2, F32>, +ov: List<&2, F32>, +tw: List<&2, F32>,
  +win: List<&2, F32>, +ii: U32
) -> Wn:
  match hop:
    case 0n:
      st
    case 1n+p:
      wn.go(p, wn.one(st, co, si, ov, tw, win, ii), co, si, ov, tw, win, u.add(ii, 1))

# IMDCT-36 of one 18-point band
def im.band(+gg: List<&2, F32>, +ov: List<&2, F32>, +tw: List<&2, F32>, +win: List<&2, F32>) -> Wn:
  wn.go(9n, Wn{List.replicate(F32, 18n, 0.0), List.replicate(F32, 9n, 0.0)}, d9.run(cs.co(gg)),
    d9.neg(d9.run(cs.si(gg))), ov, tw, win, 0)

# 576 lines and 288 overlap samples
type Im is Data:
  Im{buf: List<&2, F32>, ov: List<&2, F32>}

# write one band back into the spectrum and the overlap
def im.store(+buf: List<&2, F32>, +ov: List<&2, F32>, ww: Wn, +jj: U32) -> Im:
  match ww:
    case Wn{out, nov}:
      Im{ls.poke(18n, buf, out, u.mul(jj, 18)), ls.poke(9n, ov, nov, u.mul(jj, 9))}

# IMDCT-36 of band jj
def im.one(st: Im, +tw: List<&2, F32>, +win: List<&2, F32>, +jj: U32) -> Im:
  match st:
    case Im{+buf, +ov}:
      im.store(buf, ov, im.band(ls.slice(buf, u.mul(jj, 18), 18n), ls.slice(ov, u.mul(jj, 9), 9n), tw, win), jj)

# IMDCT-36 over 32 bands
def im.go(hop: Nat, st: Im, +tw: List<&2, F32>, +win: List<&2, F32>, +jj: U32) -> Im:
  match hop:
    case 0n:
      st
    case 1n+p:
      im.go(p, im.one(st, tw, win, jj), tw, win, u.add(jj, 1))

# butterfly of one aliasing pair. c0 and c1 are the two cosine rows.
def aa.up(
  +xs: List<&2, F32>, +up: F32, +dp: F32, +c0: F32, +c1: F32, +bb: U32, +ii: U32
) -> List<&2, F32>:
  f.set(f.set(xs, u.add(u.mul(u.add(bb, 1), 18), ii), f.sub(f.mul(c0, up), f.mul(c1, dp))),
    u.add(u.mul(bb, 18), u.sub(17, ii)), f.add(f.mul(c1, up), f.mul(c0, dp)))

# one butterfly at index ii of band bb
def aa.one(+xs: List<&2, F32>, +aa: List<&2, F32>, +bb: U32, +ii: U32) -> List<&2, F32>:
  aa.up(xs, f.at(xs, u.add(u.mul(u.add(bb, 1), 18), ii)), f.at(xs, u.add(u.mul(bb, 18), u.sub(17, ii))),
    f.at(aa, ii), f.at(aa, u.add(ii, 8)), bb, ii)

# eight butterflies between band bb and the next
def aa.i(hop: Nat, xs: List<&2, F32>, +aa: List<&2, F32>, +bb: U32, +ii: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      aa.i(p, aa.one(xs, aa, bb, ii), aa, bb, u.add(ii, 1))

# antialias from low bands toward high bands
def aa.b(hop: Nat, xs: List<&2, F32>, +aa: List<&2, F32>, +bb: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      aa.b(p, aa.i(8n, xs, aa, bb, 0), aa, u.add(bb, 1))

# 31 long-block aliasing pairs
def aa.run(+xs: List<&2, F32>, +aa: List<&2, F32>) -> List<&2, F32>:
  aa.b(31n, xs, aa, 0)

# negate one odd sample of an odd band
def sg.i(hop: Nat, +xs: List<&2, F32>, +base: U32, +ii: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      sg.i(p, f.set(xs, u.add(base, ii), F32.neg(f.at(xs, u.add(base, ii)))), base, u.add(ii, 2))

# odd samples of 16 odd bands, starting at sample 18
def sg.b(hop: Nat, xs: List<&2, F32>, +base: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      sg.b(p, sg.i(9n, xs, base, 1), u.add(base, 36))

# frequency inversion after the IMDCT
def im.sign(st: Im) -> Im:
  match st:
    case Im{buf, ov}:
      Im{sg.b(16n, buf, 18), ov}

# four DCT-II column results
type Q4 is Data:
  Q4{a0: F32, a1: F32, a2: F32, a3: F32}

# column sample i of the 32-band vector
def dc.x0(+acc: List<&2, F32>, +kk: U32, +ii: U32) -> F32:
  f.at(acc, u.add(kk, u.mul(ii, 18)))

# mirrored column
def dc.x1(+acc: List<&2, F32>, +kk: U32, +ii: U32) -> F32:
  f.at(acc, u.add(kk, u.mul(u.sub(15, ii), 18)))

# upper column
def dc.x2(+acc: List<&2, F32>, +kk: U32, +ii: U32) -> F32:
  f.at(acc, u.add(kk, u.mul(u.add(16, ii), 18)))

# upper mirror
def dc.x3(+acc: List<&2, F32>, +kk: U32, +ii: U32) -> F32:
  f.at(acc, u.add(kk, u.mul(u.sub(31, ii), 18)))

# finish the column butterfly
def dc.q2(+t0: F32, +t1: F32, +t2: F32, +t3: F32, +s2: F32) -> Q4:
  Q4{f.add(t0, t1), f.mul(f.sub(t0, t1), s2), f.add(t3, t2), f.mul(f.sub(t3, t2), s2)}

# one DCT-II column from four samples and three secants
def dc.q(+x0: F32, +x1: F32, +x2: F32, +x3: F32, +s0: F32, +s1: F32, +s2: F32) -> Q4:
  dc.q2(f.add(x0, x3), f.add(x1, x2), f.mul(f.sub(x1, x2), s0), f.mul(f.sub(x0, x3), s1), s2)

# read column ii
def dc.cell(+acc: List<&2, F32>, +sec: List<&2, F32>, +kk: U32, +ii: U32) -> Q4:
  dc.q(dc.x0(acc, kk, ii), dc.x1(acc, kk, ii), dc.x2(acc, kk, ii), dc.x3(acc, kk, ii),
    f.at(sec, u.mul(ii, 3)), f.at(sec, u.add(u.mul(ii, 3), 1)), f.at(sec, u.add(u.mul(ii, 3), 2)))

# store one column into the 4 by 8 working rows
def dc.store(xs: List<&2, F32>, qq: Q4, +ii: U32) -> List<&2, F32>:
  match qq:
    case Q4{a0, a1, a2, a3}:
      f.set(f.set(f.set(f.set(xs, ii, a0), u.add(ii, 8), a1), u.add(ii, 16), a2), u.add(ii, 24), a3)

# gather all eight columns before any write-back
def dc.cols(
  hop: Nat, +acc: List<&2, F32>, +sec: List<&2, F32>, +kk: U32, +ii: U32, xs: List<&2, F32>
) -> List<&2, F32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      dc.cols(p, acc, sec, kk, u.add(ii, 1), dc.store(xs, dc.cell(acc, sec, kk, ii), ii))

# eight floats carried through the DCT-II row butterfly
type E8 is Data:
  E8{z0: F32, z1: F32, z2: F32, z3: F32, z4: F32, z5: F32, z6: F32, z7: F32}

# finish the first stage
def but.sum2(
  +xt: F32, +y0: F32, +y7: F32, +y1: F32, +y6: F32, +y2: F32, +y5: F32, +y3: F32
) -> E8:
  E8{f.add(y0, y3), f.add(y1, y2), y6, f.sub(y1, y2), f.sub(y0, y3), y5, y7, xt}

# first add/sub stage of a DCT-II row
def but.sum(+x0: F32, +x1: F32, +x2: F32, +x3: F32, +x4: F32, +x5: F32, +x6: F32, +x7: F32) -> E8:
  but.sum2(f.sub(x0, x7), f.add(x0, x7), f.sub(x1, x6), f.add(x1, x6), f.sub(x2, x5), f.add(x2, x5),
    f.sub(x3, x4), f.add(x3, x4))

# second stage: the 45-degree rotations
def but.mid(ee: E8) -> E8:
  match ee:
    case E8{+z0, +z1, +z2, +z3, +z4, +z5, +z6, +z7}:
      E8{f.add(z0, z1), f.mul(f.add(z3, z4), c.c707()), f.mul(f.add(z2, z6), c.c707()), z4,
        f.mul(f.sub(z0, z1), c.c707()), f.add(z5, z2), f.add(z6, z7), z7}

# last rotation update
def but.rot3(
  +o0: F32, +w3: F32, +w6: F32, +y4: F32, +o4: F32, +p5: F32, +p7: F32, +xt: F32
) -> E8:
  E8{o0, p7, w3, y4, o4, f.sub(p5, f.mul(p7, c.c198())), f.sub(xt, w6), f.add(xt, w6)}

# complete the rotation
def but.rot2(
  +o0: F32, +w3: F32, +w6: F32, +y4: F32, +o4: F32, +p5: F32, +w7: F32, +xt: F32
) -> E8:
  but.rot3(o0, w3, w6, y4, o4, p5, f.add(w7, f.mul(p5, c.c382())), xt)

# third stage: the small-angle rotation, using the updated values
def but.rot(ee: E8) -> E8:
  match ee:
    case E8{+z0, +z1, +z2, +z3, +z4, +z5, +z6, +z7}:
      but.rot2(z0, z1, z2, z3, z4, f.sub(z5, f.mul(z6, c.c198())), z6, z7)

# eight row outputs
def but.end(ee: E8) -> List<&2, F32>:
  match ee:
    case E8{+z0, +z1, +z2, +z3, +z4, +z5, +z6, +z7}:
      cs.pack(z0, f.mul(f.add(z7, z1), c.c509()), f.mul(f.add(z3, z2), c.c541()),
        f.mul(f.sub(z6, z5), c.c601()), z4, f.mul(f.add(z6, z5), c.c899()),
        f.mul(f.sub(z3, z2), c.c130()), f.mul(f.sub(z7, z1), c.c256()), 0.0)

# cs.pack takes 9; the row is 8. Drop the padding below.
def but.out(ee: E8) -> List<&2, F32>:
  ls.take(8n, but.end(ee), [])

# butterfly one row of eight and write it back
def but.row(+xs: List<&2, F32>, +base: U32) -> List<&2, F32>:
  ls.poke(8n, xs, but.out(but.rot(but.mid(but.sum(f.at(xs, base), f.at(xs, u.add(base, 1)),
    f.at(xs, u.add(base, 2)), f.at(xs, u.add(base, 3)), f.at(xs, u.add(base, 4)),
    f.at(xs, u.add(base, 5)), f.at(xs, u.add(base, 6)), f.at(xs, u.add(base, 7)))))), base)

# butterfly all four rows
def dc.fly(hop: Nat, xs: List<&2, F32>, +base: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      dc.fly(p, but.row(xs, base), u.add(base, 8))

# one entry of the 4 by 8 rows
def sc.t(+rows: List<&2, F32>, +rr: U32, +ii: U32) -> F32:
  f.at(rows, u.add(u.mul(rr, 8), ii))

# scatter one group of four bands
def sc.one(+acc: List<&2, F32>, +rows: List<&2, F32>, +yy: U32, +ii: U32) -> List<&2, F32>:
  f.set(f.set(f.set(f.set(acc, yy, sc.t(rows, 0, ii)), u.add(yy, 18),
    f.add(f.add(sc.t(rows, 2, ii), sc.t(rows, 3, ii)), sc.t(rows, 3, u.add(ii, 1)))), u.add(yy, 36),
    f.add(sc.t(rows, 1, ii), sc.t(rows, 1, u.add(ii, 1)))), u.add(yy, 54),
    f.add(f.add(sc.t(rows, 2, u.add(ii, 1)), sc.t(rows, 3, ii)), sc.t(rows, 3, u.add(ii, 1))))

# seven scatter steps; the eighth is the tail
def sc.go(hop: Nat, acc: List<&2, F32>, +rows: List<&2, F32>, +yy: U32, +ii: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      acc
    case 1n+p:
      sc.go(p, sc.one(acc, rows, yy, ii), rows, u.add(yy, 72), u.add(ii, 1))

# last scatter group, which has no i+1 neighbour
def sc.tail(+acc: List<&2, F32>, +rows: List<&2, F32>, +yy: U32) -> List<&2, F32>:
  f.set(f.set(f.set(f.set(acc, yy, sc.t(rows, 0, 7)), u.add(yy, 18), f.add(sc.t(rows, 2, 7), sc.t(rows, 3, 7))),
    u.add(yy, 36), sc.t(rows, 1, 7)), u.add(yy, 54), sc.t(rows, 3, 7))

# scatter every band of frequency bin kk
def sc.run(acc: List<&2, F32>, +rows: List<&2, F32>, +kk: U32) -> List<&2, F32>:
  sc.tail(sc.go(7n, acc, rows, kk, 0), rows, u.add(kk, 504))

# one frequency bin of the 32-point DCT-II
def dc.one(+acc: List<&2, F32>, +sec: List<&2, F32>, +kk: U32) -> List<&2, F32>:
  sc.run(acc, dc.fly(4n, dc.cols(8n, acc, sec, kk, 0, List.replicate(F32, 32n, 0.0)), 0), kk)

# DCT-II of 18 frequency bins
def dc.run(hop: Nat, acc: List<&2, F32>, +sec: List<&2, F32>, +kk: U32) -> List<&2, F32>:
  match hop:
    case 0n:
      acc
    case 1n+p:
      dc.run(p, dc.one(acc, sec, kk), sec, u.add(kk, 1))

# one F32 read from the polyphase delay Array
type La is Type:
  La{lin: Array<F32>, +v: F32}

def la.of(got: Array<F32> & F32) -> La:
  (lin, v) = got
  La{lin, v}

def ln.at(lin: Array<F32>, +ii: U32) -> La:
  la.of(Array.get(F32, lin, ii))

def ln.set(lin: Array<F32>, +ii: U32, +vv: F32) -> Array<F32>:
  Array.set(F32, lin, ii, vv)

def ln.fill(xs: List<&2, F32>, a: Array<F32>, +ii: U32) -> Array<F32>:
  match xs:
    case Nil{}:
      a
    case +hd <> tl:
      ln.fill(tl, Array.set(F32, a, ii, hd), u.add(ii, 1))

# pull one sample into an accumulator; hop is remaining after this read
def ln.pull(hop: Nat, got: La, +ii: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match hop got:
    case 0n La{lin, +cur}:
      match lin:
        case _l:
          List.reverse(&2, F32, cur <> acc)
    case 1n+p La{lin, +cur}:
      ln.pull(p, ln.at(lin, u.add(ii, 1)), u.add(ii, 1), cur <> acc)

# first hop+1 slots of an Array as a list
def ln.list(a: Array<F32>, hop: Nat) -> List<&2, F32>:
  ln.pull(hop, ln.at(a, 0), 0, [])

# four running polyphase sums, a and b
type Mac is Data:
  Mac{aa: List<&2, F32>, bb: List<&2, F32>}

# MAC state plus the delay line handle mac.* only reads
type Mk is Type:
  Mk{st: Mac, lin: Array<F32>}

# mode 0 replaces, mode 2 flips the a product, otherwise both add
def mac.av(+mode: U32, +zv: F32, +yv: F32, +w0: F32, +w1: F32) -> F32:
  match mode:
    case 2:
      f.sub(f.mul(yv, w1), f.mul(zv, w0))
    case _:
      f.sub(f.mul(zv, w0), f.mul(yv, w1))

# apply one lane of a window load
def mac.wr(
  +aa: List<&2, F32>, +bb: List<&2, F32>, +mode: U32, +jj: U32, +bv: F32, +av: F32
) -> Mac:
  match mode:
    case 0:
      Mac{f.set(aa, jj, av), f.set(bb, jj, bv)}
    case _:
      Mac{f.set(aa, jj, f.add(f.at(aa, jj), av)), f.set(bb, jj, f.add(f.at(bb, jj), bv))}

# one of the four lanes, y slot
def mac.jy(
  st: Mac, got: La, +w0: F32, +w1: F32, +mode: U32, +jj: U32, +zv: F32
) -> Mk:
  match st got:
    case Mac{aa, bb} La{lin2, yv}:
      Mk{mac.wr(aa, bb, mode, jj, f.add(f.mul(zv, w1), f.mul(yv, w0)), mac.av(mode, zv, yv, w0, w1)), lin2}

# one of the four lanes, z slot
def mac.jz(
  st: Mac, got: La, +w0: F32, +w1: F32, +vy: U32, +mode: U32, +jj: U32
) -> Mk:
  match got:
    case La{lin1, zv}:
      mac.jy(st, ln.at(lin1, u.add(vy, jj)), w0, w1, mode, jj, zv)

# one of the four lanes
def mac.j(
  st: Mac, lin: Array<F32>, +w0: F32, +w1: F32, +vz: U32, +vy: U32, +mode: U32, +jj: U32
) -> Mk:
  mac.jz(st, ln.at(lin, u.add(vz, jj)), w0, w1, vy, mode, jj)

# four lanes of one load, advance one lane
def mac.js_next(mk: Mk, +w0: F32, +w1: F32, +vz: U32, +vy: U32, +mode: U32, +jj: U32) -> Mk:
  match mk:
    case Mk{st, lin}:
      mac.j(st, lin, w0, w1, vz, vy, mode, jj)

# four lanes of one load
def mac.js(
  hop: Nat, mk: Mk, +w0: F32, +w1: F32, +vz: U32, +vy: U32, +mode: U32, +jj: U32
) -> Mk:
  match hop:
    case 0n:
      mk
    case 1n+p:
      mac.js(p, mac.js_next(mk, w0, w1, vz, vy, mode, jj), w0, w1, vz, vy, mode, u.add(jj, 1))

# odd or even load
def mac.mode3(odd: Bool) -> U32:
  match odd:
    case True{}:
      2
    case False{}:
      1

# pick the load mode
def mac.mode2(zero: Bool, odd: Bool) -> U32:
  match zero:
    case True{}:
      0
    case False{}:
      mac.mode3(odd)

# k = 0 replaces, odd k uses mode 2, other even k uses mode 1
def mac.mode(+kk: U32) -> U32:
  mac.mode2(U32.is_eq(kk, 0), U32.is_eq(u.and(kk), 1))

# window-coefficient index for block row ii and load kk
def mac.pos(+ii: U32, +kk: U32) -> U32:
  u.add(u.mul(u.sub(14, ii), 16), u.mul(kk, 2))

# one of the eight loads
def mac.step(mk: Mk, +syn: List<&2, F32>, +zlin: U32, +ii: U32, +kk: U32) -> Mk:
  match mk:
    case Mk{st, lin}:
      mac.js(4n, Mk{st, lin}, f.at(syn, mac.pos(ii, kk)), f.at(syn, u.add(mac.pos(ii, kk), 1)),
        u.sub(u.add(zlin, u.mul(ii, 4)), u.mul(kk, 64)),
        u.sub(u.add(zlin, u.mul(ii, 4)), u.mul(u.sub(15, kk), 64)), mac.mode(kk), 0)

# eight loads
def mac.k(
  hop: Nat, mk: Mk, +syn: List<&2, F32>, +zlin: U32, +ii: U32, +kk: U32
) -> Mk:
  match hop mk:
    case 0n Mk{st, lin}:
      Mk{st, lin}
    case 1n+p Mk{st, lin}:
      mac.k(p, mac.step(Mk{st, lin}, syn, zlin, ii, kk), syn, zlin, ii, u.add(kk, 1))

# scale a polyphase sum into a sample
def mac.sc(+vv: F32) -> F32:
  f.mul(vv, c.inv())

# write the eight samples this row produces
def mac.p8(
  pcm: Array<F32>, +aa: List<&2, F32>, +bb: List<&2, F32>, +nch: U32, +pcmi: U32, +ii: U32
) -> Array<F32>:
  ln.set(ln.set(ln.set(ln.set(ln.set(ln.set(ln.set(ln.set(pcm,
    u.add(pcmi, u.add(u.mul(u.sub(15, ii), nch), u.sub(nch, 1))), mac.sc(f.at(aa, 1))),
    u.add(pcmi, u.add(u.mul(u.add(17, ii), nch), u.sub(nch, 1))), mac.sc(f.at(bb, 1))),
    u.add(pcmi, u.mul(u.sub(15, ii), nch)), mac.sc(f.at(aa, 0))),
    u.add(pcmi, u.mul(u.add(17, ii), nch)), mac.sc(f.at(bb, 0))),
    u.add(pcmi, u.add(u.mul(u.sub(47, ii), nch), u.sub(nch, 1))), mac.sc(f.at(aa, 3))),
    u.add(pcmi, u.add(u.mul(u.add(49, ii), nch), u.sub(nch, 1))), mac.sc(f.at(bb, 3))),
    u.add(pcmi, u.mul(u.sub(47, ii), nch)), mac.sc(f.at(aa, 2))),
    u.add(pcmi, u.mul(u.add(49, ii), nch)), mac.sc(f.at(bb, 2)))

# store the row
def mac.put(pcm: Array<F32>, st: Mac, +nch: U32, +pcmi: U32, +ii: U32) -> Array<F32>:
  match st:
    case Mac{+aa, +bb}:
      mac.p8(pcm, aa, bb, nch, pcmi, ii)

# fresh accumulators
def mac.z() -> Mac:
  Mac{List.replicate(F32, 4n, 0.0), List.replicate(F32, 4n, 0.0)}

# channel offset: the right channel starts at 576 when there are two
def blk.off(+nch: U32, right: Bool) -> U32:
  match right:
    case False{}:
      0
    case True{}:
      u.mul(u.sub(nch, 1), 576)

# one subband sample. right selects the second channel.
def blk.g(+gr: List<&2, F32>, +nch: U32, +band: U32, +tm: U32, right: Bool) -> F32:
  f.at(gr, u.add(u.add(blk.off(nch, right), u.mul(band, 18)), tm))

# write the four samples at zlin + 4*slot
def blk.w4(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +at: U32, +band: U32, +tm: U32
) -> Array<F32>:
  ln.set(ln.set(ln.set(ln.set(lin, at, blk.g(gr, nch, band, tm, False{})), u.add(at, 1),
    blk.g(gr, nch, band, tm, True{})), u.add(at, 2), blk.g(gr, nch, 0, tm, False{})), u.add(at, 3),
    blk.g(gr, nch, 0, tm, True{}))

# the second write of a row uses band (1+ii), not band 0
def blk.w2(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +at: U32, +band: U32, +tm: U32
) -> Array<F32>:
  ln.set(ln.set(lin, at, blk.g(gr, nch, band, tm, False{})), u.add(at, 1), blk.g(gr, nch, band, tm, True{}))

# preamble: bands 16 and 0 at the current and next time
def blk.pre(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +zlin: U32, +tm: U32
) -> Array<F32>:
  blk.w4(blk.w4(lin, gr, nch, u.add(zlin, 60), 16, tm), gr, nch, u.add(zlin, 124), 16, u.add(tm, 1))

# index of the history write, which steps back 16 slots
def blk.hist(+zlin: U32, +ii: U32) -> U32:
  u.add(u.sub(zlin, u.mul(u.sub(16, ii), 4)), 2)

# same band at this time and the next, four lanes
def blk.ws(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +at: U32, +band: U32, +tm: U32
) -> Array<F32>:
  ln.set(ln.set(ln.set(ln.set(lin, at, blk.g(gr, nch, band, tm, False{})), u.add(at, 1),
    blk.g(gr, nch, band, tm, True{})), u.add(at, 2), blk.g(gr, nch, band, u.add(tm, 1), False{})),
    u.add(at, 3), blk.g(gr, nch, band, u.add(tm, 1), True{}))

# current-slot writes for row ii
def blk.i1(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +zlin: U32, +tm: U32, +ii: U32
) -> Array<F32>:
  blk.ws(lin, gr, nch, u.add(zlin, u.mul(ii, 4)), u.sub(31, ii), tm)

# next-slot and history writes for row ii
def blk.i2(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +zlin: U32, +tm: U32, +ii: U32
) -> Array<F32>:
  blk.w2(blk.w2(lin, gr, nch, u.add(u.add(zlin, u.mul(ii, 4)), 64), u.add(1, ii), u.add(tm, 1)), gr, nch,
    blk.hist(zlin, ii), u.add(1, ii), tm)

# both writes for row ii
def blk.i(
  lin: Array<F32>, +gr: List<&2, F32>, +nch: U32, +zlin: U32, +tm: U32, +ii: U32
) -> Array<F32>:
  blk.i2(blk.i1(lin, gr, nch, zlin, tm, ii), gr, nch, zlin, tm, ii)

# (z+896) - z, times 29
def sp.a1a3(g1: La, +v896: F32) -> La:
  match g1:
    case La{lin2, vz}:
      La{lin2, f.mul(f.sub(v896, vz), Enc.f32.bits(1105723392))}

def sp.a1a2(g0: La, +zz: U32) -> La:
  match g0:
    case La{lin1, v896}:
      sp.a1a3(ln.at(lin1, zz), v896)

def sp.a1a(lin: Array<F32>, +zz: U32) -> La:
  sp.a1a2(ln.at(lin, u.add(zz, 896)), zz)

# slots 1 and 13, times 213
def sp.a1b2(g1: La, +acc: F32, +v64: F32) -> La:
  match g1:
    case La{lin2, v832}:
      La{lin2, f.add(acc, f.mul(f.add(v64, v832), Enc.f32.bits(1129644032)))}

def sp.a1b1(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v64}:
      sp.a1b2(ln.at(lin1, u.add(zz, 832)), acc, v64)

def sp.a1b(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a1b1(ln.at(lin, u.add(zz, 64)), acc, zz)

# slots 12 and 2, times 459
def sp.a1c2(g1: La, +acc: F32, +v768: F32) -> La:
  match g1:
    case La{lin2, v128}:
      La{lin2, f.add(acc, f.mul(f.sub(v768, v128), Enc.f32.bits(1139113984)))}

def sp.a1c1(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v768}:
      sp.a1c2(ln.at(lin1, u.add(zz, 128)), acc, v768)

def sp.a1c(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a1c1(ln.at(lin, u.add(zz, 768)), acc, zz)

# slots 3 and 11, times 2037
def sp.a1d2(g1: La, +acc: F32, +v192: F32) -> La:
  match g1:
    case La{lin2, v704}:
      La{lin2, f.add(acc, f.mul(f.add(v192, v704), Enc.f32.bits(1157537792)))}

def sp.a1d1(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v192}:
      sp.a1d2(ln.at(lin1, u.add(zz, 704)), acc, v192)

def sp.a1d(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a1d1(ln.at(lin, u.add(zz, 192)), acc, zz)

# slots 10 and 4, times 5153
def sp.a1e2(g1: La, +acc: F32, +v640: F32) -> La:
  match g1:
    case La{lin2, v256}:
      La{lin2, f.add(acc, f.mul(f.sub(v640, v256), Enc.f32.bits(1168181248)))}

def sp.a1e1(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v640}:
      sp.a1e2(ln.at(lin1, u.add(zz, 256)), acc, v640)

def sp.a1e(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a1e1(ln.at(lin, u.add(zz, 640)), acc, zz)

# slots 5 and 9, times 6574
def sp.a1f2(g1: La, +acc: F32, +v320: F32) -> La:
  match g1:
    case La{lin2, v576}:
      La{lin2, f.add(acc, f.mul(f.add(v320, v576), Enc.f32.bits(1171091456)))}

def sp.a1f1(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v320}:
      sp.a1f2(ln.at(lin1, u.add(zz, 576)), acc, v320)

def sp.a1f(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a1f1(ln.at(lin, u.add(zz, 320)), acc, zz)

# slots 8 and 6, times 37489, then slot 7 times 75038
def sp.a1g4(g2: La, +acc: F32, +v512: F32, +v384: F32) -> La:
  match g2:
    case La{lin3, v448}:
      La{lin3,
        f.add(f.add(acc, f.mul(f.sub(v512, v384), Enc.f32.bits(1192390912))),
          f.mul(v448, Enc.f32.bits(1200787200)))}

def sp.a1g3(g1: La, +acc: F32, +v512: F32, +zz: U32) -> La:
  match g1:
    case La{lin2, v384}:
      sp.a1g4(ln.at(lin2, u.add(zz, 448)), acc, v512, v384)

def sp.a1g2(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v512}:
      sp.a1g3(ln.at(lin1, u.add(zz, 384)), acc, v512, zz)

def sp.a1g(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a1g2(ln.at(lin, u.add(zz, 512)), acc, zz)

def sp.a1go6(g: La, +zz: U32) -> La:
  match g:
    case La{lin6, acc6}:
      sp.a1g(acc6, lin6, zz)

def sp.a1go5(g: La, +zz: U32) -> La:
  match g:
    case La{lin5, acc5}:
      sp.a1go6(sp.a1f(acc5, lin5, zz), zz)

def sp.a1go4(g: La, +zz: U32) -> La:
  match g:
    case La{lin4, acc4}:
      sp.a1go5(sp.a1e(acc4, lin4, zz), zz)

def sp.a1go3(g: La, +zz: U32) -> La:
  match g:
    case La{lin3, acc3}:
      sp.a1go4(sp.a1d(acc3, lin3, zz), zz)

def sp.a1go2(g: La, +zz: U32) -> La:
  match g:
    case La{lin2, acc2}:
      sp.a1go3(sp.a1c(acc2, lin2, zz), zz)

def sp.a1go1(g: La, +zz: U32) -> La:
  match g:
    case La{lin1, acc1}:
      sp.a1go2(sp.a1b(acc1, lin1, zz), zz)

# first grouped window sum
def sp.a1(lin: Array<F32>, +zz: U32) -> La:
  sp.a1go1(sp.a1a(lin, zz), zz)

# taps 898, 770, 642, 514
def sp.a2a4(g3: La, +v898: F32, +v770: F32, +v642: F32) -> La:
  match g3:
    case La{lin4, v514}:
      La{lin4,
        f.add(f.add(f.add(f.mul(v898, Enc.f32.bits(1120927744)), f.mul(v770, Enc.f32.bits(1153687552))),
          f.mul(v642, Enc.f32.bits(1175976960))), f.mul(v514, Enc.f32.bits(1199182592)))}

def sp.a2a3(g2: La, +v898: F32, +v770: F32, +zz: U32) -> La:
  match g2:
    case La{lin3, v642}:
      sp.a2a4(ln.at(lin3, u.add(zz, 514)), v898, v770, v642)

def sp.a2a2(g1: La, +v898: F32, +zz: U32) -> La:
  match g1:
    case La{lin2, v770}:
      sp.a2a3(ln.at(lin2, u.add(zz, 642)), v898, v770, zz)

def sp.a2a1(g0: La, +zz: U32) -> La:
  match g0:
    case La{lin1, v898}:
      sp.a2a2(ln.at(lin1, u.add(zz, 770)), v898, zz)

def sp.a2a(lin: Array<F32>, +zz: U32) -> La:
  sp.a2a1(ln.at(lin, u.add(zz, 898)), zz)

# taps 386 and 258
def sp.a2b2(g1: La, +acc: F32, +v386: F32) -> La:
  match g1:
    case La{lin2, v258}:
      La{lin2, f.add(f.add(acc, f.mul(v386, Enc.f32.bits(3323714560))), f.mul(v258, Enc.f32.bits(3258187776)))}

def sp.a2b1(g0: La, +acc: F32, +zz: U32) -> La:
  match g0:
    case La{lin1, v386}:
      sp.a2b2(ln.at(lin1, u.add(zz, 258)), acc, v386)

def sp.a2b(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a2b1(ln.at(lin, u.add(zz, 386)), acc, zz)

# tap 130
def sp.a2c1(g: La, +acc: F32) -> La:
  match g:
    case La{lin1, v130}:
      La{lin1, f.add(acc, f.mul(v130, Enc.f32.bits(1125253120)))}

def sp.a2c(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a2c1(ln.at(lin, u.add(zz, 130)), acc)

# tap 2
def sp.a2d1(g: La, +acc: F32) -> La:
  match g:
    case La{lin1, v2}:
      La{lin1, f.add(acc, f.mul(v2, Enc.f32.bits(3231711232)))}

def sp.a2d(+acc: F32, lin: Array<F32>, +zz: U32) -> La:
  sp.a2d1(ln.at(lin, u.add(zz, 2)), acc)

def sp.a2go3(g: La, +zz: U32) -> La:
  match g:
    case La{lin3, acc3}:
      sp.a2d(acc3, lin3, zz)

def sp.a2go2(g: La, +zz: U32) -> La:
  match g:
    case La{lin2, acc2}:
      sp.a2go3(sp.a2c(acc2, lin2, zz), zz)

def sp.a2go1(g: La, +zz: U32) -> La:
  match g:
    case La{lin1, acc1}:
      sp.a2go2(sp.a2b(acc1, lin1, zz), zz)

# second window sum, eight weighted taps
def sp.a2(lin: Array<F32>, +zz: U32) -> La:
  sp.a2go1(sp.a2a(lin, zz), zz)

# PCM and delay line while pairing synth samples
type Pp is Type:
  Pp{pcm: Array<F32>, lin: Array<F32>}

# one synth pair: two scaled samples
def sp.pair2(g2: La, pcm: Array<F32>, +pcmi: U32, +nch: U32) -> Pp:
  match g2:
    case La{lin2, v2}:
      Pp{ln.set(pcm, u.add(pcmi, u.mul(16, nch)), mac.sc(v2)), lin2}

def sp.pair1(g1: La, pcm: Array<F32>, +pcmi: U32, +nch: U32, +zz: U32) -> Pp:
  match g1:
    case La{lin1, v1}:
      sp.pair2(sp.a2(lin1, zz), ln.set(pcm, pcmi, mac.sc(v1)), pcmi, nch)

def sp.pair(st: Pp, +pcmi: U32, +nch: U32, +zz: U32) -> Pp:
  match st:
    case Pp{pcm, lin}:
      sp.pair1(sp.a1(lin, zz), pcm, pcmi, nch, zz)

# four synth pairs that open a block
def blk.pairs(st: Pp, +nch: U32, +pcmi: U32, +z0: U32) -> Pp:
  sp.pair(sp.pair(sp.pair(sp.pair(st, u.add(pcmi, u.sub(nch, 1)), nch, u.add(z0, 1)), u.add(u.add(pcmi,
    u.mul(32, nch)), u.sub(nch, 1)), nch, u.add(z0, 65)), pcmi, nch, z0), u.add(pcmi, u.mul(32, nch)), nch,
    u.add(z0, 64))

# delay line and the PCM written so far
type Sb is Type:
  Sb{lin: Array<F32>, pcm: Array<F32>}

def blk.armed1(got: Pp) -> Sb:
  match got:
    case Pp{pcm2, lin2}:
      Sb{lin2, pcm2}

# pairs read the delay line the preamble just wrote
def blk.armed(lin: Array<F32>, pcm: Array<F32>, +nch: U32, +tm: U32) -> Sb:
  blk.armed1(blk.pairs(Pp{pcm, lin}, nch, u.mul(u.mul(32, nch), tm), u.add(u.mul(tm, 64), 60)))

# open a block: preamble, then the four pairs
def blk.arm(st: Sb, +gr: List<&2, F32>, +nch: U32, +tm: U32) -> Sb:
  match st:
    case Sb{lin, pcm}:
      blk.armed(blk.pre(lin, gr, nch, u.add(u.mul(tm, 64), 960), tm), pcm, nch, tm)

def blk.row1(got: Mk, pcm: Array<F32>, +nch: U32, +tm: U32, +ii: U32) -> Sb:
  match got:
    case Mk{st, lin2}:
      Sb{lin2, mac.put(pcm, st, nch, u.mul(u.mul(32, nch), tm), ii)}

# window the row just written
def blk.row(
  lin: Array<F32>, pcm: Array<F32>, +nch: U32, +syn: List<&2, F32>, +tm: U32, +ii: U32
) -> Sb:
  blk.row1(mac.k(8n, Mk{mac.z(), lin}, syn, u.add(u.mul(tm, 64), 960), ii, 0), pcm, nch, tm, ii)

# one row of the block, from i = 14 down to 0
def blk.step(st: Sb, +gr: List<&2, F32>, +nch: U32, +syn: List<&2, F32>, +tm: U32, +ii: U32) -> Sb:
  match st:
    case Sb{lin, pcm}:
      blk.row(blk.i(lin, gr, nch, u.add(u.mul(tm, 64), 960), tm, ii), pcm, nch, syn, tm, ii)

# fifteen rows
def blk.i.go(
  hop: Nat, st: Sb, +gr: List<&2, F32>, +nch: U32, +syn: List<&2, F32>, +tm: U32, +ii: U32
) -> Sb:
  match hop:
    case 0n:
      st
    case 1n+p:
      blk.i.go(p, blk.step(st, gr, nch, syn, tm, ii), gr, nch, syn, tm, u.sub(ii, 1))

# one time block
def blk.one(st: Sb, +gr: List<&2, F32>, +nch: U32, +syn: List<&2, F32>, +tm: U32) -> Sb:
  blk.i.go(15n, blk.arm(st, gr, nch, tm), gr, nch, syn, tm, 14)

# nine time blocks, time = 0, 2, ..., 16
def blk.go(hop: Nat, st: Sb, +gr: List<&2, F32>, +nch: U32, +syn: List<&2, F32>, +tm: U32) -> Sb:
  match hop:
    case 0n:
      st
    case 1n+p:
      blk.go(p, blk.one(st, gr, nch, syn, tm), gr, nch, syn, u.add(tm, 2))

# mono keeps the odd delay-line slots
def qmf.mono(hop: Nat, dst: List<&2, F32>, got: La, +ii: U32) -> List<&2, F32>:
  match hop got:
    case 0n La{lin, _v}:
      match lin:
        case _lin:
          dst
    case 1n+p La{lin1, v}:
      qmf.mono(p, f.set(dst, ii, v), ln.at(lin1, u.add(1152, u.add(ii, 2))), u.add(ii, 2))

# stereo copies the whole tail
def qmf.copy(hop: Nat, dst: List<&2, F32>, got: La, +ii: U32) -> List<&2, F32>:
  match hop got:
    case 0n La{lin, _v}:
      match lin:
        case _lin:
          dst
    case 1n+p La{lin1, v}:
      qmf.copy(p, f.set(dst, ii, v), ln.at(lin1, u.add(1152, u.add(ii, 1))), u.add(ii, 1))

# mono or stereo tail
def qmf.pick(mono: Bool, qmf: List<&2, F32>, lin: Array<F32>) -> List<&2, F32>:
  match mono:
    case True{}:
      qmf.mono(480n, qmf, ln.at(lin, 1152), 0)
    case False{}:
      qmf.copy(960n, qmf, ln.at(lin, 1152), 0)

# save the 15-block tail. mono copies only even indices.
def qmf.save(lin: Array<F32>, +qmf: List<&2, F32>, +nch: U32) -> List<&2, F32>:
  qmf.pick(U32.is_eq(nch, 1), qmf, lin)

# PCM, the overlap to carry, and the polyphase delay
type Pc is Data:
  Pc{pcm: List<&2, F32>, ov: List<&2, F32>, qmf: List<&2, F32>}

# zero overlap, 288 samples, one channel
def syn.zov() -> List<&2, F32>:
  List.replicate(F32, 288n, 0.0)

# zero polyphase delay
def syn.zqmf() -> List<&2, F32>:
  List.replicate(F32, 960n, 0.0)

# antialias, IMDCT, and the sign flip for one channel
def ch.prep(
  +spec: List<&2, F32>, +ov: List<&2, F32>, +aa: List<&2, F32>, +tw: List<&2, F32>, +win: List<&2, F32>
) -> Im:
  im.sign(im.go(32n, Im{aa.run(spec, aa), ov}, tw, win, 0))

# append the second channel
def syn.st2(+ba: List<&2, F32>, +oa: List<&2, F32>, bb: Im) -> Im:
  match bb:
    case Im{buf, ov}:
      Im{List.append(&2, F32, ba, buf), List.append(&2, F32, oa, ov)}

# join two channel states
def syn.st(aa: Im, bb: Im) -> Im:
  match aa:
    case Im{+ba, +oa}:
      syn.st2(ba, oa, bb)

# prepare one or two channels
def syn.ch(
  mono: Bool, +spec: List<&2, F32>, +ov: List<&2, F32>, +aa: List<&2, F32>, +tw: List<&2, F32>,
  +win: List<&2, F32>
) -> Im:
  match mono:
    case True{}:
      ch.prep(spec, ov, aa, tw, win)
    case False{}:
      syn.st(ch.prep(ls.slice(spec, 0, 576n), ls.slice(ov, 0, 288n), aa, tw, win),
        ch.prep(ls.slice(spec, 576, 576n), ls.slice(ov, 288, 288n), aa, tw, win))

# tables shared by a granule
def syn.ready(+spec: List<&2, F32>, +ov: List<&2, F32>, +nch: U32) -> Im:
  syn.ch(U32.is_eq(nch, 1), spec, ov, Enc.f.of(Tab.tab.aa()), Enc.f.of(Tab.tab.tw()),
    Enc.f.of(Tab.tab.winl()))

# DCT-II of each channel
def sy.dct(mono: Bool, +buf: List<&2, F32>, +sec: List<&2, F32>) -> List<&2, F32>:
  match mono:
    case True{}:
      dc.run(18n, buf, sec, 0)
    case False{}:
      List.append(&2, F32, dc.run(18n, ls.slice(buf, 0, 576n), sec, 0),
        dc.run(18n, ls.slice(buf, 576, 576n), sec, 0))

# delay line: the carried tail, then zeros (4096-slot Array starts at 0.0)
def sy.lin(+qmf: List<&2, F32>) -> Array<F32>:
  ln.fill(qmf, Array.new(F32, 12n, 0.0), 0)

# empty PCM for one granule (2048-slot Array covers mono 576 and stereo 1152)
def sy.pcm() -> Array<F32>:
  Array.new(F32, 11n, 0.0)

# PCM Array back to a list of length 576*nch
def sy.pcm.list(+nch: U32, pcm: Array<F32>) -> List<&2, F32>:
  ln.list(pcm, U32.to_nat(u.sub(u.mul(576, nch), 1)))

# run the polyphase and keep the overlap from the IMDCT
def syn.out(st: Sb, +ov: List<&2, F32>, +qmf: List<&2, F32>, +nch: U32) -> Pc:
  match st:
    case Sb{lin, pcm}:
      Pc{sy.pcm.list(nch, pcm), ov, qmf.save(lin, qmf, nch)}

# DCT-II then nine polyphase blocks
def syn.pcm(+buf: List<&2, F32>, +ov: List<&2, F32>, +qmf: List<&2, F32>, +nch: U32) -> Pc:
  syn.out(blk.go(9n, Sb{sy.lin(qmf), sy.pcm()}, sy.dct(U32.is_eq(nch, 1), buf, Enc.f.of(Tab.tab.sec())),
    nch, Enc.f.of(Tab.tab.syn()), 0), ov, qmf, nch)

# synthesis of a prepared granule
def syn.finish(st: Im, +qmf: List<&2, F32>, +nch: U32) -> Pc:
  match st:
    case Im{buf, ov}:
      syn.pcm(buf, ov, qmf, nch)

# one granule to PCM. spec is 576 samples per channel. ov is 288 per channel.
def syn.gran(+spec: List<&2, F32>, +ov: List<&2, F32>, +qmf: List<&2, F32>, +nch: U32) -> Pc:
  syn.finish(syn.ready(spec, ov, nch), qmf, nch)

# IMDCT only, 32 bands, no antialias. Used to check the unit impulse.
def syn.im(+buf: List<&2, F32>, +ov: List<&2, F32>) -> Im:
  im.go(32n, Im{buf, ov}, Enc.f.of(Tab.tab.tw()), Enc.f.of(Tab.tab.winl()), 0)

# one PCM sample of a granule, as a binary32 word
def syn.nth(st: Pc, +ii: U32) -> U32:
  match st:
    case Pc{pcm, _ov, _qmf}:
      Enc.f32.word(f.at(pcm, ii))

# first sample of an IMDCT buffer, as a binary32 word
def syn.word(st: Im) -> U32:
  match st:
    case Im{buf, _ov}:
      Enc.f32.word(f.at(buf, 0))

# PCM word ii of one granule whose spectrum is a unit impulse at bin 0.
def syn.probe(+ii: U32) -> U32:
  syn.nth(syn.gran(f.set(List.replicate(F32, 576n, 0.0), 0, Enc.f32.bits(1065353216)), syn.zov(),
    syn.zqmf(), 1), ii)

# unit impulse at bin 0. The first sample is the float32 word 1022453915.
def syn.impulse() -> U32:
  syn.word(syn.im(f.set(List.replicate(F32, 576n, 0.0), 0, Enc.f32.bits(1065353216)), syn.zov()))
