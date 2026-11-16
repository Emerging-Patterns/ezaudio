# `concat` appends the frames of two clips that share rate, channels and
# format, and is none when any of the three differ, for every pair of clips
import Base
import ../main.bend as Au

# LAW: concat appends frames when the clips agree
law concat_match:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +hb: U32
  for +cb: U32
  for +fb: Au.Format
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for h_rate: {U32.is_eq(hz, hb) == True{} : Bool}
  for h_nch: {U32.is_eq(nch, cb) == True{} : Bool}
  for h_fmt: {Au.fmt.same(fmt, fb) == True{} : Bool}
  {Au.concat(Au.clip(hz, nch, fmt, xs), Au.clip(hb, cb, fb, ys))
    == Some{Au.clip(hz, nch, fmt, List.append(&2, U32, xs, ys))} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the rates differ
law concat_rate:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +hb: U32
  for +cb: U32
  for +fb: Au.Format
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for h_rate: {U32.is_eq(hz, hb) == False{} : Bool}
  {Au.concat(Au.clip(hz, nch, fmt, xs), Au.clip(hb, cb, fb, ys)) == None{} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the channel counts differ
law concat_channels:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +hb: U32
  for +cb: U32
  for +fb: Au.Format
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for h_nch: {U32.is_eq(nch, cb) == False{} : Bool}
  {Au.concat(Au.clip(hz, nch, fmt, xs), Au.clip(hb, cb, fb, ys)) == None{} : Maybe<&2, Au.Clip>}

# LAW: concat is none when the formats differ
law concat_format:
  for +hz: U32
  for +nch: U32
  for +fmt: Au.Format
  for +hb: U32
  for +cb: U32
  for +fb: Au.Format
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for h_fmt: {Au.fmt.same(fmt, fb) == False{} : Bool}
  {Au.concat(Au.clip(hz, nch, fmt, xs), Au.clip(hb, cb, fb, ys)) == None{} : Maybe<&2, Au.Clip>}
