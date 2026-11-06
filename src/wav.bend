# RIFF WAVE. PCM is little-endian signed 16-bit. Float is IEEE binary32.
#
# The reader walks the chunks in order: `fmt ` first, then any chunks it does
# not know, then `data`, whose samples it reads straight from the input. It
# stops there, as libsndfile, dr_wav and Python's wave do, so what follows the
# data chunk (a LIST chunk, an ID3 tag, junk) is not read. A data chunk larger
# than what is left (a truncated file, or 0xFFFFFFFF from a streamed writer)
# is clamped to the bytes present, and the samples to whole frames.
import Base

# a parsed wave. kind 1 is signed 16-bit, kind 3 is binary32. frames are interleaved.
type Wav is Data:
  Wav{rate: U32, channels: U32, kind: U32, frames: List<&2, U32>}

# fmt fields that passed the checks
type Fm is Data:
  Fm{kind: U32, ch: U32, rate: U32}

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

# 'fact'
def tag.fact() -> U32:
  1717658484

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

# the list after its first hop elements, or [] when it is shorter
def ls.skip(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      xs
    case 1n+pp:
      match xs:
        case Nil{}:
          []
        case _hd <> tl:
          ls.skip(pp, tl)

# a chunk's payload and its pad byte: an odd size carries one
def chunk.span(+sz: U32) -> Nat:
  Nat.add(U32.to_nat(sz), U32.to_nat((sz .&. 1 : U32)))

def fmt.rate(ok: Bool, +kind: U32, +ch: U32, +rate: U32) -> Maybe<&2, Fm>:
  match ok:
    case True{}:
      Some{Fm{kind, ch, rate}}
    case False{}:
      None{}

# mono or stereo 16-bit PCM or 32-bit float at a non-zero rate. The block
# align and byte rate are not checked: they follow from the channels and the
# bits, and readers such as Python's wave and dr_wav derive them the same way.
def fmt.ok(+kind: U32, +ch: U32, +rate: U32, +bits: U32) -> Maybe<&2, Fm>:
  match kind ch bits:
    case 1 1 16:
      fmt.rate(U32.is_ne(rate, 0), kind, ch, rate)
    case 1 2 16:
      fmt.rate(U32.is_ne(rate, 0), kind, ch, rate)
    case 3 1 32:
      fmt.rate(U32.is_ne(rate, 0), kind, ch, rate)
    case 3 2 32:
      fmt.rate(U32.is_ne(rate, 0), kind, ch, rate)
    case _ _ _:
      None{}

# the tail of KSDATAFORMAT_SUBTYPE_PCM and _IEEE_FLOAT after their first word
def guid.tail() -> List<&2, U32>:
  [0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113]

# do the bytes of xs begin ys: ok carries the match so far and stops the walk
def guid.is(xs: List<&2, U32>, ys: List<&2, U32>, ok: Bool) -> Bool:
  match xs:
    case Nil{}:
      ok
    case +hx <> tx:
      match ys:
        case Nil{}:
          False{}
        case +hy <> ty:
          match ok:
            case False{}:
              False{}
            case True{}:
              guid.is(tx, ty, U32.is_eq(hx, hy))

def guid.kind(ok: Bool, +kind: U32) -> U32:
  match ok:
    case True{}:
      kind
    case False{}:
      0

# WAVE_FORMAT_EXTENSIBLE: after cbSize, the valid bits and the channel mask,
# the first word of the sub-format GUID is the format tag
def fmt.sub(rest: List<&2, U32>) -> U32:
  match rest:
    case _c0 <> _c1 <> _v0 <> _v1 <> _m0 <> _m1 <> _m2 <> _m3 <> +g0 <> +g1 <> tl:
      guid.kind(guid.is(guid.tail(), tl, True{}), le.u16(g0, g1))
    case _:
      0

# the format tag: 1 and 3 as they are, 0xFFFE through its sub-format when the
# chunk holds it (40 bytes or more), and 0 for anything else
def fmt.tag.at(ext: Bool, +sz: U32, +tag: U32, rest: List<&2, U32>) -> U32:
  match ext:
    case False{}:
      tag
    case True{}:
      guid.kind(U32.is_le(40, sz), fmt.sub(rest))

def fmt.pack(
  +sz: U32,
  +kind: U32,
  +ch: U32,
  +rate: U32,
  +bits: U32,
  rest: List<&2, U32>
) -> Maybe<&2, Fm>:
  fmt.ok(fmt.tag.at(U32.is_eq(kind, 65534), sz, kind, rest), ch, rate, bits)

def fmt.read(+sz: U32, ys: List<&2, U32>) -> Maybe<&2, Fm>:
  match ys:
    case +k0 <> +k1 <> +c0 <> +c1 <> +r0 <> +r1 <> +r2 <> +r3 <> _b0 <> _b1 <> _b2 <> _b3
      <> _a0 <> _a1 <> +t0 <> +t1 <> rest:
      fmt.pack(sz, le.u16(k0, k1), le.u16(c0, c1), le.u32(r0, r1, r2, r3), le.u16(t0, t1), rest)
    case _:
      None{}

def fmt.long(ok: Bool, +sz: U32, ys: List<&2, U32>) -> Maybe<&2, Fm>:
  match ok:
    case False{}:
      None{}
    case True{}:
      fmt.read(sz, ys)

# the fmt chunk's fields. A chunk under 16 bytes is none.
def fmt.fields(+sz: U32, ys: List<&2, U32>) -> Maybe<&2, Fm>:
  fmt.long(U32.is_le(16, sz), sz, ys)

def pcm.s16(nn: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match nn:
    case 0n:
      []
    case 1n+pp:
      match xs:
        case +lo <> +hi <> tl:
          le.u16(lo, hi) <> pcm.s16(pp, tl)
        case _:
          []

def pcm.f32(nn: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match nn:
    case 0n:
      []
    case 1n+pp:
      match xs:
        case +a0 <> +a1 <> +a2 <> +a3 <> tl:
          le.u32(a0, a1, a2, a3) <> pcm.f32(pp, tl)
        case _:
          []

def pcm.of(+kind: U32, nn: Nat, ys: List<&2, U32>) -> List<&2, U32>:
  match kind:
    case 1:
      pcm.s16(nn, ys)
    case _:
      pcm.f32(nn, ys)

# bytes per sample
def width.nat(+kind: U32) -> Nat:
  match kind:
    case 1:
      2n
    case _:
      4n

# the samples in the whole frames of have bytes
def data.count(+kind: U32, +ch: U32, +have: Nat) -> Nat:
  Nat.mul(Nat.div(have, Nat.mul(width.nat(kind), U32.to_nat(ch))), U32.to_nat(ch))

# the data chunk: its size clamped to the bytes left, its samples to whole frames
def data.read(fm: Fm, +sz: U32, +rest: List<&2, U32>) -> Maybe<&2, Wav>:
  match fm:
    case Fm{+kind, +ch, +rate}:
      Some{Wav{rate, ch, kind,
        pcm.of(kind, data.count(kind, ch, Nat.min(U32.to_nat(sz), List.length(&2, U32, rest))), rest)}}

# one step of the chunk walk: done, or the chunks left and the fmt seen so far
type Step is Data:
  Fin{got: Maybe<&2, Wav>}
  Go{fm: Maybe<&2, Fm>, xs: List<&2, U32>}

def step.fmt(got: Maybe<&2, Fm>, rest: List<&2, U32>) -> Step:
  match got:
    case None{}:
      Fin{None{}}
    case Some{fm}:
      Go{Some{fm}, rest}

# a chunk before fmt: fmt is read, data is none, anything else is skipped
def step.pre.data(isd: Bool, +sz: U32, rest: List<&2, U32>) -> Step:
  match isd:
    case True{}:
      Fin{None{}}
    case False{}:
      Go{None{}, ls.skip(chunk.span(sz), rest)}

def step.pre(isf: Bool, +tag: U32, +sz: U32, +rest: List<&2, U32>) -> Step:
  match isf:
    case True{}:
      step.fmt(fmt.fields(sz, rest), ls.skip(chunk.span(sz), rest))
    case False{}:
      step.pre.data(U32.is_eq(tag, tag.data()), sz, rest)

# a chunk after fmt: data is read and ends the walk, anything else is skipped
def step.post(isd: Bool, fm: Fm, +sz: U32, rest: List<&2, U32>) -> Step:
  match isd:
    case True{}:
      Fin{data.read(fm, sz, rest)}
    case False{}:
      Go{Some{fm}, ls.skip(chunk.span(sz), rest)}

def step.on(got: Maybe<&2, Fm>, +tag: U32, +sz: U32, rest: List<&2, U32>) -> Step:
  match got:
    case None{}:
      step.pre(U32.is_eq(tag, tag.fmt()), tag, sz, rest)
    case Some{fm}:
      step.post(U32.is_eq(tag, tag.data()), fm, sz, rest)

# read one chunk header. Fewer than eight bytes left, and no data chunk, is none.
def step.of(got: Maybe<&2, Fm>, xs: List<&2, U32>) -> Step:
  match xs:
    case +t0 <> +t1 <> +t2 <> +t3 <> +s0 <> +s1 <> +s2 <> +s3 <> rest:
      step.on(got, be.u32(t0, t1, t2, t3), le.u32(s0, s1, s2, s3), rest)
    case _:
      Fin{None{}}

# walk the chunks. Each step reads an eight-byte header, so the fuel, one
# more than the bytes, is never spent first.
def chunk.walk(fuel: Nat, st: Step) -> Maybe<&2, Wav>:
  match fuel:
    case 0n:
      None{}
    case 1n+pp:
      match st:
        case Fin{got}:
          got
        case Go{fm, xs}:
          chunk.walk(pp, step.of(fm, xs))

def open.ok(ok: Bool, +rest: List<&2, U32>) -> Maybe<&2, Wav>:
  match ok:
    case True{}:
      chunk.walk(1n+List.length(&2, U32, rest), Go{None{}, rest})
    case False{}:
      None{}

# bytes to a wave, or none when the form is not mono or stereo PCM or float.
# The RIFF size is not read: the walk stops at the data chunk.
def wav.parse(xs: List<&2, U32>) -> Maybe<&2, Wav>:
  match xs:
    case +a <> +b <> +c <> +d <> _s0 <> _s1 <> _s2 <> _s3 <> +w0 <> +w1 <> +w2 <> +w3 <> rest:
      open.ok(
        U32.is_eq(be.u32(a, b, c, d), tag.riff()) && U32.is_eq(be.u32(w0, w1, w2, w3), tag.wave()),
        rest)
    case _:
      None{}

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

# every sample is below 2^16: ok carries the check so far and stops the walk
def enc.low16(xs: List<&2, U32>, ok: Bool) -> Bool:
  match xs:
    case Nil{}:
      ok
    case +hd <> tl:
      match ok:
        case False{}:
          False{}
        case True{}:
          enc.low16(tl, U32.is_lt(hd, 65536))

# every s16 sample fits its 16 bits; binary32 words always fit
def enc.fits(+kind: U32, xs: List<&2, U32>) -> Bool:
  match kind:
    case 1:
      enc.low16(xs, True{})
    case _:
      True{}

# the header bytes before the samples: 44 for PCM, 58 for float, which also
# carries cbSize and a fact chunk
def head.n(+kind: U32) -> U32:
  match kind:
    case 1:
      44
    case _:
      58

# the byte rate, the data size and the RIFF size all fit a U32
def enc.sized(+rate: U32, +ch: U32, +kind: U32, +ns: U32) -> Bool:
  U32.is_le(rate, U32.div(4294967295, align.of(kind, ch)))
    && U32.is_le(ns, U32.div((4294967295 - head.n(kind) : U32), U32.div(width.of(kind), 8)))

def enc.fmt.body(+rate: U32, +ch: U32, +kind: U32) -> List<&2, U32>:
  enc.cat(put.u16(kind),
    enc.cat(put.u16(ch),
      enc.cat(put.u32(rate),
        enc.cat(put.u32((rate * align.of(kind, ch) : U32)),
          enc.cat(put.u16(align.of(kind, ch)), put.u16(width.of(kind)))))))

# the fmt chunk and, for float, its cbSize and a fact chunk with the frame count
def enc.fmt(+rate: U32, +ch: U32, +kind: U32, +ns: U32) -> List<&2, U32>:
  match kind:
    case 1:
      enc.cat(put.be(tag.fmt()), enc.cat(put.u32(16), enc.fmt.body(rate, ch, kind)))
    case _:
      enc.cat(put.be(tag.fmt()),
        enc.cat(put.u32(18),
          enc.cat(enc.fmt.body(rate, ch, kind),
            enc.cat(put.u16(0),
              enc.cat(put.be(tag.fact()), enc.cat(put.u32(4), put.u32(U32.div(ns, ch))))))))

def enc.head(+rate: U32, +ch: U32, +kind: U32, +ns: U32, +nb: U32) -> List<&2, U32>:
  enc.cat(put.be(tag.riff()),
    enc.cat(put.u32(((head.n(kind) - 8 : U32) + nb : U32)),
      enc.cat(put.be(tag.wave()),
        enc.cat(enc.fmt(rate, ch, kind, ns),
          enc.cat(put.be(tag.data()), put.u32(nb))))))

def write.some(
  +rate: U32,
  +ch: U32,
  +kind: U32,
  +ns: U32,
  pcm: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  Some{enc.cat(enc.head(rate, ch, kind, ns, enc.bytes(kind, ns)), pcm)}

def write.if(
  ok: Bool,
  +rate: U32,
  +ch: U32,
  +kind: U32,
  +ns: U32,
  frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      write.some(rate, ch, kind, ns, enc.pcm(kind, frames))

def write.n(+rate: U32, +ch: U32, +kind: U32, +ns: U32, +frames: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  write.if(enc.ok(ch, kind, rate) && enc.sized(rate, ch, kind, ns) && enc.fits(kind, frames), rate, ch, kind, ns,
    frames)

# a wave file, or none when the clip is not 16-bit PCM or 32-bit float, mono
# or stereo, an s16 sample does not fit 16 bits, or a size does not fit a U32
def wav.write(+rate: U32, +ch: U32, +kind: U32, +frames: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  write.n(rate, ch, kind, U32.from_nat(List.length(&2, U32, frames)), frames)
