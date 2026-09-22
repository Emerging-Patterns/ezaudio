# ezaudio: a Clip is a sample rate, a channel count, a sample format, and
# interleaved PCM frames. WAV reads and writes RIFF PCM. MP3 reads and writes
# MPEG-1 Layer III.
import Base
import ./wav.bend as Wav
import ./mp3.bend as Mp3

# signed 16-bit PCM, or IEEE 754 binary32
type Format is Data:
  S16{}
  Flt{}

# one clip. pcm is interleaved. s16 lives in the low 16 bits.
type Clip is Data:
  Clip{hz: U32, nch: U32, fmt: Format, pcm: List<&2, U32>}

# signed 16-bit little-endian PCM
def s16() -> Format:
  S16{}

# IEEE 754 binary32, stored as its bits
def f32() -> Format:
  Flt{}

def kind.of(fmt: Format) -> U32:
  match fmt:
    case S16{}:
      1
    case Flt{}:
      3

def fmt.of(+kind: U32) -> Format:
  match kind:
    case 1:
      S16{}
    case _:
      Flt{}

def wav.clip(w: Wav.Wav) -> Clip:
  match w:
    case Wav.Wav{+rate, +channels, +kind, frames}:
      Clip{rate, channels, fmt.of(kind), frames}

def fmt.same(aa: Format, bb: Format) -> Bool:
  match aa bb:
    case S16{} S16{}:
      True{}
    case Flt{} Flt{}:
      True{}
    case S16{} Flt{}:
      False{}
    case Flt{} S16{}:
      False{}

# a clip from its rate, channel count, format, and interleaved frames
def clip(+rate: U32, +channels: U32, format: Format, frames: List<&2, U32>) -> Clip:
  Clip{rate, channels, format, frames}

# the sample rate, in hertz
def rate(c: Clip) -> U32:
  match c:
    case Clip{+hz, _nch, _fmt, _pcm}:
      hz

# how many channels are interleaved
def channels(c: Clip) -> U32:
  match c:
    case Clip{_hz, +nch, _fmt, _pcm}:
      nch

# s16 or f32
def format(c: Clip) -> Format:
  match c:
    case Clip{_hz, _nch, +fmt, _pcm}:
      fmt

# the interleaved frames
def frames(c: Clip) -> List<&2, U32>:
  match c:
    case Clip{_hz, _nch, _fmt, +pcm}:
      pcm

def count.of(+channels: U32, +nsamples: U32) -> U32:
  match channels:
    case 0:
      0
    case _:
      U32.div(nsamples, channels)

# how many frames. zero channels count as none.
def count(c: Clip) -> U32:
  match c:
    case Clip{_hz, +nch, _fmt, +pcm}:
      count.of(nch, U32.from_nat(List.length(&2, U32, pcm)))

# one sample, repeated across nframes frames
def fill(+rate: U32, +channels: U32, format: Format, +sample: U32, +nframes: U32) -> Clip:
  Clip{rate, channels, format, List.replicate(U32, U32.to_nat((nframes * channels : U32)), sample)}

