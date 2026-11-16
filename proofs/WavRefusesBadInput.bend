# proofs of laws/WavRefusesBadInput.bend
import Base
import ../main.bend as Au
import ../src/wav.bend as Wav
import ../laws/WavRefusesBadInput.bend as Laws
import ./lemmas/NatAndLists.bend as M1

# the RIFF check fails, so the file does not open, whatever follows
def open.no(
  +a: U32,
  +b: U32,
  +c: U32,
  +d: U32,
  +rest: List<&2, U32>,
  h_riff: {U32.is_eq(Wav.be.u32(a, b, c, d), 1380533830) == False{} : Bool}
) -> {Au.decode_wav(a <> b <> c <> d <> rest) == None{} : Maybe<&2, Au.Clip>}:
  match rest:
    case +s0 <> +s1 <> +s2 <> +s3 <> +w0 <> +w1 <> +w2 <> +w3 <> +tl:
      Equal.cong(Bool, Maybe<&2, Au.Clip>,
        ok => Au.wav.parsed(Wav.open.ok(Bool.and(ok, U32.is_eq(Wav.be.u32(w0, w1, w2, w3), Wav.tag.wave())), tl)),
        U32.is_eq(Wav.be.u32(a, b, c, d), 1380533830), False{}, h_riff)
    case Nil{}:
      {==}
    case _s0 <> Nil{}:
      {==}
    case _s0 <> _s1 <> Nil{}:
      {==}
    case _s0 <> _s1 <> _s2 <> Nil{}:
      {==}
    case _s0 <> _s1 <> _s2 <> _s3 <> Nil{}:
      {==}
    case _s0 <> _s1 <> _s2 <> _s3 <> _w0 <> Nil{}:
      {==}
    case _s0 <> _s1 <> _s2 <> _s3 <> _w0 <> _w1 <> Nil{}:
      {==}
    case _s0 <> _s1 <> _s2 <> _s3 <> _w0 <> _w1 <> _w2 <> Nil{}:
      {==}

def Laws.wav_bad(a, b, c, d, rest, h_riff):
  open.no(a, b, c, d, rest, h_riff)

def Laws.wav_part_frame(hz, nch, fmt, pcm, h_part):
  Equal.cong(Bool, Maybe<&2, List<&2, U32>>, ok => Au.wav.bytes(ok, hz, nch, Au.kind.of(fmt), pcm),
    Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n), False{}, h_part)

# a write any of whose three checks fails is none
def if.none(
  aa: Bool,
  bb: Bool,
  cc: Bool,
  +rate: U32,
  +ch: U32,
  +kind: U32,
  +ns: U32,
  frames: List<&2, U32>,
  h_no: {Bool.and(Bool.and(aa, bb), cc) == False{} : Bool}
) -> {Wav.write.if(Bool.and(Bool.and(aa, bb), cc), rate, ch, kind, ns, frames) == None{} : Maybe<&2, List<&2, U32>>}:
  Equal.cong(Bool, Maybe<&2, List<&2, U32>>, ok => Wav.write.if(ok, rate, ch, kind, ns, frames),
    Bool.and(Bool.and(aa, bb), cc), False{}, h_no)

# a clip whose writer refuses it is none, whole frames or not
def bytes.none(
  whole: Bool,
  +rate: U32,
  +ch: U32,
  +kind: U32,
  +frames: List<&2, U32>,
  h_no: {Wav.wav.write(rate, ch, kind, frames) == None{} : Maybe<&2, List<&2, U32>>}
) -> {Au.wav.bytes(whole, rate, ch, kind, frames) == None{} : Maybe<&2, List<&2, U32>>}:
  match whole:
    case False{}:
      {==}
    case True{}:
      h_no

# the first check false
def and.first(
  aa: Bool,
  bb: Bool,
  cc: Bool,
  hh: {aa == False{} : Bool}
) -> {Bool.and(Bool.and(aa, bb), cc) == False{} : Bool}:
  Equal.cong(Bool, Bool, xx => Bool.and(Bool.and(xx, bb), cc), aa, False{}, hh)

# the second check false
def and.second(
  aa: Bool,
  bb: Bool,
  cc: Bool,
  hh: {bb == False{} : Bool}
) -> {Bool.and(Bool.and(aa, bb), cc) == False{} : Bool}:
  match aa:
    case False{}:
      {==}
    case True{}:
      Equal.cong(Bool, Bool, xx => Bool.and(xx, cc), bb, False{}, hh)

# the third check false
def and.third(
  aa: Bool,
  bb: Bool,
  cc: Bool,
  hh: {cc == False{} : Bool}
) -> {Bool.and(Bool.and(aa, bb), cc) == False{} : Bool}:
  match aa bb:
    case False{} _bb:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      hh

# both is false when its rate check is
def both.no(okc: Bool) -> {Wav.enc.both(okc, False{}) == False{} : Bool}:
  match okc:
    case False{}:
      {==}
    case True{}:
      {==}

# a zero rate fails enc.ok for every channel count and format
def ok.rate0(+nch: U32, fmt: Au.Format) -> {Wav.enc.ok(nch, Au.kind.of(fmt), 0) == False{} : Bool}:
  match fmt:
    case Au.S16{}:
      both.no(Wav.enc.ch(nch))
    case Au.Flt{}:
      both.no(Wav.enc.ch(nch))

def Laws.wav_rate0(nch, fmt, pcm):
  bytes.none(Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n), 0, nch, Au.kind.of(fmt), pcm,
    if.none(Wav.enc.ok(nch, Au.kind.of(fmt), 0),
      Wav.enc.sized(0, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm))),
      Wav.enc.fits(Au.kind.of(fmt), pcm), 0, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm)), pcm,
      and.first(Wav.enc.ok(nch, Au.kind.of(fmt), 0),
        Wav.enc.sized(0, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm))),
        Wav.enc.fits(Au.kind.of(fmt), pcm), ok.rate0(nch, fmt))))

def Laws.wav_wide_s16(hz, nch, pcm, h_wide):
  bytes.none(Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n), hz, nch, 1, pcm,
    if.none(Wav.enc.ok(nch, 1, hz), Wav.enc.sized(hz, nch, 1, U32.from_nat(List.length(&2, U32, pcm))),
      Wav.enc.fits(1, pcm), hz, nch, 1, U32.from_nat(List.length(&2, U32, pcm)), pcm,
      and.third(Wav.enc.ok(nch, 1, hz), Wav.enc.sized(hz, nch, 1, U32.from_nat(List.length(&2, U32, pcm))),
        Wav.enc.fits(1, pcm), h_wide)))

def Laws.wav_too_big(hz, nch, fmt, pcm, h_size):
  bytes.none(Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n), hz, nch, Au.kind.of(fmt), pcm,
    if.none(Wav.enc.ok(nch, Au.kind.of(fmt), hz),
      Wav.enc.sized(hz, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm))),
      Wav.enc.fits(Au.kind.of(fmt), pcm), hz, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm)), pcm,
      and.second(Wav.enc.ok(nch, Au.kind.of(fmt), hz),
        Wav.enc.sized(hz, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm))),
        Wav.enc.fits(Au.kind.of(fmt), pcm), h_size)))
