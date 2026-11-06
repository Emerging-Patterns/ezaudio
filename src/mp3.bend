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

# encoder header: MPEG-1 Layer III at 320 kbit/s, no CRC, original bit set, pad 0 or 1
def enc.hdr(+hz: U32, +ch: U32, +pad: U32) -> List<&2, U32>:
  [255, 251, ((224 .|. enc.srbits(hz) : U32) .|. (pad << 1n : U32) : U32), enc.b3(ch)]

# the encoder's rates are 32000, 44100 and 48000
def enc.rate(+hz: U32) -> Bool:
  Bool.or(U32.is_eq(hz, 32000), Bool.or(U32.is_eq(hz, 44100), U32.is_eq(hz, 48000)))

# mono or stereo
def enc.ch(+ch: U32) -> Bool:
  Bool.or(U32.is_eq(ch, 1), U32.is_eq(ch, 2))

def enc.fit(+hz: U32, +ch: U32) -> Bool:
  Bool.and(enc.rate(hz), enc.ch(ch))

def ls.cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

# exactly hop bytes: the list, then zeros
def ls.fix(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      []
    case 1n+p:
      match xs:
        case Nil{}:
          0 <> ls.fix(p, [])
        case +hd <> tl:
          hd <> ls.fix(p, tl)

# a frame is 1152 * 320000 / 8 / hz bytes; this is the remainder of that division, times hz
def enc.rem(+hz: U32) -> U32:
  (46080000 - (U32.div(46080000, hz) * hz : U32) : U32)

# a frame pads once the remainders since the last padded frame make a whole byte
def enc.padb(+hz: U32, +slot: U32) -> Bool:
  U32.is_le(hz, (slot + enc.rem(hz) : U32))

def enc.next(pad: Bool, +hz: U32, +slot: U32) -> U32:
  match pad:
    case True{}:
      ((slot + enc.rem(hz) : U32) - hz : U32)
    case False{}:
      (slot + enc.rem(hz) : U32)

# the pad bit of each of hop frames, starting from a slot remainder
def enc.pads(hop: Nat, +hz: U32, +slot: U32) -> List<&2, Bool>:
  match hop:
    case 0n:
      []
    case 1n+p:
      enc.padb(hz, slot) <> enc.pads(p, hz, enc.next(enc.padb(hz, slot), hz, slot))

def enc.pad(pad: Bool) -> U32:
  match pad:
    case True{}:
      1
    case False{}:
      0

# a frame: the header, side information and main data, as many bytes as the header says
def enc.frame(+hz: U32, +ch: U32, +pad: U32, gs: List<&2, Enc.Gr>) -> List<&2, U32>:
  ls.fix(U32.to_nat(frame.n(320, hz, pad)), ls.cat(enc.hdr(hz, ch, pad), Enc.fr.data(gs, ch)))

# one frame per pad bit, each taking two granules per channel
def fr.go(pads: List<&2, Bool>, +gs: List<&2, Enc.Gr>, +hz: U32, +ch: U32) -> List<&2, U32>:
  match pads:
    case Nil{}:
      []
    case pd <> tl:
      ls.cat(enc.frame(hz, ch, enc.pad(pd), Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
        fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), hz, ch))

# frames for samples / channels per-channel samples: whole frames, a granule of MDCT delay
# and the filterbank's, so 1152 * frames is at least samples + 1056
def enc.nf(+ch: U32, +pcm: List<&2, U32>) -> U32:
  (U32.div(U32.div(U32.from_nat(List.length(&2, U32, pcm)), ch), 1152) + 2 : U32)

def side.bits(+ch: U32) -> U32:
  match ch:
    case 1:
      136
    case _:
      256

def bud.cap(fit: Bool, +nn: U32) -> U32:
  match fit:
    case True{}:
      nn
    case False{}:
      4095

def enc.room(+hz: U32, +ch: U32) -> U32:
  (U32.div((((frame.n(320, hz, 0) * 8 : U32) - 32 : U32) - side.bits(ch) : U32), (ch * 2 : U32)) - 8 : U32)

# bits per granule and channel: an unpadded frame less header and side information, shared
# by the granules, less 8; at most 4095, the largest 12-bit part2_3_length
def enc.bud(+hz: U32, +ch: U32) -> U32:
  bud.cap(U32.is_le(enc.room(hz, ch), 4095), enc.room(hz, ch))

def enc.out(+nf: U32, +hz: U32, +ch: U32, +kind: U32, +pcm: List<&2, U32>) -> List<&2, U32>:
  fr.go(enc.pads(U32.to_nat(nf), hz, 0), Enc.enc.grans(hz, ch, kind, pcm, nf, enc.bud(hz, ch)), hz, ch)

# every input sample is in a frame: nf frames, the first padded from slot 0
def enc.bytes(+hz: U32, +ch: U32, +kind: U32, +pcm: List<&2, U32>) -> List<&2, U32>:
  enc.out(enc.nf(ch, pcm), hz, ch, kind, pcm)

