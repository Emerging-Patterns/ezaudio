# proofs of laws/TrimKeepsFrameSpan.bend
import Base
import ../main.bend as Au
import ../laws/TrimKeepsFrameSpan.bend as Laws
import ./lemmas/NatAndLists.bend as M1

def Laws.trim_span():
  {==}

def Laws.trim_all():
  {==}

def Laws.trim_past():
  {==}

def Laws.trim_stereo():
  {==}

def Laws.trim_past_end(hz, nch, fmt, pcm, start, nframes, h_past):
  Equal.cong(Bool, Maybe<&2, Au.Clip>,
    ok => Au.trim.go(Bool.and(ok, Bool.or(Nat.is_ne(U32.to_nat(nch), 0n),
      Nat.is_eq(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), 0n))), hz, nch, fmt, pcm,
      Nat.mul(U32.to_nat(start), U32.to_nat(nch)), Nat.mul(U32.to_nat(nframes), U32.to_nat(nch))),
    Nat.is_le(Nat.mul(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), U32.to_nat(nch)), List.length(&2, U32, pcm)),
    False{}, h_past)

# the fits check is true when both of its parts are
def fits.true(
  +nch: U32,
  +span: Nat,
  +pcm: List<&2, U32>,
  h_fit: {Nat.is_le(Nat.mul(span, U32.to_nat(nch)), List.length(&2, U32, pcm)) == True{} : Bool},
  h_nch: {Nat.is_ne(U32.to_nat(nch), 0n) == True{} : Bool}
) -> {Au.trim.fits(U32.to_nat(nch), span, List.length(&2, U32, pcm)) == True{} : Bool}:
  Equal.trans(Bool, Au.trim.fits(U32.to_nat(nch), span, List.length(&2, U32, pcm)),
    Bool.or(Nat.is_ne(U32.to_nat(nch), 0n), Nat.is_eq(span, 0n)), True{},
    Equal.cong(Bool, Bool, ok => Bool.and(ok, Bool.or(Nat.is_ne(U32.to_nat(nch), 0n), Nat.is_eq(span, 0n))),
      Nat.is_le(Nat.mul(span, U32.to_nat(nch)), List.length(&2, U32, pcm)), True{}, h_fit),
    Equal.cong(Bool, Bool, ok => Bool.or(ok, Nat.is_eq(span, 0n)), Nat.is_ne(U32.to_nat(nch), 0n), True{}, h_nch))

# a trim whose check is true keeps the sample count the lemma gives
def kept.len(
  ok: Bool,
  +hz: U32,
  +nch: U32,
  fmt: Au.Format,
  +pcm: List<&2, U32>,
  +skip: Nat,
  +keep: Nat,
  h_ok: {ok == True{} : Bool},
  h_len: {List.length(&2, U32, Au.ls.take(keep, Au.ls.drop(skip, pcm))) == keep : Nat}
) -> {Laws.trim.len(Au.trim.go(ok, hz, nch, fmt, pcm, skip, keep)) == Some{keep} : Maybe<&2, Nat>}:
  match ok:
    case False{}:
      Empty.absurd({Laws.trim.len(Au.trim.go(False{}, hz, nch, fmt, pcm, skip, keep)) == Some{keep}
        : Maybe<&2, Nat>}, M1.false_true(h_ok))
    case True{}:
      Equal.cong(Nat, Maybe<&2, Nat>, nn => Some{nn}, List.length(&2, U32, Au.ls.take(keep, Au.ls.drop(skip, pcm))),
        keep, h_len)

def Laws.trim_fits(hz, nch, fmt, pcm, start, nframes, h_fit, h_nch):
  kept.len(Au.trim.fits(U32.to_nat(nch), Nat.add(U32.to_nat(start), U32.to_nat(nframes)), List.length(&2, U32, pcm)),
    hz, nch, fmt, pcm, Nat.mul(U32.to_nat(start), U32.to_nat(nch)), Nat.mul(U32.to_nat(nframes), U32.to_nat(nch)),
    fits.true(nch, Nat.add(U32.to_nat(start), U32.to_nat(nframes)), pcm, h_fit, h_nch),
    M1.len_take_drop(pcm, Nat.mul(U32.to_nat(start), U32.to_nat(nch)), Nat.mul(U32.to_nat(nframes), U32.to_nat(nch)),
      Equal.trans(Bool,
        Nat.is_le(Nat.add(Nat.mul(U32.to_nat(start), U32.to_nat(nch)), Nat.mul(U32.to_nat(nframes), U32.to_nat(nch))),
          List.length(&2, U32, pcm)),
        Nat.is_le(Nat.mul(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), U32.to_nat(nch)),
          List.length(&2, U32, pcm)),
        True{},
        Equal.cong(Nat, Bool, nn => Nat.is_le(nn, List.length(&2, U32, pcm)),
          Nat.add(Nat.mul(U32.to_nat(start), U32.to_nat(nch)), Nat.mul(U32.to_nat(nframes), U32.to_nat(nch))),
          Nat.mul(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), U32.to_nat(nch)),
          Equal.sym(Nat, Nat.mul(Nat.add(U32.to_nat(start), U32.to_nat(nframes)), U32.to_nat(nch)),
            Nat.add(Nat.mul(U32.to_nat(start), U32.to_nat(nch)), Nat.mul(U32.to_nat(nframes), U32.to_nat(nch))),
            M1.mul_add(U32.to_nat(start), U32.to_nat(nframes), U32.to_nat(nch)))),
        h_fit)))
