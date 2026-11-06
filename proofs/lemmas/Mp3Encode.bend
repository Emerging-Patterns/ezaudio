# encode_mp3 past its guards, and the length of an exact-length frame, as
# the MPEG-1 Layer III encoder glue in src/mp3.bend builds them
import Base
import ../../src/mp3.bend as Mp3
import ../../laws/defs/Mp3Stream.bend as D1
import ./NatAndLists.bend as M1

# a clip that passes the guards and has a sample is its frames
law pick_some:
  for ok: Bool
  for +hz: U32
  for +ch: U32
  for +kind: U32
  for +pcm: List<&2, U32>
  for hh: {Bool.and(ok, Nat.is_ne(List.length(&2, U32, pcm), 0n)) == True{} : Bool}
  {Mp3.mp3.pick(ok, hz, ch, kind, pcm) == Some{Mp3.enc.bytes(hz, ch, kind, pcm)}
    : Maybe<&2, List<&2, U32>>}

# the proof of pick_some
def pick_some(ok, hz, ch, kind, pcm, hh):
  match ok pcm:
    case False{} _pcm:
      Empty.absurd({Mp3.mp3.pick(False{}, hz, ch, kind, _pcm) == Some{Mp3.enc.bytes(hz, ch, kind, _pcm)}
        : Maybe<&2, List<&2, U32>>}, M1.false_true(hh))
    case True{} Nil{}:
      Empty.absurd({Mp3.mp3.pick(True{}, hz, ch, kind, []) == Some{Mp3.enc.bytes(hz, ch, kind, [])}
        : Maybe<&2, List<&2, U32>>}, M1.false_true(hh))
    case True{} _hd <> _tl:
      {==}

# whether a clip encodes is the guard and a sample
law pick_is:
  for ok: Bool
  for +hz: U32
  for +ch: U32
  for +kind: U32
  for +pcm: List<&2, U32>
  {D1.is.some(Mp3.mp3.pick(ok, hz, ch, kind, pcm)) == Bool.and(ok, Nat.is_ne(List.length(&2, U32, pcm), 0n))
    : Bool}

# the proof of pick_is
def pick_is(ok, _hz, _ch, _kind, pcm):
  match ok pcm:
    case False{} _pcm:
      {==}
    case True{} Nil{}:
      {==}
    case True{} _hd <> _tl:
      {==}

# skipping a frame's bytes leaves what follows it
law skip_fix:
  for kk: Nat
  for xs: List<&2, U32>
  for +rr: List<&2, U32>
  {D1.ls.skip(kk, List.append(&2, U32, Mp3.ls.fix(kk, xs), rr)) == rr : List<&2, U32>}

# the proof of skip_fix
def skip_fix(kk, xs, rr):
  match kk xs:
    case 0n _xs:
      {==}
    case 1n+pk Nil{}:
      skip_fix(pk, [], rr)
    case 1n+pk _hd <> tl:
      skip_fix(pk, tl, rr)

# a comparison that is not GT stays so under a lower zero bit
law fin_le:
  for cc: Cmp
  for +bb: Bool
  for hh: {Cmp.is_le(cc) == True{} : Bool}
  {Cmp.is_le(Word.cmp.fin(False{}, bb, cc)) == True{} : Bool}

# the proof of fin_le
def fin_le(cc, bb, hh):
  match cc bb:
    case LT{} _bb:
      {==}
    case EQ{} False{}:
      {==}
    case EQ{} True{}:
      {==}
    case GT{} _bb:
      Empty.absurd({Cmp.is_le(Word.cmp.fin(False{}, _bb, GT{})) == True{} : Bool}, M1.false_true(hh))

# the zero word is at most every word
law zero_le_word:
  for nn: Nat
  for ww: Word(nn)
  {Cmp.is_le(Word.cmp(nn, Word.zero(nn), ww)) == True{} : Bool}

# the proof of zero_le_word
def zero_le_word(nn, ww):
  match nn:
    case 0n:
      {==}
    case 1n+(+pp):
      match ww:
        case WCon{+bb, +tt}:
          fin_le(Word.cmp(pp, Word.zero(pp), tt), bb, zero_le_word(pp, tt))

# 0 is at most every U32
law zero_le:
  for bud: U32
  {U32.is_le(0, bud) == True{} : Bool}

# the proof of zero_le
def zero_le(bud):
  match bud:
    case U32{ww}:
      zero_le_word(32n, ww)
