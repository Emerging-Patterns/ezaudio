# proofs of laws/Mp3DecodesWholeFrames.bend
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../laws/Mp3DecodesWholeFrames.bend as Laws
import ../laws/defs/WholeFrames.bend as D1

# whole frames when there is a clip; nothing to say of none
def whole.of(mm: Maybe<&2, Au.Clip>) -> Bool:
  match mm:
    case None{}:
      True{}
    case Some{clip}:
      D1.whole(clip)

# what whole.of says of a result equal to Some(clip), it says of clip
def whole.some(
  +mm: Maybe<&2, Au.Clip>,
  +clip: Au.Clip,
  h_eq: {mm == Some{clip} : Maybe<&2, Au.Clip>},
  h_ok: {whole.of(mm) == True{} : Bool}
) -> {D1.whole(clip) == True{} : Bool}:
  Equal.trans(Bool, D1.whole(clip), whole.of(mm), True{},
    Equal.cong(Maybe<&2, Au.Clip>, Bool, xx => whole.of(xx), Some{clip}, mm,
      Equal.sym(Maybe<&2, Au.Clip>, mm, Some{clip}, h_eq)),
    h_ok)

# a kept clip passed the check, which is whole
def keep.whole(
  ok: Bool,
  +hz: U32,
  +nch: U32,
  fmt: Au.Format,
  +pcm: List<&2, U32>,
  eo: {Bool.and(Bool.or(U32.is_eq(nch, 1), U32.is_eq(nch, 2)),
    Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat((1152 * nch : U32))), 0n)) == ok : Bool}
) -> {whole.of(Au.mp3.keep(ok, Au.Clip{hz, nch, fmt, pcm})) == True{} : Bool}:
  match ok:
    case False{}:
      {==}
    case True{}:
      eo

# whatever the frame decoder hands over, the clip made of it is whole frames or none
def parsed.whole(mm: Maybe<&2, Mp3.Pcm>) -> {whole.of(Au.mp3.parsed(mm)) == True{} : Bool}:
  match mm:
    case None{}:
      {==}
    case Some{Mp3.Pcm{+hz, +ch, +pcm}}:
      keep.whole(
        Bool.and(Bool.or(U32.is_eq(ch, 1), U32.is_eq(ch, 2)),
          Nat.is_eq(Nat.mod(List.length(&2, U32, pcm), U32.to_nat((1152 * ch : U32))), 0n)),
        hz, ch, Au.Flt{}, pcm, {==})

def Laws.mp3_decode_whole_frames(bytes, clip, h_dec):
  whole.some(Au.decode_mp3(bytes), clip, h_dec, parsed.whole(Mp3.mp3.decode(bytes)))