def ls.drop(hop: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      xs
    case 1n+p:
      match xs:
        case Nil{}:
          []
        case _hd <> tl:
          ls.drop(p, tl)

def ls.take(hop: Nat, xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match hop:
    case 0n:
      List.reverse(&2, U32, acc)
    case 1n+p:
      match xs:
        case Nil{}:
          List.reverse(&2, U32, acc)
        case +hd <> tl:
          ls.take(p, tl, hd <> acc)

def ls.slice(xs: List<&2, U32>, +dropn: U32, +taken: U32) -> List<&2, U32>:
  ls.take(U32.to_nat(taken), ls.drop(U32.to_nat(dropn), xs), [])

def trim.go(
  ok: Bool,
  +rate: U32,
  +channels: U32,
  format: Format,
  frames: List<&2, U32>,
  +start: U32,
  +nframes: U32
) -> Maybe<&2, Clip>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Clip{rate, channels, format,
        ls.slice(frames, (start * channels : U32), (nframes * channels : U32))}}

# frames [start, start + nframes). none when that span passes the end.
def trim(c: Clip, +start: U32, +nframes: U32) -> Maybe<&2, Clip>:
  match c:
    case Clip{+hz, +nch, fmt, +pcm}:
      trim.go(U32.is_le((start + nframes : U32), count.of(nch, U32.from_nat(List.length(&2, U32, pcm)))), hz, nch,
        fmt, pcm, start, nframes)

def eq.all(ar: Bool, ac: Bool, af: Bool) -> Bool:
  match ar:
    case False{}:
      False{}
    case True{}:
      match ac:
        case False{}:
          False{}
        case True{}:
          af

def concat.go(
  ok: Bool,
  +rate: U32,
  +channels: U32,
  format: Format,
  left: List<&2, U32>,
  right: List<&2, U32>
) -> Maybe<&2, Clip>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Clip{rate, channels, format, List.append(&2, U32, left, right)}}

def concat.pair(+rate: U32, +channels: U32, +format: Format, left: List<&2, U32>, other: Clip) -> Maybe<&2, Clip>:
  match other:
    case Clip{+rb, +cb, fb, right}:
      concat.go(eq.all(U32.is_eq(rate, rb), U32.is_eq(channels, cb), fmt.same(format, fb)), rate, channels, format,
        left, right)

# the frames of both clips, or none when rate, channels, or format differ
def concat(left: Clip, right: Clip) -> Maybe<&2, Clip>:
  match left:
    case Clip{+hz, +nch, +fmt, pcm}:
      concat.pair(hz, nch, fmt, pcm, right)

def list.empty(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case _hd <> _tl:
      False{}

def wav.bytes(empty: Bool, +rate: U32, +channels: U32, +kind: U32, frames: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match empty:
    case True{}:
      None{}
    case False{}:
      Wav.wav.write(rate, channels, kind, frames)

def wav.parsed(got: Maybe<&2, Wav.Wav>) -> Maybe<&2, Clip>:
  match got:
    case None{}:
      None{}
    case Some{w}:
      Some{wav.clip(w)}

# a RIFF WAVE clip, or none when the bytes are not mono or stereo PCM or float
def decode_wav(xs: List<&2, U32>) -> Maybe<&2, Clip>:
  wav.parsed(Wav.wav.parse(xs))

# a RIFF WAVE file. none when there are no frames, or the rate or channels are unfit.
def encode_wav(c: Clip) -> Maybe<&2, List<&2, U32>>:
  match c:
    case Clip{+hz, +nch, fmt, +pcm}:
      wav.bytes(list.empty(pcm), hz, nch, kind.of(fmt), pcm)

def mp3.clip(p: Mp3.Pcm) -> Clip:
  match p:
    case Mp3.Pcm{+hz, +ch, pcm}:
      Clip{hz, ch, Flt{}, pcm}

def mp3.parsed(got: Maybe<&2, Mp3.Pcm>) -> Maybe<&2, Clip>:
  match got:
    case None{}:
      None{}
    case Some{p}:
      Some{mp3.clip(p)}

# MPEG-1 Layer III to f32 frames. Layer I, Layer II, joint stereo, and a CRC are none.
def decode_mp3(xs: List<&2, U32>) -> Maybe<&2, Clip>:
  mp3.parsed(Mp3.mp3.decode(xs))

# MPEG-1 Layer III at 320 kbit/s. rates are 32000, 44100, and 48000. none when unfit or empty.
def encode_mp3(c: Clip) -> Maybe<&2, List<&2, U32>>:
  match c:
    case Clip{+hz, +nch, fmt, pcm}:
      Mp3.mp3.encode(hz, nch, kind.of(fmt), pcm)
