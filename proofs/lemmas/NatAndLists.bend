# Nat addition and multiplication, and the lengths of replicate, take and
# drop, as the clip helpers in main.bend use them
import Base
import ../../main.bend as Au

# the type False names: Unit for False, Empty for True
def false_ty(bb: Bool) -> Type:
  match bb:
    case False{}:
      Unit
    case True{}:
      Empty

# False is never True
law false_true:
  for ee: {False{} == True{} : Bool}
  Empty

# the proof of false_true
def false_true(ee):
  %ee : false_ty(_)
  Unit{}

# replicate n makes n samples
law len_rep:
  for nn: Nat
  for +xx: U32
  {List.length(&2, U32, List.replicate(U32, nn, xx)) == nn : Nat}

# the proof of len_rep
def len_rep(nn, xx):
  match nn:
    case 0n:
      {==}
    case 1n+pp:
      Equal.cong(Nat, Nat, kk => 1n+kk, List.length(&2, U32, List.replicate(U32, pp, xx)), pp, len_rep(pp, xx))

# addition is associative
law add_assoc:
  for aa: Nat
  for +bb: Nat
  for +cc: Nat
  {Nat.add(Nat.add(aa, bb), cc) == Nat.add(aa, Nat.add(bb, cc)) : Nat}

# the proof of add_assoc
def add_assoc(aa, bb, cc):
  match aa:
    case 0n:
      {==}
    case 1n+pp:
      Equal.cong(Nat, Nat, kk => 1n+kk, Nat.add(Nat.add(pp, bb), cc), Nat.add(pp, Nat.add(bb, cc)),
        add_assoc(pp, bb, cc))

# multiplication distributes over addition on the left factor
law mul_add:
  for +aa: Nat
  for +bb: Nat
  for +cc: Nat
  {Nat.mul(Nat.add(aa, bb), cc) == Nat.add(Nat.mul(aa, cc), Nat.mul(bb, cc)) : Nat}

# the proof of mul_add
def mul_add(aa, bb, cc):
  match aa:
    case 0n:
      {==}
    case 1n+(+pp):
      Equal.trans(Nat, Nat.add(cc, Nat.mul(Nat.add(pp, bb), cc)),
        Nat.add(cc, Nat.add(Nat.mul(pp, cc), Nat.mul(bb, cc))),
        Nat.add(Nat.add(cc, Nat.mul(pp, cc)), Nat.mul(bb, cc)),
        Equal.cong(Nat, Nat, kk => Nat.add(cc, kk), Nat.mul(Nat.add(pp, bb), cc),
          Nat.add(Nat.mul(pp, cc), Nat.mul(bb, cc)), mul_add(pp, bb, cc)),
        Equal.sym(Nat, Nat.add(Nat.add(cc, Nat.mul(pp, cc)), Nat.mul(bb, cc)),
          Nat.add(cc, Nat.add(Nat.mul(pp, cc), Nat.mul(bb, cc))),
          add_assoc(cc, Nat.mul(pp, cc), Nat.mul(bb, cc))))

# taking k samples from a list of at least k gives k
law len_take:
  for xs: List<&2, U32>
  for kk: Nat
  for hh: {Nat.is_le(kk, List.length(&2, U32, xs)) == True{} : Bool}
  {List.length(&2, U32, Au.ls.take(kk, xs)) == kk : Nat}

# the proof of len_take
def len_take(xs, kk, hh):
  match xs kk:
    case _xs 0n:
      {==}
    case Nil{} 1n+_pk:
      Empty.absurd({List.length(&2, U32, Au.ls.take(1n+_pk, [])) == 1n+_pk : Nat}, false_true(hh))
    case _hd <> tl 1n+pk:
      Equal.cong(Nat, Nat, nn => 1n+nn, List.length(&2, U32, Au.ls.take(pk, tl)), pk, len_take(tl, pk, hh))

# dropping m and taking k from a list of at least m + k gives k
law len_take_drop:
  for xs: List<&2, U32>
  for mm: Nat
  for +kk: Nat
  for hh: {Nat.is_le(Nat.add(mm, kk), List.length(&2, U32, xs)) == True{} : Bool}
  {List.length(&2, U32, Au.ls.take(kk, Au.ls.drop(mm, xs))) == kk : Nat}

# the proof of len_take_drop
def len_take_drop(xs, mm, kk, hh):
  match xs mm:
    case _xs 0n:
      len_take(_xs, kk, hh)
    case Nil{} 1n+_pm:
      Empty.absurd({List.length(&2, U32, Au.ls.take(kk, Au.ls.drop(1n+_pm, []))) == kk : Nat}, false_true(hh))
    case _hd <> tl 1n+pm:
      len_take_drop(tl, pm, kk, hh)
