# proofs of laws/Mp3FramesFollowHeaders.bend
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ../src/mp3_enc.bend as Enc
import ../laws/defs/Mp3Stream.bend as D1
import ../laws/Mp3FramesFollowHeaders.bend as Laws
import ./lemmas/Mp3Encode.bend as M2

# a 44100 Hz frame starts with its header
def head44(
  pd: Bool,
  +ch: U32,
  gs: List<&2, Enc.Gr>,
  rr: List<&2, U32>
) -> {D1.ls.take4(Mp3.ls.cat(Mp3.enc.frame(44100, ch, Mp3.enc.pad(pd), gs), rr))
  == Mp3.enc.hdr(44100, ch, Mp3.enc.pad(pd)) : List<&2, U32>}:
  match pd:
    case True{}:
      {==}
    case False{}:
      {==}

# skipping the length a 44100 Hz header says leaves the next frame
def skip44(
  pd: Bool,
  +ch: U32,
  +gs: List<&2, Enc.Gr>,
  +rr: List<&2, U32>
) -> {D1.ls.skip(U32.to_nat(Mp3.frame.of(Mp3.ls.cat(Mp3.enc.frame(44100, ch, Mp3.enc.pad(pd), gs), rr))),
  Mp3.ls.cat(Mp3.enc.frame(44100, ch, Mp3.enc.pad(pd), gs), rr)) == rr : List<&2, U32>}:
  match pd:
    case True{}:
      M2.skip_fix(U32.to_nat(Mp3.frame.n(320, 44100, 1)), Mp3.ls.cat(Mp3.enc.hdr(44100, ch, 1), Enc.fr.data(gs, ch)),
        rr)
    case False{}:
      M2.skip_fix(U32.to_nat(Mp3.frame.n(320, 44100, 0)), Mp3.ls.cat(Mp3.enc.hdr(44100, ch, 0), Enc.fr.data(gs, ch)),
        rr)

# every pad bit is a frame of the 44100 Hz stream
def walk44(
  pads: List<&2, Bool>,
  +gs: List<&2, Enc.Gr>,
  +ch: U32
) -> D1.walk(pads, Mp3.fr.go(pads, gs, 44100, ch), 44100, ch):
  match pads:
    case Nil{}:
      {==}
    case +pd <> +tl:
      %Equal.sym(List<&2, U32>,
        D1.ls.skip(U32.to_nat(Mp3.frame.of(Mp3.ls.cat(Mp3.enc.frame(44100, ch, Mp3.enc.pad(pd),
          Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 44100, ch)))),
          Mp3.ls.cat(Mp3.enc.frame(44100, ch, Mp3.enc.pad(pd), Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 44100, ch))),
        Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 44100, ch),
        skip44(pd, ch, Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, []),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 44100, ch)))
        : {D1.ls.take4(Mp3.ls.cat(Mp3.enc.frame(44100, ch, Mp3.enc.pad(pd),
          Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 44100, ch)))
          == Mp3.enc.hdr(44100, ch, Mp3.enc.pad(pd)) : List<&2, U32>} & D1.walk(tl, _, 44100, ch)
      (head44(pd, ch, Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, []),
        Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 44100, ch)),
        walk44(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), ch))

def Laws.mp3_frames_44(nch, fmt, pcm, h_ok):
  %Equal.sym(Maybe<&2, List<&2, U32>>, Mp3.mp3.pick(Mp3.enc.fit(44100, nch), 44100, nch, Au.kind.of(fmt), pcm),
    Some{Mp3.enc.bytes(44100, nch, Au.kind.of(fmt), pcm)},
    M2.pick_some(Mp3.enc.fit(44100, nch), 44100, nch, Au.kind.of(fmt), pcm, h_ok))
    : D1.walk(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 44100, 0), D1.bytes.of(_), 44100, nch)
  walk44(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 44100, 0),
    Enc.enc.grans(44100, nch, Au.kind.of(fmt), pcm, D1.mp3.nframes(nch, pcm), Mp3.enc.bud(44100, nch)), nch)

# a 48000 Hz frame starts with its header
def head48(
  pd: Bool,
  +ch: U32,
  gs: List<&2, Enc.Gr>,
  rr: List<&2, U32>
) -> {D1.ls.take4(Mp3.ls.cat(Mp3.enc.frame(48000, ch, Mp3.enc.pad(pd), gs), rr))
  == Mp3.enc.hdr(48000, ch, Mp3.enc.pad(pd)) : List<&2, U32>}:
  match pd:
    case True{}:
      {==}
    case False{}:
      {==}

