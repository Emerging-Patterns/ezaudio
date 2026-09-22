# wave/ffmpeg vs ezaudio bench driver. EZA: "EZA1" + u32le hz/nch/fmt/nsamp + samples.
# Built as a native ELF via `bend bench/main.bend -o …` (CC=bend-cc or clang -O3).
import ../ezaudio/main.bend as Au

# unwrap a parsed U32, or zero when parse fails
def u32.arg.go(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{n}:
      n
    case None{}:
      0

# parse a decimal U32 from a string
def u32.arg(s: String) -> U32:
  u32.arg.go(U32.read(s))

# a mono s16 clip filled with one sample value
def solid.s16(+hz: U32, +nframes: U32, +sample: U32) -> Au.Clip:
  Au.fill(hz, 1, Au.s16(), sample, nframes)

# little-endian bytes of a U32
def u32.le(+n: U32) -> U32 & U32 & U32 & U32:
  ((n .&. 255 : U32), ((n >> 8n : U32) .&. 255 : U32), ((n >> 16n : U32) .&. 255 : U32),
    ((n >> 24n : U32) .&. 255 : U32))

# prepend four little-endian bytes of a word onto acc
def push.u32.go(b: U32 & U32 & U32 & U32, acc: List<&2, U32>) -> List<&2, U32>:
  (b0, b1, b2, b3) = b
  {b3 <> {b2 <> {b1 <> {b0 <> acc : List<&2, U32>} : List<&2, U32>} : List<&2, U32>} : List<&2, U32>}

# push one U32 as little-endian onto an accumulator
def push.u32(+n: U32, acc: List<&2, U32>) -> List<&2, U32>:
  push.u32.go(u32.le(n), acc)

# emit interleaved samples as little-endian U32 words
def emit.px(px: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match px:
    case Nil{}:
      acc
    case h <> t:
      emit.px(t, push.u32(h, acc))

# format tag: 1 for s16, 3 for f32
def fmt.tag(fmt: Au.Format) -> U32:
  Au.kind.of(fmt)

# EZA1 bytes for a clip
def emit.eza(+hz: U32, +nch: U32, +fmt: U32, +ns: U32, px: List<&2, U32>) -> List<&2, U32>:
  +magic = {49 <> {65 <> {90 <> {69 <> [] : List<&2, U32>} : List<&2, U32>} : List<&2, U32>} : List<&2, U32>}
  List.reverse(&2, U32, emit.px(px, push.u32(ns, push.u32(fmt, push.u32(nch, push.u32(hz, magic))))))

# serialize a Clip as EZA1
def clip.bytes(c: Au.Clip) -> List<&2, U32>:
  match c:
    case Au.Clip{+hz, +nch, fmt, +pcm}:
      emit.eza(hz, nch, fmt.tag(fmt), U32.from_nat(List.length(&2, U32, pcm)), pcm)

# rebuild a U32 from four little-endian bytes
def u32.of4(+a: U32, +b: U32, +c: U32, +d: U32) -> U32:
  (a .|. ((b << 8n : U32) .|. ((c << 16n : U32) .|. (d << 24n : U32) : U32) : U32) : U32)

# parse n little-endian U32 samples from a byte list
def parse.px(n: Nat, xs: List<&2, U32>, acc: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match n:
    case 0n:
      Some{List.reverse(&2, U32, acc)}
    case 1n+p:
      match xs:
        case a <> b <> c <> d <> rest:
          parse.px(p, rest, {u32.of4(a, b, c, d) <> acc : List<&2, U32>})
        case _other:
          None{}

# finish an EZA1 parse into a Clip
def parse.eza.px(+hz: U32, +nch: U32, +fmt: U32, m: Maybe<&2, List<&2, U32>>) -> Maybe<&2, Au.Clip>:
  match m:
    case None{}:
      None{}
    case Some{px}:
      Some{Au.clip(hz, nch, Au.fmt.of(fmt), px)}

# parse EZA1 bytes into a Clip
def parse.eza(xs: List<&2, U32>) -> Maybe<&2, Au.Clip>:
  match xs:
    case 69 <> 90 <> 65 <> 49 <> a <> b <> c <> d <> e <> f <> g <> h
      <> i <> j <> k <> l <> m <> n <> o <> p <> rest:
      +hz = u32.of4(a, b, c, d)
      +nch = u32.of4(e, f, g, h)
      +fmt = u32.of4(i, j, k, l)
      +ns = u32.of4(m, n, o, p)
      parse.eza.px(hz, nch, fmt, parse.px(U32.to_nat(ns), rest, []))
    case _other:
      None{}

# length of a byte list, accumulated in n
def ulen(xs: List<&2, U32>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case _h <> t:
      ulen(t, (n + 1 : U32))

# wrapping sum of (sample + 1), so a failed decode stays 0
def samp.sum(px: List<&2, U32>, +a: U32) -> U32:
  match px:
    case Nil{}:
      a
    case h <> t:
      samp.sum(t, ((a + h : U32) + 1 : U32))

# close the file once the write Result is Unit
def wrote.close(file: File, ok: Unit) -> IO(Unit):
  match ok:
    case Unit{}:
      File.close(file)

# force a write Result, then close the file
def wrote(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, result) = pair
  do IO<Unit>:
    ok : Unit <- IO.pass(Unit, result)
    wrote.close(file, ok)

# write a byte list to a path
def write.file(path: String, data: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    p : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, data)
    wrote(p)

# after reading bytes, close the file and return them
def took.after(xs: List<&2, U32>, closed: Unit) -> List<&2, U32>:
  match closed:
    case Unit{}:
      xs

# force a read Result, then close the file
def took.bytes(pair: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(List<&2, U32>):
  (file, result) = pair
  do IO<List<&2, U32>>:
    xs : List<&2, U32> <- IO.pass(List<&2, U32>, result)
    closed : Unit <- File.close(file)
    return took.after(xs, closed)

# read n bytes after learning the file size
def read.n(pair: File & Result<&1, &1, U32 & String, U32>) -> IO(List<&2, U32>):
  (file, result) = pair
  do IO<List<&2, U32>>:
    n : U32 <- IO.pass(U32, result)
    p : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, n)
    took.bytes(p)

# read a whole file as bytes
def read.file(path: String) -> IO(List<&2, U32>):
  do IO<List<&2, U32>>:
    f : File <- IO.try(File, File.open(path, "r"))
    p : File & Result<&1, &1, U32 & String, U32> <- File.size(f)
    read.n(p)

# die with a message
def die.msg(msg: String) -> IO(Unit):
  IO.die(Unit, 1, msg)

# write a decoded Clip as EZA1, or die
def write.maybe(path: String, m: Maybe<&2, Au.Clip>) -> IO(Unit):
  match m:
    case None{}:
      die.msg("decode failed")
    case Some{c}:
      write.file(path, clip.bytes(c))

# write encoded bytes, or die
def write.enc(path: String, m: Maybe<&2, List<&2, U32>>) -> IO(Unit):
  match m:
    case None{}:
      die.msg("encode failed")
    case Some{xs}:
      write.file(path, xs)

# unwrap a parsed EZA1 Clip, or die
def load.eza.go(m: Maybe<&2, Au.Clip>) -> IO(Au.Clip):
  match m:
    case None{}:
      IO.die(Au.Clip, 1, "bad eza")
    case Some{c}:
      IO.pure(Au.Clip, c)

# load an EZA1 file as a Clip
def load.eza(path: String) -> IO(Au.Clip):
  do IO<Au.Clip>:
    xs : List<&2, U32> <- read.file(path)
    load.eza.go(parse.eza(xs))

# decode a WAV file to EZA1
def cmd.wav.dec(src: String, dst: String) -> IO(Unit):
  do IO<Unit>:
    xs : List<&2, U32> <- read.file(src)
    write.maybe(dst, Au.decode_wav(xs))

# encode an EZA1 file to WAV
def cmd.wav.enc(src: String, dst: String) -> IO(Unit):
  do IO<Unit>:
    c : Au.Clip <- load.eza(src)
    write.enc(dst, Au.encode_wav(c))

# encode then decode a WAV round-trip into EZA1
def cmd.wav.rt.go(dst: String, m: Maybe<&2, List<&2, U32>>) -> IO(Unit):
  match m:
    case None{}:
      die.msg("encode_wav failed")
    case Some{xs}:
      write.maybe(dst, Au.decode_wav(xs))

# WAV round-trip from EZA1 to EZA1
def cmd.wav.rt(src: String, dst: String) -> IO(Unit):
  do IO<Unit>:
    c : Au.Clip <- load.eza(src)
    cmd.wav.rt.go(dst, Au.encode_wav(c))

# decode an MP3 file to EZA1
def cmd.mp3.dec(src: String, dst: String) -> IO(Unit):
  do IO<Unit>:
    xs : List<&2, U32> <- read.file(src)
    write.maybe(dst, Au.decode_mp3(xs))

# encode an EZA1 file to MP3
def cmd.mp3.enc(src: String, dst: String) -> IO(Unit):
  do IO<Unit>:
    c : Au.Clip <- load.eza(src)
    write.enc(dst, Au.encode_mp3(c))

# encode then decode an MP3 round-trip into EZA1
def cmd.mp3.rt.go(dst: String, m: Maybe<&2, List<&2, U32>>) -> IO(Unit):
  match m:
    case None{}:
      die.msg("encode_mp3 failed")
    case Some{xs}:
      write.maybe(dst, Au.decode_mp3(xs))

# MP3 round-trip from EZA1 to EZA1
def cmd.mp3.rt(src: String, dst: String) -> IO(Unit):
  do IO<Unit>:
    c : Au.Clip <- load.eza(src)
    cmd.mp3.rt.go(dst, Au.encode_mp3(c))

# fold encode_wav length into a checksum
def step.wav.enc(+sum: U32, m: Maybe<&2, List<&2, U32>>) -> U32:
  match m:
    case None{}:
      sum
    case Some{xs}:
      (sum + ulen(xs, 0) : U32)

# repeat encode_wav n times
def loop.wav.enc(+c: Au.Clip, n: Nat, +sum: U32) -> U32:
  match n:
    case 0n:
      sum
    case 1n+p:
      loop.wav.enc(c, p, step.wav.enc(sum, Au.encode_wav(c)))

# fold a decoded clip's samples into a checksum
def step.clip(+sum: U32, m: Maybe<&2, Au.Clip>) -> U32:
  match m:
    case None{}:
      sum
    case Some{c}:
      (sum + samp.sum(Au.frames(c), 0) : U32)

# repeat decode_wav n times
def loop.wav.dec(+xs: List<&2, U32>, n: Nat, +sum: U32) -> U32:
  match n:
    case 0n:
      sum
    case 1n+p:
      loop.wav.dec(xs, p, step.clip(sum, Au.decode_wav(xs)))

# fold encode_mp3 length into a checksum
def step.mp3.enc(+sum: U32, m: Maybe<&2, List<&2, U32>>) -> U32:
  match m:
    case None{}:
      sum
    case Some{xs}:
      (sum + ulen(xs, 0) : U32)

# repeat encode_mp3 n times
def loop.mp3.enc(+c: Au.Clip, n: Nat, +sum: U32) -> U32:
  match n:
    case 0n:
      sum
    case 1n+p:
      loop.mp3.enc(c, p, step.mp3.enc(sum, Au.encode_mp3(c)))

# repeat decode_mp3 n times
def loop.mp3.dec(+xs: List<&2, U32>, n: Nat, +sum: U32) -> U32:
  match n:
    case 0n:
      sum
    case 1n+p:
      loop.mp3.dec(xs, p, step.clip(sum, Au.decode_mp3(xs)))

# format a timing line for the harness
def show.ms(t0: Nat, t1: Nat, +sum: U32, +hz: U32, +nframes: U32, +n: U32) -> String:
  "MS " ++ Nat.show(Nat.sub(t1, t0)) ++ " SUM " ++ U32.show(sum) ++ " HZ " ++ U32.show(hz)
    ++ " FR " ++ U32.show(nframes) ++ " N " ++ U32.show(n)

# timed solid s16 WAV encode bench
def bench.wav.enc(+hz: U32, +nframes: U32, +n: U32) -> IO(Unit):
  +c = solid.s16(hz, nframes, 0)
  +k = U32.to_nat(n)
  do IO<Unit>:
    t0 : Nat <- IO.now()
    sum : U32 = loop.wav.enc(c, k, 0)
    t1 : Nat <- IO.now()
    IO.print(show.ms(t0, t1, sum, hz, nframes, n))

# timed solid s16 MP3 encode bench
def bench.mp3.enc(+hz: U32, +nframes: U32, +n: U32) -> IO(Unit):
  +c = solid.s16(hz, nframes, 0)
  +k = U32.to_nat(n)
  do IO<Unit>:
    t0 : Nat <- IO.now()
    sum : U32 = loop.mp3.enc(c, k, 0)
    t1 : Nat <- IO.now()
    IO.print(show.ms(t0, t1, sum, hz, nframes, n))

# timed WAV decode bench from a file
def bench.wav.dec(path: String, +n: U32) -> IO(Unit):
  +k = U32.to_nat(n)
  do IO<Unit>:
    xs : List<&2, U32> <- read.file(path)
    t0 : Nat <- IO.now()
    sum : U32 = loop.wav.dec(xs, k, 0)
    t1 : Nat <- IO.now()
    IO.print(show.ms(t0, t1, sum, 0, 0, n))

# timed MP3 decode bench from a file
def bench.mp3.dec(path: String, +n: U32) -> IO(Unit):
  +k = U32.to_nat(n)
  do IO<Unit>:
    xs : List<&2, U32> <- read.file(path)
    t0 : Nat <- IO.now()
    sum : U32 = loop.mp3.dec(xs, k, 0)
    t1 : Nat <- IO.now()
    IO.print(show.ms(t0, t1, sum, 0, 0, n))

# fallthrough for unknown commands
def run.m.at(z: Bool, +cmd: String, _a: String, _b: String, _c: String) -> IO(Unit):
  match z:
    case True{}:
      IO.print("pong")
    case False{}:
      die.msg("unknown command " ++ cmd)

# dispatch the ping command
def run.m(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.m.at(String.eq(cmd, "ping"), cmd, a, b, c)

# dispatch bench-mp3-dec
def run.l.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      bench.mp3.dec(a, u32.arg(b))
    case False{}:
      run.m(cmd, a, b, c)

# try bench-mp3-dec then fall through
def run.l(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.l.at(String.eq(cmd, "bench-mp3-dec"), cmd, a, b, c)

# dispatch bench-wav-dec
def run.k.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      bench.wav.dec(a, u32.arg(b))
    case False{}:
      run.l(cmd, a, b, c)

# try bench-wav-dec then fall through
def run.k(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.k.at(String.eq(cmd, "bench-wav-dec"), cmd, a, b, c)

# dispatch bench-mp3-enc
def run.j.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      bench.mp3.enc(u32.arg(a), u32.arg(b), u32.arg(c))
    case False{}:
      run.k(cmd, a, b, c)

# try bench-mp3-enc then fall through
def run.j(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.j.at(String.eq(cmd, "bench-mp3-enc"), cmd, a, b, c)

# dispatch bench-wav-enc
def run.i.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      bench.wav.enc(u32.arg(a), u32.arg(b), u32.arg(c))
    case False{}:
      run.j(cmd, a, b, c)

# try bench-wav-enc then fall through
def run.i(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.i.at(String.eq(cmd, "bench-wav-enc"), cmd, a, b, c)

# dispatch mp3-rt
def run.h.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      cmd.mp3.rt(a, b)
    case False{}:
      run.i(cmd, a, b, c)

# try mp3-rt then fall through
def run.h(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.h.at(String.eq(cmd, "mp3-rt"), cmd, a, b, c)

# dispatch mp3-enc
def run.g.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      cmd.mp3.enc(a, b)
    case False{}:
      run.h(cmd, a, b, c)

# try mp3-enc then fall through
def run.g(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.g.at(String.eq(cmd, "mp3-enc"), cmd, a, b, c)

# dispatch mp3-dec
def run.f.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      cmd.mp3.dec(a, b)
    case False{}:
      run.g(cmd, a, b, c)

# try mp3-dec then fall through
def run.f(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.f.at(String.eq(cmd, "mp3-dec"), cmd, a, b, c)

# dispatch wav-rt
def run.e.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      cmd.wav.rt(a, b)
    case False{}:
      run.f(cmd, a, b, c)

# try wav-rt then fall through
def run.e(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.e.at(String.eq(cmd, "wav-rt"), cmd, a, b, c)

# dispatch wav-enc
def run.d.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      cmd.wav.enc(a, b)
    case False{}:
      run.e(cmd, a, b, c)

# try wav-enc then fall through
def run.d(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.d.at(String.eq(cmd, "wav-enc"), cmd, a, b, c)

# dispatch wav-dec
def run.named.at(z: Bool, +cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  match z:
    case True{}:
      cmd.wav.dec(a, b)
    case False{}:
      run.d(cmd, a, b, c)

# try wav-dec then fall through
def run.named(+cmd: String, +a: String, +b: String, +c: String) -> IO(Unit):
  run.named.at(String.eq(cmd, "wav-dec"), cmd, a, b, c)

# the first four argv strings, empty when missing
def args4(xs: List<String>) -> String & String & String & String:
  match xs:
    case a <> b <> c <> d <> _t:
      (a, b, c, d)
    case a <> b <> c <> Nil{}:
      (a, b, c, "")
    case a <> b <> Nil{}:
      (a, b, "", "")
    case a <> Nil{}:
      (a, "", "", "")
    case Nil{}:
      ("", "", "", "")

# unpack argv and run the named command
def main.go(quad: String & String & String & String) -> IO(Unit):
  (a, b, c, d) = quad
  run.named(a, b, c, d)

# CLI entry: dispatch by the first argv word
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    main.go(args4(args))