def mp3.body(+hz: U32, +ch: U32, +kind: U32, pcm: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match pcm:
    case Nil{}:
      None{}
    case +hd <> tl:
      Some{enc.bytes(hz, ch, kind, hd <> tl)}

def mp3.pick(
  ok: Bool,
  +hz: U32,
  +ch: U32,
  +kind: U32,
  pcm: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      mp3.body(hz, ch, kind, pcm)

# samples are interleaved U32 bits. kind 1 is s16, any other binary32.
def mp3.encode(
  +hz: U32,
  +ch: U32,
  +kind: U32,
  pcm: List<&2, U32>
) -> Maybe<&2, List<&2, U32>>:
  mp3.pick(enc.fit(hz, ch), hz, ch, kind, pcm)


# a decoded stream: hertz, channels, interleaved binary32 words
type Pcm is Data:
  Pcm{hz: U32, ch: U32, pcm: List<&2, U32>}

# the first n bytes, the rest, and whether the bytes ran out first
type Cut is Data:
  Cut{got: List<&2, U32>, rest: List<&2, U32>, short: Bool}

def cut.go(hop: Nat, xs: List<&2, U32>, acc: List<&2, U32>) -> Cut:
  match hop xs:
    case 0n ys:
      Cut{List.reverse(&2, U32, acc), ys, False{}}
    case _ Nil{}:
      Cut{List.reverse(&2, U32, acc), [], True{}}
    case 1n+p +hd <> tl:
      cut.go(p, tl, hd <> acc)

# "Xing" or "Info", a LAME/Xing header frame
def xing.tag(xs: List<&2, U32>) -> Bool:
  match xs:
    case 88 <> 105 <> 110 <> 103 <> _rest:
      True{}
    case 73 <> 110 <> 102 <> 111 <> _rest:
      True{}
    case _:
      False{}

# the tag sits where the main data would start, after the header, CRC and side info
def xing.is(+fr: List<&2, U32>) -> Bool:
  xing.tag(Dec.bd.drop(U32.to_nat(((4 + (2 * hdr.crc(fr) : U32) : U32) + side.n(hdr.ch(fr)) : U32)), fr))

# the frame walk: done with the frames found, newest first, or the bytes left, whether no
# frame has been kept yet, and the frames so far
type Fq is Data:
  FqEnd{acc: List<&2, List<&2, U32>>}
  FqGo{xs: List<&2, U32>, first: Bool, acc: List<&2, List<&2, U32>>}

def fq.keep(info: Bool, got: List<&2, U32>, rest: List<&2, U32>, acc: List<&2, List<&2, U32>>) -> Fq:
  match info:
    case True{}:
      FqGo{rest, False{}, acc}
    case False{}:
      FqGo{rest, False{}, got <> acc}

# a Xing or Info frame is skipped when it comes first
def fq.first(first: Bool, +got: List<&2, U32>, rest: List<&2, U32>, acc: List<&2, List<&2, U32>>) -> Fq:
  match first:
    case True{}:
      fq.keep(xing.is(got), got, rest, acc)
    case False{}:
      fq.keep(False{}, got, rest, acc)

# a frame the bytes end inside is dropped, as minimp3 and dr_mp3 drop it
def fq.cut(cc: Cut, first: Bool, acc: List<&2, List<&2, U32>>) -> Fq:
  match cc:
    case Cut{got, rest, short}:
      match short:
        case True{}:
          FqEnd{acc}
        case False{}:
          fq.first(first, got, rest, acc)

# a byte that does not start an MPEG-1 Layer III header is junk: step over it
def fq.tail(xs: List<&2, U32>, first: Bool, acc: List<&2, List<&2, U32>>) -> Fq:
  match xs:
    case Nil{}:
      FqEnd{acc}
    case _hd <> tl:
      FqGo{tl, first, acc}

def fq.at(ok: Bool, +xs: List<&2, U32>, first: Bool, acc: List<&2, List<&2, U32>>) -> Fq:
  match ok:
    case True{}:
      fq.cut(cut.go(U32.to_nat(frame.of(xs)), xs, []), first, acc)
    case False{}:
      fq.tail(xs, first, acc)

def fq.done(st: Fq) -> List<&2, List<&2, U32>>:
  match st:
    case FqEnd{acc}:
      List.reverse(&2, List<&2, U32>, acc)
    case FqGo{_xs, _first, acc}:
      List.reverse(&2, List<&2, U32>, acc)

# every step takes at least one byte, so one more step than there are bytes finishes
def fq.walk(fuel: Nat, st: Fq) -> List<&2, List<&2, U32>>:
  match fuel:
    case 0n:
      fq.done(st)
    case 1n+p:
      match st:
        case FqEnd{acc}:
          List.reverse(&2, List<&2, U32>, acc)
        case FqGo{+xs, first, acc}:
          fq.walk(p, fq.at(l3.ok(xs), xs, first, acc))

# ID3v2 size: four syncsafe bytes, 7 bits each
def id3.size(+s0: U32, +s1: U32, +s2: U32, +s3: U32) -> U32:
  ((((s0 << 21n : U32) .|. (s1 << 14n : U32) : U32) .|. (s2 << 7n : U32) : U32) .|. s3 : U32)

def id3.ok(+v0: U32, +s0: U32, +s1: U32, +s2: U32, +s3: U32) -> Bool:
  U32.is_ne(v0, 255) && U32.is_lt(s0, 128) && U32.is_lt(s1, 128) && U32.is_lt(s2, 128) && U32.is_lt(s3, 128)

# flag bit 4: a 10-byte footer follows the tag
def id3.foot(on: Bool) -> U32:
  match on:
    case True{}:
      10
    case False{}:
      0

def id3.cut(ok: Bool, +size: U32, rest: List<&2, U32>, whole: List<&2, U32>) -> List<&2, U32>:
  match ok:
    case True{}:
      Dec.bd.drop(U32.to_nat(size), rest)
    case False{}:
      whole

def id3.at(xs: List<&2, U32>, whole: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case 73 <> 68 <> 51 <> +v0 <> _v1 <> +fl <> +s0 <> +s1 <> +s2 <> +s3 <> rest:
      id3.cut(id3.ok(v0, s0, s1, s2, s3),
        (id3.size(s0, s1, s2, s3) + id3.foot(U32.is_ne((fl .&. 16 : U32), 0)) : U32), rest, whole)
    case _:
      whole

# a leading ID3v2 tag ("ID3", version, flags, syncsafe size) is skipped by its size
def id3.skip(+xs: List<&2, U32>) -> List<&2, U32>:
  id3.at(xs, xs)

def fq.start(+xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  fq.walk(1n+List.length(&2, U32, xs), FqGo{xs, True{}, []})

# the whole frames of a stream, each starting with its header: a leading ID3v2 tag is
# skipped by its size, bytes that are not an MPEG-1 Layer III header are stepped over, a
# Xing or Info frame is skipped when it is the first frame, and a frame the bytes end
# inside is dropped
def mp3.frames(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  fq.start(id3.skip(xs))

# mode extension: in joint stereo, bit 1 is mid/side and bit 0 is intensity stereo
def hdr.ext(xs: List<&2, U32>) -> U32:
  match xs:
    case _b0 <> _b1 <> _b2 <> +b3 <> _rest:
      ((b3 >> 4n : U32) .&. 3 : U32)
    case _:
      0

def mode.ok(+mode: U32, +ext: U32) -> Bool:
  match mode:
    case 1:
      U32.is_eq(ext, 0)
    case _:
      True{}

# the stream's rate and channels hold, and joint stereo uses neither mid/side nor intensity
def play.ok(+fr: List<&2, U32>, +hz: U32, +ch: U32) -> Bool:
  U32.is_eq(hdr.hz(fr), hz) && U32.is_eq(hdr.ch(fr), ch) && mode.ok(hdr.mode(fr), hdr.ext(fr))

def play.frame(+fr: List<&2, U32>, +st: Dec.St) -> Maybe<&2, Dec.St>:
  match st:
    case Dec.St{+hz, +ch, ov, qmf, fresh, lib, acc}:
      Dec.dec.frame(play.ok(fr, hz, ch), fr, hdr.crc(fr), Dec.St{hz, ch, ov, qmf, fresh, lib, acc})

def play.step(+fr: List<&2, U32>, got: Maybe<&2, Dec.St>) -> Maybe<&2, Dec.St>:
  match got:
    case None{}:
      None{}
    case Some{st}:
      play.frame(fr, st)

def play.go(fs: List<&2, List<&2, U32>>, got: Maybe<&2, Dec.St>) -> Maybe<&2, Dec.St>:
  match fs:
    case Nil{}:
      got
    case +hd <> tl:
      play.go(tl, play.step(hd, got))

def play.end(got: Maybe<&2, Dec.St>) -> Maybe<&2, Pcm>:
  match got:
    case None{}:
      None{}
    case Some{st}:
      match st:
        case Dec.St{hz, ch, _ov, _qmf, _fresh, _lib, acc}:
          Some{Pcm{hz, ch, List.reverse(&2, U32, acc)}}

# decode frames in order. The first frame sets the rate and channels; no frames is none.
def mp3.play(fs: List<&2, List<&2, U32>>) -> Maybe<&2, Pcm>:
  match fs:
    case Nil{}:
      None{}
    case +hd <> tl:
      play.end(play.go(hd <> tl, Some{Dec.st.fresh(hdr.hz(hd), hdr.ch(hd))}))

# the quantized lines and global_gain of each granule channel of one frame, in bitstream
# order, before requantization
def mp3.lines(+fr: List<&2, U32>) -> Maybe<&2, List<&2, Dec.Gl>>:
  Dec.dec.gls(fr, hdr.ch(fr), hdr.crc(fr), Dec.lib.of(hdr.hz(fr)))

# bytes in, PCM out: the frames mp3.frames finds, decoded. none when a frame holds what the
# decoder does not read (see Dec.dec.gls), uses mid/side or intensity stereo, or changes
# the rate or channels, and when there is no frame at all.
def mp3.decode(xs: List<&2, U32>) -> Maybe<&2, Pcm>:
  mp3.play(mp3.frames(xs))
