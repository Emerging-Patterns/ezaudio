# RIFF WAVE. PCM is little-endian signed 16-bit. Float is IEEE binary32.
import Base

# a parsed wave. kind 1 is signed 16-bit, kind 3 is binary32. frames are interleaved.
type Wav is Data:
  Wav{rate: U32, channels: U32, kind: U32, frames: List<&2, U32>}

# fmt fields that passed the PCM checks
type Fm is Data:
  Fm{kind: U32, ch: U32, rate: U32}

# the chunk walker: phase 0 tag, 1 size, 2 payload, 3 pad byte
type St is Data:
  St{
    phase: U32, left: U32, tag: U32, sz: U32, seen: U32, kind: U32, ch: U32,
    rate: U32, acc: List<&2, U32>, frames: List<&2, U32>
  }

# 'RIFF'
def tag.riff() -> U32:
  1380533830

# 'WAVE'
def tag.wave() -> U32:
  1463899717

# 'fmt '
def tag.fmt() -> U32:
  1718449184

# 'data'
def tag.data() -> U32:
  1684108385

def be.u32(+aa: U32, +bb: U32, +cc: U32, +dd: U32) -> U32:
  ((((aa << 24n : U32) .|. (bb << 16n : U32) : U32) .|. (cc << 8n : U32) : U32) .|. dd : U32)

def le.u16(+aa: U32, +bb: U32) -> U32:
  (aa .|. (bb << 8n : U32) : U32)

def le.u32(+aa: U32, +bb: U32, +cc: U32, +dd: U32) -> U32:
  (le.u16(aa, bb) .|. (le.u16(cc, dd) << 16n : U32) : U32)

def put.u16(+vv: U32) -> List<&2, U32>:
  [(vv .&. 255 : U32), ((vv >> 8n : U32) .&. 255 : U32)]

def put.u32(+vv: U32) -> List<&2, U32>:
  List.append(&2, U32, put.u16(vv), put.u16((vv >> 16n : U32)))

def put.be(+vv: U32) -> List<&2, U32>:
  [((vv >> 24n : U32) .&. 255 : U32), ((vv >> 16n : U32) .&. 255 : U32),
   ((vv >> 8n : U32) .&. 255 : U32), (vv .&. 255 : U32)]

def put.lo(+vv: U32) -> U32:
  (vv .&. 255 : U32)

def put.hi(+vv: U32) -> U32:
  ((vv >> 8n : U32) .&. 255 : U32)

def put.b2(+vv: U32) -> U32:
  ((vv >> 16n : U32) .&. 255 : U32)

def put.b3(+vv: U32) -> U32:
  ((vv >> 24n : U32) .&. 255 : U32)

def word4.pick(big: Bool, +aa: U32, +bb: U32, +cc: U32, +dd: U32) -> U32:
  match big:
    case True{}:
      be.u32(aa, bb, cc, dd)
    case False{}:
      le.u32(aa, bb, cc, dd)

def word.of(xs: List<&2, U32>, +big: U32) -> U32:
  match xs:
    case +dd <> +cc <> +bb <> +aa <> _tl:
      word4.pick(U32.is_eq(big, 1), aa, bb, cc, dd)
    case _:
      0

def st.empty() -> St:
  St{0, 4, 0, 0, 0, 0, 0, 0, [], []}

def st.set(
  +phase: U32, +left: U32, +tag: U32, +sz: U32, +seen: U32, +kind: U32, +ch: U32,
  +rate: U32, acc: List<&2, U32>, frames: List<&2, U32>
) -> St:
  St{phase, left, tag, sz, seen, kind, ch, rate, acc, frames}

def fmt.rate(ok: Bool, +kind: U32, +ch: U32, +rate: U32) -> Maybe<&2, Fm>:
  match ok:
    case True{}:
      Some{Fm{kind, ch, rate}}
    case False{}:
      None{}

def fmt.ok(+kind: U32, +ch: U32, +rate: U32, +br: U32, +al: U32, +bits: U32) -> Maybe<&2, Fm>:
  match kind ch bits:
    case 1 1 16:
      fmt.rate(U32.is_eq(al, 2) && U32.is_eq(br, (rate * 2 : U32)) && U32.is_ne(rate, 0), kind, ch, rate)
    case 1 2 16:
      fmt.rate(U32.is_eq(al, 4) && U32.is_eq(br, (rate * 4 : U32)) && U32.is_ne(rate, 0), kind, ch, rate)
    case 3 1 32:
      fmt.rate(U32.is_eq(al, 4) && U32.is_eq(br, (rate * 4 : U32)) && U32.is_ne(rate, 0), kind, ch, rate)
    case 3 2 32:
      fmt.rate(U32.is_eq(al, 8) && U32.is_eq(br, (rate * 8 : U32)) && U32.is_ne(rate, 0), kind, ch, rate)
    case _ _ _:
      None{}

