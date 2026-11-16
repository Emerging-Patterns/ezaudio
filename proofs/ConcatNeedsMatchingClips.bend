# proofs of laws/ConcatNeedsMatchingClips.bend
import Base
import ../main.bend as Au
import ../laws/ConcatNeedsMatchingClips.bend as Laws
import ./lemmas/NatAndLists.bend as M1

# the clips agree on all three: concat.go keeps both frame lists
def go.some(
  ar: Bool,
  ac: Bool,
  af: Bool,
  +hz: U32,
  +nch: U32,
  fmt: Au.Format,
  +xs: List<&2, U32>,
  +ys: List<&2, U32>,
  h_ar: {ar == True{} : Bool},
  h_ac: {ac == True{} : Bool},
  h_af: {af == True{} : Bool}
) -> {Au.concat.go(Au.eq.all(ar, ac, af), hz, nch, fmt, xs, ys)
  == Some{Au.clip(hz, nch, fmt, List.append(&2, U32, xs, ys))} : Maybe<&2, Au.Clip>}:
  match ar ac af:
    case True{} True{} True{}:
      {==}
    case False{} ac af:
      Empty.absurd({Au.concat.go(Au.eq.all(False{}, ac, af), hz, nch, fmt, xs, ys)
        == Some{Au.clip(hz, nch, fmt, List.append(&2, U32, xs, ys))} : Maybe<&2, Au.Clip>}, M1.false_true(h_ar))
    case True{} False{} af:
      Empty.absurd({Au.concat.go(Au.eq.all(True{}, False{}, af), hz, nch, fmt, xs, ys)
        == Some{Au.clip(hz, nch, fmt, List.append(&2, U32, xs, ys))} : Maybe<&2, Au.Clip>}, M1.false_true(h_ac))
    case True{} True{} False{}:
      Empty.absurd({Au.concat.go(Au.eq.all(True{}, True{}, False{}), hz, nch, fmt, xs, ys)
        == Some{Au.clip(hz, nch, fmt, List.append(&2, U32, xs, ys))} : Maybe<&2, Au.Clip>}, M1.false_true(h_af))

def Laws.concat_match(hz, nch, fmt, hb, cb, fb, xs, ys, h_rate, h_nch, h_fmt):
  go.some(U32.is_eq(hz, hb), U32.is_eq(nch, cb), Au.fmt.same(fmt, fb), hz, nch, fmt, xs, ys, h_rate, h_nch, h_fmt)

# any one disagreement: concat.go is none
def go.none(
  ar: Bool,
  ac: Bool,
  af: Bool,
  +hz: U32,
  +nch: U32,
  fmt: Au.Format,
  +xs: List<&2, U32>,
  +ys: List<&2, U32>,
  h_no: {Bool.and(ar, Bool.and(ac, af)) == False{} : Bool}
) -> {Au.concat.go(Au.eq.all(ar, ac, af), hz, nch, fmt, xs, ys) == None{} : Maybe<&2, Au.Clip>}:
  match ar ac af:
    case True{} True{} True{}:
      Empty.absurd({Au.concat.go(Au.eq.all(True{}, True{}, True{}), hz, nch, fmt, xs, ys) == None{}
        : Maybe<&2, Au.Clip>}, M1.false_true(Equal.sym(Bool, True{}, False{}, h_no)))
    case False{} _ac _af:
      {==}
    case True{} False{} _af:
      {==}
    case True{} True{} False{}:
      {==}

def Laws.concat_rate(hz, nch, fmt, hb, cb, fb, xs, ys, h_rate):
  go.none(U32.is_eq(hz, hb), U32.is_eq(nch, cb), Au.fmt.same(fmt, fb), hz, nch, fmt, xs, ys,
    Equal.cong(Bool, Bool, rr => Bool.and(rr, Bool.and(U32.is_eq(nch, cb), Au.fmt.same(fmt, fb))), U32.is_eq(hz, hb),
      False{}, h_rate))

# the middle of three is false, so all three are not
def and.right(
  aa: Bool,
  bb: Bool,
  cc: Bool,
  hh: {bb == False{} : Bool}
) -> {Bool.and(aa, Bool.and(bb, cc)) == False{} : Bool}:
  match aa:
    case False{}:
      {==}
    case True{}:
      Equal.cong(Bool, Bool, xx => Bool.and(xx, cc), bb, False{}, hh)

# the last of three is false, so all three are not
def and.last(
  aa: Bool,
  bb: Bool,
  cc: Bool,
  hh: {cc == False{} : Bool}
) -> {Bool.and(aa, Bool.and(bb, cc)) == False{} : Bool}:
  match aa bb:
    case False{} _bb:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      hh

def Laws.concat_channels(hz, nch, fmt, hb, cb, fb, xs, ys, h_nch):
  go.none(U32.is_eq(hz, hb), U32.is_eq(nch, cb), Au.fmt.same(fmt, fb), hz, nch, fmt, xs, ys,
    and.right(U32.is_eq(hz, hb), U32.is_eq(nch, cb), Au.fmt.same(fmt, fb), h_nch))

def Laws.concat_format(hz, nch, fmt, hb, cb, fb, xs, ys, h_fmt):
  go.none(U32.is_eq(hz, hb), U32.is_eq(nch, cb), Au.fmt.same(fmt, fb), hz, nch, fmt, xs, ys,
    and.last(U32.is_eq(hz, hb), U32.is_eq(nch, cb), Au.fmt.same(fmt, fb), h_fmt))