# skipping the length a 48000 Hz header says leaves the next frame
def skip48(
  pd: Bool,
  +ch: U32,
  +gs: List<&2, Enc.Gr>,
  +rr: List<&2, U32>
) -> {D1.ls.skip(U32.to_nat(Mp3.frame.of(Mp3.ls.cat(Mp3.enc.frame(48000, ch, Mp3.enc.pad(pd), gs), rr))),
  Mp3.ls.cat(Mp3.enc.frame(48000, ch, Mp3.enc.pad(pd), gs), rr)) == rr : List<&2, U32>}:
  match pd:
    case True{}:
      M2.skip_fix(U32.to_nat(Mp3.frame.n(320, 48000, 1)), Mp3.ls.cat(Mp3.enc.hdr(48000, ch, 1), Enc.fr.data(gs, ch)),
        rr)
    case False{}:
      M2.skip_fix(U32.to_nat(Mp3.frame.n(320, 48000, 0)), Mp3.ls.cat(Mp3.enc.hdr(48000, ch, 0), Enc.fr.data(gs, ch)),
        rr)

# every pad bit is a frame of the 48000 Hz stream
def walk48(
  pads: List<&2, Bool>,
  +gs: List<&2, Enc.Gr>,
  +ch: U32
) -> D1.walk(pads, Mp3.fr.go(pads, gs, 48000, ch), 48000, ch):
  match pads:
    case Nil{}:
      {==}
    case +pd <> +tl:
      %Equal.sym(List<&2, U32>,
        D1.ls.skip(U32.to_nat(Mp3.frame.of(Mp3.ls.cat(Mp3.enc.frame(48000, ch, Mp3.enc.pad(pd),
          Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 48000, ch)))),
          Mp3.ls.cat(Mp3.enc.frame(48000, ch, Mp3.enc.pad(pd), Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 48000, ch))),
        Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 48000, ch),
        skip48(pd, ch, Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, []),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 48000, ch)))
        : {D1.ls.take4(Mp3.ls.cat(Mp3.enc.frame(48000, ch, Mp3.enc.pad(pd),
          Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 48000, ch)))
          == Mp3.enc.hdr(48000, ch, Mp3.enc.pad(pd)) : List<&2, U32>} & D1.walk(tl, _, 48000, ch)
      (head48(pd, ch, Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, []),
        Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 48000, ch)),
        walk48(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), ch))

def Laws.mp3_frames_48(nch, fmt, pcm, h_ok):
  %Equal.sym(Maybe<&2, List<&2, U32>>, Mp3.mp3.pick(Mp3.enc.fit(48000, nch), 48000, nch, Au.kind.of(fmt), pcm),
    Some{Mp3.enc.bytes(48000, nch, Au.kind.of(fmt), pcm)},
    M2.pick_some(Mp3.enc.fit(48000, nch), 48000, nch, Au.kind.of(fmt), pcm, h_ok))
    : D1.walk(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 48000, 0), D1.bytes.of(_), 48000, nch)
  walk48(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 48000, 0),
    Enc.enc.grans(48000, nch, Au.kind.of(fmt), pcm, D1.mp3.nframes(nch, pcm), Mp3.enc.bud(48000, nch)), nch)

# a 32000 Hz frame starts with its header
def head32(
  pd: Bool,
  +ch: U32,
  gs: List<&2, Enc.Gr>,
  rr: List<&2, U32>
) -> {D1.ls.take4(Mp3.ls.cat(Mp3.enc.frame(32000, ch, Mp3.enc.pad(pd), gs), rr))
  == Mp3.enc.hdr(32000, ch, Mp3.enc.pad(pd)) : List<&2, U32>}:
  match pd:
    case True{}:
      {==}
    case False{}:
      {==}

