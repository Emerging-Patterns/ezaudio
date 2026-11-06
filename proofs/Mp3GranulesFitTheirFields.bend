# proofs of laws/Mp3GranulesFitTheirFields.bend
import Base
import ../src/mp3.bend as Mp3
import ../src/mp3_enc.bend as Enc
import ../laws/Mp3GranulesFitTheirFields.bend as Laws
import ./lemmas/Mp3Encode.bend as M2

# what every coded granule keeps: its length field, its budget, its bits
def inv(+ht: Enc.Ht, +bud: U32, +gg: Enc.Gr) -> Type:
  {Enc.gr.part(gg) == U32.from_nat(List.length(&2, U32, Enc.gr.bits(gg))) : U32}
    & {U32.is_le(Enc.gr.part(gg), bud) == True{} : Bool}
    & {Enc.hf.code(ht, Enc.take.u(U32.to_nat((Enc.gr.big(gg) * 2 : U32)), Enc.gr.ix(gg), []), Enc.gr.tab(gg))
      == Some{Enc.gr.bits(gg)} : Maybe<&2, List<&2, U32>>}

# a granule of zeros writes no bits
def inv.zero(+ht: Enc.Ht, +bud: U32) -> inv(ht, bud, Enc.gr.zero()):
  ({==}, (M2.zero_le(bud), {==}))

def inv.fit(
  ok: Bool,
  +ht: Enc.Ht,
  +bits: List<&2, U32>,
  +big: U32,
  +ix: List<&2, U32>,
  +gg: U32,
  +tab: U32,
  +bud: U32,
  h_le: {U32.is_le(U32.from_nat(List.length(&2, U32, bits)), bud) == ok : Bool},
  h_code: {Enc.hf.code(ht, Enc.take.u(U32.to_nat((big * 2 : U32)), ix, []), tab) == Some{bits}
    : Maybe<&2, List<&2, U32>>}
) -> inv(ht, bud, Enc.gr.fit(ok, bits, big, ix, gg, tab)):
  match ok:
    case True{}:
      ({==}, (h_le, h_code))
    case False{}:
      inv.zero(ht, bud)

def inv.code(
  got: Maybe<&2, List<&2, U32>>,
  +ht: Enc.Ht,
  +big: U32,
  +ix: List<&2, U32>,
  +gg: U32,
  +tab: U32,
  +bud: U32,
  hh: {Enc.hf.code(ht, Enc.take.u(U32.to_nat((big * 2 : U32)), ix, []), tab) == got : Maybe<&2, List<&2, U32>>}
) -> inv(ht, bud, Enc.gr.code(got, big, ix, gg, tab, bud)):
  match got:
    case None{}:
      inv.zero(ht, bud)
    case Some{+bits}:
      inv.fit(U32.is_le(U32.from_nat(List.length(&2, U32, bits)), bud), ht, bits, big, ix, gg, tab, bud, {==}, hh)

def inv.make(
  +ht: Enc.Ht,
  +ix: List<&2, U32>,
  +gg: U32,
  +tab: U32,
  +hz: U32,
  +bud: U32
) -> inv(ht, bud, Enc.gr.make(ht, ix, gg, tab, hz, bud)):
  inv.code(Enc.hf.code(ht, Enc.take.u(U32.to_nat((Enc.bv.of(ix, hz) * 2 : U32)), ix, []), tab), ht,
    Enc.bv.of(ix, hz), ix, gg, tab, bud, {==})

def inv.ok(
  ok: Bool,
  +ht: Enc.Ht,
  +ix: List<&2, U32>,
  +gg: U32,
  +tab: U32,
  +hz: U32,
  +bud: U32
) -> inv(ht, bud, Enc.gr.ok(ok, ht, ix, gg, tab, hz, bud)):
  match ok:
    case True{}:
      inv.make(ht, ix, gg, tab, hz, bud)
    case False{}:
      inv.zero(ht, bud)

def inv.pack(+ht: Enc.Ht, st: Enc.Sr, +hz: U32, +bud: U32) -> inv(ht, bud, Enc.gr.pack(ht, st, hz, bud)):
  match st:
    case Enc.Sr{_lo, _hi, +gg, +tab, +ix, ok}:
      inv.ok(ok, ht, ix, gg, tab, hz, bud)

def inv.tiny(
  zz: Bool,
  +pk: F32,
  +ht: Enc.Ht,
  +spec: List<&2, F32>,
  +hz: U32,
  +bud: U32
) -> inv(ht, bud, Enc.gr.tiny(zz, pk, ht, spec, hz, bud)):
  match zz:
    case True{}:
      inv.zero(ht, bud)
    case False{}:
      inv.pack(ht, Enc.dz.go(Enc.dz.thrs(), spec, pk, hz, bud, ht, Enc.Sr{0, 255, 0, 0, [], False{}}), hz, bud)

# every granule gr.of codes keeps the three
def inv.of(
  +ht: Enc.Ht,
  +spec: List<&2, F32>,
  +hz: U32,
  +bud: U32
) -> inv(ht, bud, Enc.gr.of(ht, spec, hz, bud)):
  inv.tiny(F32.is_lt(Enc.pk.go(spec, 0.0), Enc.f32.bits(730643660)), Enc.pk.go(spec, 0.0), ht, spec, hz, bud)

def inv.part(
  +ht: Enc.Ht,
  +bud: U32,
  +gg: Enc.Gr,
  pp: inv(ht, bud, gg)
) -> {Enc.gr.part(gg) == U32.from_nat(List.length(&2, U32, Enc.gr.bits(gg))) : U32}:
  match pp:
    case (aa, _rest):
      aa

def inv.fits(
  +ht: Enc.Ht,
  +bud: U32,
  +gg: Enc.Gr,
  pp: inv(ht, bud, gg)
) -> {U32.is_le(Enc.gr.part(gg), bud) == True{} : Bool}:
  match pp:
    case (_aa, (bb, _cc)):
      bb

def inv.bits(
  +ht: Enc.Ht,
  +bud: U32,
  +gg: Enc.Gr,
  pp: inv(ht, bud, gg)
) -> {Enc.hf.code(ht, Enc.take.u(U32.to_nat((Enc.gr.big(gg) * 2 : U32)), Enc.gr.ix(gg), []), Enc.gr.tab(gg))
  == Some{Enc.gr.bits(gg)} : Maybe<&2, List<&2, U32>>}:
  match pp:
    case (_aa, (_bb, cc)):
      cc

def Laws.mp3_gr_part(ht, spec, hz, bud):
  inv.part(ht, bud, Enc.gr.of(ht, spec, hz, bud), inv.of(ht, spec, hz, bud))

def Laws.mp3_gr_fit(ht, spec, hz, bud):
  inv.fits(ht, bud, Enc.gr.of(ht, spec, hz, bud), inv.of(ht, spec, hz, bud))

def Laws.mp3_gr_code(ht, spec, hz, bud):
  inv.bits(ht, bud, Enc.gr.of(ht, spec, hz, bud), inv.of(ht, spec, hz, bud))

def bud.le(
  fit: Bool,
  +nn: U32,
  hh: {U32.is_le(nn, 4095) == fit : Bool}
) -> {U32.is_le(Mp3.bud.cap(fit, nn), 4095) == True{} : Bool}:
  match fit:
    case True{}:
      hh
    case False{}:
      {==}

def Laws.mp3_bud(hz, ch):
  bud.le(U32.is_le(Mp3.enc.room(hz, ch), 4095), Mp3.enc.room(hz, ch), {==})

def Laws.mp3_room():
  {==}
