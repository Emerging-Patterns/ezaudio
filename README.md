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
  channel. Layer I and Layer II decode as none, as do mid/side joint stereo
  and a header with no frame behind it. A silent frame at 320 kbit/s is the
  header and then zeros for the rest of `1152 * 320 * 125 / hz` bytes:
  `FF FB E0 C4` and 1044 bytes at 44100 Hz mono, `FF FB E0 04` and 1044 bytes
  for stereo, `FF FB E4 C4` and 960 bytes at 48000 Hz, `FF FB E8 C4` and 1440
  bytes at 32000 Hz. Decoding those byte strings yields 1152 zero binary32
  samples per channel.
- `encode_mp3` encodes a clip exactly when its rate is 32000, 44100 or 48000
  Hz, it has one or two channels, and it has a sample, for every clip. For
  every clip it encodes, at each rate, the stream is `samples / channels /
  1152 + 2` whole 320 kbit/s frames, which hold every sample after the 576
  samples of MDCT priming and the filterbank's 480: each frame starts with
  the header `FF FB E0 C4` (`E4` at 48000 Hz, `E8` at 32000 Hz, `04` for
  stereo), is as long as that header says, and nothing follows the last. At
  44100 Hz a frame sets the pad bit (`E2`, 1045 bytes) when the remainders
  of `144 * 320000 / 44100` add up to a byte, 44 of every 49 frames as in
  LAME, so the stream is exactly 320 kbit/s. Every granule, for every
  spectrum, has a part2_3_length that is the length of its Huffman bits and
  at most its budget, which is at most 4095 bits, and those bits are its
  first big_values pairs. Binary32 samples are clamped to [-1, 1] and NaN
  reads as 0, for every word. Silence is the header and zeros: one zero
  sample is `FF FB E0 C4` and 1044 bytes, then `FF FB E2 C4` and 1045 bytes,
  at 44100 Hz mono; binary32 zeros of either sign encode the same way.

Every clip `decode_mp3` returns, for every input, has one or two channels
and a multiple of 1152 samples per channel, and two inputs in which it finds
the same frames decode the same, for every input. It skips a leading ID3v2
tag by its size (and its footer), steps over bytes that do not start an
MPEG-1 Layer III header (a Layer I or II header, MPEG-2 and 2.5 syncs, the
bytes of an APIC picture or an APEv2 tag), skips a first Xing or Info frame,
and drops a last frame the bytes end inside, as minimp3 and dr_mp3 do. A CRC
after the header is skipped, not checked. It decodes big values and count1
quadruples; a quadruple that runs past part2_3_length is discarded, as
ffmpeg does, and big values past part2_3_length or main data past the frame
are none.

Decode reads long blocks with no scale-factor bits and no bit reservoir, as
shine and ezaudio's own encoder write them: it decodes streams like those,
not typical LAME files. A frame with a bit reservoir (main_data_begin not 0),
window switching (block types 1, 2 and 3), scale-factor bits
(scalefac_compress not 0), preflag, scalefac_scale, or mid/side or
intensity stereo makes the whole decode none, as does a change of rate or
channels mid-stream: a frame with a valid header is never skipped. A
free-format stream has no frame it reads, so it is none. Full codec
conformance is not claimed yet.
