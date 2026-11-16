# ISO/IEC 11172-3 2.4.3.1: every clip `encode_mp3` takes is a stream of
# whole 320 kbit/s frames, for every clip at each of its rates. The frames
# are `samples / channels / 1152 + 2`: 1152 samples a frame cover the
# samples, the granule of MDCT delay the first frame primes with zeros, and
# the analysis filterbank's 480. Frame i starts with the header
# `enc.hdr(hz, channels, pad_i)` (FF FB, then E0, E4 or E8 for 44100, 48000
# or 32000 Hz with the pad bit 02, then C4 mono or 04 stereo), is as many
# bytes as that header says (144 * 320000 / hz, plus the pad byte), and no
# byte follows the last frame. A frame pads once the remainders of
# 144 * 320000 / hz since the last padded frame add up to a whole byte, as
# LAME does: 44 of every 49 frames at 44100 Hz, so the stream is exactly
# 320 kbit/s; never at 32000 or 48000 Hz.
import Base
import ../main.bend as Au
import ../src/mp3.bend as Mp3
import ./defs/Mp3Stream.bend as D1

# LAW: every encodable 44100 Hz clip is its frames, each with its header and length
law mp3_frames_44:
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  for h_ok: {D1.mp3.ok(44100, nch, pcm) == True{} : Bool}
  D1.walk(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 44100, 0),
    D1.bytes.of(Au.encode_mp3(Au.clip(44100, nch, fmt, pcm))), 44100, nch)

# LAW: every encodable 48000 Hz clip is its frames, each with its header and length
law mp3_frames_48:
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  for h_ok: {D1.mp3.ok(48000, nch, pcm) == True{} : Bool}
  D1.walk(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 48000, 0),
    D1.bytes.of(Au.encode_mp3(Au.clip(48000, nch, fmt, pcm))), 48000, nch)

# LAW: every encodable 32000 Hz clip is its frames, each with its header and length
law mp3_frames_32:
  for +nch: U32
  for +fmt: Au.Format
  for +pcm: List<&2, U32>
  for h_ok: {D1.mp3.ok(32000, nch, pcm) == True{} : Bool}
  D1.walk(Mp3.enc.pads(U32.to_nat(D1.mp3.nframes(nch, pcm)), 32000, 0),
    D1.bytes.of(Au.encode_mp3(Au.clip(32000, nch, fmt, pcm))), 32000, nch)

# LAW: there is one pad bit, so one frame, per frame asked for
law mp3_pads_len:
  for nn: Nat
  for +hz: U32
  for +slot: U32
  {List.length(&2, Bool, Mp3.enc.pads(nn, hz, slot)) == nn : Nat}

# LAW: no 48000 Hz frame pads
law mp3_pads_48:
  for nn: Nat
  {Mp3.enc.pads(nn, 48000, 0) == List.replicate(Bool, nn, False{}) : List<&2, Bool>}

# LAW: no 32000 Hz frame pads
law mp3_pads_32:
  for nn: Nat
  {Mp3.enc.pads(nn, 32000, 0) == List.replicate(Bool, nn, False{}) : List<&2, Bool>}

# LAW: every 49 frames at 44100 Hz add 44 padded frames, wherever the stream ends, so every 49
# frames are 49 * 1044 + 44 bytes for 49 * 1152 samples: 320 kbit/s
law mp3_pads_44:
  for +nn: Nat
  {D1.pads.count(Mp3.enc.pads(Nat.add(49n, nn), 44100, 0)) == Nat.add(44n, D1.pads.count(Mp3.enc.pads(nn, 44100, 0)))
    : Nat}

# LAW: ISO/IEC 11172-3 — the header at 44100 Hz mono reads as MPEG-1 Layer III, 320 kbit/s,
# 44100 Hz, single channel, no CRC, with its pad bit, padded or not
law mp3_hdr_44_1:
  for pd: Bool
  {D1.hdr.fields(Mp3.enc.hdr(44100, 1, Mp3.enc.pad(pd)))
    == D1.Hf{True{}, 1, 1, 320, 44100, 1, 0, Mp3.enc.pad(pd)} : D1.Hf}

# LAW: ISO/IEC 11172-3 — the header at 44100 Hz stereo reads back its fields, padded or not
law mp3_hdr_44_2:
  for pd: Bool
  {D1.hdr.fields(Mp3.enc.hdr(44100, 2, Mp3.enc.pad(pd)))
    == D1.Hf{True{}, 1, 1, 320, 44100, 2, 0, Mp3.enc.pad(pd)} : D1.Hf}

# LAW: ISO/IEC 11172-3 — the header at 48000 Hz reads back its fields, padded or not
law mp3_hdr_48:
  for pd: Bool
  {D1.hdr.fields(Mp3.enc.hdr(48000, 1, Mp3.enc.pad(pd)))
    == D1.Hf{True{}, 1, 1, 320, 48000, 1, 0, Mp3.enc.pad(pd)} : D1.Hf}

# LAW: ISO/IEC 11172-3 — the header at 32000 Hz reads back its fields, padded or not
law mp3_hdr_32:
  for pd: Bool
  {D1.hdr.fields(Mp3.enc.hdr(32000, 2, Mp3.enc.pad(pd)))
    == D1.Hf{True{}, 1, 1, 320, 32000, 2, 0, Mp3.enc.pad(pd)} : D1.Hf}
