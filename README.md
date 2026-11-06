# ezaudio

Audio for [Bend 2](https://github.com/bendlang/bend).

## Install

ezaudio is built and checked on bend 2.0.38.

With [Bend](https://github.com/bendlang/bend) alone there is no install
step: import ezaudio by its hub name and `bend` fetches it from
[the hub](https://hub.bend-lang.com) into `~/.bend/lib` on the first run.
`emerging-ezaudio@0.4.0.0` is ezaudio v0.4.0:

```
import emerging-ezaudio@0.4.0.0/main.bend as Au
```

That name resolves to `0xd2dab0fbc9db2e9ba3da65dae724eb41`.
To pin by content instead, import `0xd2dab0fbc9db2e9ba3da65dae724eb41/main.bend`.

Use 0.4.0 or later. Versions before 0.4.0 on the hub carry no LICENSE
file, so the hub shows them under the default license in its terms, not
this repository's LICENSE.

Or with [ez](https://github.com/Emerging-Patterns/ez), which records the
package in `ez.toml` (`ez init` makes one):

```
ez add Emerging-Patterns/ezaudio
```

## Usage

A clip is a `Clip`: a sample rate, a channel count, a sample format, and
interleaved frames. `s16` is signed 16-bit PCM. `f32` is IEEE 754 binary32,
stored as its bits. `decode_wav` and `encode_wav` read and write a RIFF WAVE
file of that PCM. `decode_mp3` reads MPEG-1 Layer III into `f32` frames.
`encode_mp3` writes MPEG-1 Layer III at 320 kbit/s through the analysis
filterbank, MDCT and Huffman coder. `count`, `fill`, `trim`, and `concat` are the raw-frame
helpers. Resampling is not in this version.

```
import emerging-ezaudio@0.4.0.0/main.bend as Au

def main() -> U32:
  Au.rate(Au.clip(8000, 1, Au.s16(), [0, 1]))
```

## Compliance

[LAWS.bend](LAWS.bend) lists what ezaudio guarantees: one file under
[laws/](laws/) each, proved by the file of the same name under
[proofs/](proofs/) (`bend PROOF.bend`). Most laws are closed equalities on
one fixture; the ones below that say "for every" are quantified over their
inputs. They target:

- The IBM/Microsoft RIFF WAVE form: the `RIFF`, `WAVE`, `fmt `, and `data`
  identifiers. A mono signed-16 clip at 8000 Hz encodes as PCM (format tag 1),
  one channel, 16 bits, little-endian samples, and decodes back to that clip.
  Binary32 encodes as format tag 3 with an 18-byte fmt chunk and a fact chunk.
  Stereo signed-16, the widest s16 samples, a clip of no frames, and mono and
  stereo IEEE 754 binary32, round-trip the same way, including the bits of
  1.0. Every clip `decode_wav` returns, for every input, has one or two
  channels and whole frames. A clip whose samples are not whole frames does
  not encode, for every clip; nor does a zero sample rate, an s16 sample of
  2^16 or more, or a byte rate that does not fit a U32. A byte list that is
  not RIFF decodes as none.
- `decode_wav` reads files the way libsndfile, dr_wav, ffmpeg and Python's
  `wave` do: it stops at the data chunk, so any bytes after it change
  nothing (for every such tail); a truncated or streamed data chunk
  (size 0xFFFFFFFF) reads the bytes that are there, cut to whole frames;
  chunks it does not know are skipped, before and after fmt;
  WAVE_FORMAT_EXTENSIBLE is read through its sub-format; the byte rate and
  block align are not checked. Data before fmt is none.
- `fill` makes `n * channels` samples and `trim` checks its span as natural
  numbers, for every count, so neither wraps a U32: a span past the end is
  none, and one that fits keeps exactly `n * channels` samples. `concat`
  appends clips that share rate, channels, and format, and is none when they
  differ.
- [ISO/IEC 11172-3](https://www.iso.org/standard/22412.html) MPEG-1 Layer III:
  the header `FF FB 90 C0` is Layer III, MPEG-1, 128 kbit/s, 44100 Hz, single
  channel. Layer I and Layer II decode as none, as do joint stereo, a CRC,
  and a header with no frame behind it. A silent frame at 320 kbit/s is the
  header and then zeros for the rest of `1152 * 320 * 125 / hz` bytes:
  `FF FB E0 C4` and 1044 bytes at 44100 Hz mono, `FF FB E0 04` and 1044 bytes
  for stereo, `FF FB E4 C4` and 960 bytes at 48000 Hz, `FF FB E8 C4` and 1440
  bytes at 32000 Hz. Decoding those byte strings yields 1152 zero binary32
  samples per channel. Binary32 silence encodes as the mono frame. An empty
  sample list, and a rate other than 32000, 44100, or 48000, encode as none.

Decode accepts long blocks only. Short blocks, a non-zero scale-factor
compress, a bit reservoir, joint stereo, a CRC, the count1 region, preflag,
and scale-factor scale are none. Full codec conformance is not claimed yet.
