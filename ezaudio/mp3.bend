# MPEG-1 Layer III (ISO/IEC 11172-3). Mono and stereo. Layer I and II are rejected.
import Base
import ./mp3_enc.bend as Enc
import ./mp3_dec.bend as Dec

# one pulled bit, or a field, beside the reader
type Bit is Data:
  Bit{xs: List<&2, U32>, buf: U32, n: U32, v: U32}

# bitstream: leftover bytes, the current byte, how many low bits remain
type Br is Data:
  Br{xs: List<&2, U32>, buf: U32, n: U32}

# a field just read
type Acc is Data:
  Acc{br: Br, v: U32}

# 'MPEG-1 Layer III' is layer code 1 in the header
def hdr.layer(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> +b1 <> _b2 <> _b3 <> _rest:
      ((b1 >> 1n : U32) .&. 3 : U32)
    case _:
      0

# 1 when the ID bit selects MPEG-1
def hdr.mpeg1(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> +b1 <> _b2 <> _b3 <> _rest:
      ((b1 >> 3n : U32) .&. 1 : U32)
    case _:
      0

# bitrate index, 0 and 15 are not a frame
def hdr.index(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> _b1 <> +b2 <> _b3 <> _rest:
      (b2 >> 4n : U32)
    case _:
      0

# sampling-frequency index. 3 is reserved.
def hdr.sr(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> _b1 <> +b2 <> _b3 <> _rest:
      ((b2 >> 2n : U32) .&. 3 : U32)
    case _:
      3

# channel mode. 3 is mono.
def hdr.mode(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> _b1 <> _b2 <> +b3 <> _rest:
      (b3 >> 6n : U32)
    case _:
      0

# padding bit
def hdr.pad(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> _b1 <> +b2 <> _b3 <> _rest:
      ((b2 >> 1n : U32) .&. 1 : U32)
    case _:
      0

# protection bit 0 means a 16-bit CRC follows the header
def hdr.crc(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> +b1 <> _b2 <> _b3 <> _rest:
      U32.xor((b1 .&. 1 : U32), 1)
    case _:
      0

# 1 when the first two bytes carry the 11-bit sync 0xFFE
def hdr.sync(xs: List<&2, U32>) -> Bool:
  match xs:
    case 255 <> +b1 <> _b2 <> _b3 <> _rest:
      U32.is_eq((b1 .&. 224 : U32), 224)
    case _:
      False{}

def kbps.of(+ix: U32) -> U32:
  match ix:
    case 1:
      32
    case 2:
      40
    case 3:
      48
    case 4:
      56
    case 5:
      64
    case 6:
      80
    case 7:
      96
    case 8:
      112
    case 9:
      128
    case 10:
      160
    case 11:
      192
    case 12:
      224
    case 13:
      256
    case 14:
      320
    case _:
      0

# ISO/IEC 11172-3 MPEG-1 Layer III bitrate, kilobits per second
def hdr.kbps(xs: List<&2, U32>) -> U32:
  kbps.of(hdr.index(xs))

def hz.of(+ix: U32) -> U32:
  match ix:
    case 0:
      44100
    case 1:
      48000
    case 2:
      32000
    case _:
      0

# ISO/IEC 11172-3 sampling frequency, hertz
def hdr.hz(xs: List<&2, U32>) -> U32:
  hz.of(hdr.sr(xs))

# 1 or 2 channels. mode 3 is single channel.
def ch.of(+mode: U32) -> U32:
  match mode:
    case 3:
      1
    case _:
      2

def hdr.ch(xs: List<&2, U32>) -> U32:
  ch.of(hdr.mode(xs))

def l3.and(a: Bool, b: Bool) -> Bool:
  match a:
    case False{}:
      False{}
    case True{}:
      b

def l3.ok(+xs: List<&2, U32>) -> Bool:
  l3.and(
    hdr.sync(xs) && U32.is_eq(hdr.mpeg1(xs), 1) && U32.is_eq(hdr.layer(xs), 1),
    U32.is_ne(hdr.kbps(xs), 0) && U32.is_ne(hdr.hz(xs), 0))

# frame length in bytes: 1152 * kbps * 125 / hz, plus the pad bit
def frame.n(+kb: U32, +hz: U32, +pad: U32) -> U32:
  (U32.div(((1152 * kb : U32) * 125 : U32), hz) + pad : U32)

def frame.of(+xs: List<&2, U32>) -> U32:
  frame.n(hdr.kbps(xs), hdr.hz(xs), hdr.pad(xs))

def br.zero(xs: List<&2, U32>) -> Br:
  Br{xs, 0, 0}

def br.fill(xs: List<&2, U32>) -> Br:
  match xs:
    case Nil{}:
      Br{[], 0, 0}
    case +hd <> tl:
      Br{tl, hd, 8}

def br.norm(br: Br) -> Br:
  match br:
    case Br{xs, _buf, 0}:
      br.fill(xs)
    case Br{xs, buf, n}:
      Br{xs, buf, n}

def bit.at(z: Bool, xs: List<&2, U32>, +buf: U32, +n: U32) -> Bit:
  match z:
    case True{}:
      Bit{xs, buf, n, 0}
    case False{}:
      Bit{xs, buf, (n - 1 : U32), ((buf >> U32.to_nat((n - 1 : U32)) : U32) .&. 1 : U32)}

def br.one.at(br: Br) -> Bit:
  match br:
    case Br{xs, +buf, +n}:
      bit.at(U32.is_eq(n, 0), xs, buf, n)

def br.one(br: Br) -> Bit:
  br.one.at(br.norm(br))

def br.shift(b: Bit, +acc: U32) -> Acc:
  match b:
    case Bit{xs, buf, n, v}:
      Acc{Br{xs, buf, n}, ((acc << 1n : U32) .|. v : U32)}

def br.next(ac: Acc) -> Acc:
  match ac:
    case Acc{br, +v}:
      br.shift(br.one(br), v)

def br.get(hop: Nat, ac: Acc) -> Acc:
  match hop:
    case 0n:
      ac
    case 1n+p:
      br.get(p, br.next(ac))

def br.take(br: Br, +k: U32) -> Acc:
  br.get(U32.to_nat(k), Acc{br, 0})

def acc.br(ac: Acc) -> Br:
  match ac:
    case Acc{br, _v}:
      br

def acc.v(ac: Acc) -> U32:
  match ac:
    case Acc{_br, v}:
      v

# side-info length in bytes. MPEG-1 mono is 17, stereo is 32.
def side.n(+ch: U32) -> U32:
  match ch:
    case 1:
      17
    case _:
      32

def sr.row(+hz: U32) -> U32:
  match hz:
    case 48000:
      6
    case 32000:
      7
    case _:
      5

# encoder header at 320 kbit/s, original bit set, no CRC, no pad
def enc.b2(+hz: U32) -> U32:
  (224 .|. (sr.row(hz) .&. 0 : U32) : U32)

def enc.srbits(+hz: U32) -> U32:
  match hz:
    case 48000:
      4
    case 32000:
      8
    case _:
      0

def enc.b3(+ch: U32) -> U32:
  match ch:
    case 1:
      196
    case _:
      4

def enc.hdr(+hz: U32, +ch: U32) -> List<&2, U32>:
  [255, 251, (224 .|. enc.srbits(hz) : U32), enc.b3(ch)]

def enc.rate(+hz: U32) -> Bool:
  match hz:
    case 44100:
      True{}
    case 48000:
      True{}
    case 32000:
      True{}
    case _:
      False{}

def enc.ch(+ch: U32) -> Bool:
  match ch:
    case 1:
      True{}
    case 2:
      True{}
    case _:
      False{}

def kind.ok(+k: U32) -> Bool:
  match k:
    case 1:
      True{}
    case 3:
      True{}
    case _:
      False{}

def zeros.rest(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case 0 <> t:
      zeros.rest(t)
    case _ <> _t:
      False{}

# an empty sample list is not silence. Silence is one or more zero samples.
def frames.zero(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case 0 <> t:
      zeros.rest(t)
    case _ <> _t:
      False{}

def frames.empty(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case _ <> _t:
      False{}

def ls.cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

# one silent 320 kbit/s frame. big_values and part2_3_length are zero.
def silence.of(+hz: U32, +ch: U32) -> List<&2, U32>:
  ls.cat(enc.hdr(hz, ch), List.replicate(U32, U32.to_nat((frame.n(320, hz, 0) - 4 : U32)), 0))

def silence.ok(ok: Bool, +hz: U32, +ch: U32) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{silence.of(hz, ch)}

# non-zero PCM goes through the analysis filterbank, MDCT, and Huffman encoder.
def mp3.live(
  +hz: U32, +ch: U32, +kind: U32, frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  Enc.enc.run(hz, ch, kind, frames)

def mp3.nz(
  z: Bool, +hz: U32, +ch: U32, +kind: U32, frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match z:
    case True{}:
      silence.ok(True{}, hz, ch)
    case False{}:
      mp3.live(hz, ch, kind, frames)

def mp3.body(
  empty: Bool, +hz: U32, +ch: U32, +kind: U32, +frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match empty:
    case True{}:
      None{}
    case False{}:
      mp3.nz(frames.zero(frames), hz, ch, kind, frames)

def mp3.pick(
  ok: Bool, +hz: U32, +ch: U32, +kind: U32, +frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      mp3.body(frames.empty(frames), hz, ch, kind, frames)

# samples are interleaved U32 bits. kind 1 is s16, kind 3 is binary32.
def mp3.encode(
  +hz: U32, +ch: U32, +kind: U32, frames: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  mp3.pick(enc.rate(hz) && enc.ch(ch) && kind.ok(kind), hz, ch, kind, frames)

# a decoded frame: hertz, channels, interleaved binary32 words
type Pcm is Data:
  Pcm{hz: U32, ch: U32, pcm: List<&2, U32>}

# decoder state. phase 0 seeks a header, 1 collects a frame, 2 has failed.
type Wk is Data:
  Wk{
    hz: U32, ch: U32, pcm: List<&2, U32>, ov: List<&2, F32>, qmf: List<&2, F32>, fresh: U32,
    lib: Dec.Lib, on: U32, phase: U32, left: U32, buf: List<&2, U32>
  }

def le.pick(eq: Bool, +aa: U32, +bb: U32) -> Bool:
  match eq:
    case True{}:
      True{}
    case False{}:
      U32.is_lt(aa, bb)

def le.u(+aa: U32, +bb: U32) -> Bool:
  le.pick(U32.is_eq(aa, bb), aa, bb)

def frm.fit(+xs: List<&2, U32>, +nn: U32) -> Bool:
  le.u(nn, U32.from_nat(List.length(&2, U32, xs)))

def frm.take(+xs: List<&2, U32>, +nn: U32) -> List<&2, U32>:
  Dec.bd.take(U32.to_nat(nn), xs, [])

def frm.rest(+xs: List<&2, U32>, +nn: U32) -> List<&2, U32>:
  Dec.bd.drop(U32.to_nat(nn), xs)

def frm.and(aa: Bool, bb: Bool) -> Bool:
  match aa:
    case False{}:
      False{}
    case True{}:
      bb

# MPEG-1 Layer III, no CRC, not joint stereo
def frm.yes(+xs: List<&2, U32>) -> Bool:
  frm.and(l3.ok(xs), frm.and(U32.is_ne(hdr.mode(xs), 1), U32.is_eq(hdr.crc(xs), 0)))

def wk.make(+hz: U32, +ch: U32, lib: Dec.Lib) -> Wk:
  Wk{hz, ch, [], Dec.dec.ov(ch), Dec.dec.qmf(), 1, lib, 0, 0, 0, []}


def buf.add(xs: List<&2, U32>, +hd: U32) -> List<&2, U32>:
  List.append(&2, U32, xs, [hd])

def win.tail(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case _hd <> tl:
      tl
    case Nil{}:
      []

def wk.bad(st: Wk) -> Wk:
  match st:
    case Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, _phase, _left, _buf}:
      Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, 2, 0, []}

def wk.seek(st: Wk, buf: List<&2, U32>) -> Wk:
  match st:
    case Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, _phase, _left, _buf}:
      Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, 0, 0, buf}

def wk.read(st: Wk, +left: U32, buf: List<&2, U32>) -> Wk:
  match st:
    case Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, _phase, _left, _buf}:
      Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, 1, left, buf}

def wk.fail(+hz: U32, +ch: U32, pcm: List<&2, U32>) -> Wk:
  Wk{hz, ch, pcm, [], [], 0, Dec.lib.of(), 0, 2, 0, []}

def walk.keep(oo: Dec.Out, +hz: U32, +ch: U32, +pcm0: List<&2, U32>) -> Wk:
  match oo:
    case Dec.Out{pcm, ov, qmf, fresh, lib}:
      Wk{hz, ch, List.append(&2, U32, pcm0, pcm), ov, qmf, fresh, lib, 1, 0, 0, []}

def walk.apply(got: Maybe<&2, Dec.Out>, +hz: U32, +ch: U32, pcm0: List<&2, U32>) -> Wk:
  match got:
    case None{}:
      wk.fail(hz, ch, pcm0)
    case Some{oo}:
      walk.keep(oo, hz, ch, pcm0)

def wk.eq(eqh: Bool, eqc: Bool) -> Bool:
  match eqh:
    case False{}:
      False{}
    case True{}:
      eqc

def walk.fr2(
  ok: Bool, +buf: List<&2, U32>, +hz: U32, +ch: U32, pcm0: List<&2, U32>, ov: List<&2, F32>,
  qmf: List<&2, F32>, +fresh: U32, lib: Dec.Lib
) -> Wk:
  match ok:
    case False{}:
      wk.fail(hz, ch, pcm0)
    case True{}:
      walk.apply(Dec.dec.step(buf, ch, ov, qmf, fresh, lib), hz, ch, pcm0)

def walk.fr1(+buf: List<&2, U32>, +hz: U32, +ch: U32, lib: Dec.Lib) -> Wk:
  walk.apply(Dec.dec.step(buf, ch, Dec.dec.ov(ch), Dec.dec.qmf(), 1, lib), hz, ch, [])

def walk.fr0(
  cold: Bool, +buf: List<&2, U32>, +hz0: U32, +ch0: U32, pcm0: List<&2, U32>, ov: List<&2, F32>,
  qmf: List<&2, F32>, +fresh: U32, lib: Dec.Lib, +on: U32
) -> Wk:
  match cold:
    case True{}:
      walk.fr1(buf, hdr.hz(buf), hdr.ch(buf), Dec.lib.use(lib, hdr.hz(buf)))
    case False{}:
      walk.fr2(wk.eq(U32.is_eq(hdr.hz(buf), hz0), U32.is_eq(hdr.ch(buf), ch0)), buf, hz0, ch0, pcm0, ov,
        qmf, fresh, lib)

def walk.frame(
  +buf: List<&2, U32>, +hz: U32, +ch: U32, pcm: List<&2, U32>, ov: List<&2, F32>, qmf: List<&2, F32>,
  +fresh: U32, lib: Dec.Lib, +on: U32
) -> Wk:
  walk.fr0(U32.is_eq(on, 0), buf, hz, ch, pcm, ov, qmf, fresh, lib, on)

def walk.rd2(
  done: Bool, +hz: U32, +ch: U32, pcm: List<&2, U32>, ov: List<&2, F32>, qmf: List<&2, F32>,
  +fresh: U32, lib: Dec.Lib, +on: U32, +left: U32, buf: List<&2, U32>
) -> Wk:
  match done:
    case False{}:
      Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, 1, (left - 1 : U32), buf}
    case True{}:
      walk.frame(buf, hz, ch, pcm, ov, qmf, fresh, lib, on)

def walk.arm(big: Bool, st: Wk, +buf: List<&2, U32>) -> Wk:
  match big:
    case False{}:
      wk.bad(st)
    case True{}:
      wk.read(st, (frame.of(buf) - 4 : U32), buf)

def walk.good(ok: Bool, st: Wk, +buf: List<&2, U32>) -> Wk:
  match ok:
    case False{}:
      wk.bad(st)
    case True{}:
      walk.arm(le.u(5, frame.of(buf)), st, buf)

def walk.hdr(sync: Bool, st: Wk, +buf: List<&2, U32>) -> Wk:
  match sync:
    case False{}:
      wk.seek(st, win.tail(buf))
    case True{}:
      walk.good(frm.yes(buf), st, buf)

def walk.seen2(full: Bool, +buf: List<&2, U32>, st: Wk) -> Wk:
  match full:
    case False{}:
      st
    case True{}:
      walk.hdr(hdr.sync(buf), st, buf)

def walk.seen(full: Bool, st: Wk) -> Wk:
  match st:
    case Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, phase, left, +buf}:
      walk.seen2(full, buf, Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, phase, left, buf})

def walk.ph(
  +phase: U32, +hz: U32, +ch: U32, pcm: List<&2, U32>, ov: List<&2, F32>, qmf: List<&2, F32>,
  +fresh: U32, lib: Dec.Lib, +on: U32, +left: U32, +buf: List<&2, U32>, +hd: U32
) -> Wk:
  match phase:
    case 2:
      Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, 2, 0, []}
    case 1:
      walk.rd2(U32.is_eq(left, 1), hz, ch, pcm, ov, qmf, fresh, lib, on, left, buf.add(buf, hd))
    case _:
      walk.seen(U32.is_eq(U32.from_nat(List.length(&2, U32, buf.add(buf, hd))), 4),
        Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, 0, 0, buf.add(buf, hd)})

def walk.byte(st: Wk, +hd: U32) -> Wk:
  match st:
    case Wk{hz, ch, pcm, ov, qmf, fresh, lib, on, phase, left, buf}:
      walk.ph(phase, hz, ch, pcm, ov, qmf, fresh, lib, on, left, buf, hd)

def walk.done(ok: Bool, +hz: U32, +ch: U32, pcm: List<&2, U32>) -> Maybe<&2, Pcm>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Pcm{hz, ch, pcm}}

def walk.fin(seek: Bool, have: Bool, +hz: U32, +ch: U32, pcm: List<&2, U32>) -> Maybe<&2, Pcm>:
  match seek:
    case False{}:
      None{}
    case True{}:
      walk.done(have, hz, ch, pcm)

def walk.finish(st: Wk) -> Maybe<&2, Pcm>:
  match st:
    case Wk{+hz, +ch, pcm, _ov, _qmf, _fresh, _lib, on, phase, _left, _buf}:
      walk.fin(U32.is_eq(phase, 0), U32.is_eq(on, 1), hz, ch, pcm)

def walk.go(xs: List<&2, U32>, st: Wk) -> Maybe<&2, Pcm>:
  match xs:
    case Nil{}:
      walk.finish(st)
    case +hd <> tl:
      walk.go(tl, walk.byte(st, hd))

def wk.zero() -> Wk:
  Wk{0, 0, [], [], [], 1, Dec.lib.of(), 0, 0, 0, []}

# bytes in, PCM out. Layer I, Layer II, joint stereo, a CRC, and a bit reservoir are none.
def mp3.decode(xs: List<&2, U32>) -> Maybe<&2, Pcm>:
  walk.go(xs, wk.zero())