# skipping the length a 32000 Hz header says leaves the next frame
def skip32(
  pd: Bool,
  +ch: U32,
  +gs: List<&2, Enc.Gr>,
  +rr: List<&2, U32>
) -> {D1.ls.skip(U32.to_nat(Mp3.frame.of(Mp3.ls.cat(Mp3.enc.frame(32000, ch, Mp3.enc.pad(pd), gs), rr))),
  Mp3.ls.cat(Mp3.enc.frame(32000, ch, Mp3.enc.pad(pd), gs), rr)) == rr : List<&2, U32>}:
  match pd:
    case True{}:
      M2.skip_fix(U32.to_nat(Mp3.frame.n(320, 32000, 1)), Mp3.ls.cat(Mp3.enc.hdr(32000, ch, 1), Enc.fr.data(gs, ch)),
        rr)
    case False{}:
      M2.skip_fix(U32.to_nat(Mp3.frame.n(320, 32000, 0)), Mp3.ls.cat(Mp3.enc.hdr(32000, ch, 0), Enc.fr.data(gs, ch)),
        rr)

# every pad bit is a frame of the 32000 Hz stream
def walk32(
  pads: List<&2, Bool>,
  +gs: List<&2, Enc.Gr>,
  +ch: U32
) -> D1.walk(pads, Mp3.fr.go(pads, gs, 32000, ch), 32000, ch):
  match pads:
    case Nil{}:
      {==}
    case +pd <> +tl:
      %Equal.sym(List<&2, U32>,
        D1.ls.skip(U32.to_nat(Mp3.frame.of(Mp3.ls.cat(Mp3.enc.frame(32000, ch, Mp3.enc.pad(pd),
          Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 32000, ch)))),
          Mp3.ls.cat(Mp3.enc.frame(32000, ch, Mp3.enc.pad(pd), Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 32000, ch))),
        Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 32000, ch),
        skip32(pd, ch, Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, []),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 32000, ch)))
        : {D1.ls.take4(Mp3.ls.cat(Mp3.enc.frame(32000, ch, Mp3.enc.pad(pd),
          Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, [])),
          Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 32000, ch)))
          == Mp3.enc.hdr(32000, ch, Mp3.enc.pad(pd)) : List<&2, U32>} & D1.walk(tl, _, 32000, ch)
      (head32(pd, ch, Enc.gr.take(U32.to_nat((ch * 2 : U32)), gs, []),
        Mp3.fr.go(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), 32000, ch)),
        walk32(tl, Enc.gr.drop(U32.to_nat((ch * 2 : U32)), gs), ch))

def Laws.mp3_frames_32(nch, fmt, pcm, h_ok):
  %Equal.sym(Maybe<&2, List<&2, U32>>, Mp3.mp3.pick(Mp3.enc.fit(32000, nch), 32000, nch, Au.kind.of(fmt), pcm),
    Some{Mp3.enc.bytes(32000, nch, Au.kind.of(fmt), pcm)},
    M2.pick_some(Mp3.enc.fit(32000, nch), 32000, nch, Au.kind.of(fmt), pcm, h_ok))
    : D1.walk(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 32000, 0), D1.bytes.of(_), 32000, nch)
  walk32(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 32000, 0),
    Enc.enc.grans(32000, nch, Au.kind.of(fmt), pcm, D1.mp3.nframes(nch, pcm), Mp3.enc.bud(32000, nch)), nch)

def Laws.mp3_pads_len(nn, hz, slot):
  match nn:
    case 0n:
      {==}
    case 1n+pp:
      Equal.cong(Nat, Nat, kk => 1n+kk,
        List.length(&2, Bool, Mp3.enc.pads(pp, hz, Mp3.enc.next(Mp3.enc.padb(hz, slot), hz, slot))), pp,
        Laws.mp3_pads_len(pp, hz, Mp3.enc.next(Mp3.enc.padb(hz, slot), hz, slot)))

def Laws.mp3_pads_48(nn):
  match nn:
    case 0n:
      {==}
    case 1n+pp:
      Equal.cong(List<&2, Bool>, List<&2, Bool>, xs => False{} <> xs, Mp3.enc.pads(pp, 48000, 0),
        List.replicate(Bool, pp, False{}), Laws.mp3_pads_48(pp))

def Laws.mp3_pads_32(nn):
  match nn:
    case 0n:
      {==}
    case 1n+pp:
      Equal.cong(List<&2, Bool>, List<&2, Bool>, xs => False{} <> xs, Mp3.enc.pads(pp, 32000, 0),
        List.replicate(Bool, pp, False{}), Laws.mp3_pads_32(pp))

def Laws.mp3_pads_44():
  {==}

def Laws.mp3_hdr_44_1():
  {==}

def Laws.mp3_hdr_44_2():
  {==}

def Laws.mp3_hdr_48():
  {==}

def Laws.mp3_hdr_32():
  {==}