def fmt.pack(
  +k0: U32, +k1: U32, +c0: U32, +c1: U32, +r0: U32, +r1: U32, +r2: U32, +r3: U32,
  +b0: U32, +b1: U32, +b2: U32, +b3: U32, +a0: U32, +a1: U32, +t0: U32, +t1: U32
) -> Maybe<&2, Fm>:
  fmt.ok(
    le.u16(k0, k1), le.u16(c0, c1), le.u32(r0, r1, r2, r3), le.u32(b0, b1, b2, b3),
    le.u16(a0, a1), le.u16(t0, t1))

def fmt.fields(ys: List<&2, U32>) -> Maybe<&2, Fm>:
  match ys:
    case +k0 <> +k1 <> +c0 <> +c1 <> +r0 <> +r1 <> +r2 <> +r3 <> +b0 <> +b1 <> +b2 <> +b3
      <> +a0 <> +a1 <> +t0 <> +t1 <> _rest:
      fmt.pack(k0, k1, c0, c1, r0, r1, r2, r3, b0, b1, b2, b3, a0, a1, t0, t1)
    case _:
      None{}

def pcm.cons(got: Maybe<&2, List<&2, U32>>, +vv: U32) -> Maybe<&2, List<&2, U32>>:
  match got:
    case None{}:
      None{}
    case Some{rest}:
      Some{vv <> rest}

