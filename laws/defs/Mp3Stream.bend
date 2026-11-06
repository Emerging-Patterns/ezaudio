# an encoder's MPEG-1 Layer III stream, read frame by frame: which clips
# encode, how many frames, and each frame's header and length
import Base
import ../../src/mp3.bend as Mp3

# true when there is an encoding
def is.some(got: Maybe<&2, List<&2, U32>>) -> Bool:
  match got:
    case None{}:
      False{}
    case Some{_xs}:
      True{}

# a clip encodes when its rate is 32000, 44100 or 48000, it has one or two
# channels, and it has a sample
def mp3.ok(+hz: U32, +nch: U32, +pcm: List<&2, U32>) -> Bool:
  Bool.and(
    Bool.and(Bool.or(U32.is_eq(hz, 32000), Bool.or(U32.is_eq(hz, 44100), U32.is_eq(hz, 48000))),
      Bool.or(U32.is_eq(nch, 1), U32.is_eq(nch, 2))),
    Nat.is_ne(List.length(&2, U32, pcm), 0n))

# frames for a clip: whole frames of its samples / channels, plus two, so
# 1152 * frames covers the samples and the 1056 samples of encoder delay
def mp3.nframes(+nch: U32, +pcm: List<&2, U32>) -> U32:
  (U32.div(U32.div(U32.from_nat(List.length(&2, U32, pcm)), nch), 1152) + 2 : U32)

# the first four bytes, a frame header
def ls.take4(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case +b0 <> +b1 <> +b2 <> +b3 <> _rest:
      [b0, b1, b2, b3]
    case _:
      []

def ls.skip(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      match xs:
        case Nil{}:
          []
        case _hd <> tl:
          ls.skip(p, tl)

# a stream of one frame per pad bit: each starts with the encoder header for
# hz, ch and that pad bit, and is as long as that header says (ISO/IEC
# 11172-3 2.4.3.1: 144 * bitrate / hz bytes, plus the pad byte); no bytes follow
def walk(pads: List<&2, Bool>, +xs: List<&2, U32>, +hz: U32, +ch: U32) -> Type:
  match pads:
    case Nil{}:
      {xs == [] : List<&2, U32>}
    case pd <> tl:
      {ls.take4(xs) == Mp3.enc.hdr(hz, ch, Mp3.enc.pad(pd)) : List<&2, U32>}
        & walk(tl, ls.skip(U32.to_nat(Mp3.frame.of(xs)), xs), hz, ch)

# the stream encode_mp3 gives, or nothing
def bytes.of(got: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match got:
    case None{}:
      []
    case Some{xs}:
      xs

# a header as a decoder reads it: sync, layer code (1 is Layer III), the
# MPEG-1 bit, kbit/s, hertz, channels, CRC and pad bits
type Hf is Data:
  Hf{sync: Bool, layer: U32, mpeg1: U32, kbps: U32, hz: U32, ch: U32, crc: U32, pad: U32}

def hdr.fields(+xs: List<&2, U32>) -> Hf:
  Hf{Mp3.hdr.sync(xs), Mp3.hdr.layer(xs), Mp3.hdr.mpeg1(xs), Mp3.hdr.kbps(xs), Mp3.hdr.hz(xs), Mp3.hdr.ch(xs),
    Mp3.hdr.crc(xs), Mp3.hdr.pad(xs)}

def pads.count(xs: List<&2, Bool>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case True{} <> tl:
      1n+pads.count(tl)
    case False{} <> tl:
      pads.count(tl)

# the remainder after hop frames, as Mp3.enc.pads carries it
def slot.after(hop: Nat, +hz: U32, +slot: U32) -> U32:
  match hop:
    case 0n:
      slot
    case 1n+p:
      slot.after(p, hz, Mp3.enc.next(Mp3.enc.padb(hz, slot), hz, slot))

# padded frames and the remainder after them
type Cycle is Data:
  Cycle{pads: Nat, slot: U32}

def pads.cycle() -> Cycle:
  Cycle{pads.count(Mp3.enc.pads(49n, 44100, 0)), slot.after(49n, 44100, 0)}

def pads.want() -> Cycle:
  Cycle{44n, 0}

# header, side information and 2 * ch granules at the budget fit an unpadded frame
def room.ok(+hz: U32, +ch: U32) -> Bool:
  U32.is_le(
    ((((ch * 2 : U32) * Mp3.enc.bud(hz, ch) : U32) + 32 : U32) + (Mp3.side.n(ch) * 8 : U32) : U32),
    (Mp3.frame.n(320, hz, 0) * 8 : U32))

def room.all() -> Bool:
  Bool.and(Bool.and(Bool.and(room.ok(32000, 1), room.ok(32000, 2)), Bool.and(room.ok(44100, 1), room.ok(44100, 2))),
    Bool.and(room.ok(48000, 1), room.ok(48000, 2)))
