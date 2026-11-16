# proofs of laws/WavChunkIdsAreRiff.bend
import Base
import ../main.bend as Au
import ../src/wav.bend as Wav
import ../laws/WavChunkIdsAreRiff.bend as Laws

# the type a Maybe names: Unit for None, Empty for Some
def none_ty(mm: Maybe<&2, List<&2, U32>>) -> Type:
  match mm:
    case None{}:
      Unit
    case Some{_xs}:
      Empty

# None is never Some
def none_some(+xs: List<&2, U32>, ee: {None{} == Some{xs} : Maybe<&2, List<&2, U32>>}) -> Empty:
  %ee : none_ty(_)
  Unit{}

# the bytes inside a Maybe, or none
def bytes.in(mm: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match mm:
    case None{}:
      []
    case Some{xs}:
      xs

# what equals Some(xs) and Some(ys) has ids of either
def ids.same(
  +xs: List<&2, U32>,
  +ys: List<&2, U32>,
  hh: {Some{xs} == Some{ys} : Maybe<&2, List<&2, U32>>},
  h_xs: {Laws.ids.of(xs) == [1380533830, 1463899717, 1718449184] : List<&2, U32>}
) -> {Laws.ids.of(ys) == [1380533830, 1463899717, 1718449184] : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Laws.ids.of(ys), Laws.ids.of(xs), [1380533830, 1463899717, 1718449184],
    Equal.cong(List<&2, U32>, List<&2, U32>, zz => Laws.ids.of(zz), ys, xs,
      Equal.cong(Maybe<&2, List<&2, U32>>, List<&2, U32>, mm => bytes.in(mm), Some{ys}, Some{xs},
        Equal.sym(Maybe<&2, List<&2, U32>>, Some{xs}, Some{ys}, hh))),
    h_xs)

# a write that passed its checks has the three ids, for each format
def write.ids(
  ok: Bool,
  +rate: U32,
  +ch: U32,
  +fmt: Au.Format,
  +ns: U32,
  +frames: List<&2, U32>,
  +bytes: List<&2, U32>,
  hh: {Wav.write.if(ok, rate, ch, Au.kind.of(fmt), ns, frames) == Some{bytes} : Maybe<&2, List<&2, U32>>}
) -> {Laws.ids.of(bytes) == [1380533830, 1463899717, 1718449184] : List<&2, U32>}:
  match ok fmt:
    case False{} fmt:
      Empty.absurd({Laws.ids.of(bytes) == [1380533830, 1463899717, 1718449184] : List<&2, U32>},
        none_some(bytes, hh))
    case True{} Au.S16{}:
      ids.same(Wav.enc.cat(Wav.enc.head(rate, ch, 1, ns, Wav.enc.bytes(1, ns)), Wav.enc.pcm(1, frames)), bytes, hh,
        {==})
    case True{} Au.Flt{}:
      ids.same(Wav.enc.cat(Wav.enc.head(rate, ch, 3, ns, Wav.enc.bytes(3, ns)), Wav.enc.pcm(3, frames)), bytes, hh,
        {==})

# a clip that encoded passed the whole-frame check and then the writer's
def bytes.ids(
  whole: Bool,
  +hz: U32,
  +nch: U32,
  +fmt: Au.Format,
  +pcm: List<&2, U32>,
  +bytes: List<&2, U32>,
  hh: {Au.wav.bytes(whole, hz, nch, Au.kind.of(fmt), pcm) == Some{bytes} : Maybe<&2, List<&2, U32>>}
) -> {Laws.ids.of(bytes) == [1380533830, 1463899717, 1718449184] : List<&2, U32>}:
  match whole:
    case False{}:
      Empty.absurd({Laws.ids.of(bytes) == [1380533830, 1463899717, 1718449184] : List<&2, U32>},
        none_some(bytes, hh))
    case True{}:
      write.ids(
        Bool.and(Bool.and(Wav.enc.ok(nch, Au.kind.of(fmt), hz),
          Wav.enc.sized(hz, nch, Au.kind.of(fmt), U32.from_nat(List.length(&2, U32, pcm)))),
          Wav.enc.fits(Au.kind.of(fmt), pcm)),
        hz, nch, fmt, U32.from_nat(List.length(&2, U32, pcm)), pcm, bytes, hh)

def Laws.riff_ids(hz, nch, fmt, pcm, bytes, h_enc):
  bytes.ids(Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n), hz, nch, fmt, pcm, bytes, h_enc)