def pcm.s16(xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Some{[]}
    case +lo <> +hi <> tl:
      pcm.cons(pcm.s16(tl), le.u16(lo, hi))
    case _:
      None{}

def pcm.f32(xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Some{[]}
    case +a0 <> +a1 <> +a2 <> +a3 <> tl:
      pcm.cons(pcm.f32(tl), le.u32(a0, a1, a2, a3))
    case _:
      None{}

def pcm.of(+kind: U32, ys: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match kind:
    case 1:
      pcm.s16(ys)
    case _:
      pcm.f32(ys)

def done.ok(ok: Bool, +rt: U32, +ch: U32, +kd: U32, fr: List<&2, U32>) -> Maybe<&2, Wav>:
  match ok:
    case True{}:
      Some{Wav{rt, ch, kd, fr}}
    case False{}:
      None{}

def st.done(st: St) -> Maybe<&2, Wav>:
  match st:
    case St{ph, lf, _tg, _sz, sn, kd, ch, rt, _ac, fr}:
      done.ok(U32.is_eq(ph, 0) && U32.is_eq(lf, 4) && U32.is_eq(sn, 2), rt, ch, kd, fr)

def step.next.pad(
  odd: Bool, +sz: U32, +tag: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32,
  frames: List<&2, U32>
) -> St:
  match odd:
    case True{}:
      st.set(3, 1, tag, sz, seen, kind, ch, rate, [], frames)
    case False{}:
      st.set(0, 4, tag, sz, seen, kind, ch, rate, [], frames)

def step.next(
  +sz: U32, +tag: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32, frames: List<&2, U32>
) -> St:
  step.next.pad(U32.is_eq((sz .&. 1 : U32), 1), sz, tag, seen, kind, ch, rate, frames)

def step.fmt.got(got: Maybe<&2, Fm>, +sz: U32, frames: List<&2, U32>) -> St:
  match got:
    case None{}:
      step.next(sz, tag.fmt(), 3, 0, 0, 0, frames)
    case Some{Fm{kd, cc, rt}}:
      step.next(sz, tag.fmt(), 1, kd, cc, rt, frames)

def step.fmt(
  +sz: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32, ys: List<&2, U32>,
  frames: List<&2, U32>
) -> St:
  match seen:
    case 0:
      step.fmt.got(fmt.fields(ys), sz, frames)
    case _:
      step.next(sz, tag.fmt(), seen, kind, ch, rate, frames)

def step.pcm.got(
  got: Maybe<&2, List<&2, U32>>, +sz: U32, +kind: U32, +ch: U32, +rate: U32
) -> St:
  match got:
    case None{}:
      step.next(sz, tag.data(), 3, kind, ch, rate, [])
    case Some{fr}:
      step.next(sz, tag.data(), 2, kind, ch, rate, fr)

def step.pcm(
  ready: Bool, +sz: U32, +kind: U32, +ch: U32, +rate: U32, ys: List<&2, U32>,
  frames: List<&2, U32>
) -> St:
  match ready:
    case False{}:
      step.next(sz, tag.data(), 3, kind, ch, rate, frames)
    case True{}:
      step.pcm.got(pcm.of(kind, ys), sz, kind, ch, rate)

def step.dat(
  isd: Bool, +tag: U32, +sz: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32,
  ys: List<&2, U32>, frames: List<&2, U32>
) -> St:
  match isd:
    case False{}:
      step.next(sz, tag, seen, kind, ch, rate, frames)
    case True{}:
      step.pcm(U32.is_eq(seen, 1), sz, kind, ch, rate, ys, frames)

def step.chunk.on(
  isf: Bool, +tag: U32, +sz: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32,
  ys: List<&2, U32>, frames: List<&2, U32>
) -> St:
  match isf:
    case True{}:
      step.fmt(sz, seen, kind, ch, rate, ys, frames)
    case False{}:
      step.dat(U32.is_eq(tag, tag.data()), tag, sz, seen, kind, ch, rate, ys, frames)

def step.chunk(
  +tag: U32, +sz: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32,
  ys: List<&2, U32>, frames: List<&2, U32>
) -> St:
  step.chunk.on(U32.is_eq(tag, tag.fmt()), tag, sz, seen, kind, ch, rate, ys, frames)

def step.tag.at(
  last: Bool, +left: U32, +sz: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32,
  acc: List<&2, U32>, frames: List<&2, U32>
) -> St:
  match last:
    case False{}:
      st.set(0, (left - 1 : U32), 0, sz, seen, kind, ch, rate, acc, frames)
    case True{}:
      st.set(1, 4, word.of(acc, 1), sz, seen, kind, ch, rate, [], frames)

def step.tag(st: St, +hd: U32) -> St:
  match st:
    case St{_ph, +left, _tg, sz, seen, kind, ch, rate, acc, frames}:
      step.tag.at(U32.is_eq(left, 1), left, sz, seen, kind, ch, rate, hd <> acc, frames)

def step.size.done(
  +sz: U32, +tag: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32, frames: List<&2, U32>
) -> St:
  match sz:
    case 0:
      st.set(0, 4, tag, sz, seen, kind, ch, rate, [], frames)
    case _:
      st.set(2, sz, tag, sz, seen, kind, ch, rate, [], frames)

def step.size.at(
  last: Bool, +left: U32, +tag: U32, +seen: U32, +kind: U32, +ch: U32, +rate: U32,
  acc: List<&2, U32>, frames: List<&2, U32>
) -> St:
  match last:
    case False{}:
      st.set(1, (left - 1 : U32), tag, 0, seen, kind, ch, rate, acc, frames)
    case True{}:
      step.size.done(word.of(acc, 0), tag, seen, kind, ch, rate, frames)

def step.size(st: St, +hd: U32) -> St:
  match st:
    case St{_ph, +left, tag, _sz, seen, kind, ch, rate, acc, frames}:
      step.size.at(U32.is_eq(left, 1), left, tag, seen, kind, ch, rate, hd <> acc, frames)

def step.pad(st: St) -> St:
  match st:
    case St{_phase, _left, tag, sz, seen, kind, ch, rate, _acc, frames}:
      st.set(0, 4, tag, sz, seen, kind, ch, rate, [], frames)

def step.pay.at(
  last: Bool, +left: U32, +tag: U32, +sz: U32, +seen: U32, +kind: U32, +ch: U32,
  +rate: U32, acc: List<&2, U32>, frames: List<&2, U32>
) -> St:
  match last:
    case False{}:
      st.set(2, (left - 1 : U32), tag, sz, seen, kind, ch, rate, acc, frames)
    case True{}:
      step.chunk(tag, sz, seen, kind, ch, rate, List.reverse(&2, U32, acc), frames)

def step.pay(st: St, +hd: U32) -> St:
  match st:
    case St{_ph, +left, tag, sz, seen, kind, ch, rate, acc, frames}:
      step.pay.at(U32.is_eq(left, 1), left, tag, sz, seen, kind, ch, rate, hd <> acc, frames)

def step.err.dec(
  last: Bool, +phase: U32, +left: U32, +tag: U32, +sz: U32, +kind: U32, +ch: U32,
  +rate: U32, acc: List<&2, U32>, frames: List<&2, U32>
) -> St:
  match last:
    case False{}:
      st.set(phase, (left - 1 : U32), tag, sz, 3, kind, ch, rate, acc, frames)
    case True{}:
      st.set(0, 4, tag, sz, 3, kind, ch, rate, [], frames)

def step.err.keep(+phase: U32, st: St, +hd: U32) -> St:
  match st:
    case St{phase, +left, tag, sz, _sn, kind, ch, rate, acc, frames}:
      step.err.dec(U32.is_eq(left, 1), phase, left, tag, sz, kind, ch, rate, hd <> acc, frames)

def step.on(+phase: U32, st: St, +hd: U32) -> St:
  match phase:
    case 0:
      step.tag(st, hd)
    case 1:
      step.size(st, hd)
    case 2:
      step.pay(st, hd)
    case _:
      step.pad(st)

def step.bad(bad: Bool, +phase: U32, st: St, +hd: U32) -> St:
  match bad:
    case True{}:
      step.err.keep(phase, st, hd)
    case False{}:
      step.on(phase, st, hd)

def step.byte(st: St, +hd: U32) -> St:
  match st:
    case St{+phase, +left, +tag, +sz, +seen, +kind, +ch, +rate, +acc, +frames}:
      step.bad(
        U32.is_eq(seen, 3), phase,
        st.set(phase, left, tag, sz, seen, kind, ch, rate, acc, frames), hd)

def walk.go(xs: List<&2, U32>, st: St) -> Maybe<&2, Wav>:
  match xs:
    case Nil{}:
      st.done(st)
    case +hd <> tl:
      walk.go(tl, step.byte(st, hd))

def open.ok(ok: Bool, rest: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{rest}
    case False{}:
      None{}

def open.riff(xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match xs:
    case +a <> +b <> +c <> +d <> +s0 <> +s1 <> +s2 <> +s3 <> +w0 <> +w1 <> +w2 <> +w3 <> rest:
      open.ok(
        U32.is_eq(be.u32(a, b, c, d), tag.riff()) && U32.is_eq(be.u32(w0, w1, w2, w3), tag.wave()),
        rest)
    case _:
      None{}

def wav.go(got: Maybe<&2, List<&2, U32>>) -> Maybe<&2, Wav>:
  match got:
    case None{}:
      None{}
    case Some{rest}:
      walk.go(rest, st.empty())

# bytes to a wave, or none when the form is not mono or stereo PCM or float
def wav.parse(xs: List<&2, U32>) -> Maybe<&2, Wav>:
  wav.go(open.riff(xs))

def enc.s16(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      put.lo(hd) <> put.hi(hd) <> enc.s16(tl)

def enc.f32(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +hd <> tl:
      put.lo(hd) <> put.hi(hd) <> put.b2(hd) <> put.b3(hd) <> enc.f32(tl)

def enc.pcm(+kind: U32, xs: List<&2, U32>) -> List<&2, U32>:
  match kind:
    case 1:
      enc.s16(xs)
    case _:
      enc.f32(xs)

def enc.ch(+nc: U32) -> Bool:
  match nc:
    case 1:
      True{}
    case 2:
      True{}
    case _:
      False{}

def enc.both(okc: Bool, okr: Bool) -> Bool:
  match okc:
    case False{}:
      False{}
    case True{}:
      okr

def enc.ok(+nc: U32, +fk: U32, +rt: U32) -> Bool:
  match fk:
    case 1:
      enc.both(enc.ch(nc), U32.is_ne(rt, 0))
    case 3:
      enc.both(enc.ch(nc), U32.is_ne(rt, 0))
    case _:
      False{}

def enc.bytes(+kind: U32, +ns: U32) -> U32:
  match kind:
    case 1:
      (ns * 2 : U32)
    case _:
      (ns * 4 : U32)

def enc.cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

def align.of(+kind: U32, +ch: U32) -> U32:
  match kind:
    case 1:
      (ch * 2 : U32)
    case _:
      (ch * 4 : U32)

def width.of(+kind: U32) -> U32:
  match kind:
    case 1:
      16
    case _:
      32

def enc.head(+rate: U32, +ch: U32, +kind: U32, +nb: U32) -> List<&2, U32>:
  enc.cat(put.be(tag.riff()),
    enc.cat(put.u32((36 + nb : U32)),
      enc.cat(put.be(tag.wave()),
        enc.cat(put.be(tag.fmt()),
          enc.cat(put.u32(16),
            enc.cat(put.u16(kind),
              enc.cat(put.u16(ch),
                enc.cat(put.u32(rate),
                  enc.cat(put.u32((rate * align.of(kind, ch) : U32)),
                    enc.cat(put.u16(align.of(kind, ch)),
                      enc.cat(put.u16(width.of(kind)),
                        enc.cat(put.be(tag.data()), put.u32(nb)))))))))))))

def write.some(
  +rate: U32, +ch: U32, +kind: U32, frames: List<&2, U32>, pcm: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  nb = enc.bytes(kind, U32.from_nat(List.length(&2, U32, frames)))
  Some{enc.cat(enc.head(rate, ch, kind, nb), pcm)}

def write.if(
  ok: Bool, +rate: U32, +ch: U32, +kind: U32, +frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      write.some(rate, ch, kind, frames, enc.pcm(kind, frames))

# a wave file, or none when the clip is not 16-bit PCM or 32-bit float, mono or stereo
def wav.write(+rate: U32, +ch: U32, +kind: U32, frames: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  write.if(enc.ok(ch, kind, rate), rate, ch, kind, frames)
