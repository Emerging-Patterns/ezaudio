# proofs of laws/WavDecodesWellFormed.bend
import Base
import ../main.bend as Au
import ../src/wav.bend as Wav
import ../laws/WavDecodesWellFormed.bend as Laws
import ../laws/defs/WellFormed.bend as D1

# well formed when there is a clip; nothing to say of none
def wf.of(mm: Maybe<&2, Au.Clip>) -> Bool:
  match mm:
    case None{}:
      True{}
    case Some{clip}:
      D1.wf(clip)

# what wf.of says of a result equal to Some(clip), it says of clip
def wf.some(
  +mm: Maybe<&2, Au.Clip>,
  +clip: Au.Clip,
  h_eq: {mm == Some{clip} : Maybe<&2, Au.Clip>},
  h_ok: {wf.of(mm) == True{} : Bool}
) -> {D1.wf(clip) == True{} : Bool}:
  Equal.trans(Bool, D1.wf(clip), wf.of(mm), True{},
    Equal.cong(Maybe<&2, Au.Clip>, Bool, xx => wf.of(xx), Some{clip}, mm,
      Equal.sym(Maybe<&2, Au.Clip>, mm, Some{clip}, h_eq)),
    h_ok)

# a kept clip passed the check, which is wf
def keep.wf(
  ok: Bool,
  +hz: U32,
  +nch: U32,
  fmt: Au.Format,
  +pcm: List<&2, U32>,
  eo: {Bool.and(Bool.or(U32.is_eq(nch, 1), U32.is_eq(nch, 2)),
    Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat(nch)), 0n)) == ok : Bool}
) -> {wf.of(Au.wav.keep(ok, Au.Clip{hz, nch, fmt, pcm})) == True{} : Bool}:
  match ok:
    case False{}:
      {==}
    case True{}:
      eo

# whatever the reader hands over, the clip made of it is well formed or none
def parsed.wf(mm: Maybe<&2, Wav.Wav>) -> {wf.of(Au.wav.parsed(mm)) == True{} : Bool}:
  match mm:
    case None{}:
      {==}
    case Some{Wav.Wav{+rate, +channels, +kind, +frames}}:
      keep.wf(
        Bool.and(Bool.or(U32.is_eq(channels, 1), U32.is_eq(channels, 2)),
          Nat.is_eq(Nat.mod(List.length(&2, U32, frames), U32.to_nat(channels)), 0n)),
        rate, channels, Au.fmt.of(kind), frames, {==})

def Laws.wav_decode_well_formed(bytes, clip, h_dec):
  wf.some(Au.decode_wav(bytes), clip, h_dec, parsed.wf(Wav.wav.parse(bytes)))
